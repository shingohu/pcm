package com.lianke.audioswitch;

public class AudioDevice {
    ///设备名称
    public String name;
    ///设备类型
    public AudioDeviceType type;

    public AudioDevice(String name, AudioDeviceType type) {
        this.name = name;
        this.type = type;
    }


    @Override
    public int hashCode() {
        return (this.name + this.type.toString()).hashCode();
    }


}
