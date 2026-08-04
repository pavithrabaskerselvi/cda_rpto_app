import 'package:flutter/material.dart';

/// A small colored pill badge indicating status — used for documents,
/// drone_form submissions, logbook entries, etc.
///
/// ASSUMPTIONS:
/// - Recognized statuses: 'pending', 'approved', 'rejected', 'draft'.
///   Unknown strings fall back to a neutral gray badge showing the raw text.
class FormStatusBadge extends StatelessWidget {
  final String status;

  const FormStatusBadge({super.key, required this.status});

  Color _bgColor(String s) {
    switch (s.toLowerCase()) {
      case 'approved':
        return Colors.green.withOpacity(0.15);
      case 'rejected':
        return Colors.red.withOpacity(0.15);
      case 'pending':
        return Colors.orange.withOpacity(0.15);
      case 'draft':
        return Colors.blueGrey.withOpacity(0.15);
      default:
        return Colors.grey.withOpacity(0.15);
    }
  }

  Color _textColor(String s) {
    switch (s.toLowerCase()) {
      case 'approved':
        return Colors.green.shade800;
      case 'rejected':
        return Colors.red.shade800;
      case 'pending':
        return Colors.orange.shade800;
      case 'draft':
        return Colors.blueGrey.shade800;
      default:
        return Colors.grey.shade800;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _bgColor(status),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status[0].toUpperCase() + status.substring(1).toLowerCase(),
        style: TextStyle(
          color: _textColor(status),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}