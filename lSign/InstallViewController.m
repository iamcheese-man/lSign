#import "InstallViewController.h"
#import <dlfcn.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface InstallViewController () <UIDocumentPickerDelegate>
@property (nonatomic, strong) UIButton *pickButton;
@property (nonatomic, strong) UITextView *logView;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@end

@implementation InstallViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Install";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    [self setupUI];
}

- (void)setupUI {
    self.pickButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.pickButton.translatesAutoresizingMaskIntoConstraints = NO;

    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *config = [UIButtonConfiguration filledButtonConfiguration];
        config.title = @"Select Signed IPA";
        config.cornerStyle = UIButtonConfigurationCornerStyleLarge;
        self.pickButton.configuration = config;
    } else {
        [self.pickButton setTitle:@"Select Signed IPA" forState:UIControlStateNormal];
        self.pickButton.backgroundColor = [UIColor systemBlueColor];
        [self.pickButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        self.pickButton.layer.cornerRadius = 10;
    }

    [self.pickButton addTarget:self action:@selector(pickIPA) forControlEvents:UIControlEventTouchUpInside];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.spinner.translatesAutoresizingMaskIntoConstraints = NO;
    self.spinner.hidesWhenStopped = YES;

    self.logView = [[UITextView alloc] init];
    self.logView.translatesAutoresizingMaskIntoConstraints = NO;
    self.logView.editable = NO;
    self.logView.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
    self.logView.backgroundColor = [UIColor secondarySystemBackgroundColor];
    self.logView.layer.cornerRadius = 8;
    self.logView.text = @"Select a signed IPA to install.\n";

    [self.view addSubview:self.pickButton];
    [self.view addSubview:self.spinner];
    [self.view addSubview:self.logView];

    UILayoutGuide *guide = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.pickButton.topAnchor constraintEqualToAnchor:guide.topAnchor constant:40],
        [self.pickButton.leadingAnchor constraintEqualToAnchor:guide.leadingAnchor constant:20],
        [self.pickButton.trailingAnchor constraintEqualToAnchor:guide.trailingAnchor constant:-20],
        [self.pickButton.heightAnchor constraintEqualToConstant:50],

        [self.spinner.topAnchor constraintEqualToAnchor:self.pickButton.bottomAnchor constant:16],
        [self.spinner.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],

        [self.logView.topAnchor constraintEqualToAnchor:self.spinner.bottomAnchor constant:16],
        [self.logView.leadingAnchor constraintEqualToAnchor:guide.leadingAnchor constant:20],
        [self.logView.trailingAnchor constraintEqualToAnchor:guide.trailingAnchor constant:-20],
        [self.logView.bottomAnchor constraintEqualToAnchor:guide.bottomAnchor constant:-20],
    ]];
}

- (void)pickIPA {
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypeData]];
    picker.delegate = self;
    picker.allowsMultipleSelection = NO;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *url = urls.firstObject;
    if (!url) return;
    [url startAccessingSecurityScopedResource];
    [self installIPA:url.path];
}

- (void)installIPA:(NSString *)ipaPath {
    [self.spinner startAnimating];
    self.pickButton.enabled = NO;
    [self log:[NSString stringWithFormat:@"Installing %@...", ipaPath.lastPathComponent]];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        void *handle = dlopen("/System/Library/PrivateFrameworks/MobileInstallation.framework/MobileInstallation", RTLD_LAZY);
        NSString *result;

        if (!handle) {
            result = @"Failed to load MobileInstallation framework.";
        } else {
            typedef int (*MIInstall_t)(NSString *, NSDictionary *, void *, NSString *);
            MIInstall_t MobileInstallationInstall = dlsym(handle, "MobileInstallationInstall");

            if (!MobileInstallationInstall) {
                result = @"Symbol MobileInstallationInstall not found.";
            } else {
                int code = MobileInstallationInstall(ipaPath, @{@"PackageType": @"Developer"}, NULL, ipaPath);
                result = code == 0 ? @"Installed successfully." : [NSString stringWithFormat:@"Install failed with code: %d", code];
            }
            dlclose(handle);
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [self.spinner stopAnimating];
            self.pickButton.enabled = YES;
            [self log:result];
        });
    });
}

- (void)log:(NSString *)message {
    self.logView.text = [self.logView.text stringByAppendingFormat:@"%@\n", message];
    [self.logView scrollRangeToVisible:NSMakeRange(self.logView.text.length - 1, 1)];
}

@end
