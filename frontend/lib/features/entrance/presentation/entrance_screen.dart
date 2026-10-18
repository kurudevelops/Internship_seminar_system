import 'dart:async';
import 'package:flutter/material.dart';
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
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade800 : Colors.green.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
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

  Future<void> _togglePresent(AttendeeModel attendee) async {
    try {
      await _repo.setAttendance(attendee.studentId, !attendee.isPresent);
      _notify(
        'Marked ${attendee.fullName} as ${!attendee.isPresent ? "PRESENT" : "ABSENT"}.',
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

  Future<void> _checkDuplicateLive() async {
    final sid = _idCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    if (sid.isEmpty && email.isEmpty) {
      setState(() => _duplicateMatch = null);
      return;
    }
    try {
      final res = await _repo.verifyOnline(studentId: sid, email: email);
      if (mounted) {
        setState(() => _duplicateMatch = res.registered ? res.attendee : null);
      }
    } catch (_) {}
  }

  Future<void> _submitWalkIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      final amount = double.tryParse(_feeCtrl.text.trim()) ?? 0.0;
      await _repo.registerWalkIn(
        studentId: _idCtrl.text.trim(),
        fullName: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        programSection: _sectionCtrl.text.trim(),
        markPresentNow: _markPresentNow,
        markPaidNow: _markPaidNow,
        amountPaid: _markPaidNow ? amount : 0.0,
        paymentMethod: _markPaidNow ? _paymentMethod : 'NONE',
      );
      _notify('Walk-in registered successfully!');
      _idCtrl.clear();
      _nameCtrl.clear();
      _emailCtrl.clear();
      _sectionCtrl.clear();
      setState(() {
        _duplicateMatch = null;
        _tabIndex = 0;
      });
      await _loadRoster();
    } catch (e) {
      _notify(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0284C7),
        foregroundColor: Colors.white,
        title: const Text('Entrance Desk — Online Check & Walk-In Registration'),
        actions: [
          IconButton(
            onPressed: _loadRoster,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Roster',
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
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 0,
                  icon: Icon(Icons.qr_code_scanner),
                  label: Text('Check Online Registration & Mark Present'),
                ),
                ButtonSegment(
                  value: 1,
                  icon: Icon(Icons.person_add_alt_1),
                  label: Text('Register Walk-In Student'),
                ),
              ],
              selected: {_tabIndex},
              onSelectionChanged: (s) => setState(() => _tabIndex = s.first),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _tabIndex == 0 ? _buildCheckInTab() : _buildWalkInTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckInTab() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            onChanged: (_) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 300), _loadRoster);
            },
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              hintText:
                  'Type Student ID, Full Name, or Section to check if already registered online...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        _searchCtrl.clear();
                        _loadRoster();
                      },
                      icon: const Icon(Icons.clear),
                    )
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              color: Colors.white,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _roster.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.search_off, size: 48, color: Colors.black38),
                              const SizedBox(height: 10),
                              const Text(
                                'Student not found in Online Pre-Registration Roster.',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: () {
                                  _idCtrl.text = _searchCtrl.text.trim();
                                  _scheduleDuplicateCheck();
                                  setState(() => _tabIndex = 1);
                                },
                                icon: const Icon(Icons.person_add),
                                label: const Text('Register as Walk-In Instead'),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: _roster.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, idx) {
                            final item = _roster[idx];
                            final isWalkIn = item.registrationType == 'WALK_IN';
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 8,
                              ),
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
                                  const SizedBox(width: 6),
                                  Chip(
                                    label: Text(
                                      item.isPaid ? 'PAID' : 'UNPAID',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: item.isPaid
                                            ? Colors.green.shade900
                                            : Colors.red.shade900,
                                      ),
                                    ),
                                    backgroundColor: item.isPaid
                                        ? Colors.green.shade100
                                        : Colors.red.shade100,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                              subtitle: Text('${item.programSection} • ${item.email}'),
                              trailing: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: item.isPresent
                                      ? Colors.green.shade700
                                      : const Color(0xFF0284C7),
                                ),
                                onPressed: () => _togglePresent(item),
                                icon: Icon(
                                  item.isPresent
                                      ? Icons.check_circle
                                      : Icons.login,
                                ),
                                label: Text(
                                  item.isPresent
                                      ? 'PRESENT (Tap to Undo)'
                                      : 'Mark PRESENT',
                                ),
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

  Widget _buildWalkInTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Card(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(28.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Walk-In Student Registration',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Automatically checks if the student is already registered online as you type.',
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 20),
                    if (_duplicateMatch != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.amber.shade400),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Already Registered Online: ${_duplicateMatch!.fullName}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'ID: ${_duplicateMatch!.studentId} • ${_duplicateMatch!.programSection} • '
                              'Status: ${_duplicateMatch!.isPresent ? "PRESENT" : "ABSENT"}',
                            ),
                            const SizedBox(height: 10),
                            if (!_duplicateMatch!.isPresent)
                              FilledButton.icon(
                                onPressed: () => _togglePresent(_duplicateMatch!),
                                icon: const Icon(Icons.check),
                                label: const Text('Mark Existing Student PRESENT Now'),
                              ),
                          ],
                        ),
                      ),
                    TextFormField(
                      controller: _idCtrl,
                      onChanged: (_) => _scheduleDuplicateCheck(),
                      decoration: const InputDecoration(
                        labelText: 'Student ID Number *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Full Name (Last, First M.I.) *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _emailCtrl,
                      onChanged: (_) => _scheduleDuplicateCheck(),
                      decoration: const InputDecoration(
                        labelText: 'University Email *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || !v.contains('@'))
                          ? 'Enter valid email'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _sectionCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Program & Year/Section (e.g., BSCS 3A) *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Mark as PRESENT immediately'),
                      value: _markPresentNow,
                      onChanged: (v) => setState(() => _markPresentNow = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Paid seminar fee at entrance'),
                      value: _markPaidNow,
                      onChanged: (v) => setState(() => _markPaidNow = v),
                    ),
                    if (_markPaidNow) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _feeCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Amount Paid (PHP)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _paymentMethod,
                              decoration: const InputDecoration(
                                labelText: 'Method',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'CASH', child: Text('CASH')),
                                DropdownMenuItem(value: 'GCASH', child: Text('GCASH')),
                              ],
                              onChanged: (v) {
                                if (v != null) setState(() => _paymentMethod = v);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: (_isSubmitting || _duplicateMatch != null)
                            ? null
                            : _submitWalkIn,
                        icon: const Icon(Icons.how_to_reg),
                        label: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Text('Register Walk-In Student'),
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