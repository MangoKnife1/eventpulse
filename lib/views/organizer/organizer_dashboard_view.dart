import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';
import '../../services/event_service.dart';
import '../../services/auth_service.dart';
import '../../services/cloudinary_service.dart';
import '../../services/service_exception.dart';
import '../../models/event_model.dart';
import '../../models/ticket_model.dart';

class OrganizerDashboardView extends StatefulWidget {
  const OrganizerDashboardView({super.key});

  @override
  State<OrganizerDashboardView> createState() => _OrganizerDashboardViewState();
}

class _OrganizerDashboardViewState extends State<OrganizerDashboardView> {
  String _selectedEventId = 'all';

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eventService = Provider.of<EventService>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final currentUser = Provider.of<AuthService>(context).currentUser;
    // Organizers see all of their own events (including pending); admins see everything.
    final allEvents = eventService.eventsManagedBy(currentUser);
    final managedIds = allEvents.map((e) => e.id).toSet();
    final allTickets = eventService.userTickets
        .where((t) => managedIds.contains(t.eventId) && !t.isOrganizerPass)
        .toList();

    // Filter tickets based on active event scope
    final scopedTickets = _selectedEventId == 'all'
        ? allTickets
        : allTickets.where((t) => t.eventId == _selectedEventId).toList();

    final checkedInTickets =
        scopedTickets.where((t) => t.status == TicketStatus.checkedIn).toList();
    final totalAttendees = scopedTickets.length;
    final checkedInCount = checkedInTickets.length;
    final checkInRate =
        totalAttendees > 0 ? (checkedInCount / totalAttendees) : 0.0;

    return Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
        body: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
            children: [
              // Host Studio In-page Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Organizer Dashboard',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5238),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Create Event',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700)),
                    onPressed: () => _showCreateEventSheet(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Event Terminal Scope Selector
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF131B2E) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event_available,
                        color: Color(0xFFFF5238), size: 18),
                    const SizedBox(width: 10),
                    Text(
                      'Terminal Event:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedEventId == 'all' ||
                                  allEvents.any((e) => e.id == _selectedEventId)
                              ? _selectedEventId
                              : 'all',
                          isExpanded: true,
                          dropdownColor:
                              isDark ? const Color(0xFF131B2E) : Colors.white,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color:
                                isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: 'all',
                              child: Text('All Events (Universal Gate)'),
                            ),
                            ...allEvents.map((evt) => DropdownMenuItem(
                                  value: evt.id,
                                  child: Text(evt.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                )),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedEventId = val;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Metrics Row
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      title: 'RSVP Total',
                      value: '$totalAttendees',
                      subtitle: 'Registered',
                      color: const Color(0xFF0EA5E9),
                      icon: Icons.people_outline,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricCard(
                      title: 'Checked-In',
                      value: '$checkedInCount',
                      subtitle:
                          '${(checkInRate * 100).toStringAsFixed(0)}% arrived',
                      color: const Color(0xFF10B981),
                      icon: Icons.check_circle_outline,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Attendee Roster Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Attendee Roster (${scopedTickets.length})',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    'Gate List',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? const Color(0xFF64748B)
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              scopedTickets.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF131B2E) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          'No attendees registered for this event scope',
                          style: TextStyle(
                              color: isDark
                                  ? const Color(0xFF64748B)
                                  : const Color(0xFF94A3B8)),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: scopedTickets.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final ticket = scopedTickets[index];
                        final isChecked =
                            ticket.status == TicketStatus.checkedIn;

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color:
                                isDark ? const Color(0xFF131B2E) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: const Color(0xFFFF5238)
                                    .withValues(alpha: 0.15),
                                child: Text(
                                  ticket.userName.isNotEmpty
                                      ? ticket.userName[0].toUpperCase()
                                      : 'A',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFFF5238)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ticket.userName,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    Text(
                                      ticket.qrPayload,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontFamily: 'monospace',
                                        color: isDark
                                            ? const Color(0xFF64748B)
                                            : const Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              InkWell(
                                onTap: () async {
                                  if (!isChecked) {
                                    await eventService.checkInTicketWithCode(
                                      ticket.qrPayload,
                                      targetEventId: _selectedEventId,
                                    );
                                    if (!mounted) return;
                                    setState(() {});
                                  }
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isChecked
                                        ? const Color(0xFF10B981)
                                            .withValues(alpha: 0.12)
                                        : const Color(0xFF64748B)
                                            .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isChecked
                                            ? Icons.check
                                            : Icons.circle_outlined,
                                        size: 13,
                                        color: isChecked
                                            ? const Color(0xFF10B981)
                                            : const Color(0xFF64748B),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isChecked ? 'CHECKED IN' : 'CHECK IN',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: isChecked
                                              ? const Color(0xFF10B981)
                                              : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ],
          ),
        ));
  }

  void _showCreateEventSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _CreateEventSheet(),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final IconData icon;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                ),
              ),
              Icon(icon, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

class _CreateEventSheet extends StatefulWidget {
  const _CreateEventSheet();

  @override
  State<_CreateEventSheet> createState() => _CreateEventSheetState();
}

class _CreateEventSheetState extends State<_CreateEventSheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _venueController = TextEditingController();
  final _locationController = TextEditingController();
  final _capacityController = TextEditingController(text: '50');

  static const _categories = [
    'Technology',
    'Design',
    'Music & Arts',
    'Community',
    'Gaming'
  ];
  String _category = _categories.first;
  DateTime _dateTime = DateTime.now().add(const Duration(days: 3, hours: 2));
  String _imageUrl = '';
  bool _uploading = false;
  bool _saving = false;

  // Tags + inline error (a SnackBar would be hidden behind this sheet)
  final _tagController = TextEditingController();
  final List<String> _tags = [];
  String? _formError;
  static const _maxTags = 6;
  static const _suggestedTags = [
    'Workshop',
    'Networking',
    'Social',
    'Competition',
    'Beginner-friendly',
    'Live',
    'Volunteering',
    'Creative',
    'Career',
    'Free',
  ];

  void _addTags(String raw) {
    final parts = raw.split(RegExp(r'[,;\n]'));
    setState(() {
      for (var p in parts) {
        p = p.trim().replaceAll(RegExp(r'^#+'), '').trim();
        if (p.isEmpty) continue;
        if (p.length > 24) p = p.substring(0, 24);
        if (_tags.length >= _maxTags) break;
        if (_tags.any((t) => t.toLowerCase() == p.toLowerCase())) continue;
        _tags.add(p);
      }
      _tagController.clear();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _venueController.dispose();
    _locationController.dispose();
    _capacityController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dateTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime),
    );
    if (time == null) return;
    setState(() {
      _dateTime =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _pickBanner() async {
    setState(() {
      _uploading = true;
      _formError = null;
    });
    try {
      final url =
          await CloudinaryService.pickAndUpload(folder: 'eventpulse/banners');
      if (url != null && mounted) setState(() => _imageUrl = url);
    } catch (e) {
      if (mounted) setState(() => _formError = friendlyError(e));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _submit(
      EventService eventService, AuthService authService) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (_tagController.text.trim().isNotEmpty) _addTags(_tagController.text);

    if (_titleController.text.trim().isEmpty) {
      setState(() => _formError = 'Please enter an event title.');
      return;
    }
    final capacity = int.tryParse(_capacityController.text.trim());
    if (capacity == null || capacity < 1) {
      setState(() => _formError = 'Capacity must be a number, at least 1.');
      return;
    }

    setState(() {
      _saving = true;
      _formError = null;
    });
    try {
      final event = await eventService.createEvent(
        title: _titleController.text,
        description: _descController.text.trim().isNotEmpty
            ? _descController.text.trim()
            : 'Join our local community for an interactive gathering.',
        category: _category,
        dateTime: _dateTime,
        location: _locationController.text.trim().isNotEmpty
            ? _locationController.text.trim()
            : 'To be announced',
        venueName: _venueController.text.trim().isNotEmpty
            ? _venueController.text.trim()
            : 'Community Center',
        imageUrl: _imageUrl,
        organizer: authService.currentUser,
        capacity: capacity,
        tags: List<String>.from(_tags),
      );
      navigator.pop();
      messenger.showSnackBar(SnackBar(
        content: Text(event.approvalStatus == ApprovalStatus.approved
            ? 'Meetup published!'
            : 'Submitted for admin review. It goes live once approved.'),
      ));
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _formError = friendlyError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final eventService = Provider.of<EventService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);

    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Create Community Meetup',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _buildTextField('Event Title', _titleController,
                    'e.g. Flutter Mobile Architecture Talk', isDark),
                const SizedBox(height: 12),
                _buildTextField('Venue Name', _venueController,
                    'e.g. IT Laboratory 2', isDark),
                const SizedBox(height: 12),
                _buildTextField('Street Address', _locationController,
                    'e.g. Main Campus, Engineering Building', isDark),
                const SizedBox(height: 12),
                _buildTextField('Capacity', _capacityController, '50', isDark,
                    isNumber: true),
                const SizedBox(height: 12),
                _buildTextField('Description', _descController,
                    'What should attendees expect?', isDark,
                    maxLines: 3),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(
                      labelText: 'Category', border: OutlineInputBorder()),
                  items: _categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _category = v ?? _category),
                ),
                const SizedBox(height: 16),
                _buildTagsSection(isDark),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _pickDateTime,
                  icon: const Icon(Icons.event, size: 18),
                  label: Text(
                      DateFormat('EEE, MMM d, y • h:mm a').format(_dateTime)),
                ),
                const SizedBox(height: 12),
                _buildBannerSection(isDark),
                if (_formError != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color:
                              const Color(0xFFEF4444).withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 18, color: Color(0xFFEF4444)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _formError!,
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5238),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: (_saving || _uploading)
                        ? null
                        : () => _submit(eventService, authService),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Submit Meetup',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagsSection(bool isDark) {
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final suggestions = _suggestedTags
        .where((t) => !_tags.any((x) => x.toLowerCase() == t.toLowerCase()))
        .toList();
    final full = _tags.length >= _maxTags;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tags (optional, up to $_maxTags)',
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: muted),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _tagController,
                enabled: !full,
                textInputAction: TextInputAction.done,
                onSubmitted: _addTags,
                decoration: InputDecoration(
                  hintText: full
                      ? 'Tag limit reached'
                      : 'Type a tag, then press Add (or use commas)',
                  prefixText: '#',
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: full ? null : () => _addTags(_tagController.text),
              child: const Text('Add'),
            ),
          ],
        ),
        if (_tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: _tags
                .map((t) => InputChip(
                      label: Text('#$t'),
                      visualDensity: VisualDensity.compact,
                      onDeleted: () => setState(() => _tags.remove(t)),
                    ))
                .toList(),
          ),
        ],
        if (!full && suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: suggestions
                .map((t) => ActionChip(
                      label: Text('+ $t'),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _addTags(t),
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildBannerSection(bool isDark) {
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final bg = isDark ? const Color(0xFF131B2E) : const Color(0xFFF1F5F9);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Banner image',
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: muted),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 150,
            width: double.infinity,
            color: bg,
            child: _uploading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : (_imageUrl.isEmpty
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined,
                              size: 36, color: muted),
                          const SizedBox(height: 6),
                          Text('No image yet',
                              style: TextStyle(fontSize: 12, color: muted)),
                        ],
                      )
                    : Image.network(
                        _imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(
                            child: Icon(Icons.broken_image_outlined,
                                color: muted)),
                      )),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: (_uploading || _saving) ? null : _pickBanner,
                icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                label: Text(
                    _imageUrl.isEmpty ? 'Upload from gallery' : 'Change image'),
              ),
            ),
            if (_imageUrl.isNotEmpty) ...[
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Remove image',
                onPressed: (_uploading || _saving)
                    ? null
                    : () => setState(() => _imageUrl = ''),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          CloudinaryService.isConfigured
              ? 'JPG, PNG or WEBP, up to 10 MB. Uploaded to Cloudinary. A default banner is used if you skip this.'
              : 'Image upload is not set up: add your Cloudinary cloud name and preset in lib/config/app_config.dart.',
          style: TextStyle(
            fontSize: 11,
            color: CloudinaryService.isConfigured
                ? muted
                : const Color(0xFFEF4444),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    String hint,
    bool isDark, {
    int maxLines = 1,
    bool isNumber = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131B2E) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1),
            ),
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: isNumber ? TextInputType.number : TextInputType.text,
            style: TextStyle(
                fontSize: 13, color: isDark ? Colors.white : Colors.black),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? const Color(0xFF64748B)
                      : const Color(0xFF94A3B8)),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }
}

typedef OrganizerView = OrganizerDashboardView;
