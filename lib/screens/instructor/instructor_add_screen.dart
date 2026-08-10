import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/company_model.dart';
import '../../config/constants.dart';
import '../../config/theme_colors.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/attach_document_button.dart';

// NOTE: This screen now uses PlatformFile (with .bytes) instead of
// dart:io File, so document upload works correctly on Flutter Web
// as well as Android/iOS/Desktop.

class InstructorAddScreen extends StatefulWidget {
  const InstructorAddScreen({super.key});

  @override
  State<InstructorAddScreen> createState() => _InstructorAddScreenState();
}

class _InstructorAddScreenState extends State<InstructorAddScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _licenseController = TextEditingController();
  final _experienceController = TextEditingController();
  final _experienceMonthsController = TextEditingController();

  String? _selectedSpecialization;
  String? _selectedCompanyId;
  String? _selectedCompanyName;
  String _status = 'Active';

  bool _isLoadingCompanies = true;
  bool _isSaving = false;
  List<CompanyModel> _companies = [];

  // --- Documents state (collected locally until instructor is saved) ---
  List<AttachedDocument> _documents = [];

  final List<String> _specializations = [
    'All',
    'RPAS Instructor',
    'Fixed Wing',
    'Multirotor',
    'VTOL',
    'FPV',
    'Simulator Training',
  ];

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  Future<void> _loadCompanies() async {
    setState(() => _isLoadingCompanies = true);
    try {
      final snap = await FirebaseFirestore.instance.collection('companies').get();
      setState(() {
        _companies = snap.docs.map((d) => CompanyModel.fromDocument(d)).toList();
        _isLoadingCompanies = false;
      });
    } catch (e) {
      setState(() => _isLoadingCompanies = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load companies: $e'), backgroundColor: kCoral),
        );
      }
    }
  }

  Future<void> _saveInstructor() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedSpecialization == null ||
        _selectedCompanyName == null ||
        _selectedCompanyName!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields'), backgroundColor: kCoral),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('instructors').add({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'licenseNumber': _licenseController.text.trim(),
        'specialization': _selectedSpecialization,
        'experienceYears': int.tryParse(_experienceController.text.trim()) ?? 0,
        'experienceMonths': int.tryParse(_experienceMonthsController.text.trim()) ?? 0,
        'companyId': _selectedCompanyId, // may be null if company was typed manually (not in list)
        'companyName': _selectedCompanyName?.trim(),
        'status': _status,
        'profileImageUrl': null,
        'documents': _documents.map((d) => d.toMap()).toList(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Instructor added successfully'), backgroundColor: kGreen),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'), backgroundColor: kCoral),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _licenseController.dispose();
    _experienceController.dispose();
    _experienceMonthsController.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(String hint, CompanyColors c) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: c.textSecondary.withValues(alpha: 0.6)),
      filled: true,
      fillColor: c.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c.borderSubtle.withValues(alpha: 0.24)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c.accent),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c.danger),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final c = CompanyColors.of(isDark);

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        title: Text('Add Instructor', style: TextStyle(color: c.textPrimary)),
        iconTheme: IconThemeData(color: c.textPrimary),
        actions: const [],
      ),
      body: _isLoadingCompanies
          ? Center(child: CircularProgressIndicator(color: c.accent))
          : Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildLabel('Full Name', c),
            TextFormField(
              controller: _nameController,
              style: TextStyle(color: c.textPrimary),
              decoration: _fieldDecoration('e.g. Rajesh Kumar', c),
              validator: (val) => val == null || val.trim().isEmpty ? 'Name required' : null,
            ),
            const SizedBox(height: 16),

            _buildLabel('Email', c),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(color: c.textPrimary),
              decoration: _fieldDecoration('e.g. instructor@cda.com', c),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Email required';
                if (!val.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 16),

            _buildLabel('Phone Number', c),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: TextStyle(color: c.textPrimary),
              decoration: _fieldDecoration('e.g. 9876543210', c),
              validator: (val) => val == null || val.trim().isEmpty ? 'Phone required' : null,
            ),
            const SizedBox(height: 16),

            _buildLabel('License Number', c),
            TextFormField(
              controller: _licenseController,
              style: TextStyle(color: c.textPrimary),
              decoration: _fieldDecoration('e.g. RPTO/LIC/2026/001', c),
              validator: (val) => val == null || val.trim().isEmpty ? 'License number required' : null,
            ),
            const SizedBox(height: 16),

            _buildLabel('Documents', c),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: c.borderSubtle.withValues(alpha: 0.06)),
              ),
              child: AttachDocumentButton(
                initialDocuments: _documents,
                onDocumentsChanged: (docs) => setState(() => _documents = docs),
              ),
            ),
            const SizedBox(height: 16),

            _buildLabel('Specialization', c),
            DropdownButtonFormField<String>(
              value: _selectedSpecialization,
              dropdownColor: c.surface,
              style: TextStyle(color: c.textPrimary),
              decoration: _fieldDecoration('Select specialization', c),
              items: _specializations
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (val) => setState(() => _selectedSpecialization = val),
            ),
            const SizedBox(height: 16),

            // ---- Company: searchable Autocomplete (type to filter) ----
            // Typing an existing company name (case/whitespace-insensitive)
            // auto-links it to that company's id. Typing a name that isn't
            // in the list is now ALSO accepted as-is (manual entry) — the
            // admin does not have to pick from the dropdown to proceed.
            _buildLabel('Company', c),
            Autocomplete<CompanyModel>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) return _companies;
                return _companies.where((comp) => comp.name
                    .toLowerCase()
                    .contains(textEditingValue.text.toLowerCase()));
              },
              displayStringForOption: (comp) => comp.name,
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                // NOTE: Do NOT force-sync controller.text to
                // _selectedCompanyName here. Autocomplete already updates
                // the field text automatically when a dropdown option is
                // selected (see onSelected below). Force-syncing on every
                // rebuild fought with manual typing — since
                // _selectedCompanyName is trimmed but controller.text can
                // have a trailing space (e.g. right after pressing
                // spacebar), the mismatch caused the field to reset/clear
                // mid-typing.
                return TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  style: TextStyle(color: c.textPrimary),
                  decoration: _fieldDecoration('Type to search or enter company name', c),
                  validator: (val) =>
                  val == null || val.trim().isEmpty ? 'Please enter a company name' : null,
                  onChanged: (val) {
                    // If the typed text exactly matches an existing
                    // company name, link it to that company's id.
                    // Otherwise, accept the typed text as-is as a
                    // manual/new company name (companyId stays null) —
                    // no need to force picking from the dropdown list.
                    final match = _companies.where(
                          (comp) =>
                      comp.name.trim().toLowerCase() ==
                          val.trim().toLowerCase(),
                    );
                    setState(() {
                      if (match.isNotEmpty) {
                        _selectedCompanyId = match.first.id;
                        _selectedCompanyName = match.first.name;
                      } else {
                        _selectedCompanyId = null;
                        _selectedCompanyName = val.isEmpty ? null : val;
                      }
                    });
                  },
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(10),
                    elevation: 4,
                    child: SizedBox(
                      width: 300,
                      height: options.length > 4 ? 220 : options.length * 55.0,
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: options.length,
                        itemBuilder: (context, index) {
                          final comp = options.elementAt(index);
                          return ListTile(
                            title: Text(comp.name, style: TextStyle(color: c.textPrimary)),
                            onTap: () => onSelected(comp),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
              onSelected: (comp) {
                setState(() {
                  _selectedCompanyId = comp.id;
                  _selectedCompanyName = comp.name;
                });
              },
            ),
            const SizedBox(height: 16),

            _buildLabel('Experience', c),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _experienceController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: c.textPrimary),
                    decoration: _fieldDecoration('Years (e.g. 5)', c),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _experienceMonthsController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: c.textPrimary),
                    decoration: _fieldDecoration('Months (e.g. 6)', c),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return null; // optional
                      final m = int.tryParse(val.trim());
                      if (m == null || m < 0 || m > 11) return '0-11 only';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _buildLabel('Status', c),
            Row(
              children: ['Active', 'Inactive'].map((s) {
                final isSelected = _status == s;
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: ChoiceChip(
                    label: Text(s),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _status = s),
                    selectedColor: c.accent,
                    backgroundColor: c.surface,
                    labelStyle: TextStyle(color: isSelected ? c.background : c.textSecondary),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveInstructor,
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.accent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(color: c.background, strokeWidth: 2),
                )
                    : Text('Add Instructor',
                    style: TextStyle(color: c.background, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text, CompanyColors c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(color: c.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}