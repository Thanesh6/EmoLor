import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'pending_requests_tab.dart';
import 'schedule_tab.dart';

/// UCD034 – Sessions Hub
///
/// Combines [PendingRequestsTab] (UCD033) and [ScheduleTab] (UCD034) into a
/// single tabbed view so the therapist can switch between incoming requests
/// and the calendar schedule without leaving the Sessions section.
class SessionsHubTab extends StatelessWidget {
  const SessionsHubTab({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // Tab bar header
          Container(
            color: Colors.white,
            child: TabBar(
              labelColor: const Color(0xFF1E40AF),
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: const Color(0xFF1E40AF),
              indicatorWeight: 3,
              labelStyle: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              tabs: const [
                Tab(
                  icon: Icon(Icons.calendar_month, size: 20),
                  text: 'Schedule',
                ),
                Tab(
                  icon: Icon(Icons.inbox_rounded, size: 20),
                  text: 'Requests',
                ),
              ],
            ),
          ),

          // Tab views
          const Expanded(
            child: TabBarView(
              children: [
                ScheduleTab(),
                PendingRequestsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
