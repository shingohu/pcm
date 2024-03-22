//
//  adpcm_decoder.h
//  pcm
//
//  Created by shingohu on 2024/1/19.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN


@class adpcmDecoder;


@interface adpcmDecoder : NSObject

-(NSData*)start:(NSData*)adpcmData;

-(void)end;

@end

NS_ASSUME_NONNULL_END
