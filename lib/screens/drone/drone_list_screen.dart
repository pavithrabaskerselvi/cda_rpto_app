import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/drone_model.dart';
import '../../config/theme_colors.dart';
import '../../providers/theme_provider.dart';
import 'drone_detail_screen.dart';
import 'drone_add_screen.dart';

class DroneListScreen extends StatefulWidget {
  const DroneListScreen({super.key});

  @override
  State<DroneListScreen> createState() => _DroneListScreenState();
}

class _DroneListScreenState extends State<DroneListScreen> {
  String _searchQuery = '';
  String _selectedType = 'All';

  final List<String> _types = ['All', 'Fixed Wing', 'Multirotor', 'VTOL'];

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

  /// Sun / moon switch — same idea as the Company List toggle. Flips the
  /// shared ThemeProvider, so every Drone screen updates together.
  Widget _buildThemeToggle(bool isDark, CompanyColors c) {
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

  // ---- gradient hero header, matching Company Details premium style ----
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
              _buildThemeToggle(isDark, c),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'DroneList',
            style: GoogleFonts.plusJakartaSans(
              color: c.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchAndFilters(CompanyColors c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        children: [
          TextField(
            style: GoogleFonts.plusJakartaSans(color: c.textPrimary),
            onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Search drone name / serial no...',
              hintStyle: GoogleFonts.plusJakartaSans(color: c.textSecondary),
              prefixIcon: Icon(Icons.search, color: c.accent),
              filled: true,
              fillColor: c.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _types.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final type = _types[index];
                final selected = type == _selectedType;
                return ChoiceChip(
                  label: Text(type),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedType = type),
                  selectedColor: c.accent,
                  backgroundColor: c.surface,
                  labelStyle: GoogleFonts.plusJakartaSans(
                    color: selected ? c.background : c.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide.none,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _droneCard(BuildContext context, DroneModel drone, CompanyColors c) {
    final initial = drone.droneName.isNotEmpty ? drone.droneName[0].toUpperCase() : '?';
    final statusColor = _statusColor(drone.status, c);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.35)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => DroneDetailsScreen(drone: drone)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      c.gold.withValues(alpha: 0.7),
                      c.accent.withValues(alpha: 0.6),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: c.surfaceElevated,
                  child: Text(
                    initial,
                    style: GoogleFonts.plusJakartaSans(
                        color: c.accent, fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      drone.droneName,
                      style: GoogleFonts.plusJakartaSans(
                          color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 15.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${drone.model} • ${drone.serialNumber}',
                      style: GoogleFonts.plusJakartaSans(color: c.textSecondary, fontSize: 12.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      drone.companyName,
                      style: GoogleFonts.plusJakartaSans(
                          color: c.textSecondary.withValues(alpha: 0.8), fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      drone.status,
                      style: GoogleFonts.plusJakartaSans(
                          color: statusColor, fontWeight: FontWeight.w600, fontSize: 11),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Icon(Icons.chevron_right, color: c.textSecondary.withValues(alpha: 0.8), size: 20),
                ],
              ),
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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: c.accent,
        foregroundColor: c.background,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddDroneScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: Text('Add Drone', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(context, isDark, c),
          _searchAndFilters(c),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('drones')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}',
                        style: GoogleFonts.plusJakartaSans(color: c.textPrimary)),
                  );
                }
                if (!snapshot.hasData) {
                  return Center(
                      child: CircularProgressIndicator(color: c.accent));
                }

                var drones = snapshot.data!.docs
                    .map((doc) => DroneModel.fromDocument(doc))
                    .where((d) {
                  final matchesType = _selectedType == 'All' || d.type == _selectedType;
                  final matchesSearch = _searchQuery.isEmpty ||
                      d.droneName.toLowerCase().contains(_searchQuery) ||
                      d.serialNumber.toLowerCase().contains(_searchQuery);
                  return matchesType && matchesSearch;
                }).toList();

                if (drones.isEmpty) {
                  return Center(
                    child: Text('No drones found',
                        style: GoogleFonts.plusJakartaSans(color: c.textSecondary, fontSize: 16)),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                  itemCount: drones.length,
                  itemBuilder: (context, index) => _droneCard(context, drones[index], c),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
