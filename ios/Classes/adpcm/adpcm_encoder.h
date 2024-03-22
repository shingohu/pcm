//
//  adpcm_encoder.h
//  pcm
//
//  Created by shingohu on 2024/1/19.
//

#import <Foundation/Foundation.h>




@class adpcmEncoder;

@interface adpcmEncoder : NSObject



-(NSData*)start:(NSData*)pcmData;

-(void)end;

@end

