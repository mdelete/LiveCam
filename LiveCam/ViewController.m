//
//  ViewController.m
//  LiveCam
//
//  Created by Marc Delling on 28.07.19.
//  Copyright © 2019 Marc Delling. All rights reserved.
//

#import "ViewController.h"
#import "LFLivePreview.h"
#import "LCSpinnerView.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.view addSubview:[[LFLivePreview alloc] initWithFrame:self.view.bounds]];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(configurationSettingNotification:)
                                                 name:@"ConfigurationSetting"
                                               object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskLandscapeRight;
}

- (void)configurationSettingNotification:(NSNotification *)notification {
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Configure URL", nil)
                                                                   message:NSLocalizedString(@"Type in the URL for your RTMP-Server", nil)
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *ok = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                 style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction * _Nonnull action) {
        NSString *url = alert.textFields[0].text;
        if (url) {
            [[NSUserDefaults standardUserDefaults] setObject:url forKey:@"LCServerUrl"];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
    }];
    [alert addAction:ok];
    
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil];
    [alert addAction:cancel];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"rmtp://";
        textField.text = [[NSUserDefaults standardUserDefaults] stringForKey:@"LCServerUrl"];
        textField.keyboardType = UIKeyboardTypeURL;
    }];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self presentViewController:alert animated:YES completion:^{
            LCSpinnerView* spinner = [notification object];
            spinner.isBlinking = NO;
        }];
    });
}

@end
