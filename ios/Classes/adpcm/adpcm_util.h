//
//  adpcm_util.h
//  audio_streamer
//
//  Created by shingohu on 2023/2/24.
//

#import <Foundation/Foundation.h>
#import "adpcm.h"


@interface AdpcmUtil : NSObject



+(NSData*)adpcm2pcm: (NSData*)adpmcData :(adpcm_state_t*)state;


+(NSData*)pcm2Adpcm: (NSData*)pcmData :(adpcm_state_t*)state;


+(NSString*)savePCM:(NSData*)pcmData;



+(NSData*)startDecode:(NSData*)adpcmData;


+(NSData*)startEncode:(NSData*)pcmData;


+(void)endEncode;

+(void)endDeocde;



@end


