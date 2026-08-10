import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/company_model.dart';
import '../../config/constants.dart';
import '../../config/theme_colors.dart';
import '../../widgets/attach_document_button.dart';
import 'company_edit_screen.dart';

class CompanyDetailScreen extends StatefulWidget {
  final CompanyModel company;

  const CompanyDetailScreen({super.key, required this.company});

  @override
  State<CompanyDetailScreen> createState() => _CompanyDetailScreenState();
}

class _CompanyDetailScreenState extends State<CompanyDetailScreen> {
  bool _isDeleting = false;
  bool _savingDocs = false;

  Future<void> _confirmDelete(CompanyColors c) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: c.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Company',
          style: GoogleFonts.plusJakartaSans(
            color: c.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Are you sure you want to delete ${widget.company.name}? This cannot be undone.',
          style: GoogleFonts.plusJakartaSans(color: c.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.plusJakartaSans(color: c.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete',
                style: GoogleFonts.plusJakartaSans(
                    color: c.danger, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isDeleting = true);
      try {
        await FirebaseFirestore.instance
            .collection('companies')
            .doc(widget.company.id)
            .delete();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Company deleted'), backgroundColor: kGreen),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e'), backgroundColor: kCoral),
          );
        }
      } finally {
        setState(() => _isDeleting = false);
      }
    }
  }

  Future<void> _openEditScreen() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CompanyEditScreen(company: widget.company),
      ),
    );
    // CompanyEditScreen pops with `true` after a successful save. This
    // screen holds a snapshot (widget.company) that won't reflect the
    // change on its own, so pop back to the list — its StreamBuilder
    // will show the fresh data immediately.
    if (updated == true && mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _toggleStatus() async {
    final newStatus = widget.company.status == 'Active' ? 'Inactive' : 'Active';
    try {
      await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.company.id)
          .update({'status': newStatus, 'updatedAt': FieldValue.serverTimestamp()});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status changed to $newStatus'), backgroundColor: kGreen),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: kCoral),
        );
      }
    }
  }

  Future<void> _onDocumentsChanged(List<AttachedDocument> docs) async {
    setState(() => _savingDocs = true);
    try {
      await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.company.id)
          .update({'documents': docs.map((d) => d.toMap()).toList()});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save document: $e'), backgroundColor: kCoral),
        );
      }
    } finally {
      if (mounted) setState(() => _savingDocs = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = CompanyColors.of(false);

    final company = widget.company;
    final isActive = company.status == 'Active';
    final statusColor = isActive ? c.success : c.danger;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        title: Text(
          company.name,
          style: GoogleFonts.plusJakartaSans(
            color: c.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        iconTheme: IconThemeData(color: c.textPrimary),
        actions: [
          IconButton(
            icon: Icon(Icons.edit_outlined, color: c.accent),
            onPressed: _openEditScreen,
          ),
          IconButton(
            icon: _isDeleting
                ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(color: c.danger, strokeWidth: 2),
            )
                : Icon(Icons.delete_outline, color: c.danger),
            onPressed: _isDeleting ? null : () => _confirmDelete(c),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [c.gold.withValues(alpha: 0.8), c.accent.withValues(alpha: 0.6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 42,
                    backgroundColor: c.surfaceElevated,
                    child: Text(
                      company.name.isNotEmpty ? company.name[0].toUpperCase() : '?',
                      style: GoogleFonts.plusJakartaSans(
                        color: c.accent,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  company.name,
                  style: GoogleFonts.plusJakartaSans(
                    color: c.textPrimary,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _toggleStatus,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withValues(alpha: 0.45)),
                    ),
                    child: Text(
                      '${company.status} · tap to toggle',
                      style: GoogleFonts.plusJakartaSans(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _buildSectionLabel('Registration', c),
          const SizedBox(height: 10),
          _buildInfoCard(c, [
            if (company.tradeName.isNotEmpty)
              _buildInfoRow(Icons.storefront_outlined, 'Trade Name', company.tradeName, c),
            _buildInfoRow(Icons.badge_outlined, 'Authorization Number', company.registrationNumber, c),
            _buildInfoRow(Icons.location_on_outlined, 'Address', company.address, c),
            _buildInfoRow(Icons.location_city_outlined, 'City, State', '${company.city}, ${company.state}', c),
            _buildInfoRow(Icons.pin_drop_outlined, 'Pincode', company.pincode, c),
          ]),
          const SizedBox(height: 20),
          _buildSectionLabel('Contact', c),
          const SizedBox(height: 10),
          _buildInfoCard(c, [
            _buildInfoRow(Icons.email_outlined, 'Contact Email', company.contactEmail, c),
            _buildInfoRow(Icons.phone_outlined, 'Contact Phone', company.contactPhone, c),
          ]),
          const SizedBox(height: 20),
          _buildSectionLabel('Timeline', c),
          const SizedBox(height: 10),
          _buildInfoCard(c, [
            _buildInfoRow(
              Icons.calendar_today_outlined,
              'Registered On',
              '${company.createdAt.day}/${company.createdAt.month}/${company.createdAt.year}',
              c,
            ),
          ]),
          const SizedBox(height: 20),
          _buildSectionLabel('Documents', c),
          const SizedBox(height: 10),
          _buildDocumentsSection(c),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text, CompanyColors c) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          color: c.gold,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
        ),
      ),
    );
  }

  Widget _buildDocumentsSection(CompanyColors c) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.borderSubtle.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_savingDocs)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: c.accent),
                  ),
                  const SizedBox(width: 8),
                  Text('Saving...',
                      style: GoogleFonts.plusJakartaSans(color: c.textSecondary, fontSize: 12)),
                ],
              ),
            ),
          AttachDocumentButton(
            initialDocuments: widget.company.documents,
            onDocumentsChanged: _onDocumentsChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(CompanyColors c, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.borderSubtle.withValues(alpha: 0.05)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, CompanyColors c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: c.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: c.accent, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    color: c.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value.isEmpty ? '-' : value,
                  style: GoogleFonts.plusJakartaSans(
                    color: c.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}