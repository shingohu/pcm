//
//  Log.m
//  pcm
//
//  Created by shingohu on 2025/1/8.
//

#import "Log.h"

@implementation Log

static int _enableLog = 1;

+(void)print:(NSString *)message{
    if(_enableLog == 1){
        NSLog(@"[PCM][%ld] %@",(long)[Log getNowDateFormatInteger],message);
    }
}

+(void)enableLog:(BOOL)enable{
    if(enable){
        _enableLog = 1;
    }else{
        _enableLog = 0;
    }
}



+ (NSInteger)getNowDateFormatInteger{
    // 创建 NSDate 对象表示当前时间
    NSDate *date = [NSDate date];
     
    // 将 NSDate 对象转换成时间戳（单位为秒）
    NSTimeInterval timestampInSeconds = [date timeIntervalSince1970];
     
    // 将时间戳转换成毫秒
    double timestampInMilliseconds = timestampInSeconds * 1000;
     
    return  timestampInMilliseconds;
}


@end
