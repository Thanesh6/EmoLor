import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/chat_message.dart';
import '../../services/media_download_service.dart';

/// UCD032 – Media Preview Screen
///
/// Full-screen preview for images and document details, with a
/// prominent "Save to Device" / "Download" action.
///
/// Supports:
/// • Pinch-to-zoom on images (via [InteractiveViewer]).
/// • Document metadata display (name, size, type).
/// • Download progress indicator.
/// • Alternative flows: permission denied, file unavailable.
class MediaPreviewScreen extends StatefulWidget {
  /// The chat message containing the media attachment.
  final ChatMessage message;

  const MediaPreviewScreen({super.key, required this.message});

  @override
  State<MediaPreviewScreen> createState() => _MediaPreviewScreenState();
}

class _MediaPreviewScreenState extends State<MediaPreviewScreen> {
  final MediaDownloadService _downloadService = MediaDownloadService();

  bool _isDownloading = false;
  double _progress = 0.0;

  bool get _isImage => widget.message.mediaType == 'image';

  // ── Download action (Main Flow) ───────────────────────────────────────

  Future<void> _download() async {
    if (_isDownloading) return;
    setState(() {
      _isDownloading = true;
      _progress = 0.0;
    });

    final result = await _downloadService.downloadMedia(
      url: widget.message.mediaUrl!,
      fileName: widget.message.fileName ?? 'emolor_media',
      isImage: _isImage,
      onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      },
    );

    if (!mounted) return;
    setState(() => _isDownloading = false);

    switch (result.status) {
      case DownloadStatus.success:
        // Step 6: "Download Complete" notification
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Download complete',
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
        break;

      case DownloadStatus.permissionDenied:
        // Alternative Flow – Permission Denied
        _showErrorSnackBar(
          'Permission required to save files.',
          actionLabel: 'Settings',
          onAction: _openAppSettings,
        );
        break;

      case DownloadStatus.fileUnavailable:
        // Alternative Flow – File Deleted / Expired
        _showErrorSnackBar('File is no longer available.');
        break;

      case DownloadStatus.error:
        _showErrorSnackBar(result.message ?? 'Download failed.');
        break;
    }
  }

  void _showErrorSnackBar(String text,
      {String? actionLabel, VoidCallback? onAction}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text, style: GoogleFonts.poppins(fontSize: 14)),
            ),
          ],
        ),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: actionLabel != null && onAction != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: Colors.white,
                onPressed: onAction,
              )
            : null,
      ),
    );
  }

  Future<void> _openAppSettings() async {
    final uri = Uri.parse('app-settings:');
    try {
      await launchUrl(uri);
    } catch (_) {
      // Fallback: open permission_handler's built-in settings page
      // (handled by the OS-level app info screen via url_launcher)
    }
  }

  Future<void> _openInExternal() async {
    final uri = Uri.tryParse(widget.message.mediaUrl ?? '');
    if (uri != null) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Could not open file', style: GoogleFonts.poppins()),
            ),
          );
        }
      }
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isImage ? Colors.black : null,
      appBar: AppBar(
        backgroundColor: _isImage ? Colors.black : null,
        foregroundColor: _isImage ? Colors.white : null,
        title: Text(
          widget.message.fileName ?? (_isImage ? 'Photo' : 'Document'),
          style: GoogleFonts.poppins(fontSize: 16),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // Open in external app
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: 'Open in app',
            onPressed: _openInExternal,
          ),
          // Download / Save to device
          _isDownloading
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      value: _progress > 0 ? _progress : null,
                      strokeWidth: 2.5,
                      color: _isImage ? Colors.white : null,
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.download_rounded),
                  tooltip: 'Save to device',
                  onPressed: _download,
                ),
        ],
      ),
      body: _isImage ? _buildImagePreview() : _buildDocumentPreview(),

      // Floating download button at the bottom for easy access
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: _isDownloading
              ? _buildDownloadProgressBar()
              : ElevatedButton.icon(
                  onPressed: _download,
                  icon: const Icon(Icons.download_rounded, size: 22),
                  label: Text(
                    _isImage ? 'Save to Gallery' : 'Save to Downloads',
                    style: GoogleFonts.poppins(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6B21A8),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                  ),
                ),
        ),
      ),
    );
  }

  // ── Image Preview ─────────────────────────────────────────────────────

  Widget _buildImagePreview() {
    return Center(
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: Image.network(
          widget.message.mediaUrl!,
          fit: BoxFit.contain,
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: progress.expectedTotalBytes != null
                    ? progress.cumulativeBytesLoaded /
                        progress.expectedTotalBytes!
                    : null,
                strokeWidth: 2,
                color: Colors.white,
              ),
            );
          },
          errorBuilder: (_, __, ___) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.broken_image, size: 64, color: Colors.grey[500]),
              const SizedBox(height: 12),
              Text(
                'Image unavailable',
                style:
                    GoogleFonts.poppins(fontSize: 16, color: Colors.grey[400]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Document Preview ──────────────────────────────────────────────────

  Widget _buildDocumentPreview() {
    final fileName = widget.message.fileName ?? 'Document';
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toUpperCase()
        : 'FILE';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // File type icon
            Container(
              width: 100,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue[200]!, width: 1.5),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.insert_drive_file,
                      size: 48, color: Colors.blue[600]),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.blue[600],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      ext,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // File name
            Text(
              fileName,
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            // File size
            if (widget.message.fileSizeBytes != null)
              Text(
                _formatSize(widget.message.fileSizeBytes!),
                style:
                    GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
              ),
            const SizedBox(height: 6),
            // Sender info
            Text(
              'Shared by ${widget.message.senderName}',
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  // ── Download progress bar ─────────────────────────────────────────────

  Widget _buildDownloadProgressBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF6B21A8).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Color(0xFF6B21A8),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Downloading\u2026 ${(_progress * 100).toInt()}%',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6B21A8),
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _progress > 0 ? _progress : null,
                    backgroundColor: Colors.grey[200],
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Color(0xFF6B21A8)),
                    minHeight: 5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
