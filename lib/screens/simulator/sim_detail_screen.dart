import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/simulator_model.dart';
import '../document/documents_screen.dart';
import 'sim_add_screen.dart';

class SimDetailScreen extends StatefulWidget {
  final SimulatorModel simulator;

  const SimDetailScreen({super.key, required this.simulator});

  @override
  State<SimDetailScreen> createState() => _SimDetailScreenState();
}

class _SimDetailScreenState extends State<SimDetailScreen> {
  bool _isDeleting = false;

  // ---- Theme-aware colors: flip between dark/light based on current
  // Theme brightness instead of hardcoded dark-only constants. ----
  bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  Color _pBackground(BuildContext c) =>
      _isDark(c) ? const Color(0xFF05070D) : const Color(0xFFF5F7FA);
  Color _pSurface(BuildContext c) =>
      _isDark(c) ? const Color(0xFF10141F) : const Color(0xFFFFFFFF);
  Color _pAccent(BuildContext c) =>
      _isDark(c) ? const Color(0xFF2DD4BF) : const Color(0xFF0E9488);
  Color _pGold(BuildContext c) =>
      _isDark(c) ? const Color(0xFFC9A24B) : const Color(0xFFA9822F);
  Color _pTextPrimary(BuildContext c) =>
      _isDark(c) ? const Color(0xFFF5F6FA) : const Color(0xFF0B1220);
  Color _pTextSecondary(BuildContext c) =>
      _isDark(c) ? const Color(0xFF8A93A6) : const Color(0xFF5B6472);
  Color _pDanger(BuildContext c) =>
      _isDark(c) ? const Color(0xFFE0685A) : const Color(0xFFC94A3B);
  Color _pSuccess(BuildContext c) =>
      _isDark(c) ? const Color(0xFF3FCE8E) : const Color(0xFF1F9D63);
  Color _pAmber(BuildContext c) =>
      _isDark(c) ? const Color(0xFFFFB020) : const Color(0xFFB77400);
  Color _pBorder(BuildContext c) =>
      _isDark(c) ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE2E5EA);

  Color _statusColor(BuildContext context, String status) {
    switch (status) {
      case 'Available':
        return _pSuccess(context);
      case 'In Use':
        return _pAccent(context);
      case 'Under Maintenance':
        return _pAmber(context);
      default:
        return _pDanger(context);
    }
  }

  // 🆕 Opens the Add/Edit form pre-filled with this simulator. If the save
  // goes through, pop this detail screen too so the caller (the simulator
  // list, which streams from Firestore) shows the fresh data right away.
  Future<void> _editSimulator() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SimAddScreen(existingSimulator: widget.simulator),
      ),
    );
    if (updated == true && mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _pSurface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Simulator',
            style: GoogleFonts.plusJakartaSans(
                color: _pTextPrimary(context), fontWeight: FontWeight.w700)),
        content: Text(
          'Are you sure you want to delete ${widget.simulator.simulatorName}? This cannot be undone.',
          style: GoogleFonts.plusJakartaSans(color: _pTextSecondary(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: _pTextSecondary(context))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete',
                style: GoogleFonts.plusJakartaSans(
                    color: _pDanger(context), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isDeleting = true);
      try {
        await FirebaseFirestore.instance
            .collection('simulators')
            .doc(widget.simulator.id)
            .delete();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Simulator deleted', style: GoogleFonts.plusJakartaSans()),
                backgroundColor: _pSuccess(context)),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Failed to delete: $e', style: GoogleFonts.plusJakartaSans()),
                backgroundColor: _pDanger(context)),
          );
        }
      } finally {
        if (mounted) setState(() => _isDeleting = false);
      }
    }
  }

  Future<void> _cycleStatus() async {
    const statuses = ['Available', 'In Use', 'Under Maintenance'];
    final currentIndex = statuses.indexOf(widget.simulator.status);
    final newStatus = statuses[(currentIndex + 1) % statuses.length];
    try {
      await FirebaseFirestore.instance
          .collection('simulators')
          .doc(widget.simulator.id)
          .update({'status': newStatus, 'updatedAt': FieldValue.serverTimestamp()});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Status changed to $newStatus', style: GoogleFonts.plusJakartaSans()),
              backgroundColor: _pSuccess(context)),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e', style: GoogleFonts.plusJakartaSans()), backgroundColor: _pDanger(context)),
        );
      }
    }
  }

  void _openDocuments() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentsScreen(
          title: '${widget.simulator.simulatorName} Documents',
          firestorePath: 'simulators/${widget.simulator.id}',
          requirements: const [
            DocumentRequirement(key: 'manual', label: 'Manual', required: false),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sim = widget.simulator;
    final statusColor = _statusColor(context, sim.status);

    return Scaffold(
      backgroundColor: _pBackground(context),
      appBar: AppBar(
        backgroundColor: _pBackground(context),
        elevation: 0,
        title: Text(sim.simulatorName,
            style: GoogleFonts.plusJakartaSans(
                color: _pTextPrimary(context), fontWeight: FontWeight.w700, fontSize: 18)),
        iconTheme: IconThemeData(color: _pTextPrimary(context)),
        actions: [
          IconButton(
            icon: Icon(Icons.edit_outlined, color: _pAccent(context)),
            onPressed: _isDeleting ? null : _editSimulator,
          ),
          IconButton(
            icon: _isDeleting
                ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(color: _pDanger(context), strokeWidth: 2),
            )
                : Icon(Icons.delete_outline, color: _pDanger(context)),
            onPressed: _isDeleting ? null : _confirmDelete,
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
                      colors: [_pGold(context).withValues(alpha: 0.8), _pAccent(context).withValues(alpha: 0.6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 42,
                    backgroundColor: _pSurface(context),
                    child: Icon(Icons.sports_esports, color: _pAccent(context), size: 36),
                  ),
                ),
                const SizedBox(height: 14),
                Text(sim.simulatorName,
                    style: GoogleFonts.plusJakartaSans(
                        color: _pTextPrimary(context), fontSize: 21, fontWeight: FontWeight.w800),
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _cycleStatus,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withValues(alpha: 0.45)),
                    ),
                    child: Text(
                      '${sim.status} · tap to change',
                      style: GoogleFonts.plusJakartaSans(
                          color: statusColor, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _buildSectionLabel(context, 'Details'),
          const SizedBox(height: 10),
          _buildInfoCard(context, [
            _buildInfoRow(context, Icons.devices_other_outlined, 'Model', sim.model),
            _buildInfoRow(context, Icons.numbers_outlined, 'Serial Number', sim.serialNumber),
          ]),
          const SizedBox(height: 20),
          _buildSectionLabel(context, 'Company'),
          const SizedBox(height: 10),
          _buildInfoCard(context, [
            _buildInfoRow(context, Icons.apartment_outlined, 'Company / Branch', sim.companyName),
          ]),
          const SizedBox(height: 20),
          _buildSectionLabel(context, 'Timeline'),
          const SizedBox(height: 10),
          _buildInfoCard(context, [
            _buildInfoRow(
              context,
              Icons.calendar_today_outlined,
              'Added On',
              '${sim.createdAt.day}/${sim.createdAt.month}/${sim.createdAt.year}',
            ),
          ]),
          const SizedBox(height: 20),
          _buildSectionLabel(context, 'Documents'),
          const SizedBox(height: 10),
          _buildDocumentsCard(context),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          color: _pGold(context),
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
        ),
      ),
    );
  }

  Widget _buildDocumentsCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _pSurface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _pBorder(context)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _openDocuments,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _pBackground(context),
                  border: Border.all(color: _pAccent(context).withValues(alpha: 0.5)),
                ),
                child: Icon(Icons.description_outlined, color: _pAccent(context), size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Attachments',
                        style: GoogleFonts.plusJakartaSans(color: _pTextSecondary(context), fontSize: 12.5)),
                    const SizedBox(height: 3),
                    Text('Documents',
                        style: GoogleFonts.plusJakartaSans(
                            color: _pTextPrimary(context), fontSize: 15, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: _pTextSecondary(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: _pSurface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _pBorder(context)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _pAccent(context).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _pAccent(context), size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.plusJakartaSans(color: _pTextSecondary(context), fontSize: 12)),
                const SizedBox(height: 3),
                Text(
                  value.isEmpty ? '-' : value,
                  style: GoogleFonts.plusJakartaSans(
                      color: _pTextPrimary(context), fontSize: 14.5, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}