//
//  PCMRecorder.m
//  pcm
//
//  Created by shingohu on 2024/1/18.
//

#import "PCMPlayer.h"

#define kRate 8000 //采样率
#define kChannels   (1)//声道数
#define kBits       (16)//位数

@implementation PCMPlayer
{
    AUGraph _graph;
    AudioUnit _remoteIOUnit;
    AudioStreamBasicDescription _streamFormat;
    BOOL hasInitReomteIOUnit;
}

+ (instancetype)shared{

    static PCMPlayer *AudioPlayer = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        AudioPlayer = [[self alloc] init];
    });
    return AudioPlayer;
}
- (instancetype)init
{
    self = [super init];
    if (self) {
        [self setupRemoteIOUnit];
    }
    return self;
}


- (void)setUp:(double)sampleRate{
    [self setupRemoteIOUnit];
    [self setAudioFormat:sampleRate];
}


- (void)start{
    if(!self.isRunning){
        CheckError(AUGraphInitialize(_graph),"AUGraphInitialize failed");
        CheckError(AUGraphStart(_graph), "AUGraphStart failed");
        AudioOutputUnitStart(_remoteIOUnit);
        self.isRunning = YES;
      //  NSLog(@"开始播放耗时%ld",(long)([self getNowDateFormatInteger] - start));
    }
}



- (NSInteger)getNowDateFormatInteger{
    // 创建 NSDate 对象表示当前时间
    NSDate *date = [NSDate date];
     
    // 将 NSDate 对象转换成时间戳（单位为秒）
    NSTimeInterval timestampInSeconds = [date timeIntervalSince1970];
     
    // 将时间戳转换成毫秒
    double timestampInMilliseconds = timestampInSeconds * 1000;
     
    return  timestampInMilliseconds;
}


- (void)stop{
    if(self.isRunning){
        CheckError(AUGraphUninitialize(_graph), "AUGraphInitialize failed");
        CheckError(AUGraphStop(_graph), "AUGraphStop failed");
        AudioOutputUnitStop(_remoteIOUnit);
        self.isRunning = NO;
    }
}


- (void)setupRemoteIOUnit{
    if(hasInitReomteIOUnit){
        return;
    }
    hasInitReomteIOUnit = YES;
    //Create graph
    CheckError(NewAUGraph(&_graph),
               "NewAUGraph failed");
    
    //Create nodes and add to the graph
    AudioComponentDescription inputcd = {0};
    inputcd.componentType = kAudioUnitType_Output;
    inputcd.componentSubType = kAudioUnitSubType_VoiceProcessingIO;
    inputcd.componentManufacturer = kAudioUnitManufacturer_Apple;
    inputcd.componentFlagsMask = 0;
    inputcd.componentFlags = 0;
    AUNode remoteIONode;
    //Add node to the graph
    CheckError(AUGraphAddNode(_graph,
                              &inputcd,
                              &remoteIONode),
               "AUGraphAddNode failed");
    
    //Open the graph
    CheckError(AUGraphOpen(_graph),
               "AUGraphOpen failed");
    
    //Get reference to the node
    CheckError(AUGraphNodeInfo(_graph,
                               remoteIONode,
                               &inputcd,
                               &_remoteIOUnit),
               "AUGraphNodeInfo failed");
    
    
    
    ///0 开启回声消除 默认是开启,所以这里不要动就行了
    UInt32 echoCancellation = 0;
    UInt32 size = sizeof(echoCancellation);
    CheckError(AudioUnitSetProperty(_remoteIOUnit,
                                    kAUVoiceIOProperty_BypassVoiceProcessing,
                                    kAudioUnitScope_Input,
                                    0,
                                    &echoCancellation,
                                    size),
               "AudioUnitSetProperty kAUVoiceIOProperty_BypassVoiceProcessing failed");
    
    
    //禁用录音功能
    UInt32 inputEnableFlag = 0;
    CheckError(AudioUnitSetProperty(_remoteIOUnit,
                                    kAudioOutputUnitProperty_EnableIO,
                                    kAudioUnitScope_Input,
                                    1,
                                    &inputEnableFlag,
                                    sizeof(inputEnableFlag)),
               "Open input of bus 1 failed");
    
    
//    Open output of bus 0(output speaker)
    //启用播放功能
    UInt32 outputEnableFlag = 1;
    CheckError(AudioUnitSetProperty(_remoteIOUnit,
                                    kAudioOutputUnitProperty_EnableIO,
                                    kAudioUnitScope_Output,
                                    0,
                                    &outputEnableFlag,
                                    sizeof(outputEnableFlag)),
               "Open output of bus 0 failed");
   
  
    //音频播放回调
    AURenderCallbackStruct playCallback;
    playCallback.inputProc = _playCallback;
    playCallback.inputProcRefCon = (__bridge void *)(self);
    CheckError(AudioUnitSetProperty(_remoteIOUnit,
                                    kAudioUnitProperty_SetRenderCallback,
                                    kAudioUnitScope_Input,
                                    0,
                                    &playCallback,
                                    sizeof(playCallback)),
               "kAudioUnitProperty_SetRenderCallback failed");
    
}




-(void)setAudioFormat:(double)sampleRate{
    
    
    
   
    
    //Set up stream format for input and output
    _streamFormat.mFormatID = kAudioFormatLinearPCM;
    _streamFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    _streamFormat.mSampleRate = sampleRate;
    _streamFormat.mFramesPerPacket = 1;
    _streamFormat.mBytesPerFrame = 2;
    _streamFormat.mBytesPerPacket = 2;
    _streamFormat.mBitsPerChannel = kBits;
    _streamFormat.mChannelsPerFrame = kChannels;
    
    CheckError(AudioUnitSetProperty(_remoteIOUnit,
                                    kAudioUnitProperty_StreamFormat,
                                    kAudioUnitScope_Input,
                                    0,
                                    &_streamFormat,
                                    sizeof(_streamFormat)),
               "kAudioUnitProperty_StreamFormat of bus 0 failed");
    CheckError(AudioUnitSetProperty(_remoteIOUnit,
                                    kAudioUnitProperty_StreamFormat,
                                    kAudioUnitScope_Output,
                                    1,
                                    &_streamFormat,
                                    sizeof(_streamFormat)),
               "kAudioUnitProperty_StreamFormat of bus 1 failed");
    
    
    
}


static bool CheckError(OSStatus error, const char *operation)
{
    if (error == noErr) return false;
    char errorString[20];
    // See if it appears to be a 4-char-code
    *(UInt32 *)(errorString + 1) = CFSwapInt32HostToBig(error);
    if (isprint(errorString[1]) && isprint(errorString[2]) &&
        isprint(errorString[3]) && isprint(errorString[4])) {
        errorString[0] = errorString[5] = '\'';
        errorString[6] = '\0';
    } else
        // No, format it as an integer
        sprintf(errorString, "%d", (int)error);
    fprintf(stderr, "Error: %s (%s)\n", operation, errorString);
    return true;
}



OSStatus _playCallback(
                         void *inRefCon,
                         AudioUnitRenderActionFlags     *ioActionFlags,
                         const AudioTimeStamp         *inTimeStamp,
                         UInt32                         inBusNumber,
                         UInt32                         inNumberFrames,
                         AudioBufferList             *ioData)

{
    memset(ioData->mBuffers[0].mData, 0, ioData->mBuffers[0].mDataByteSize);
    PCMPlayer *player = (__bridge PCMPlayer*)inRefCon;
   // NSLog(@"播放回调%ld",(long)([player getNowDateFormatInteger] ));
    if (player.audioCallBack) {
        AudioBuffer buffer =  ioData->mBuffers[0];
        UInt32 len = buffer.mDataByteSize;
        NSData* data =  player.audioCallBack(len);
        if(data != nil && player.isRunning && data.length > 0){
            buffer.mDataByteSize = len;
            Byte *tempByte = (Byte *)[data bytes];
            memcpy(buffer.mData,tempByte,len);
          //  NSLog(@"读取长度%u",(unsigned int)len);
        }
    }
    return 0;
}
@end
