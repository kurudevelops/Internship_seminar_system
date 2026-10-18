class AttendeeModel {
  final String id;
  final String studentId;
  final String fullName;
  final String email;
  final String programSection;
  final String registrationType; // PRE_REGISTERED or WALK_IN
  final bool isPresent;
  final String? timeIn;
  final bool isPaid;
  final double amountPaid;
  final String paymentMethod; // NONE, CASH, GCASH
  final String? paidAt;
  final String createdAt;

  const AttendeeModel({
    required this.id,
    required this.studentId,
    required this.fullName,
    required this.email,
    required this.programSection,
    required this.registrationType,
    required this.isPresent,
    this.timeIn,
    required this.isPaid,
    required this.amountPaid,
    required this.paymentMethod,
    this.paidAt,
    required this.createdAt,
  });

  factory AttendeeModel.fromJson(Map<String, dynamic> json) {
    return AttendeeModel(
      id: json['id']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      programSection: json['program_section']?.toString() ?? '',
      registrationType: json['registration_type']?.toString() ?? 'PRE_REGISTERED',
      isPresent: json['is_present'] == true,
      timeIn: json['time_in']?.toString(),
      isPaid: json['is_paid'] == true,
      amountPaid: (json['amount_paid'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['payment_method']?.toString() ?? 'NONE',
      paidAt: json['paid_at']?.toString(),
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}