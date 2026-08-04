import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/company_model.dart';
import '../../models/instructor_model.dart';
import '../../config/constants.dart';
import '../../config/theme_colors.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/attach_document_button.dart';

// Edit screen for an existing instructor. Mirrors instructor_add_screen.dart
// but pre-fills all fields from the instructor being edited and performs
// a Firestore `update()` instead of `add()`.
class InstructorEditScreen extends StatefulWidget {
  final InstructorModel instructor;

  const InstructorEditScreen({super.key, required this.instructor});

  @override
  State<InstructorEditScreen> createState() => _InstructorEditScreenState();
}

class _InstructorEditScreenState extends State<InstructorEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _licenseController;
  late final TextEditingController _experienceController;
  late final TextEditingController _experienceMonthsController;

  String? _selectedSpecialization;
  String? _selectedCompanyId;
  String? _selectedCompanyName;
  late String _status;

  bool _isLoadingCompanies = true;
  bool _isSaving = false;
  List<CompanyModel> _companies = [];

  // --- Documents state ---
  late List<AttachedDocument> _documents;

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
    final i = widget.instructor;
    _nameController = TextEditingController(text: i.name);
    _emailController = TextEditingController(text: i.email);
    _phoneController = TextEditingController(text: i.phone);
    _licenseController = TextEditingController(text: i.licenseNumber);
    _experienceController = TextEditingController(text: i.experienceYears.toString());
    _experienceMonthsController = TextEditingController(text: i.experienceMonths.toString());
    // If the instructor's saved specialization isn't in the current list
    // (e.g. an older record), fall back to null so the dropdown doesn't crash.
    _selectedSpecialization =
    _specializations.contains(i.specialization) ? i.specialization : null;
    _selectedCompanyId = i.companyId;
    _selectedCompanyName = i.companyName;
    _status = i.status;
    _documents = List<AttachedDocument>.from(i.documents);
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
      await FirebaseFirestore.instance
          .collection('instructors')
          .doc(widget.instructor.id)
          .update({
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
        'documents': _documents.map((d) => d.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Instructor updated successfully'), backgroundColor: kGreen),
        );
        Navigator.pop(context, true); // signal caller to refresh/pop further
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'), backgroundColor: kCoral),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
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

  Widget _buildThemeToggle(bool isDark, CompanyColors c) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wb_sunny_outlined,
              size: 18, color: isDark ? c.textSecondary : c.accent),
          Switch(
            value: isDark,
            activeThumbColor: c.accent,
            onChanged: (val) => context.read<ThemeProvider>().toggleTheme(val),
          ),
          Icon(Icons.nightlight_round,
              size: 18, color: isDark ? c.accent : c.textSecondary),
        ],
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
        title: Text('Edit Instructor', style: TextStyle(color: c.textPrimary)),
        iconTheme: IconThemeData(color: c.textPrimary),
        actions: [_buildThemeToggle(isDark, c)],
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
            // Typing an existing company name links it to that company's
            // id. A name that isn't in the list is accepted as-is
            // (manual entry) — no need to pick from the dropdown.
            _buildLabel('Company', c),
            Autocomplete<CompanyModel>(
              initialValue: TextEditingValue(text: _selectedCompanyName ?? ''),
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) return _companies;
                return _companies.where((comp) => comp.name
                    .toLowerCase()
                    .contains(textEditingValue.text.toLowerCase()));
              },
              displayStringForOption: (comp) => comp.name,
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                // NOTE: We do NOT force-sync controller.text to
                // _selectedCompanyName on every rebuild — that fights
                // manual typing (e.g. breaks on spacebar). Autocomplete
                // already updates the field text automatically when a
                // dropdown option is selected (see onSelected below).
                return TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  style: TextStyle(color: c.textPrimary),
                  decoration: _fieldDecoration('Type to search or enter company name', c),
                  validator: (val) =>
                  val == null || val.trim().isEmpty ? 'Please enter a company name' : null,
                  onChanged: (val) {
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
                    : Text('Save Changes',
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