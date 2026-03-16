import 'package:flutter/material.dart';

import '../../../../shared/screens/engagement_child_picker.dart';
import '../../../child_profile/services/child_profile_service.dart';

/// UCD043 – Caregiver-side wrapper that loads the caregiver's children
/// via [ChildProfileService] and feeds them to [EngagementChildPicker].
class CaregiverEngagementTab extends StatefulWidget {
  const CaregiverEngagementTab({super.key});

  @override
  State<CaregiverEngagementTab> createState() => _CaregiverEngagementTabState();
}

class _CaregiverEngagementTabState extends State<CaregiverEngagementTab> {
  final ChildProfileService _service = ChildProfileService();
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
      final profiles = await _service.getMyChildProfiles();
      if (!mounted) return;
      setState(() {
        _children = profiles
            .map((p) => {
                  'id': p.profileId,
                  'name': p.name,
                  'avatarUrl': p.avatarUrl,
                })
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load children: $e';
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
