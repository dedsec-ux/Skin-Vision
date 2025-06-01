import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:get/get.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

class PermissionManager {
  // Check and request all required permissions
  static Future<void> checkAndRequestPermissions() async {
    print('PERMISSION DEBUG: Starting permission checks');
    // For Android 10+ (API level 29+), the storage permission model changed
    final androidSdkVersion = await _getAndroidSdkVersion();
    print('PERMISSION DEBUG: Android SDK Version: $androidSdkVersion');
    
    // Define required permissions based on Android version
    final permissionsToRequest = <Permission>[];
    
    // Notification permissions - always add to force requesting
    final notificationStatus = await Permission.notification.status;
    print('PERMISSION DEBUG: Notification permission status: $notificationStatus');
    permissionsToRequest.add(Permission.notification);
    
    // Storage/Gallery permissions based on Android version
    if (androidSdkVersion >= 29) {
      // Android 10+ uses more granular permissions
      if (await Permission.photos.status != PermissionStatus.granted) {
        permissionsToRequest.add(Permission.photos);
      }
      if (await Permission.videos.status != PermissionStatus.granted) {
        permissionsToRequest.add(Permission.videos);
      }
    } else {
      // Android 9 and below use storage permission
      if (await Permission.storage.status != PermissionStatus.granted) {
        permissionsToRequest.add(Permission.storage);
      }
    }
    
    // Request permissions if needed
    if (permissionsToRequest.isNotEmpty) {
      print('PERMISSION DEBUG: Requesting permissions: ${permissionsToRequest.map((p) => p.toString()).join(', ')}');
      await _requestPermissions(permissionsToRequest);
    } else {
      print('PERMISSION DEBUG: All required permissions already granted');
    }
    
    // Double-check notification permission specifically
    final finalNotificationStatus = await Permission.notification.status;
    print('PERMISSION DEBUG: Final notification permission status: $finalNotificationStatus');
  }
  
  // Request a list of permissions
  static Future<void> _requestPermissions(List<Permission> permissions) async {
    // Request all permissions at once
    final initialStatuses = await permissions.request();
    print('PERMISSION DEBUG: Initial permission request results:');
    initialStatuses.forEach((permission, status) {
      print('PERMISSION DEBUG: - $permission: $status');
    });
    
    // Request again to ensure dialog is shown
    final statuses = await permissions.request();
    print('PERMISSION DEBUG: Second permission request results:');
    statuses.forEach((permission, status) {
      print('PERMISSION DEBUG: - $permission: $status');
    });
    
    final permanentlyDeniedPermissions = <Permission>[];
    statuses.forEach((permission, status) {
      if (status == PermissionStatus.permanentlyDenied) {
        permanentlyDeniedPermissions.add(permission);
      }
    });
    
    if (permanentlyDeniedPermissions.isNotEmpty) {
      print('PERMISSION DEBUG: Some permissions permanently denied: ${permanentlyDeniedPermissions.map((p) => p.toString()).join(', ')}');
      _showAppSettingsDialog(permanentlyDeniedPermissions);
    }
  }
  
  // Dialog to guide users to app settings when permissions are permanently denied
  static void _showAppSettingsDialog(List<Permission> permissions) {
    final permissionNames = permissions.map(_getPermissionName).join(', ');
    
    Get.dialog(
      AlertDialog(
        title: Text('Permissions Required'),
        content: Text(
          'This app needs $permissionNames permissions to function properly. '
          'Please open the app settings and enable these permissions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              openAppSettings();
            },
            child: Text('Open Settings'),
          ),
        ],
      ),
    );
  }
  
  // Helper method to get human-readable permission names
  static String _getPermissionName(Permission permission) {
    switch (permission) {
      case Permission.notification:
        return 'Notification';
      case Permission.photos:
        return 'Photos';
      case Permission.videos:
        return 'Videos';
      case Permission.storage:
        return 'Storage';
      default:
        return permission.toString().split('.').last;
    }
  }
  
  // Helper method to get Android SDK version
  static Future<int> _getAndroidSdkVersion() async {
    try {
      if (Platform.isAndroid) {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        return androidInfo.version.sdkInt;
      }
      // Default to 29 (Android 10) if not Android
      return 29;
    } catch (e) {
      print('Error detecting Android SDK version: $e');
      // If we can't detect, assume Android 10+ to be safe
      return 29;
    }
  }
} 