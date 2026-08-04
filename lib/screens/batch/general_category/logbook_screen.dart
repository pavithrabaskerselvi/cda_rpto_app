import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../models/student_model.dart';
import '../../../models/drone_model.dart';

class LogbookScreen extends StatefulWidget {
  final String batchId;
  final String batchName;

  const LogbookScreen({
    super.key,
    required this.batchId,
    required this.batchName,
  });

  @override
  State<LogbookScreen> createState() => _LogbookScreenState();
}

class _LogbookScreenState extends State<LogbookScreen> {
  bool _isLoading = true;
  List<StudentModel> _students = [];

  // ---- Theme-aware colors: flip between dark/light based on current
  // Theme brightness instead of hardcoded dark-only constants. ----
  bool _isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

  Color _kNavy(BuildContext c) =>
      _isDark(c) ? const Color(0xFF050A14) : const Color(0xFFF7F8FA);
  Color _kSurface(BuildContext c) =>
      _isDark(c) ? const Color(0xFF0F1B2E) : const Color(0xFFFFFFFF);
  Color _kTeal(BuildContext c) =>
      _isDark(c) ? const Color(0xFF14B8A6) : const Color(0xFF0D9488);
  Color _kCoral(BuildContext c) =>
      _isDark(c) ? const Color(0xFFFF6B6B) : const Color(0xFFD64545);
  Color _kAmber(BuildContext c) =>
      _isDark(c) ? const Color(0xFFF59E0B) : const Color(0xFFB77400);
  Color _kTextPrimary(BuildContext c) =>
      _isDark(c) ? Colors.white : const Color(0xFF0B1220);
  Color _kTextMuted(BuildContext c) =>
      _isDark(c) ? Colors.white54 : const Color(0xFF7B8494);
  Color _kTextFaint(BuildContext c) =>
      _isDark(c) ? Colors.white38 : const Color(0xFF9AA3B2);
  Color _kBorder(BuildContext c) =>
      _isDark(c) ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE2E5EA);

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('students')
          .where('batchId', isEqualTo: widget.batchId)
          .get();
      setState(() {
        _students = snap.docs.map((d) => StudentModel.fromDocument(d)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load: $e'), backgroundColor: _kCoral(context)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kNavy(context),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: _kNavy(context),
            pinned: true,
            expandedHeight: 130,
            iconTheme: IconThemeData(color: _kTextPrimary(context)),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
              title: Text(
                '${widget.batchName} - Flight Logbook',
                style: TextStyle(color: _kTextPrimary(context), fontSize: 15, fontWeight: FontWeight.w600),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_kAmber(context).withValues(alpha: 0.25), _kNavy(context)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ),
          if (_isLoading)
            SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: _kTeal(context))),
            )
          else if (_students.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Text('No students found in this batch', style: TextStyle(color: _kTextMuted(context))),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildStudentTile(_students[index]),
                childCount: _students.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }

  Widget _buildStudentTile(StudentModel student) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StudentLogbookScreen(student: student),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _kSurface(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorder(context)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: _kAmber(context).withValues(alpha: 0.2),
              child: Text(
                student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
                style: TextStyle(color: _kAmber(context), fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(student.name,
                      style: TextStyle(color: _kTextPrimary(context), fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(student.phone, style: TextStyle(color: _kTextMuted(context), fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: _kTextFaint(context)),
          ],
        ),
      ),
    );
  }
}

// ---------------- Student Logbook Entries ----------------

class StudentLogbookScreen extends StatefulWidget {
  final StudentModel student;

  const StudentLogbookScreen({super.key, required this.student});

  @override
  State<StudentLogbookScreen> createState() => _StudentLogbookScreenState();
}

class _StudentLogbookScreenState extends State<StudentLogbookScreen> {
  bool _isSaving = false;
  List<DroneModel> _drones = [];

  // ---- Theme-aware colors: flip between dark/light based on current
  // Theme brightness instead of hardcoded dark-only constants. ----
  bool _isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

  Color _kNavy(BuildContext c) =>
      _isDark(c) ? const Color(0xFF050A14) : const Color(0xFFF7F8FA);
  Color _kSurface(BuildContext c) =>
      _isDark(c) ? const Color(0xFF0F1B2E) : const Color(0xFFFFFFFF);
  Color _kTeal(BuildContext c) =>
      _isDark(c) ? const Color(0xFF14B8A6) : const Color(0xFF0D9488);
  Color _kCoral(BuildContext c) =>
      _isDark(c) ? const Color(0xFFFF6B6B) : const Color(0xFFD64545);
  Color _kAmber(BuildContext c) =>
      _isDark(c) ? const Color(0xFFF59E0B) : const Color(0xFFB77400);
  Color _kGreen(BuildContext c) =>
      _isDark(c) ? const Color(0xFF22C55E) : const Color(0xFF1F9D5A);
  Color _kPurple(BuildContext c) =>
      _isDark(c) ? const Color(0xFF8B5CF6) : const Color(0xFF7C3AED);
  Color _kTextPrimary(BuildContext c) =>
      _isDark(c) ? Colors.white : const Color(0xFF0B1220);
  Color _kTextSecondary(BuildContext c) =>
      _isDark(c) ? Colors.white70 : const Color(0xFF5B6472);
  Color _kTextMuted(BuildContext c) =>
      _isDark(c) ? Colors.white54 : const Color(0xFF7B8494);
  Color _kBorder(BuildContext c) =>
      _isDark(c) ? Colors.white24 : const Color(0xFFD8DBE2);
  Color _kBorderSoft(BuildContext c) =>
      _isDark(c) ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE2E5EA);

  @override
  void initState() {
    super.initState();
    _loadDrones();
  }

  Future<void> _loadDrones() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('drones').get();
      setState(() {
        _drones = snap.docs.map((d) => DroneModel.fromDocument(d)).toList();
      });
    } catch (_) {}
  }

  Stream<QuerySnapshot> _logEntriesStream() {
    return FirebaseFirestore.instance
        .collection('logbook_entries')
        .where('studentId', isEqualTo: widget.student.id)
        .orderBy('flightDate', descending: true)
        .snapshots();
  }

  Future<void> _addEntryDialog() async {
    DateTime flightDate = DateTime.now();
    String? selectedDroneId;
    String? selectedDroneName;
    final sortieController = TextEditingController();
    final durationController = TextEditingController();
    final remarksController = TextEditingController();
    String flightType = 'Solo';

    await showModalBottomSheet(
      context: context,
      backgroundColor: _kSurface(context),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('New Logbook Entry',
                        style: TextStyle(color: _kTextPrimary(context), fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: flightDate,
                          firstDate: DateTime(2023),
                          lastDate: DateTime.now(),
                          builder: (context, child) => Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: _isDark(context)
                                  ? ColorScheme.dark(primary: _kTeal(context), surface: _kSurface(context))
                                  : ColorScheme.light(primary: _kTeal(context), surface: _kSurface(context)),
                            ),
                            child: child!,
                          ),
                        );
                        if (picked != null) setModalState(() => flightDate = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: _kBorder(context)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, color: _kTextMuted(context), size: 18),
                            const SizedBox(width: 10),
                            Text('${flightDate.day}/${flightDate.month}/${flightDate.year}',
                                style: TextStyle(color: _kTextPrimary(context))),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedDroneId,
                      dropdownColor: _kSurface(context),
                      style: TextStyle(color: _kTextPrimary(context)),
                      decoration: _fieldDecoration(context, 'Select Drone'),
                      items: _drones
                          .map((d) => DropdownMenuItem(
                        value: d.id,
                        child: Text(d.droneName, style: TextStyle(color: _kTextPrimary(context))),
                      ))
                          .toList(),
                      onChanged: (val) {
                        setModalState(() {
                          selectedDroneId = val;
                          selectedDroneName = _drones.firstWhere((d) => d.id == val).droneName;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: flightType,
                      dropdownColor: _kSurface(context),
                      style: TextStyle(color: _kTextPrimary(context)),
                      decoration: _fieldDecoration(context, 'Flight Type'),
                      items: ['Solo', 'Dual', 'Simulator']
                          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (val) => setModalState(() => flightType = val ?? 'Solo'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: sortieController,
                      style: TextStyle(color: _kTextPrimary(context)),
                      decoration: _fieldDecoration(context, 'Sortie Type (e.g. Take-off/Landing)'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: durationController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: _kTextPrimary(context)),
                      decoration: _fieldDecoration(context, 'Duration (minutes)'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: remarksController,
                      maxLines: 3,
                      style: TextStyle(color: _kTextPrimary(context)),
                      decoration: _fieldDecoration(context, 'Remarks'),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isSaving
                            ? null
                            : () async {
                          if (selectedDroneId == null ||
                              sortieController.text.trim().isEmpty ||
                              durationController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: const Text('Fill all required fields'), backgroundColor: _kCoral(context)),
                            );
                            return;
                          }
                          setState(() => _isSaving = true);
                          try {
                            await FirebaseFirestore.instance.collection('logbook_entries').add({
                              'studentId': widget.student.id,
                              'studentName': widget.student.name,
                              'batchId': widget.student.batchId,
                              'droneId': selectedDroneId,
                              'droneName': selectedDroneName,
                              'flightDate': Timestamp.fromDate(flightDate),
                              'flightType': flightType,
                              'sortieType': sortieController.text.trim(),
                              'durationMinutes': int.tryParse(durationController.text.trim()) ?? 0,
                              'remarks': remarksController.text.trim(),
                              'createdAt': FieldValue.serverTimestamp(),
                            });
                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: const Text('Logbook entry saved'), backgroundColor: _kGreen(context)),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e'), backgroundColor: _kCoral(context)),
                              );
                            }
                          } finally {
                            setState(() => _isSaving = false);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kTeal(context),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                            : const Text('Save Entry',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  InputDecoration _fieldDecoration(BuildContext context, String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: _kTextMuted(context)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: _kBorder(context)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: _kTeal(context)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kNavy(context),
      appBar: AppBar(
        backgroundColor: _kNavy(context),
        title: Text(widget.student.name, style: TextStyle(color: _kTextPrimary(context))),
        iconTheme: IconThemeData(color: _kTextPrimary(context)),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _kTeal(context),
        onPressed: _addEntryDialog,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _logEntriesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: _kTeal(context)));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text('No logbook entries yet', style: TextStyle(color: _kTextMuted(context))),
            );
          }
          final docs = snapshot.data!.docs;

          final totalMinutes = docs.fold<int>(0, (sum, doc) {
            final data = doc.data() as Map<String, dynamic>;
            return sum + ((data['durationMinutes'] ?? 0) as int);
          });

          return Column(
            children: [
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _kSurface(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _kAmber(context).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.timer, color: _kAmber(context)),
                    const SizedBox(width: 10),
                    Text(
                      'Total Flight Time: ${totalMinutes ~/ 60}h ${totalMinutes % 60}m',
                      style: TextStyle(color: _kTextPrimary(context), fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Text('${docs.length} entries', style: TextStyle(color: _kTextMuted(context), fontSize: 12)),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final date = (data['flightDate'] as Timestamp).toDate();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _kSurface(context),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _kBorderSoft(context)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  data['droneName'] ?? '',
                                  style: TextStyle(color: _kTextPrimary(context), fontWeight: FontWeight.w600),
                                ),
                              ),
                              Text('${date.day}/${date.month}/${date.year}',
                                  style: TextStyle(color: _kTextMuted(context), fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            children: [
                              _buildChip(context, data['flightType'] ?? '', _kPurple(context)),
                              _buildChip(context, '${data['durationMinutes'] ?? 0} min', _kTeal(context)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('Sortie: ${data['sortieType'] ?? ''}',
                              style: TextStyle(color: _kTextSecondary(context), fontSize: 13)),
                          if ((data['remarks'] ?? '').toString().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(data['remarks'],
                                style: TextStyle(color: _kTextMuted(context), fontSize: 12)),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildChip(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
