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
    public var isRecording = false
    
    ///音频缓冲
    private var audioBuffer:Data = Data.init();
    
    ///读取的下标
    private var readPCMDataIndex = 0
    
    private var onAudioCallback:OnAudioCallback?
    
    
    
    public func initRecorder(onAudioCallback:OnAudioCallback?){
        self.onAudioCallback = onAudioCallback
        PCMRecorder.shared().setUp(Double(samplateRate))
    }
    
    
    func setUp(samplateRate:Int,preFrameSize:Int) {
        if(!isRecording){
            self.PRE_FRAME_SIZE = preFrameSize
            if(self.samplateRate != samplateRate){
                self.samplateRate = samplateRate
                PCMRecorder.shared().setUp(Double(samplateRate))
            }
        }
    }
    
    ///开始录制
    func start() {
        if(!isRecording){
            isRecording = true
            //self.startReadNexPCMDataRunner()
            PCMRecorder.shared().start()
        }
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
    
    private func startReadNexPCMDataRunner(){
        DispatchQueue.global(qos: .userInteractive ).async {
            self.readNextPCMDataInRunner()
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
    
    
    
    
    private func readNextPCMDataInRunner(){
        while self.isRecording {
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
            }else{
                ///这里不sleep下 在release模式下会卡住,不知道为什么
                Thread.sleep(forTimeInterval: 0.001)
            }
        }
        resetWhenStop()
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
