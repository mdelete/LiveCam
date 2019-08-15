//
//  LCSpinnerView.h
//  LiveCam
//
//  Created by Marc Delling on 13.08.19.
//  Copyright © 2019 Marc Delling. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface LCSpinnerView : UIView

@property (nonatomic, assign) CGFloat arcAngle;

@property (nonatomic, strong) UIColor* arcColor;

@property (atomic, assign) BOOL isSpinning;

@property (atomic, assign) BOOL isBlinking;

@end

NS_ASSUME_NONNULL_END
