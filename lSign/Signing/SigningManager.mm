#import "SigningManager.h"
#import "zsigner.h"
#import "SSZipArchive/SSZipArchive.h"   // adjust path if needed

@implementation SigningManager

+ (NSString *)signIPA:(NSURL *)ipaURL
                  p12:(NSURL *)p12URL
            provision:(NSURL *)provisionURL
             password:(NSString *)password
             bundleID:(nullable NSString *)bundleID
              appName:(nullable NSString *)appName
           appVersion:(nullable NSString *)appVersion
          logCallback:(nullable LogCallback)log {

    if (!log) log = ^(NSString *msg){ NSLog(@"[lSign] %@", msg); };

    log(@"Reading files...");

    NSError *error = nil;
    NSData *provData = [NSData dataWithContentsOfURL:provisionURL error:&error];
    if (!provData) return [NSString stringWithFormat:@"Failed to read provision: %@", error.localizedDescription];

    NSData *p12Data = [NSData dataWithContentsOfURL:p12URL error:&error];
    if (!p12Data) return [NSString stringWithFormat:@"Failed to read P12: %@", error.localizedDescription];

    NSString *tempDir = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
    NSFileManager *fm = [NSFileManager defaultManager];

    [fm createDirectoryAtPath:tempDir withIntermediateDirectories:YES attributes:nil error:nil];

    @try {
        log(@"Extracting IPA with SSZipArchive...");

        if (![SSZipArchive unzipFileAtPath:ipaURL.path toDestination:tempDir]) {
            return @"Failed to unzip IPA";
        }

        NSString *payloadDir = [tempDir stringByAppendingPathComponent:@"Payload"];
        NSArray *contents = [fm contentsOfDirectoryAtPath:payloadDir error:nil];
        NSString *dotApp = [contents filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self ENDSWITH '.app'"]].firstObject;

        if (!dotApp) return @"No .app found";

        NSString *appPath = [payloadDir stringByAppendingPathComponent:dotApp];

        // Update Info.plist
        if (bundleID || appName || appVersion) {
            NSString *plistPath = [appPath stringByAppendingPathComponent:@"Info.plist"];
            NSMutableDictionary *plist = [NSMutableDictionary dictionaryWithContentsOfFile:plistPath];
            if (plist) {
                if (bundleID) plist[@"CFBundleIdentifier"] = bundleID;
                if (appName) {
                    plist[@"CFBundleDisplayName"] = appName;
                    plist[@"CFBundleName"] = appName;
                }
                if (appVersion) plist[@"CFBundleShortVersionString"] = appVersion;
                [plist writeToFile:plistPath atomically:YES];
            }
        }

        log(@"Signing with ZSigner...");
        __block NSString *result = nil;
        dispatch_semaphore_t sem = dispatch_semaphore_create(0);

        [ZSigner signWithAppPath:appPath prov:provData key:p12Data pass:password completionHandler:^(BOOL success, NSError *e) {
            result = success ? @"success" : [NSString stringWithFormat:@"Signing failed: %@", e.localizedDescription ?: @"Unknown"];
            dispatch_semaphore_signal(sem);
        }];

        dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);

        return [result isEqualToString:@"success"] ? @"Signing completed successfully." : result;

    } @finally {
        [fm removeItemAtPath:tempDir error:nil];
    }
}

@end
