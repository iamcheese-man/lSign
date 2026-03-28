#import "MainViewController.h"
#import "SigningManager.h"

typedef NS_ENUM(NSInteger, PickerTarget) {
    PickerTargetIPA,
    PickerTargetP12,
    PickerTargetProvision
};

@interface MainViewController () <UIDocumentPickerDelegate>
@property (nonatomic, strong) NSURL *ipaURL;
@property (nonatomic, strong) NSURL *p12URL;
@property (nonatomic, strong) NSURL *provisionURL;
@property (nonatomic, assign) PickerTarget currentTarget;

// UI
@property (nonatomic, strong) UIButton *ipaButton;
@property (nonatomic, strong) UIButton *p12Button;
@property (nonatomic, strong) UIButton *provisionButton;
@property (nonatomic, strong) UITextField *passwordField;
@property (nonatomic, strong) UITextField *bundleIDField;
@property (nonatomic, strong) UITextField *appNameField;
@property (nonatomic, strong) UITextField *appVersionField;
@property (nonatomic, strong) UIButton *signButton;
@property (nonatomic, strong) UITextView *logView;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@end

@implementation MainViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"lSign";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    [self setupUI];
}

- (void)setupUI {
    UIScrollView *scroll = [[UIScrollView alloc] init];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:scroll];

    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 12;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:stack];

    // File pickers
    self.ipaButton       = [self makePickerButton:@"Select IPA" tag:PickerTargetIPA];
    self.p12Button       = [self makePickerButton:@"Select P12" tag:PickerTargetP12];
    self.provisionButton = [self makePickerButton:@"Select MobileProvision" tag:PickerTargetProvision];

    // Text fields
    self.passwordField   = [self makeField:@"P12 Password" secure:YES];
    self.bundleIDField   = [self makeField:@"Bundle ID (optional)" secure:NO];
    self.appNameField    = [self makeField:@"App Name (optional)" secure:NO];
    self.appVersionField = [self makeField:@"Version (optional)" secure:NO];

    // Sign button
    self.signButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.signButton setTitle:@"Sign IPA" forState:UIControlStateNormal];
    self.signButton.titleLabel.font = [UIFont boldSystemFontOfSize:17];
    self.signButton.backgroundColor = [UIColor systemBlueColor];
    [self.signButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    self.signButton.layer.cornerRadius = 10;
    self.signButton.heightAnchor.constraintEqualToConstant(50).active = YES;
    [self.signButton addTarget:self action:@selector(signTapped) forControlEvents:UIControlEventTouchUpInside];

    // Spinner
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.spinner.hidesWhenStopped = YES;

    // Log view
    self.logView = [[UITextView alloc] init];
    self.logView.editable = NO;
    self.logView.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
    self.logView.backgroundColor = [UIColor secondarySystemBackgroundColor];
    self.logView.layer.cornerRadius = 8;
    self.logView.text = @"Logs will appear here...\n";
    self.logView.heightAnchor.constraintEqualToConstant(200).active = YES;

    for (UIView *v in @[
        [self sectionLabel:@"Files"],
        self.ipaButton, self.p12Button, self.provisionButton,
        [self sectionLabel:@"Options"],
        self.passwordField, self.bundleIDField, self.appNameField, self.appVersionField,
        self.signButton, self.spinner,
        [self sectionLabel:@"Log"],
        self.logView
    ]) {
        [stack addArrangedSubview:v];
    }

    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[scroll]|" options:0 metrics:nil views:@{@"scroll": scroll}]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[scroll]|" options:0 metrics:nil views:@{@"scroll": scroll}]];
    [stack.topAnchor constraintEqualToAnchor:scroll.topAnchor constant:16].active = YES;
    [stack.bottomAnchor constraintEqualToAnchor:scroll.bottomAnchor constant:-16].active = YES;
    [stack.leadingAnchor constraintEqualToAnchor:scroll.leadingAnchor constant:16].active = YES;
    [stack.trailingAnchor constraintEqualToAnchor:scroll.trailingAnchor constant:-16].active = YES;
    [stack.widthAnchor constraintEqualToAnchor:self.view.widthAnchor constant:-32].active = YES;
}

- (UILabel *)sectionLabel:(NSString *)text {
    UILabel *l = [[UILabel alloc] init];
    l.text = text.uppercaseString;
    l.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    l.textColor = [UIColor secondaryLabelColor];
    return l;
}

- (UIButton *)makePickerButton:(NSString *)title tag:(PickerTarget)tag {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.tag = tag;
    [btn setTitle:title forState:UIControlStateNormal];
    btn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    btn.backgroundColor = [UIColor secondarySystemBackgroundColor];
    btn.layer.cornerRadius = 10;
    btn.contentEdgeInsets = UIEdgeInsetsMake(0, 14, 0, 14);
    btn.heightAnchor.constraintEqualToConstant(48).active = YES;
    [btn addTarget:self action:@selector(pickerTapped:) forControlEvents:UIControlEventTouchUpInside];
    return btn;
}

- (UITextField *)makeField:(NSString *)placeholder secure:(BOOL)secure {
    UITextField *tf = [[UITextField alloc] init];
    tf.placeholder = placeholder;
    tf.secureTextEntry = secure;
    tf.backgroundColor = [UIColor secondarySystemBackgroundColor];
    tf.layer.cornerRadius = 10;
    tf.leftView = [[UIView alloc] initWithFrame:CGRectMake(0,0,14,0)];
    tf.leftViewMode = UITextFieldViewModeAlways;
    tf.heightAnchor.constraintEqualToConstant(48).active = YES;
    tf.autocorrectionType = UITextAutocorrectionTypeNo;
    tf.autocapitalizationType = UITextAutocapitalizationTypeNone;
    return tf;
}

- (void)pickerTapped:(UIButton *)sender {
    self.currentTarget = (PickerTarget)sender.tag;
    NSArray *types;
    if (self.currentTarget == PickerTargetIPA) {
        types = @[@"com.apple.itunes.ipa", @"public.data"];
    } else if (self.currentTarget == PickerTargetP12) {
        types = @[@"public.data"];
    } else {
        types = @[@"public.data"];
    }
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[
        [UTType typeWithIdentifier:@"public.data"]
    ]];
    picker.delegate = self;
    picker.allowsMultipleSelection = NO;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *url = urls.firstObject;
    if (!url) return;
    [url startAccessingSecurityScopedResource];
    NSString *name = url.lastPathComponent;
    switch (self.currentTarget) {
        case PickerTargetIPA:
            self.ipaURL = url;
            [self.ipaButton setTitle:[NSString stringWithFormat:@"IPA: %@", name] forState:UIControlStateNormal];
            break;
        case PickerTargetP12:
            self.p12URL = url;
            [self.p12Button setTitle:[NSString stringWithFormat:@"P12: %@", name] forState:UIControlStateNormal];
            break;
        case PickerTargetProvision:
            self.provisionURL = url;
            [self.provisionButton setTitle:[NSString stringWithFormat:@"Provision: %@", name] forState:UIControlStateNormal];
            break;
    }
}

- (void)signTapped {
    if (!self.ipaURL || !self.p12URL || !self.provisionURL) {
        [self log:@"Error: Please select IPA, P12 and MobileProvision"];
        return;
    }

    [self.spinner startAnimating];
    self.signButton.enabled = NO;
    [self log:@"Starting signing..."];

    NSString *password  = self.passwordField.text ?: @"";
    NSString *bundleID  = self.bundleIDField.text.length  ? self.bundleIDField.text  : nil;
    NSString *appName   = self.appNameField.text.length   ? self.appNameField.text   : nil;
    NSString *appVersion= self.appVersionField.text.length? self.appVersionField.text: nil;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *result = [SigningManager signIPA:self.ipaURL
                                              p12:self.p12URL
                                        provision:self.provisionURL
                                         password:password
                                         bundleID:bundleID
                                          appName:appName
                                       appVersion:appVersion
                                      logCallback:^(NSString *msg) {
            dispatch_async(dispatch_get_main_queue(), ^{ [self log:msg]; });
        }];

        dispatch_async(dispatch_get_main_queue(), ^{
            [self.spinner stopAnimating];
            self.signButton.enabled = YES;
            [self log:result];
        });
    });
}

- (void)log:(NSString *)message {
    self.logView.text = [self.logView.text stringByAppendingFormat:@"%@\n", message];
    NSRange bottom = NSMakeRange(self.logView.text.length - 1, 1);
    [self.logView scrollRangeToVisible:bottom];
}

@end
