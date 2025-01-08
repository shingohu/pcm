//  Created by shingohu on 2024/1/19.
//  Copyright © 2024 胡杰. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>


NS_ASSUME_NONNULL_BEGIN

@class PCMPlayer;




@interface PCMPlayer : NSObject

@property (nonatomic, assign) BOOL isRunning;

- (void)setUp:(double)sampleRate;
- (void)start;
- (void)pause;
- (void)stop;

- (void)clear;
- (void)feed:(NSData*)data;


- (NSInteger)remainingFrames;


@end

NS_ASSUME_NONNULL_END
