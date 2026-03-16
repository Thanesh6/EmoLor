import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// UCD032 – Download Media Service
///
/// Securely downloads shared media files (images, documents) from
/// cloud storage to the user's local device for offline viewing.
///
/// Responsibilities:
/// • Check and request storage / photo-library permissions.
/// • Stream-download the file via [Dio].
/// • Save images to the device Gallery (via [Gal]).
/// • Save documents to the Downloads / app-documents folder.
/// • Report progress, success, and error states.

// ── Result types ────────────────────────────────────────────────────────

enum DownloadStatus { success, permissionDenied, fileUnavailable, error }

@immutable
class DownloadResult {
  final DownloadStatus status;
  final String? filePath;
  final String? message;

  const DownloadResult({
    required this.status,
    this.filePath,
    this.message,
  });

  bool get isSuccess => status == DownloadStatus.success;
}

// ── Service ─────────────────────────────────────────────────────────────

class MediaDownloadService {
  final Dio _dio = Dio();

  // ── Permission handling (Main Flow steps 2-3) ─────────────────────────

  /// Request the appropriate storage permission for the current platform.
  /// Returns `true` when the user has granted write access.
  Future<bool> requestStoragePermission({bool isImage = true}) async {
    if (kIsWeb) return true; // Web uses browser download – no permission needed

    if (Platform.isAndroid) {
      return _requestAndroidPermission(isImage: isImage);
    } else if (Platform.isIOS) {
      return _requestIOSPermission(isImage: isImage);
    }
    // Desktop – typically no runtime permission needed
    return true;
  }

  Future<bool> _requestAndroidPermission({required bool isImage}) async {
    // Android 13+ (API 33) uses granular media permissions
    if (await _isAndroid13OrAbove()) {
      if (isImage) {
        // For saving to gallery via Gal – photos permission
        final status = await Permission.photos.request();
        return status.isGranted || status.isLimited;
      }
      // Documents – no special permission on Android 13+
      return true;
    }
    // Android 10-12 – scoped storage, but WRITE_EXTERNAL_STORAGE still used
    // for some operations on API 29-32
    final status = await Permission.storage.request();
    return status.isGranted;
  }

  Future<bool> _requestIOSPermission({required bool isImage}) async {
    if (isImage) {
      // Photo library access for saving images
      final status = await Permission.photosAddOnly.request();
      return status.isGranted || status.isLimited;
    }
    // Documents – no special permission on iOS
    return true;
  }

  Future<bool> _isAndroid13OrAbove() async {
    if (!Platform.isAndroid) return false;
    // permission_handler uses the platform-specific SDK int check
    // On Android 13+ (SDK 33), Permission.photos is available
    return await Permission.photos.status !=
            PermissionStatus.permanentlyDenied ||
        await Permission.photos.status == PermissionStatus.denied ||
        await Permission.photos.status == PermissionStatus.granted;
  }

  // ── Download logic (Main Flow steps 4-6) ──────────────────────────────

  /// Download a media file from [url] and save it locally.
  ///
  /// [fileName] – the original file name (e.g., `report.pdf`).
  /// [isImage]  – whether the file is an image (saved to Gallery)
  ///              or a document (saved to Downloads).
  /// [onProgress] – optional callback reporting 0.0 → 1.0 progress.
  Future<DownloadResult> downloadMedia({
    required String url,
    required String fileName,
    bool isImage = false,
    void Function(double progress)? onProgress,
  }) async {
    // Step 2-3: Check / request permission
    final hasPermission = await requestStoragePermission(isImage: isImage);
    if (!hasPermission) {
      return const DownloadResult(
        status: DownloadStatus.permissionDenied,
        message: 'Permission required to save files.',
      );
    }

    try {
      // Step 4: Retrieve the secure file stream
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/$fileName';

      final response = await _dio.download(
        url,
        tempPath,
        onReceiveProgress: (received, total) {
          if (total > 0 && onProgress != null) {
            onProgress(received / total);
          }
        },
      );

      // Check if the download succeeded
      if (response.statusCode != 200) {
        return const DownloadResult(
          status: DownloadStatus.fileUnavailable,
          message: 'File is no longer available.',
        );
      }

      final tempFile = File(tempPath);
      if (!await tempFile.exists() || await tempFile.length() == 0) {
        return const DownloadResult(
          status: DownloadStatus.fileUnavailable,
          message: 'File is no longer available.',
        );
      }

      // Step 5: Save to Gallery (images) or Downloads (documents)
      String savedPath;
      if (isImage) {
        await Gal.putImage(tempPath, album: 'EmoLor');
        savedPath = tempPath;
      } else {
        savedPath = await _saveToDownloads(tempPath, fileName);
      }

      // Clean up temp file if it was copied elsewhere
      if (savedPath != tempPath && await tempFile.exists()) {
        await tempFile.delete();
      }

      // Step 6: Return success
      return DownloadResult(
        status: DownloadStatus.success,
        filePath: savedPath,
        message: 'Download complete',
      );
    } on DioException catch (e) {
      // Alternative Flow – File Deleted / Expired
      if (e.response?.statusCode == 404 || e.response?.statusCode == 410) {
        return const DownloadResult(
          status: DownloadStatus.fileUnavailable,
          message: 'File is no longer available.',
        );
      }
      return DownloadResult(
        status: DownloadStatus.error,
        message: 'Download failed: ${e.message}',
      );
    } catch (e) {
      return DownloadResult(
        status: DownloadStatus.error,
        message: 'Download failed: $e',
      );
    }
  }

  /// Save a downloaded file from temp to the app's documents / downloads folder.
  Future<String> _saveToDownloads(String tempPath, String fileName) async {
    Directory targetDir;

    if (Platform.isAndroid) {
      // Use the public Downloads directory on Android
      targetDir = Directory('/storage/emulated/0/Download');
      if (!await targetDir.exists()) {
        targetDir = await getApplicationDocumentsDirectory();
      }
    } else if (Platform.isIOS) {
      targetDir = await getApplicationDocumentsDirectory();
    } else {
      targetDir = await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
    }

    // Avoid name collisions by appending a timestamp
    final ext = fileName.contains('.') ? '.${fileName.split('.').last}' : '';
    final baseName = fileName.contains('.')
        ? fileName.substring(0, fileName.lastIndexOf('.'))
        : fileName;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final destPath = '${targetDir.path}/${baseName}_$timestamp$ext';

    await File(tempPath).copy(destPath);
    return destPath;
  }
}
