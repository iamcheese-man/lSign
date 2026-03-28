#import "SigningManager.h"
#import "zsigner.h"

// This is the auto-generated Swift-ObjC bridge header (usually named like this)
#import "lSign-Swift.h"   // If it doesn't work, try "lSign-Swift.h" or your product name + "-Swift.h"

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

    log(@"Reading provision and P12...");

    NSError *error = nil;
    NSData *provData = [NSData dataWithContentsOfURL:provisionURL options:0 error:&error];
    if (!provData) return [NSString stringWithFormat:@"Failed to read provision: %@", error.localizedDescription];

    NSData *p12Data = [NSData dataWithContentsOfURL:p12URL options:0 error:&error];
    if (!p12Data) return [NSString stringWithFormat:@"Failed to read P12: %@", error.localizedDescription];

    NSString *tempDir = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
    NSFileManager *fm = [NSFileManager defaultManager];

    if (![fm createDirectoryAtPath:tempDir withIntermediateDirectories:YES attributes:nil error:&error]) {
        return [NSString stringWithFormat:@"Failed to create temp dir: %@", error.localizedDescription];
    }

    @try {
        log(@"Extracting IPA (rename to zip + unzipItem via Swift bridge)...");

        NSURL *tempURL = [NSURL fileURLWithPath:tempDir];
        BOOL unzipSuccess = [ZipHelper unzipIPA:ipaURL to:tempURL];

        if (!unzipSuccess) {
            return @"Failed to extract IPA";
        }

        // Find the .app bundle
        NSString *payloadDir = [tempDir stringByAppendingPathComponent:@"Payload"];
        NSArray<NSString *> *contents = [fm contentsOfDirectoryAtPath:payloadDir error:nil];
        NSString *dotApp = [contents filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self ENDSWITH '.app'"]].firstObject;

        if (!dotApp) return @"No .app bundle found after extraction";

        NSString *appPath = [payloadDir stringByAppendingPathComponent:dotApp];

        // Update Info.plist if requested
        if (bundleID.length || appName.length || appVersion.length) {
            log(@"Updating Info.plist...");
            NSString *plistPath = [appPath stringByAppendingPathComponent:@"Info.plist"];
            NSMutableDictionary *plist = [NSMutableDictionary dictionaryWithContentsOfFile:plistPath];
            if (plist) {
                if (bundleID.length)   plist[@"CFBundleIdentifier"] = bundleID;
                if (appName.length) {
                    plist[@"CFBundleDisplayName"] = appName;
                    plist[@"CFBundleName"] = appName;
                }
                if (appVersion.length) plist[@"CFBundleShortVersionString"] = appVersion;
                [plist writeToFile:plistPath atomically:YES];
            }
        }

        log(@"Signing with ZSigner...");
        __block NSString *result = nil;
        dispatch_semaphore_t sem = dispatch_semaphore_create(0);

        [ZSigner signWithAppPath:appPath
                            prov:provData
                             key:p12Data
                            pass:password
               completionHandler:^(BOOL success, NSError *signError) {
            result = success ? @"success" : [NSString stringWithFormat:@"ZSigner failed: %@", signError.localizedDescription ?: @"Unknown"];
            dispatch_semaphore_signal(sem);
        }];

        dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);

        if (![result isEqualToString:@"success"]) return result;

        log(@"Signing completed successfully.");
        return @"Signing completed successfully.";

    } @finally {
        [fm removeItemAtPath:tempDir error:nil];
        log(@"Temp files cleaned up.");
    }
}

@end
