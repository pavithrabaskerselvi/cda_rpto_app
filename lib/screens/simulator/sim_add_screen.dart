import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/simulator_model.dart';
import '../../widgets/attach_document_button.dart';

class SimAddScreen extends StatefulWidget {
  // 🆕 When non-null, the screen opens in "Edit" mode, prefilled with this
  // simulator's data. Saving updates the existing Firestore doc instead of
  // creating a new one.
  final SimulatorModel? existingSimulator;

  const SimAddScreen({super.key, this.existingSimulator});

  @override
  State<SimAddScreen> createState() => _SimAddScreenState();
}

class _SimAddScreenState extends State<SimAddScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _modelController = TextEditingController();
  final _serialController = TextEditingController();

  String _status = 'Available';
  bool _isSaving = false;

  String? _selectedCompanyId;
  String? _selectedCompanyName;

  bool get _isEditing => widget.existingSimulator != null;

  // --- Documents attached locally until the simulator is saved ---
  // (Only used in "add" mode — see note near the Documents section below.)
  List<AttachedDocument> _documents = [];

  @override
  void initState() {
    super.initState();
    final existing = widget.existingSimulator;
    if (existing != null) {
      _nameController.text = existing.simulatorName;
      _modelController.text = existing.model;
      _serialController.text = existing.serialNumber;
      _status = existing.status;
      _selectedCompanyName = existing.companyName;
      // companyId isn't guaranteed to be exposed on the model, so fetch it
      // straight from the document to correctly preselect the dropdown.
      FirebaseFirestore.instance
          .collection('simulators')
          .doc(existing.id)
          .get()
          .then((doc) {
        final data = doc.data();
        if (mounted && data != null) {
          setState(() => _selectedCompanyId = data['companyId'] as String?);
        }
      });
    }
  }

  // ---- Theme-aware colors instead of hardcoded kNavy/kSurface constants ----
  bool _isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;
  Color _bg(BuildContext c) =>
      _isDark(c) ? const Color(0xFF05070D) : const Color(0xFFF5F7FA);
  Color _surface(BuildContext c) =>
      _isDark(c) ? const Color(0xFF10141F) : const Color(0xFFFFFFFF);
  Color _textPrimary(BuildContext c) =>
      _isDark(c) ? const Color(0xFFF5F6FA) : const Color(0xFF0B1220);
  Color _textSecondary(BuildContext c) =>
      _isDark(c) ? const Color(0xFF8A93A6) : const Color(0xFF5B6472);
  Color _textMuted(BuildContext c) =>
      _isDark(c) ? const Color(0xFF6B7280) : const Color(0xFF9AA3B2);
  Color _danger(BuildContext c) =>
      _isDark(c) ? const Color(0xFFE0685A) : const Color(0xFFC94A3B);
  Color _green(BuildContext c) =>
      _isDark(c) ? const Color(0xFF3FCE8E) : const Color(0xFF1F9D63);
  static const Color teal = Color(0xFF2DD4BF); // brand accent, same both modes

  InputDecoration _fieldDecoration(BuildContext context, String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: _textMuted(context)),
      filled: true,
      fillColor: _surface(context),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
    );
  }

  static const TextStyle _labelStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
  );

  Future<void> _saveSimulator() async {
    // Run form validation (fields themselves have no "required" validators
    // anymore, but this keeps any future validators working).
    if (!_formKey.currentState!.validate()) return;

    final hasName = _nameController.text.trim().isNotEmpty;
    final hasModel = _modelController.text.trim().isNotEmpty;
    final hasSerial = _serialController.text.trim().isNotEmpty;
    final hasCompany = _selectedCompanyId != null;
    final hasDocuments = _documents.isNotEmpty;

    // Nothing at all filled in and no document attached -> block save.
    if (!_isEditing &&
        !hasName &&
        !hasModel &&
        !hasSerial &&
        !hasCompany &&
        !hasDocuments) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please fill at least one field or attach a document'),
          backgroundColor: _danger(context),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      if (_isEditing) {
        // update() only touches the fields listed here, so any existing
        // 'documents' array on the doc is left completely untouched.
        await FirebaseFirestore.instance
            .collection('simulators')
            .doc(widget.existingSimulator!.id)
            .update({
          'simulatorName': _nameController.text.trim(),
          'model': _modelController.text.trim(),
          'serialNumber': _serialController.text.trim(),
          'companyId': _selectedCompanyId,
          'companyName': _selectedCompanyName,
          'status': _status,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: const Text('Simulator updated'), backgroundColor: _green(context)),
          );
          Navigator.pop(context, true);
        }
      } else {
        await FirebaseFirestore.instance.collection('simulators').add({
          'simulatorName': _nameController.text.trim(),
          'model': _modelController.text.trim(),
          'serialNumber': _serialController.text.trim(),
          'companyId': _selectedCompanyId,
          'companyName': _selectedCompanyName,
          'status': _status,
          'createdAt': FieldValue.serverTimestamp(),
          'documents': _documents.map((d) => d.toMap()).toList(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: const Text('Simulator added successfully'), backgroundColor: _green(context)),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'), backgroundColor: _danger(context)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _modelController.dispose();
    _serialController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg(context),
      appBar: AppBar(
        backgroundColor: _bg(context),
        title: Text(_isEditing ? 'Edit Simulator' : 'Add Simulator',
            style: TextStyle(color: _textPrimary(context))),
        iconTheme: IconThemeData(color: _textPrimary(context)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildLabel(context, 'Simulator Name'),
            TextFormField(
              controller: _nameController,
              style: TextStyle(color: _textPrimary(context)),
              decoration: _fieldDecoration(context, 'e.g. VR Drone Sim Unit 1'),
              // Optional now — no validator.
            ),
            const SizedBox(height: 16),

            _buildLabel(context, 'Model'),
            TextFormField(
              controller: _modelController,
              style: TextStyle(color: _textPrimary(context)),
              decoration: _fieldDecoration(context, 'e.g. DJI FlightSim Pro'),
              // Optional now — no validator.
            ),
            const SizedBox(height: 16),

            _buildLabel(context, 'Serial Number'),
            TextFormField(
              controller: _serialController,
              style: TextStyle(color: _textPrimary(context)),
              decoration: _fieldDecoration(context, 'e.g. SN-2026-00123'),
              // Optional now — no validator.
            ),
            const SizedBox(height: 16),

            _buildLabel(context, 'Company'),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('companies').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator(color: teal));
                }
                final companies = snapshot.data!.docs;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: _surface(context),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      dropdownColor: _surface(context),
                      value: _selectedCompanyId,
                      hint: Text('Select company', style: TextStyle(color: _textMuted(context))),
                      style: TextStyle(color: _textPrimary(context)),
                      items: companies.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return DropdownMenuItem<String>(
                          value: doc.id,
                          child: Text(data['name'] ?? ''),
                          onTap: () => _selectedCompanyName = data['name'] ?? '',
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedCompanyId = val),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Documents are only editable from the Add flow here. In Edit
            // mode we deliberately leave the existing 'documents' array on
            // the Firestore doc untouched (see _saveSimulator), so we don't
            // show an attach control that could look like it holds the
            // current attachments when it doesn't.
            if (!_isEditing) ...[
              _buildLabel(context, 'Documents'),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _surface(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _textMuted(context).withOpacity(0.15)),
                ),
                child: AttachDocumentButton(
                  initialDocuments: _documents,
                  onDocumentsChanged: (docs) => setState(() => _documents = docs),
                ),
              ),
              const SizedBox(height: 16),
            ],

            _buildLabel(context, 'Status'),
            Row(
              children: ['Available', 'In Use', 'Under Maintenance'].map((s) {
                final isSelected = _status == s;
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: ChoiceChip(
                    label: Text(s, style: const TextStyle(fontSize: 12)),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _status = s),
                    selectedColor: teal,
                    backgroundColor: _surface(context),
                    labelStyle: TextStyle(
                        color: isSelected ? _bg(context) : _textSecondary(context)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveSimulator,
                style: ElevatedButton.styleFrom(
                  backgroundColor: teal,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(color: _bg(context), strokeWidth: 2),
                )
                    : Text(_isEditing ? 'Save Changes' : 'Add Simulator',
                    style: TextStyle(color: _bg(context), fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: _labelStyle.copyWith(color: _textPrimary(context))),
    );
  }
}