import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../models/drone_model.dart';
import '../../config/theme_colors.dart';
import '../../providers/theme_provider.dart';

class AddDroneScreen extends StatefulWidget {
  final DroneModel? existingDrone; // null => add mode, else edit mode
  const AddDroneScreen({super.key, this.existingDrone});

  @override
  State<AddDroneScreen> createState() => _AddDroneScreenState();
}

class _AddDroneScreenState extends State<AddDroneScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _modelCtrl;
  late TextEditingController _serialCtrl;

  String _type = 'Multirotor';
  String _status = 'Available';
  String? _companyId;
  String? _companyName;
  DateTime? _lastMaintenanceDate;
  bool _saving = false;

  final List<String> _types = ['Fixed Wing', 'Multirotor', 'VTOL'];
  final List<String> _statuses = ['Available', 'In Use', 'Under Maintenance'];

  bool get _isEdit => widget.existingDrone != null;

  @override
  void initState() {
    super.initState();
    final d = widget.existingDrone;
    _nameCtrl = TextEditingController(text: d?.droneName ?? '');
    _modelCtrl = TextEditingController(text: d?.model ?? '');
    _serialCtrl = TextEditingController(text: d?.serialNumber ?? '');
    _type = d?.type.isNotEmpty == true ? d!.type : 'Multirotor';
    _status = d?.status ?? 'Available';
    _companyId = d?.companyId;
    _companyName = d?.companyName;
    _lastMaintenanceDate = d?.lastMaintenanceDate;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _modelCtrl.dispose();
    _serialCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(CompanyColors c) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _lastMaintenanceDate ?? DateTime.now(),
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(primary: c.accent, surface: c.surface),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _lastMaintenanceDate = picked);
  }

  Future<void> _saveDrone() async {
    if (!_formKey.currentState!.validate()) return;
    if (_companyId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Select a company')));
      return;
    }
    setState(() => _saving = true);

    try {
      final docRef = _isEdit
          ? FirebaseFirestore.instance.collection('drones').doc(widget.existingDrone!.id)
          : FirebaseFirestore.instance.collection('drones').doc();

      final drone = DroneModel(
        id: docRef.id,
        droneName: _nameCtrl.text.trim(),
        model: _modelCtrl.text.trim(),
        serialNumber: _serialCtrl.text.trim(),
        type: _type,
        companyId: _companyId!,
        companyName: _companyName ?? '',
        status: _status,
        lastMaintenanceDate: _lastMaintenanceDate,
        createdAt: widget.existingDrone?.createdAt ?? DateTime.now(),
        updatedAt: _isEdit ? DateTime.now() : null,
      );

      await docRef.set(drone.toMap());

      if (mounted) {
        Navigator.pop(context);
        if (_isEdit) Navigator.pop(context); // also close details screen after edit
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error saving drone: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _decoration(String label, CompanyColors c) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: c.textSecondary),
      filled: true,
      fillColor: c.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.borderSubtle.withValues(alpha: 0.24)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.accent),
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
            activeColor: c.accent,
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
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: c.background,
            pinned: true,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: c.textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              _isEdit ? 'Edit Drone' : 'Add Drone',
              style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold),
            ),
            actions: [_buildThemeToggle(isDark, c)],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      style: TextStyle(color: c.textPrimary),
                      decoration: _decoration('Drone Name *', c),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _modelCtrl,
                      style: TextStyle(color: c.textPrimary),
                      decoration: _decoration('Model', c),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _serialCtrl,
                      style: TextStyle(color: c.textPrimary),
                      decoration: _decoration('Serial Number', c),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: _type,
                      dropdownColor: c.surface,
                      style: TextStyle(color: c.textPrimary),
                      decoration: _decoration('Type', c),
                      items:
                      _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (v) => setState(() => _type = v!),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: _status,
                      dropdownColor: c.surface,
                      style: TextStyle(color: c.textPrimary),
                      decoration: _decoration('Status', c),
                      items: _statuses
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) => setState(() => _status = v!),
                    ),
                    const SizedBox(height: 14),
                    StreamBuilder<QuerySnapshot>(
                      stream:
                      FirebaseFirestore.instance.collection('companies').snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return LinearProgressIndicator(color: c.accent);
                        }
                        final companies = snapshot.data!.docs;
                        // Ensure current selection still exists in dropdown items
                        final validIds = companies.map((comp) => comp.id).toSet();
                        final currentValue =
                        (_companyId != null && validIds.contains(_companyId))
                            ? _companyId
                            : null;
                        return DropdownButtonFormField<String>(
                          initialValue: currentValue,
                          dropdownColor: c.surface,
                          style: TextStyle(color: c.textPrimary),
                          decoration: _decoration('Company *', c),
                          items: companies.map((comp) {
                            final data = comp.data() as Map<String, dynamic>;
                            final name = data['companyName'] ?? data['name'] ?? comp.id;
                            return DropdownMenuItem(value: comp.id, child: Text(name));
                          }).toList(),
                          onChanged: (v) {
                            final match = companies.firstWhere((comp) => comp.id == v);
                            final data = match.data() as Map<String, dynamic>;
                            setState(() {
                              _companyId = v;
                              _companyName = data['companyName'] ?? data['name'] ?? '';
                            });
                          },
                          validator: (v) => v == null ? 'Select a company' : null,
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: () => _pickDate(c),
                      child: InputDecorator(
                        decoration: _decoration('Last Maintenance Date', c),
                        child: Text(
                          _lastMaintenanceDate != null
                              ? '${_lastMaintenanceDate!.day}/${_lastMaintenanceDate!.month}/${_lastMaintenanceDate!.year}'
                              : 'Select date',
                          style: TextStyle(color: c.textPrimary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _saving ? null : _saveDrone,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.accent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _saving
                          ? SizedBox(
                        height: 20,
                        width: 20,
                        child:
                        CircularProgressIndicator(color: c.background, strokeWidth: 2),
                      )
                          : Text(
                        _isEdit ? 'Update Drone' : 'Save Drone',
                        style: TextStyle(
                            color: c.background,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
