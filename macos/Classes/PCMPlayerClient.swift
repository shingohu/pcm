//
//  PCMPlayerClient.swift
//  pcm
//
//  Created by shingohu on 2024/1/19.
//

import Foundation


class PCMPlayerClient {
    
    let player = PCMPlayer()
    

    
    public func setUp(sampleRate:Int){
        player.setUp(Double(sampleRate));
    }
    
    
    func start() {
        player.start()
    }
    
    func pause(){
        player.pause()
    }
    
    
    func stop(){
        player.stop()
    }
    
    func clear(){
        player.clear()
    }
    
    func feed(audio:Data){
        if(audio.count > 0){
            player.feed(audio)
        }
    }
    ///是否正在播放
    var isPlaying: Bool {
        get {
            player.isRunning
        }
    }
    
    public func remainingFrames()->Int{
        return player.remainingFrames();
    }
    


    
}
