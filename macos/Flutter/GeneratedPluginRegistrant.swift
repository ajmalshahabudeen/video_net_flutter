//
//  Generated file. Do not edit.
//

import FlutterMacOS
import Foundation

import media_kit_video
import network_info_plus
import package_info_plus
import shared_preferences_foundation
import volume_controller
import wakelock_plus

func RegisterGeneratedPlugins(registry: FlutterPluginRegistry) {
  MediaKitVideoPlugin.register(with: registry.registrar(forPlugin: "MediaKitVideoPlugin"))
  NetworkInfoPlusPlugin.register(with: registry.registrar(forPlugin: "NetworkInfoPlusPlugin"))
  FPPPackageInfoPlusPlugin.register(with: registry.registrar(forPlugin: "FPPPackageInfoPlusPlugin"))
  SharedPreferencesPlugin.register(with: registry.registrar(forPlugin: "SharedPreferencesPlugin"))
  VolumeControllerPlugin.register(with: registry.registrar(forPlugin: "VolumeControllerPlugin"))
  WakelockPlusMacosPlugin.register(with: registry.registrar(forPlugin: "WakelockPlusMacosPlugin"))
}
