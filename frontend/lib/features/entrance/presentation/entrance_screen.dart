import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/config/app_config.dart';
import '../../../core/models/attendee_model.dart';
import '../data/entrance_repository.dart';

class EntranceScreen extends StatefulWidget {
  final VoidCallback onSwitchRole;

  const EntranceScreen({super.key, required this.onSwitchRole});

  @override
  State<EntranceScreen> createState() => _EntranceScreenState();
}

class _EntranceScreenState extends State<EntranceScreen> {
  final EntranceRepository _repo = EntranceRepository();
  int _tabIndex = 0;

  // Lookup & Check-In State
  List<AttendeeModel> _roster = [];
  bool _isLoading = false;
  String _quickFilter = 'ALL'; // ALL, PRESENT, ABSENT, PRE_REGISTERED, WALK_IN
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  // Walk-In Form State
  final _formKey = GlobalKey<FormState>();
  final _idCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _sectionCtrl = TextEditingController();
  bool _markPresentNow = true;
  bool _markPaidNow = false;
  String _paymentMethod = 'CASH';
  late final TextEditingController _feeCtrl;
  AttendeeModel? _duplicateMatch;
  bool _isCheckingDuplicate = false;
  Timer? _dupTimer;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _feeCtrl = TextEditingController(
      text: AppConfig.defaultSeminarFee.toStringAsFixed(2),
    );
    _loadRoster();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _dupTimer?.cancel();
    _searchCtrl.dispose();
    _idCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _sectionCtrl.dispose();
    _feeCtrl.dispose();
    super.dispose();
  }

  void _notify(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor:
            isError ? const Color(0xFFDC2626) : const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String _formatTime(String? iso) {
    if (iso == null || iso.isEmpty) return 'Not checked in';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('hh:mm a').format(dt);
    } catch (_) {
      return iso;
    }
  }

  Future<void> _loadRoster() async {
    setState(() => _isLoading = true);
    try {
      final list = await _repo.searchRoster(_searchCtrl.text);
      setState(() => _roster = list);
    } catch (e) {
      _notify(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<AttendeeModel> get _filteredRoster {
    return _roster.where((item) {
      if (_quickFilter == 'PRESENT') return item.isPresent;
      if (_quickFilter == 'ABSENT') return !item.isPresent;
      if (_quickFilter == 'PRE_REGISTERED') {
        return item.registrationType == 'PRE_REGISTERED';
      }
      if (_quickFilter == 'WALK_IN') return item.registrationType == 'WALK_IN';
      return true;
    }).toList();
  }

  Future<void> _togglePresent(AttendeeModel attendee) async {
    try {
      await _repo.setAttendance(attendee.studentId, !attendee.isPresent);
      _notify(
        '${attendee.fullName} marked as ${!attendee.isPresent ? "PRESENT" : "ABSENT"}.',
      );
      await _loadRoster();
      if (_duplicateMatch?.studentId == attendee.studentId) {
        await _checkDuplicateLive();
      }
    } catch (e) {
      _notify(e.toString(), isError: true);
    }
  }

  void _scheduleDuplicateCheck() {
    _dupTimer?.cancel();
    _dupTimer =
        Timer(const Duration(milliseconds: 350), _checkDuplicateLive);
  }

  Future<void> _checkDuplicateLive() async {
    final sid = _idCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    if (sid.isEmpty && email.isEmpty) {
      setState(() {
        _duplicateMatch = null;
        _isCheckingDuplicate = false;
      });
      return;
    }
    setState(() => _isCheckingDuplicate = true);
    try {
      final res = await _repo.verifyOnline(studentId: sid, email: email);
      if (mounted) {
        setState(() => _duplicateMatch = res.registered ? res.attendee : null);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isCheckingDuplicate = false);
    }
  }

  Future<void> _submitWalkIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      final amount = double.tryParse(_feeCtrl.text.trim()) ?? 0.0;
      final created = await _repo.registerWalkIn(
        studentId: _idCtrl.text.trim(),
        fullName: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        programSection: _sectionCtrl.text.trim(),
        markPresentNow: _markPresentNow,
        markPaidNow: _markPaidNow,
        amountPaid: _markPaidNow ? amount : 0.0,
        paymentMethod: _markPaidNow ? _paymentMethod : 'NONE',
      );
      _notify('Walk-in registered: ${created.fullName}');
      _idCtrl.clear();
      _nameCtrl.clear();
      _emailCtrl.clear();
      _sectionCtrl.clear();
      setState(() {
        _duplicateMatch = null;
        _tabIndex = 0;
      });
      await _loadRoster();
      if (mounted) {
        _showDigitalPassModal(created);
      }
    } catch (e) {
      _notify(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showDigitalPassModal(AttendeeModel attendee) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        contentPadding: const EdgeInsets.all(24),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0284C7), Color(0xFF1E3A8A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            attendee.registrationType == 'WALK_IN'
                                ? 'WALK-IN PASS'
                                : 'ONLINE PRE-REGISTERED',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Icon(
                          attendee.isPresent
                              ? Icons.verified
                              : Icons.schedule,
                          color: Colors.white,
                          size: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      attendee.fullName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: ${attendee.studentId}  •  ${attendee.programSection}',
                      style: const TextStyle(
                        color: Color(0xFFE0F2FE),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _passRow('Email', attendee.email),
              _passRow(
                'Attendance',
                attendee.isPresent ? 'PRESENT IN VENUE' : 'ABSENT',
              ),
              _passRow('Check-In Time', _formatTime(attendee.timeIn)),
              _passRow(
                'Finance Status',
                attendee.isPaid
                    ? 'PAID (PHP ${attendee.amountPaid.toStringAsFixed(2)} - ${attendee.paymentMethod})'
                    : 'UNPAID',
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _passRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalCount = _roster.length;
    final presentCount = _roster.where((a) => a.isPresent).length;
    final walkInCount =
        _roster.where((a) => a.registrationType == 'WALK_IN').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 68,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0EA5E9).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.how_to_reg,
                color: Color(0xFF38BDF8),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Entrance Registration & Verification Desk',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    'Verify online pre-registrations, check in attendees, or log walk-ins',
                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadRoster,
            icon: const Icon(Icons.refresh),
            tooltip: 'Sync Roster',
          ),
          const SizedBox(width: 6),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFF334155)),
                backgroundColor: const Color(0xFF1E293B),
              ),
              onPressed: widget.onSwitchRole,
              icon: const Icon(Icons.swap_horiz, size: 18),
              label: const Text('Switch Station'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Sub-header with quick stats & mode switcher
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            child: Wrap(
              spacing: 20,
              runSpacing: 14,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    _QuickStatPill(
                      label: 'Loaded Roster',
                      value: '$totalCount',
                      color: const Color(0xFF0284C7),
                    ),
                    _QuickStatPill(
                      label: 'Checked-In Present',
                      value: '$presentCount',
                      color: const Color(0xFF059669),
                    ),
                    _QuickStatPill(
                      label: 'Walk-Ins',
                      value: '$walkInCount',
                      color: const Color(0xFF7C3AED),
                    ),
                  ],
                ),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(
                      value: 0,
                      icon: Icon(Icons.fact_check_outlined, size: 18),
                      label: Text('Online Verification & Check-In'),
                    ),
                    ButtonSegment(
                      value: 1,
                      icon: Icon(Icons.person_add_alt_1, size: 18),
                      label: Text('Walk-In Registration'),
                    ),
                  ],
                  selected: {_tabIndex},
                  onSelectionChanged: (s) =>
                      setState(() => _tabIndex = s.first),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Expanded(
            child: _tabIndex == 0 ? _buildLookupView() : _buildWalkInView(),
          ),
        ],
      ),
    );
  }

  Widget _buildLookupView() {
    final displayed = _filteredRoster;

    return Padding(
      padding: const EdgeInsets.all(28.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            children: [
              // Search and filter bar
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchCtrl,
                        onChanged: (_) {
                          _debounce?.cancel();
                          _debounce = Timer(
                            const Duration(milliseconds: 280),
                            _loadRoster,
                          );
                        },
                        decoration: InputDecoration(
                          hintText:
                              'Search by Student ID, Full Name, University Email, or Section (e.g., 2230001, Dela Cruz, BSCS 3A)...',
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Color(0xFF0284C7),
                          ),
                          suffixIcon: _searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    _loadRoster();
                                  },
                                  icon: const Icon(Icons.clear),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            const Text(
                              'Quick Filter:',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(width: 10),
                            _buildFilterChip('ALL', 'All Attendees'),
                            const SizedBox(width: 8),
                            _buildFilterChip('ABSENT', 'Pending Check-In'),
                            const SizedBox(width: 8),
                            _buildFilterChip('PRESENT', 'Already Present'),
                            const SizedBox(width: 8),
                            _buildFilterChip(
                              'PRE_REGISTERED',
                              'Pre-Registered Online',
                            ),
                            const SizedBox(width: 8),
                            _buildFilterChip('WALK_IN', 'Walk-In Only'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Roster Table Card
              Expanded(
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : displayed.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(18),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: const Icon(
                                        Icons.person_search_outlined,
                                        size: 42,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'No Matching Online Pre-Registration Found',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'If this student has not registered online, register them right now as a Walk-In.',
                                      style: TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 13.5,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    FilledButton.icon(
                                      style: FilledButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF0284C7),
                                      ),
                                      onPressed: () {
                                        final q = _searchCtrl.text.trim();
                                        if (q.isNotEmpty) {
                                          _idCtrl.text = q;
                                          _scheduleDuplicateCheck();
                                        }
                                        setState(() => _tabIndex = 1);
                                      },
                                      icon: const Icon(Icons.person_add_alt_1),
                                      label: const Text(
                                        'Transfer to Walk-In Registration',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.separated(
                              itemCount: displayed.length,
                              separatorBuilder: (_, __) => const Divider(
                                height: 1,
                                color: Color(0xFFF1F5F9),
                              ),
                              itemBuilder: (context, idx) {
                                final item = displayed[idx];
                                final isWalkIn =
                                    item.registrationType == 'WALK_IN';
                                final initials = item.fullName.isNotEmpty
                                    ? item.fullName
                                        .trim()
                                        .substring(0, 1)
                                        .toUpperCase()
                                    : '?';

                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 14,
                                  ),
                                  child: Wrap(
                                    spacing: 16,
                                    runSpacing: 12,
                                    alignment: WrapAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          CircleAvatar(
                                            radius: 22,
                                            backgroundColor: item.isPresent
                                                ? const Color(0xFFD1FAE5)
                                                : const Color(0xFFE0F2FE),
                                            child: Text(
                                              initials,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                color: item.isPresent
                                                    ? const Color(0xFF065F46)
                                                    : const Color(0xFF0369A1),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              maxWidth: 460,
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Wrap(
                                                  spacing: 8,
                                                  runSpacing: 4,
                                                  crossAxisAlignment:
                                                      WrapCrossAlignment.center,
                                                  children: [
                                                    Text(
                                                      item.fullName,
                                                      style: const TextStyle(
                                                        fontSize: 15.5,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color:
                                                            Color(0xFF0F172A),
                                                      ),
                                                    ),
                                                    _StatusBadge(
                                                      label: isWalkIn
                                                          ? 'WALK-IN'
                                                          : 'ONLINE PRE-REG',
                                                      bgColor: isWalkIn
                                                          ? const Color(
                                                              0xFFF3E8FF,
                                                            )
                                                          : const Color(
                                                              0xFFE0F2FE,
                                                            ),
                                                      textColor: isWalkIn
                                                          ? const Color(
                                                              0xFF6B21A8,
                                                            )
                                                          : const Color(
                                                              0xFF0369A1,
                                                            ),
                                                    ),
                                                    _StatusBadge(
                                                      label: item.isPaid
                                                          ? 'PAID'
                                                          : 'UNPAID',
                                                      bgColor: item.isPaid
                                                          ? const Color(
                                                              0xFFD1FAE5,
                                                            )
                                                          : const Color(
                                                              0xFFFEE2E2,
                                                            ),
                                                      textColor: item.isPaid
                                                          ? const Color(
                                                              0xFF065F46,
                                                            )
                                                          : const Color(
                                                              0xFF991B1B,
                                                            ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'ID: ${item.studentId}  •  ${item.programSection}  •  ${item.email}  •  ${_formatTime(item.timeIn)}',
                                                  style: const TextStyle(
                                                    fontSize: 12.5,
                                                    color: Color(0xFF64748B),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            onPressed: () =>
                                                _showDigitalPassModal(item),
                                            icon: const Icon(
                                              Icons.badge_outlined,
                                              color: Color(0xFF64748B),
                                            ),
                                            tooltip: 'View Pass Details',
                                          ),
                                          const SizedBox(width: 8),
                                          FilledButton.icon(
                                            style: FilledButton.styleFrom(
                                              backgroundColor: item.isPresent
                                                  ? const Color(0xFF059669)
                                                  : const Color(0xFF0284C7),
                                            ),
                                            onPressed: () =>
                                                _togglePresent(item),
                                            icon: Icon(
                                              item.isPresent
                                                  ? Icons.check_circle
                                                  : Icons.login,
                                              size: 18,
                                            ),
                                            label: Text(
                                              item.isPresent
                                                  ? 'PRESENT (Undo)'
                                                  : 'Check-In PRESENT',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final selected = _quickFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _quickFilter = value),
      selectedColor: const Color(0xFFE0F2FE),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: selected ? const Color(0xFF0369A1) : const Color(0xFF475569),
      ),
    );
  }

  Widget _buildWalkInView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3E8FF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.person_add_alt_1,
                                color: Color(0xFF7C3AED),
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Walk-In Desk Registration',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  'Live duplicate detection checks the online database as you type',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (_isCheckingDuplicate)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (_duplicateMatch != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        margin: const EdgeInsets.only(bottom: 22),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFF59E0B)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  color: Color(0xFFB45309),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Duplicate Found: ${_duplicateMatch!.fullName} is Already Registered!',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF92400E),
                                      fontSize: 14.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'ID: ${_duplicateMatch!.studentId}  •  ${_duplicateMatch!.programSection}  •  '
                              'Type: ${_duplicateMatch!.registrationType}  •  '
                              'Attendance: ${_duplicateMatch!.isPresent ? "PRESENT" : "ABSENT"}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF78350F),
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (!_duplicateMatch!.isPresent)
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFFD97706),
                                ),
                                onPressed: () =>
                                    _togglePresent(_duplicateMatch!),
                                icon: const Icon(Icons.check_circle_outline),
                                label: const Text(
                                  'Mark Existing Student PRESENT Now',
                                ),
                              ),
                          ],
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _idCtrl,
                            onChanged: (_) => _scheduleDuplicateCheck(),
                            decoration: const InputDecoration(
                              labelText: 'Student ID Number *',
                              hintText: 'e.g., 2231234',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Required'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: TextFormField(
                            controller: _sectionCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Program & Section *',
                              hintText: 'e.g., BSCS 3A',
                              prefixIcon: Icon(Icons.school_outlined),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Required'
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Full Name (Last Name, First Name M.I.) *',
                        hintText: 'e.g., Dela Cruz, Juan A.',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailCtrl,
                      onChanged: (_) => _scheduleDuplicateCheck(),
                      decoration: const InputDecoration(
                        labelText: 'University Email *',
                        hintText: 'e.g., 2231234@slu.edu.ph',
                        prefixIcon: Icon(Icons.alternate_email),
                      ),
                      validator: (v) => (v == null || !v.contains('@'))
                          ? 'Valid email required'
                          : null,
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Mark as PRESENT immediately',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: const Text(
                              'Logs check-in time upon walk-in registration',
                              style: TextStyle(fontSize: 12),
                            ),
                            value: _markPresentNow,
                            onChanged: (v) =>
                                setState(() => _markPresentNow = v),
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Collected seminar payment at entrance',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: const Text(
                              'Optional: toggle on if paying right now',
                              style: TextStyle(fontSize: 12),
                            ),
                            value: _markPaidNow,
                            onChanged: (v) => setState(() => _markPaidNow = v),
                          ),
                        ],
                      ),
                    ),
                    if (_markPaidNow) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _feeCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Amount Collected (PHP)',
                                prefixIcon: Icon(Icons.payments_outlined),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _paymentMethod,
                              decoration: const InputDecoration(
                                labelText: 'Payment Method',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'CASH',
                                  child: Text('CASH'),
                                ),
                                DropdownMenuItem(
                                  value: 'GCASH',
                                  child: Text('GCASH'),
                                ),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _paymentMethod = v);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed:
                            (_isSubmitting || _duplicateMatch != null)
                                ? null
                                : _submitWalkIn,
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.how_to_reg),
                        label: Text(
                          _markPresentNow
                              ? 'Register Walk-In & Mark Present'
                              : 'Register Walk-In Student',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickStatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _QuickStatPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color bgColor;
  final Color textColor;

  const _StatusBadge({
    required this.label,
    required this.bgColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: textColor,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}