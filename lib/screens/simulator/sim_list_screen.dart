import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart'; // NEW
import '../../models/simulator_model.dart';
import '../../providers/theme_provider.dart'; // NEW
import 'sim_add_screen.dart';
import 'sim_detail_screen.dart';

class SimListScreen extends StatefulWidget {
  const SimListScreen({super.key});

  @override
  State<SimListScreen> createState() => _SimListScreenState();
}

class _SimListScreenState extends State<SimListScreen> {
  String _searchQuery = '';
  final _searchController = TextEditingController();

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
  Color _pTextMuted(BuildContext c) =>
      _isDark(c) ? const Color(0xFF6B7280) : const Color(0xFF9AA3B2);
  Color _pDanger(BuildContext c) =>
      _isDark(c) ? const Color(0xFFE0685A) : const Color(0xFFC94A3B);
  Color _pSuccess(BuildContext c) =>
      _isDark(c) ? const Color(0xFF3FCE8E) : const Color(0xFF1F9D63);
  Color _pAmber(BuildContext c) =>
      _isDark(c) ? const Color(0xFFFFB020) : const Color(0xFFB77400);

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

  Stream<QuerySnapshot> _simStream() {
    return FirebaseFirestore.instance
        .collection('simulators')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>(); // NEW

    return Scaffold(
      backgroundColor: _pBackground(context),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: _pBackground(context),
            pinned: true,
            expandedHeight: 130,
            iconTheme: IconThemeData(color: _pTextPrimary(context)),
            // NEW: dark/light mode toggle
            actions: [
              Row(
                children: [
                  Icon(Icons.light_mode,
                      size: 18,
                      color: themeProvider.isDarkMode
                          ? _pTextMuted(context)
                          : _pAmber(context)),
                  Switch(
                    value: themeProvider.isDarkMode,
                    activeColor: _pAccent(context),
                    onChanged: (val) => themeProvider.toggleTheme(val),
                  ),
                  Icon(Icons.dark_mode,
                      size: 18,
                      color: themeProvider.isDarkMode
                          ? _pAccent(context)
                          : _pTextMuted(context)),
                  const SizedBox(width: 8),
                ],
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
              title: Text(
                'Simulators',
                style: GoogleFonts.plusJakartaSans(
                  color: _pTextPrimary(context),
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              background: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _pGold(context).withValues(alpha: 0.18),
                      _pAccent(context).withValues(alpha: 0.12),
                      _pBackground(context),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.plusJakartaSans(color: _pTextPrimary(context)),
                onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search simulator name or model...',
                  hintStyle: GoogleFonts.plusJakartaSans(color: _pTextMuted(context)),
                  prefixIcon: Icon(Icons.search, color: _pAccent(context)),
                  filled: true,
                  fillColor: _pSurface(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 4)),
          StreamBuilder<QuerySnapshot>(
            stream: _simStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: _pAccent(context))),
                );
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                      child: Text('No simulators found',
                          style: GoogleFonts.plusJakartaSans(color: _pTextSecondary(context)))),
                );
              }

              var sims = snapshot.data!.docs
                  .map((d) => SimulatorModel.fromDocument(d))
                  .where((s) => _searchQuery.isEmpty ||
                  s.simulatorName.toLowerCase().contains(_searchQuery) ||
                  s.model.toLowerCase().contains(_searchQuery))
                  .toList();

              if (sims.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                      child: Text('No matching simulators',
                          style: GoogleFonts.plusJakartaSans(color: _pTextSecondary(context)))),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildSimCard(context, sims[index]),
                  childCount: sims.length,
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _pAccent(context),
        foregroundColor: _pBackground(context),
        icon: const Icon(Icons.add),
        label: Text('Add Simulator', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SimAddScreen()),
          );
        },
      ),
    );
  }

  Widget _buildSimCard(BuildContext context, SimulatorModel sim) {
    final statusColor = _statusColor(context, sim.status);
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SimDetailScreen(simulator: sim)),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _pSurface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: statusColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [_pGold(context).withValues(alpha: 0.7), _pAccent(context).withValues(alpha: 0.6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: _pBackground(context),
                child: Icon(Icons.sports_esports, color: _pAccent(context), size: 20),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          sim.simulatorName,
                          style: GoogleFonts.plusJakartaSans(
                              color: _pTextPrimary(context), fontSize: 15, fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          sim.status,
                          style: GoogleFonts.plusJakartaSans(
                              color: statusColor, fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(sim.model,
                      style: GoogleFonts.plusJakartaSans(color: _pTextSecondary(context), fontSize: 12)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.apartment, color: _pTextMuted(context), size: 14),
                      const SizedBox(width: 4),
                      Text(sim.companyName,
                          style: GoogleFonts.plusJakartaSans(color: _pTextSecondary(context), fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: _pTextMuted(context)),
          ],
        ),
      ),
    );
  }
}