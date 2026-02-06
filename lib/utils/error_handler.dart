import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:sono/widgets/global/bottom_sheet.dart';

class ErrorHandler {
  static void showErrorSnackbar({
    required BuildContext context,
    required String message,
    required dynamic error,
    required StackTrace stackTrace,
  }) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.clearSnackBars();

    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(message, maxLines: 2, overflow: TextOverflow.ellipsis),
        backgroundColor: Colors.redAccent.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(10, 5, 10, 10),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: 'VIEW',
          textColor: Colors.white,
          onPressed: () {
            showErrorDetailsDialog(
              context: context,
              error: error,
              stackTrace: stackTrace,
              title: "An Error Occurred",
            );
          },
        ),
      ),
    );
  }

  static void showErrorDetailsDialog({
    required BuildContext context,
    required String title,
    required dynamic error,
    required StackTrace stackTrace,
  }) {
    final fullErrorText = 'Error:\n$error\n\nStackTrace:\n$stackTrace';
    bool isUploading = false;

    showSonoBottomSheet(
      context: context,
      title: title,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Text(
          fullErrorText,
          style: const TextStyle(
            color: Colors.white70,
            fontFamily: 'monospace',
            fontSize: 12,
          ),
        ),
      ),
      actions: [
        TextButton(
          child: const Text('Close', style: TextStyle(color: Colors.white70)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        StatefulBuilder(
          builder: (context, setDialogState) {
            return isUploading
                ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  ),
                )
                : ElevatedButton.icon(
                  icon: const Icon(Icons.share_rounded, size: 16),
                  label: const Text('Copy Link'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    setDialogState(() => isUploading = true);
                    try {
                      final url = await _uploadToPasteService(fullErrorText);
                      await Clipboard.setData(ClipboardData(text: url));
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Success! Link to error log copied to clipboard.',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Could not upload error log: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } finally {
                      if (context.mounted) {
                        setDialogState(() => isUploading = false);
                      }
                    }
                  },
                );
          },
        ),
      ],
    );
  }

  static Future<void> logErrorToPasteService({
    required dynamic error,
    required StackTrace stackTrace,
    String? reason,
  }) async {
    final fullErrorText =
        'Reason: ${reason ?? 'N/A'}\n\nError:\n$error\n\nStackTrace:\n$stackTrace';
    try {
      final url = await _uploadToPasteService(fullErrorText);
      if (kDebugMode) {
        print('Error log uploaded to: $url');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Could not upload error log: $e');
      }
    }
  }

  /// Uploads to paste.rs & returns URL
  static Future<String> _uploadToPasteService(String content) async {
    try {
      final response = await http
          .post(Uri.parse('https://paste.rs/'), body: content)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 201) {
        return response.body;
      } else {
        throw Exception('Server returned status ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Could not connect to paste service: $e');
    }
  }
}