#import "SigningManager.h"
#import "zsigner.h"

@implementation SigningManager

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

    log(@"Extracting IPA temporarily...");
    NSString *tempDir = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
    [[NSFileManager defaultManager] createDirectoryAtPath:tempDir withIntermediateDirectories:YES attributes:nil error:nil];

    // Extract IPA (ZSigner requires the .app bundle path)
    unzFile uf = unzOpen64(ipaURL.path.UTF8String);
    if (!uf) return @"Failed to open IPA";

    NSFileManager *fm = [NSFileManager defaultManager];
    unz_global_info64 gi;
    unzGetGlobalInfo64(uf, &gi);

    for (uLong i = 0; i < gi.number_entry; i++) {
        char filename[512];
        unz_file_info64 fi;
        unzGetCurrentFileInfo64(uf, &fi, filename, sizeof(filename), NULL, 0, NULL, 0);

        NSString *filePath = [tempDir stringByAppendingPathComponent:@(filename)];
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
        }

        if (i + 1 < gi.number_entry) unzGoToNextFile(uf);
    }

    unzClose(uf);

    // Find the .app bundle
    NSString *payloadDir = [tempDir stringByAppendingPathComponent:@"Payload"]; 
    NSArray *contents = [fm contentsOfDirectoryAtPath:payloadDir error:nil];
    NSString *dotApp = [contents filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self ENDSWITH '.app'"]].firstObject;
    if (!dotApp) return @"No .app found in IPA";

    NSString *appPath = [payloadDir stringByAppendingPathComponent:dotApp];

    log(@"Signing with ZSigner...");
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
    
    // Cleanup temp directory
    [fm removeItemAtPath:tempDir error:nil];
    
    if (![result isEqualToString:@"success"]) return result;

    log(@"Signing completed successfully.");
    return @"Signing completed successfully.";
}

@end
