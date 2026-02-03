import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum ApkInstallResultType { done, error, fileNotFound }

class ApkInstallResult {
  final ApkInstallResultType type;
  final String message;

  ApkInstallResult({required this.type, required this.message});

  factory ApkInstallResult.fromMap(Map<dynamic, dynamic> map) {
    final typeStr = map['type'] as String?;
    ApkInstallResultType type;
    switch (typeStr) {
      case 'done':
        type = ApkInstallResultType.done;
        break;
      default:
        type = ApkInstallResultType.error;
    }
    return ApkInstallResult(
      type: type,
      message: map['message'] as String? ?? '',
    );
  }
}

class ApkInstaller {
  static const MethodChannel _channel = MethodChannel(
    'wtf.sono.app/apk_installer',
  );

  /// Opens the APK file for installation using Androids package installer
  ///
  /// Returns [ApkInstallResult] indicating success or failure
  /// Throws [PlatformException] if the native call fails

  static Future<ApkInstallResult> installApk(String filePath) async {
    if (!Platform.isAndroid) {
      return ApkInstallResult(
        type: ApkInstallResultType.error,
        message: 'APK installation is only supported on Android',
      );
    }

    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'installApk',
        {'filePath': filePath},
      );

      if (result != null) {
        return ApkInstallResult.fromMap(result);
      } else {
        return ApkInstallResult(
          type: ApkInstallResultType.error,
          message: 'Unknown error occurred',
        );
      }
    } on PlatformException catch (e) {
      debugPrint('ApkInstaller: PlatformException - ${e.code}: ${e.message}');

      if (e.code == 'FILE_NOT_FOUND') {
        return ApkInstallResult(
          type: ApkInstallResultType.fileNotFound,
          message: e.message ?? 'APK file not found',
        );
      }

      return ApkInstallResult(
        type: ApkInstallResultType.error,
        message: e.message ?? 'Installation failed',
      );
    } catch (e) {
      debugPrint('ApkInstaller: Unexpected error - $e');
      return ApkInstallResult(
        type: ApkInstallResultType.error,
        message: e.toString(),
      );
    }
  }
}
