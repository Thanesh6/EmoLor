import 'package:flutter/material.dart';

import '../../../../shared/screens/engagement_child_picker.dart';
import '../../services/client_record_service.dart';

/// UCD043 – Therapist-side wrapper that loads linked children
/// via [ClientRecordService] and feeds them to [EngagementChildPicker].
class TherapistEngagementTab extends StatefulWidget {
  const TherapistEngagementTab({super.key});

  @override
  State<TherapistEngagementTab> createState() => _TherapistEngagementTabState();
}

class _TherapistEngagementTabState extends State<TherapistEngagementTab> {
  final ClientRecordService _service = ClientRecordService();
  List<Map<String, String?>> _children = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final clients = await _service.getMyClients();
      if (!mounted) return;
      setState(() {
        _children = clients
            .map((c) => {
                  'id': c.childId,
                  'name': c.childName,
                  'avatarUrl': c.avatarUrl,
                })
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load clients: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return EngagementChildPicker(
      children: _children,
      isLoading: _loading,
      errorMessage: _error,
      onRetry: _load,
    );
  }
}
