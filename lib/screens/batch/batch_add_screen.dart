import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AddBatchScreen extends StatefulWidget {
  const AddBatchScreen({super.key});

  @override
  State<AddBatchScreen> createState() => _AddBatchScreenState();
}

class _AddBatchScreenState extends State<AddBatchScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _batchNameController = TextEditingController();
  final TextEditingController _studentCountController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _scheduleDaysController = TextEditingController();
  final TextEditingController _sessionDurationController = TextEditingController();
  final TextEditingController _maxCapacityController = TextEditingController();
  final TextEditingController _targetFlyingHoursController = TextEditingController();
  final TextEditingController _targetSimulatorHoursController = TextEditingController();
  final TextEditingController _feeAmountController = TextEditingController();

  String _selectedStatus = 'Upcoming';
  String _selectedCategory = 'RPC';
  DateTime? _startDate;
  DateTime? _endDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  bool _isSaving = false;

  final List<String> _statusOptions = ['Upcoming', 'Ongoing', 'Completed'];
  final List<String> _categoryOptions = ['RPC'];

  // ---- Theme-aware colors: flip between dark/light based on current
  // Theme brightness instead of hardcoded dark-only constants. ----
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
    _studentCountController.dispose();
    _locationController.dispose();
    _scheduleDaysController.dispose();
    _sessionDurationController.dispose();
    _maxCapacityController.dispose();
    _targetFlyingHoursController.dispose();
    _targetSimulatorHoursController.dispose();
    _feeAmountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? (_startDate ?? now)
          : (_endDate ?? _startDate ?? now),
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
            dialogBackgroundColor: _kNavy(context),
          )
              : ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: _kTeal(context),
              surface: _kSurface(context),
              onSurface: _kTextPrimary(context),
            ),
            dialogBackgroundColor: _kNavy(context),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          // reset end date if it's before new start date
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = null;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: (isStart ? _startTime : _endTime) ?? TimeOfDay.now(),
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
          _startTime = picked;
        } else {
          _endTime = picked;
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

  String _formatTime(TimeOfDay? time) {
    if (time == null) return 'Select time';
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String _timeToStorageString(TimeOfDay? time) {
    if (time == null) return '';
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _saveBatch() async {
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

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance.collection('batches').add({
        'batchName': _batchNameController.text.trim(),
        'studentCount': int.tryParse(_studentCountController.text.trim()) ?? 0,
        'status': _selectedStatus,
        'category': _selectedCategory,
        'location': _locationController.text.trim(),
        'scheduleDays': _scheduleDaysController.text.trim(),
        'startDate': Timestamp.fromDate(_startDate!),
        'endDate': Timestamp.fromDate(_endDate!),
        'startTime': _timeToStorageString(_startTime),
        'endTime': _timeToStorageString(_endTime),
        'sessionDuration': _sessionDurationController.text.trim(),
        'maxCapacity': int.tryParse(_maxCapacityController.text.trim()) ?? 0,
        'targetFlyingHours': num.tryParse(_targetFlyingHoursController.text.trim()) ?? 0,
        'targetSimulatorHours': num.tryParse(_targetSimulatorHoursController.text.trim()) ?? 0,
        'feeAmount': num.tryParse(_feeAmountController.text.trim()) ?? 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Batch created successfully'),
            backgroundColor: _kTeal(context),
          ),
        );
        Navigator.of(context).pop();
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

  @override
  Widget build(BuildContext context) {
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
          'Add Batch',
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
                  .map((category) => DropdownMenuItem(
                value: category,
                child: Text(category),
              ))
                  .toList(),
              onChanged: (value) {
                setState(() => _selectedCategory = value ?? 'RPC');
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

            TextFormField(
              controller: _studentCountController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: _kTextPrimary(context)),
              decoration: _inputDecoration(context, 'Number of Students', icon: Icons.groups_2_outlined),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Student count is required';
                }
                if (int.tryParse(value.trim()) == null) {
                  return 'Enter a valid number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              initialValue: _selectedStatus,
              dropdownColor: _kSurface(context),
              style: TextStyle(color: _kTextPrimary(context)),
              decoration: _inputDecoration(context, 'Status', icon: Icons.flag_outlined),
              items: _statusOptions
                  .map((status) => DropdownMenuItem(
                value: status,
                child: Text(status),
              ))
                  .toList(),
              onChanged: (value) {
                setState(() => _selectedStatus = value ?? 'Upcoming');
              },
            ),
            const SizedBox(height: 16),

            // Start Date
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

            // End Date
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

            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _pickTime(isStart: true),
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: _inputDecoration(context, 'Start Time', icon: Icons.access_time_outlined),
                      child: Text(
                        _formatTime(_startTime),
                        style: TextStyle(
                          color: _startTime == null ? _kTextSecondary(context) : _kTextPrimary(context),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => _pickTime(isStart: false),
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: _inputDecoration(context, 'End Time', icon: Icons.access_time_outlined),
                      child: Text(
                        _formatTime(_endTime),
                        style: TextStyle(
                          color: _endTime == null ? _kTextSecondary(context) : _kTextPrimary(context),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
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
            const SizedBox(height: 32),

            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveBatch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kTeal(context),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
                    : const Text(
                  'Save Batch',
                  style: TextStyle(
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