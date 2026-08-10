import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/company_model.dart';
import '../../config/theme_colors.dart';
import '../../providers/theme_provider.dart';
import 'company_add_screen.dart';
import 'company_detail_screen.dart';

class CompanyListScreen extends StatefulWidget {
  const CompanyListScreen({super.key});

  @override
  State<CompanyListScreen> createState() => _CompanyListScreenState();
}

class _CompanyListScreenState extends State<CompanyListScreen> {
  String _searchQuery = '';
  final _searchController = TextEditingController();
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Active', 'Inactive'];

  Stream<QuerySnapshot> _companyStream() {
    return FirebaseFirestore.instance
        .collection('companies')
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
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final c = CompanyColors.of(isDark);

    return Scaffold(
      backgroundColor: c.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: c.background,
            pinned: true,
            expandedHeight: 130,
            elevation: 0,
            iconTheme: IconThemeData(color: c.textPrimary),
            actions: const [],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
              title: Text(
                'Company Details',
                style: GoogleFonts.plusJakartaSans(
                  color: c.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
              background: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [c.accent.withValues(alpha: 0.35), c.background],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
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
                style: GoogleFonts.plusJakartaSans(color: c.textPrimary),
                onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search details...',
                  hintStyle: GoogleFonts.plusJakartaSans(color: c.textSecondary),
                  prefixIcon: Icon(Icons.search, color: c.textSecondary),
                  filled: true,
                  fillColor: c.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _filters.length,
                itemBuilder: (context, index) {
                  final filter = _filters[index];
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: ChoiceChip(
                      label: Text(filter),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _selectedFilter = filter),
                      selectedColor: c.accent,
                      backgroundColor: c.surface,
                      labelStyle: GoogleFonts.plusJakartaSans(
                        color: isSelected ? c.background : c.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected ? c.accent : c.borderSubtle.withValues(alpha: 0.08),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          StreamBuilder<QuerySnapshot>(
            stream: _companyStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: c.accent)),
                );
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Text('No companies found',
                        style: GoogleFonts.plusJakartaSans(color: c.textSecondary)),
                  ),
                );
              }

              final allCompanies = snapshot.data!.docs
                  .map((d) => CompanyModel.fromDocument(d))
                  .toList();

              var mainCompanies = allCompanies
                  .where((comp) => comp.isMainCompany)
                  .where((comp) => _selectedFilter == 'All' || comp.status == _selectedFilter)
                  .where((comp) => _searchQuery.isEmpty || comp.name.toLowerCase().contains(_searchQuery))
                  .toList();

              if (mainCompanies.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Text('No matching companies',
                        style: GoogleFonts.plusJakartaSans(color: c.textSecondary)),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    final company = mainCompanies[index];
                    final branches = allCompanies
                        .where((comp) => comp.parentCompanyId == company.id)
                        .toList();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCompanyCard(company, c, branchCount: branches.length),
                        ...branches.asMap().entries.map((entry) {
                          return _buildBranchRow(entry.value, c);
                        }),
                        const SizedBox(height: 4),
                      ],
                    );
                  },
                  childCount: mainCompanies.length,
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: c.accent,
        icon: Icon(Icons.add, color: c.background),
        label: Text(
          'Add Details',
          style: GoogleFonts.plusJakartaSans(color: c.background, fontWeight: FontWeight.w700),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CompanyAddScreen()),
          );
        },
      ),
    );
  }

  Widget _buildCompanyCard(CompanyModel company, CompanyColors c, {required int branchCount}) {
    final isActive = company.status == 'Active';
    final statusColor = isActive ? c.success : c.danger;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CompanyDetailScreen(company: company)),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: statusColor.withValues(alpha: 0.28)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [c.gold.withValues(alpha: 0.7), c.accent.withValues(alpha: 0.5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: c.background,
                child: Text(
                  company.name.isNotEmpty ? company.name[0].toUpperCase() : '?',
                  style: GoogleFonts.plusJakartaSans(
                    color: c.accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
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
                          company.name,
                          style: GoogleFonts.plusJakartaSans(
                            color: c.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: statusColor.withValues(alpha: 0.45)),
                        ),
                        child: Text(
                          company.status,
                          style: GoogleFonts.plusJakartaSans(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${company.city}, ${company.state}',
                    style: GoogleFonts.plusJakartaSans(color: c.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.phone_outlined, color: c.textSecondary.withValues(alpha: 0.7), size: 14),
                      const SizedBox(width: 4),
                      Text(
                        company.contactPhone,
                        style: GoogleFonts.plusJakartaSans(color: c.textSecondary, fontSize: 11),
                      ),
                      if (branchCount > 0) ...[
                        const SizedBox(width: 12),
                        Icon(Icons.account_tree_outlined, color: c.gold.withValues(alpha: 0.85), size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '$branchCount ${branchCount == 1 ? 'branch' : 'branches'}',
                          style: GoogleFonts.plusJakartaSans(
                            color: c.gold,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: c.textSecondary.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }

  // Branch row, indented with a connector line so it visually nests under its company
  Widget _buildBranchRow(CompanyModel branch, CompanyColors c) {
    final isActive = branch.status == 'Active';
    final statusColor = isActive ? c.success : c.danger;

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 6),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 28,
              child: Column(
                children: [
                  Container(width: 2, height: 22, color: c.borderSubtle.withValues(alpha: 0.12)),
                  Container(width: 12, height: 2, color: c.borderSubtle.withValues(alpha: 0.12)),
                ],
              ),
            ),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => CompanyDetailScreen(company: branch)),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: c.surface.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: c.borderSubtle.withValues(alpha: 0.06)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: c.gold.withValues(alpha: 0.15),
                        child: Text(
                          branch.name.isNotEmpty ? branch.name[0].toUpperCase() : '?',
                          style: GoogleFonts.plusJakartaSans(
                            color: c.gold,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              branch.name,
                              style: GoogleFonts.plusJakartaSans(
                                color: c.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${branch.city}, ${branch.state}',
                              style: GoogleFonts.plusJakartaSans(color: c.textSecondary, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          branch.status,
                          style: GoogleFonts.plusJakartaSans(
                            color: statusColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
