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
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade800 : Colors.green.shade800,
        behavior: SnackBarBehavior.floating,
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
        title: const Text('Remove Attendee Record?'),
        content: Text(
          'Are you sure you want to permanently remove ${attendee.fullName} (${attendee.studentId})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove Record'),
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
    final sectionCtrl = TextEditingController(text: existing?.programSection ?? '');
    String regType = existing?.registrationType ?? 'PRE_REGISTERED';
    bool isPresent = existing?.isPresent ?? false;
    bool isPaid = existing?.isPaid ?? false;
    String paymentMethod = (existing?.paymentMethod == 'NONE' || existing == null)
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
              title: Text(isEdit ? 'Edit Attendee Record' : 'Create Attendee Record'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: idCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Student ID',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: emailCtrl,
                        decoration: const InputDecoration(
                          labelText: 'University Email',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: sectionCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Program & Section (e.g., BSCS 3A)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: regType,
                        decoration: const InputDecoration(
                          labelText: 'Registration Type',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'PRE_REGISTERED',
                            child: Text('Online Pre-Registered'),
                          ),
                          DropdownMenuItem(
                            value: 'WALK_IN',
                            child: Text('Walk-In'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) setDialogState(() => regType = v);
                        },
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Attendance: PRESENT'),
                        subtitle: Text(isPresent ? 'Marked Present' : 'Marked Absent'),
                        value: isPresent,
                        onChanged: (v) => setDialogState(() => isPresent = v),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Finance: PAID'),
                        value: isPaid,
                        onChanged: (v) => setDialogState(() => isPaid = v),
                      ),
                      if (isPaid) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: amountCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Amount (PHP)',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: paymentMethod,
                                decoration: const InputDecoration(
                                  labelText: 'Method',
                                  border: OutlineInputBorder(),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'CASH', child: Text('CASH')),
                                  DropdownMenuItem(value: 'GCASH', child: Text('GCASH')),
                                ],
                                onChanged: (v) {
                                  if (v != null) setDialogState(() => paymentMethod = v);
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
                        _notify('Record updated.');
                      } else {
                        await _repo.createAttendee(payload);
                        _notify('Record created.');
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                      await _loadDashboard();
                    } catch (e) {
                      _notify(e.toString(), isError: true);
                    }
                  },
                  child: Text(isEdit ? 'Save Changes' : 'Create Record'),
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
        title: const Text('Bulk Import Pre-Registered CSV'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: TextField(
            controller: csvCtrl,
            maxLines: 8,
            decoration: const InputDecoration(
              hintText:
                  'student_id,full_name,email,program_section\n'
                  '2230101,Dela Cruz, Juan,2230101@slu.edu.ph,BSCS 3A',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
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
            child: const Text('Import CSV'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4C1D95),
        foregroundColor: Colors.white,
        title: const Text('Admin & Execom Portal — Attendance & Roster Control'),
        actions: [
          FilledButton.tonalIcon(
            onPressed: _showBulkCsvImportDialog,
            icon: const Icon(Icons.upload_file),
            label: const Text('Import CSV'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.amber.shade700),
            onPressed: () => _showCreateOrEditDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Add Student'),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _loadDashboard,
            icon: const Icon(Icons.refresh),
          ),
          TextButton.icon(
            onPressed: widget.onSwitchRole,
            icon: const Icon(Icons.swap_horiz, color: Colors.white),
            label: const Text('Switch Role', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildAdminAnalyticsHeader(),
          const Divider(height: 1),
          Expanded(child: _buildAdminRosterTable()),
        ],
      ),
    );
  }

  Widget _buildAdminAnalyticsHeader() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Wrap(
        spacing: 14,
        runSpacing: 14,
        children: [
          _metricCard(
            title: 'Total Pre-Registered',
            value: '${_summary.totalPreRegistered}',
            subtitle:
                'Present: ${_summary.preRegisteredPresent}  |  Absent: ${_summary.preRegisteredAbsent}',
            color: const Color(0xFF0284C7),
          ),
          _metricCard(
            title: 'Total Walk-In',
            value: '${_summary.totalWalkIn}',
            subtitle:
                'Present: ${_summary.walkInPresent}  |  Absent: ${_summary.walkInAbsent}',
            color: const Color(0xFF7C3AED),
          ),
          _metricCard(
            title: 'Total Present (Attendance)',
            value: '${_summary.totalPresent}',
            subtitle:
                'Pre-Reg Present: ${_summary.preRegisteredPresent} + Walk-In Present: ${_summary.walkInPresent}',
            color: const Color(0xFF15803D),
          ),
          _metricCard(
            title: 'Total Absent',
            value: '${_summary.totalAbsent}',
            subtitle:
                'Pre-Reg Absent: ${_summary.preRegisteredAbsent} + Walk-In Absent: ${_summary.walkInAbsent}',
            color: const Color(0xFFB91C1C),
          ),
        ],
      ),
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminRosterTable() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 360,
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
                    filled: true,
                    fillColor: Colors.white,
                    hintText: 'Search ID, Name, Email, or Section...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              DropdownButtonHideUnderline(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: DropdownButton<String>(
                    value: _regTypeFilter,
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('All Registration Types')),
                      DropdownMenuItem(value: 'PRE_REGISTERED', child: Text('Pre-Registered Only')),
                      DropdownMenuItem(value: 'WALK_IN', child: Text('Walk-In Only')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _regTypeFilter = v);
                        _loadDashboard();
                      }
                    },
                  ),
                ),
              ),
              DropdownButtonHideUnderline(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: DropdownButton<String>(
                    value: _presenceFilter,
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('All Attendance')),
                      DropdownMenuItem(value: 'PRESENT', child: Text('Present Only')),
                      DropdownMenuItem(value: 'ABSENT', child: Text('Absent Only')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _presenceFilter = v);
                        _loadDashboard();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              color: Colors.white,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _attendees.isEmpty
                      ? const Center(child: Text('No matching records found.'))
                      : ListView.separated(
                          itemCount: _attendees.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, idx) {
                            final item = _attendees[idx];
                            final isWalkIn = item.registrationType == 'WALK_IN';
                            return ListTile(
                              title: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      '${item.fullName} (${item.studentId})',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Chip(
                                    label: Text(
                                      isWalkIn ? 'WALK-IN' : 'PRE-REGISTERED',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                '${item.programSection} • ${item.email} • '
                                'Finance: ${item.isPaid ? "PAID (PHP ${item.amountPaid.toStringAsFixed(2)})" : "UNPAID"}',
                              ),
                              trailing: Wrap(
                                spacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  FilterChip(
                                    selected: item.isPresent,
                                    selectedColor: Colors.green.shade100,
                                    checkmarkColor: Colors.green.shade900,
                                    label: Text(
                                      item.isPresent ? 'PRESENT' : 'ABSENT',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: item.isPresent
                                            ? Colors.green.shade900
                                            : Colors.red.shade900,
                                      ),
                                    ),
                                    onSelected: (_) => _togglePresence(item),
                                  ),
                                  IconButton(
                                    onPressed: () => _showCreateOrEditDialog(existing: item),
                                    icon: const Icon(Icons.edit_outlined),
                                    tooltip: 'Edit Record',
                                  ),
                                  IconButton(
                                    onPressed: () => _confirmDelete(item),
                                    icon: Icon(Icons.delete_outline, color: Colors.red.shade700),
                                    tooltip: 'Remove Record',
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
    );
  }
}