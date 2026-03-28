#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^LogCallback)(NSString *message);

@interface SigningManager : NSObject

+ (NSString *)signIPA:(NSURL *)ipaURL
                  p12:(NSURL *)p12URL
            provision:(NSURL *)provisionURL
             password:(NSString *)password
             bundleID:(nullable NSString *)bundleID
              appName:(nullable NSString *)appName
           appVersion:(nullable NSString *)appVersion
          logCallback:(LogCallback)log;

@end

NS_ASSUME_NONNULL_END
