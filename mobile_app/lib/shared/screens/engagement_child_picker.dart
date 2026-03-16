import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'engagement_trends_screen.dart';
import 'performance_stats_screen.dart';

/// UCD043 – Child selector for the Engagement Analytics view.
///
/// Both therapists and caregivers land here first; they pick a child,
/// then the [EngagementTrendsScreen] loads for that child.
///
/// [children] is a list of `{'id': String, 'name': String, 'avatarUrl': String?}`.
class EngagementChildPicker extends StatelessWidget {
  final List<Map<String, String?>> children;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;

  const EngagementChildPicker({
    super.key,
    required this.children,
    this.isLoading = false,
    this.errorMessage,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 12),
            Text(errorMessage!,
                style:
                    GoogleFonts.poppins(fontSize: 14, color: Colors.red[600])),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      );
    }

    if (children.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.analytics_outlined, size: 56, color: Colors.grey[300]),
            const SizedBox(height: 14),
            Text(
              'No linked children found.\nLink a client to view analytics.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Engagement Analytics',
            style:
                GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Select a child to view activity trends',
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 1.1,
              ),
              itemCount: children.length,
              itemBuilder: (_, i) {
                final child = children[i];
                final name = child['name'] ?? 'Child';
                final id = child['id'] ?? '';
                final avatarUrl = child['avatarUrl'];

                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _showAnalyticsOptions(context, id, name),
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundColor: Colors.indigo[50],
                            backgroundImage: avatarUrl != null
                                ? NetworkImage(avatarUrl)
                                : null,
                            child: avatarUrl == null
                                ? Text(
                                    name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : '?',
                                    style: GoogleFonts.poppins(
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.indigo[400],
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            name,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                                fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.analytics,
                                  size: 14, color: Colors.indigo[400]),
                              const SizedBox(width: 4),
                              Text(
                                'View Analytics',
                                style: GoogleFonts.poppins(
                                    fontSize: 11, color: Colors.indigo[400]),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAnalyticsOptions(
      BuildContext context, String childId, String childName) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                childName,
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose an analytics view',
                style:
                    GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading:
                    Icon(Icons.show_chart, color: Colors.indigo[400], size: 28),
                title: Text('Engagement Trends',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                subtitle: Text(
                  'Activity frequency, daily usage, and completion rates',
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: Colors.grey[500]),
                ),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => EngagementTrendsScreen(
                        childId: childId, childName: childName),
                  ));
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Icon(Icons.radar, color: Colors.teal[400], size: 28),
                title: Text('Performance Statistics',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                subtitle: Text(
                  'Accuracy rates, response times, and adaptive difficulty',
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: Colors.grey[500]),
                ),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => PerformanceStatsScreen(
                        childId: childId, childName: childName),
                  ));
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
