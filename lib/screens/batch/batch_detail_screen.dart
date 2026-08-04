import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/student_model.dart';
import '../student/student_detail_screen.dart';
import '../student/student_add_screen.dart';
import 'general_category/attendance_screen.dart';
import 'general_category/counseling_screen.dart';
import 'general_category/logbook_screen.dart';

class BatchDetailScreen extends StatefulWidget {
  final String batchId;

  const BatchDetailScreen({super.key, required this.batchId});

  @override
  State<BatchDetailScreen> createState() => _BatchDetailScreenState();
}

class _BatchDetailScreenState extends State<BatchDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  bool _isEditing = false;
  bool _isSaving = false;
  bool _isDeleting = false;

  late TextEditingController _batchNameController;
  late TextEditingController _studentCountController;
  late TextEditingController _locationController;
  late TextEditingController _scheduleDaysController;
  late TextEditingController _sessionDurationController;
  late TextEditingController _maxCapacityController;
  late TextEditingController _targetFlyingHoursController;
  late TextEditingController _targetSimulatorHoursController;
  late TextEditingController _feeAmountController;

  String? _selectedInstructor;
  String? _selectedDrone;
  String _selectedStatus = 'Upcoming';
  String _selectedCategory = 'RPTO';
  DateTime? _startDate;
  DateTime? _endDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  final List<String> _categoryOptions = ['RPTO', 'FPV', 'Aerial'];

  bool _initialized = false;

  String _studentSearchQuery = '';
  String _studentStatusFilter = 'All';
  final List<String> _studentStatusFilters = ['All', 'Active', 'Completed', 'Dropped'];

  final List<String> _statusOptions = ['Upcoming', 'Ongoing', 'Completed'];

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
  Color _kAmber(BuildContext c) =>
      _isDark(c) ? const Color(0xFFFFB020) : const Color(0xFFB77400);
  Color _kGreen(BuildContext c) =>
      _isDark(c) ? const Color(0xFF3FCE8E) : const Color(0xFF1F9D63);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _batchNameController = TextEditingController();
    _studentCountController = TextEditingController();
    _locationController = TextEditingController();
    _scheduleDaysController = TextEditingController();
    _sessionDurationController = TextEditingController();
    _maxCapacityController = TextEditingController();
    _targetFlyingHoursController = TextEditingController();
    _targetSimulatorHoursController = TextEditingController();
    _feeAmountController = TextEditingController();
  }

  @override
  void dispose() {
    _tabController.dispose();
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

  void _populateFields(Map<String, dynamic> data) {
    if (_initialized) return;
    _batchNameController.text = data['batchName'] ?? '';
    _studentCountController.text = (data['studentCount'] ?? '').toString();
    _selectedInstructor = data['instructor'];
    _selectedDrone = data['drone'];
    _selectedStatus = data['status'] ?? 'Upcoming';
    _startDate = data['startDate'] != null
        ? (data['startDate'] as Timestamp).toDate()
        : null;
    _endDate = data['endDate'] != null
        ? (data['endDate'] as Timestamp).toDate()
        : null;
    _selectedCategory = (data['category'] ?? 'RPTO').toString();
    _locationController.text = data['location'] ?? '';
    _scheduleDaysController.text = data['scheduleDays'] ?? '';
    _sessionDurationController.text = data['sessionDuration'] ?? '';
    _maxCapacityController.text = (data['maxCapacity'] ?? '').toString();
    _targetFlyingHoursController.text = (data['targetFlyingHours'] ?? '').toString();
    _targetSimulatorHoursController.text = (data['targetSimulatorHours'] ?? '').toString();
    _feeAmountController.text = (data['feeAmount'] ?? '').toString();
    _startTime = _parseTime(data['startTime']);
    _endTime = _parseTime(data['endTime']);
    _initialized = true;
  }

  TimeOfDay? _parseTime(dynamic value) {
    if (value == null || value.toString().isEmpty) return null;
    final parts = value.toString().split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) return '—';
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String _timeToStorageString(TimeOfDay? time) {
    if (time == null) return '';
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
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

  Color _statusColor(BuildContext context, String status) {
    switch (status.toLowerCase()) {
      case 'ongoing':
        return _kTeal(context);
      case 'completed':
        return _kGreen(context);
      case 'upcoming':
        return _kAmber(context);
      case 'archived':
        return _kTextSecondary(context);
      default:
        return _kTextSecondary(context);
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
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = null;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _saveChanges() async {
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
      await FirebaseFirestore.instance
          .collection('batches')
          .doc(widget.batchId)
          .update({
        'batchName': _batchNameController.text.trim(),
        'instructor': _selectedInstructor,
        'drone': _selectedDrone,
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
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() => _isEditing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Batch updated successfully'),
            backgroundColor: _kTeal(context),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating batch: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _kSurface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Delete Batch', style: TextStyle(color: _kTextPrimary(context))),
        content: Text(
          'Are you sure you want to delete this batch? This action cannot be undone.',
          style: TextStyle(color: _kTextSecondary(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: _kTextSecondary(context))),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isDeleting = true);
      try {
        await FirebaseFirestore.instance
            .collection('batches')
            .doc(widget.batchId)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Batch deleted'),
              backgroundColor: _kTeal(context),
            ),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting batch: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        if (mounted) setState(() => _isDeleting = false);
      }
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
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _kBorder(context)),
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
          'Batch Details',
          style: TextStyle(color: _kTextPrimary(context), fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: Icon(Icons.edit_outlined, color: _kTeal(context)),
              onPressed: () => setState(() => _isEditing = true),
            ),
          IconButton(
            icon: _isDeleting
                ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent),
            )
                : const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: _isDeleting ? null : _confirmDelete,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: _kTeal(context),
          unselectedLabelColor: _kTextSecondary(context),
          indicatorColor: _kTeal(context),
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.info_outline)),
            Tab(text: 'Students', icon: Icon(Icons.people_outline)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(context),
          _buildStudentsTab(context),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (context, _) {
          if (_tabController.index != 1) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            backgroundColor: _kTeal(context),
            icon: Icon(Icons.person_add_alt_1, color: _kNavy(context)),
            label: Text('Add Student', style: TextStyle(color: _kNavy(context), fontWeight: FontWeight.w700)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StudentAddScreen(
                    preselectedBatchId: widget.batchId,
                    preselectedBatchName: _batchNameController.text,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildOverviewTab(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('batches')
          .doc(widget.batchId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading batch: ${snapshot.error}',
              style: const TextStyle(color: Colors.redAccent),
            ),
          );
        }

        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator(color: _kTeal(context)));
        }

        if (!snapshot.data!.exists) {
          return Center(
            child: Text('Batch not found', style: TextStyle(color: _kTextSecondary(context))),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        _populateFields(data);

        return Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _statusColor(context, _selectedStatus).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 8, color: _statusColor(context, _selectedStatus)),
                    const SizedBox(width: 6),
                    Text(
                      _selectedStatus,
                      style: TextStyle(
                        color: _statusColor(context, _selectedStatus),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ---- Stat cards: live counts pulled from the students
              // collection for this batch (no fake numbers). ----
              FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance
                    .collection('students')
                    .where('batchId', isEqualTo: widget.batchId)
                    .get(),
                builder: (context, studentsSnap) {
                  final studentDocs = studentsSnap.data?.docs ?? [];
                  final total = studentDocs.length;
                  final active = studentDocs.where((d) {
                    final sd = d.data() as Map<String, dynamic>;
                    return (sd['status'] ?? '') == 'Active';
                  }).length;

                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: _kSurface(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _kBorder(context)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _statCard(context, 'Students', total, Icons.people_outline),
                        _statCard(context, 'Active', active, Icons.check_circle_outline),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _exportBatchReport(context, data),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _kTeal(context),
                        side: BorderSide(color: _kTeal(context).withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.download_outlined, size: 18),
                      label: const Text('Export Report'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _toggleArchive(context, _selectedStatus),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _kAmber(context),
                        side: BorderSide(color: _kAmber(context).withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: Icon(
                        _selectedStatus == 'Archived' ? Icons.unarchive_outlined : Icons.archive_outlined,
                        size: 18,
                      ),
                      label: Text(_selectedStatus == 'Archived' ? 'Unarchive Batch' : 'Archive Batch'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Text(
                'QUICK ACTIONS',
                style: TextStyle(
                  color: _kTextSecondary(context),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _quickActionButton(
                      context,
                      icon: Icons.event_available_outlined,
                      label: 'Attendance',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AttendanceScreen(
                            batchId: widget.batchId,
                            batchName: data['batchName'] ?? 'Batch',
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _quickActionButton(
                      context,
                      icon: Icons.menu_book_outlined,
                      label: 'Logbook',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LogbookScreen(
                            batchId: widget.batchId,
                            batchName: data['batchName'] ?? 'Batch',
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _quickActionButton(
                      context,
                      icon: Icons.psychology_outlined,
                      label: 'Counseling',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CounselingScreen(
                            batchId: widget.batchId,
                            batchName: data['batchName'] ?? 'Batch',
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              TextFormField(
                controller: _batchNameController,
                enabled: _isEditing,
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

              _isEditing
                  ? DropdownButtonFormField<String>(
                initialValue: _categoryOptions.contains(_selectedCategory)
                    ? _selectedCategory
                    : _categoryOptions.first,
                dropdownColor: _kSurface(context),
                style: TextStyle(color: _kTextPrimary(context)),
                decoration: _inputDecoration(context, 'Category', icon: Icons.category_outlined),
                items: _categoryOptions
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedCategory = v ?? 'RPTO'),
              )
                  : TextFormField(
                enabled: false,
                style: TextStyle(color: _kTextPrimary(context)),
                controller: TextEditingController(text: _selectedCategory),
                decoration: _inputDecoration(context, 'Category', icon: Icons.category_outlined),
              ),
              const SizedBox(height: 16),

              _isEditing
                  ? StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('instructors')
                    .orderBy('name')
                    .snapshots(),
                builder: (context, snap) {
                  final names = <String>[];
                  if (snap.hasData) {
                    for (final doc in snap.data!.docs) {
                      final d = doc.data() as Map<String, dynamic>;
                      if (d['name'] != null) names.add(d['name'].toString());
                    }
                  }
                  if (_selectedInstructor != null &&
                      !names.contains(_selectedInstructor)) {
                    names.add(_selectedInstructor!);
                  }
                  return DropdownButtonFormField<String>(
                    initialValue: _selectedInstructor,
                    dropdownColor: _kSurface(context),
                    style: TextStyle(color: _kTextPrimary(context)),
                    decoration:
                    _inputDecoration(context, 'Instructor', icon: Icons.person_outline),
                    items: names
                        .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedInstructor = v),
                    validator: (v) => v == null ? 'Please select an instructor' : null,
                  );
                },
              )
                  : TextFormField(
                enabled: false,
                style: TextStyle(color: _kTextPrimary(context)),
                decoration: _inputDecoration(context, 'Instructor', icon: Icons.person_outline)
                    .copyWith(hintText: _selectedInstructor),
                controller: TextEditingController(text: _selectedInstructor ?? '-'),
              ),
              const SizedBox(height: 16),

              _isEditing
                  ? StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('drones')
                    .orderBy('name')
                    .snapshots(),
                builder: (context, snap) {
                  final names = <String>[];
                  if (snap.hasData) {
                    for (final doc in snap.data!.docs) {
                      final d = doc.data() as Map<String, dynamic>;
                      if (d['name'] != null) names.add(d['name'].toString());
                    }
                  }
                  if (_selectedDrone != null && !names.contains(_selectedDrone)) {
                    names.add(_selectedDrone!);
                  }
                  return DropdownButtonFormField<String>(
                    initialValue: _selectedDrone,
                    dropdownColor: _kSurface(context),
                    style: TextStyle(color: _kTextPrimary(context)),
                    decoration: _inputDecoration(context, 'Drone', icon: Icons.flight_outlined),
                    items: names
                        .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedDrone = v),
                    validator: (v) => v == null ? 'Please select a drone' : null,
                  );
                },
              )
                  : TextFormField(
                enabled: false,
                style: TextStyle(color: _kTextPrimary(context)),
                controller: TextEditingController(text: _selectedDrone ?? '-'),
                decoration: _inputDecoration(context, 'Drone', icon: Icons.flight_outlined),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _locationController,
                enabled: _isEditing,
                style: TextStyle(color: _kTextPrimary(context)),
                decoration: _inputDecoration(context, 'Location', icon: Icons.location_on_outlined),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _scheduleDaysController,
                enabled: _isEditing,
                style: TextStyle(color: _kTextPrimary(context)),
                decoration: _inputDecoration(context, 'Schedule Days', icon: Icons.event_repeat_outlined)
                    .copyWith(hintText: 'e.g. Mon, Wed, Fri'),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _studentCountController,
                enabled: _isEditing,
                keyboardType: TextInputType.number,
                style: TextStyle(color: _kTextPrimary(context)),
                decoration:
                _inputDecoration(context, 'Number of Students', icon: Icons.groups_2_outlined),
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

              _isEditing
                  ? DropdownButtonFormField<String>(
                initialValue: _selectedStatus,
                dropdownColor: _kSurface(context),
                style: TextStyle(color: _kTextPrimary(context)),
                decoration: _inputDecoration(context, 'Status', icon: Icons.flag_outlined),
                items: _statusOptions
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedStatus = v ?? 'Upcoming'),
              )
                  : const SizedBox.shrink(),
              if (_isEditing) const SizedBox(height: 16),

              InkWell(
                onTap: _isEditing ? () => _pickDate(isStart: true) : null,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: _inputDecoration(context, 'Start Date', icon: Icons.calendar_today_outlined),
                  child: Text(
                    _formatDate(_startDate),
                    style: TextStyle(
                      color: _isEditing ? _kTextPrimary(context) : _kTextSecondary(context),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              InkWell(
                onTap: _isEditing ? () => _pickDate(isStart: false) : null,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: _inputDecoration(context, 'End Date', icon: Icons.calendar_today_outlined),
                  child: Text(
                    _formatDate(_endDate),
                    style: TextStyle(
                      color: _isEditing ? _kTextPrimary(context) : _kTextSecondary(context),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _isEditing ? () => _pickTime(isStart: true) : null,
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: _inputDecoration(context, 'Start Time', icon: Icons.access_time_outlined),
                        child: Text(
                          _formatTime(_startTime),
                          style: TextStyle(
                            color: _isEditing ? _kTextPrimary(context) : _kTextSecondary(context),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: _isEditing ? () => _pickTime(isStart: false) : null,
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: _inputDecoration(context, 'End Time', icon: Icons.access_time_outlined),
                        child: Text(
                          _formatTime(_endTime),
                          style: TextStyle(
                            color: _isEditing ? _kTextPrimary(context) : _kTextSecondary(context),
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
                enabled: _isEditing,
                style: TextStyle(color: _kTextPrimary(context)),
                decoration: _inputDecoration(context, 'Session Duration', icon: Icons.timelapse_outlined)
                    .copyWith(hintText: 'e.g. 2 hours'),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _maxCapacityController,
                enabled: _isEditing,
                keyboardType: TextInputType.number,
                style: TextStyle(color: _kTextPrimary(context)),
                decoration: _inputDecoration(context, 'Max Capacity', icon: Icons.groups_outlined),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _targetFlyingHoursController,
                enabled: _isEditing,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: _kTextPrimary(context)),
                decoration: _inputDecoration(context, 'Target Flying Hours', icon: Icons.flight_takeoff_outlined),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _targetSimulatorHoursController,
                enabled: _isEditing,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: _kTextPrimary(context)),
                decoration: _inputDecoration(context, 'Target Simulator Hours', icon: Icons.sports_esports_outlined),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _feeAmountController,
                enabled: _isEditing,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: _kTextPrimary(context)),
                decoration: _inputDecoration(context, 'Fee Amount (INR)', icon: Icons.currency_rupee_outlined),
              ),
              const SizedBox(height: 32),

              if (_isEditing)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSaving
                            ? null
                            : () {
                          setState(() {
                            _isEditing = false;
                            _initialized = false;
                            _populateFields(data);
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: _kBorder(context)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text('Cancel',
                            style: TextStyle(color: _kTextSecondary(context))),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveChanges,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kTeal(context),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                            : const Text(
                          'Save Changes',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStudentsTab(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: TextField(
            style: TextStyle(color: _kTextPrimary(context)),
            onChanged: (val) => setState(() => _studentSearchQuery = val.toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Search students...',
              hintStyle: TextStyle(color: _kTextSecondary(context)),
              prefixIcon: Icon(Icons.search, color: _kTeal(context)),
              filled: true,
              fillColor: _kSurface(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: _kBorder(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: _kBorder(context)),
              ),
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _studentStatusFilters.length,
            itemBuilder: (context, index) {
              final filter = _studentStatusFilters[index];
              final isSelected = _studentStatusFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(filter),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _studentStatusFilter = filter),
                  selectedColor: _kTeal(context),
                  backgroundColor: _kSurface(context),
                  labelStyle: TextStyle(
                    color: isSelected ? _kNavy(context) : _kTextSecondary(context),
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: isSelected ? _kTeal(context) : _kBorder(context)),
                  ),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('students')
                .where('batchId', isEqualTo: widget.batchId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error loading students: ${snapshot.error}',
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return Center(child: CircularProgressIndicator(color: _kTeal(context)));
              }
              final allDocs = snapshot.data!.docs;
              final allStudents = allDocs.map((d) => StudentModel.fromDocument(d)).toList();
              final students = allStudents.where((s) {
                final matchesSearch = _studentSearchQuery.isEmpty ||
                    s.name.toLowerCase().contains(_studentSearchQuery);
                final matchesFilter =
                    _studentStatusFilter == 'All' || s.status == _studentStatusFilter;
                return matchesSearch && matchesFilter;
              }).toList();

              if (students.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people_outline, color: _kTextSecondary(context), size: 48),
                      const SizedBox(height: 12),
                      Text(
                        allStudents.isEmpty ? 'No students assigned to this batch' : 'No matching students',
                        style: TextStyle(color: _kTextSecondary(context)),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                itemCount: students.length,
                itemBuilder: (context, index) {
                  final student = students[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: _kSurface(context),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _kBorder(context)),
                    ),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      leading: CircleAvatar(
                        backgroundColor: _kTeal(context).withValues(alpha: 0.15),
                        child: Text(
                          student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
                          style: TextStyle(color: _kTeal(context), fontWeight: FontWeight.w700),
                        ),
                      ),
                      title: Text(student.name, style: TextStyle(color: _kTextPrimary(context), fontWeight: FontWeight.w600)),
                      subtitle: Text(student.status, style: TextStyle(color: _kTextSecondary(context))),
                      trailing: Icon(Icons.chevron_right, color: _kTextSecondary(context)),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => StudentDetailScreen(student: student)),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
  Widget _statCard(BuildContext context, String label, int value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: _kTeal(context), size: 24),
        const SizedBox(height: 6),
        Text(
          value.toString(),
          style: TextStyle(color: _kTextPrimary(context), fontSize: 20, fontWeight: FontWeight.w700),
        ),
        Text(label, style: TextStyle(color: _kTextSecondary(context), fontSize: 11)),
      ],
    );
  }

  /// Builds a CSV of the batch info + its students and shows it in a
  /// copy-to-clipboard dialog (no extra packages needed for a full
  /// file download — this keeps the report accessible without adding
  /// a dependency this project doesn't already have).
  Future<void> _exportBatchReport(BuildContext context, Map<String, dynamic> data) async {
    final studentsSnap = await FirebaseFirestore.instance
        .collection('students')
        .where('batchId', isEqualTo: widget.batchId)
        .get();
    final students = studentsSnap.docs.map((d) => StudentModel.fromDocument(d)).toList();

    final buffer = StringBuffer();
    buffer.writeln('Batch Report: ${data['batchName'] ?? ''}');
    buffer.writeln('Instructor: ${data['instructor'] ?? '-'}');
    buffer.writeln('Status: ${data['status'] ?? '-'}');
    buffer.writeln('Total Students: ${students.length}');
    buffer.writeln();
    buffer.writeln('Name,Status,Phone');
    for (final s in students) {
      buffer.writeln('${s.name},${s.status},${s.phone}');
    }

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _kSurface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Batch Report', style: TextStyle(color: _kTextPrimary(context))),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              buffer.toString(),
              style: TextStyle(color: _kTextSecondary(context), fontFamily: 'monospace', fontSize: 12.5),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Close', style: TextStyle(color: _kTextSecondary(context))),
          ),
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: buffer.toString()));
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: const Text('Report copied to clipboard'), backgroundColor: _kTeal(context)),
              );
            },
            child: Text('Copy', style: TextStyle(color: _kTeal(context))),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleArchive(BuildContext context, String currentStatus) async {
    final isArchived = currentStatus == 'Archived';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _kSurface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isArchived ? 'Unarchive this batch?' : 'Archive this batch?',
          style: TextStyle(color: _kTextPrimary(context)),
        ),
        content: Text(
          isArchived
              ? 'This will restore the batch to its previous status and allow edits again.'
              : 'Archived batches become read-only in status but you can still view students and attendance.',
          style: TextStyle(color: _kTextSecondary(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancel', style: TextStyle(color: _kTextSecondary(context))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              isArchived ? 'Unarchive' : 'Archive',
              style: TextStyle(color: _kAmber(context)),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      if (isArchived) {
        final doc = await FirebaseFirestore.instance.collection('batches').doc(widget.batchId).get();
        final previous = (doc.data() as Map<String, dynamic>?)?['previousStatus'] ?? 'Upcoming';
        await FirebaseFirestore.instance.collection('batches').doc(widget.batchId).update({
          'status': previous,
          'previousStatus': FieldValue.delete(),
        });
      } else {
        await FirebaseFirestore.instance.collection('batches').doc(widget.batchId).update({
          'previousStatus': currentStatus,
          'status': 'Archived',
        });
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isArchived ? 'Batch restored to active' : 'Batch archived'),
            backgroundColor: _kTeal(context),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Widget _quickActionButton(
      BuildContext context, {
        required IconData icon,
        required String label,
        required VoidCallback onTap,
      }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: _kSurface(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kBorder(context)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _kTeal(context), size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: _kTextPrimary(context),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}