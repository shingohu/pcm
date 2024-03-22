//
//  adpcm_decoder.m
//  pcm
//
//  Created by shingohu on 2024/1/19.
//

#import "adpcm_decoder.h"

#import "adpcm.h"

@implementation adpcmDecoder
{
    adpcm_state_t* decoder;
}

-(NSData*)start:(NSData*)adpcmData{
    
    
    if(decoder == nil){
        decoder = malloc(sizeof(adpcm_state_t));
    }
    
    return [self adpcm2pcm:adpcmData :decoder];
    
}


-(void)end{
    if(decoder){
        free(decoder);
        decoder = nil;
    }
}




-(NSData*)adpcm2pcm: (NSData*)adpmcData :(adpcm_state_t*)state{
    
    NSInteger adpcmLen = [adpmcData length];
    
    char *indata = (char*)adpmcData.bytes ;
    
    short pcmBuffer[adpcmLen*4];
    
    
    adpcm_decoder(indata, pcmBuffer, (int)(adpcmLen*2), state);
    
    NSData *pcmData = [NSData dataWithBytes:(char *)pcmBuffer length: adpcmLen*4];
    
    return pcmData;
}


@end
