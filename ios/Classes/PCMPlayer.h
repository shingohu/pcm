//  Created by shingohu on 2024/1/19.
//  Copyright © 2024 胡杰. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>


NS_ASSUME_NONNULL_BEGIN

@class PCMPlayer;




@interface PCMPlayer : NSObject


@property (nonatomic, copy)   NSData* _Nullable (^audioCallBack)(NSInteger);

@property (nonatomic, assign) BOOL isRunning;

+ (instancetype)shared;


- (void)start:(double)sampleRate;
- (void)stop;


@end

NS_ASSUME_NONNULL_END
