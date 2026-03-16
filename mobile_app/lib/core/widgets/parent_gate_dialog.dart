import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../../features/auth/presentation/providers/auth_provider.dart';

/// Parent Gate dialog — requires a caregiver 4-digit PIN to access
/// restricted areas from Child Mode (UCD008).
class ParentGateDialog extends ConsumerStatefulWidget {
  final VoidCallback onSuccess;

  const ParentGateDialog({super.key, required this.onSuccess});

  @override
  ConsumerState<ParentGateDialog> createState() => _ParentGateDialogState();
}

class _ParentGateDialogState extends ConsumerState<ParentGateDialog> {
  String _pin = '';
  String? _errorMessage;
  bool _isLoading = false;
  int _failedAttempts = 0;
  static const int _maxAttempts = 3;
  bool _lockedOut = false;

  void _onDigitPress(String digit) {
    if (_lockedOut || _isLoading) return;
    if (_pin.length < 4) {
      setState(() {
        _pin += digit;
        _errorMessage = null;
      });

      // Auto-submit when 4th digit is entered
      if (_pin.length == 4) {
        _verifyPin();
      }
    }
  }

  void _onDelete() {
    if (_lockedOut || _isLoading) return;
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
        _errorMessage = null;
      });
    }
  }

  Future<void> _verifyPin() async {
    if (_pin.length != 4) return;

    setState(() => _isLoading = true);

    try {
      // 1. Fetch User Profile to get stored hash
      final profile = await ref.read(authProvider.notifier).getUserProfile();

      // Default PIN hash for "1234" (SHA-256)
      const defaultPinHash =
          '03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4';

      final storedHash = (profile != null && profile['parent_pin_hash'] != null)
          ? profile['parent_pin_hash'] as String
          : defaultPinHash;

      // 2. Hash input PIN with SHA-256
      final bytes = utf8.encode(_pin);
      final digest = sha256.convert(bytes);
      final inputHash = digest.toString();

      // 3. Compare
      if (inputHash == storedHash) {
        if (mounted) {
          Navigator.of(context).pop(); // Close dialog
          widget.onSuccess();
        }
      } else {
        _failedAttempts++;
        if (_failedAttempts >= _maxAttempts) {
          setState(() {
            _lockedOut = true;
            _errorMessage = 'Too many failed attempts. Please try again later.';
            _pin = '';
          });
          // Unlock after 30 seconds
          Future.delayed(const Duration(seconds: 30), () {
            if (mounted) {
              setState(() {
                _lockedOut = false;
                _failedAttempts = 0;
                _errorMessage = null;
              });
            }
          });
        } else {
          final remaining = _maxAttempts - _failedAttempts;
          setState(() {
            _errorMessage =
                'Incorrect PIN. $remaining attempt${remaining == 1 ? '' : 's'} remaining.';
            _pin = '';
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Verification failed. Please try again.';
        _pin = '';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasError = _errorMessage != null;
    final double maxDialogHeight = MediaQuery.of(context).size.height * 0.82;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 410,
          maxHeight: maxDialogHeight,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_person,
                    size: 58, color: Color(0xFF6B21A8)),
                const SizedBox(height: 8),
                Text(
                  'Parent Gate',
                  style: GoogleFonts.fredoka(
                    fontSize: 29,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF4C1D95),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Enter your 4-digit PIN',
                  style: GoogleFonts.fredoka(
                      fontSize: 18, color: Colors.grey[600]),
                ),
                const SizedBox(height: 14),

                // PIN Display
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: index < _pin.length
                            ? (hasError ? Colors.red : const Color(0xFF6B21A8))
                            : Colors.grey[300],
                        border: hasError
                            ? Border.all(color: Colors.red, width: 2)
                            : null,
                      ),
                    );
                  }),
                ),

                if (hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.fredoka(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),

                const SizedBox(height: 14),

                // Number Pad
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: CircularProgressIndicator(),
                  )
                else
                  AbsorbPointer(
                    absorbing: _lockedOut,
                    child: Opacity(
                      opacity: _lockedOut ? 0.4 : 1.0,
                      child: SizedBox(
                        width: 300,
                        height: 345,
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 1.2,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                          ),
                          itemCount: 12,
                          itemBuilder: (context, index) {
                            if (index == 9) {
                              return const SizedBox.shrink();
                            }
                            if (index == 11) {
                              return TextButton(
                                onPressed: _onDelete,
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(65, 65),
                                  maximumSize: const Size(72, 72),
                                  padding: EdgeInsets.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  shape: const CircleBorder(),
                                  backgroundColor: Colors.grey[100],
                                ),
                                child: const Icon(Icons.backspace,
                                    color: Colors.black54, size: 18),
                              );
                            }

                            final digit = index == 10 ? '0' : '${index + 1}';
                            return TextButton(
                              onPressed: () => _onDigitPress(digit),
                              style: TextButton.styleFrom(
                                minimumSize: const Size(65, 65),
                                maximumSize: const Size(72, 72),
                                padding: EdgeInsets.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: const CircleBorder(),
                                backgroundColor: Colors.grey[100],
                              ),
                              child: Text(
                                digit,
                                style: GoogleFonts.fredoka(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.fredoka(
                        color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
