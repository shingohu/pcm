import Flutter
import UIKit
import AVFoundation
import CoreTelephony



public class PCMPlugin: NSObject, FlutterPlugin,FlutterStreamHandler,UIApplicationDelegate {
    
    
    private var pcmStreamSink: FlutterEventSink?
    
    private var audioManagerChannel:FlutterMethodChannel?
    
    private let delayedCancellable = DelayedCancellable()
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = PCMPlugin()
        
        let recorderChannel = FlutterMethodChannel(name: "pcm/recorder", binaryMessenger: registrar.messenger())
        
        let playerChannel = FlutterMethodChannel(name: "pcm/player", binaryMessenger: registrar.messenger())
        
        let pcmStreamChannel = FlutterEventChannel(name: "pcm/stream", binaryMessenger: registrar.messenger())
        
        
        instance.audioManagerChannel = FlutterMethodChannel(name: "pcm/audioManager", binaryMessenger: registrar.messenger())
        
        let utilChannel = FlutterMethodChannel(name: "pcm/util", binaryMessenger: registrar.messenger())
    
        pcmStreamChannel.setStreamHandler(instance)
        registrar.addMethodCallDelegate(instance, channel: recorderChannel)
        
        registrar.addMethodCallDelegate(instance, channel: playerChannel)
        
        registrar.addMethodCallDelegate(instance, channel: utilChannel)
        
        registrar.addMethodCallDelegate(instance, channel: instance.audioManagerChannel!)
        
        registrar.addApplicationDelegate(instance)
        
        PCMRecorderClient.shared.initRecorder(onAudioCallback: instance.recordAudioCallBack)
        
        PCMPlayerClient.shared.setOnPlayComplete {
            DispatchQueue.main.async{
                playerChannel.invokeMethod("onPlayComplete", arguments: nil);
            }
        }
        
        instance.registerAudioListener()
        
        
    }
    

    
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let method = call.method
        if(method == "startRecording"){
            haseRecordPermission { allow in
                if(allow){
                    let sampleRateInHz:Int =  (call.arguments as! Dictionary<String, Any>)["sampleRateInHz"] as! Int
                    let preFrameSize = (call.arguments as! Dictionary<String, Any>)["preFrameSize"]  as! Int
                    var enableAEC =  (call.arguments as! Dictionary<String, Any>)["enableAEC"]  as! Bool
                    
                    let session = AVAudioSession.sharedInstance()
                    if(session.category != .playAndRecord && session.category != .record){
                        do {
                            print("录音时没有设置录音模式,重新设置")
                            try session.setCategory(.playAndRecord,mode: .default, options: [.allowBluetooth,.allowBluetoothA2DP,.defaultToSpeaker])
                        }catch {
                            print(error)
                            print("设置音频录音和播放模式失败")
                            result(false)
                            return
                        }
                    }
                    
                    if(enableAEC && session.category == .record){
                        enableAEC = false
                    }
                    var success = PCMRecorderClient.shared.setUp(samplateRate: sampleRateInHz, preFrameSize: preFrameSize,enableAEC: enableAEC)
                    if(success){
                        success =  PCMRecorderClient.shared.start()
                    }
                    if(!success){
                        print("录音失败")
                    }
                    result(success)
                }else{
                    print("没有录音权限")
                    result(false)
                }
            }
        }else if(method == "stopRecording"){
            PCMRecorderClient.shared.stop()
            result(true)
        }else if(method == "isRecording"){
            result(PCMRecorderClient.shared.isRecording)
        }else if(method == "requestRecordPermission"){
            requestRecordPermission(result: result)
        }else if(method == "checkRecordPermission"){
            requestRecordPermission(result: result)
        }
        
        
        else if(method == "setUpPlayer"){
            let sampleRateInHz:Int =  (call.arguments as! Dictionary<String, Any>)["sampleRateInHz"] as! Int
            PCMPlayerClient.shared.setUp(samplateRate: sampleRateInHz)
            result(true)
        }

        else if(method == "startPlaying"){
            let data = (call.arguments as! Dictionary<String, Any>)["data"]  as! FlutterStandardTypedData
            let sampleRateInHz:Int =  (call.arguments as! Dictionary<String, Any>)["sampleRateInHz"] as! Int
            let session = AVAudioSession.sharedInstance()
            if(session.category == .record){
                print("当前为仅录音模式,不可进行播放")
                result(false)
                return
            }
            PCMPlayerClient.shared.setUp(samplateRate: sampleRateInHz)
            PCMPlayerClient.shared.feed(audio: data.data)
            result(true)
        }else if(method == "pausePlaying"){
            PCMPlayer.shared().pause()
            result(true)
        }   else if(method == "isPlaying"){
            result(PCMPlayerClient.shared.isPlaying)
        }else if(method == "stopPlaying"){
            PCMPlayerClient.shared.stop()
            result(true)
        }else if(method == "clearPlayer"){
            PCMPlayerClient.shared.clear()
            result(true)
        } else if(method == "remainingFrames"){
            result(PCMPlayerClient.shared.remainingFrames())
        }else if(method == "abandonAudioFocus"){
            self.abandonAudioFocus()
            result(true)
        } else if(method == "requestAudioFocus"){
            requestAudioFocus()
            result(true)
        }else if(method == "setCategory"){
            setCategory(args: (call.arguments as! Dictionary<String, Any>))
            result(true)
        }else if(method == "getCategory"){
            result(getCategory())
        }else if(method == "getCategoryOptions"){
            result(getCategoryOptions())
        }else if(method == "isTelephoneCalling"){
            result(self.isTelephoneCalling())
        }else if(method == "getAvailableAudioDevices"){
            result(self.getAvailableAudioDevices())
        }else if(method == "getCurrentAudioDevice"){
            result(self.getCurrentAudioDevice().toDic())
        }else if(method == "setCurrentAudioDevice"){
            let index = call.arguments as! Int;
            self.setCurrentAudioDevice(type: index)
            result(true)
        }else if("pcm2wav" == method){
            
            let sampleRateInHz:Int =  (call.arguments as! Dictionary<String, Any>)["sampleRateInHz"] as! Int
            
            let pcmPath:String =  (call.arguments as! Dictionary<String, Any>)["pcmPath"] as! String
            let wavPath:String =  (call.arguments as! Dictionary<String, Any>)["wavPath"] as! String
            
            
            DispatchQueue.global(qos: .userInitiated).async {
                Util.pcm2wav(inFileName: pcmPath, outFileName: wavPath, sampleRate: sampleRateInHz)
                // 回到主线程更新UI
                DispatchQueue.main.async{
                    result(true)
                }
            }
        }else if("adpcm2wav" == method){
            let sampleRateInHz:Int =  (call.arguments as! Dictionary<String, Any>)["sampleRateInHz"] as! Int
            let adpcmPath:String =  (call.arguments as! Dictionary<String, Any>)["adpcmPath"] as! String
            let wavPath:String =  (call.arguments as! Dictionary<String, Any>)["wavPath"] as! String
            
            
            DispatchQueue.global(qos: .userInitiated).async {
                let pcmPath:String? =  Util.adpcmFile2pcm(inFileName: adpcmPath)
                if(pcmPath != nil){
                    Util.pcm2wav(inFileName: pcmPath!, outFileName: wavPath, sampleRate: sampleRateInHz)
                    // 回到主线程更新UI
                    DispatchQueue.main.async{
                        result(true)
                    }
                }else{
                    // 回到主线程更新UI
                    DispatchQueue.main.async{
                        result(false)
                    }
                }
            }
        }
    }
    
    
    
    // Event Channel: On Stream Listen
    public func onListen(withArguments arguments: Any?,
                         eventSink: @escaping FlutterEventSink) -> FlutterError? {
        self.pcmStreamSink = eventSink
        return nil
    }
    
    // Event Channel: On Stream Cancelled
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.pcmStreamSink = nil
        return nil
    }
    
    
    
    func requestRecordPermission(result: @escaping FlutterResult){
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { allow in
                result(allow)
            }
        } else {
            let session = AVAudioSession.sharedInstance();
            session.requestRecordPermission { allow in
                result(allow)
            }
        }
        
    }
    
    
    func haseRecordPermission(_ response: @escaping (Bool) -> Void){
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { allow in
                response(allow)
            }
        } else {
            let session = AVAudioSession.sharedInstance();
            session.requestRecordPermission { allow in
                response(allow)
            }
        }
        
    }
    
    
    ///打开扬声器
    func openSpeaker(){
        ///这里异步执行,否则连续多切换几次,会导致音频延时严重,微信也有这个问题,目前无法解决
            do {
                if(!self.isSpeakerOn()){
                    let session = AVAudioSession.sharedInstance()
                    try session.overrideOutputAudioPort(AVAudioSession.PortOverride.speaker)
                }
            }catch {
                print(error)
                print("打开扬声器失败")
            }
        
    }
    
    

    ///设置音频输出回到默认设置
    func overrideOutputAudioPortNone(){
            do {
                let session = AVAudioSession.sharedInstance()
                try session.overrideOutputAudioPort(AVAudioSession.PortOverride.none)
            }catch {
                print("overrideOutputAudioPortNone失败")
                print(error)
            }
        
    }
    
    
    
    func setCategory(args:Dictionary<String,Any>){
        do{
            let category = indexToCategory(index: args["category"] as? Int)
            if(category == nil){
                print("category is not support")
                return
            }
            let modeIndex = args["mode"] as? Int
            var options = args["options"] as? UInt?
            if(options == nil){
                options = 0
            }
            let policyIndex = args["policy"] as? Int
            
            let mode:AVAudioSession.Mode = indexToMode(index: modeIndex)
            let policy:AVAudioSession.RouteSharingPolicy? = indexToPolicy(index: policyIndex)
            let session = AVAudioSession.sharedInstance()
            
            
            if(session.category == category && session.categoryOptions == AVAudioSession.CategoryOptions(rawValue: options! ?? 0) && session.mode == mode){
                return
            }

            if(policy == nil){
                try session.setCategory(category!, mode: mode, options: AVAudioSession.CategoryOptions(rawValue: options! ?? 0))
            }else {
                try session.setCategory(category!, mode: mode, policy: policy!, options: AVAudioSession.CategoryOptions(rawValue: options! ?? 0))
            }
            print("设置音频会话类型:\(category!)")
        }catch {
            print("setCategory error")
            print(error)
        }
    }
    
    func getCategory() ->Int{
        let session = AVAudioSession.sharedInstance()
        return categoryToFlutter(category: session.category)
    }
    
    
    func getCategoryOptions()->UInt{
        let session = AVAudioSession.sharedInstance()
        return session.categoryOptions.rawValue
    }
    
    
    
    
    func categoryToFlutter(category:AVAudioSession.Category) ->Int {
        if(category == .ambient){
            return 0
        }
        
        if(category == .soloAmbient){
            return 1
        }
        
        if(category == .playback){
            return 2
        }
        
        if(category == .record){
            return 3
        }
        
        if(category == .playAndRecord){
            return 4
        }
        return 5
    }
    
    
    
    ///释放音频焦点
    func abandonAudioFocus(){
        do {
            try AVAudioSession.sharedInstance().setActive(false,options: .notifyOthersOnDeactivation)
        }catch {
            print("释放音频焦点失败")
            print(error)
        }
    }
    
    ///请求音频焦点
    func requestAudioFocus(){
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setActive(true)
        }catch {
            print("请求音频焦点失败")
            print(error)
        }
    }

    func isSpeakerOn()->Bool{
        let session = AVAudioSession.sharedInstance()
        var speakerOn = false
        session.currentRoute.outputs.forEach { output in
            if(output.portType == .builtInSpeaker){
                speakerOn = true
            }
        }
        
        return speakerOn
    }
    
    func isBluetoothOn()->Bool{
        let session = AVAudioSession.sharedInstance()
        var isOn = false
        session.currentRoute.outputs.forEach { output in
            if(output.portType == .bluetoothHFP || output.portType == .bluetoothA2DP ){
                isOn = true
            }
        }
        
        return isOn
    }
    
    
    
    ///录音回调
    public func recordAudioCallBack(_ audioData: Data?)->Void {
        DispatchQueue.main.async {
            if(audioData != nil){
                if(self.pcmStreamSink != nil){
                    self.pcmStreamSink!(FlutterStandardTypedData.init(bytes: audioData!))
                }
            }else{
                if(self.pcmStreamSink != nil){
                    ///录音结束
                    self.pcmStreamSink!(nil)
                }
            }
        }
    }
    
    

    
    func registerAudioListener(){
        NotificationCenter.default.addObserver(self, selector: #selector(audioRouteChangeListener(_:)), name: AVAudioSession.routeChangeNotification, object: nil)
    }
    
    @objc func audioRouteChangeListener(_ notification:Notification) {
        delayedCancellable.cancel()
        delayedCancellable.execute(task: {
            self.notifyAudioDeviceInMainThread()
        }(), afterDelay: 0.1)
    }
    
    
    
    func notifyAudioDeviceInMainThread(){
        DispatchQueue.main.async{
            self.notifyCurrentAudioDeviceChanged();
            self.notifyAudioDeviceChanged();
        }
    }
  
    
    
    
    
    func isTelephoneCalling()->Bool{
        
        let callcenter = CTCallCenter()
        
        if(callcenter.currentCalls != nil){
            for call in callcenter.currentCalls! {
                if(call.callState != CTCallStateDisconnected){
                    return true
                }
            }
        }
        return false
        
    }
    
    
    func getAvailableAudioDevices() ->Array<Dictionary<String,Any>>{
        
        
        var audioDevices = Array<AudioDevice>()
        
        let audioSession = AVAudioSession.sharedInstance()
        var bluetoothHfp:AVAudioSessionPortDescription? ;
        
        if(audioSession.isInputAvailable){
            for port in audioSession.availableInputs! {
                if(port.portType == .bluetoothHFP){
                    bluetoothHfp = port;
                }
            }
        }
        if(bluetoothHfp != nil){
            audioDevices.append(BLUETOOTHHEADSET(name: bluetoothHfp!.portName))
        }
        
        for port in audioSession.currentRoute.outputs {
            if(port.portType == .headphones){
                audioDevices.append(WIREDHEADSET())
            }
            if(port.portType == .bluetoothA2DP){
                audioDevices.append(BLUETOOTHA2DP(name: port.portName))
            }
            if(port.portType == .bluetoothHFP){
                audioDevices.removeAll { device in
                    return device.type == AudioDeviceType.BLUETOOTHHEADSET || device.type == AudioDeviceType.BLUETOOTHA2DP
                }
                audioDevices.append(BLUETOOTHHEADSET(name: port.portName))
            }
        }
        return audioDevices.map { $0.toDic() }
    }
    
    
    
    ///获取当前的输出设备
    func getCurrentAudioDevice() ->AudioDevice{
        let audioSession = AVAudioSession.sharedInstance()
        
        for port in audioSession.currentRoute.outputs {
            if(port.portType == .headphones){
                return WIREDHEADSET()
            }
            if(port.portType == .bluetoothHFP){
                return BLUETOOTHHEADSET(name: port.portName)
            }
            if(port.portType == .bluetoothA2DP){
                return BLUETOOTHA2DP(name: port.portName)
            }
            if(port.portType == .builtInSpeaker){
                return SPEAKER()
            }
            if(port.portType == .builtInReceiver){
                return EARPIECE()
            }
        }
        
        return EARPIECE();
        
        
    }
    
    
    func setCurrentAudioDevice(type:Int){
        if(getCurrentAudioDevice().type.rawValue == type){
            return
        }
        if(type == AudioDeviceType.SPEAKER.rawValue){
            self.openSpeaker();
            
        }else if(type == AudioDeviceType.BLUETOOTHHEADSET.rawValue){
            self.overrideOutputAudioPortNone()
            if(getCurrentAudioDevice().type != AudioDeviceType.BLUETOOTHHEADSET){
                self.setCurrentAudioDeviceWithBluetoothHeadset()
            }
        }else if(type == AudioDeviceType.WIREDHEADSET.rawValue){
            self.overrideOutputAudioPortNone()
            if(getCurrentAudioDevice().type == AudioDeviceType.BLUETOOTHHEADSET){
                self.setBuildInMic()
            }
        }else{
            self.overrideOutputAudioPortNone()
            if(getCurrentAudioDevice().type == AudioDeviceType.SPEAKER){
                self.setBuildInReceiverOn()
            }
        }
        notifyAudioDeviceInMainThread()
    }
    
    
    ///设置输入输出设备为蓝牙耳机
    func setCurrentAudioDeviceWithBluetoothHeadset(){
        let audioSession = AVAudioSession.sharedInstance()
        do{
            for port in audioSession.availableInputs!{
                if(port.portType == .bluetoothHFP){
                    try audioSession.setPreferredInput(port);
                    return;
                }
            }}catch {
                print("设置输入为蓝牙耳机失败")
                print(error)
            }
    }
    
    ///设置输入设备为MIC
    func setBuildInMic(){
        let audioSession = AVAudioSession.sharedInstance()
        do{
            for port in audioSession.availableInputs!{
                if(port.portType == .builtInMic){
                    try audioSession.setPreferredInput(port);
                    return;
                }
            }}catch {
                print("设置输入为mic失败")
                print(error)
            }
    }

    ///使用听筒
    func setBuildInReceiverOn(){
            do {
                let session = AVAudioSession.sharedInstance()
                if(session.category == .playAndRecord){
                    try session.setCategory(session.category, mode: session.mode, options: [.allowBluetooth,.allowBluetoothA2DP])
                }else if(session.category == .playback){
                    try session.setCategory(session.category, mode: session.mode, options: [.allowBluetoothA2DP])
                }else if(session.category == .record){
                    try session.setCategory(session.category, mode: session.mode, options: [.allowBluetooth])
                }else{
                    try session.setCategory(session.category, mode: session.mode, options: [])
                }
            }catch {
                print(error)
            }
    }
    
    func notifyCurrentAudioDeviceChanged(){
        audioManagerChannel?.invokeMethod("onCurrentAudioDeviceChanged", arguments: self.getCurrentAudioDevice().toDic())
    }
    
    
    func notifyAudioDeviceChanged(){
        audioManagerChannel?.invokeMethod("onAudioDevicesChanged", arguments: self.getAvailableAudioDevices())
    }
    
    public func applicationDidBecomeActive(_ application: UIApplication) {
        notifyAudioDeviceChanged()
    }
    
    
    
    
    
    public func indexToCategory(index:Int?) -> AVAudioSession.Category?{
        if(index == 0){
            return AVAudioSession.Category.ambient;
        }
        
        if(index == 1){
            return AVAudioSession.Category.soloAmbient;
        }
        
        if(index == 2){
            return AVAudioSession.Category.playback;
        }
        
        if(index == 3){
            return AVAudioSession.Category.record;
        }
        
        if(index == 4){
            return AVAudioSession.Category.playAndRecord;
        }
        
        if(index == 5){
            return AVAudioSession.Category.multiRoute;
        }
    
        return nil
        
    }
    
    public func indexToMode(index:Int?)->AVAudioSession.Mode{
        if(index == 0){
            return AVAudioSession.Mode.default;
        }
        if(index == 1){
            return AVAudioSession.Mode.gameChat;
        }
        
        if(index == 2){
            return AVAudioSession.Mode.measurement;
        }
        
        if(index == 3){
            return AVAudioSession.Mode.moviePlayback;
        }
        
        if(index == 4){
            return AVAudioSession.Mode.spokenAudio;
        }
        
        if(index == 5){
            return AVAudioSession.Mode.videoChat;
        }
        if(index == 6){
            return AVAudioSession.Mode.videoRecording;
        }
        
        if(index == 7){
            return AVAudioSession.Mode.voiceChat;
        }
        
        if(index == 8){
            return AVAudioSession.Mode.voicePrompt;
        }
        
        return AVAudioSession.Mode.default;
        
        
    }
    
    public func indexToPolicy(index:Int?)->AVAudioSession.RouteSharingPolicy?{
        if(index==0){
            return AVAudioSession.RouteSharingPolicy.default;
        }
        
        if(index==1){
            return AVAudioSession.RouteSharingPolicy.longFormAudio;
        }
        
        if(index==2){
            if #available(iOS 13.0, *) {
                return AVAudioSession.RouteSharingPolicy.longFormVideo
            }
        }
        
        if(index==3){
            return AVAudioSession.RouteSharingPolicy.independent;
        }
        return nil
    }
    
   
    
}


class DelayedCancellable {
    private var workItem: DispatchWorkItem?
 
    func execute(task: @escaping @autoclosure () -> Void, afterDelay seconds: TimeInterval) {
        workItem?.cancel() // 取消之前的任务
 
        let newWorkItem = DispatchWorkItem(block: task)
        workItem = newWorkItem
 
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: newWorkItem)
    }
 
    func cancel() {
        workItem?.cancel()
    }
}

