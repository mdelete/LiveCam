//
//  LFVideoCapture.m
//  LFLiveKit
//
//  Created by Marc Delling on 19/7/30
//  Copyright © 2019 Marc Delling  All rights reserved.
//

#import "LFVideoCapture.h"

#if !TARGET_IPHONE_SIMULATOR
@import Metal;
#endif

@interface LFVideoCapture () <AVCaptureVideoDataOutputSampleBufferDelegate>
{
    AVCaptureDevice* _inputCamera;
    AVCaptureDeviceInput* _videoInput;
    AVCaptureVideoDataOutput* _videoOutput;
    
    int32_t _frameRate;
    
    CIContext* _ciContext;
    
    dispatch_queue_t cameraProcessingQueue;
}

@property (nonatomic, strong) LFLiveVideoConfiguration *configuration;

/// The AVCaptureSession used to capture from the camera
@property(readwrite, retain, nonatomic) AVCaptureSession *captureSession;

/// This enables the capture session preset to be changed on the fly
@property (readwrite, nonatomic, copy) NSString *captureSessionPreset;

/// The face detector
@property (nonatomic, strong) CIDetector *detector;

@end

@implementation LFVideoCapture

@synthesize torch = _torch;
@synthesize zoomScale = _zoomScale;

#pragma mark - View LifeCycle
- (instancetype)initWithVideoConfiguration:(LFLiveVideoConfiguration *)configuration {
    if (self = [super init]) {
        _configuration = configuration;

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterBackground:) name:UIApplicationWillResignActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterForeground:) name:UIApplicationDidBecomeActiveNotification object:nil];
        
        self.pixelFace = NO;
        self.zoomScale = 1.0;
        self.mirror = YES;
        
#if TARGET_IPHONE_SIMULATOR
        _ciContext = [CIContext contextWithOptions:nil];
#else
        _ciContext = [CIContext contextWithMTLDevice:MTLCreateSystemDefaultDevice()];
#endif
        
        // Face detector
        NSDictionary *detectorOptions = [[NSDictionary alloc] initWithObjectsAndKeys:CIDetectorAccuracyLow, CIDetectorAccuracy, nil];
        self.detector = [CIDetector detectorOfType:CIDetectorTypeFace context:nil options:detectorOptions];
        
        _previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.captureSession];
        
        if ([_previewLayer.connection isVideoOrientationSupported]) {
            [_previewLayer.connection setVideoOrientation:AVCaptureVideoOrientationLandscapeRight];
        }
    }
    return self;
}

- (AVCaptureSession*) captureSession {
    if (!_captureSession) {
        
        cameraProcessingQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH,0);
        
        _frameRate = 0; // This will not set frame rate unless this value gets set to 1 or above
        _inputCamera = nil;
        
        AVCaptureDeviceDiscoverySession *captureDeviceDiscoverySession = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera] mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionUnspecified];
        
        NSArray *devices = [captureDeviceDiscoverySession devices];
        
        for (AVCaptureDevice *device in devices)
        {
            if ([device position] == AVCaptureDevicePositionFront)
            {
                _inputCamera = device;
            }
        }
        
        if (!_inputCamera) {
            return nil;
        }
        
        _captureSession = [[AVCaptureSession alloc] init];
        
        [_captureSession beginConfiguration];
        
        // FIXME: use _configuration.outputImageOrientation;
        
        NSError *error = nil;
        
        _videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:_inputCamera error:&error];
        
        if ([_captureSession canAddInput:_videoInput])
        {
            [_captureSession addInput:_videoInput];
        }
        
        self.frameRate = _configuration.videoFrameRate;
        
        _videoOutput = [[AVCaptureVideoDataOutput alloc] init];
        
        [_videoOutput setAlwaysDiscardsLateVideoFrames:NO];
        [_videoOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
        
        [_videoOutput setSampleBufferDelegate:self queue:cameraProcessingQueue];
        
        if ([_captureSession canAddOutput:_videoOutput])
        {
            [_captureSession addOutput:_videoOutput];
        }
        else
        {
            NSLog(@"Couldn't add video output");
            return nil;
        }
        
        AVCaptureConnection* connection = [_videoOutput connectionWithMediaType:AVMediaTypeVideo];
        
        if([connection isVideoMirroringSupported]) {
            [connection setVideoMirrored:(_videoInput.device.position == AVCaptureDevicePositionFront)];
        }
        
        if([connection isVideoOrientationSupported]) {
            [connection setVideoOrientation:AVCaptureVideoOrientationLandscapeRight];
        }
        
        _captureSessionPreset = _configuration.avSessionPreset;
        
        [_captureSession setSessionPreset:_captureSessionPreset];
        [_captureSession commitConfiguration];
    }
    
    return _captureSession;
}

- (void)dealloc {
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [self.captureSession stopRunning];
    
    [_videoOutput setSampleBufferDelegate:nil queue:dispatch_get_main_queue()];
    
    [self.captureSession removeInput:_videoInput];
    [self.captureSession removeOutput:_videoOutput];
}

#pragma mark - Configure

- (void)enableConfigMode {
    self.detector = [CIDetector detectorOfType: CIDetectorTypeQRCode context: nil options: nil];
}

#pragma mark - Getter & Setter

- (void)setRunning:(BOOL)running {
    if (_running == running) return;
    _running = running;
    
    if (!_running) {
        [UIApplication sharedApplication].idleTimerDisabled = NO;
        [self.captureSession stopRunning];
    } else {
        [UIApplication sharedApplication].idleTimerDisabled = YES;
        [self.captureSession startRunning];
    }
}

- (NSUInteger)frameRate {
    return _frameRate;
}

- (void)setFrameRate:(NSUInteger)frameRate;
{
    _frameRate = (int32_t) frameRate;
    
    NSLog(@"setting framerate to %d", _frameRate);
    
    CMTime frameDuration = kCMTimeInvalid;
    
    if (_frameRate > 0) {
        frameDuration = CMTimeMake(1, _frameRate);
    }
    
    NSError *error;
    
    [_inputCamera lockForConfiguration:&error];
    
    if (error == nil) {
        [_inputCamera setActiveVideoMinFrameDuration:frameDuration];
        [_inputCamera setActiveVideoMaxFrameDuration:frameDuration];
    }
    
    [_inputCamera unlockForConfiguration];
}

- (void)setCaptureDevicePosition:(AVCaptureDevicePosition)captureDevicePosition {
    if(captureDevicePosition == _videoInput.device.position) return;
    [self rotateCamera];
    self.frameRate = _configuration.videoFrameRate;
}

- (AVCaptureDevicePosition)captureDevicePosition {
    return _videoInput.device.position;
}

- (void)setTorch:(BOOL)torch {
    BOOL ret = NO;
    if (!self.captureSession) return;
    AVCaptureSession *session = (AVCaptureSession *)self.captureSession;
    [session beginConfiguration];
    if (_inputCamera) {
        if (_inputCamera.torchAvailable) {
            NSError *err = nil;
            if ([_inputCamera lockForConfiguration:&err]) {
                [_inputCamera setTorchMode:(torch ? AVCaptureTorchModeOn : AVCaptureTorchModeOff) ];
                [_inputCamera unlockForConfiguration];
                ret = (_inputCamera.torchMode == AVCaptureTorchModeOn);
            } else {
                NSLog(@"Error while locking device for torch: %@", err);
                ret = false;
            }
        } else {
            NSLog(@"Torch not available in current camera input");
        }
    }
    [session commitConfiguration];
    _torch = ret;
}

- (BOOL)torch {
    return _inputCamera.torchMode;
}

- (void)setMirror:(BOOL)mirror {
    _mirror = mirror;
}

- (void)setZoomScale:(CGFloat)zoomScale {
    if (_inputCamera) {
        AVCaptureDevice *device = (AVCaptureDevice *)_inputCamera;
        if ([device lockForConfiguration:nil]) {
            device.videoZoomFactor = zoomScale;
            [device unlockForConfiguration];
            _zoomScale = zoomScale;
        }
    }
}

- (CGFloat)zoomScale {
    return _zoomScale;
}

- (void)rotateCamera
{
    AVCaptureDeviceDiscoverySession *captureDeviceDiscoverySession = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera] mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionUnspecified];
    
    NSArray *devices = [captureDeviceDiscoverySession devices];
    
    if (devices.count < 2)
        return;
    
    NSError *error;
    AVCaptureDeviceInput *newVideoInput;
    AVCaptureDevicePosition currentCameraPosition = _videoInput.device.position;
    
    if (currentCameraPosition == AVCaptureDevicePositionBack) {
        currentCameraPosition = AVCaptureDevicePositionFront;
    } else {
        currentCameraPosition = AVCaptureDevicePositionBack;
    }
    
    AVCaptureDevice *backFacingCamera = nil;
    
    for (AVCaptureDevice *device in devices) {
        if (device.position == currentCameraPosition) {
            backFacingCamera = device;
        }
    }
    
    newVideoInput = [[AVCaptureDeviceInput alloc] initWithDevice:backFacingCamera error:&error];
    
    if (newVideoInput != nil) {
        [_captureSession beginConfiguration];
        [_captureSession removeInput:_videoInput];
        
        if ([_captureSession canAddInput:newVideoInput]) {
            [_captureSession addInput:newVideoInput];
            _videoInput = newVideoInput;
        } else {
            [_captureSession addInput:_videoInput];
        }

        [_captureSession commitConfiguration];
    }
    
    _inputCamera = backFacingCamera;
    
    AVCaptureConnection* connection = [_videoOutput connectionWithMediaType:AVMediaTypeVideo];
    
    if([connection isVideoMirroringSupported]) {
        [connection setVideoMirrored:(currentCameraPosition == AVCaptureDevicePositionFront)];
    }
    
    if([connection isVideoOrientationSupported]) {
        [connection setVideoOrientation:AVCaptureVideoOrientationLandscapeRight];
    }
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    if (!self.captureSession.isRunning)
    {
        return;
    }
    
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
            
    if (self.pixelFace) {
        [self filterBuffer:pixelBuffer];
    }
            
    if (self.delegate) {
        [self.delegate captureOutput:self pixelBuffer:pixelBuffer];
    }
}

- (CIImage*)compositeImage:(CIImage*)image withImage:(CIImage*)baseImage
{
    if (baseImage == nil)
        return image;
    
    CIFilter *filter = [CIFilter filterWithName:@"CIMaximumCompositing" keysAndValues:
                        kCIInputImageKey, image,
                        kCIInputBackgroundImageKey, baseImage,
                        nil];
    
    return filter.outputImage;
}

- (void)filterBuffer:(CVPixelBufferRef)pixelBuffer {
    
    CFDictionaryRef attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, pixelBuffer, kCMAttachmentMode_ShouldPropagate);
    CIImage *convertedImage = [[CIImage alloc] initWithCVPixelBuffer:pixelBuffer options:(__bridge NSDictionary *)attachments];
    
    if (attachments) {
        CFRelease(attachments);
    }
    
    const int di = 1; // For landscape depending on which camera: front=1, back=3, why? 2 works as good...
    
    NSDictionary *imageOptions = [NSDictionary dictionaryWithObject:@(di) forKey:CIDetectorImageOrientation];
    NSArray<CIFeature*> *features = [self.detector featuresInImage:convertedImage options:imageOptions];
    
    CIImage *maskImage = nil;
    
    for (CIFeature *feature in features) {

        CGRect r = [feature bounds];
        CIVector *center = [CIVector vectorWithX:(r.origin.x + r.size.width / 2.0) Y:(r.origin.y + r.size.height / 2.0)];
        
        CIFilter* radialGradient = [CIFilter filterWithName:@"CIRadialGradient"];
        [radialGradient setValue:center forKey:kCIInputCenterKey];
        [radialGradient setValue:@(r.size.width) forKey:@"inputRadius1"];
        
        maskImage = [self compositeImage:radialGradient.outputImage withImage:maskImage];
    }
    
    CVPixelBufferLockBaseAddress( pixelBuffer, 0 );
    
    CIFilter* pixelateFilter = [CIFilter filterWithName:@"CIPixellate"];
    [pixelateFilter setValue:convertedImage forKey:kCIInputImageKey];
    [pixelateFilter setValue:@(30) forKey:kCIInputScaleKey];
    
    CIFilter *maskFilter = [CIFilter filterWithName:@"CIBlendWithMask"];
    [maskFilter setValue:pixelateFilter.outputImage forKey:kCIInputImageKey];
    [maskFilter setValue:convertedImage forKey:kCIInputBackgroundImageKey];
    [maskFilter setValue:maskImage forKey:kCIInputMaskImageKey];
    
    // FIXME: composite over watermark, compositing with images does not seem to work
    
    //CIFilter *watermarkFilter = [CIFilter filterWithName: @"CISourceOverCompositing"];
    //[watermarkFilter setValue:convertedImage forKey:kCIInputBackgroundImageKey];
    //[watermarkFilter setValue:self.watermarkImage forKey:kCIInputImageKey];
    
    [_ciContext render:maskFilter.outputImage toCVPixelBuffer:pixelBuffer];

    CVPixelBufferUnlockBaseAddress( pixelBuffer, 0 );
}

#pragma mark Notification

- (void)willEnterBackground:(NSNotification *)notification {
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    [self.captureSession stopRunning];
}

- (void)willEnterForeground:(NSNotification *)notification {
    [self.captureSession startRunning];
    [UIApplication sharedApplication].idleTimerDisabled = YES;
}

@end
