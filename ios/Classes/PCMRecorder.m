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
    AudioUnit _remoteIOUnit;
    AudioStreamBasicDescription _streamFormat;
    double sampleRate;
    bool enableAEC;
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


-(void)setUp:(double)sampleRate enableAEC:(BOOL)enableAEC{
    if(_remoteIOUnit != nil){
        if(self->sampleRate != sampleRate || self->enableAEC != enableAEC){
            [self stop];
        }
    }
    self->sampleRate = sampleRate;
    self->enableAEC = enableAEC;
    if(_remoteIOUnit == nil){
        [self setupRemoteIOUnit:sampleRate enableAEC:enableAEC];
    }
}



- (void)start{
    if(!self.isRunning){
        self.isRunning = YES;
        NSLog(@"开始录音");
       // long start = [self getNowDateFormatInteger];
        if(_remoteIOUnit == nil){
            [self setupRemoteIOUnit:sampleRate enableAEC:enableAEC];
        }
            //启用录音功能(提前设置这个会导致请求录音权限)
        UInt32 inputEnableFlag = 1;
        CheckError(AudioUnitSetProperty(_remoteIOUnit,
                                            kAudioOutputUnitProperty_EnableIO,
                                            kAudioUnitScope_Input,
                                            1,
                                            &inputEnableFlag,
                                            sizeof(inputEnableFlag)),
                       "Open input of bus 1 failed");
        CheckError(AudioUnitInitialize(_remoteIOUnit),"Recorder AudioUnitInitialize error");
        bool error = CheckError(AudioOutputUnitStart(_remoteIOUnit),"Recorder AudioOutputUnitStart error");
        self.isRunning = !error;
        if(!self.isRunning){
            NSLog(@"录音失败");
            [self stop];
        }else{
           // NSLog(@"开始录音耗时%ld",(long)([self getNowDateFormatInteger] - start));
        }
    }
}
- (void)stop{
    if(self.isRunning ||_remoteIOUnit!= nil){
        AudioUnitUninitialize(_remoteIOUnit);
        AudioOutputUnitStop(_remoteIOUnit);
        AudioComponentInstanceDispose(_remoteIOUnit);
        _remoteIOUnit = nil;
        self.isRunning = NO;
        self.audioCallBack(nil);
        NSLog(@"结束录音");
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




- (void)setupRemoteIOUnit:(double)sampleRate enableAEC:(BOOL)enableAEC{
    AudioComponentDescription inputcd = {0};
    inputcd.componentType = kAudioUnitType_Output;
    if(enableAEC){
        inputcd.componentSubType = kAudioUnitSubType_VoiceProcessingIO;
    }else{
        inputcd.componentSubType = kAudioUnitSubType_RemoteIO;
    }
    inputcd.componentManufacturer = kAudioUnitManufacturer_Apple;
    inputcd.componentFlagsMask = 0;
    inputcd.componentFlags = 0;

    
    AudioComponent inputComponent = AudioComponentFindNext(NULL, &inputcd);
     
    // 打开AudioUnit
    CheckError(AudioComponentInstanceNew(inputComponent, &_remoteIOUnit),"AudioComponentInstanceNew  failed");
    
    
//    Open output of bus 0(output speaker)
    //禁用播放功能
    UInt32 outputEnableFlag = 0;
    CheckError(AudioUnitSetProperty(_remoteIOUnit,
                                    kAudioOutputUnitProperty_EnableIO,
                                    kAudioUnitScope_Output,
                                    0,
                                    &outputEnableFlag,
                                    sizeof(outputEnableFlag)),
               "Open output of bus 0 failed");
    
    
    
    
    
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
    
    
    
   
  
    //音频采集结果回调
    AURenderCallbackStruct recordCallback;
    recordCallback.inputProc = _recordCallback;
    recordCallback.inputProcRefCon = (__bridge void *)(self);
    CheckError(AudioUnitSetProperty(_remoteIOUnit,
                                kAudioOutputUnitProperty_SetInputCallback,
                                    kAudioUnitScope_Output,
                                    1,
                                    &recordCallback,
                                    sizeof(recordCallback)),
               "couldnt set remote i/o render callback for output");
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


OSStatus _recordCallback(void *inRefCon,
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
    
    OSStatus status = AudioUnitRender(audioRecorder->_remoteIOUnit,
                    ioActionFlags,
                    inTimeStamp,
                    1,
                    inNumberFrames,
                    &bufferList);
    if(status == noErr){
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
