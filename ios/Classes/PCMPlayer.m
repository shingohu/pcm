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
    AudioUnit _remoteIOUnit;
    double sampleRate ;
    NSMutableData* mSamples;
    AVAudioSessionCategory category;
    
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
        self->sampleRate = kRate;
        self->mSamples = [NSMutableData new];
    }
    return self;
}


- (void)setUp:(double)sampleRate{
    if(_remoteIOUnit != nil){
        if(self->sampleRate != sampleRate){
            [self stop];
        }else if(self->category != [[AVAudioSession sharedInstance] category]){
            [self stop];
        }
    }
    if(_remoteIOUnit == nil){
        [self setupRemoteIOUnit:sampleRate];
    }
}


- (void)start{
    if(!self.isRunning){
        NSLog(@"开始播放");
        self.isRunning = YES;
       // long start = [self getNowDateFormatInteger];
        if(_remoteIOUnit == nil){
            [self setupRemoteIOUnit:sampleRate];
        }
        CheckError(AudioUnitInitialize(_remoteIOUnit),"Player AudioUnitInitialize error");
        bool error = CheckError(AudioOutputUnitStart(_remoteIOUnit), "Player AudioOutputUnitStart error");
        self.isRunning = !error;
        if(!self.isRunning){
            NSLog(@"播放失败");
            [self stop];
        }else{
           // NSLog(@"开始播放耗时%ld",(long)([self getNowDateFormatInteger] - start));
        }
    }
    
}

- (void)stop{
    
    if(self.isRunning || _remoteIOUnit != nil){
        AudioUnitUninitialize(_remoteIOUnit);
        CheckError(AudioOutputUnitStop(_remoteIOUnit),"Player AudioOutputUnitStop error");
        AudioComponentInstanceDispose(_remoteIOUnit);
        _remoteIOUnit = nil;
        self.isRunning = NO;
        NSLog(@"结束播放");
    }
    [self clear];
}


- (void)feed:(NSData *)data{
    @synchronized (self->mSamples) {
        [self->mSamples appendData:data];
    }
}

- (NSInteger)remainingFrames{
    
    NSUInteger count = 0;
    @synchronized (self ->mSamples) {
        count = [self->mSamples length];
    }
    return count;
}


-(void)clear{
    @synchronized (self->mSamples) {
        [self->mSamples setLength:0];
    }
}


- (void)setupRemoteIOUnit:(double)sampleRate{
    self->sampleRate = sampleRate;
    [[AVAudioSession sharedInstance] setPreferredSampleRate:sampleRate error:nil];
    
    
    OSType subType = kAudioUnitSubType_RemoteIO;
    
    
    BOOL enableAEC = NO;
    AVAudioSessionCategory category = [[AVAudioSession sharedInstance] category];
    if(category == AVAudioSessionCategoryPlayAndRecord){
        enableAEC = YES;
    }
    if(enableAEC){
        subType = kAudioUnitSubType_VoiceProcessingIO;
    }
    self->category = category;
    //Create nodes and add to the graph
    AudioComponentDescription inputcd = {0};
    inputcd.componentType = kAudioUnitType_Output;
    inputcd.componentSubType = subType;
    inputcd.componentManufacturer = kAudioUnitManufacturer_Apple;
    inputcd.componentFlagsMask = 0;
    inputcd.componentFlags = 0;
    
    
    AudioComponent inputComponent = AudioComponentFindNext(NULL, &inputcd);
    
    // 打开AudioUnit
    CheckError(AudioComponentInstanceNew(inputComponent, &_remoteIOUnit),"Audio Component Instance New Failed");
    
    
    
    AudioStreamBasicDescription audioFormat;
    
    //Set up stream format for input and output
    audioFormat.mFormatID = kAudioFormatLinearPCM;
    audioFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    audioFormat.mSampleRate = sampleRate;
    audioFormat.mFramesPerPacket = 1;
    audioFormat.mBytesPerFrame = 2;
    audioFormat.mBytesPerPacket = 2;
    audioFormat.mBitsPerChannel = kBits;
    audioFormat.mChannelsPerFrame = kChannels;
    
    
    CheckError(AudioUnitSetProperty(_remoteIOUnit,
                                    kAudioUnitProperty_StreamFormat,
                                    kAudioUnitScope_Input,
                                    0,
                                    &audioFormat,
                                    sizeof(audioFormat)),
               "kAudioUnitProperty_StreamFormat of bus 0 failed");
    
    CheckError(AudioUnitSetProperty(_remoteIOUnit,
                                    kAudioUnitProperty_StreamFormat,
                                    kAudioUnitScope_Output,
                                    1,
                                    &audioFormat,
                                    sizeof(audioFormat)),
               "kAudioUnitProperty_StreamFormat of bus 1 failed");
    
    //禁用录音功能
    UInt32 inputEnableFlag = 0;
    CheckError(AudioUnitSetProperty(_remoteIOUnit,
                                    kAudioOutputUnitProperty_EnableIO,
                                    kAudioUnitScope_Input,
                                    1,
                                    &inputEnableFlag,
                                    sizeof(inputEnableFlag)),
               "Open input of bus 1 failed");
    
    
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





- (NSInteger)getNowDateFormatInteger{
    // 创建 NSDate 对象表示当前时间
    NSDate *date = [NSDate date];
    
    // 将 NSDate 对象转换成时间戳（单位为秒）
    NSTimeInterval timestampInSeconds = [date timeIntervalSince1970];
    
    // 将时间戳转换成毫秒
    double timestampInMilliseconds = timestampInSeconds * 1000;
    
    return  timestampInMilliseconds;
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
    
    
    PCMPlayer *player = (__bridge PCMPlayer*)inRefCon;
    @synchronized (player->mSamples) {
        NSUInteger bytesToCopy = MIN(ioData->mBuffers[0].mDataByteSize, [player->mSamples length]);
        if(bytesToCopy>0){
            // provide samples
            memcpy(ioData->mBuffers[0].mData, [player->mSamples bytes], bytesToCopy);
            // pop front bytes
            NSRange range = NSMakeRange(0, bytesToCopy);
            [player->mSamples replaceBytesInRange:range withBytes:NULL length:0];
        }else{
            memset(ioData->mBuffers[0].mData, 0, ioData->mBuffers[0].mDataByteSize);
        }
        
    }
    return 0;
}
@end
