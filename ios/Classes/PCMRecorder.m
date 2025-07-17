//
//  PCMRecorder.m
//  pcm
//
//  Created by shingohu on 2024/1/18.
//

#import "PCMRecorder.h"



#define kRate 8000 //采样率
#define kChannels   (1)//声道数
#define kBits       (16)//位数


@implementation PCMRecorder
{
    AudioUnit audioUnit;
    double sampleRate;
    bool enableAEC;
    BOOL hasInitAudioUnit;
}

+ (instancetype)shared{

    static PCMRecorder *AudioRecord = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        AudioRecord = [[self alloc] init];
    });
    return AudioRecord;
}
- (instancetype)init
{
    self = [super init];
    if (self) {
        self->sampleRate = kRate;
        self->enableAEC = YES;
    }
    return self;
}


-(BOOL)setUp:(double)sampleRate enableAEC:(BOOL)enableAEC{
    if(audioUnit != nil && (self->sampleRate != sampleRate || self->enableAEC != enableAEC)){
        [self stop];
    }
    self->sampleRate = sampleRate;
    self->enableAEC = enableAEC;
    BOOL success =  [self setupRemoteIOUnit:sampleRate enableAEC:enableAEC];
    if(!success){
        if(audioUnit != nil){
            AudioComponentInstanceDispose(audioUnit);
            audioUnit = nil;
        }
    }
    return YES;
}



- (BOOL)start{
    if(!self.isRunning && audioUnit != nil){
        [self audioUnitInitialize];
        BOOL error = CheckError(AudioOutputUnitStart(audioUnit),"Recorder AudioOutputUnitStart");
        if(!error){
            self.isRunning = YES;
        }else{
            [self audioUnitUninitialize];
            if(audioUnit != nil){
                AudioComponentInstanceDispose(audioUnit);
                audioUnit = nil;
            }
            return NO;
        }
    }
    return  self.isRunning;
}

///销毁
- (void)stop{
    if(audioUnit != nil){
        if(self.isRunning) {
            AudioOutputUnitStop(audioUnit);
        }
        [self audioUnitUninitialize];
        self.isRunning = NO;
        self.audioCallBack(nil);
    }
    if(audioUnit != nil){
        AudioComponentInstanceDispose(self->audioUnit);
        self->audioUnit = nil;
    }
}

-(void)audioUnitInitialize{
    if(!hasInitAudioUnit){
        [self setupEnableInput];
        ///初始化的时候会请求音频焦点的
        hasInitAudioUnit =  !CheckError(AudioUnitInitialize(audioUnit),"Recorder AudioUnitInitialize");
    }
}

-(void)audioUnitUninitialize{
        AudioUnitUninitialize(audioUnit);
        hasInitAudioUnit = NO;
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




- (BOOL)setupRemoteIOUnit:(double)sampleRate enableAEC:(BOOL)enableAEC{
    if(audioUnit != nil){
        return YES;
    }
    if(![self setupAudioUnit:enableAEC]){
        return NO;
    }
    if(![self setupDisableOutput]){
        return NO;
    }
    if(![self setupStreamFormat:sampleRate]){
        return NO;
    }
    if(![self setupInputCallback]){
        return NO;
    }
    NSTimeInterval interval = sampleRate/(1000*8*100);
    [self setupBufferDuration:interval];
    return YES;
}


-(BOOL)setupBufferDuration:(NSTimeInterval)duration{
    [[AVAudioSession sharedInstance] setPreferredIOBufferDuration:duration error:nil];
    return YES;
}




-(BOOL)setupAudioUnit:(BOOL)enableAEC{
    // Describe audio component
    AudioComponentDescription desc;
    desc.componentType = kAudioUnitType_Output;
    if(enableAEC){
        desc.componentSubType = kAudioUnitSubType_VoiceProcessingIO;
    }else{
        desc.componentSubType = kAudioUnitSubType_RemoteIO;
    }
    desc.componentManufacturer = kAudioUnitManufacturer_Apple;
    desc.componentFlags = 0;
    desc.componentFlagsMask = 0;
    // Get component
    AudioComponent inputComponent = AudioComponentFindNext(NULL, &desc);
    if(inputComponent != NULL){
        // Get audio units
        BOOL error  = CheckError(AudioComponentInstanceNew(inputComponent, &audioUnit),"AudioComponentInstanceNew");
        if(error){
            return NO;
        }
    }
    return YES;
}


///启用输入(注意这个会请求mic权限)
-(BOOL)setupEnableInput{
    
    UInt32 enableIO = 1;
    BOOL error = NO;
    error = CheckError(AudioUnitSetProperty(audioUnit,
                         kAudioOutputUnitProperty_EnableIO,
                         kAudioUnitScope_Input,
                         1,   //output element
                         &enableIO,
                         sizeof(enableIO)),"enable input");
    if(error){
        return NO;
    }
    return YES;
}




///禁用播放
-(BOOL)setupDisableOutput{
    
    UInt32 enableIO = 0;
    BOOL error = NO;
    error = CheckError(AudioUnitSetProperty(audioUnit,
                         kAudioOutputUnitProperty_EnableIO,
                         kAudioUnitScope_Output,
                         0,   //output element
                         &enableIO,
                         sizeof(enableIO)),"disable output");
    if(error){
        return NO;
    }
    return YES;
}


///设置格式
-(BOOL)setupStreamFormat:(double)sampleRate{
    
    // Describe format
    AudioStreamBasicDescription audioFormat = {0};

    audioFormat.mSampleRate = sampleRate;
    audioFormat.mFormatID = kAudioFormatLinearPCM;
    audioFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked ;
    audioFormat.mChannelsPerFrame = 1;
    audioFormat.mFramesPerPacket = 1;
    audioFormat.mBitsPerChannel = 16;
    audioFormat.mBytesPerPacket = 2;
    audioFormat.mBytesPerFrame = 2;
    audioFormat.mReserved = 0;
    
    // Apply format
    BOOL error = CheckError(AudioUnitSetProperty(audioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Output,
                                  1,
                                  &audioFormat,
                                  sizeof(audioFormat)),"SetInputStreamFormat");
    if(error){
        return NO;
    }
    
    return YES;
    
    
    
}



///设置回调
-(BOOL)setupInputCallback{
    // Set input callback
    AURenderCallbackStruct callbackStruct;
    callbackStruct.inputProc = _inputCallback;
    callbackStruct.inputProcRefCon = (__bridge void *)(self);
    BOOL error = CheckError(AudioUnitSetProperty(audioUnit,
                                  kAudioOutputUnitProperty_SetInputCallback,
                                  kAudioUnitScope_Global,
                                  1,
                                  &callbackStruct,
                                  sizeof(callbackStruct)),"SetInputCallback");
    if(error){
        return NO;
    }
    return YES;
}




static bool CheckError(OSStatus error, const char *operation)
{
    if (error == noErr) return NO;
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
    return YES;
}


OSStatus _inputCallback(void *inRefCon,
                          AudioUnitRenderActionFlags *ioActionFlags,
                          const AudioTimeStamp *inTimeStamp,
                          UInt32 inBusNumber,
                          UInt32 inNumberFrames,
                          AudioBufferList *ioData){
    PCMRecorder *audioRecorder = (__bridge PCMRecorder*)inRefCon;
    
    AudioBufferList bufferList;
    bufferList.mNumberBuffers = 1;
    bufferList.mBuffers[0].mData = NULL;
    bufferList.mBuffers[0].mDataByteSize = 0;
    OSStatus status = AudioUnitRender(audioRecorder->audioUnit,
                    ioActionFlags,
                    inTimeStamp,
                    1,
                    inNumberFrames,
                    &bufferList);
    if(status == noErr){
        //NSLog(@"获取长度 %u",(unsigned int)(inNumberFrames*2));
        audioRecorder.isRunning  = YES;
        //将采集到的声音，进行回调
        if (audioRecorder.audioCallBack)
        {
            AudioBuffer buffer = bufferList.mBuffers[0];
            NSData *pcmBlock =[NSData dataWithBytes:buffer.mData length:buffer.mDataByteSize];
            audioRecorder.audioCallBack(pcmBlock);
        }
    }
    return status;
}

@end
