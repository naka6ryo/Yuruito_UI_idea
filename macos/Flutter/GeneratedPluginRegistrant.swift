//
//  Generated file. Do not edit.
//

import FlutterMacOS
import Foundation

import cloud_firestore
import firebase_auth
import firebase_core
import geolocator_apple // Koブランチの変更を維持
import path_provider_foundation

func RegisterGeneratedPlugins(registry: FlutterPluginRegistry) {
  FLTFirebaseFirestorePlugin.register(with: registry.registrar(forPlugin: "FLTFirebaseFirestorePlugin"))
  FLTFirebaseAuthPlugin.register(with: registry.registrar(forPlugin: "FLTFirebaseAuthPlugin"))
  FLTFirebaseCorePlugin.register(with: registry.registrar(forPlugin: "FLTFirebaseCorePlugin"))
  GeolocatorPlugin.register(with: registry.registrar(forPlugin: "GeolocatorPlugin")) // Koブランチの変更を維持
  PathProviderPlugin.register(with: registry.registrar(forPlugin: "PathProviderPlugin"))
}