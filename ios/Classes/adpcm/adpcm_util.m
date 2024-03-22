//
//  adpcm_util.m
//  audio_streamer
//
//  Created by shingohu on 2023/2/24.
//

#import "adpcm_util.h"
#import "adpcm.h"
@implementation AdpcmUtil


static adpcm_state_t* decoder;
static adpcm_state_t* encoder;


+(NSData*)startDecode:(NSData*)adpcmData{
    
    if(!decoder){
        decoder = malloc(sizeof(adpcm_state_t));
    }
    
    return [AdpcmUtil adpcm2pcm:adpcmData :decoder];
    
}


+(NSData*)startEncode:(NSData*)pcmData{
    
    if(!encoder){
        encoder = malloc(sizeof(adpcm_state_t));
    }
    
    return [AdpcmUtil pcm2Adpcm:pcmData :encoder];
    
}


+(void)endEncode{
    if(encoder){
        free(encoder);
        encoder = nil;
    }
}

+(void)endDeocde{
    if(decoder){
        free(decoder);
        decoder = nil;
    }
}







+(NSData*)adpcm2pcm: (NSData*)adpmcData :(adpcm_state_t*)state{
    
    NSInteger adpcmLen = [adpmcData length];
    
    char *indata = (char*)adpmcData.bytes ;
    
    short pcmBuffer[adpcmLen*4];
    
    
    adpcm_decoder(indata, pcmBuffer, (int)(adpcmLen*2), state);
    
    NSData *pcmData = [NSData dataWithBytes:(char *)pcmBuffer length: adpcmLen*4];
    
    return pcmData;
}



+(NSData*)pcm2Adpcm: (NSData*)pcmData :(adpcm_state_t*)state{
    
    NSInteger pcmLen = [pcmData length];
        
    char adpcmBuffer[pcmLen/4];
    short *recordingData = (short *)pcmData.bytes;
    adpcm_coder(recordingData, adpcmBuffer, (int)(pcmLen/2) , state);
    
    
    NSData *adpcmData = [NSData dataWithBytes:adpcmBuffer length: pcmLen/4];
    
    return adpcmData;
    
}


+(NSString*)savePCM:(NSData*)pcmData{
    NSString *pcmFile ;
    
    NSDate *date = [NSDate date];
    
    
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    pcmFile = [path stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.pcm", date]];
       
       
    if (![[NSFileManager defaultManager] fileExistsAtPath:pcmFile]) {
           [[NSFileManager defaultManager] createFileAtPath:pcmFile contents:[@"" dataUsingEncoding:NSASCIIStringEncoding] attributes:nil];
    }
       
    NSFileHandle *handle = [NSFileHandle fileHandleForUpdatingAtPath:pcmFile];
    [handle seekToEndOfFile];
    
    
    [handle writeData: pcmData];
    
    NSLog(@"PCM FILE PATH->%@",pcmFile);
    return pcmFile;
    
    
}




@end
