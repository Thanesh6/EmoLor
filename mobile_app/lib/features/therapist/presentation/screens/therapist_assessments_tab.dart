import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TherapistAssessmentsTab extends StatefulWidget {
  const TherapistAssessmentsTab({super.key});

  @override
  State<TherapistAssessmentsTab> createState() => _TherapistAssessmentsTabState();
}

class _TherapistAssessmentsTabState extends State<TherapistAssessmentsTab> {
  int _selectedFilter = 0;
  final List<String> _filters = ['All', 'Pending', 'Completed', 'In Progress'];

  final List<Map<String, dynamic>> _assessments = [
    {
      'patient': 'Thanesh',
      'avatar': '😊',
      'type': 'Emotion Recognition',
      'description': 'Evaluate ability to identify basic emotions from facial expressions.',
      'status': 'pending',
      'dueDate': 'Mar 28, 2026',
      'color': Color(0xFF6B21A8),
    },
    {
      'patient': 'Sarah',
      'avatar': '🦁',
      'type': 'Social Communication',
      'description': 'Assess verbal and non-verbal communication skills in social contexts.',
      'status': 'in_progress',
      'dueDate': 'Mar 30, 2026',
      'color': Color(0xFF1E40AF),
    },
    {
      'patient': 'Alex',
      'avatar': '🐰',
      'type': 'Behavioural Regulation',
      'description': 'Measure ability to manage emotions and respond to stress.',
      'status': 'completed',
      'dueDate': 'Mar 25, 2026',
      'color': Color(0xFF065F46),
    },
    {
      'patient': 'Emma',
      'avatar': '🦊',
      'type': 'Sensory Processing',
      'description': 'Evaluate responses to sensory stimuli and self-regulation strategies.',
      'status': 'pending',
      'dueDate': 'Apr 2, 2026',
      'color': Color(0xFF92400E),
    },
    {
      'patient': 'Thanesh',
      'avatar': '😊',
      'type': 'Cognitive Flexibility',
      'description': 'Assess ability to switch between tasks and adapt to changing rules.',
      'status': 'completed',
      'dueDate': 'Mar 20, 2026',
      'color': Color(0xFF1E40AF),
    },
  ];

  List<Map<String, dynamic>> get _filtered {
    if (_selectedFilter == 0) return _assessments;
    final map = ['', 'pending', 'completed', 'in_progress'];
    return _assessments.where((a) => a['status'] == map[_selectedFilter]).toList();
  }

  TextStyle _ts({double size = 16, FontWeight weight = FontWeight.w500, Color color = Colors.black87}) =>
      GoogleFonts.baloo2(fontSize: size, fontWeight: weight, color: color);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Assessments', style: _ts(size: 26, weight: FontWeight.w700, color: const Color(0xFF1E3A8A))),
                  Text('Track and manage patient assessment tools', style: _ts(size: 15, color: Colors.grey[600]!)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add, size: 20),
                label: Text('New Assessment', style: _ts(size: 15, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E40AF),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Summary cards
          Row(
            children: [
              _buildSummaryCard('📋', 'Total', '${_assessments.length}', const Color(0xFF1E40AF)),
              const SizedBox(width: 16),
              _buildSummaryCard('⏳', 'Pending', '${_assessments.where((a) => a['status'] == 'pending').length}', const Color(0xFF92400E)),
              const SizedBox(width: 16),
              _buildSummaryCard('🔄', 'In Progress', '${_assessments.where((a) => a['status'] == 'in_progress').length}', const Color(0xFF6B21A8)),
              const SizedBox(width: 16),
              _buildSummaryCard('✅', 'Completed', '${_assessments.where((a) => a['status'] == 'completed').length}', const Color(0xFF065F46)),
            ],
          ),
          const SizedBox(height: 28),

          // Filter chips
          Row(
            children: List.generate(_filters.length, (i) => Padding(
              padding: const EdgeInsets.only(right: 10),
              child: GestureDetector(
                onTap: () => setState(() => _selectedFilter = i),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: _selectedFilter == i ? const Color(0xFF1E40AF) : Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: _selectedFilter == i ? const Color(0xFF1E40AF) : Colors.grey.shade300),
                    boxShadow: _selectedFilter == i ? [BoxShadow(color: const Color(0xFF1E40AF).withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 3))] : [],
                  ),
                  child: Text(_filters[i], style: _ts(size: 14, weight: FontWeight.w600, color: _selectedFilter == i ? Colors.white : Colors.grey[700]!)),
                ),
              ),
            )),
          ),
          const SizedBox(height: 24),

          // Assessment list
          ..._filtered.map((a) => _buildAssessmentCard(a)),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String emoji, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, 6))],
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Text(emoji, style: const TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: _ts(size: 24, weight: FontWeight.w700, color: color)),
                Text(label, style: _ts(size: 13, color: Colors.grey[600]!)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssessmentCard(Map<String, dynamic> a) {
    final statusColor = a['status'] == 'completed'
        ? const Color(0xFF065F46)
        : a['status'] == 'in_progress'
            ? const Color(0xFF6B21A8)
            : const Color(0xFF92400E);
    final statusLabel = a['status'] == 'completed'
        ? 'Completed'
        : a['status'] == 'in_progress'
            ? 'In Progress'
            : 'Pending';
    final statusIcon = a['status'] == 'completed'
        ? Icons.check_circle_rounded
        : a['status'] == 'in_progress'
            ? Icons.timelapse_rounded
            : Icons.radio_button_unchecked_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4))],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: (a['color'] as Color).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(child: Text(a['avatar'], style: const TextStyle(fontSize: 26))),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(a['type'], style: _ts(size: 16, weight: FontWeight.w700)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 14, color: statusColor),
                          const SizedBox(width: 5),
                          Text(statusLabel, style: _ts(size: 13, weight: FontWeight.w600, color: statusColor)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Patient: ${a['patient']}', style: _ts(size: 14, weight: FontWeight.w600, color: const Color(0xFF1E40AF))),
                const SizedBox(height: 4),
                Text(a['description'], style: _ts(size: 14, color: Colors.grey[600]!)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 5),
                    Text('Due: ${a['dueDate']}', style: _ts(size: 13, color: Colors.grey[500]!)),
                    const Spacer(),
                    TextButton(
                      onPressed: () {},
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF1E40AF),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Color(0xFF1E40AF))),
                      ),
                      child: Text(a['status'] == 'completed' ? 'View Results' : 'Start Assessment',
                          style: _ts(size: 13, weight: FontWeight.w600, color: const Color(0xFF1E40AF))),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
