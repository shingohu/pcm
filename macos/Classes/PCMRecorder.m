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

#define kOutputBus 0
#define kInputBus 1
#define SampleRate 8000
#define numberOfChannel 1  // 1 is mono: 2 is stereo


@implementation PCMRecorder
{
    AudioUnit audioUnit;
    double sampleRate;
    bool enableAEC;
    int bufferSize;
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
    return success;
}



- (BOOL)start{
    if(!self.isRunning){
        BOOL error = NO;
        error = CheckError(AudioUnitInitialize(audioUnit),"Recorder AudioUnitInitialize error");
        if(error){
            return  NO;
        }
        error = CheckError(AudioOutputUnitStart(audioUnit),"Recorder AudioOutputUnitStart error");
        if(error){
            [self stop];
            return  NO;
        }
        self.isRunning = YES;
    }
    return YES;
}
- (void)stop{
    if(audioUnit != nil){
        if(self.isRunning){
            AudioOutputUnitStop(audioUnit);
            AudioUnitUninitialize(audioUnit);
        }
        AudioComponentInstanceDispose(audioUnit);
        audioUnit = nil;
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


-(BOOL)setupAudioUnit:(BOOL)enableAEC{
    // Describe audio component
    AudioComponentDescription desc;
    desc.componentType = kAudioUnitType_Output;
    if(enableAEC){
        desc.componentSubType = kAudioUnitSubType_VoiceProcessingIO;
    }else{
        desc.componentSubType = kAudioUnitSubType_HALOutput;
    }
    desc.componentManufacturer = kAudioUnitManufacturer_Apple;
    desc.componentFlags = 0;
    desc.componentFlagsMask = 0;
    
    
    // Get component
    AudioComponent inputComponent = AudioComponentFindNext(NULL, &desc);
    
    if(inputComponent != NULL){
        // Get audio units
        BOOL error  = CheckError(AudioComponentInstanceNew(inputComponent, &audioUnit),"AudioComponentInstanceNew Error");
        if(error){
            return NO;
        }
    }
    return YES;
}

-(BOOL)setupEnableIO{
    
    UInt32 enableIO;
    BOOL error = NO;
    
    //When using AudioUnitSetProperty the 4th parameter in the method
    //refer to an AudioUnitElement. When using an AudioOutputUnit
    //the input element will be '1' and the output element will be '0'.
    
    
    enableIO = 1;
    error = CheckError(AudioUnitSetProperty(audioUnit,
                         kAudioOutputUnitProperty_EnableIO,
                         kAudioUnitScope_Input,
                         1, // input element
                         &enableIO,
                         sizeof(enableIO)),"kAudioUnitScope_Input error");
    
    if(error){
        return NO;
    }
    
    enableIO = 0;
    error = CheckError(AudioUnitSetProperty(audioUnit,
                         kAudioOutputUnitProperty_EnableIO,
                         kAudioUnitScope_Output,
                         0,   //output element
                         &enableIO,
                         sizeof(enableIO)),"kAudioUnitScope_Output error");
    if(error){
        return NO;
    }
    
    
    return YES;
    
    
}



-(BOOL)setupMicInput{
    AudioObjectPropertyAddress addr;
    UInt32 size = sizeof(AudioDeviceID);
    AudioDeviceID deviceID = 0;
    
    addr.mSelector = kAudioHardwarePropertyDefaultInputDevice;
    addr.mScope = kAudioObjectPropertyScopeGlobal;
    addr.mElement = kAudioObjectPropertyElementMaster;

    BOOL error = CheckError(AudioObjectGetPropertyData(kAudioObjectSystemObject, &addr, 0, NULL, &size, &deviceID),"kAudioObjectSystemObject error");
    
    
    if (!error) {
        error = CheckError(AudioUnitSetProperty(audioUnit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0, &deviceID, size),"kAudioOutputUnitProperty_CurrentDevice error");
    }
    
    
    int m_valueCount = deviceID / sizeof(AudioValueRange) ;
    NSLog(@"Available %d Sample Rates\n",m_valueCount);
    
    NSLog(@"DeviceName: %@",[self deviceName:deviceID]);
    NSLog(@"BufferSize: %d",[self bufferSize:deviceID]);
    
    return YES;
}


#pragma mark - Helper Methods
-(NSString *)deviceName:(AudioDeviceID)devID
{
    // Check name
    AudioObjectPropertyAddress address;
    
    address.mSelector = kAudioObjectPropertyName;
    address.mScope = kAudioObjectPropertyScopeGlobal;
    address.mElement = kAudioObjectPropertyElementMaster;

    CFStringRef name;
    UInt32 stringsize = sizeof(CFStringRef);
    
    AudioObjectGetPropertyData(devID, &address, 0, nil, &stringsize, &name);
    
    return (__bridge NSString *)(name);
    
}

-(UInt32)bufferSize:(AudioDeviceID)devID
{
    // Check buffer size
    AudioObjectPropertyAddress address;
    
    address.mSelector = kAudioDevicePropertyBufferFrameSize;
    address.mScope = kAudioObjectPropertyScopeGlobal;
    address.mElement = kAudioObjectPropertyElementMaster;
    
    UInt32 buf = 0;
    UInt32 bufSize = sizeof(UInt32);
    
    AudioObjectGetPropertyData(devID, &address, 0, nil, &bufSize, &buf);
    
    return buf;
}


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
                                  sizeof(audioFormat)),"Input StreamFormat error");
    

    
//    error = CheckError(AudioUnitSetProperty(audioUnit,
//                                  kAudioUnitProperty_StreamFormat,
//                                  kAudioUnitScope_Input,
//                                  0,
//                                  &audioFormat,
//                                  sizeof(audioFormat)),"Output StreamFormat error");
//    
    if(error){
        return NO;
    }
    
    return YES;
    
    
    
}


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
                                  sizeof(callbackStruct)),"SetInputCallback error");
    if(error){
        return NO;
    }
    return YES;
}


-(BOOL)setupBufferFrameSize:(UInt32)bufferSize{
    
    UInt32 preferredBufferSize = (( 10 * sampleRate) / 1000); // in bytes
    int size = sizeof (preferredBufferSize);

    ///设置buffsize的时候，IOS和MAC系统不一样
    BOOL error = CheckError(AudioUnitSetProperty (audioUnit, kAudioDevicePropertyBufferFrameSize, kAudioUnitScope_Output, 1, &preferredBufferSize, size),"kAudioDevicePropertyBufferFrameSize error");
    
    return !error;
}


- (BOOL)setupRemoteIOUnit:(double)sampleRate enableAEC:(BOOL)enableAEC{
    
    if(audioUnit != nil){
        return YES;
    }
    
    
    if(![self setupAudioUnit:enableAEC]){
        return NO;
    }
    
    if(![self setupEnableIO]){
        return NO;
    }
    
    
    if(!enableAEC){
        if(![self setupMicInput]){
            return NO;
        }
    }
    
    if(![self setupStreamFormat:sampleRate]){
        return NO;
    }
    
    if(![self setupInputCallback]){
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
    bufferList.mBuffers[0].mDataByteSize = inNumberFrames*2;

    
    OSStatus status = AudioUnitRender(audioRecorder->audioUnit,
                    ioActionFlags,
                    inTimeStamp,
                    inBusNumber,
                    inNumberFrames,
                    &bufferList);
    if(status == noErr){
        //将采集到的声音，进行回调
        if (audioRecorder.audioCallBack)
        {
            AudioBuffer buffer = bufferList.mBuffers[0];
            NSData *pcmBlock =[NSData dataWithBytes:buffer.mData length:buffer.mDataByteSize];
            NSLog(@"获取长度 %lu",(unsigned long)pcmBlock.length);
            audioRecorder.audioCallBack(pcmBlock);
        }
    }
    return status;
}




@end
