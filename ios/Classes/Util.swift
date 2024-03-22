//
//  Util.swift
//  pcm
//
//  Created by shingohu on 2024/1/19.
//

import Foundation

class Util {
    
    
    
    static func pcm2wav(inFileName: String, outFileName: String,sampleRate:Int) {
        
        do{
            guard let input: URL = URL(string: inFileName) else { return }
            guard let output: URL = URL(string: outFileName) else { return }
            
            var totalAudioLen: Int64
            var totalDataLen: Int64
            let longSampleRate: Int64 = Int64(sampleRate)
            
            let channels = 1
            let byteRate: Int64 = Int64(16 * sampleRate * channels / 8)
            
            totalAudioLen = Int64(inFileName.getFileSize())
            totalDataLen = totalAudioLen + 36
            
            writewaveFileHeader(output: output, totalAudioLen: totalAudioLen, totalDataLen: totalDataLen, longSampleRate: longSampleRate, channels: channels, byteRate: byteRate)
            
            let readHandler = try FileHandle(forReadingFrom: input)
            let writeHandler = try FileHandle(forWritingTo: output)
            
            // 文件头占44字节，偏移后才写入pcm数据
            writeHandler.seek(toFileOffset: 44)
            
            let data = readHandler.readDataToEndOfFile()
            
            writeHandler.write(data)
        } catch {
            print("pcm转wav失败: \(error)")
        }
    
    }
    
    private static func writewaveFileHeader(output: URL, totalAudioLen: Int64, totalDataLen: Int64, longSampleRate: Int64, channels: Int, byteRate: Int64) {
        var header: [UInt8] = Array(repeating: 0, count: 44)
        
        // RIFF/WAVE header
        header[0] = UInt8(ascii: "R")
        header[1] = UInt8(ascii: "I")
        header[2] = UInt8(ascii: "F")
        header[3] = UInt8(ascii: "F")
        header[4] = (UInt8)(totalDataLen & 0xff)
        header[5] = (UInt8)((totalDataLen >> 8) & 0xff)
        header[6] = (UInt8)((totalDataLen >> 16) & 0xff)
        header[7] = (UInt8)((totalDataLen >> 24) & 0xff)
        
        //WAVE
        header[8] = UInt8(ascii: "W")
        header[9] = UInt8(ascii: "A")
        header[10] = UInt8(ascii: "V")
        header[11] = UInt8(ascii: "E")
        
        // 'fmt' chunk
        header[12] = UInt8(ascii: "f")
        header[13] = UInt8(ascii: "m")
        header[14] = UInt8(ascii: "t")
        header[15] = UInt8(ascii: " ")
        
        // 4 bytes: size of 'fmt ' chunk
        header[16] = 16
        header[17] = 0
        header[18] = 0
        header[19] = 0
        
        // format = 1
        header[20] = 1
        header[21] = 0
        header[22] = UInt8(channels)
        header[23] = 0
        
        header[24] = (UInt8)(longSampleRate & 0xff)
        header[25] = (UInt8)((longSampleRate >> 8) & 0xff)
        header[26] = (UInt8)((longSampleRate >> 16) & 0xff)
        header[27] = (UInt8)((longSampleRate >> 24) & 0xff)
        
        header[28] = (UInt8)(byteRate & 0xff)
        header[29] = (UInt8)((byteRate >> 8) & 0xff)
        header[30] = (UInt8)((byteRate >> 16) & 0xff)
        header[31] = (UInt8)((byteRate >> 24) & 0xff)
        
        // block align
        header[32] = UInt8(2 * 16 / 8)
        header[33] = 0
        
        // bits per sample
        header[34] = 16
        header[35] = 0
        
        //data
        header[36] = UInt8(ascii: "d")
        header[37] = UInt8(ascii: "a")
        header[38] = UInt8(ascii: "t")
        header[39] = UInt8(ascii: "a")
        header[40] = UInt8(totalAudioLen & 0xff)
        header[41] = UInt8((totalAudioLen >> 8) & 0xff)
        header[42] = UInt8((totalAudioLen >> 16) & 0xff)
        header[43] = UInt8((totalAudioLen >> 24) & 0xff)
        
        guard let writeHandler = try? FileHandle(forWritingTo: output) else { return }
        let data = Data.init(bytes: header, count: header.count)
        writeHandler.write(data)
        
    }
    
    
    
    ///把adpcm 文件内容转成pcm
    static func adpcmFile2pcm(inFileName:String)->String?{
    
        do {
            guard let input: URL = URL(string: inFileName) else { return nil}
            let readHandler = try FileHandle(forReadingFrom: input)
            
            let adpcmData = readHandler.readDataToEndOfFile()
            
            let adpcm:adpcmDecoder = adpcmDecoder()
            
            let pcmData = adpcm.start(adpcmData)
            
            adpcm.end()
            try FileManager.default.removeItem(atPath: inFileName)
            FileManager.default.createFile(atPath: inFileName, contents: pcmData)
            return inFileName
        } catch {
            print("adpcm转pcm失败: \(error)")
        }
        return nil
    }
    
    
    
    
    
    
}

extension String {
    
    /// 计算文件夹大小(有单文件计算)
    func getFileSize() -> UInt64  {
        var size: UInt64 = 0
        let fileManager = FileManager.default
        var isDir: ObjCBool = false
        let isExists = fileManager.fileExists(atPath: self, isDirectory: &isDir)
        // 判断文件存在
        if isExists {
            // 是否为文件夹
            if isDir.boolValue {
                // 迭代器 存放文件夹下的所有文件名
                let enumerator = fileManager.enumerator(atPath: self)
                for subPath in enumerator! {
                    // 获得全路径
                    let fullPath = self.appending("/\(subPath)")
                    do {
                        let attr = try fileManager.attributesOfItem(atPath: fullPath)
                        size += attr[FileAttributeKey.size] as! UInt64
                    } catch  {
                        print("error :\(error)")
                    }
                }
            } else {    // 单文件
                do {
                    let attr = try fileManager.attributesOfItem(atPath: self)
                    size += attr[FileAttributeKey.size] as! UInt64
                    
                } catch  {
                    print("error :\(error)")
                }
            }
        }
        return size
    }
}

