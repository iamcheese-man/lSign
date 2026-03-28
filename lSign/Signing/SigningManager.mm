#import "SigningManager.h"
#import "zsigner.h"
#import <zlib.h>
#import <minizip/unzip.h>
#import <minizip/zip.h>

@implementation SigningManager

#pragma mark - ZIP helpers

+ (BOOL)extractZip:(NSString *)zipPath toDirectory:(NSString *)destDir {
    unzFile uf = unzOpen64(zipPath.UTF8String);
    if (!uf) return NO;

    NSFileManager *fm = [NSFileManager defaultManager];
    unz_global_info64 gi;
    unzGetGlobalInfo64(uf, &gi);

    for (uLong i = 0; i < gi.number_entry; i++) {
        char filename[512];
        unz_file_info64 fi;
        unzGetCurrentFileInfo64(uf, &fi, filename, sizeof(filename), NULL, 0, NULL, 0);

        NSString *filePath = [destDir stringByAppendingPathComponent:@(filename)];
        NSString *dirPath = filePath.stringByDeletingLastPathComponent;
        [fm createDirectoryAtPath:dirPath withIntermediateDirectories:YES attributes:nil error:nil];

        if (filename[strlen(filename) - 1] != '/') {
            unzOpenCurrentFile(uf);
            NSMutableData *data = [NSMutableData data];
            uint8_t buf[65536];
            int n;
            while ((n = unzReadCurrentFile(uf, buf, sizeof(buf))) > 0) {
                [data appendBytes:buf length:n];
            }
            unzCloseCurrentFile(uf);
            [data writeToFile:filePath atomically:YES];

            uint32_t extAttr = fi.external_fa >> 16;
            if (extAttr != 0) {
                [fm setAttributes:@{NSFilePosixPermissions: @(extAttr)} ofItemAtPath:filePath error:nil];
            }
        }

        if (i + 1 < gi.number_entry) unzGoToNextFile(uf);
    }

    unzClose(uf);
    return YES;
}

+ (BOOL)packDirectory:(NSString *)sourceDir toZip:(NSString *)zipPath {
    zipFile zf = zipOpen64(zipPath.UTF8String, APPEND_STATUS_CREATE);
    if (!zf) return NO;

    NSFileManager *fm = [NSFileManager defaultManager];
    NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath:sourceDir];
    NSString *file;

    while ((file = [enumerator nextObject])) {
        NSString *fullPath = [sourceDir stringByAppendingPathComponent:file];
        BOOL isDir = NO;
        [fm fileExistsAtPath:fullPath isDirectory:&isDir];
        if (isDir) continue;

        zip_fileinfo zi = {};
        zipOpenNewFileInZip(zf, file.UTF8String, &zi, NULL, 0, NULL, 0, NULL, Z_DEFLATED, Z_DEFAULT_COMPRESSION);
        NSData *data = [NSData dataWithContentsOfFile:fullPath];
        zipWriteInFileInZip(zf, data.bytes, (unsigned)data.length);
        zipCloseFileInZip(zf);
    }

    zipClose(zf, NULL);
    return YES;
}

#pragma mark - Main

+ (NSString *)signIPA:(NSURL *)ipaURL
                  p12:(NSURL *)p12URL
            provision:(NSURL *)provisionURL
             password:(NSString *)password
             bundleID:(nullable NSString *)bundleID
              appName:(nullable NSString *)appName
           appVersion:(nullable NSString *)appVersion
          logCallback:(LogCallback)log {

    log(@"Reading input files...");

    NSError *readError = nil;
    NSData *provData = [NSData dataWithContentsOfURL:provisionURL options:0 error:&readError];
    if (!provData) return [NSString stringWithFormat:@"Failed to read provision: %@", readError.localizedDescription];

    NSData *p12Data = [NSData dataWithContentsOfURL:p12URL options:0 error:&readError];
    if (!p12Data) return [NSString stringWithFormat:@"Failed to read P12: %@", readError.localizedDescription];

    log(@"Extracting IPA...");
    NSString *tempDir = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
    [[NSFileManager defaultManager] createDirectoryAtPath:tempDir withIntermediateDirectories:YES attributes:nil error:nil];

    if (![self extractZip:ipaURL.path toDirectory:tempDir]) {
        return @"Failed to extract IPA";
    }

    NSString *payloadDir = [tempDir stringByAppendingPathComponent:@"Payload"];
    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:payloadDir error:nil];
    NSString *dotApp = [contents filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self ENDSWITH '.app'"]].firstObject;
    if (!dotApp) return @"No .app found in IPA";

    NSString *appPath = [payloadDir stringByAppendingPathComponent:dotApp];

    log(@"Signing...");
    __block NSString *result = nil;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);

    [ZSigner signWithAppPath:appPath
                        prov:provData
                         key:p12Data
                        pass:password
           completionHandler:^(BOOL success, NSError *error) {
        result = success ? @"success" : [NSString stringWithFormat:@"Signing failed: %@", error.localizedDescription ?: @"Unknown error"];
        dispatch_semaphore_signal(sem);
    }];

    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    if (![result isEqualToString:@"success"]) return result;

    log(@"Repacking IPA...");
    NSString *outputName = [NSString stringWithFormat:@"signed_%@", ipaURL.lastPathComponent];
    NSString *outputPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject]
                            stringByAppendingPathComponent:outputName];

    if (![self packDirectory:tempDir toZip:outputPath]) {
        return @"Failed to repack IPA";
    }

    [[NSFileManager defaultManager] removeItemAtPath:tempDir error:nil];

    log([NSString stringWithFormat:@"Output: %@", outputPath]);
    return @"Signing completed successfully.";
}

@end
