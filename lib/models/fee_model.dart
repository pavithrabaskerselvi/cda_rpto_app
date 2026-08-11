/// FeeModel
/// Represents a single fee payment document in the 'fees' collection.
/// Each student may have multiple fee docs (installments); totalCourseFee
/// is expected to be repeated on every doc for that student.
class FeeModel {
  final String id;
  final String studentId;
  final double amountPaid;
  final double totalCourseFee;

  const FeeModel({
    required this.id,
    required this.studentId,
    required this.amountPaid,
    required this.totalCourseFee,
  });

  factory FeeModel.fromMap(Map<String, dynamic> data, String id) {
    return FeeModel(
      id: id,
      studentId: (data['studentId'] ?? '') as String,
      amountPaid: (data['amountPaid'] ?? 0).toDouble(),
      totalCourseFee: (data['totalCourseFee'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
    'studentId': studentId,
    'amountPaid': amountPaid,
    'totalCourseFee': totalCourseFee,
  };
}