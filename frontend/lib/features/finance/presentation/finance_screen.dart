import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/config/app_config.dart';
import '../../../core/models/attendee_model.dart';
import '../data/finance_repository.dart';

class FinanceScreen extends StatefulWidget {
  final VoidCallback onSwitchRole;

  const FinanceScreen({super.key, required this.onSwitchRole});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  final FinanceRepository _repo = FinanceRepository();
  final NumberFormat _currency = NumberFormat.currency(symbol: 'PHP ', decimalDigits: 2);

  FinanceSummaryModel _summary = const FinanceSummaryModel();
  List<AttendeeModel> _attendees = [];
  bool _isLoading = false;

  final TextEditingController _searchCtrl = TextEditingController();
  String _paymentFilter = 'ALL';
  String _regTypeFilter = 'ALL';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadLedger();
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

  Future<void> _loadLedger() async {
    setState(() => _isLoading = true);
    try {
      final data = await _repo.fetchLedger(
        query: _searchCtrl.text,
        paymentStatus: _paymentFilter,
        registrationType: _regTypeFilter,
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

  Future<void> _showPaymentDialog(AttendeeModel attendee) async {
    bool isPaid = !attendee.isPaid ? true : attendee.isPaid;
    String method = attendee.paymentMethod == 'NONE' ? 'CASH' : attendee.paymentMethod;
    final amountCtrl = TextEditingController(
      text: attendee.amountPaid > 0
          ? attendee.amountPaid.toStringAsFixed(2)
          : AppConfig.defaultSeminarFee.toStringAsFixed(2),
    );

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text('Payment — ${attendee.fullName}'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Payment Status: PAID',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      value: isPaid,
                      onChanged: (v) => setDialogState(() => isPaid = v),
                    ),
                    if (isPaid) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: amountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Amount Paid (PHP)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: method,
                        decoration: const InputDecoration(
                          labelText: 'Payment Method',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'CASH', child: Text('CASH')),
                          DropdownMenuItem(value: 'GCASH', child: Text('GCASH')),
                        ],
                        onChanged: (v) {
                          if (v != null) setDialogState(() => method = v);
                        },
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final amt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                    try {
                      await _repo.updatePayment(
                        attendeeId: attendee.id,
                        isPaid: isPaid,
                        amountPaid: isPaid ? amt : 0.0,
                        paymentMethod: isPaid ? method : 'NONE',
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      _notify('Updated payment for ${attendee.fullName}.');
                      await _loadLedger();
                    } catch (e) {
                      _notify(e.toString(), isError: true);
                    }
                  },
                  child: const Text('Save Payment'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF15803D),
        foregroundColor: Colors.white,
        title: const Text('Finance Portal — Collections & Total Earnings'),
        actions: [
          IconButton(
            onPressed: _loadLedger,
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
          _buildFinanceSummaryStrip(),
          const Divider(height: 1),
          Expanded(child: _buildLedgerList()),
        ],
      ),
    );
  }

  Widget _buildFinanceSummaryStrip() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Wrap(
        spacing: 14,
        runSpacing: 14,
        children: [
          _financeCard(
            title: 'Total Earnings Collected',
            value: _currency.format(_summary.totalEarnings),
            subtitle:
                'Cash: ${_currency.format(_summary.cashEarnings)}  |  GCash: ${_currency.format(_summary.gcashEarnings)}',
            color: const Color(0xFF15803D),
          ),
          _financeCard(
            title: 'Paid Students',
            value: '${_summary.totalPaidCount} / ${_summary.totalAttendees}',
            subtitle:
                'Pre-Reg: ${_currency.format(_summary.preRegisteredEarnings)}  |  Walk-In: ${_currency.format(_summary.walkInEarnings)}',
            color: const Color(0xFF0284C7),
          ),
          _financeCard(
            title: 'Unpaid Students',
            value: '${_summary.totalUnpaidCount}',
            subtitle:
                'Est. Uncollected: ${_currency.format(_summary.estimatedUncollected)}',
            color: const Color(0xFFB91C1C),
          ),
        ],
      ),
    );
  }

  Widget _financeCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
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
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
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

  Widget _buildLedgerList() {
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
                      _loadLedger,
                    );
                  },
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    hintText: 'Search Student ID, Name, or Section...',
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
                    value: _paymentFilter,
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('All Payment Statuses')),
                      DropdownMenuItem(value: 'PAID', child: Text('Paid Only')),
                      DropdownMenuItem(value: 'UNPAID', child: Text('Unpaid Only')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _paymentFilter = v);
                        _loadLedger();
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
                    value: _regTypeFilter,
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('All Registration Types')),
                      DropdownMenuItem(value: 'PRE_REGISTERED', child: Text('Pre-Registered Only')),
                      DropdownMenuItem(value: 'WALK_IN', child: Text('Walk-In Only')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _regTypeFilter = v);
                        _loadLedger();
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
                      ? const Center(child: Text('No records found.'))
                      : ListView.separated(
                          itemCount: _attendees.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, idx) {
                            final item = _attendees[idx];
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
                                      item.registrationType == 'WALK_IN'
                                          ? 'WALK-IN'
                                          : 'PRE-REGISTERED',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  const SizedBox(width: 6),
                                  Chip(
                                    label: Text(
                                      item.isPresent ? 'PRESENT' : 'ABSENT',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                '${item.programSection} • ${item.email} • '
                                'Method: ${item.paymentMethod}',
                              ),
                              trailing: Wrap(
                                spacing: 12,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    item.isPaid
                                        ? _currency.format(item.amountPaid)
                                        : 'PHP 0.00',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: item.isPaid
                                          ? Colors.green.shade800
                                          : Colors.red.shade800,
                                    ),
                                  ),
                                  FilledButton.tonalIcon(
                                    onPressed: () => _showPaymentDialog(item),
                                    icon: Icon(
                                      item.isPaid
                                          ? Icons.receipt_long
                                          : Icons.payments_outlined,
                                    ),
                                    label: Text(
                                      item.isPaid ? 'PAID (Edit)' : 'Record Payment',
                                    ),
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