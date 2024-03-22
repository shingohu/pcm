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
    private var PRE_FRAME_SIZE:Int = 160;
    public var isRecording = false
    ///是否需要编码为Adpcm
    private var encodeToADPCM = false
    
    ///音频缓冲
    private var audioBuffer:Data = Data.init();
    
    ///读取的下标
    private var readPCMDataIndex = 0
    
    private var onAudioCallback:OnAudioCallback?
    

    
    
    
    func setUp(preFrameSize:Int) {
        if(!isRecording){
            self.PRE_FRAME_SIZE = preFrameSize
        }
    }
    
    
    func setOnAudioCallback(onAudioCallback:OnAudioCallback?){
        self.onAudioCallback = onAudioCallback
    }
    
    
    
    ///开始录制
    func start(samplateRate:Double) {
        if(!isRecording){
            isRecording = true
            PCMRecorder.shared().start(samplateRate)
            self.startReadNexPCMDataRunner()
        }
    }
    
    ///停止录制
    func stop() {
        if(isRecording){
            PCMRecorder.shared().stop()
            isRecording = false
        }
    }
    
    
    
    
    
    
    private func recordAudioCallBack(_ audioData: Data?)->Void {
        if(audioData != nil){
            audioBuffer.append(audioData!)
        }
    }
    
    private func startReadNexPCMDataRunner(){
        DispatchQueue.global(qos: .userInteractive ).async {
            self.readNextPCMData()
        }
    }
    
    
    private func readNextPCMData(){
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
