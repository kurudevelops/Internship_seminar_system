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
  final NumberFormat _currency =
      NumberFormat.currency(symbol: 'PHP ', decimalDigits: 2);

  FinanceSummaryModel _summary = const FinanceSummaryModel();
  List<AttendeeModel> _attendees = [];
  bool _isLoading = false;

  final TextEditingController _searchCtrl = TextEditingController();
  String _paymentFilter = 'ALL'; // ALL, PAID, UNPAID
  String _regTypeFilter = 'ALL'; // ALL, PRE_REGISTERED, WALK_IN
  String _channelFilter = 'ALL'; // ALL, CASH, GCASH
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
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor:
            isError ? const Color(0xFFDC2626) : const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String _formatPaidTimestamp(String? iso) {
    if (iso == null || iso.isEmpty) return 'No payment timestamp';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return 'Paid ${DateFormat('MMM d, hh:mm a').format(dt)}';
    } catch (_) {
      return iso;
    }
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

  List<AttendeeModel> get _visibleAttendees {
    if (_channelFilter == 'ALL') return _attendees;
    return _attendees
        .where((a) => a.isPaid && a.paymentMethod == _channelFilter)
        .toList();
  }

  Future<void> _quickCollectDefaultFee(
    AttendeeModel attendee,
    String method,
  ) async {
    try {
      final fee = _summary.defaultSeminarFee > 0
          ? _summary.defaultSeminarFee
          : AppConfig.defaultSeminarFee;
      await _repo.updatePayment(
        attendeeId: attendee.id,
        isPaid: true,
        amountPaid: fee,
        paymentMethod: method,
      );
      _notify(
        'Collected ${_currency.format(fee)} ($method) from ${attendee.fullName}.',
      );
      await _loadLedger();
    } catch (e) {
      _notify(e.toString(), isError: true);
    }
  }

  Future<void> _showPaymentDialog(AttendeeModel attendee) async {
    bool isPaid = !attendee.isPaid ? true : attendee.isPaid;
    String method =
        attendee.paymentMethod == 'NONE' ? 'CASH' : attendee.paymentMethod;
    final defaultFee = _summary.defaultSeminarFee > 0
        ? _summary.defaultSeminarFee
        : AppConfig.defaultSeminarFee;
    final amountCtrl = TextEditingController(
      text: attendee.amountPaid > 0
          ? attendee.amountPaid.toStringAsFixed(2)
          : defaultFee.toStringAsFixed(2),
    );

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(
                'Payment Record — ${attendee.fullName}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ID: ${attendee.studentId}  •  ${attendee.programSection}  •  ${attendee.registrationType}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Payment Status: PAID',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          isPaid
                              ? 'Student has settled the seminar fee'
                              : 'Mark account as unpaid (PHP 0.00)',
                          style: const TextStyle(fontSize: 12),
                        ),
                        value: isPaid,
                        onChanged: (v) => setDialogState(() => isPaid = v),
                      ),
                    ),
                    if (isPaid) ...[
                      const SizedBox(height: 14),
                      TextField(
                        controller: amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Amount Collected (PHP)',
                          prefixIcon: Icon(Icons.payments_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: method,
                        decoration: const InputDecoration(
                          labelText: 'Payment Channel',
                          prefixIcon:
                              Icon(Icons.account_balance_wallet_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'CASH', child: Text('CASH')),
                          DropdownMenuItem(
                            value: 'GCASH',
                            child: Text('GCASH'),
                          ),
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
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: isPaid
                        ? const Color(0xFF059669)
                        : const Color(0xFFDC2626),
                  ),
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
                      _notify('Saved payment record for ${attendee.fullName}.');
                      await _loadLedger();
                    } catch (e) {
                      _notify(e.toString(), isError: true);
                    }
                  },
                  icon: Icon(
                    isPaid ? Icons.check_circle_outline : Icons.money_off,
                    size: 18,
                  ),
                  label: Text(isPaid ? 'Save Payment' : 'Mark Unpaid'),
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
    final total = _summary.totalAttendees;
    final paidRatio =
        total > 0 ? (_summary.totalPaidCount / total).clamp(0.0, 1.0) : 0.0;
    final unpaidRatio =
        total > 0 ? (_summary.totalUnpaidCount / total).clamp(0.0, 1.0) : 0.0;
    final expectedTotal =
        _summary.totalEarnings + _summary.estimatedUncollected;
    final earningsRatio = expectedTotal > 0
        ? (_summary.totalEarnings / expectedTotal).clamp(0.0, 1.0)
        : 0.0;

    final displayed = _visibleAttendees;

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
                color: const Color(0xFF10B981).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.account_balance_wallet_outlined,
                color: Color(0xFF34D399),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Finance & Collections Ledger',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    'Track Paid vs. Unpaid attendees, Cash & GCash channels, and Total Seminar Earnings',
                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadLedger,
            icon: const Icon(Icons.refresh),
            tooltip: 'Sync Ledger',
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 4 Executive Finance KPI Cards
                Wrap(
                  spacing: 18,
                  runSpacing: 18,
                  children: [
                    _FinanceKpiCard(
                      label: 'TOTAL SEMINAR EARNINGS',
                      value: _currency.format(_summary.totalEarnings),
                      subtext:
                          'Pre-Reg: ${_currency.format(_summary.preRegisteredEarnings)}  •  Walk-In: ${_currency.format(_summary.walkInEarnings)}',
                      progress: earningsRatio,
                      accentColor: const Color(0xFF059669),
                      icon: Icons.payments_outlined,
                    ),
                    _FinanceKpiCard(
                      label: 'CASH vs. GCASH BREAKDOWN',
                      value: _currency.format(_summary.cashEarnings),
                      subtext:
                          'Cash On Hand  •  GCash: ${_currency.format(_summary.gcashEarnings)}',
                      progress: _summary.totalEarnings > 0
                          ? (_summary.cashEarnings / _summary.totalEarnings)
                              .clamp(0.0, 1.0)
                          : 0.0,
                      accentColor: const Color(0xFF0284C7),
                      icon: Icons.point_of_sale_outlined,
                    ),
                    _FinanceKpiCard(
                      label:
                          'PAID ACCOUNTS (${(paidRatio * 100).toStringAsFixed(0)}%)',
                      value: '${_summary.totalPaidCount} / $total',
                      subtext:
                          'Standard Seminar Fee: ${_currency.format(_summary.defaultSeminarFee)}',
                      progress: paidRatio,
                      accentColor: const Color(0xFF7C3AED),
                      icon: Icons.verified_outlined,
                    ),
                    _FinanceKpiCard(
                      label: 'UNPAID / RECEIVABLES',
                      value: '${_summary.totalUnpaidCount} Unpaid',
                      subtext:
                          'Est. Uncollected: ${_currency.format(_summary.estimatedUncollected)}',
                      progress: unpaidRatio,
                      accentColor: const Color(0xFFDC2626),
                      icon: Icons.pending_actions_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Search & Multi-Filter Control Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
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
                                    _loadLedger,
                                  );
                                },
                                decoration: InputDecoration(
                                  hintText:
                                      'Search Student ID, Full Name, Email, or Section...',
                                  prefixIcon: const Icon(Icons.search),
                                  suffixIcon: _searchCtrl.text.isNotEmpty
                                      ? IconButton(
                                          onPressed: () {
                                            _searchCtrl.clear();
                                            _loadLedger();
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
                                      _loadLedger();
                                    }
                                  },
                                ),
                                _dropdownBox(
                                  value: _channelFilter,
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'ALL',
                                      child: Text('All Channels'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'CASH',
                                      child: Text('Paid via CASH'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'GCASH',
                                      child: Text('Paid via GCASH'),
                                    ),
                                  ],
                                  onChanged: (v) {
                                    if (v != null) {
                                      setState(() => _channelFilter = v);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              const Text(
                                'Account Status:',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(width: 10),
                              _filterChip('ALL', 'All Accounts'),
                              const SizedBox(width: 8),
                              _filterChip('UNPAID', 'Unpaid Only'),
                              const SizedBox(width: 8),
                              _filterChip('PAID', 'Paid Only'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Financial Ledger Table Card
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
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'FINANCIAL LEDGER (${displayed.length} ACCOUNTS SHOWN)',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF475569),
                                letterSpacing: 0.6,
                              ),
                            ),
                            Text(
                              'Default Fee: ${_currency.format(_summary.defaultSeminarFee)}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF059669),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.all(48.0),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (displayed.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(48.0),
                          child: Center(
                            child: Text(
                              'No matching finance records found.',
                              style: TextStyle(color: Color(0xFF64748B)),
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: displayed.length,
                          separatorBuilder: (_, __) => const Divider(
                            height: 1,
                            color: Color(0xFFF1F5F9),
                          ),
                          itemBuilder: (context, idx) {
                            final item = displayed[idx];
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
                                        const BoxConstraints(maxWidth: 520),
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
                                            _badge(
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
                                            _badge(
                                              item.isPresent
                                                  ? 'PRESENT IN HALL'
                                                  : 'ABSENT',
                                              item.isPresent
                                                  ? const Color(0xFFD1FAE5)
                                                  : const Color(0xFFF1F5F9),
                                              item.isPresent
                                                  ? const Color(0xFF065F46)
                                                  : const Color(0xFF475569),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'ID: ${item.studentId}  •  ${item.programSection}  •  '
                                          '${item.isPaid ? "${item.paymentMethod} (${_formatPaidTimestamp(item.paidAt)})" : "Unpaid Account"}',
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 8,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: item.isPaid
                                              ? const Color(0xFFD1FAE5)
                                              : const Color(0xFFFEE2E2),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          item.isPaid
                                              ? _currency
                                                  .format(item.amountPaid)
                                              : 'UNPAID (PHP 0.00)',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                            color: item.isPaid
                                                ? const Color(0xFF065F46)
                                                : const Color(0xFF991B1B),
                                          ),
                                        ),
                                      ),
                                      if (!item.isPaid) ...[
                                        OutlinedButton.icon(
                                          onPressed: () =>
                                              _quickCollectDefaultFee(
                                            item,
                                            'CASH',
                                          ),
                                          icon: const Icon(
                                            Icons.payments_outlined,
                                            size: 16,
                                          ),
                                          label: const Text('Quick Cash'),
                                        ),
                                        OutlinedButton.icon(
                                          onPressed: () =>
                                              _quickCollectDefaultFee(
                                            item,
                                            'GCASH',
                                          ),
                                          icon: const Icon(
                                            Icons.qr_code,
                                            size: 16,
                                          ),
                                          label: const Text('Quick GCash'),
                                        ),
                                      ],
                                      FilledButton.icon(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: item.isPaid
                                              ? const Color(0xFF334155)
                                              : const Color(0xFF059669),
                                        ),
                                        onPressed: () =>
                                            _showPaymentDialog(item),
                                        icon: Icon(
                                          item.isPaid
                                              ? Icons.edit_outlined
                                              : Icons.add_card,
                                          size: 17,
                                        ),
                                        label: Text(
                                          item.isPaid
                                              ? 'Edit'
                                              : 'Custom Amount',
                                        ),
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

  Widget _filterChip(String value, String label) {
    final selected = _paymentFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() => _paymentFilter = value);
        _loadLedger();
      },
      selectedColor: const Color(0xFFD1FAE5),
      labelStyle: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        color: selected ? const Color(0xFF065F46) : const Color(0xFF475569),
      ),
    );
  }

  Widget _badge(String text, Color bg, Color fg) {
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

class _FinanceKpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String subtext;
  final double progress;
  final Color accentColor;
  final IconData icon;

  const _FinanceKpiCard({
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
              fontSize: 30,
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