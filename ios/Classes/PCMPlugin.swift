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
        
        PCMRecorderClient.shared.setOnAudioCallback(onAudioCallback: instance.recordAudioCallBack)
        PCMPlayerClient.shared.initPlayer()
        instance.registerAudioListener()
        //instance.initAudioSessionForFast()
    }
    
    
    
    
    ///加快初始化？不确定是否有效
    func initAudioSessionForFast(){
        do{
            if(PCMPlayerClient.shared.isPlaying || PCMRecorderClient.shared.isRecording){
                return
            }
            
            let session = AVAudioSession.sharedInstance()
            if(session.category == .playAndRecord){
                return;
            }
            try session.setCategory(.playAndRecord)
            try session.setMode(.voiceChat)
//            AVAudioSessionModeVoiceChat，主要用于执行双向语音通信VoIP场景。只能是 AVAudioSessionCategoryPlayAndRecord Category下。在这个模式系统会自动配置AVAudioSessionCategoryOptionAllowBluetooth 这个选项。系统会自动选择最佳的内置麦克风组合支持语音聊天，比如插上耳机就使用耳机上的麦克风进行采集。使用此模式时，该设备的音调君合针对语音进行了优化，并且允许路线组仅缩小为适用于语音聊天的路线。如果应用程序未将其模式设置为其中一个聊天模式（语音，视频或游戏），则AVAudioSessionModeVoiceChat模式将被隐式设置。另一方面，如果应用程序先前已将其类别设置为AVAudioSessionCategoryPlayAndRecord并将其模式设置为AVAudioSessionModeVideoChat或AVAudioSessionModeGameChat，则实例化语音处理I / O音频单元不会导致模式发生更改。
            try session.setCategory(.playback)
        }catch {
            print("设置音频模式为播放和录音模式失败")
            print(error)
        }
    }
    
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        
        let method = call.method
        
        
        if(method == "initRecorder"){
            result(true)
        }
        else if(method == "startRecording"){
            
            haseRecordPermission { allow in
                if(allow){
                    let sampleRateInHz:Int =  (call.arguments as! Dictionary<String, Any>)["sampleRateInHz"] as! Int
                    let preFrameSize = (call.arguments as! Dictionary<String, Any>)["preFrameSize"]  as! Int
                    PCMRecorderClient.shared.setUp(preFrameSize: preFrameSize)
                    PCMRecorderClient.shared.start(samplateRate: Double(sampleRateInHz))
                    result(true)
                }else{
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
        }else if(method == "initPlayer"){
            result(true)
        }else if(method == "startPlaying"){
            let data = (call.arguments as! Dictionary<String, Any>)["data"]  as! FlutterStandardTypedData
            let sampleRateInHz:Int =  (call.arguments as! Dictionary<String, Any>)["sampleRateInHz"] as! Int
            PCMPlayerClient.shared.start(samplateRate: Double(sampleRateInHz))
            PCMPlayerClient.shared.play(audio: data.data)
            result(true)
        }else if(method == "isPlaying"){
            result(PCMPlayerClient.shared.isPlaying)
        }else if(method == "stopPlaying"){
            PCMPlayerClient.shared.stop()
            result(true)
        }else if(method == "unPlayLength"){
            result(PCMPlayerClient.shared.unPlayLength())
        }else if(method == "abandonAudioFocus"){
            DispatchQueue.global(qos: .userInitiated).async {
                self.abandonAudioFocus()
                // 回到主线程更新UI
                DispatchQueue.main.async{
                    result(true)
                }
            }
        } else if(method == "requestAudioFocus"){
            requestAudioFocus()
            result(true)
        }else if(method == "setPlayAndRecordSession"){
            let defaultToSpeaker:Bool =  (call.arguments as! Dictionary<String, Any>)["defaultToSpeaker"] as! Bool
            setPlayAndRecordSession(defaultToSpeaker: defaultToSpeaker)
            result(true)
        }else if(method == "setPlaybackSession"){
            setPlaybackSession()
            result(true)
        }else if(method == "setRecordSession"){
            setRecordSession()
            result(true)
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
            
        }
        
        else if("pcm2wav" == method){
            
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
    
    
    
    ///设置录音和播放模式
    func setPlayAndRecordSession(defaultToSpeaker:Bool){
        do{
            if(PCMPlayerClient.shared.isPlaying || PCMRecorderClient.shared.isRecording){
                return
            }
            
            let session = AVAudioSession.sharedInstance()
            if(session.category == .playAndRecord){
                try session.setActive(true);
                return;
            }
            if(defaultToSpeaker){
                try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth,.allowBluetoothA2DP,.defaultToSpeaker])
            }else{
                try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth,.allowBluetoothA2DP])
            }
            
//            AVAudioSessionModeVoiceChat，主要用于执行双向语音通信VoIP场景。只能是 AVAudioSessionCategoryPlayAndRecord Category下。在这个模式系统会自动配置AVAudioSessionCategoryOptionAllowBluetooth 这个选项。系统会自动选择最佳的内置麦克风组合支持语音聊天，比如插上耳机就使用耳机上的麦克风进行采集。使用此模式时，该设备的音调君合针对语音进行了优化，并且允许路线组仅缩小为适用于语音聊天的路线。如果应用程序未将其模式设置为其中一个聊天模式（语音，视频或游戏），则AVAudioSessionModeVoiceChat模式将被隐式设置。另一方面，如果应用程序先前已将其类别设置为AVAudioSessionCategoryPlayAndRecord并将其模式设置为AVAudioSessionModeVideoChat或AVAudioSessionModeGameChat，则实例化语音处理I / O音频单元不会导致模式发生更改。
            try session.setActive(true);
            print("设置音频为播放和录音模式")
          
        }catch {
            print("设置音频模式为播放和录音模式失败")
            print(error)
        }
    }
    
    
    
    ///设置播放模式
    func setPlaybackSession(){
        do{
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback)
            try session.setActive(true);
            print("设置音频为播放模式")
        }catch {
            print("设置音频为播放模式失败")
            print(error)
        }
    }
    
    
    
    ///设置录音模式
    func setRecordSession(){
        do{
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record,options: .allowBluetooth)
            try session.setActive(true);
            print("设置音频为录音模式")
        }catch {
            print("设置音频为录音模式失败")
            print(error)
        }
    }
    
    
    
    
    
    
    ///释放音频焦点
    func abandonAudioFocus(){
        do {
            if(PCMPlayerClient.shared.isPlaying || PCMRecorderClient.shared.isRecording){
                return ;
            }
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(false,options: .notifyOthersOnDeactivation)
            print("释放音频焦点")
        }catch {
            print("释放音频焦点报错")
            print(error)
        }
    }
    
    ///请求音频焦点
    func requestAudioFocus(){
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setActive(true)
            print("请求音频焦点")
        }catch {
            print("请求音频焦点报错")
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

