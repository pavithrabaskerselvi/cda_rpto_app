import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/constants.dart';
import '../../config/theme_colors.dart';
import '../../models/student_model.dart';

class StudentEditScreen extends StatefulWidget {
  final StudentModel student;
  const StudentEditScreen({super.key, required this.student});

  @override
  State<StudentEditScreen> createState() => _StudentEditScreenState();
}

class _StudentEditScreenState extends State<StudentEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _stateCtrl;
  late TextEditingController _placeCtrl;

  late String _status;
  String? _batchId;
  String? _batchName;
  String? _companyId;
  String? _companyName;
  DateTime? _enrollmentDate;
  bool _saving = false;

  final List<String> _statuses = ['Active', 'Completed', 'Dropped'];

  @override
  void initState() {
    super.initState();
    final s = widget.student;
    _nameCtrl = TextEditingController(text: s.name);
    _emailCtrl = TextEditingController(text: s.email);
    _phoneCtrl = TextEditingController(text: s.phone);
    _stateCtrl = TextEditingController(text: s.state);
    _placeCtrl = TextEditingController(text: s.place);
    _status = s.status;
    _batchId = s.batchId;
    _batchName = s.batchName;
    _companyId = s.companyId;
    _companyName = s.companyName;
    _enrollmentDate = s.enrollmentDate;
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

  Future<void> _pickDate() async {
    final isDark = ThemeColors.isDark(context);
    final picked = await showDatePicker(
      context: context,
      initialDate: _enrollmentDate ?? DateTime.now(),
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: isDark
            ? ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(primary: kTeal, surface: kSurface))
            : ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: kTeal)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _enrollmentDate = picked);
  }

  Future<void> _updateStudent() async {
    if (!_formKey.currentState!.validate()) return;
    if (_batchId == null || _companyId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Select batch and company')));
      return;
    }
    setState(() => _saving = true);

    try {
      final updated = widget.student.copyWith(
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        state: _stateCtrl.text.trim(),
        place: _placeCtrl.text.trim(),
        batchId: _batchId,
        batchName: _batchName,
        companyId: _companyId,
        companyName: _companyName,
        status: _status,
        enrollmentDate: _enrollmentDate,
        updatedAt: DateTime.now(),
      );
      await FirebaseFirestore.instance
          .collection('students')
          .doc(widget.student.id)
          .update(updated.toMap());
      if (mounted) {
        Navigator.pop(context);
        Navigator.pop(context); // back to list past the detail screen
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error updating student: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _decoration(BuildContext context, String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: ThemeColors.textSecondary(context)),
      filled: true,
      fillColor: ThemeColors.surface(context),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColors.bg(context),
      appBar: AppBar(
        backgroundColor: ThemeColors.bg(context),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: ThemeColors.textPrimary(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Edit Student',
            style: TextStyle(
                color: ThemeColors.textPrimary(context),
                fontWeight: FontWeight.bold)),
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
                style: TextStyle(color: ThemeColors.textPrimary(context)),
                decoration: _decoration(context, 'Full Name *'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _emailCtrl,
                style: TextStyle(color: ThemeColors.textPrimary(context)),
                keyboardType: TextInputType.emailAddress,
                decoration: _decoration(context, 'Email'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phoneCtrl,
                style: TextStyle(color: ThemeColors.textPrimary(context)),
                keyboardType: TextInputType.phone,
                decoration: _decoration(context, 'Phone *'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _stateCtrl,
                style: TextStyle(color: ThemeColors.textPrimary(context)),
                textCapitalization: TextCapitalization.words,
                decoration: _decoration(context, 'State *'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _placeCtrl,
                style: TextStyle(color: ThemeColors.textPrimary(context)),
                textCapitalization: TextCapitalization.words,
                decoration: _decoration(context, 'Place (City/Town) *'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _status,
                dropdownColor: ThemeColors.surface(context),
                style: TextStyle(color: ThemeColors.textPrimary(context)),
                decoration: _decoration(context, 'Status'),
                items: _statuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setState(() => _status = v!),
              ),
              const SizedBox(height: 14),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('batches').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const LinearProgressIndicator(color: kTeal);
                  final batches = snapshot.data!.docs;
                  final validIds = batches.map((b) => b.id).toSet();
                  final currentValue = validIds.contains(_batchId) ? _batchId : null;
                  return DropdownButtonFormField<String>(
                    initialValue: currentValue,
                    dropdownColor: ThemeColors.surface(context),
                    style: TextStyle(color: ThemeColors.textPrimary(context)),
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
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('branches').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const LinearProgressIndicator(color: kTeal);
                  final companies = snapshot.data!.docs;
                  final validIds = companies.map((c) => c.id).toSet();
                  final currentValue = validIds.contains(_companyId) ? _companyId : null;
                  return DropdownButtonFormField<String>(
                    initialValue: currentValue,
                    dropdownColor: ThemeColors.surface(context),
                    style: TextStyle(color: ThemeColors.textPrimary(context)),
                    decoration: _decoration(context, 'Branch *'),
                    items: companies.map((c) {
                      final data = c.data() as Map<String, dynamic>;
                      final name = data['branchName'] ?? data['companyName'] ?? data['name'] ?? c.id;
                      return DropdownMenuItem(value: c.id, child: Text(name));
                    }).toList(),
                    onChanged: (v) {
                      final match = companies.firstWhere((c) => c.id == v);
                      final data = match.data() as Map<String, dynamic>;
                      setState(() {
                        _companyId = v;
                        _companyName = data['branchName'] ?? data['companyName'] ?? data['name'] ?? '';
                      });
                    },
                    validator: (v) => v == null ? 'Select a branch' : null,
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
                    style: TextStyle(color: ThemeColors.textPrimary(context)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saving ? null : _updateStudent,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kTeal,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
                    : const Text('Update Student',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}