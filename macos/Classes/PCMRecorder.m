//
//  PCMRecorder.m
//  pcm
//
//  Created by shingohu on 2024/1/18.
//

#import "PCMRecorder.h"
#import "Log.h"



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
        BOOL error = NO;
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
        [self printLog:@"开始录音"];
    }
    return YES;
}
- (void)stop{
    if(_remoteIOUnit!= nil){
        if(self.isRunning){
            AudioOutputUnitStop(_remoteIOUnit);
        }
        AudioUnitUninitialize(_remoteIOUnit);
        AudioComponentInstanceDispose(_remoteIOUnit);
        _remoteIOUnit = nil;
    }
    if(self.isRunning){
        self.isRunning = NO;
        self.audioCallBack(nil);
        [self printLog:@"结束录音"];
    }
}


-(void)printLog:(NSString*)log{
    [Log print:log];
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
        inputcd.componentSubType = kAudioUnitSubType_HALOutput;
    }else{
        inputcd.componentSubType = kAudioUnitSubType_HALOutput;
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
    
    
    
    UInt32 enableIO = 1;
    AudioUnitSetProperty(_remoteIOUnit,
                             kAudioOutputUnitProperty_EnableIO,
                             kAudioUnitScope_Input,
                             1,
                             &enableIO,
                             sizeof(enableIO));
    
    
    enableIO = 0;
    AudioUnitSetProperty(_remoteIOUnit,
                             kAudioOutputUnitProperty_EnableIO,
                             kAudioUnitScope_Output,
                             0,
                             &enableIO,
                             sizeof(enableIO));

    
    
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
    audioFormat.mReserved = 0;
    
    AudioUnitSetProperty(_remoteIOUnit,
                            kAudioUnitProperty_StreamFormat,
                            kAudioUnitScope_Output,
                            1,
                            &audioFormat,
                            sizeof(audioFormat));

   
  
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
    
    
    
    UInt32 preferredBufferSize = (( 20 * audioFormat.mSampleRate) / 1000); // in bytes
    UInt32   size = sizeof (preferredBufferSize);

       // Mac OS 设置
       AudioUnitSetProperty (_remoteIOUnit,
                                      kAudioDevicePropertyBufferFrameSize,
                                      kAudioUnitScope_Global,
                                      0,
                                      &preferredBufferSize,
                                      size);
       
       AudioUnitGetProperty (_remoteIOUnit,
                                      kAudioDevicePropertyBufferFrameSize,
                                      kAudioUnitScope_Global,
                                      0,
                                      &preferredBufferSize,
                                      &size);
    
    // 检查
    size = sizeof(audioFormat);
        AudioUnitGetProperty( _remoteIOUnit,
                                      kAudioUnitProperty_StreamFormat,
                                      kAudioUnitScope_Output,
                                      1,
                                      &audioFormat,
                                      &size);
    
    
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
