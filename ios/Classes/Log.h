//
//  Log.h
//  pcm
//
//  Created by shingohu on 2025/1/8.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Log : NSObject



+(void)print:(NSString*)message;

+(void)enableLog:(BOOL)enable;

@end

NS_ASSUME_NONNULL_END
