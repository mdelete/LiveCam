//
//  LFLiveDebug.m
//  LaiFeng
//
//  Created by LaiFeng on 16/5/20.
//  Copyright © 2016年 LaiFeng All rights reserved.
//

#import "LFLiveDebug.h"

@implementation LFLiveDebug

- (NSString *)description {
    return [NSString stringWithFormat:@"Anzahl der verlorenen Frames:%ld Gesamtzahl der Frames:%ld Letzte Audioaufnahmen:%ld Letzte Videoaufnahmen:%ld Anzahl der nicht gesendeten:%ld Gesamtdurchfluss:%0.f",_dropFrame,_totalFrame,_currentCapturedAudioCount,_currentCapturedVideoCount,_unSendCount,_dataFlow];
}


@end
