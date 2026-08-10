import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../config/constants.dart';
import '../../config/theme_colors.dart';
import '../../models/student_model.dart';

const kGold = Color(0xFFD4AF37);

class StudentInfoTab extends StatelessWidget {
  final StudentModel student;
  const StudentInfoTab({super.key, required this.student});

  Color _statusColor(String status) {
    switch (status) {
      case 'Active':
        return kGreen;
      case 'Completed':
        return kTeal;
      case 'Dropped':
        return kCoral;
      default:
        return kAmber;
    }
  }

  TextStyle _jakarta({
    required double size,
    FontWeight weight = FontWeight.w500,
    required Color color,
    double? letterSpacing,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: _jakarta(
                  size: 13,
                  weight: FontWeight.w500,
                  color: ThemeColors.textSecondary(context)),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              // This was hardcoded white before — invisible on a light
              // background. Now it follows the current theme.
              style: _jakarta(
                  size: 15,
                  weight: FontWeight.w600,
                  color: ThemeColors.textPrimary(context)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [kGold, kTeal],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: CircleAvatar(
                  radius: 30,
                  backgroundColor: ThemeColors.surface(context),
                  child: Text(
                    student.name.isNotEmpty
                        ? student.name[0].toUpperCase()
                        : '?',
                    style: _jakarta(
                        size: 24, weight: FontWeight.w700, color: kGold),
                  ),
                ),
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: _statusColor(student.status).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _statusColor(student.status).withOpacity(0.4),
                    width: 1,
                  ),
                ),
                child: Text(
                  student.status,
                  style: _jakarta(
                    size: 13,
                    weight: FontWeight.w600,
                    color: _statusColor(student.status),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ThemeColors.surface(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kGold.withOpacity(0.12), width: 1),
            ),
            child: Column(
              children: [
                _infoRow(context, 'Roll No', student.rollNo),
                Divider(color: ThemeColors.divider(context)),
                _infoRow(context, 'Name', student.name),
                Divider(color: ThemeColors.divider(context)),
                _infoRow(context, 'Email', student.email),
                Divider(color: ThemeColors.divider(context)),
                _infoRow(context, 'Phone', student.phone),
                Divider(color: ThemeColors.divider(context)),
                _infoRow(context, 'Aadhaar', student.aadhaar),
                Divider(color: ThemeColors.divider(context)),
                _infoRow(
                  context,
                  'Date of Birth',
                  student.dateOfBirth != null
                      ? DateFormat('dd MMM yyyy').format(student.dateOfBirth!)
                      : '',
                ),
                Divider(color: ThemeColors.divider(context)),
                _infoRow(context, 'Batch', student.batchName),
                Divider(color: ThemeColors.divider(context)),
                _infoRow(context, 'Company', student.companyName),
                Divider(color: ThemeColors.divider(context)),
                _infoRow(
                  context,
                  'Enrollment Date',
                  student.enrollmentDate != null
                      ? DateFormat('dd MMM yyyy').format(student.enrollmentDate!)
                      : '',
                ),
                Divider(color: ThemeColors.divider(context)),
                _infoRow(context, 'Added On',
                    DateFormat('dd MMM yyyy').format(student.createdAt)),
                if (student.updatedAt != null) ...[
                  Divider(color: ThemeColors.divider(context)),
                  _infoRow(
                      context,
                      'Last Updated',
                      DateFormat('dd MMM yyyy, hh:mm a')
                          .format(student.updatedAt!)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}