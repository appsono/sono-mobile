import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pub_semver/pub_semver.dart' as semver;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sono/services/utils/apk_installer.dart';
import 'package:sono/services/utils/env_config.dart';

class UpdateInfo {
  final String latestVersion;
  final int versionCode;
  final String? apkUrl;
  final String? releaseNotes;
  final String? sha256;
  final int? fileSize;
  final DateTime? publishedAt;
  final String channel;

  UpdateInfo({
    required this.latestVersion,
    required this.channel,
    this.versionCode = 0,
    this.apkUrl,
    this.releaseNotes,
    this.sha256,
    this.fileSize,
    this.publishedAt,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      latestVersion: json['version'] ?? '0.0.0',
      versionCode: json['version_code'] ?? 0,
      apkUrl: json['download_url'],
      releaseNotes: json['release_notes'],
      sha256: json['sha256'],
      fileSize: json['file_size'],
      publishedAt: json['published_at'] != null
          ? DateTime.tryParse(json['published_at'])
          : null,
      channel: json['channel'] ?? 'stable',
    );
  }
}

class UpdateService {
  String? _cachedChannel;
  static const String _lastUpdateTimestampKey = 'last_downloaded_update_timestamp';

  /// Gets the timestamp of the last successfully downloaded update
  Future<DateTime?> getLastDownloadedUpdateTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getString(_lastUpdateTimestampKey);
    if (timestamp != null) {
      return DateTime.tryParse(timestamp);
    }
    return null;
  }

  /// Saves the timestamp of a successfully downloaded update
  Future<void> saveLastDownloadedUpdateTimestamp(DateTime timestamp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastUpdateTimestampKey, timestamp.toIso8601String());
    debugPrint('UpdateService: Saved last downloaded update timestamp: $timestamp');
  }

  /// Checks if install packages permission is granted
  Future<bool> isInstallPermissionGranted() async {
    if (!Platform.isAndroid) return true;
    return await Permission.requestInstallPackages.isGranted;
  }

  /// Requests install packages permission and returns whether it was granted
  Future<bool> requestInstallPermission() async {
    if (!Platform.isAndroid) return true;
    final status = await Permission.requestInstallPackages.request();
    return status.isGranted;
  }

  /// Cleans up old Sono APK files from the temp directory
  Future<void> cleanupOldApks() async {
    try {
      final Directory tempDir = await getTemporaryDirectory();
      final List<FileSystemEntity> files = tempDir.listSync();

      for (final entity in files) {
        if (entity is File && entity.path.contains('sono-') && entity.path.endsWith('.apk')) {
          try {
            await entity.delete();
            debugPrint('UpdateService: Cleaned up old APK: ${entity.path}');
          } catch (e) {
            debugPrint('UpdateService: Failed to delete APK ${entity.path}: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('UpdateService: Error during APK cleanup: $e');
    }
  }

  Future<String> getAppChannel() async {
    if (_cachedChannel != null) return _cachedChannel!;

    final packageInfo = await PackageInfo.fromPlatform();
    final packageName = packageInfo.packageName;

    if (packageName.endsWith('.nightly')) {
      _cachedChannel = 'nightly';
    } else if (packageName.endsWith('.beta')) {
      _cachedChannel = 'beta';
    } else {
      _cachedChannel = 'stable';
    }

    debugPrint('UpdateService: Detected channel: $_cachedChannel (package: $packageName)');
    return _cachedChannel!;
  }

  Future<String> getCurrentAppVersion() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  Future<UpdateInfo?> getLatestReleaseInfo() async {
    try {
      final channel = await getAppChannel();
      final baseUrl = EnvConfig.updateApiUrl;
      final Uri url = Uri.parse('$baseUrl/api/v1/version/$channel');

      debugPrint('UpdateService: Fetching version info from $url');

      final response = await http
          .get(url, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return UpdateInfo.fromJson(data);
      } else if (response.statusCode == 404) {
        debugPrint('UpdateService: No version available for channel: $channel');
        return null;
      } else {
        debugPrint(
          'UpdateService: Failed to fetch version - Status: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('UpdateService: Error fetching latest release info: $e');
    }
    return null;
  }

  Future<int> getCurrentBuildNumber() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return int.tryParse(packageInfo.buildNumber) ?? 0;
  }

  Future<bool> isUpdateAvailable() async {
    final String currentVersionStr = await getCurrentAppVersion();
    final int currentBuildNumber = await getCurrentBuildNumber();
    final UpdateInfo? latestUpdate = await getLatestReleaseInfo();

    debugPrint(
      'UpdateService CHECK: Current app version string: "$currentVersionStr", build: $currentBuildNumber',
    );
    if (latestUpdate != null) {
      debugPrint(
        'UpdateService CHECK: Latest version from API: "${latestUpdate.latestVersion}"',
      );
      debugPrint(
        'UpdateService CHECK: Channel: "${latestUpdate.channel}"',
      );
      debugPrint(
        'UpdateService CHECK: APK URL present: ${latestUpdate.apkUrl != null}',
      );
      debugPrint(
        'UpdateService CHECK: API version_code: ${latestUpdate.versionCode}, published_at: ${latestUpdate.publishedAt}',
      );
    } else {
      debugPrint('UpdateService CHECK: latestUpdate object is null.');
    }

    if (latestUpdate == null || latestUpdate.apkUrl == null) {
      return false;
    }

    try {
      final semver.Version current = semver.Version.parse(currentVersionStr);
      final semver.Version latestFromApi = semver.Version.parse(
        latestUpdate.latestVersion,
      );

      final semver.Version latestNormalized = semver.Version(
        latestFromApi.major,
        latestFromApi.minor,
        latestFromApi.patch,
        pre:
            latestFromApi.preRelease.join('.').isEmpty
                ? null
                : latestFromApi.preRelease.join('.'),
        build: null,
      );

      debugPrint(
        'UpdateService PARSED: Current: ${current.toString()}, Latest from API (raw): ${latestFromApi.toString()}, Latest (normalized for compare): ${latestNormalized.toString()}',
      );

      final int versionComparison = latestNormalized.compareTo(current);

      //if API version is higher => update is available
      if (versionComparison > 0) {
        debugPrint('UpdateService COMPARISON: API version is higher - update available');
        return true;
      }

      //if API version is lower => no update
      if (versionComparison < 0) {
        debugPrint('UpdateService COMPARISON: Current version is higher - no update');
        return false;
      }

      //versions are equal(?) => check version_code (build number)
      debugPrint(
        'UpdateService COMPARISON: Versions equal, comparing build numbers: current=$currentBuildNumber, api=${latestUpdate.versionCode}',
      );

      if (latestUpdate.versionCode > currentBuildNumber) {
        debugPrint('UpdateService COMPARISON: API build number is higher - update available');
        return true;
      }

      if (latestUpdate.versionCode < currentBuildNumber) {
        debugPrint('UpdateService COMPARISON: Current build number is higher - no update');
        return false;
      }

      //build numbers are also equal(?) => check published_at against saved timestamp
      if (latestUpdate.publishedAt != null) {
        final lastDownloaded = await getLastDownloadedUpdateTimestamp();
        debugPrint(
          'UpdateService COMPARISON: Build numbers equal, comparing timestamps: api=${latestUpdate.publishedAt}, lastDownloaded=$lastDownloaded',
        );

        if (lastDownloaded == null) {
          //never downloaded an update before => this is a new install, no update needed
          debugPrint('UpdateService COMPARISON: No previous download recorded - no update');
          return false;
        }

        if (latestUpdate.publishedAt!.isAfter(lastDownloaded)) {
          debugPrint('UpdateService COMPARISON: API timestamp is newer than last download - update available');
          return true;
        }
      }

      debugPrint('UpdateService COMPARISON: No update available');
      return false;
    } catch (e) {
      debugPrint(
        'UpdateService ERROR: Error comparing versions ("$currentVersionStr" vs "${latestUpdate.latestVersion}"): $e',
      );
      return false;
    }
  }

  Future<void> downloadAndInstallUpdate(
    UpdateInfo updateInfo,
    Function(double progress) onProgress,
    Function(String message) onError,
    Function onSuccess,
  ) async {
    if (updateInfo.apkUrl == null) {
      onError("APK download URL is missing.");
      return;
    }

    if (!Platform.isAndroid) {
      onError("Auto-updates via APK are only supported on Android.");
      return;
    }

    var installPermissionStatus =
        await Permission.requestInstallPackages.status;
    if (!installPermissionStatus.isGranted) {
      installPermissionStatus =
          await Permission.requestInstallPackages.request();
      if (!installPermissionStatus.isGranted) {
        onError(
          "Permission to install packages was denied. Please enable it in app settings to receive updates.",
        );
        return;
      }
    }

    final Directory tempDir = await getTemporaryDirectory();
    final String filePath =
        '${tempDir.path}/sono-${updateInfo.channel}-v${updateInfo.latestVersion}.apk';

    try {
      debugPrint(
        "UpdateService: Downloading update from ${updateInfo.apkUrl} to $filePath",
      );
      onProgress(0.0);

      final client = http.Client();
      final request = http.Request('GET', Uri.parse(updateInfo.apkUrl!));
      final http.StreamedResponse response = await client.send(request);

      if (response.statusCode != 200) {
        client.close();
        throw Exception(
          'Download failed: ${response.statusCode} ${response.reasonPhrase}',
        );
      }

      final int? contentLength = response.contentLength ?? updateInfo.fileSize;
      List<int> bytes = [];
      int receivedBytes = 0;

      response.stream.listen(
        (List<int> newBytes) {
          bytes.addAll(newBytes);
          receivedBytes += newBytes.length;
          if (contentLength != null && contentLength > 0) {
            onProgress(receivedBytes / contentLength);
          }
        },
        onDone: () async {
          client.close();
          try {
            final File file = File(filePath);
            await file.writeAsBytes(bytes, flush: true);
            debugPrint("UpdateService: Download complete: $filePath");
            onProgress(1.0);

            debugPrint(
              "UpdateService: Attempting to open APK for installation...",
            );
            final ApkInstallResult result = await ApkInstaller.installApk(filePath);

            if (result.type == ApkInstallResultType.done) {
              //save the timestamp of this update so we dont prompt again for the same build
              if (updateInfo.publishedAt != null) {
                await saveLastDownloadedUpdateTimestamp(updateInfo.publishedAt!);
              } else {
                //if no published_at => save current time as fallback
                await saveLastDownloadedUpdateTimestamp(DateTime.now());
              }
              onSuccess();
            } else {
              debugPrint(
                "UpdateService: Failed to open APK - ${result.type}: ${result.message}",
              );
              onError(
                "Could not start installation: ${result.message}. You may need to find the file in: ${tempDir.path} and install it manually.",
              );
            }
          } catch (e) {
            onError("Error saving or opening downloaded APK: $e");
          }
        },
        onError: (e) {
          client.close();
          onError("Error during download stream: $e");
        },
        cancelOnError: true,
      );
    } catch (e) {
      onError("Failed to initiate download: $e");
    }
  }
}