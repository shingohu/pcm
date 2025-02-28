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
    AudioUnit audioUnit;
    double sampleRate ;
    NSMutableData* mSamples;
    BOOL hasInitAudioUnit;
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
    if(audioUnit != nil && self->sampleRate != sampleRate){
        [self stop];
    }
    if(audioUnit == nil){
        [self setupRemoteIOUnit:sampleRate];
    }
}


- (void)start{
    if(!self.isRunning && audioUnit != nil){
        //NSUInteger start1 = [self getNowDateFormatInteger];
        [self audioUnitInitialize];
        //NSInteger start2 = [self getNowDateFormatInteger];
        bool error = CheckError(AudioOutputUnitStart(audioUnit), "Player AudioOutputUnitStart");
        //NSInteger start3 = [self getNowDateFormatInteger];
        //printf("播放开始1耗时%ld\n", (long)(start2 - start1));
        //printf("播放开始2耗时%ld\n", (long)(start3 - start2));
        if(!error){
            self.isRunning = YES;
        }
    }
}


-(void)audioUnitInitialize{
    if(!hasInitAudioUnit){
        ///初始化的时候会请求音频焦点的
        if(AudioUnitInitialize(audioUnit) == noErr){
            hasInitAudioUnit = YES;
        }else{
            hasInitAudioUnit = NO;
        }
    }
}

-(void)audioUnitUninitialize{
    AudioUnitUninitialize(audioUnit);
    hasInitAudioUnit = NO;
}



-(void)pause{
    if(self.isRunning){
        AudioOutputUnitStop(audioUnit);
        //[self audioUnitUninitialize];
        self.isRunning = NO;
    }
    [self clear];
}

- (void)stop{
    if(audioUnit != nil){
        [self pause];
        [self audioUnitUninitialize];
        AudioComponentInstanceDispose(self->audioUnit);
        self->audioUnit = nil;
    }
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
    //Create nodes and add to the graph
    AudioComponentDescription inputcd = {0};
    inputcd.componentType = kAudioUnitType_Output;
    inputcd.componentSubType = kAudioUnitSubType_RemoteIO;
    inputcd.componentManufacturer = kAudioUnitManufacturer_Apple;
    inputcd.componentFlagsMask = 0;
    inputcd.componentFlags = 0;
    
    
    AudioComponent inputComponent = AudioComponentFindNext(NULL, &inputcd);
    
    // 打开AudioUnit
    CheckError(AudioComponentInstanceNew(inputComponent, &audioUnit),"AudioComponentInstanceNew");
    
    
    
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
    
    
    CheckError(AudioUnitSetProperty(audioUnit,
                                    kAudioUnitProperty_StreamFormat,
                                    kAudioUnitScope_Input,
                                    0,
                                    &audioFormat,
                                    sizeof(audioFormat)),
               "SetOutputStreamFormat");
    
    //音频播放回调
    AURenderCallbackStruct playCallback;
    playCallback.inputProc = _playCallback;
    playCallback.inputProcRefCon = (__bridge void *)(self);
    CheckError(AudioUnitSetProperty(audioUnit,
                                    kAudioUnitProperty_SetRenderCallback,
                                    kAudioUnitScope_Input,
                                    0,
                                    &playCallback,
                                    sizeof(playCallback)),
               "SetOutputCallback");
    
    
    ///每次取10毫秒数据
    NSTimeInterval interval = sampleRate/(1000*8*100);
    [self setupBufferDuration:interval];
}




-(BOOL)setupBufferDuration:(NSTimeInterval)duration{
    [[AVAudioSession sharedInstance] setPreferredIOBufferDuration:duration error:nil];
    return YES;
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
        player.isRunning = YES;
        NSUInteger bytesToCopy = MIN(ioData->mBuffers[0].mDataByteSize, [player->mSamples length]);
        //NSLog(@"获取长度 %u",inNumberFrames * 2);
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
