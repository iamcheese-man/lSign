#import "SigningManager.h"
#import "zsigner.h"
#import "minizip/unzip.h"
#import "minizip/zip.h"

#import <Foundation/Foundation.h>

typedef void (^InternalLogBlock)(NSString *msg);

@implementation SigningManager

#pragma mark - Directory Helpers

+ (BOOL)createDirectoryIfNeeded:(NSString *)path {
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDir = NO;

    if ([fm fileExistsAtPath:path isDirectory:&isDir]) {
        return isDir;
    }

    return [fm createDirectoryAtPath:path
         withIntermediateDirectories:YES
                          attributes:nil
                               error:nil];
}

#pragma mark - Minizip Unzip Helpers

+ (BOOL)extractCurrentFileFromZip:(unzFile)zipFile
                      destination:(NSString *)destinationPath
                              log:(InternalLogBlock)log
{
    char filename[1024] = {0};
    unz_file_info fileInfo;
    memset(&fileInfo, 0, sizeof(fileInfo));

    if (unzGetCurrentFileInfo(zipFile, &fileInfo, filename, sizeof(filename), NULL, 0, NULL, 0) != UNZ_OK) {
        if (log) log(@"Failed to get current ZIP entry info");
        return NO;
    }

    NSString *entryName = [NSString stringWithUTF8String:filename];
    if (!entryName) {
        if (log) log(@"Failed to decode ZIP entry name");
        return NO;
    }

    NSString *fullPath = [destinationPath stringByAppendingPathComponent:entryName];

    // Directory
    if ([entryName hasSuffix:@"/"]) {
        return [self createDirectoryIfNeeded:fullPath];
    }

    // Ensure parent dir exists
    NSString *parentDir = [fullPath stringByDeletingLastPathComponent];
    if (![self createDirectoryIfNeeded:parentDir]) {
        if (log) log([NSString stringWithFormat:@"Failed to create directory: %@", parentDir]);
        return NO;
    }

    if (unzOpenCurrentFile(zipFile) != UNZ_OK) {
        if (log) log([NSString stringWithFormat:@"Failed to open ZIP entry: %@", entryName]);
        return NO;
    }

    FILE *outFile = fopen([fullPath UTF8String], "wb");
    if (!outFile) {
        if (log) log([NSString stringWithFormat:@"Failed to create file: %@", fullPath]);
        unzCloseCurrentFile(zipFile);
        return NO;
    }

    void *buffer = malloc(8192);
    if (!buffer) {
        fclose(outFile);
        unzCloseCurrentFile(zipFile);
        if (log) log(@"Failed to allocate extraction buffer");
        return NO;
    }

    BOOL success = YES;
    int bytesRead = 0;

    do {
        bytesRead = unzReadCurrentFile(zipFile, buffer, 8192);
        if (bytesRead < 0) {
            success = NO;
            if (log) log([NSString stringWithFormat:@"Failed while reading ZIP entry: %@", entryName]);
            break;
        }

        if (bytesRead > 0) {
            size_t written = fwrite(buffer, 1, bytesRead, outFile);
            if (written != (size_t)bytesRead) {
                success = NO;
                if (log) log([NSString stringWithFormat:@"Failed while writing extracted file: %@", fullPath]);
                break;
            }
        }
    } while (bytesRead > 0);

    free(buffer);
    fclose(outFile);
    unzCloseCurrentFile(zipFile);

    return success;
}

+ (BOOL)unzipIPAAtPath:(NSString *)ipaPath
         toDestination:(NSString *)destinationPath
                   log:(InternalLogBlock)log
{
    if (log) log([NSString stringWithFormat:@"Opening IPA with Minizip: %@", ipaPath]);

    unzFile zipFile = unzOpen([ipaPath UTF8String]);
    if (!zipFile) {
        if (log) log(@"Failed to open IPA as ZIP");
        return NO;
    }

    int result = unzGoToFirstFile(zipFile);
    if (result != UNZ_OK) {
        if (log) log(@"Failed to move to first ZIP entry");
        unzClose(zipFile);
        return NO;
    }

    do {
        if (![self extractCurrentFileFromZip:zipFile destination:destinationPath log:log]) {
            unzClose(zipFile);
            return NO;
        }

        result = unzGoToNextFile(zipFile);
    } while (result == UNZ_OK);

    unzClose(zipFile);

    if (result != UNZ_END_OF_LIST_OF_FILE) {
        if (log) log(@"ZIP traversal ended unexpectedly");
        return NO;
    }

    return YES;
}

#pragma mark - Minizip Zip Helpers

+ (BOOL)addFileAtPath:(NSString *)filePath
          relativeTo:(NSString *)basePath
               toZip:(zipFile)zip
                 log:(InternalLogBlock)log
{
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDir = NO;

    if (![fm fileExistsAtPath:filePath isDirectory:&isDir]) {
        if (log) log([NSString stringWithFormat:@"Missing file during zip: %@", filePath]);
        return NO;
    }

    NSString *relativePath = [filePath substringFromIndex:basePath.length];
    if ([relativePath hasPrefix:@"/"]) {
        relativePath = [relativePath substringFromIndex:1];
    }

    if (isDir) {
        NSArray *children = [fm contentsOfDirectoryAtPath:filePath error:nil];
        for (NSString *child in children) {
            NSString *childPath = [filePath stringByAppendingPathComponent:child];
            if (![self addFileAtPath:childPath relativeTo:basePath toZip:zip log:log]) {
                return NO;
            }
        }
        return YES;
    }

    NSData *data = [NSData dataWithContentsOfFile:filePath];
    if (!data) {
        if (log) log([NSString stringWithFormat:@"Failed to read file for zip: %@", filePath]);
        return NO;
    }

    zip_fileinfo zipInfo;
    memset(&zipInfo, 0, sizeof(zipInfo));

    int openResult = zipOpenNewFileInZip(
        zip,
        [relativePath UTF8String],
        &zipInfo,
        NULL, 0,
        NULL, 0,
        NULL,
        Z_DEFLATED,
        Z_DEFAULT_COMPRESSION
    );

    if (openResult != ZIP_OK) {
        if (log) log([NSString stringWithFormat:@"Failed to add file to zip: %@", relativePath]);
        return NO;
    }

    int writeResult = zipWriteInFileInZip(zip, data.bytes, (unsigned int)data.length);
    zipCloseFileInZip(zip);

    if (writeResult != ZIP_OK) {
        if (log) log([NSString stringWithFormat:@"Failed to write file into zip: %@", relativePath]);
        return NO;
    }

    return YES;
}

+ (BOOL)zipDirectoryAtPath:(NSString *)directoryPath
              toIPAAtPath:(NSString *)outputIPAPath
                      log:(InternalLogBlock)log
{
    if (log) log([NSString stringWithFormat:@"Creating signed IPA: %@", outputIPAPath]);

    zipFile zip = zipOpen([outputIPAPath UTF8String], APPEND_STATUS_CREATE);
    if (!zip) {
        if (log) log(@"Failed to create ZIP output file");
        return NO;
    }

    BOOL success = [self addFileAtPath:directoryPath
                            relativeTo:directoryPath
                                 toZip:zip
                                   log:log];

    zipClose(zip, NULL);
    return success;
}

#pragma mark - Main Signing Method

+ (NSString *)signIPA:(NSURL *)ipaURL
                  p12:(NSURL *)p12URL
            provision:(NSURL *)provisionURL
             password:(NSString *)password
             bundleID:(nullable NSString *)bundleID
              appName:(nullable NSString *)appName
           appVersion:(nullable NSString *)appVersion
           logCallback:(LogCallback)log
{
    if (!log) {
        log = ^(NSString *msg) {
            NSLog(@"[lSign] %@", msg);
        };
    }

    log(@"Reading files...");

    NSError *error = nil;
    NSFileManager *fm = [NSFileManager defaultManager];

    NSData *provData = [NSData dataWithContentsOfURL:provisionURL options:0 error:&error];
    if (!provData) {
        return [NSString stringWithFormat:@"Failed to read provision: %@", error.localizedDescription ?: @"Unknown error"];
    }

    NSData *p12Data = [NSData dataWithContentsOfURL:p12URL options:0 error:&error];
    if (!p12Data) {
        return [NSString stringWithFormat:@"Failed to read P12: %@", error.localizedDescription ?: @"Unknown error"];
    }

    NSString *tempDir = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
    NSString *payloadDir = [tempDir stringByAppendingPathComponent:@"Payload"];
    NSString *signedOutputDir = [NSTemporaryDirectory() stringByAppendingPathComponent:@"SignedIPAs"];

    [fm createDirectoryAtPath:tempDir withIntermediateDirectories:YES attributes:nil error:nil];
    [fm createDirectoryAtPath:signedOutputDir withIntermediateDirectories:YES attributes:nil error:nil];

    __block NSString *finalResult = nil;
    __block BOOL didFinish = NO;

    @try {
        log(@"Extracting IPA with Minizip...");

        if (![self unzipIPAAtPath:ipaURL.path toDestination:tempDir log:log]) {
            return @"Failed to unzip IPA";
        }

        NSArray *contents = [fm contentsOfDirectoryAtPath:payloadDir error:&error];
        if (!contents) {
            return [NSString stringWithFormat:@"Failed to read Payload directory: %@", error.localizedDescription ?: @"Unknown error"];
        }

        NSString *dotApp = nil;
        for (NSString *item in contents) {
            if ([[item pathExtension].lowercaseString isEqualToString:@"app"]) {
                dotApp = item;
                break;
            }
        }

        if (!dotApp) {
            return @"No .app found inside Payload";
        }

        NSString *appPath = [payloadDir stringByAppendingPathComponent:dotApp];

        // Update Info.plist
        if (bundleID || appName || appVersion) {
            log(@"Updating Info.plist...");

            NSString *plistPath = [appPath stringByAppendingPathComponent:@"Info.plist"];
            NSMutableDictionary *plist = [NSMutableDictionary dictionaryWithContentsOfFile:plistPath];

            if (plist) {
                if (bundleID.length > 0) {
                    plist[@"CFBundleIdentifier"] = bundleID;
                }

                if (appName.length > 0) {
                    plist[@"CFBundleDisplayName"] = appName;
                    plist[@"CFBundleName"] = appName;
                }

                if (appVersion.length > 0) {
                    plist[@"CFBundleShortVersionString"] = appVersion;
                }

                [plist writeToFile:plistPath atomically:YES];
            } else {
                log(@"Warning: Info.plist not found or unreadable, skipping plist modifications.");
            }
        }

        log(@"Signing extracted .app with ZSigner...");

        dispatch_semaphore_t sem = dispatch_semaphore_create(0);

        NSProgress *progress = [ZSigner signWithAppPath:appPath
                                                   prov:provData
                                                    key:p12Data
                                                   pass:(password ?: @"")
                                      completionHandler:^(BOOL success, NSError *signError) {

            if (!success) {
                finalResult = [NSString stringWithFormat:@"Signing failed: %@", signError.localizedDescription ?: @"Unknown signing error"];
                didFinish = YES;
                dispatch_semaphore_signal(sem);
                return;
            }

            log(@"ZSigner finished successfully.");
            log(@"Repacking signed app into IPA with Minizip...");

            NSString *baseName = [[ipaURL.lastPathComponent stringByDeletingPathExtension] stringByAppendingString:@"-signed.ipa"];
            NSString *signedIPAPath = [signedOutputDir stringByAppendingPathComponent:baseName];

            if (![self zipDirectoryAtPath:tempDir toIPAAtPath:signedIPAPath log:log]) {
                finalResult = @"Signing succeeded, but failed to repackage IPA";
            } else {
                finalResult = signedIPAPath;
            }

            didFinish = YES;
            dispatch_semaphore_signal(sem);
        }];

        if (progress) {
            log(@"ZSigner returned NSProgress object.");
        }

        dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);

        if (!didFinish) {
            return @"Signing did not finish properly";
        }

        return finalResult ?: @"Unknown signing result";

    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"Exception: %@", exception.reason ?: @"Unknown exception"];
    } @finally {
        [fm removeItemAtPath:tempDir error:nil];
    }
}

@end
