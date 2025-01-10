//
//  Generated file. Do not edit.
//

import FlutterMacOS
import Foundation

import audio_session
import pcm
import record_darwin

func RegisterGeneratedPlugins(registry: FlutterPluginRegistry) {
  AudioSessionPlugin.register(with: registry.registrar(forPlugin: "AudioSessionPlugin"))
  PCMPlugin.register(with: registry.registrar(forPlugin: "PCMPlugin"))
  RecordPlugin.register(with: registry.registrar(forPlugin: "RecordPlugin"))
}
