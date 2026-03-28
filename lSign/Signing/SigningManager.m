#import "SigningManager.h"
#import <ZSign/ZSign.h>

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

    NSString *ipaPath       = ipaURL.path;
    NSString *p12Path       = p12URL.path;
    NSString *provisionPath = provisionURL.path;

    // Output path — Documents directory
    NSString *outputName = [NSString stringWithFormat:@"signed_%@", ipaURL.lastPathComponent];
    NSString *outputPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject]
                            stringByAppendingPathComponent:outputName];

    log(@"Initializing ZSign...");

    ZSigner *signer = [[ZSigner alloc] init];

    // Configure
    signer.p12Path        = p12Path;
    signer.p12Password    = password;
    signer.provisionPath  = provisionPath;

    if (bundleID.length)   signer.bundleID  = bundleID;
    if (appName.length)    signer.appName   = appName;
    if (appVersion.length) signer.appVersion = appVersion;

    log(@"Signing...");

    NSError *error = nil;
    BOOL success = [signer signIPA:ipaPath outputPath:outputPath error:&error];

    if (success) {
        log([NSString stringWithFormat:@"Output: %@", outputPath]);
        return @"Signing completed successfully.";
    } else {
        return [NSString stringWithFormat:@"Signing failed: %@", error.localizedDescription ?: @"Unknown error"];
    }
}

@end
