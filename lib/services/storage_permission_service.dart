import 'package:flutter/services.dart';

class StoragePermissionService {
  static const MethodChannel _channel =
      MethodChannel('com.epilogue.read/storage_permission');

  /// Checks if the app has All Files Access on Android 11+
  static Future<bool> hasStoragePermission() async {
    try {
      final bool? granted = await _channel.invokeMethod<bool>('hasStoragePermission');
      return granted ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Launches the system settings screen for All Files Access
  static Future<bool> requestStoragePermission() async {
    try {
      final bool? launched = await _channel.invokeMethod<bool>('requestStoragePermission');
      return launched ?? false;
    } catch (_) {
      return false;
    }
  }
}
