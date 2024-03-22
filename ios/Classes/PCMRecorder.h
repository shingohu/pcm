//  Created by shingohu on 2024/1/19.
//  Copyright © 2024 胡杰. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>

NS_ASSUME_NONNULL_BEGIN

@class PCMRecorder;




@interface PCMRecorder : NSObject


@property (nonatomic, copy)  void (^audioCallBack)( NSData* _Nullable );

@property (nonatomic, assign) BOOL isRunning;

+ (instancetype)shared;


- (void)start:(double)sampleRate;
- (void)stop;


@end

NS_ASSUME_NONNULL_END
