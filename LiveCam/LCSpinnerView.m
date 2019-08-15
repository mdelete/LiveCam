//
//  SpinnerView.m
//  LiveCam
//
//  Created by Marc Delling on 13.08.19.
//  Copyright © 2019 Marc Delling. All rights reserved.
//

#import "LCSpinnerView.h"

@implementation LCSpinnerView {
    CGFloat _arcAngle;
    BOOL _spinning;
    BOOL _blinking;
    UIColor* _arcColor;
    CAShapeLayer *_centerLayer, *_ringLayer;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _arcAngle = M_E;
        _arcColor = UIColor.blackColor;
        _centerLayer = [CAShapeLayer layer];
        _ringLayer = [CAShapeLayer layer];
        self.userInteractionEnabled = NO;
    }
    return self;
}

/**
 * Set between 0 and 2*M_PI
 * Don't use the extremes because either there will be no circle
 * or a full circle, either way you wouldn't see the animation
 */
- (void)setArcAngle:(CGFloat)angle {
    _arcAngle = angle;
    [self setNeedsLayout];
}

- (BOOL)isSpinning {
    return _spinning;
}

- (void)setIsSpinning:(BOOL)spinning {
    _spinning = spinning;
    _blinking = NO;
    [self.layer removeAllAnimations];
    [_ringLayer removeAllAnimations];
    if (spinning) {
        [self spin];
    }
    [self setNeedsLayout];
}

- (BOOL)isBlinking {
    return _blinking;
}

- (void)setIsBlinking:(BOOL)blinking {
    _blinking = blinking;
    [self.layer removeAllAnimations];
    [_ringLayer removeAllAnimations];
    if (blinking) {
        _spinning = NO;
        [self blink];
    }
    [self setNeedsLayout];
}

- (void)setArcColor:(UIColor *)color {
    _arcColor = color;
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGFloat radius = self.bounds.size.width;
    CGPoint center = CGPointMake(self.bounds.size.width / 2, self.bounds.size.height / 2);
    
    _centerLayer.fillColor = [_arcColor CGColor];
    _centerLayer.path = [[UIBezierPath bezierPathWithArcCenter:center radius:(radius-7) startAngle:0 endAngle:2*M_PI clockwise:YES] CGPath];
    
    [self.layer addSublayer:_centerLayer];
    
    if (_spinning == YES) {
        _ringLayer.fillColor = nil;
        _ringLayer.strokeColor = [_arcColor CGColor];
        _ringLayer.lineWidth = 6;
        _ringLayer.opacity = 0.85;
        _ringLayer.lineCap = kCALineCapRound;
        _ringLayer.path = [[UIBezierPath bezierPathWithArcCenter:center radius:self.bounds.size.width startAngle:0 endAngle:_arcAngle clockwise:YES] CGPath];
    } else {
        _ringLayer.fillColor = nil;
        _ringLayer.strokeColor = [UIColor.whiteColor CGColor];
        _ringLayer.lineWidth = 6;
        _ringLayer.opacity = 0.85;
        _ringLayer.lineCap = kCALineCapRound;
        _ringLayer.path = [[UIBezierPath bezierPathWithArcCenter:center radius:self.bounds.size.width startAngle:0 endAngle:(2*M_PI) clockwise:YES] CGPath];
    }
    
    [self.layer addSublayer:_ringLayer];

    // FIXME: It would be nice if the spinner would fade at the tail
    
//    CAGradientLayer *gradientLayer = [CAGradientLayer layer];
//
//    gradientLayer.frame = self.frame;
//    gradientLayer.colors = @[(__bridge id)[UIColor redColor].CGColor,(__bridge id)[UIColor blueColor].CGColor];
//    gradientLayer.startPoint = CGPointMake(0,0.5);
//    gradientLayer.endPoint = CGPointMake(1,0.5);
//    gradientLayer.mask = _ringLayer;
//
//    [self.layer addSublayer:gradientLayer];
}
- (void)blink
{
    static NSString *keyPath = @"opacity";
    CABasicAnimation *opacity = [CABasicAnimation animationWithKeyPath:keyPath];
    opacity.duration = 0.5;
    opacity.fromValue = @(0);
    opacity.toValue = @(1);
    opacity.repeatCount = INFINITY;
    opacity.autoreverses = YES;
    [_ringLayer addAnimation:opacity forKey:keyPath];
}

- (void)spin
{
    static NSString *keyPath = @"transform.rotation";
    CABasicAnimation *rotate = [CABasicAnimation animationWithKeyPath:keyPath];
    rotate.duration = 4;
    rotate.fromValue = @(0);
    rotate.toValue = @(2*M_PI);
    rotate.repeatCount = INFINITY;
    [self.layer addAnimation:rotate forKey:keyPath];
}

@end
