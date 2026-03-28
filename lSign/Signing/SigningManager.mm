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

    NSString *outputName = [NSString stringWithFormat:@"signed_%@", ipaURL.lastPathComponent];
    NSString *outputPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject]
                            stringByAppendingPathComponent:outputName];

    log(@"Initializing ZSign...");

    ZSigner *signer = [[ZSigner alloc] init];
    signer.ipaPath       = ipaURL.path;
    signer.p12Path       = p12URL.path;
    signer.p12Password   = password;
    signer.provisionPath = provisionURL.path;
    signer.outputPath    = outputPath;

    if (bundleID.length)    signer.bundleId  = bundleID;
    if (appName.length)     signer.appName   = appName;
    if (appVersion.length)  signer.appVersion = appVersion;

    log(@"Signing...");

    NSError *error = nil;
    BOOL success = [signer sign:&error];

    if (success) {
        log([NSString stringWithFormat:@"Output: %@", outputPath]);
        return @"Signing completed successfully.";
    } else {
        return [NSString stringWithFormat:@"Signing failed: %@", error.localizedDescription ?: @"Unknown error"];
    }
}

@end
