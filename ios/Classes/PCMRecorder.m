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


-(BOOL)setUp:(double)sampleRate enableAEC:(BOOL)enableAEC{
    if(_remoteIOUnit != nil && (self->sampleRate != sampleRate || self->enableAEC != enableAEC)){
        [self stop];
    }
    self->sampleRate = sampleRate;
    self->enableAEC = enableAEC;
    if(_remoteIOUnit == nil){
        return [self setupRemoteIOUnit:sampleRate enableAEC:enableAEC];
    }
    return YES;
}



- (BOOL)start{
    if(!self.isRunning){
        
        [[AVAudioSession sharedInstance] setPreferredIOBufferDuration:0.01 error:nil];
        
        BOOL error = NO;
            //启用录音功能(提前设置这个会导致请求录音权限)
        UInt32 inputEnableFlag = 1;
        error = CheckError(AudioUnitSetProperty(_remoteIOUnit,
                                            kAudioOutputUnitProperty_EnableIO,
                                            kAudioUnitScope_Input,
                                            1,
                                            &inputEnableFlag,
                                            sizeof(inputEnableFlag)),
                       "Open input of bus 1 failed");
        if(error){
            return  NO;
        }
        error = CheckError(AudioUnitInitialize(_remoteIOUnit),"Recorder AudioUnitInitialize error");
        if(error){
            return  NO;
        }
        error = CheckError(AudioOutputUnitStart(_remoteIOUnit),"Recorder AudioOutputUnitStart error");
        if(error){
            [self stop];
            return  NO;
        }
        self.isRunning = YES;
    }
    return YES;
}
- (void)stop{
    if(_remoteIOUnit!= nil){
        if(self.isRunning){
            AudioOutputUnitStop(_remoteIOUnit);
        }
        AudioUnitUninitialize(_remoteIOUnit);
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            AudioComponentInstanceDispose(self->_remoteIOUnit);
            self->_remoteIOUnit = nil;
        });
    }
    if(self.isRunning){
        self.isRunning = NO;
        self.audioCallBack(nil);
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




- (BOOL)setupRemoteIOUnit:(double)sampleRate enableAEC:(BOOL)enableAEC{
    
    BOOL error = NO;
    
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
    error = CheckError(AudioComponentInstanceNew(inputComponent, &_remoteIOUnit),"AudioComponentInstanceNew  failed");
    if(error){
        return NO;
    }
    
    
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
     
    
    error = CheckError(AudioUnitSetProperty(_remoteIOUnit,
                                     kAudioUnitProperty_StreamFormat,
                                     kAudioUnitScope_Output,
                                     1,
                                     &audioFormat,
                                     sizeof(audioFormat)),
                "kAudioUnitProperty_StreamFormat of bus 1 failed");
    
    
    if(error){
        return NO;
    }
    
    
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
    //音频采集结果回调
    AURenderCallbackStruct recordCallback;
    recordCallback.inputProc = _recordCallback;
    recordCallback.inputProcRefCon = (__bridge void *)(self);
    error = CheckError(AudioUnitSetProperty(_remoteIOUnit,
                                kAudioOutputUnitProperty_SetInputCallback,
                                    kAudioUnitScope_Global,
                                    1,
                                    &recordCallback,
                                    sizeof(recordCallback)),
               "couldnt set remote i/o render callback for output");
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
            //NSLog(@"获取长度 %lu",(unsigned long)pcmBlock.length);
            audioRecorder.audioCallBack(pcmBlock);
        }
    }
    return status;
}

@end
