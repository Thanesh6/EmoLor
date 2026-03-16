import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

class LinkAccountScreen extends StatefulWidget {
  const LinkAccountScreen({super.key});

  @override
  State<LinkAccountScreen> createState() => _LinkAccountScreenState();
}

class _LinkAccountScreenState extends State<LinkAccountScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;
  String? _message;
  bool _isSuccess = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _linkAccount() async {
    if (_codeController.text.isEmpty) {
      setState(() {
        _isSuccess = false;
        _message = 'Please enter a code.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _message = null;
    });

    // Mock API Call
    await Future.delayed(const Duration(seconds: 2));

    // TODO: Implement actual DB linking logic – currently always succeeds

    if (mounted) {
      setState(() {
        _isLoading = false;
        _isSuccess = true;
        _message = 'Successfully linked to Client!';
      });

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) context.pop();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Link Client Account',
            style: GoogleFonts.fredoka(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Enter Client Code',
              style: GoogleFonts.fredoka(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF6D28D9)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Ask the client for their unique linking code to connect with them.',
              style: GoogleFonts.fredoka(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            TextField(
              controller: _codeController,
              textAlign: TextAlign.center,
              style: GoogleFonts.fredoka(fontSize: 32, letterSpacing: 5),
              decoration: InputDecoration(
                hintText: 'ABCD-1234',
                hintStyle: GoogleFonts.fredoka(
                    fontSize: 32, letterSpacing: 5, color: Colors.grey[300]),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                contentPadding: const EdgeInsets.symmetric(vertical: 20),
              ),
            ),
            const SizedBox(height: 24),
            if (_message != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: _isSuccess ? Colors.green[50] : Colors.red[50],
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: _isSuccess ? Colors.green : Colors.red),
                ),
                child: Row(
                  children: [
                    Icon(_isSuccess ? Icons.check_circle : Icons.error,
                        color: _isSuccess ? Colors.green : Colors.red),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _message!,
                        style: GoogleFonts.fredoka(
                            color: _isSuccess
                                ? Colors.green[800]
                                : Colors.red[800],
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ElevatedButton(
              onPressed: _isLoading ? null : _linkAccount,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text(
                      'Link Account',
                      style: GoogleFonts.fredoka(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
