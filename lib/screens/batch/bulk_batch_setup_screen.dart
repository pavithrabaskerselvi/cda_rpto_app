import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// BulkBatchSetupScreen
/// ---------------------
/// Built for onboarding many existing batches at once (e.g. importing
/// 12 batches / 178 students from old records) without clicking through
/// "Add Batch" then "Add Student" one name at a time.
///
/// Flow: fill in the batch details once, paste every student name for
/// that batch (one per line — works great pasted straight from a Drive
/// folder listing like "01. JAGANATHAN"), hit Save. This creates the
/// batch document AND one student document per line in a single
/// Firestore batched write.
///
/// Repeat once per batch (12 times) instead of once per student (178
/// times).
class BulkBatchSetupScreen extends StatefulWidget {
  const BulkBatchSetupScreen({super.key});

  @override
  State<BulkBatchSetupScreen> createState() => _BulkBatchSetupScreenState();
}

class _BulkBatchSetupScreenState extends State<BulkBatchSetupScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _batchNameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _scheduleDaysController = TextEditingController();
  final TextEditingController _sessionDurationController = TextEditingController();
  final TextEditingController _maxCapacityController = TextEditingController();
  final TextEditingController _targetFlyingHoursController = TextEditingController();
  final TextEditingController _targetSimulatorHoursController = TextEditingController();
  final TextEditingController _feeAmountController = TextEditingController();
  final TextEditingController _studentNamesController = TextEditingController();

  String? _selectedInstructor;
  String _selectedStatus = 'Upcoming';
  String _selectedCategory = 'RPTO';
  DateTime? _startDate;
  DateTime? _endDate;

  bool _isSaving = false;
  int _succeeded = 0;
  int _failed = 0;

  final List<String> _statusOptions = ['Upcoming', 'Ongoing', 'Completed'];
  final List<String> _categoryOptions = ['RPTO', 'FPV', 'Aerial'];

  bool _isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;
  Color _kNavy(BuildContext c) =>
      _isDark(c) ? const Color(0xFF05070D) : const Color(0xFFF7F8FA);
  Color _kSurface(BuildContext c) =>
      _isDark(c) ? const Color(0xFF10141F) : const Color(0xFFFFFFFF);
  Color _kTeal(BuildContext c) =>
      _isDark(c) ? const Color(0xFF2DD4BF) : const Color(0xFF0F9E93);
  Color _kTextPrimary(BuildContext c) =>
      _isDark(c) ? const Color(0xFFF5F6FA) : const Color(0xFF0F172A);
  Color _kTextSecondary(BuildContext c) =>
      _isDark(c) ? const Color(0xFF9CA3AF) : const Color(0xFF5B6472);
  Color _kBorder(BuildContext c) =>
      _isDark(c) ? const Color(0xFF1F2937) : const Color(0xFFE2E5EA);

  @override
  void dispose() {
    _batchNameController.dispose();
    _locationController.dispose();
    _scheduleDaysController.dispose();
    _sessionDurationController.dispose();
    _maxCapacityController.dispose();
    _targetFlyingHoursController.dispose();
    _targetSimulatorHoursController.dispose();
    _feeAmountController.dispose();
    _studentNamesController.dispose();
    super.dispose();
  }

  /// Splits the pasted textarea into clean student names: one per
  /// non-empty line, with a leading "01. " / "1) " / "1 - " style
  /// numbering (as seen in Drive folder names) stripped off.
  List<String> get _parsedStudentNames {
    return _studentNamesController.text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) => line.replaceFirst(RegExp(r'^\d+\s*[\.\)\-]\s*'), '').trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? (_startDate ?? now) : (_endDate ?? _startDate ?? now),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
      builder: (context, child) {
        final dark = _isDark(context);
        return Theme(
          data: dark
              ? ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: _kTeal(context),
              surface: _kSurface(context),
              onSurface: Colors.white,
            ),
          )
              : ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: _kTeal(context),
              surface: _kSurface(context),
              onSurface: _kTextPrimary(context),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = null;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Select date';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  InputDecoration _inputDecoration(BuildContext context, String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: _kTextSecondary(context)),
      prefixIcon: icon != null ? Icon(icon, color: _kTextSecondary(context)) : null,
      filled: true,
      fillColor: _kSurface(context),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _kBorder(context)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _kBorder(context)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _kTeal(context), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }

  Future<void> _saveBatchWithStudents() async {
    if (!_formKey.currentState!.validate()) return;

    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select start and end dates'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    if (_selectedInstructor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an instructor'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final names = _parsedStudentNames;
    if (names.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Paste at least one student name'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _succeeded = 0;
      _failed = 0;
    });

    try {
      final firestore = FirebaseFirestore.instance;
      final batchDocRef = firestore.collection('batches').doc();

      // Firestore write batches cap at 500 operations. 1 batch doc +
      // up to a few hundred student docs comfortably fits for a single
      // course batch, but split into chunks of 400 students just in
      // case someone pastes an unusually large list.
      const chunkSize = 400;
      var remaining = List<String>.from(names);
      var isFirstChunk = true;

      while (remaining.isNotEmpty) {
        final chunk = remaining.take(chunkSize).toList();
        remaining = remaining.skip(chunkSize).toList();

        final writeBatch = firestore.batch();

        if (isFirstChunk) {
          writeBatch.set(batchDocRef, {
            'batchName': _batchNameController.text.trim(),
            'instructor': _selectedInstructor,
            'studentCount': names.length,
            'status': _selectedStatus,
            'category': _selectedCategory,
            'location': _locationController.text.trim(),
            'scheduleDays': _scheduleDaysController.text.trim(),
            'startDate': Timestamp.fromDate(_startDate!),
            'endDate': Timestamp.fromDate(_endDate!),
            'sessionDuration': _sessionDurationController.text.trim(),
            'maxCapacity': int.tryParse(_maxCapacityController.text.trim()) ?? 0,
            'targetFlyingHours': num.tryParse(_targetFlyingHoursController.text.trim()) ?? 0,
            'targetSimulatorHours': num.tryParse(_targetSimulatorHoursController.text.trim()) ?? 0,
            'feeAmount': num.tryParse(_feeAmountController.text.trim()) ?? 0,
            'createdAt': FieldValue.serverTimestamp(),
          });
          isFirstChunk = false;
        }

        for (final name in chunk) {
          final studentDocRef = firestore.collection('students').doc();
          writeBatch.set(studentDocRef, {
            'name': name,
            'email': '',
            'phone': '',
            'state': '',
            'place': '',
            'batchId': batchDocRef.id,
            'batchName': _batchNameController.text.trim(),
            'companyId': '',
            'companyName': '',
            'status': 'Active',
            'enrollmentDate': Timestamp.fromDate(_startDate!),
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        try {
          await writeBatch.commit();
          setState(() => _succeeded += chunk.length);
        } catch (_) {
          setState(() => _failed += chunk.length);
        }
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: _kSurface(dialogContext),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              'Batch created',
              style: TextStyle(color: _kTextPrimary(dialogContext)),
            ),
            content: Text(
              '"${_batchNameController.text.trim()}" was created with '
                  '$_succeeded student${_succeeded == 1 ? '' : 's'} added'
                  '${_failed > 0 ? ' ($_failed failed — try again for those)' : ''}.',
              style: TextStyle(color: _kTextSecondary(dialogContext)),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  Navigator.of(context).pop();
                },
                child: Text('Done', style: TextStyle(color: _kTeal(dialogContext))),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving batch: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final names = _parsedStudentNames;

    return Scaffold(
      backgroundColor: _kNavy(context),
      appBar: AppBar(
        backgroundColor: _kNavy(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _kTextPrimary(context)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Bulk Batch Setup',
          style: TextStyle(
            color: _kTextPrimary(context),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _kSurface(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kBorder(context)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: _kTeal(context), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Fill in the batch info once, paste every student name below '
                          '(one per line), then Save. This creates the batch and all '
                          'its students together.',
                      style: TextStyle(color: _kTextSecondary(context), fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _batchNameController,
              style: TextStyle(color: _kTextPrimary(context)),
              decoration: _inputDecoration(context, 'Batch Name', icon: Icons.badge_outlined),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Batch name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              dropdownColor: _kSurface(context),
              style: TextStyle(color: _kTextPrimary(context)),
              decoration: _inputDecoration(context, 'Category', icon: Icons.category_outlined),
              items: _categoryOptions
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedCategory = v ?? 'RPTO'),
            ),
            const SizedBox(height: 16),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('instructors')
                  .orderBy('name')
                  .snapshots(),
              builder: (context, snapshot) {
                final instructorNames = <String>[];
                if (snapshot.hasData) {
                  for (final doc in snapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = data['name'];
                    if (name != null) instructorNames.add(name.toString());
                  }
                }
                return DropdownButtonFormField<String>(
                  initialValue: _selectedInstructor,
                  dropdownColor: _kSurface(context),
                  style: TextStyle(color: _kTextPrimary(context)),
                  decoration: _inputDecoration(context, 'Instructor', icon: Icons.person_outline),
                  items: instructorNames
                      .map((name) => DropdownMenuItem(value: name, child: Text(name)))
                      .toList(),
                  onChanged: (value) => setState(() => _selectedInstructor = value),
                  validator: (value) => value == null ? 'Please select an instructor' : null,
                );
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _locationController,
              style: TextStyle(color: _kTextPrimary(context)),
              decoration: _inputDecoration(context, 'Location', icon: Icons.location_on_outlined),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _scheduleDaysController,
              style: TextStyle(color: _kTextPrimary(context)),
              decoration: _inputDecoration(context, 'Schedule Days', icon: Icons.event_repeat_outlined)
                  .copyWith(hintText: 'e.g. Mon, Wed, Fri'),
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              initialValue: _selectedStatus,
              dropdownColor: _kSurface(context),
              style: TextStyle(color: _kTextPrimary(context)),
              decoration: _inputDecoration(context, 'Status', icon: Icons.flag_outlined),
              items: _statusOptions
                  .map((status) => DropdownMenuItem(value: status, child: Text(status)))
                  .toList(),
              onChanged: (value) => setState(() => _selectedStatus = value ?? 'Upcoming'),
            ),
            const SizedBox(height: 16),

            InkWell(
              onTap: () => _pickDate(isStart: true),
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: _inputDecoration(context, 'Start Date', icon: Icons.calendar_today_outlined),
                child: Text(
                  _formatDate(_startDate),
                  style: TextStyle(
                    color: _startDate == null ? _kTextSecondary(context) : _kTextPrimary(context),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            InkWell(
              onTap: () => _pickDate(isStart: false),
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: _inputDecoration(context, 'End Date', icon: Icons.calendar_today_outlined),
                child: Text(
                  _formatDate(_endDate),
                  style: TextStyle(
                    color: _endDate == null ? _kTextSecondary(context) : _kTextPrimary(context),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _sessionDurationController,
              style: TextStyle(color: _kTextPrimary(context)),
              decoration: _inputDecoration(context, 'Session Duration', icon: Icons.timelapse_outlined)
                  .copyWith(hintText: 'e.g. 2 hours'),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _maxCapacityController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: _kTextPrimary(context)),
              decoration: _inputDecoration(context, 'Max Capacity', icon: Icons.groups_outlined),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _targetFlyingHoursController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: _kTextPrimary(context)),
              decoration: _inputDecoration(context, 'Target Flying Hours', icon: Icons.flight_takeoff_outlined),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _targetSimulatorHoursController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: _kTextPrimary(context)),
              decoration: _inputDecoration(context, 'Target Simulator Hours', icon: Icons.sports_esports_outlined),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _feeAmountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: _kTextPrimary(context)),
              decoration: _inputDecoration(context, 'Fee Amount (INR)', icon: Icons.currency_rupee_outlined),
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                Icon(Icons.groups_2_outlined, color: _kTeal(context), size: 18),
                const SizedBox(width: 6),
                Text(
                  'Student Names',
                  style: TextStyle(
                    color: _kTextPrimary(context),
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                Text(
                  '${names.length} detected',
                  style: TextStyle(
                    color: names.isEmpty ? _kTextSecondary(context) : _kTeal(context),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _studentNamesController,
              maxLines: 10,
              minLines: 6,
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: _kTextPrimary(context)),
              decoration: _inputDecoration(context, 'Paste one name per line').copyWith(
                hintText: '01. JAGANATHAN\n02. PRASANNA SALLA\n03. KAREEM KHADER HAYATHBASHA\n...',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tip: leading numbers like "01. " or "1) " are stripped automatically, '
                  'so you can paste folder names straight from Drive.',
              style: TextStyle(color: _kTextSecondary(context), fontSize: 11.5),
            ),
            const SizedBox(height: 32),

            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveBatchWithStudents,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kTeal(context),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                )
                    : Text(
                  names.isEmpty
                      ? 'Save Batch'
                      : 'Save Batch + ${names.length} Student${names.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}