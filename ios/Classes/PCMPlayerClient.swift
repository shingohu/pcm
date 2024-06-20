//
//  PCMPlayerClient.swift
//  pcm
//
//  Created by shingohu on 2024/1/19.
//

import Foundation


class PCMPlayerClient {
    
    static let shared = PCMPlayerClient()
    
    private init(){
       
    }
    
    
    private var _isPlaying = false
    
    
    
    ///音频缓冲
    private var audioBuffer:Data = Data.init()
    
    ///读取的下标
    private var readPCMDataIndex = 0
    
    private var samplateRate:Int = 8000
    
    public func initPlayer(){
        PCMPlayer.shared().audioCallBack = playAudioCallback;
        PCMPlayer.shared().setUp(Double(samplateRate))
    }
    
    public func setUp(samplateRate:Int){
        if(!isPlaying){
            if(self.samplateRate != samplateRate){
                self.samplateRate = samplateRate
                PCMPlayer.shared().setUp(Double(samplateRate))
            }
        }
    }
    
    
    
  
    func start() {
        if(!isPlaying){
            isPlaying = true
            PCMPlayer.shared().start()
        }
    }
    
    
    func stop(){
        if(isPlaying){
            isPlaying = false
            PCMPlayer.shared().stop()
            readPCMDataIndex = 0
            audioBuffer.removeAll()
        }
    }
    
    func play(audio:Data){
        if(!self.isPlaying){
            start()
        }
        if(self.isPlaying){
            audioBuffer.append(audio)
        }
    }
    
    
    ///是否正在播放
    var isPlaying: Bool {
        get {
            _isPlaying
        }
        set {
            _isPlaying = newValue
        }
    }
    
    public func unPlayLength()->Int{
        let count = audioBuffer.count
        return count - readPCMDataIndex;
    }
    

    
    public func playAudioCallback(length:Int)->Data?{
        let count = audioBuffer.count
        var readLength = 0 ;
        if(count - readPCMDataIndex >= length ){
            readLength = length;
        }
        if(readLength != 0){
            let data =  audioBuffer.subdata(in: readPCMDataIndex..<(readPCMDataIndex+readLength))
            readPCMDataIndex += readLength
            return data
        }else{
            ///没有就填充0(静音数据)
            ///带耳机会出现一卡一卡的
           // return Data(count: readLength)
        }
        return nil;
    }
    
    
}
