//
//  PCMRecorderClient.swift
//  pcm
//
//  Created by shingohu on 2024/1/19.
//

import UIKit


typealias OnAudioCallback = (Data?)->Void

class PCMRecorderClient {
    
    
    
    static let shared = PCMRecorderClient()
    
    
    private init(){
        PCMRecorder.shared().audioCallBack = recordAudioCallBack;
    }
    
    
    
    ///需要读取的每帧大小
    private var PRE_FRAME_SIZE:Int = 160
    private var samplateRate:Int = 8000
    private var enableAEC:Bool = true
    public var isRecording = false
    
    ///音频缓冲
    private var audioBuffer:Data = Data.init();
    
    ///读取的下标
    private var readPCMDataIndex = 0
    
    private var onAudioCallback:OnAudioCallback?
    
    
    
    public func initRecorder(onAudioCallback:OnAudioCallback?){
        self.onAudioCallback = onAudioCallback
    }
    
    
    func setUp(samplateRate:Int,preFrameSize:Int,enableAEC:Bool)->Bool {
        if(!isRecording){
            self.PRE_FRAME_SIZE = preFrameSize
            self.samplateRate = samplateRate
            self.enableAEC = enableAEC
            return PCMRecorder.shared().setUp(Double(samplateRate),enableAEC: enableAEC)
        }
        return true
    }
    
    ///开始录制
    func start()->Bool {
        if(!isRecording){
            isRecording =  PCMRecorder.shared().start()
        }
        return isRecording
    }
    
    ///停止录制
    func stop() {
        if(isRecording){
            PCMRecorder.shared().stop()
            isRecording = false
            resetWhenStop()
        }
    }
    
    
    
    
    
    
    private func recordAudioCallBack(_ audioData: Data?)->Void {
        if(audioData != nil && isRecording){
            audioBuffer.append(audioData!)
            readNextPCMData()
        }
    }
        
    
    private func readNextPCMData(){
        
        let length = audioBuffer.count
        var readLength = 0 ;
        if(length - readPCMDataIndex >= PRE_FRAME_SIZE ){
            readLength = PRE_FRAME_SIZE;
        }
        if(readLength  != 0){
            let data =  audioBuffer.subdata(in: readPCMDataIndex..<(readPCMDataIndex+readLength))
            if(self.onAudioCallback != nil){
                self.onAudioCallback!(data)
            }
            readPCMDataIndex += readLength
            readNextPCMData()
        }
    }
    
    
    
    
    
    
    private func resetWhenStop(){
        ///结束录制
        self.readPCMDataIndex = 0
        self.audioBuffer.removeAll()
        self.isRecording = false
        if(self.onAudioCallback != nil){
            self.onAudioCallback!(nil)
        }
        
    }
    
    
    
}
