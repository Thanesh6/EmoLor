import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../shared/models/scheduled_session.dart';
import '../../../../shared/services/client_linking_service.dart';
import '../../services/client_notes_service.dart';
import '../../services/client_record_service.dart';

/// UCD039 – Client Record Dashboard
///
/// Comprehensive profile for a single child, organized in four tabs:
/// 1. Bio-Data — name, age, parent contact
/// 2. Sensory Profile — custom emotion–colour mappings
/// 3. Emotion Journal — recent mood / emotion entries
/// 4. Clinical History — past sessions and activity logs
class ClientRecordScreen extends StatefulWidget {
  final String childId;
  final String childName;
  final String caregiverId;

  const ClientRecordScreen({
    super.key,
    required this.childId,
    required this.childName,
    required this.caregiverId,
  });

  @override
  State<ClientRecordScreen> createState() => _ClientRecordScreenState();
}

class _ClientRecordScreenState extends State<ClientRecordScreen>
    with SingleTickerProviderStateMixin {
  final ClientRecordService _service = ClientRecordService();
  final ClientLinkingService _linkingService = ClientLinkingService();
  final ClientNotesService _notesService = ClientNotesService();
  late TabController _tabController;

  // Data
  ClientBioData? _bio;
  List<EmotionColourEntry> _colours = [];
  List<EmotionJournalEntry> _journal = [];
  List<ScheduledSession> _sessions = [];
  List<ActivityProgressEntry> _activities = [];
  List<ClientNote> _notes = [];

  bool _loadingBio = true;
  bool _loadingColours = true;
  bool _loadingJournal = true;
  bool _loadingSessions = true;
  bool _loadingActivities = true;
  bool _loadingNotes = true;
  String? _accessError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _verifyAndLoad();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _verifyAndLoad() async {
    final linked = await _service.isLinkedToChild(widget.childId);
    if (!linked) {
      if (!mounted) return;
      setState(() => _accessError =
          'Access Denied. You are no longer linked to this client.');
      return;
    }
    // Load all tabs in parallel
    _loadBio();
    _loadColours();
    _loadJournal();
    _loadSessions();
    _loadActivities();
    _loadNotes();
  }

  Future<void> _loadBio() async {
    setState(() => _loadingBio = true);
    final data = await _service.getBioData(widget.childId);
    if (!mounted) return;
    setState(() {
      _bio = data;
      _loadingBio = false;
    });
  }

  Future<void> _loadColours() async {
    setState(() => _loadingColours = true);
    final data = await _service.getEmotionColours(widget.childId);
    if (!mounted) return;
    setState(() {
      _colours = data;
      _loadingColours = false;
    });
  }

  Future<void> _loadJournal() async {
    setState(() => _loadingJournal = true);
    final data = await _service.getEmotionEntries(widget.childId);
    if (!mounted) return;
    setState(() {
      _journal = data;
      _loadingJournal = false;
    });
  }

  Future<void> _loadSessions() async {
    setState(() => _loadingSessions = true);
    final data = await _service.getSessionHistory(widget.childId);
    if (!mounted) return;
    setState(() {
      _sessions = data;
      _loadingSessions = false;
    });
  }

  Future<void> _loadActivities() async {
    setState(() => _loadingActivities = true);
    final data = await _service.getActivityProgress(widget.childId);
    if (!mounted) return;
    setState(() {
      _activities = data;
      _loadingActivities = false;
    });
  }

  Future<void> _loadNotes() async {
    setState(() => _loadingNotes = true);
    final data = await _notesService.getNotes(widget.childId);
    if (!mounted) return;
    setState(() {
      _notes = data;
      _loadingNotes = false;
    });
  }

  // ── UCD041 – Unlink Client Account ────────────────────────────────────

  /// Shows a high-priority warning modal before unlinking.
  Future<void> _showUnlinkWarning() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon:
            Icon(Icons.warning_amber_rounded, color: Colors.red[600], size: 48),
        title: Text(
          'Unlink Client',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Are you sure? You will lose access to '
              '${widget.childName}\'s data. '
              'This action cannot be undone.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.red[400], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'The caregiver will be notified of this disconnection.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.red[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: Colors.grey[600])),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Confirm Unlink',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _linkingService.unlinkClient(
        caregiverId: widget.caregiverId,
        childName: widget.childName,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Client "${widget.childName}" has been unlinked successfully.'),
          backgroundColor: Colors.green[600],
        ),
      );

      // Redirect back to client list (which no longer shows this child)
      Navigator.pop(context, true); // true signals a refresh is needed
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to unlink client: $e'),
          backgroundColor: Colors.red[600],
        ),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_accessError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Client Record')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 56, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text(
                _accessError!,
                textAlign: TextAlign.center,
                style:
                    GoogleFonts.poppins(fontSize: 15, color: Colors.red[600]),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to Client List'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          widget.childName,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _verifyAndLoad,
          ),
          IconButton(
            icon: Icon(Icons.link_off, color: Colors.red[400]),
            tooltip: 'Unlink Client',
            onPressed: _showUnlinkWarning,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF1E40AF),
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: const Color(0xFF1E40AF),
          indicatorWeight: 3,
          isScrollable: true,
          labelStyle:
              GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
          unselectedLabelStyle:
              GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
          tabs: const [
            Tab(text: 'Bio-Data'),
            Tab(text: 'Sensory Profile'),
            Tab(text: 'Emotion Journal'),
            Tab(text: 'Clinical History'),
            Tab(text: 'Notes'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBioTab(),
          _buildSensoryTab(),
          _buildJournalTab(),
          _buildClinicalTab(),
          _buildNotesTab(),
        ],
      ),
    );
  }

  // ── Tab 1: Bio-Data ───────────────────────────────────────────────────

  Widget _buildBioTab() {
    if (_loadingBio) return const Center(child: CircularProgressIndicator());
    if (_bio == null) {
      return Center(
        child: Text('Profile not found.',
            style: GoogleFonts.poppins(color: Colors.grey[500])),
      );
    }
    final b = _bio!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Child card
          _SectionCard(
            title: 'Child Information',
            icon: Icons.child_care,
            iconColor: Colors.indigo,
            children: [
              _InfoRow(label: 'Name', value: b.childName),
              if (b.age != null)
                _InfoRow(label: 'Age', value: '${b.age} years'),
              if (b.dateOfBirth != null)
                _InfoRow(
                  label: 'Date of Birth',
                  value: DateFormat('dd MMM yyyy').format(b.dateOfBirth!),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Caregiver card
          _SectionCard(
            title: 'Parent / Caregiver Contact',
            icon: Icons.person_outline,
            iconColor: Colors.teal,
            children: [
              _InfoRow(label: 'Name', value: b.caregiverName),
              if (b.caregiverPhone != null)
                _InfoRow(label: 'Phone', value: b.caregiverPhone!),
              if (b.caregiverEmail != null)
                _InfoRow(label: 'Email', value: b.caregiverEmail!),
            ],
          ),

          // Preferences
          if (b.preferences.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Preferences',
              icon: Icons.tune,
              iconColor: Colors.deepPurple,
              children: b.preferences.entries.map((e) {
                return _InfoRow(label: e.key, value: e.value.toString());
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ── Tab 2: Sensory Profile (Emotion–Colour Mappings) ──────────────────

  Widget _buildSensoryTab() {
    if (_loadingColours) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_colours.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.palette_outlined, size: 56, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              'No custom emotion–colour mappings yet.',
              style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _colours.length,
      itemBuilder: (_, i) {
        final c = _colours[i];
        final color = _parseHex(c.colorHex);
        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey[300]!, width: 1),
              ),
            ),
            title: Text(
              c.emotionName,
              style: GoogleFonts.poppins(
                  fontSize: 15, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              c.colorHex.toUpperCase(),
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
            ),
            trailing: c.icon != null
                ? Text(c.icon!, style: const TextStyle(fontSize: 22))
                : null,
          ),
        );
      },
    );
  }

  // ── Tab 3: Emotion Journal ────────────────────────────────────────────

  Widget _buildJournalTab() {
    if (_loadingJournal) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_journal.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_stories, size: 56, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              'No emotion entries recorded yet.',
              style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _journal.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final e = _journal[i];
        return Card(
          elevation: 1,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _emotionColor(e.emotionName)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        e.emotionName,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _emotionColor(e.emotionName),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Intensity dots
                    ...List.generate(5, (dot) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 3),
                        child: Icon(
                          Icons.circle,
                          size: 8,
                          color: dot < e.intensity
                              ? _emotionColor(e.emotionName)
                              : Colors.grey[300],
                        ),
                      );
                    }),
                    const Spacer(),
                    Text(
                      DateFormat('dd MMM, HH:mm').format(e.timestamp),
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
                if (e.trigger != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.flash_on, size: 14, color: Colors.amber[700]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Trigger: ${e.trigger}',
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: Colors.grey[700]),
                        ),
                      ),
                    ],
                  ),
                ],
                if (e.notes != null && e.notes!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    e.notes!,
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: Colors.grey[800]),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Tab 4: Clinical History ───────────────────────────────────────────

  Widget _buildClinicalTab() {
    final sessionsLoading = _loadingSessions;
    final activitiesLoading = _loadingActivities;

    if (sessionsLoading && activitiesLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Sessions ───────────────────────────────────────────
          Text(
            'Past Sessions',
            style: GoogleFonts.poppins(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 10),
          if (sessionsLoading)
            const Center(child: CircularProgressIndicator())
          else if (_sessions.isEmpty)
            _emptyCard('No session history for this client.')
          else
            ..._sessions.map(_buildSessionCard),

          const SizedBox(height: 24),

          // ── Activities ─────────────────────────────────────────
          Text(
            'Activity Progress',
            style: GoogleFonts.poppins(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 10),
          if (activitiesLoading)
            const Center(child: CircularProgressIndicator())
          else if (_activities.isEmpty)
            _emptyCard('No activity logs for this client.')
          else
            ..._activities.map(_buildActivityCard),
        ],
      ),
    );
  }

  Widget _buildSessionCard(ScheduledSession s) {
    Color statusColor;
    switch (s.status) {
      case ScheduledSessionStatus.completed:
        statusColor = Colors.green[600]!;
        break;
      case ScheduledSessionStatus.cancelled:
        statusColor = Colors.red[600]!;
        break;
      case ScheduledSessionStatus.scheduled:
        statusColor = Colors.blue[600]!;
        break;
    }

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    s.title,
                    style: GoogleFonts.poppins(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    s.status.label,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 13, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  DateFormat('dd MMM yyyy').format(s.sessionDate),
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: Colors.grey[700]),
                ),
                if (s.timeSlot != null) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.access_time, size: 13, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    s.timeSlot!.shortLabel,
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: Colors.grey[700]),
                  ),
                ],
                const SizedBox(width: 12),
                Icon(Icons.timer_outlined, size: 13, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${s.durationMinutes} min',
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            ),
            if (s.goals.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: s.goals.take(3).map((g) {
                  return Chip(
                    label: Text(g, style: GoogleFonts.poppins(fontSize: 10)),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    backgroundColor: Colors.purple[50],
                  );
                }).toList(),
              ),
            ],
            if (s.notes != null && s.notes!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                s.notes!,
                style:
                    GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCard(ActivityProgressEntry a) {
    Color statusColor;
    switch (a.status) {
      case 'completed':
        statusColor = Colors.green[600]!;
        break;
      case 'in_progress':
        statusColor = Colors.orange[600]!;
        break;
      default:
        statusColor = Colors.blue[600]!;
    }

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    a.activityTitle,
                    style: GoogleFonts.poppins(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    a.status.replaceAll('_', ' '),
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                // Progress bar
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: a.completionPct / 100,
                      minHeight: 8,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${a.completionPct}%',
                  style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700]),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (a.starsEarned > 0) ...[
                  Icon(Icons.star, size: 14, color: Colors.amber[700]),
                  const SizedBox(width: 2),
                  Text(
                    '${a.starsEarned}',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: Colors.amber[800]),
                  ),
                  const SizedBox(width: 12),
                ],
                if (a.score != null) ...[
                  Icon(Icons.scoreboard_outlined,
                      size: 14, color: Colors.purple[400]),
                  const SizedBox(width: 4),
                  Text(
                    'Score: ${a.score}',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: Colors.grey[700]),
                  ),
                  const SizedBox(width: 12),
                ],
                Icon(Icons.timer_outlined, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  a.formattedTime,
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: Colors.grey[700]),
                ),
                const Spacer(),
                if (a.difficulty.isNotEmpty)
                  Text(
                    a.difficulty,
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: Colors.grey[500]),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab 5: Notes (UCD042) ─────────────────────────────────────────────

  Widget _buildNotesTab() {
    if (_loadingNotes) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Header with "Add Note" button
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Clinical Notes',
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _openNoteEditor(),
                icon: const Icon(Icons.add, size: 18),
                label: Text('Add Note',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E40AF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),

        // Notes list
        Expanded(
          child: _notes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.note_alt_outlined,
                          size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text(
                        'No clinical notes yet.\nTap "Add Note" to begin.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                            fontSize: 13, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _notes.length,
                  itemBuilder: (_, i) => _buildNoteCard(_notes[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildNoteCard(ClientNote note) {
    final dateStr = DateFormat('dd MMM yyyy, HH:mm').format(note.createdAt);
    final editedStr = note.wasEdited
        ? '  (edited ${DateFormat('dd MMM, HH:mm').format(note.updatedAt)})'
        : '';

    Color categoryColor;
    switch (note.category) {
      case 'Behavioral':
        categoryColor = Colors.orange[700]!;
        break;
      case 'Milestone':
        categoryColor = Colors.green[700]!;
        break;
      case 'Session Summary':
        categoryColor = Colors.blue[700]!;
        break;
      case 'Follow-up':
        categoryColor = Colors.purple[700]!;
        break;
      default:
        categoryColor = Colors.blueGrey[600]!;
    }

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category badge + edit/delete actions
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    note.category,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: categoryColor,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.edit_outlined,
                      size: 18, color: Colors.grey[500]),
                  tooltip: 'Edit',
                  onPressed: () => _openNoteEditor(existing: note),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      size: 18, color: Colors.red[400]),
                  tooltip: 'Delete',
                  onPressed: () => _confirmDeleteNote(note),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Note content
            Text(
              note.content,
              style: GoogleFonts.poppins(fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 8),

            // Timestamp
            Text(
              '$dateStr$editedStr',
              style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  /// Opens a bottom-sheet editor for creating or editing a note.
  Future<void> _openNoteEditor({ClientNote? existing}) async {
    final contentCtrl = TextEditingController(text: existing?.content ?? '');
    String selectedCategory = existing?.category ?? 'General';
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      existing != null ? 'Edit Note' : 'New Clinical Note',
                      style: GoogleFonts.poppins(
                          fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),

                    // Category dropdown
                    DropdownButtonFormField<String>(
                      initialValue: selectedCategory,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        labelStyle: GoogleFonts.poppins(fontSize: 14),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                      items: ClientNotesService.categories
                          .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c,
                                  style: GoogleFonts.poppins(fontSize: 14))))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setModalState(() => selectedCategory = v);
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // Content text area
                    TextFormField(
                      controller: contentCtrl,
                      maxLines: 6,
                      minLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Clinical Observation',
                        hintText:
                            'e.g. Subject showed improved focus during the colour-match activity',
                        labelStyle: GoogleFonts.poppins(fontSize: 14),
                        hintStyle: GoogleFonts.poppins(
                            fontSize: 13, color: Colors.grey[400]),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        alignLabelWithHint: true,
                      ),
                      style: GoogleFonts.poppins(fontSize: 14),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Note content cannot be empty.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Actions
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: saving
                                ? null
                                : () async {
                                    // Discard changes warning
                                    if (contentCtrl.text.trim().isNotEmpty &&
                                        contentCtrl.text.trim() !=
                                            (existing?.content ?? '')) {
                                      final discard = await showDialog<bool>(
                                        context: ctx,
                                        builder: (d) => AlertDialog(
                                          title: Text('Discard Changes?',
                                              style: GoogleFonts.poppins(
                                                  fontWeight: FontWeight.w600)),
                                          content: Text(
                                            'Unsaved changes will be lost. Continue?',
                                            style: GoogleFonts.poppins(
                                                fontSize: 14),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(d, false),
                                              child: const Text('Keep Editing'),
                                            ),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    Colors.red[600],
                                                foregroundColor: Colors.white,
                                              ),
                                              onPressed: () =>
                                                  Navigator.pop(d, true),
                                              child: const Text('Discard'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (discard != true) return;
                                    }
                                    if (!ctx.mounted) return;
                                    Navigator.pop(ctx, false);
                                  },
                            child: Text('Cancel',
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w500)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E40AF),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: saving
                                ? null
                                : () async {
                                    if (!formKey.currentState!.validate()) {
                                      return;
                                    }
                                    setModalState(() => saving = true);
                                    try {
                                      if (existing != null) {
                                        await _notesService.updateNote(
                                          noteId: existing.id,
                                          content: contentCtrl.text,
                                          category: selectedCategory,
                                        );
                                      } else {
                                        await _notesService.createNote(
                                          childId: widget.childId,
                                          content: contentCtrl.text,
                                          category: selectedCategory,
                                        );
                                      }
                                      if (ctx.mounted) {
                                        Navigator.pop(ctx, true);
                                      }
                                    } catch (e) {
                                      setModalState(() => saving = false);
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx)
                                            .showSnackBar(SnackBar(
                                          content: Text('Failed to save: $e'),
                                          backgroundColor: Colors.red[600],
                                        ));
                                      }
                                    }
                                  },
                            child: saving
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : Text('Save Note',
                                    style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    contentCtrl.dispose();

    if (saved == true && mounted) {
      _loadNotes();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(existing != null ? 'Note Updated' : 'Note Saved'),
          backgroundColor: Colors.green[600],
        ),
      );
    }
  }

  /// Confirm-delete dialog for a note.
  Future<void> _confirmDeleteNote(ClientNote note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Note?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(
          'This clinical note will be permanently removed.',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _notesService.deleteNote(note.id);
      if (!mounted) return;
      _loadNotes();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Note Deleted'),
          backgroundColor: Colors.green[600],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete note: $e'),
          backgroundColor: Colors.red[600],
        ),
      );
    }
  }

  Widget _emptyCard(String message) {
    return Card(
      elevation: 0,
      color: Colors.grey[100],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Center(
          child: Text(
            message,
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500]),
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  Color _parseHex(String hex) {
    final h = hex.replaceFirst('#', '');
    if (h.length == 6) return Color(int.parse('FF$h', radix: 16));
    if (h.length == 8) return Color(int.parse(h, radix: 16));
    return Colors.grey;
  }

  Color _emotionColor(String name) {
    const map = {
      'Happy': Color(0xFFFFE66D),
      'Sad': Color(0xFF74B9FF),
      'Angry': Color(0xFFFF6B6B),
      'Calm': Color(0xFF7ED957),
      'Scared': Color(0xFFBB6BD9),
      'Excited': Color(0xFFFF9F43),
      'Love': Color(0xFFFF7EB3),
      'Surprised': Color(0xFFFF9F43),
      'Cool': Color(0xFF7ED957),
      'Kind': Color(0xFF4ECDC4),
    };
    return map[name] ?? Colors.blueGrey;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ── Reusable widgets ────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final MaterialColor iconColor;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor[600], size: 22),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600]),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                  fontSize: 14, color: const Color(0xFF1E293B)),
            ),
          ),
        ],
      ),
    );
  }
}
