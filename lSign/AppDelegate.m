#import "AppDelegate.h"
#import "MainViewController.h"
#import "InstallViewController.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];

    UINavigationController *signNav = [[UINavigationController alloc] initWithRootViewController:[[MainViewController alloc] init]];
    signNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Sign" image:[UIImage systemImageNamed:@"signature"] tag:0];

    UINavigationController *installNav = [[UINavigationController alloc] initWithRootViewController:[[InstallViewController alloc] init]];
    installNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Install" image:[UIImage systemImageNamed:@"arrow.down.app"] tag:1];

    UITabBarController *tabs = [[UITabBarController alloc] init];
    tabs.viewControllers = @[signNav, installNav];
    tabs.selectedIndex = 0;

    self.window.rootViewController = tabs;
    [self.window makeKeyAndVisible];
    return YES;
}

@end
