import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/drone_model.dart';
import '../../config/theme_colors.dart';
import '../../providers/theme_provider.dart';
import '../document/documents_screen.dart';
import 'drone_add_screen.dart';

class DroneDetailsScreen extends StatelessWidget {
  final DroneModel drone;
  const DroneDetailsScreen({super.key, required this.drone});

  Color _statusColor(String status, CompanyColors c) {
    switch (status) {
      case 'Available':
        return c.success;
      case 'In Use':
        return c.accent;
      case 'Under Maintenance':
        return const Color(0xFFFFB020);
      default:
        return c.danger;
    }
  }

  void _confirmDelete(BuildContext context, CompanyColors c) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Drone',
            style: GoogleFonts.plusJakartaSans(
                color: c.textPrimary, fontWeight: FontWeight.w700)),
        content: Text('Delete ${drone.droneName}? This cannot be undone.',
            style: GoogleFonts.plusJakartaSans(color: c.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: c.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('drones').doc(drone.id).delete();
              if (context.mounted) {
                Navigator.pop(context); // close dialog
                Navigator.pop(context); // back to list
              }
            },
            child: Text('Delete',
                style: GoogleFonts.plusJakartaSans(
                    color: c.danger, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _openDocuments(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentsScreen(
          title: '${drone.droneName} Documents',
          firestorePath: 'drones/${drone.id}',
          requirements: const [
            DocumentRequirement(
                key: 'registration_certificate', label: 'Registration Certificate'),
            DocumentRequirement(key: 'insurance', label: 'Insurance'),
            DocumentRequirement(key: 'manual', label: 'Manual', required: false),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeToggle(BuildContext context, bool isDark, CompanyColors c) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.wb_sunny_outlined,
            size: 18, color: isDark ? c.textSecondary : c.accent),
        Switch(
          value: isDark,
          activeColor: c.accent,
          onChanged: (val) => context.read<ThemeProvider>().toggleTheme(val),
        ),
        Icon(Icons.nightlight_round,
            size: 18, color: isDark ? c.accent : c.textSecondary),
      ],
    );
  }

  // ---- gradient hero header, matching Company Details / DroneList premium style ----
  Widget _header(BuildContext context, bool isDark, CompanyColors c) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            c.gold.withValues(alpha: 0.18),
            c.accent.withValues(alpha: 0.12),
            c.background,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(Icons.arrow_back, color: c.textPrimary),
                onPressed: () => Navigator.pop(context),
              ),
              const Spacer(),
              _buildThemeToggle(context, isDark, c),
              IconButton(
                icon: Icon(Icons.edit, color: c.textPrimary),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AddDroneScreen(existingDrone: drone)),
                  );
                },
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: c.textPrimary),
                onPressed: () => _confirmDelete(context, c),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Drone Details',
            style: GoogleFonts.plusJakartaSans(
              color: c.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  drone.droneName,
                  style: GoogleFonts.plusJakartaSans(
                      color: c.textSecondary, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _statusColor(drone.status, c).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _statusColor(drone.status, c).withValues(alpha: 0.4)),
                ),
                child: Text(
                  drone.status,
                  style: GoogleFonts.plusJakartaSans(
                      color: _statusColor(drone.status, c),
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---- one row-card, matching the avatar + title/subtitle + chevron style ----
  Widget _rowCard(
      CompanyColors c, {
        required IconData icon,
        required String label,
        required String value,
        VoidCallback? onTap,
        bool danger = false,
      }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: danger ? c.danger.withValues(alpha: 0.4) : c.borderSubtle.withValues(alpha: 0.06)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      c.gold.withValues(alpha: 0.6),
                      c.accent.withValues(alpha: 0.5),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.background,
                  ),
                  child: Icon(icon, color: c.accent, size: 18),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: GoogleFonts.plusJakartaSans(
                            color: c.textSecondary, fontSize: 12.5)),
                    const SizedBox(height: 3),
                    Text(
                      value.isEmpty ? '-' : value,
                      style: GoogleFonts.plusJakartaSans(
                          color: c.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right, color: c.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final c = CompanyColors.of(isDark);

    return Scaffold(
      backgroundColor: c.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(context, isDark, c),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _rowCard(c, icon: Icons.precision_manufacturing_outlined, label: 'Model', value: drone.model),
                _rowCard(c, icon: Icons.qr_code_2, label: 'Serial Number', value: drone.serialNumber),
                _rowCard(c, icon: Icons.category_outlined, label: 'Type', value: drone.type),
                _rowCard(c, icon: Icons.apartment_outlined, label: 'Company', value: drone.companyName),
                _rowCard(
                  c,
                  icon: Icons.build_outlined,
                  label: 'Last Maintenance',
                  value: drone.lastMaintenanceDate != null
                      ? DateFormat('dd MMM yyyy').format(drone.lastMaintenanceDate!)
                      : '',
                ),
                _rowCard(
                  c,
                  icon: Icons.calendar_today_outlined,
                  label: 'Added On',
                  value: DateFormat('dd MMM yyyy').format(drone.createdAt),
                ),
                if (drone.updatedAt != null)
                  _rowCard(
                    c,
                    icon: Icons.update,
                    label: 'Last Updated',
                    value: DateFormat('dd MMM yyyy, hh:mm a').format(drone.updatedAt!),
                  ),
                const SizedBox(height: 4),
                _rowCard(
                  c,
                  icon: Icons.description_outlined,
                  label: 'Attachments',
                  value: 'Documents',
                  onTap: () => _openDocuments(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
