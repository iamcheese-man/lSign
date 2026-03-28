#import "MainViewController.h"
#import "SigningManager.h"
#import <UIKit/UIKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface MainViewController () <UIDocumentPickerDelegate>

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *stackView;

@property (nonatomic, strong) UILabel *titleLabel;

@property (nonatomic, strong) UIButton *ipaButton;
@property (nonatomic, strong) UIButton *p12Button;
@property (nonatomic, strong) UIButton *provButton;

@property (nonatomic, strong) UITextField *passwordField;
@property (nonatomic, strong) UITextField *bundleIdField;
@property (nonatomic, strong) UITextField *appNameField;
@property (nonatomic, strong) UITextField *appVersionField;

@property (nonatomic, strong) UIButton *signButton;
@property (nonatomic, strong) UITextView *logView;

@property (nonatomic, strong, nullable) NSURL *ipaURL;
@property (nonatomic, strong, nullable) NSURL *p12URL;
@property (nonatomic, strong, nullable) NSURL *provURL;

@property (nonatomic, strong, nullable) UIButton *currentPickingButton;

@end

@implementation MainViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.title = @"lSign";

    [self setupUI];
}

#pragma mark - UI Setup

- (void)setupUI {
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.scrollView];

    self.stackView = [[UIStackView alloc] init];
    self.stackView.axis = UILayoutConstraintAxisVertical;
    self.stackView.spacing = 14;
    self.stackView.alignment = UIStackViewAlignmentFill;
    self.stackView.distribution = UIStackViewDistributionFill;
    self.stackView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.stackView];

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.text = @"IPA Signer";
    self.titleLabel.font = [UIFont boldSystemFontOfSize:28];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    [self.stackView addArrangedSubview:self.titleLabel];

    self.ipaButton = [self makeFileButtonWithTitle:@"Select IPA"];
    [self.ipaButton addTarget:self action:@selector(selectIPA) forControlEvents:UIControlEventTouchUpInside];
    [self.stackView addArrangedSubview:self.ipaButton];

    self.p12Button = [self makeFileButtonWithTitle:@"Select P12"];
    [self.p12Button addTarget:self action:@selector(selectP12) forControlEvents:UIControlEventTouchUpInside];
    [self.stackView addArrangedSubview:self.p12Button];

    self.provButton = [self makeFileButtonWithTitle:@"Select Provision"];
    [self.provButton addTarget:self action:@selector(selectProvision) forControlEvents:UIControlEventTouchUpInside];
    [self.stackView addArrangedSubview:self.provButton];

    self.passwordField = [self makeTextFieldWithPlaceholder:@"Certificate Password"];
    self.passwordField.secureTextEntry = YES;
    [self.stackView addArrangedSubview:self.passwordField];

    self.bundleIdField = [self makeTextFieldWithPlaceholder:@"Optional Bundle ID Override"];
    [self.stackView addArrangedSubview:self.bundleIdField];

    self.appNameField = [self makeTextFieldWithPlaceholder:@"Optional App Name Override"];
    [self.stackView addArrangedSubview:self.appNameField];

    self.appVersionField = [self makeTextFieldWithPlaceholder:@"Optional App Version Override"];
    [self.stackView addArrangedSubview:self.appVersionField];

    self.signButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.signButton.translatesAutoresizingMaskIntoConstraints = NO;

    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *config = [UIButtonConfiguration filledButtonConfiguration];
        config.title = @"Sign IPA";
        config.cornerStyle = UIButtonConfigurationCornerStyleLarge;
        self.signButton.configuration = config;
    } else {
        [self.signButton setTitle:@"Sign IPA" forState:UIControlStateNormal];
        self.signButton.backgroundColor = [UIColor systemBlueColor];
        [self.signButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        self.signButton.layer.cornerRadius = 12.0;
        self.signButton.contentEdgeInsets = UIEdgeInsetsMake(12, 16, 12, 16);
    }

    [self.signButton addTarget:self action:@selector(signTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.stackView addArrangedSubview:self.signButton];

    self.logView = [[UITextView alloc] init];
    self.logView.translatesAutoresizingMaskIntoConstraints = NO;
    self.logView.editable = NO;
    self.logView.font = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightRegular];
    self.logView.backgroundColor = [UIColor secondarySystemBackgroundColor];
    self.logView.layer.cornerRadius = 12.0;
    self.logView.text = @"Logs will appear here...";
    [self.stackView addArrangedSubview:self.logView];

    UILayoutGuide *guide = self.view.safeAreaLayoutGuide;

    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:guide.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:guide.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:guide.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:guide.bottomAnchor],

        [self.stackView.topAnchor constraintEqualToAnchor:self.scrollView.topAnchor constant:20],
        [self.stackView.leadingAnchor constraintEqualToAnchor:self.scrollView.leadingAnchor constant:20],
        [self.stackView.trailingAnchor constraintEqualToAnchor:self.scrollView.trailingAnchor constant:-20],
        [self.stackView.bottomAnchor constraintEqualToAnchor:self.scrollView.bottomAnchor constant:-20],

        [self.stackView.widthAnchor constraintEqualToAnchor:self.scrollView.widthAnchor constant:-40],

        [self.signButton.heightAnchor constraintEqualToConstant:50],
        [self.logView.heightAnchor constraintEqualToConstant:200]
    ]];
}

- (UIButton *)makeFileButtonWithTitle:(NSString *)title {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.translatesAutoresizingMaskIntoConstraints = NO;

    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *config = [UIButtonConfiguration tintedButtonConfiguration];
        config.title = title;
        config.cornerStyle = UIButtonConfigurationCornerStyleLarge;
        btn.configuration = config;
    } else {
        [btn setTitle:title forState:UIControlStateNormal];
        btn.backgroundColor = [UIColor tertiarySystemBackgroundColor];
        [btn setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
        btn.layer.cornerRadius = 12.0;
        btn.contentEdgeInsets = UIEdgeInsetsMake(0, 14, 0, 14);
    }

    [btn.heightAnchor constraintEqualToConstant:48].active = YES;
    return btn;
}

- (UITextField *)makeTextFieldWithPlaceholder:(NSString *)placeholder {
    UITextField *tf = [[UITextField alloc] init];
    tf.translatesAutoresizingMaskIntoConstraints = NO;
    tf.placeholder = placeholder;
    tf.borderStyle = UITextBorderStyleRoundedRect;
    tf.clearButtonMode = UITextFieldViewModeWhileEditing;
    tf.autocapitalizationType = UITextAutocapitalizationTypeNone;
    tf.autocorrectionType = UITextAutocorrectionTypeNo;
    tf.spellCheckingType = UITextSpellCheckingTypeNo;

    [tf.heightAnchor constraintEqualToConstant:48].active = YES;
    return tf;
}

#pragma mark - File Pickers

- (void)selectIPA {
    self.currentPickingButton = self.ipaButton;
    [self presentPickerForTypes:@[
        [UTType typeWithIdentifier:@"com.apple.itunes.ipa"],
        [UTType filenameExtension:@"ipa"],
        [UTType typeWithIdentifier:@"public.data"]
    ]];
}

- (void)selectP12 {
    self.currentPickingButton = self.p12Button;
    [self presentPickerForTypes:@[
        [UTType filenameExtension:@"p12"],
        [UTType typeWithIdentifier:@"com.rsa.pkcs-12"],
        [UTType typeWithIdentifier:@"public.data"]
    ]];
}

- (void)selectProvision {
    self.currentPickingButton = self.provButton;
    [self presentPickerForTypes:@[
        [UTType filenameExtension:@"mobileprovision"],
        [UTType typeWithIdentifier:@"public.data"]
    ]];
}

- (void)presentPickerForTypes:(NSArray<UTType *> *)types {
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:types];
    picker.delegate = self;
    picker.allowsMultipleSelection = NO;
    [self presentViewController:picker animated:YES completion:nil];
}

#pragma mark - UIDocumentPickerDelegate

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *pickedURL = urls.firstObject;
    if (!pickedURL) return;

    [pickedURL startAccessingSecurityScopedResource];

    if (self.currentPickingButton == self.ipaButton) {
        self.ipaURL = pickedURL;
        [self updateButton:self.ipaButton withURL:pickedURL fallback:@"Select IPA"];
        [self appendLog:[NSString stringWithFormat:@"Selected IPA: %@", pickedURL.lastPathComponent]];
    } else if (self.currentPickingButton == self.p12Button) {
        self.p12URL = pickedURL;
        [self updateButton:self.p12Button withURL:pickedURL fallback:@"Select P12"];
        [self appendLog:[NSString stringWithFormat:@"Selected P12: %@", pickedURL.lastPathComponent]];
    } else if (self.currentPickingButton == self.provButton) {
        self.provURL = pickedURL;
        [self updateButton:self.provButton withURL:pickedURL fallback:@"Select Provision"];
        [self appendLog:[NSString stringWithFormat:@"Selected Provision: %@", pickedURL.lastPathComponent]];
    }

    self.currentPickingButton = nil;
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    [self appendLog:@"File picking cancelled."];
    self.currentPickingButton = nil;
}

#pragma mark - Button Label Updates

- (void)updateButton:(UIButton *)button withURL:(NSURL *)url fallback:(NSString *)fallback {
    NSString *title = url.lastPathComponent ?: fallback;

    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *config = button.configuration;
        if (!config) {
            config = [UIButtonConfiguration tintedButtonConfiguration];
            config.cornerStyle = UIButtonConfigurationCornerStyleLarge;
        }
        config.title = title;
        button.configuration = config;
    } else {
        [button setTitle:title forState:UIControlStateNormal];
    }
}

#pragma mark - Signing

- (void)signTapped {
    [self.view endEditing:YES];

    if (!self.ipaURL) {
        [self appendLog:@"Error: Please select an IPA file."];
        return;
    }

    if (!self.p12URL) {
        [self appendLog:@"Error: Please select a P12 certificate."];
        return;
    }

    if (!self.provURL) {
        [self appendLog:@"Error: Please select a provisioning profile."];
        return;
    }

    NSString *password = self.passwordField.text ?: @"";
    NSString *bundleID = self.bundleIdField.text.length > 0 ? self.bundleIdField.text : nil;
    NSString *appName = self.appNameField.text.length > 0 ? self.appNameField.text : nil;
    NSString *appVersion = self.appVersionField.text.length > 0 ? self.appVersionField.text : nil;

    [self appendLog:@"Starting signing process..."];
    [self setSigningUIEnabled:NO];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *result = [SigningManager signIPA:self.ipaURL
                                               p12:self.p12URL
                                         provision:self.provURL
                                          password:password
                                          bundleID:bundleID
                                           appName:appName
                                        appVersion:appVersion
                                       logCallback:^(NSString *msg) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self appendLog:msg];
            });
        }];

        dispatch_async(dispatch_get_main_queue(), ^{
            [self appendLog:[NSString stringWithFormat:@"Result: %@", result ?: @"Unknown result"]];
            [self setSigningUIEnabled:YES];
            [self showResultAlert:result];
        });
    });
}

- (void)setSigningUIEnabled:(BOOL)enabled {
    self.signButton.enabled = enabled;
    self.ipaButton.enabled = enabled;
    self.p12Button.enabled = enabled;
    self.provButton.enabled = enabled;
    self.passwordField.enabled = enabled;
    self.bundleIdField.enabled = enabled;
    self.appNameField.enabled = enabled;
    self.appVersionField.enabled = enabled;

    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *config = self.signButton.configuration;
        config.showsActivityIndicator = !enabled;
        config.title = enabled ? @"Sign IPA" : @"Signing...";
        self.signButton.configuration = config;
    } else {
        [self.signButton setTitle:(enabled ? @"Sign IPA" : @"Signing...") forState:UIControlStateNormal];
        self.signButton.alpha = enabled ? 1.0 : 0.7;
    }
}

#pragma mark - Logging

- (void)appendLog:(NSString *)message {
    if (message.length == 0) return;

    NSString *current = self.logView.text ?: @"";
    NSString *newLine = current.length > 0 ? @"\n" : @"";
    self.logView.text = [current stringByAppendingFormat:@"%@%@", newLine, message];

    NSRange bottom = NSMakeRange(self.logView.text.length - 1, 1);
    [self.logView scrollRangeToVisible:bottom];
}

#pragma mark - Result Alert

- (void)showResultAlert:(NSString *)result {
    NSString *title = @"Done";
    NSString *message = result ?: @"Unknown result";

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];

    if (result.length > 0 && [[NSFileManager defaultManager] fileExistsAtPath:result]) {
        [alert addAction:[UIAlertAction actionWithTitle:@"Share"
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction * _Nonnull action) {
            NSURL *fileURL = [NSURL fileURLWithPath:result];
            UIActivityViewController *activity = [[UIActivityViewController alloc] initWithActivityItems:@[fileURL] applicationActivities:nil];
            [self presentViewController:activity animated:YES completion:nil];
        }]];
    }

    [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    [self presentViewController:alert animated:YES completion:nil];
}

@end
