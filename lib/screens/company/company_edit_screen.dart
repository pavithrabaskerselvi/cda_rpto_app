import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/company_model.dart';
import '../../config/constants.dart';
import '../../config/theme_colors.dart';

// Edit screen for an existing company. Mirrors company_add_screen.dart but
// pre-fills all fields from the company being edited and performs a
// Firestore `update()` instead of `add()`.
class CompanyEditScreen extends StatefulWidget {
  final CompanyModel company;

  const CompanyEditScreen({super.key, required this.company});

  @override
  State<CompanyEditScreen> createState() => _CompanyEditScreenState();
}

class _CompanyEditScreenState extends State<CompanyEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _tradeNameController;
  late final TextEditingController _regController;
  late final TextEditingController _addressController;
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  late final TextEditingController _pincodeController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;

  late String _status;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final co = widget.company;
    _nameController = TextEditingController(text: co.name);
    _tradeNameController = TextEditingController(text: co.tradeName);
    _regController = TextEditingController(text: co.registrationNumber);
    _addressController = TextEditingController(text: co.address);
    _cityController = TextEditingController(text: co.city);
    _stateController = TextEditingController(text: co.state);
    _pincodeController = TextEditingController(text: co.pincode);
    _emailController = TextEditingController(text: co.contactEmail);
    _phoneController = TextEditingController(text: co.contactPhone);
    _status = co.status;
  }

  Future<void> _saveCompany() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.company.id)
          .update({
        'name': _nameController.text.trim(),
        'tradeName': _tradeNameController.text.trim(),
        'registrationNumber': _regController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'pincode': _pincodeController.text.trim(),
        'contactEmail': _emailController.text.trim(),
        'contactPhone': _phoneController.text.trim(),
        'status': _status,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Details updated successfully'),
            backgroundColor: kGreen,
          ),
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
    _tradeNameController.dispose();
    _regController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
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
    final c = CompanyColors.of(false);

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        title: Text('Edit Details', style: TextStyle(color: c.textPrimary)),
        iconTheme: IconThemeData(color: c.textPrimary),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildLabel('Company Name', c),
            TextFormField(
              controller: _nameController,
              style: TextStyle(color: c.textPrimary),
              decoration: _fieldDecoration('e.g. Chennai Drone Academy', c),
              validator: (val) => val == null || val.trim().isEmpty ? 'Name required' : null,
            ),
            const SizedBox(height: 16),

            _buildLabel('Trade Name', c),
            TextFormField(
              controller: _tradeNameController,
              style: TextStyle(color: c.textPrimary),
              decoration: _fieldDecoration('e.g. SkyLynk Drones', c),
            ),
            const SizedBox(height: 16),

            _buildLabel('Authorization Number', c),
            TextFormField(
              controller: _regController,
              style: TextStyle(color: c.textPrimary),
              decoration: _fieldDecoration('e.g. RPTO/AUTH/2026/001', c),
              validator: (val) => val == null || val.trim().isEmpty ? 'Authorization number required' : null,
            ),
            const SizedBox(height: 16),

            _buildLabel('Address', c),
            TextFormField(
              controller: _addressController,
              maxLines: 2,
              style: TextStyle(color: c.textPrimary),
              decoration: _fieldDecoration('Street, area', c),
              validator: (val) => val == null || val.trim().isEmpty ? 'Address required' : null,
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('City', c),
                      TextFormField(
                        controller: _cityController,
                        style: TextStyle(color: c.textPrimary),
                        decoration: _fieldDecoration('e.g. Chennai', c),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('State', c),
                      TextFormField(
                        controller: _stateController,
                        style: TextStyle(color: c.textPrimary),
                        decoration: _fieldDecoration('e.g. Tamil Nadu', c),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _buildLabel('Pincode', c),
            TextFormField(
              controller: _pincodeController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: c.textPrimary),
              decoration: _fieldDecoration('e.g. 600019', c),
              validator: (val) => val == null || val.trim().isEmpty ? 'Pincode required' : null,
            ),
            const SizedBox(height: 16),

            _buildLabel('Contact Email', c),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(color: c.textPrimary),
              decoration: _fieldDecoration('e.g. company@cda.com', c),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Email required';
                if (!val.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 16),

            _buildLabel('Contact Phone', c),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: TextStyle(color: c.textPrimary),
              decoration: _fieldDecoration('e.g. 9876543210', c),
              validator: (val) => val == null || val.trim().isEmpty ? 'Phone required' : null,
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
                onPressed: _isSaving ? null : _saveCompany,
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
                    : Text(
                  'Save Changes',
                  style: TextStyle(color: c.background, fontWeight: FontWeight.w600),
                ),
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