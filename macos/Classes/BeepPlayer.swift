//
//  BeepPlayer.swift
//  pcm
//
//  Created by shingohu on 2025/1/9.
//

import FlutterMacOS
import AVFoundation


class BeepPlayer :NSObject, AVAudioPlayerDelegate{

    
    static let shared = BeepPlayer()
    
    
    private override init(){
        
    }
    
    private var  _registrar: FlutterPluginRegistrar?
    private var _audioPlayers: [String:AVAudioPlayer] = [:]
    
    public func setUp(register:FlutterPluginRegistrar){
        self._registrar = register
    }
    
    
    func load(filePath:String) ->Bool{
        
        if(_audioPlayers[filePath] != nil){
            return true
        }
        let assetKey: String = self._registrar!.lookupKey(forAsset: filePath)
    
    
        //https://github.com/flutter/flutter/issues/47681
        let flutterBundleId = "io.flutter.flutter.app"
        let flutterAssetsDirectory = "flutter_assets"
        guard let flutterBundle = Bundle(identifier: flutterBundleId) else {
            Log.print("Could not get Flutter App bundle with ID: \(flutterBundleId)")
            return false
        }
        guard
            let assetURL = flutterBundle.url(forResource: filePath, withExtension: nil, subdirectory: flutterAssetsDirectory)
        else {
            Log.print("Could not get resource URL! \(filePath)")
            return false
        }
        guard let audioPlayer: AVAudioPlayer = try? AVAudioPlayer(contentsOf: assetURL) else {
            Log.print("Failed to initialize AVAudioPlayer for \(filePath)")
            return false
        }        
        let isSuccess: Bool = audioPlayer.prepareToPlay()
        if(!isSuccess){
            Log.print("Failed to prepare AVAudioPlayer to play \(filePath)")
        }else{
            Log.print("Successfully prepared AVAudioPlayer to play \(filePath)")
        }
        audioPlayer.delegate = self
        self._audioPlayers[filePath] = audioPlayer
        return true
    }
    
    
    func play(filePath:String)->Bool{
        let player = _audioPlayers[filePath]
        
        if(player == nil){
            Log.print("\(filePath) has not been loaded")
            return false
        }
        player?.stop()
        player?.currentTime = 0
        player?.volume = 1
        return player!.play()
    }
    
    func stop(filePath:String){
        let player = _audioPlayers[filePath]
        if(player != nil){
            player?.stop()
        }
    }
    
    
   
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        
    }
       
       func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
           print(
               "Failed decoding \(String(describing: player.url?.path))\n" +
               "Error:\n" +
               String(describing: error)
           )
           
       }
    
    
}
