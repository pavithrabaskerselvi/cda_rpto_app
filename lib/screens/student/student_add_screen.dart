import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/student_model.dart';

class StudentAddScreen extends StatefulWidget {
  // Optional: pre-select and lock the batch when opened from a batch's
  // own "Add Student" button, so the person doesn't have to pick it again.
  final String? preselectedBatchId;
  final String? preselectedBatchName;

  const StudentAddScreen({
    super.key,
    this.preselectedBatchId,
    this.preselectedBatchName,
  });

  @override
  State<StudentAddScreen> createState() => _StudentAddScreenState();
}

class _StudentAddScreenState extends State<StudentAddScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _placeCtrl = TextEditingController();

  String? _batchId;
  String? _batchName;
  String _status = 'Active';
  String? _companyId;
  String? _companyName;
  DateTime? _enrollmentDate;
  bool _saving = false;

  final List<String> _statuses = ['Active', 'Completed', 'Dropped'];

  @override
  void initState() {
    super.initState();
    _batchId = widget.preselectedBatchId;
    _batchName = widget.preselectedBatchName;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _stateCtrl.dispose();
    _placeCtrl.dispose();
    super.dispose();
  }

  // ---- Theme-aware colors instead of hardcoded kNavy/kSurface constants ----
  bool _isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;
  Color _bg(BuildContext c) =>
      _isDark(c) ? const Color(0xFF050A14) : const Color(0xFFF5F7FA);
  Color _surface(BuildContext c) =>
      _isDark(c) ? const Color(0xFF0F1B2E) : const Color(0xFFFFFFFF);
  Color _textPrimary(BuildContext c) =>
      _isDark(c) ? Colors.white : const Color(0xFF0B1220);
  Color _textSecondary(BuildContext c) =>
      _isDark(c) ? Colors.white70 : const Color(0xFF5B6472);
  static const Color teal = Color(0xFF14B8A6); // brand accent, same both modes

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _enrollmentDate ?? DateTime.now(),
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: _isDark(context)
            ? ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
                primary: teal, surface: _surface(context)))
            : ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
                primary: teal, surface: _surface(context))),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _enrollmentDate = picked);
  }

  Future<void> _saveStudent() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    if (_batchId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Select a batch')));
      return;
    }

    try {
      final docRef = FirebaseFirestore.instance.collection('students').doc();
      final student = StudentModel(
        id: docRef.id,
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        state: _stateCtrl.text.trim(),
        place: _placeCtrl.text.trim(),
        batchId: _batchId!,
        batchName: _batchName ?? '',
        companyId: _companyId ?? '',
        companyName: _companyName ?? '',
        status: _status,
        enrollmentDate: _enrollmentDate,
        createdAt: DateTime.now(),
      );
      await docRef.set(student.toMap());
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error saving student: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _decoration(BuildContext context, String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: _textSecondary(context)),
      filled: true,
      fillColor: _surface(context),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg(context),
      appBar: AppBar(
        backgroundColor: _bg(context),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _textPrimary(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Add Student',
            style: TextStyle(
                color: _textPrimary(context), fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameCtrl,
                style: TextStyle(color: _textPrimary(context)),
                decoration: _decoration(context, 'Full Name *'),
                validator: (v) =>
                v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _emailCtrl,
                style: TextStyle(color: _textPrimary(context)),
                keyboardType: TextInputType.emailAddress,
                decoration: _decoration(context, 'Email'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phoneCtrl,
                style: TextStyle(color: _textPrimary(context)),
                keyboardType: TextInputType.phone,
                decoration: _decoration(context, 'Phone *'),
                validator: (v) =>
                v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _stateCtrl,
                style: TextStyle(color: _textPrimary(context)),
                textCapitalization: TextCapitalization.words,
                decoration: _decoration(context, 'State *'),
                validator: (v) =>
                v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _placeCtrl,
                style: TextStyle(color: _textPrimary(context)),
                textCapitalization: TextCapitalization.words,
                decoration: _decoration(context, 'Place (City/Town) *'),
                validator: (v) =>
                v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _status,
                dropdownColor: _surface(context),
                style: TextStyle(color: _textPrimary(context)),
                decoration: _decoration(context, 'Status'),
                items: _statuses
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setState(() => _status = v!),
              ),
              const SizedBox(height: 14),
              widget.preselectedBatchId != null
                  ? TextFormField(
                enabled: false,
                style: TextStyle(color: _textPrimary(context)),
                controller: TextEditingController(text: _batchName ?? ''),
                decoration: _decoration(context, 'Batch *'),
              )
                  : StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('batches').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return LinearProgressIndicator(color: teal);
                  }
                  final batches = snapshot.data!.docs;
                  final validIds = batches.map((b) => b.id).toSet();
                  final currentValue = validIds.contains(_batchId) ? _batchId : null;
                  return DropdownButtonFormField<String>(
                    initialValue: currentValue,
                    dropdownColor: _surface(context),
                    style: TextStyle(color: _textPrimary(context)),
                    decoration: _decoration(context, 'Batch *'),
                    items: batches.map((b) {
                      final data = b.data() as Map<String, dynamic>;
                      final name = data['batchName'] ?? data['name'] ?? b.id;
                      return DropdownMenuItem(value: b.id, child: Text(name));
                    }).toList(),
                    onChanged: (v) {
                      final match = batches.firstWhere((b) => b.id == v);
                      final data = match.data() as Map<String, dynamic>;
                      setState(() {
                        _batchId = v;
                        _batchName = data['batchName'] ?? data['name'] ?? '';
                      });
                    },
                    validator: (v) => v == null ? 'Select a batch' : null,
                  );
                },
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: _decoration(context, 'Enrollment Date'),
                  child: Text(
                    _enrollmentDate != null
                        ? '${_enrollmentDate!.day}/${_enrollmentDate!.month}/${_enrollmentDate!.year}'
                        : 'Select date',
                    style: TextStyle(color: _textPrimary(context)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saving ? null : _saveStudent,
                style: ElevatedButton.styleFrom(
                  backgroundColor: teal,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
                    : const Text('Save Student',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}