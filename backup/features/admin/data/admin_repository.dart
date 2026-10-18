import '../../../core/models/attendee_model.dart';
import '../../../core/network/api_client.dart';

class AdminSummaryModel {
  final int totalRegistered;
  final int totalPreRegistered;
  final int totalWalkIn;
  final int totalPresent;
  final int totalAbsent;
  final int preRegisteredPresent;
  final int preRegisteredAbsent;
  final int walkInPresent;
  final int walkInAbsent;

  const AdminSummaryModel({
    this.totalRegistered = 0,
    this.totalPreRegistered = 0,
    this.totalWalkIn = 0,
    this.totalPresent = 0,
    this.totalAbsent = 0,
    this.preRegisteredPresent = 0,
    this.preRegisteredAbsent = 0,
    this.walkInPresent = 0,
    this.walkInAbsent = 0,
  });

  factory AdminSummaryModel.fromJson(Map<String, dynamic> json) {
    return AdminSummaryModel(
      totalRegistered: (json['total_registered'] as num?)?.toInt() ?? 0,
      totalPreRegistered: (json['total_pre_registered'] as num?)?.toInt() ?? 0,
      totalWalkIn: (json['total_walk_in'] as num?)?.toInt() ?? 0,
      totalPresent: (json['total_present'] as num?)?.toInt() ?? 0,
      totalAbsent: (json['total_absent'] as num?)?.toInt() ?? 0,
      preRegisteredPresent: (json['pre_registered_present'] as num?)?.toInt() ?? 0,
      preRegisteredAbsent: (json['pre_registered_absent'] as num?)?.toInt() ?? 0,
      walkInPresent: (json['walk_in_present'] as num?)?.toInt() ?? 0,
      walkInAbsent: (json['walk_in_absent'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdminDashboardData {
  final AdminSummaryModel summary;
  final List<AttendeeModel> attendees;

  AdminDashboardData({required this.summary, required this.attendees});
}

class AdminRepository {
  Future<AdminDashboardData> fetchDashboard({
    String query = '',
    String registrationType = 'ALL',
    String presence = 'ALL',
  }) async {
    final res = await ApiClient.get(
      '/api/admin/dashboard',
      queryParams: {
        'q': query,
        'registration_type': registrationType,
        'presence': presence,
      },
    );
    final summary = AdminSummaryModel.fromJson(
      res['summary'] as Map<String, dynamic>? ?? {},
    );
    final list = (res['data'] as List<dynamic>? ?? [])
        .map((e) => AttendeeModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return AdminDashboardData(summary: summary, attendees: list);
  }

  Future<void> createAttendee(Map<String, dynamic> payload) async {
    await ApiClient.post('/api/admin/attendees', body: payload);
  }

  Future<void> updateAttendee(String id, Map<String, dynamic> payload) async {
    await ApiClient.put('/api/admin/attendees/$id', body: payload);
  }

  Future<void> togglePresence(String id, bool isPresent) async {
    await ApiClient.patch(
      '/api/admin/attendees/$id/presence',
      body: {'is_present': isPresent},
    );
  }

  Future<void> deleteAttendee(String id) async {
    await ApiClient.delete('/api/admin/attendees/$id');
  }

  Future<String> importCsv(String csvContent) async {
    final res = await ApiClient.post(
      '/api/admin/import-csv',
      body: {'csv_content': csvContent},
    );
    return res['message']?.toString() ?? 'Import completed.';
  }
}