import FlutterMacOS
import AVFoundation
import Cocoa


public class PCMPlugin: NSObject, FlutterPlugin,FlutterStreamHandler {
    
    
    private var pcmStreamSink: FlutterEventSink?
    
    var players = [String: PCMPlayerClient]()
    
    

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = PCMPlugin()
        let pcmMethodChannel = FlutterMethodChannel(name: "com.lianke.pcm", binaryMessenger: registrar.messenger)
        let pcmStreamChannel = FlutterEventChannel(name: "com.lianke.pcm.stream", binaryMessenger: registrar.messenger)
        pcmStreamChannel.setStreamHandler(instance)
        registrar.addMethodCallDelegate(instance, channel: pcmMethodChannel)
        registrar.addApplicationDelegate(instance)
        PCMRecorderClient.shared.initRecorder(onAudioCallback: instance.recordAudioCallBack)
    }
    

    
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let method = call.method
        if(method == "startRecording"){
            haseRecordPermission { allow in
                if(allow){
                    let sampleRateInHz:Int =  (call.arguments as! Dictionary<String, Any>)["sampleRateInHz"] as! Int
                    let preFrameSize = (call.arguments as! Dictionary<String, Any>)["preFrameSize"]  as! Int
                    let enableAEC =  (call.arguments as! Dictionary<String, Any>)["enableAEC"]  as! Bool
                    var success = PCMRecorderClient.shared.setUp(samplateRate: sampleRateInHz, preFrameSize: preFrameSize,enableAEC: enableAEC)
                    if(success){
                        success =  PCMRecorderClient.shared.start()
                    }
                    if(!success){
                        self.printLog(message: "录音失败")
                    }
                    result(success)
                }else{
                    self.printLog(message: "没有录音权限")
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
        }else if(method == "enableLog"){
            Log.enable((call.arguments as! Dictionary<String, Any>)["enableLog"]  as! Bool)
            result(true)
        }
        
        else if(method == "setUpPlayer"){
            let sampleRateInHz:Int =  (call.arguments as! Dictionary<String, Any>)["sampleRateInHz"] as! Int
            let playerId =  (call.arguments as! Dictionary<String, Any>)["playerId"] as! String
            if(players[playerId] == nil){
                let player = PCMPlayerClient()
                player.setUp(samplateRate: sampleRateInHz)
                players[playerId] = player
                self.printLog(message: "\(playerId) PCMPlayer 初始化,采样率为\(sampleRateInHz)")
            }else{
                self.printLog(message: "\(playerId) PCMPlayer已经初始化")
            }
            result(true)
        }
        else if(method == "startPlaying"){
            let playerId =  (call.arguments as! Dictionary<String, Any>)["playerId"] as! String
            if(players[playerId] == nil){
                self.printLog(message: "\(playerId) PCMPlayer未初始化")
                result(false)
            }else{
                players[playerId]?.start()
                result(players[playerId]!.isPlaying)
            }
        }
        
        else if(method == "stopPlaying"){
            let playerId =  (call.arguments as! Dictionary<String, Any>)["playerId"] as! String
            if(players[playerId] == nil){
                self.printLog(message: "\(playerId) PCMPlayer未初始化")
                result(false)
            }else{
                players[playerId]?.stop()
                players.removeValue(forKey: playerId)
                result(true)
            }
        }
        
        else if(method == "pausePlaying"){
            let playerId =  (call.arguments as! Dictionary<String, Any>)["playerId"] as! String
            if(players[playerId] == nil){
                self.printLog(message: "\(playerId) PCMPlayer未初始化")
                result(false)
            }else{
                players[playerId]?.pause()
                result(true)
            }

        }
        
        else if(method == "clearPlaying"){
            let playerId =  (call.arguments as! Dictionary<String, Any>)["playerId"] as! String
            if(players[playerId] == nil){
                self.printLog(message: "\(playerId) PCMPlayer未初始化")
            }else{
                players[playerId]?.clear()
            }
            result(true)
            
        }
        
        else if(method == "isPlaying"){
            let playerId =  (call.arguments as! Dictionary<String, Any>)["playerId"] as! String
            if(players[playerId] == nil){
                self.printLog(message: "\(playerId) PCMPlayer未初始化")
                result(false)
            }else{
                result(players[playerId]!.isPlaying)
            }
        }
        
        else if(method == "remainingFrames"){
            let playerId =  (call.arguments as! Dictionary<String, Any>)["playerId"] as! String
            if(players[playerId] == nil){
                self.printLog(message: "\(playerId) PCMPlayer未初始化")
                result(0)
            }else{
                result(players[playerId]!.remainingFrames())
            }
        }
        
        else if(method == "feedPlaying"){
            let playerId =  (call.arguments as! Dictionary<String, Any>)["playerId"] as! String
            let data = (call.arguments as! Dictionary<String, Any>)["data"]  as! FlutterStandardTypedData
            if(players[playerId] == nil){
                self.printLog(message: "\(playerId) PCMPlayer未初始化")
            }else{
                players[playerId]?.feed(audio: data.data)
            }
            result(true)
        }
        
    }
    
    
    
    
    private func printLog(message:String){
        Log.print(message)
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
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            result(true)
          break
        case .notDetermined:
          AVCaptureDevice.requestAccess(for: .audio) { allowed in
            DispatchQueue.main.async {
                result(allowed)
            }
          }
          break
        default:
            result(false)
          break
        }
        
    }
    
    
    func haseRecordPermission(_ response: @escaping (Bool) -> Void){
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            response(true)
          break
        case .notDetermined:
          AVCaptureDevice.requestAccess(for: .audio) { allowed in
            DispatchQueue.main.async {
                response(allowed)
            }
          }
          break
        default:
            response(false)
          break
        }
        
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
    
    

   
    
}


