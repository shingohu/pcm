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
    
    
    public func setOnPlayComplete(onPlayComplete:@escaping (()->Void)){
        PCMPlayer.shared().onPlayComplete = onPlayComplete
    }
    
    

    
    
    public func setUp(samplateRate:Int){
        PCMPlayer.shared().setUp(Double(samplateRate));
    }
    
    
    
  
    func start() {
        PCMPlayer.shared().start()
    }
    
    
    func stop(){
        PCMPlayer.shared().stop()
    }
    
  
    
    func clear(){
        PCMPlayer.shared().clear()
    }
    
    func feed(audio:Data){
        if(!self.isPlaying){
            start()
        }
        if(audio.count > 0){
            PCMPlayer.shared().feed(audio)
        }
    }
    
    
    ///是否正在播放
    var isPlaying: Bool {
        get {
            PCMPlayer.shared().isRunning
        }
    }
    
    public func remainingFrames()->Int{
       
        return PCMPlayer.shared().remainingFrames();
    }
    


    
}
