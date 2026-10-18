import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/config/app_config.dart';
import '../../../core/models/attendee_model.dart';
import '../../../core/ui/station_shell.dart';
import '../data/entrance_repository.dart';
import '../../../core/network/realtime_sync_service.dart';

class EntranceScreen extends StatefulWidget {
  final VoidCallback onSwitchRole;

  const EntranceScreen({super.key, required this.onSwitchRole});

  @override
  State<EntranceScreen> createState() => _EntranceScreenState();
}

class _EntranceScreenState extends State<EntranceScreen> {
  final EntranceRepository _repo = EntranceRepository();
  late final RealtimeSyncService _realtimeSync;
  final NumberFormat _money = NumberFormat('#,##0');
  int _tabIndex = 0;

  // Lookup & Check-In State
  List<AttendeeModel> _roster = [];
  // Unfiltered roster, so the header stats don't shrink while searching.
  List<AttendeeModel> _allRoster = [];
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
    // Automatically syncs new walk-ins & check-ins from other ushers every 4 seconds
    _realtimeSync = RealtimeSyncService(
      onSyncRequested: () {
        _loadRoster(silent: true);
        if (_tabIndex == 1) {
          _checkDuplicateLive(silent: true);
        }
      },
    )..start(interval: const Duration(seconds: 4));
  }

  @override
  void dispose() {
    _realtimeSync.stop();
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

  String _timeOrDash(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    return _formatTime(iso);
  }

  Future<void> _loadRoster({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoading = true);
    }
    try {
      final list = await _repo.searchRoster(_searchCtrl.text);
      if (mounted) {
        setState(() {
          _roster = list;
          if (_searchCtrl.text.trim().isEmpty) _allRoster = list;
        });
      }
    } catch (e) {
      if (!silent) {
        _notify(e.toString(), isError: true);
      }
    } finally {
      if (mounted && !silent) {
        setState(() => _isLoading = false);
      }
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
    _dupTimer = Timer(const Duration(milliseconds: 350), _checkDuplicateLive);
  }

  Future<void> _checkDuplicateLive({bool silent = false}) async {
    final sid = _idCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    if (sid.isEmpty && email.isEmpty) {
      setState(() {
        _duplicateMatch = null;
        _isCheckingDuplicate = false;
      });
      return;
    }
    if (!silent) {
      setState(() => _isCheckingDuplicate = true);
    }
    try {
      final res = await _repo.verifyOnline(studentId: sid, email: email);
      if (mounted) {
        setState(() => _duplicateMatch = res.registered ? res.attendee : null);
      }
    } catch (_) {
    } finally {
      if (mounted && !silent) {
        setState(() => _isCheckingDuplicate = false);
      }
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
                    colors: [AppColors.indigo, AppColors.navy],
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
                          attendee.isPresent ? Icons.verified : Icons.schedule,
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
                        color: Color(0xFFE0E7FF),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${EventInfo.dateLabel}  •  ${EventInfo.venue}',
                      style: const TextStyle(
                        color: Color(0xFFC7D2FE),
                        fontSize: 11.5,
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
    final all = _allRoster.isNotEmpty ? _allRoster : _roster;
    final total = all.length;
    final present = all.where((a) => a.isPresent).length;
    final pending = total - present;
    final online = all.where((a) => a.registrationType == 'PRE_REGISTERED').length;
    final walkIn = all.where((a) => a.registrationType == 'WALK_IN').length;
    final paidCount = all.where((a) => a.isPaid).length;
    final collected = all.fold<double>(0, (sum, a) => sum + a.amountPaid);
    final pct = total > 0 ? (present / total * 100).round() : 0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          StationHeader(
            stationLabel: 'Entrance Desk  •  Live Sync',
            stationIcon: Icons.how_to_reg,
            stationAccent: const Color(0xFF10B981),
            actions: [
              HeaderIconButton(
                icon: Icons.refresh,
                tooltip: 'Sync Roster',
                onPressed: () => _loadRoster(),
              ),
              HeaderButton(
                icon: Icons.swap_horiz,
                label: 'Switch Station',
                onPressed: widget.onSwitchRole,
              ),
            ],
            stats: [
              HeaderStat(
                label: 'TOTAL ROSTER',
                value: '$total',
                rightLabel: '$online Online',
                icon: Icons.groups_2_outlined,
                accent: const Color(0xFF94A3B8),
              ),
              HeaderStat(
                label: 'TOTAL CHECKED-IN',
                value: '$present',
                valueNote: '($pct%)',
                rightLabel: '$pending Pending',
                icon: Icons.how_to_reg_outlined,
                accent: const Color(0xFF38BDF8),
              ),
              HeaderStat(
                label: 'WALK-IN REGISTRANTS',
                value: '$walkIn',
                rightLabel: 'On-Site Desk',
                icon: Icons.directions_walk,
                accent: const Color(0xFFA78BFA),
              ),
              HeaderStat(
                label: 'PAYMENTS COLLECTED',
                value: '$paidCount',
                rightLabel: 'PHP ${_money.format(collected)}',
                icon: Icons.payments_outlined,
                accent: const Color(0xFF34D399),
              ),
            ],
            tabs: [
              StationTabData(
                label: 'Quick Lookup & Check-In',
                icon: Icons.search,
                badge: '$pending Pending',
              ),
              const StationTabData(
                label: 'Walk-In Registration',
                icon: Icons.person_add_alt_1,
              ),
            ],
            selectedTab: _tabIndex,
            onTabChanged: (i) => setState(() => _tabIndex = i),
          ),
          Expanded(
            child: _tabIndex == 0 ? _buildLookupView() : _buildWalkInView(),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Quick Lookup & Check-In
  // ---------------------------------------------------------------------------

  Widget _buildLookupView() {
    final displayed = _filteredRoster;

    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 1000 ? 2 : 1;
        final narrow = c.maxWidth < 560;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(28, 28, 28, 4),
                  sliver: SliverToBoxAdapter(child: _buildSearchCard()),
                ),
                if (_isLoading)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(64),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                else if (displayed.isEmpty)
                  SliverToBoxAdapter(child: _buildEmptyState())
                else
                  SliverPadding(
                    padding: const EdgeInsets.all(28),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => _buildAttendeeCard(displayed[i]),
                        childCount: displayed.length,
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        crossAxisSpacing: 20,
                        mainAxisSpacing: 20,
                        mainAxisExtent: narrow ? 316 : 244,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 20,
            runSpacing: 14,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.search, color: AppColors.indigo, size: 22),
                        SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            'Pre-Registration Verification & Express Check-In',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Verify if a student is already registered online by typing their Student ID, Name, University Email, or Section.',
                      style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _filterPill('ALL', 'All Records'),
                  _filterPill('ABSENT', 'Pending Check-In'),
                  _filterPill('PRESENT', 'In Hall (Checked-In)'),
                  _filterPill('PRE_REGISTERED', 'Pre-Registered Online'),
                  _filterPill('WALK_IN', 'Walk-In Only'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _searchCtrl,
            onChanged: (_) {
              setState(() {});
              _debounce?.cancel();
              _debounce = Timer(
                const Duration(milliseconds: 280),
                _loadRoster,
              );
            },
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
              hintText:
                  'Type Student ID (e.g. 2230001), Full Name (e.g. Dela Cruz), Email, or Section (e.g. BSCS 3A)...',
              prefixIcon: const Icon(Icons.search, color: AppColors.muted),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() {});
                        _loadRoster();
                      },
                      icon: const Icon(Icons.clear),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterPill(String value, String label) {
    final selected = _quickFilter == value;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() => _quickFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.indigo : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Icon(
                Icons.person_search_outlined,
                size: 42,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Matching Online Pre-Registration Found',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'If this student has not registered online, register them right now as a Walk-In.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 13.5),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.indigo),
              onPressed: () {
                final q = _searchCtrl.text.trim();
                if (q.isNotEmpty) {
                  _idCtrl.text = q;
                  _scheduleDuplicateCheck();
                }
                setState(() => _tabIndex = 1);
              },
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Transfer to Walk-In Registration'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendeeCard(AttendeeModel item) {
    final isWalkIn = item.registrationType == 'WALK_IN';

    final StatusBadge status = item.isPresent
        ? const StatusBadge(
            label: 'Checked-In (In Hall)',
            icon: Icons.schedule,
            bg: AppColors.blueSoft,
            fg: AppColors.blue,
          )
        : StatusBadge(
            label: isWalkIn ? 'Walk-In (Pending)' : 'Pre-Registered (Pending)',
            icon: Icons.warning_amber_rounded,
            bg: AppColors.amberSoft,
            fg: AppColors.amber,
          );

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TagChip(
                      label: item.studentId,
                      bg: const Color(0xFFF1F5F9),
                      fg: AppColors.ink,
                      borderColor: AppColors.border,
                      mono: true,
                    ),
                    TagChip(
                      label: isWalkIn ? 'Walk-In' : 'Online Pre-Reg',
                      bg: isWalkIn ? AppColors.violetSoft : AppColors.blueSoft,
                      fg: isWalkIn ? AppColors.violet : AppColors.blue,
                    ),
                    TagChip(
                      label: item.programSection,
                      bg: AppColors.indigoSoft,
                      fg: AppColors.indigo,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              status,
            ],
          ),
          const SizedBox(height: 14),
          Text(
            item.fullName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.email,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
          ),
          const SizedBox(height: 6),
          Text(
            item.isPaid
                ? 'PAID  •  PHP ${item.amountPaid.toStringAsFixed(0)} via ${item.paymentMethod}'
                : 'UNPAID',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: item.isPaid ? AppColors.emerald : const Color(0xFFDC2626),
            ),
          ),
          const Spacer(),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Time-In: ',
                    style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                  ),
                  Text(
                    _timeOrDash(item.timeIn),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color:
                          item.isPresent ? AppColors.emerald : AppColors.muted,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFF1F5F9),
                      foregroundColor: const Color(0xFF334155),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                    onPressed: () => _showDigitalPassModal(item),
                    icon: const Icon(Icons.qr_code_2, size: 18),
                    label: const Text('Pass'),
                  ),
                  const SizedBox(width: 8),
                  if (item.isPresent)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF334155),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                      onPressed: () => _togglePresent(item),
                      icon: const Icon(Icons.undo, size: 17),
                      label: const Text('Undo Check-In'),
                    )
                  else
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.indigo,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onPressed: () => _togglePresent(item),
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Check-In Now'),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Walk-In Registration
  // ---------------------------------------------------------------------------

  Widget _buildWalkInView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.indigoSoft,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.person_add_alt_1,
                                color: AppColors.indigo,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Walk-In Desk Registration',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                  Text(
                                    'Live duplicate detection checks the online database as you type',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
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
                              onPressed: () => _togglePresent(_duplicateMatch!),
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
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Required' : null,
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
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Required' : null,
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
                      border: Border.all(color: AppColors.border),
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
                          onChanged: (v) => setState(() => _markPresentNow = v),
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
                        backgroundColor: AppColors.indigo,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: (_isSubmitting || _duplicateMatch != null)
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
    );
  }
}
