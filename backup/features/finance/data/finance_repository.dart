import '../../../core/models/attendee_model.dart';
import '../../../core/network/api_client.dart';

class FinanceSummaryModel {
  final double defaultSeminarFee;
  final int totalAttendees;
  final int totalPaidCount;
  final int totalUnpaidCount;
  final double totalEarnings;
  final double preRegisteredEarnings;
  final double walkInEarnings;
  final double cashEarnings;
  final double gcashEarnings;
  final double estimatedUncollected;

  const FinanceSummaryModel({
    this.defaultSeminarFee = 150.0,
    this.totalAttendees = 0,
    this.totalPaidCount = 0,
    this.totalUnpaidCount = 0,
    this.totalEarnings = 0.0,
    this.preRegisteredEarnings = 0.0,
    this.walkInEarnings = 0.0,
    this.cashEarnings = 0.0,
    this.gcashEarnings = 0.0,
    this.estimatedUncollected = 0.0,
  });

  factory FinanceSummaryModel.fromJson(Map<String, dynamic> json) {
    return FinanceSummaryModel(
      defaultSeminarFee: (json['default_seminar_fee'] as num?)?.toDouble() ?? 150.0,
      totalAttendees: (json['total_attendees'] as num?)?.toInt() ?? 0,
      totalPaidCount: (json['total_paid_count'] as num?)?.toInt() ?? 0,
      totalUnpaidCount: (json['total_unpaid_count'] as num?)?.toInt() ?? 0,
      totalEarnings: (json['total_earnings'] as num?)?.toDouble() ?? 0.0,
      preRegisteredEarnings: (json['pre_registered_earnings'] as num?)?.toDouble() ?? 0.0,
      walkInEarnings: (json['walk_in_earnings'] as num?)?.toDouble() ?? 0.0,
      cashEarnings: (json['cash_earnings'] as num?)?.toDouble() ?? 0.0,
      gcashEarnings: (json['gcash_earnings'] as num?)?.toDouble() ?? 0.0,
      estimatedUncollected: (json['estimated_uncollected'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class FinanceLedgerData {
  final FinanceSummaryModel summary;
  final List<AttendeeModel> attendees;

  FinanceLedgerData({required this.summary, required this.attendees});
}

class FinanceRepository {
  Future<FinanceLedgerData> fetchLedger({
    String query = '',
    String paymentStatus = 'ALL',
    String registrationType = 'ALL',
  }) async {
    final res = await ApiClient.get(
      '/api/finance/ledger',
      queryParams: {
        'q': query,
        'payment_status': paymentStatus,
        'registration_type': registrationType,
      },
    );
    final summary = FinanceSummaryModel.fromJson(
      res['summary'] as Map<String, dynamic>? ?? {},
    );
    final list = (res['data'] as List<dynamic>? ?? [])
        .map((e) => AttendeeModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return FinanceLedgerData(summary: summary, attendees: list);
  }

  Future<void> updatePayment({
    required String attendeeId,
    required bool isPaid,
    required double amountPaid,
    required String paymentMethod,
  }) async {
    await ApiClient.patch(
      '/api/finance/payment/$attendeeId',
      body: {
        'is_paid': isPaid,
        'amount_paid': amountPaid,
        'payment_method': paymentMethod,
      },
    );
  }
}