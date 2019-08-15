//
//  LFLivePreview.m
//  LFLiveKit
//
//  Copyright © 2019 Marc Delling. All rights reserved.
//

#import "LFLivePreview.h"
#import "LFLiveKit.h"
#import "LCSpinnerView.h"

inline static NSString *formatedSpeed(float bytes, float elapsed_milli) {
    if (elapsed_milli <= 0) {
        return @"N/A";
    }

    if (bytes <= 0) {
        return @"0 KB/s";
    }

    float bytes_per_sec = ((float)bytes) * 1000.f /  elapsed_milli;
    if (bytes_per_sec >= 1000 * 1000) {
        return [NSString stringWithFormat:@"%.2f MB/s", ((float)bytes_per_sec) / 1000 / 1000];
    } else if (bytes_per_sec >= 1000) {
        return [NSString stringWithFormat:@"%.1f KB/s", ((float)bytes_per_sec) / 1000];
    } else {
        return [NSString stringWithFormat:@"%ld B/s", (long)bytes_per_sec];
    }
}

@interface LFLivePreview () <LFLiveSessionDelegate>

@property (nonatomic, strong) UIButton *pixelButton;
@property (nonatomic, strong) UIButton *cameraButton;
@property (nonatomic, strong) UIButton *muteButton;
@property (nonatomic, strong) UIButton *startLiveButton;
@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) LCSpinnerView *spinnerView;
@property (nonatomic, strong) LFLiveDebug *debugInfo;
@property (nonatomic, strong) LFLiveSession *session;
@property (nonatomic, strong) UILabel *stateLabel;

@end

@implementation LFLivePreview

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [UIColor clearColor];
        [self requestAccessForVideo];
        [self requestAccessForAudio];
        [self addSubview:self.containerView];
        [self.containerView addSubview:self.stateLabel];
        [self.containerView addSubview:self.muteButton];
        [self.containerView addSubview:self.cameraButton];
        [self.containerView addSubview:self.pixelButton];
        [self.containerView addSubview:self.startLiveButton];
    }
    return self;
}

#pragma mark -- Public Method
- (void)requestAccessForVideo {
    __weak typeof(self) _self = self;
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    switch (status) {
    case AVAuthorizationStatusNotDetermined: {
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
                if (granted) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [_self.session setRunning:YES];
                    });
                }
            }];
        break;
    }
    case AVAuthorizationStatusAuthorized: {
        dispatch_async(dispatch_get_main_queue(), ^{
            [_self.session setRunning:YES];
        });
        break;
    }
    case AVAuthorizationStatusDenied:
    case AVAuthorizationStatusRestricted:
        break;
    default:
        break;
    }
}

- (void)requestAccessForAudio {
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
    switch (status) {
    case AVAuthorizationStatusNotDetermined: {
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler:^(BOOL granted) {}];
        break;
    }
    case AVAuthorizationStatusAuthorized: {
        break;
    }
    case AVAuthorizationStatusDenied:
    case AVAuthorizationStatusRestricted:
        break;
    default:
        break;
    }
}

#pragma mark -- LFStreamingSessionDelegate
/** live status changed will callback */
- (void)liveSession:(nullable LFLiveSession *)session liveStateDidChange:(LFLiveState)state {
    NSLog(@"liveStateDidChange: %ld", state);
    switch (state) {
    case LFLiveReady:
        _stateLabel.text = NSLocalizedString(@"Not connected", nil);
        break;
    case LFLivePending:
        _stateLabel.text = NSLocalizedString(@"Connecting...", nil);
        break;
    case LFLiveStart:
        _stateLabel.text = NSLocalizedString(@"Connected", nil);
        break;
    case LFLiveError:
        _stateLabel.text = NSLocalizedString(@"Connection error", nil);
        break;
    case LFLiveStop:
        _stateLabel.text = NSLocalizedString(@"Not connected", nil);
        break;
    default:
        break;
    }
}

/** live debug info callback */
- (void)liveSession:(nullable LFLiveSession *)session debugInfo:(nullable LFLiveDebug *)debugInfo {
    NSLog(@"debugInfo uploadSpeed: %@", formatedSpeed(debugInfo.currentBandwidth, debugInfo.elapsedMilli));
}

/** callback socket errorcode */
- (void)liveSession:(nullable LFLiveSession *)session errorCode:(LFLiveSocketErrorCode)errorCode {
    NSLog(@"errorCode: %ld", errorCode);
    self.startLiveButton.selected = NO;
    self.spinnerView.isSpinning = NO;
}

#pragma mark -- Getter Setter
- (LFLiveSession *)session {
    if (!_session) {
        /***   默认分辨率368 ＊ 640  音频：44.1 iphone6以上48  双声道  方向竖屏 ***/

        LFLiveVideoConfiguration *videoConfiguration = [LFLiveVideoConfiguration new];
        videoConfiguration.videoSize = CGSizeMake(640, 360);
        videoConfiguration.videoBitRate = 800*1024;
        videoConfiguration.videoMaxBitRate = 1000*1024;
        videoConfiguration.videoMinBitRate = 500*1024;
        videoConfiguration.videoFrameRate = 30;
        videoConfiguration.videoMaxKeyframeInterval = 48;
        videoConfiguration.outputImageOrientation = UIInterfaceOrientationLandscapeRight;
        videoConfiguration.autorotate = NO;
        videoConfiguration.sessionPreset = LFCaptureSessionPreset720x1280;
        _session = [[LFLiveSession alloc] initWithAudioConfiguration:[LFLiveAudioConfiguration defaultConfiguration] videoConfiguration:videoConfiguration captureType:LFLiveCaptureDefaultMask];

        /**    自己定制单声道  */
        /*
           LFLiveAudioConfiguration *audioConfiguration = [LFLiveAudioConfiguration new];
           audioConfiguration.numberOfChannels = 1;
           audioConfiguration.audioBitrate = LFLiveAudioBitRate_64Kbps;
           audioConfiguration.audioSampleRate = LFLiveAudioSampleRate_44100Hz;
           _session = [[LFLiveSession alloc] initWithAudioConfiguration:audioConfiguration videoConfiguration:[LFLiveVideoConfiguration defaultConfiguration]];
         */

        /**    自己定制高质量音频96K */
        /*
           LFLiveAudioConfiguration *audioConfiguration = [LFLiveAudioConfiguration new];
           audioConfiguration.numberOfChannels = 2;
           audioConfiguration.audioBitrate = LFLiveAudioBitRate_96Kbps;
           audioConfiguration.audioSampleRate = LFLiveAudioSampleRate_44100Hz;
           _session = [[LFLiveSession alloc] initWithAudioConfiguration:audioConfiguration videoConfiguration:[LFLiveVideoConfiguration defaultConfiguration]];
         */

        /**    自己定制高质量音频96K 分辨率设置为540*960 方向竖屏 */

        /*
           LFLiveAudioConfiguration *audioConfiguration = [LFLiveAudioConfiguration new];
           audioConfiguration.numberOfChannels = 2;
           audioConfiguration.audioBitrate = LFLiveAudioBitRate_96Kbps;
           audioConfiguration.audioSampleRate = LFLiveAudioSampleRate_44100Hz;

           LFLiveVideoConfiguration *videoConfiguration = [LFLiveVideoConfiguration new];
           videoConfiguration.videoSize = CGSizeMake(540, 960);
           videoConfiguration.videoBitRate = 800*1024;
           videoConfiguration.videoMaxBitRate = 1000*1024;
           videoConfiguration.videoMinBitRate = 500*1024;
           videoConfiguration.videoFrameRate = 24;
           videoConfiguration.videoMaxKeyframeInterval = 48;
           videoConfiguration.orientation = UIInterfaceOrientationPortrait;
           videoConfiguration.sessionPreset = LFCaptureSessionPreset540x960;

           _session = [[LFLiveSession alloc] initWithAudioConfiguration:audioConfiguration videoConfiguration:videoConfiguration];
         */


        /**    自己定制高质量音频128K 分辨率设置为720*1280 方向竖屏 */

        /*
           LFLiveAudioConfiguration *audioConfiguration = [LFLiveAudioConfiguration new];
           audioConfiguration.numberOfChannels = 2;
           audioConfiguration.audioBitrate = LFLiveAudioBitRate_128Kbps;
           audioConfiguration.audioSampleRate = LFLiveAudioSampleRate_44100Hz;

           LFLiveVideoConfiguration *videoConfiguration = [LFLiveVideoConfiguration new];
           videoConfiguration.videoSize = CGSizeMake(720, 1280);
           videoConfiguration.videoBitRate = 800*1024;
           videoConfiguration.videoMaxBitRate = 1000*1024;
           videoConfiguration.videoMinBitRate = 500*1024;
           videoConfiguration.videoFrameRate = 15;
           videoConfiguration.videoMaxKeyframeInterval = 30;
           videoConfiguration.landscape = NO;
           videoConfiguration.sessionPreset = LFCaptureSessionPreset360x640;

           _session = [[LFLiveSession alloc] initWithAudioConfiguration:audioConfiguration videoConfiguration:videoConfiguration];
         */


        /**    自己定制高质量音频128K 分辨率设置为720*1280 方向横屏  */

        /*
           LFLiveAudioConfiguration *audioConfiguration = [LFLiveAudioConfiguration new];
           audioConfiguration.numberOfChannels = 2;
           audioConfiguration.audioBitrate = LFLiveAudioBitRate_128Kbps;
           audioConfiguration.audioSampleRate = LFLiveAudioSampleRate_44100Hz;

           LFLiveVideoConfiguration *videoConfiguration = [LFLiveVideoConfiguration new];
           videoConfiguration.videoSize = CGSizeMake(1280, 720);
           videoConfiguration.videoBitRate = 800*1024;
           videoConfiguration.videoMaxBitRate = 1000*1024;
           videoConfiguration.videoMinBitRate = 500*1024;
           videoConfiguration.videoFrameRate = 15;
           videoConfiguration.videoMaxKeyframeInterval = 30;
           videoConfiguration.landscape = YES;
           videoConfiguration.sessionPreset = LFCaptureSessionPreset720x1280;

           _session = [[LFLiveSession alloc] initWithAudioConfiguration:audioConfiguration videoConfiguration:videoConfiguration];
        */

        _session.delegate = self;
        _session.showDebugInfo = YES;
        _session.previewLayer.frame = self.bounds;
        _session.watermarkImage = [[UIImage imageNamed:@"Watermark"] CIImage];
        
        [[self layer] insertSublayer:_session.previewLayer atIndex:0];
    }
    return _session;
}

- (UIView *)containerView {
    if (!_containerView) {
        _containerView = [UIView new];
        _containerView.frame = self.bounds;
        _containerView.backgroundColor = [UIColor clearColor];
        _containerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    }
    return _containerView;
}

- (UILabel *)stateLabel {
    if (!_stateLabel) {
        _stateLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 20, 150, 40)];
        _stateLabel.text = NSLocalizedString(@"Not connected", nil);
        _stateLabel.textColor = [UIColor whiteColor];
        _stateLabel.font = [UIFont boldSystemFontOfSize:14.f];
    }
    return _stateLabel;
}

- (UIButton *)muteButton {
    if (!_muteButton) {
        _muteButton = [[UIButton alloc] initWithFrame:CGRectMake(self.frame.size.width - 54, 20, 32, 32)];
        [_muteButton setImage:[UIImage imageNamed:@"AudioMuteOn"] forState:UIControlStateNormal];
        [_muteButton setImage:[UIImage imageNamed:@"AudioMuteOff"] forState:UIControlStateSelected];
        _muteButton.exclusiveTouch = YES;
        [_muteButton addTarget:self action:@selector(muteButtonAction:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _muteButton;
}

- (void)muteButtonAction:(id)sender {
    self.session.muted = !self.session.muted;
    self.muteButton.selected = self.session.muted;
}

- (UIButton *)cameraButton {
    if (!_cameraButton) {
        _cameraButton = [[UIButton alloc] initWithFrame:CGRectMake(_muteButton.frame.origin.x - 54, 20, 32, 32)];
        [_cameraButton setImage:[UIImage imageNamed:@"CameraPreview"] forState:UIControlStateNormal];
        _cameraButton.exclusiveTouch = YES;
        [_cameraButton addTarget:self action:@selector(cameraButtonAction:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _cameraButton;
}

- (void)cameraButtonAction:(id)sender {
    AVCaptureDevicePosition devicePositon = self.session.captureDevicePosition;
    self.session.captureDevicePosition = (devicePositon == AVCaptureDevicePositionBack) ? AVCaptureDevicePositionFront : AVCaptureDevicePositionBack;
}

- (UIButton *)pixelButton {
    if (!_pixelButton) {
        _pixelButton = [[UIButton alloc] initWithFrame:CGRectMake(_cameraButton.frame.origin.x - 54, 20, 32, 32)];
        [_pixelButton setImage:[UIImage imageNamed:@"FaceOn"] forState:UIControlStateNormal];
        [_pixelButton setImage:[UIImage imageNamed:@"FaceOff"] forState:UIControlStateSelected];
        _pixelButton.exclusiveTouch = YES;
        [_pixelButton addTarget:self action:@selector(pixelButtonAction:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _pixelButton;
}

- (void)pixelButtonAction:(id)sender {
    self.session.pixelFace = !self.session.pixelFace;
    self.pixelButton.selected = self.session.pixelFace;
}

- (UIButton *)startLiveButton {
    if (!_startLiveButton) {
        _startLiveButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _startLiveButton.frame = CGRectMake((self.frame.size.width - 110), (self.frame.size.height - 110), 40, 40);
        _spinnerView = [LCSpinnerView new];
        _spinnerView.frame = _startLiveButton.bounds;
        _spinnerView.arcColor = [UIColor colorWithRed:1.0 green:0.043 blue:0.101 alpha:1.0];
        [_startLiveButton addSubview:_spinnerView];
        _startLiveButton.exclusiveTouch = YES;
        [_startLiveButton addTarget:self action:@selector(startLiveButtonAction:) forControlEvents:UIControlEventTouchUpInside];
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(startLiveButtonLongPressAction:)];
        [_startLiveButton addGestureRecognizer:longPress];
    }
    return _startLiveButton;
}

- (void)startLiveButtonAction:(id)sender {
    if (_spinnerView.isBlinking == YES) {
        _spinnerView.isBlinking = NO;
        return;
    }
    self.startLiveButton.selected = !self.startLiveButton.selected;
    if (self.startLiveButton.selected) {
        LFLiveStreamInfo *stream = [LFLiveStreamInfo new];
        NSString* url = [[NSUserDefaults standardUserDefaults] stringForKey:@"LCServerUrl"]; // load url from user default aka settings
        if (!url || url.length < 10) url = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"LCServerUrl"]; // load url from plist if there are no settings
        // FIXME: detect invalid settings url
        NSLog(@"Live URL: %@", url);
        stream.url = url;
        [self.session startLive:stream];
        _spinnerView.isSpinning = YES;
    } else {
        [self.session stopLive];
        _spinnerView.isSpinning = NO;
    }
}

- (void)startLiveButtonLongPressAction:(UILongPressGestureRecognizer*)gesture {
    if ( gesture.state == UIGestureRecognizerStateBegan ) {
        _spinnerView.isBlinking = YES;
        [[NSNotificationCenter defaultCenter] postNotificationName:@"ConfigurationSetting" object:_spinnerView userInfo:nil];
    }
}

@end

