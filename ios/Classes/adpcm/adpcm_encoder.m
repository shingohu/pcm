//
//  adpcm_encoder.m
//  pcm
//
//  Created by shingohu on 2024/1/19.
//

#import "adpcm_encoder.h"
#import "adpcm.h"

@implementation adpcmEncoder
{
    adpcm_state_t* encoder;
}






-(NSData*)start:(NSData*)pcmData{
    
    
    if(encoder == nil){
        encoder = malloc(sizeof(adpcm_state_t));
    }
    
    return [self pcm2Adpcm:pcmData :encoder];
    
}


-(void)end{
    if(encoder){
        free(encoder);
        encoder = nil;
    }
}


-(NSData*)pcm2Adpcm: (NSData*)pcmData :(adpcm_state_t*)state{
    
    NSInteger pcmLen = [pcmData length];
        
    char adpcmBuffer[pcmLen/4];
    short *recordingData = (short *)pcmData.bytes;
    adpcm_coder(recordingData, adpcmBuffer, (int)(pcmLen/2) , state);
    
    
    NSData *adpcmData = [NSData dataWithBytes:adpcmBuffer length: pcmLen/4];
    
    return adpcmData;
    
}






@end
