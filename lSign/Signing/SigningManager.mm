#import "SigningManager.h"
#import "zsigner.h"

#import <zlib.h>
#import <minizip/unzip.h>

@implementation SigningManager

+ (NSString *)signIPA:(NSURL *)ipaURL
                  p12:(NSURL *)p12URL
            provision:(NSURL *)provisionURL
             password:(NSString *)password
             bundleID:(nullable NSString *)bundleID
              appName:(nullable NSString *)appName
           appVersion:(nullable NSString *)appVersion
          logCallback:(nullable LogCallback)log {

    if (!log) log = ^(NSString *msg) { NSLog(@"[lSign] %@", msg); };

    log(@"Reading certificate and provisioning profile...");

    NSError *error = nil;
    NSData *provData = [NSData dataWithContentsOfURL:provisionURL options:0 error:&error];
    if (!provData) return [NSString stringWithFormat:@"Failed to read .mobileprovision: %@", error.localizedDescription];

    NSData *p12Data = [NSData dataWithContentsOfURL:p12URL options:0 error:&error];
    if (!p12Data) return [NSString stringWithFormat:@"Failed to read .p12: %@", error.localizedDescription];

    NSString *tempDir = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
    NSFileManager *fm = [NSFileManager defaultManager];

    if (![fm createDirectoryAtPath:tempDir withIntermediateDirectories:YES attributes:nil error:&error]) {
        return [NSString stringWithFormat:@"Failed to create temp directory: %@", error.localizedDescription];
    }

    @try {
        log(@"Extracting IPA...");

        unzFile uf = unzOpen64(ipaURL.path.UTF8String);
        if (!uf) return @"Failed to open IPA - not a valid zip file";

        unz_global_info64 gi;
        if (unzGetGlobalInfo64(uf, &gi) != UNZ_OK) {
            unzClose(uf);
            return @"Failed to read IPA structure";
        }

        BOOL extractSuccess = YES;
        for (uLong i = 0; i < gi.number_entry; i++) {
            char filename[1024] = {0};
            unz_file_info64 fileInfo;

            if (unzGetCurrentFileInfo64(uf, &fileInfo, filename, sizeof(filename), NULL, 0, NULL, 0) != UNZ_OK) break;

            NSString *relPath = @(filename);
            if ([relPath containsString:@".."]) {
                unzGoToNextFile(uf);
                continue;
            }

            NSString *fullPath = [tempDir stringByAppendingPathComponent:relPath];
            NSString *directory = [fullPath stringByDeletingLastPathComponent];
            [fm createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];

            if (filename[strlen(filename) - 1] != '/') { // it's a file
                if (unzOpenCurrentFile(uf) == UNZ_OK) {
                    NSMutableData *data = [NSMutableData data];
                    uint8_t buffer[65536];
                    int bytesRead;
                    while ((bytesRead = unzReadCurrentFile(uf, buffer, sizeof(buffer))) > 0) {
                        [data appendBytes:buffer length:bytesRead];
                    }
                    unzCloseCurrentFile(uf);
                    [data writeToFile:fullPath atomically:YES];
                }
            }

            if (i + 1 < gi.number_entry) unzGoToNextFile(uf);
        }
        unzClose(uf);

        if (!extractSuccess) return @"IPA extraction failed";

        // Find the .app
        NSString *payloadDir = [tempDir stringByAppendingPathComponent:@"Payload"];
        NSArray<NSString *> *items = [fm contentsOfDirectoryAtPath:payloadDir error:nil];
        NSString *appFolder = [items filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self ENDSWITH '.app'"]].firstObject;

        if (!appFolder) return @"No .app found inside the IPA";

        NSString *appPath = [payloadDir stringByAppendingPathComponent:appFolder];

        // Optional: Update Info.plist
        if (bundleID.length || appName.length || appVersion.length) {
            log(@"Updating Info.plist...");
            NSString *plistPath = [appPath stringByAppendingPathComponent:@"Info.plist"];
            NSMutableDictionary *plist = [NSMutableDictionary dictionaryWithContentsOfFile:plistPath];
            if (plist) {
                if (bundleID.length) plist[@"CFBundleIdentifier"] = bundleID;
                if (appName.length) {
                    plist[@"CFBundleDisplayName"] = appName;
                    plist[@"CFBundleName"] = appName;
                }
                if (appVersion.length) plist[@"CFBundleShortVersionString"] = appVersion;
                [plist writeToFile:plistPath atomically:YES];
            }
        }

        log(@"Signing with ZSigner...");
        __block NSString *signResult = nil;
        dispatch_semaphore_t sem = dispatch_semaphore_create(0);

        [ZSigner signWithAppPath:appPath
                            prov:provData
                             key:p12Data
                            pass:password
               completionHandler:^(BOOL success, NSError *signError) {
            signResult = success ? @"success" : [NSString stringWithFormat:@"ZSigner error: %@", signError.localizedDescription ?: @"Unknown"];
            dispatch_semaphore_signal(sem);
        }];

        dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);

        if (![signResult isEqualToString:@"success"]) return signResult;

        log(@"Signing completed successfully.");
        return @"Signing completed successfully.";

    } @finally {
        [fm removeItemAtPath:tempDir error:nil];
    }
}

@end
