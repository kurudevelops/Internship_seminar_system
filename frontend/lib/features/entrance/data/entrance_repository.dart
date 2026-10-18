import '../../../core/models/attendee_model.dart';
import '../../../core/network/api_client.dart';

class EntranceVerificationResult {
  final bool registered;
  final String message;
  final AttendeeModel? attendee;

  EntranceVerificationResult({
    required this.registered,
    required this.message,
    this.attendee,
  });
}

class EntranceRepository {
  Future<List<AttendeeModel>> searchRoster(String query) async {
    final res = await ApiClient.get(
      '/api/entrance/lookup',
      queryParams: {'q': query},
    );
    final raw = res['data'] as List<dynamic>? ?? [];
    return raw
        .map((e) => AttendeeModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<EntranceVerificationResult> verifyOnline({
    String? studentId,
    String? email,
  }) async {
    final res = await ApiClient.get(
      '/api/entrance/verify-online',
      queryParams: {
        if (studentId != null && studentId.isNotEmpty) 'student_id': studentId,
        if (email != null && email.isNotEmpty) 'email': email,
      },
    );
    final reg = res['registered'] == true;
    final att = res['attendee'] != null
        ? AttendeeModel.fromJson(res['attendee'] as Map<String, dynamic>)
        : null;
    return EntranceVerificationResult(
      registered: reg,
      message: res['message']?.toString() ?? '',
      attendee: att,
    );
  }

  Future<AttendeeModel> registerWalkIn({
    required String studentId,
    required String fullName,
    required String email,
    required String programSection,
    required bool markPresentNow,
    required bool markPaidNow,
    required double amountPaid,
    required String paymentMethod,
  }) async {
    final res = await ApiClient.post(
      '/api/entrance/walk-in',
      body: {
        'student_id': studentId,
        'full_name': fullName,
        'email': email,
        'program_section': programSection,
        'mark_present_now': markPresentNow,
        'mark_paid_now': markPaidNow,
        'amount_paid': amountPaid,
        'payment_method': paymentMethod,
      },
    );
    return AttendeeModel.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<void> setAttendance(String studentId, bool isPresent) async {
    await ApiClient.patch(
      '/api/entrance/check-in/${Uri.encodeComponent(studentId)}',
      body: {'is_present': isPresent},
    );
  }
}