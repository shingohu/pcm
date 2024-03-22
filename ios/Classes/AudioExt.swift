//
//  AudioExt.swift
//  pcm
//
//  Created by shingohu on 2024/3/21.
//

import Foundation


enum AudioDeviceType:Int{
    case SPEAKER = 0,EARPIECE,WIREDHEADSET,BLUETOOTHHEADSET,BLUETOOTHA2DP
    
}


class AudioDevice:NSObject{
    var name:String = "";
    var type:AudioDeviceType = AudioDeviceType.EARPIECE;
    
    
    func toDic() -> Dictionary<String, Any>{
        var typeString = "EARPIECE";
        if(type == AudioDeviceType.BLUETOOTHA2DP){
            typeString = "BLUETOOTHA2DP"
        }
        
        if(type == AudioDeviceType.SPEAKER){
            typeString = "SPEAKER"
        }
        
        if(type == AudioDeviceType.BLUETOOTHHEADSET){
            typeString = "BLUETOOTHHEADSET"
        }
        
        if(type == AudioDeviceType.EARPIECE){
            typeString = "EARPIECE"
        }
        
        if(type == AudioDeviceType.WIREDHEADSET){
            typeString = "WIREDHEADSET"
        }
        
        
        return ["name":name,"type":typeString]
    }
    
}


func EARPIECE() -> AudioDevice {
    let device = AudioDevice()
    device.name = "EARPIECE"
    device.type = AudioDeviceType.EARPIECE;
    
    
    return device
}


func SPEAKER() -> AudioDevice {
    let device = AudioDevice()
    device.name = "SPEAKER"
    device.type = AudioDeviceType.SPEAKER;
    
    
    return device
}

func WIREDHEADSET() -> AudioDevice {
    let device = AudioDevice()
    device.name = "WIREDHEADSET"
    device.type = AudioDeviceType.WIREDHEADSET;
    
    
    return device
}



func BLUETOOTHHEADSET(name:String) -> AudioDevice {
    let device = AudioDevice()
    device.name = name
    device.type = AudioDeviceType.BLUETOOTHHEADSET;
    
    
    return device
}



func BLUETOOTHA2DP(name:String) -> AudioDevice {
    let device = AudioDevice()
    device.name = name
    device.type = AudioDeviceType.BLUETOOTHA2DP;
    
    
    return device
}
