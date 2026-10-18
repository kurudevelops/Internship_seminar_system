import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/config/app_config.dart';
import '../../../core/models/attendee_model.dart';
import '../data/admin_repository.dart';

class AdminScreen extends StatefulWidget {
  final VoidCallback onSwitchRole;

  const AdminScreen({super.key, required this.onSwitchRole});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final AdminRepository _repo = AdminRepository();

  AdminSummaryModel _summary = const AdminSummaryModel();
  List<AttendeeModel> _attendees = [];
  bool _isLoading = false;

  final TextEditingController _searchCtrl = TextEditingController();
  String _regTypeFilter = 'ALL';
  String _presenceFilter = 'ALL';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
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

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);
    try {
      final data = await _repo.fetchDashboard(
        query: _searchCtrl.text,
        registrationType: _regTypeFilter,
        presence: _presenceFilter,
      );
      setState(() {
        _summary = data.summary;
        _attendees = data.attendees;
      });
    } catch (e) {
      _notify(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _togglePresence(AttendeeModel attendee) async {
    try {
      await _repo.togglePresence(attendee.id, !attendee.isPresent);
      _notify(
        'Updated ${attendee.fullName} to ${!attendee.isPresent ? "PRESENT" : "ABSENT"}.',
      );
      await _loadDashboard();
    } catch (e) {
      _notify(e.toString(), isError: true);
    }
  }

  Future<void> _confirmDelete(AttendeeModel attendee) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Remove Attendee Record?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Permanently remove ${attendee.fullName} (${attendee.studentId}) from the seminar database?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Record'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _repo.deleteAttendee(attendee.id);
        _notify('Removed ${attendee.fullName}.');
        await _loadDashboard();
      } catch (e) {
        _notify(e.toString(), isError: true);
      }
    }
  }

  Future<void> _showCreateOrEditDialog({AttendeeModel? existing}) async {
    final isEdit = existing != null;
    final idCtrl = TextEditingController(text: existing?.studentId ?? '');
    final nameCtrl = TextEditingController(text: existing?.fullName ?? '');
    final emailCtrl = TextEditingController(text: existing?.email ?? '');
    final sectionCtrl =
        TextEditingController(text: existing?.programSection ?? '');
    String regType = existing?.registrationType ?? 'PRE_REGISTERED';
    bool isPresent = existing?.isPresent ?? false;
    bool isPaid = existing?.isPaid ?? false;
    String paymentMethod =
        (existing?.paymentMethod == 'NONE' || existing == null)
            ? 'CASH'
            : existing.paymentMethod;
    final amountCtrl = TextEditingController(
      text: existing != null && existing.amountPaid > 0
          ? existing.amountPaid.toStringAsFixed(2)
          : AppConfig.defaultSeminarFee.toStringAsFixed(2),
    );

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(
                isEdit ? 'Edit Student Record' : 'Add Student Record',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: idCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Student ID',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: sectionCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Program & Section',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Full Name (Last, First M.I.)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: emailCtrl,
                        decoration: const InputDecoration(
                          labelText: 'University Email',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: regType,
                        decoration: const InputDecoration(
                          labelText: 'Registration Category',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'PRE_REGISTERED',
                            child: Text('Online Pre-Registered'),
                          ),
                          DropdownMenuItem(
                            value: 'WALK_IN',
                            child: Text('Walk-In Registration'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) setDialogState(() => regType = v);
                        },
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
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
                                'Attendance Status: PRESENT',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              value: isPresent,
                              onChanged: (v) =>
                                  setDialogState(() => isPresent = v),
                            ),
                            const Divider(height: 1),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                'Payment Status: PAID',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              value: isPaid,
                              onChanged: (v) =>
                                  setDialogState(() => isPaid = v),
                            ),
                          ],
                        ),
                      ),
                      if (isPaid) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: amountCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Amount (PHP)',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: paymentMethod,
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
                                    setDialogState(() => paymentMethod = v);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                  ),
                  onPressed: () async {
                    final payload = {
                      'student_id': idCtrl.text.trim(),
                      'full_name': nameCtrl.text.trim(),
                      'email': emailCtrl.text.trim(),
                      'program_section': sectionCtrl.text.trim(),
                      'registration_type': regType,
                      'is_present': isPresent,
                      'is_paid': isPaid,
                      'amount_paid': isPaid
                          ? (double.tryParse(amountCtrl.text.trim()) ?? 0.0)
                          : 0.0,
                      'payment_method': isPaid ? paymentMethod : 'NONE',
                    };
                    try {
                      if (isEdit) {
                        await _repo.updateAttendee(existing.id, payload);
                        _notify('Student record updated.');
                      } else {
                        await _repo.createAttendee(payload);
                        _notify('Student record created.');
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                      await _loadDashboard();
                    } catch (e) {
                      _notify(e.toString(), isError: true);
                    }
                  },
                  child: Text(isEdit ? 'Save Changes' : 'Create Student'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showBulkCsvImportDialog() async {
    final csvCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Bulk Import Online Pre-Registrations',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Paste CSV lines exported from Google Forms or Excel (student_id, full_name, email, program_section). Duplicate IDs or emails are skipped automatically.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: csvCtrl,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText:
                      'student_id,full_name,email,program_section\n'
                      '2230101,Dela Cruz, Juan,2230101@slu.edu.ph,BSCS 3A',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
            ),
            onPressed: () async {
              try {
                final msg = await _repo.importCsv(csvCtrl.text);
                if (ctx.mounted) Navigator.pop(ctx);
                _notify(msg);
                await _loadDashboard();
              } catch (e) {
                _notify(e.toString(), isError: true);
              }
            },
            icon: const Icon(Icons.upload_file, size: 18),
            label: const Text('Import Roster'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _summary.totalRegistered;
    final turnoutRatio =
        total > 0 ? (_summary.totalPresent / total).clamp(0.0, 1.0) : 0.0;
    final preRegRatio = _summary.totalPreRegistered > 0
        ? (_summary.preRegisteredPresent / _summary.totalPreRegistered)
            .clamp(0.0, 1.0)
        : 0.0;

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
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.admin_panel_settings_outlined,
                color: Color(0xFFC4B5FD),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Admin & Execom Command Center',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    'Full turnout analytics, Pre-Registered vs. Walk-In breakdown & CRUD control',
                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFF334155)),
              backgroundColor: const Color(0xFF1E293B),
            ),
            onPressed: _showBulkCsvImportDialog,
            icon: const Icon(Icons.upload_file, size: 17),
            label: const Text('Import CSV'),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
            ),
            onPressed: () => _showCreateOrEditDialog(),
            icon: const Icon(Icons.person_add_alt_1, size: 17),
            label: const Text('Add Student'),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _loadDashboard,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Data',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton(
              onPressed: widget.onSwitchRole,
              icon: const Icon(Icons.swap_horiz),
              tooltip: 'Switch Station',
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 4 Executive KPI Cards
                Wrap(
                  spacing: 18,
                  runSpacing: 18,
                  children: [
                    _AdminKpiCard(
                      label: 'TOTAL PRE-REGISTERED',
                      value: '${_summary.totalPreRegistered}',
                      subtext:
                          'Present: ${_summary.preRegisteredPresent}   •   Absent: ${_summary.preRegisteredAbsent}',
                      progress: preRegRatio,
                      accentColor: const Color(0xFF0284C7),
                      icon: Icons.assignment_ind_outlined,
                    ),
                    _AdminKpiCard(
                      label: 'TOTAL WALK-IN',
                      value: '${_summary.totalWalkIn}',
                      subtext:
                          'Present: ${_summary.walkInPresent}   •   Absent: ${_summary.walkInAbsent}',
                      progress: _summary.totalWalkIn > 0
                          ? (_summary.walkInPresent / _summary.totalWalkIn)
                              .clamp(0.0, 1.0)
                          : 0.0,
                      accentColor: const Color(0xFF7C3AED),
                      icon: Icons.directions_walk,
                    ),
                    _AdminKpiCard(
                      label: 'TOTAL ATTENDANCE (PRESENT)',
                      value: '${_summary.totalPresent}',
                      subtext:
                          'Pre-Reg: ${_summary.preRegisteredPresent} + Walk-In: ${_summary.walkInPresent} (${(turnoutRatio * 100).toStringAsFixed(0)}% Turnout)',
                      progress: turnoutRatio,
                      accentColor: const Color(0xFF059669),
                      icon: Icons.how_to_reg,
                    ),
                    _AdminKpiCard(
                      label: 'TOTAL ABSENT',
                      value: '${_summary.totalAbsent}',
                      subtext:
                          'Pre-Reg Absent: ${_summary.preRegisteredAbsent} + Walk-In Absent: ${_summary.walkInAbsent}',
                      progress: total > 0
                          ? (_summary.totalAbsent / total).clamp(0.0, 1.0)
                          : 0.0,
                      accentColor: const Color(0xFFDC2626),
                      icon: Icons.person_off_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Filter & Search Control Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: 420,
                          child: TextField(
                            controller: _searchCtrl,
                            onChanged: (_) {
                              _debounce?.cancel();
                              _debounce = Timer(
                                const Duration(milliseconds: 300),
                                _loadDashboard,
                              );
                            },
                            decoration: InputDecoration(
                              hintText:
                                  'Search student ID, full name, email, or section...',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _searchCtrl.text.isNotEmpty
                                  ? IconButton(
                                      onPressed: () {
                                        _searchCtrl.clear();
                                        _loadDashboard();
                                      },
                                      icon: const Icon(Icons.clear),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                        Wrap(
                          spacing: 12,
                          runSpacing: 10,
                          children: [
                            _dropdownBox(
                              value: _regTypeFilter,
                              items: const [
                                DropdownMenuItem(
                                  value: 'ALL',
                                  child: Text('All Registration Types'),
                                ),
                                DropdownMenuItem(
                                  value: 'PRE_REGISTERED',
                                  child: Text('Online Pre-Registered'),
                                ),
                                DropdownMenuItem(
                                  value: 'WALK_IN',
                                  child: Text('Walk-In Only'),
                                ),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _regTypeFilter = v);
                                  _loadDashboard();
                                }
                              },
                            ),
                            _dropdownBox(
                              value: _presenceFilter,
                              items: const [
                                DropdownMenuItem(
                                  value: 'ALL',
                                  child: Text('All Attendance States'),
                                ),
                                DropdownMenuItem(
                                  value: 'PRESENT',
                                  child: Text('Present Only'),
                                ),
                                DropdownMenuItem(
                                  value: 'ABSENT',
                                  child: Text('Absent Only'),
                                ),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _presenceFilter = v);
                                  _loadDashboard();
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Master Roster List Card
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 14,
                        ),
                        color: const Color(0xFFF8FAFC),
                        child: Text(
                          'MASTER ROSTER (${_attendees.length} RECORDS SHOWN)',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF475569),
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.all(48.0),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_attendees.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(48.0),
                          child: Center(
                            child: Text(
                              'No student records match the current filters.',
                              style: TextStyle(color: Color(0xFF64748B)),
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _attendees.length,
                          separatorBuilder: (_, __) => const Divider(
                            height: 1,
                            color: Color(0xFFF1F5F9),
                          ),
                          itemBuilder: (context, idx) {
                            final item = _attendees[idx];
                            final isWalkIn =
                                item.registrationType == 'WALK_IN';
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: 14,
                              ),
                              child: Wrap(
                                spacing: 16,
                                runSpacing: 12,
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 540),
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
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                            _pill(
                                              isWalkIn
                                                  ? 'WALK-IN'
                                                  : 'PRE-REGISTERED',
                                              isWalkIn
                                                  ? const Color(0xFFF3E8FF)
                                                  : const Color(0xFFE0F2FE),
                                              isWalkIn
                                                  ? const Color(0xFF6B21A8)
                                                  : const Color(0xFF0369A1),
                                            ),
                                            _pill(
                                              item.isPaid
                                                  ? 'PAID (PHP ${item.amountPaid.toStringAsFixed(0)})'
                                                  : 'UNPAID',
                                              item.isPaid
                                                  ? const Color(0xFFD1FAE5)
                                                  : const Color(0xFFFEE2E2),
                                              item.isPaid
                                                  ? const Color(0xFF065F46)
                                                  : const Color(0xFF991B1B),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'ID: ${item.studentId}  •  ${item.programSection}  •  ${item.email}',
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Wrap(
                                    spacing: 8,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      InkWell(
                                        borderRadius: BorderRadius.circular(10),
                                        onTap: () => _togglePresence(item),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: item.isPresent
                                                ? const Color(0xFFD1FAE5)
                                                : const Color(0xFFFEE2E2),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border.all(
                                              color: item.isPresent
                                                  ? const Color(0xFF34D399)
                                                  : const Color(0xFFFCA5A5),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                item.isPresent
                                                    ? Icons.check_circle
                                                    : Icons.cancel_outlined,
                                                size: 16,
                                                color: item.isPresent
                                                    ? const Color(0xFF065F46)
                                                    : const Color(0xFF991B1B),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                item.isPresent
                                                    ? 'PRESENT'
                                                    : 'ABSENT',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w800,
                                                  color: item.isPresent
                                                      ? const Color(0xFF065F46)
                                                      : const Color(0xFF991B1B),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () =>
                                            _showCreateOrEditDialog(
                                          existing: item,
                                        ),
                                        icon: const Icon(
                                          Icons.edit_outlined,
                                          size: 20,
                                          color: Color(0xFF475569),
                                        ),
                                        tooltip: 'Edit Student',
                                      ),
                                      IconButton(
                                        onPressed: () => _confirmDelete(item),
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 20,
                                          color: Color(0xFFDC2626),
                                        ),
                                        tooltip: 'Remove Student',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pill(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }

  Widget _dropdownBox({
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonHideUnderline(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: DropdownButton<String>(
          value: value,
          items: items,
          onChanged: onChanged,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
          ),
        ),
      ),
    );
  }
}

class _AdminKpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String subtext;
  final double progress;
  final Color accentColor;
  final IconData icon;

  const _AdminKpiCard({
    required this.label,
    required this.value,
    required this.subtext,
    required this.progress,
    required this.accentColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 290,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: accentColor,
                  letterSpacing: 0.6,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accentColor, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: const Color(0xFFF1F5F9),
              color: accentColor,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtext,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}