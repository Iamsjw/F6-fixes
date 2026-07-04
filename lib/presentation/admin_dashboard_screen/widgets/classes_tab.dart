import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import '../../../services/csv_export_service.dart';
import '../../../core/app_export.dart';

class ClassesTab extends StatefulWidget {
  const ClassesTab({super.key});

  @override
  State<ClassesTab> createState() => _ClassesTabState();
}

class _ClassesTabState extends State<ClassesTab> {
  List<ClassModel> _classes = [];
  bool _isLoading = true;

  // Student loading and caching per class
  final Map<String, List<UserModel>> _studentsMap = {};
  final Map<String, bool> _loadingStudentsMap = {};
  final Map<String, bool> _expandedClasses = {};

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    setState(() => _isLoading = true);
    try {
      debugPrint('[UI] ClassesTab._loadClasses() called');
      final classes = await SupabaseService.getClasses();
      debugPrint('[UI] ClassesTab._loadClasses() got ${classes.length} classes');
      if (mounted) {
        setState(() {
          _classes = classes;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('[UI] ClassesTab._loadClasses() failed: $e');
      debugPrint('[UI] Stack trace: $stackTrace');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadStudentsForClass(String classId) async {
    if (mounted) {
      setState(() {
        _loadingStudentsMap[classId] = true;
      });
    }
    try {
      final students = await SupabaseService.getStudentsByClass(classId);
      if (mounted) {
        setState(() {
          _studentsMap[classId] = students;
          _loadingStudentsMap[classId] = false;
        });
      }
    } catch (e) {
      debugPrint('[UI] ClassesTab._loadStudentsForClass() failed: $e');
      if (mounted) {
        setState(() {
          _loadingStudentsMap[classId] = false;
        });
      }
    }
  }

  void _toggleExpand(String classId) {
    final wasExpanded = _expandedClasses[classId] ?? false;
    setState(() {
      _expandedClasses[classId] = !wasExpanded;
    });

    if (!wasExpanded && _studentsMap[classId] == null) {
      _loadStudentsForClass(classId);
    }
  }

  Future<void> _showAddClassDialog() async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceVariant,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Add Class',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            style: GoogleFonts.plusJakartaSans(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              labelText: 'Class Name',
              labelStyle: GoogleFonts.plusJakartaSans(
                color: AppTheme.textMuted,
              ),
            ),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Name required' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(color: AppTheme.textMuted),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final messenger = ScaffoldMessenger.of(context);
                final result = await SupabaseService.createClass(
                  controller.text.trim(),
                );
                if (result != null && mounted) {
                  Navigator.pop(ctx, true);
                } else if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        'Failed to create class. Check Supabase logs.',
                        style: GoogleFonts.plusJakartaSans(fontSize: 13),
                      ),
                      backgroundColor: AppTheme.error,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                }
              }
            },
            child: Text(
              'Add',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );

    if (result == true) _loadClasses();
    controller.dispose();
  }

  Future<void> _showEditClassDialog(ClassModel classModel) async {
    final controller = TextEditingController(text: classModel.name);
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceVariant,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Edit Class',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            style: GoogleFonts.plusJakartaSans(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              labelText: 'Class Name',
              labelStyle: GoogleFonts.plusJakartaSans(
                color: AppTheme.textMuted,
              ),
            ),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Name required' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(color: AppTheme.textMuted),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final messenger = ScaffoldMessenger.of(context);
                final success = await SupabaseService.updateClass(
                  classModel.id,
                  controller.text.trim(),
                );
                if (success && mounted) {
                  Navigator.pop(ctx, true);
                } else if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        'Failed to update class. Check Supabase logs.',
                        style: GoogleFonts.plusJakartaSans(fontSize: 13),
                      ),
                      backgroundColor: AppTheme.error,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                }
              }
            },
            child: Text(
              'Save',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );

    if (result == true) _loadClasses();
    controller.dispose();
  }

  Future<void> _showDeleteClassDialog(ClassModel classModel) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceVariant,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Class',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${classModel.name}"? This action cannot be undone and will un-enroll students.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: AppTheme.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(color: AppTheme.textMuted),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final messenger = ScaffoldMessenger.of(context);
      final success = await SupabaseService.deleteClass(classModel.id);
      if (success && mounted) {
        _loadClasses();
      } else if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Failed to delete class. Check Supabase logs.',
              style: GoogleFonts.plusJakartaSans(fontSize: 13),
            ),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Future<void> _showAddStudentDialog(ClassModel classModel) async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final nameController = TextEditingController();
    final rollNoController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceVariant,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Add Student to ${classModel.name}',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: rollNoController,
                  style: GoogleFonts.plusJakartaSans(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Roll Number (Alphanumeric)',
                    labelStyle: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textMuted,
                    ),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Roll number required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: nameController,
                  style: GoogleFonts.plusJakartaSans(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    labelStyle: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textMuted,
                    ),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Name required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailController,
                  style: GoogleFonts.plusJakartaSans(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Email',
                    labelStyle: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textMuted,
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Email required';
                    if (!v.contains('@') || !v.contains('.')) {
                      return 'Valid email required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  style: GoogleFonts.plusJakartaSans(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textMuted,
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password required';
                    if (v.length < 6) return 'Min 6 characters';
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(color: AppTheme.textMuted),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final messenger = ScaffoldMessenger.of(context);
                final user = await SupabaseService.createUser(
                  email: emailController.text.trim(),
                  password: passwordController.text,
                  name: nameController.text.trim(),
                  role: 'student',
                  rollNo: rollNoController.text.trim().toUpperCase(),
                );
                if (user != null) {
                  await SupabaseService.enrollStudentInClass(
                    studentId: user.id,
                    classId: classModel.id,
                  );
                  if (mounted) Navigator.pop(ctx, true);
                } else {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        'Failed to create student. Check Supabase logs.',
                        style: GoogleFonts.plusJakartaSans(fontSize: 13),
                      ),
                      backgroundColor: AppTheme.error,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                }
              }
            },
            child: Text(
              'Add',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );

    if (result == true) {
      _loadStudentsForClass(classModel.id);
    }
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
    rollNoController.dispose();
  }

  Future<void> _showEditStudentDialog(UserModel student, ClassModel currentClass) async {
    final nameController = TextEditingController(text: student.name);
    final emailController = TextEditingController(text: student.email);
    final rollNoController = TextEditingController(text: student.rollNo);
    String? selectedClassId = student.classId;
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surfaceVariant,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Edit Student',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: rollNoController,
                    style: GoogleFonts.plusJakartaSans(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Roll Number (Alphanumeric)',
                      labelStyle: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textMuted,
                      ),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Roll number required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: nameController,
                    style: GoogleFonts.plusJakartaSans(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      labelStyle: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textMuted,
                      ),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Name required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailController,
                    style: GoogleFonts.plusJakartaSans(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Email',
                      labelStyle: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textMuted,
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Email required';
                      if (!v.contains('@') || !v.contains('.')) {
                        return 'Valid email required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Class',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF130E26).withOpacity(0.85),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0x33FFFFFF),
                        width: 1.0,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedClassId,
                        isExpanded: true,
                        dropdownColor: AppTheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        items: _classes
                            .map(
                              (c) => DropdownMenuItem(
                                value: c.id,
                                child: Text(c.name),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setDialogState(() => selectedClassId = v),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Cancel',
                style: GoogleFonts.plusJakartaSans(color: AppTheme.textMuted),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final messenger = ScaffoldMessenger.of(context);
                  final success = await SupabaseService.updateUser(
                    student.id,
                    data: {
                      'name': nameController.text.trim(),
                      'email': emailController.text.trim(),
                      'class_id': selectedClassId,
                      'roll_no': rollNoController.text.trim().toUpperCase(),
                    },
                  );
                  if (success && mounted) {
                    Navigator.pop(ctx, true);
                  } else if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          'Failed to update student. Check Supabase logs.',
                          style: GoogleFonts.plusJakartaSans(fontSize: 13),
                        ),
                        backgroundColor: AppTheme.error,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  }
                }
              },
              child: Text(
                'Save',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      _loadStudentsForClass(currentClass.id);
      if (selectedClassId != null && selectedClassId != currentClass.id) {
        _loadStudentsForClass(selectedClassId!);
      }
    }
    nameController.dispose();
    emailController.dispose();
    rollNoController.dispose();
  }

  Future<void> _showDeleteStudentDialog(UserModel student, ClassModel classModel) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceVariant,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Student',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        content: Text(
          'Are you sure you want to delete ${student.name}? This action cannot be undone.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: AppTheme.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(color: AppTheme.textMuted),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final messenger = ScaffoldMessenger.of(context);
      final success = await SupabaseService.deleteUser(student.id);
      if (success && mounted) {
        _loadStudentsForClass(classModel.id);
      } else if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Failed to delete student. Check Supabase logs.',
              style: GoogleFonts.plusJakartaSans(fontSize: 13),
            ),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Future<void> _importStudentsFromCsv(ClassModel classModel) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      String csvContent = '';

      if (kIsWeb) {
        if (file.bytes != null) {
          csvContent = utf8.decode(file.bytes!);
        } else {
          throw Exception('File bytes are empty on web');
        }
      } else {
        if (file.path != null) {
          final ioFile = File(file.path!);
          csvContent = await ioFile.readAsString();
        } else {
          throw Exception('File path is empty on mobile');
        }
      }

      if (csvContent.isEmpty) {
        throw Exception('CSV file is empty');
      }

      final parsed = CsvExportService.parseStudentsCsv(csvContent);
      if (parsed.isEmpty) {
        throw Exception('No students could be parsed from the CSV. Please check columns.');
      }

      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.surfaceVariant,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Bulk Import Students',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Found ${parsed.length} student records in the CSV.',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'All imported students will be automatically enrolled in ${classModel.name}.',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Note: Roll numbers will be used for logins if no emails are provided. Default passwords will be set if missing in CSV.',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Cancel',
                style: GoogleFonts.plusJakartaSans(color: AppTheme.textMuted),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'Import',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      setState(() {
        _loadingStudentsMap[classModel.id] = true;
      });

      int successCount = 0;
      int failureCount = 0;

      for (final s in parsed) {
        final rollNo = s['roll_no'] ?? s['rollno'] ?? '';
        final name = s['name'] ?? '';

        String email = s['email'] ?? '';
        if (email.isEmpty && rollNo.isNotEmpty) {
          email = '${rollNo.toLowerCase()}@upasthitix.com';
        }

        String password = s['password'] ?? '';
        if (password.isEmpty) {
          password = rollNo.isNotEmpty ? rollNo : 'student123';
        }
        if (password.length < 6) {
          password = password.padRight(6, '1');
        }

        if (email.isEmpty || name.isEmpty) {
          failureCount++;
          continue;
        }

        try {
          final user = await SupabaseService.createUser(
            email: email.trim(),
            password: password,
            name: name.trim(),
            role: 'student',
            rollNo: rollNo.toUpperCase(),
          );
          if (user != null) {
            await SupabaseService.enrollStudentInClass(
              studentId: user.id,
              classId: classModel.id,
            );
            successCount++;
          } else {
            failureCount++;
          }
        } catch (e) {
          failureCount++;
        }
      }

      _loadStudentsForClass(classModel.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Import completed: $successCount succeeded, $failureCount failed.',
              style: GoogleFonts.plusJakartaSans(fontSize: 13),
            ),
            backgroundColor: successCount > 0 ? AppTheme.successSoft : AppTheme.errorSoft,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error during bulk import: $e',
              style: GoogleFonts.plusJakartaSans(fontSize: 13),
            ),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.shadowLight.withAlpha(15),
            border: Border(
              bottom: BorderSide(
                color: AppTheme.shadowLight.withAlpha(25),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Text(
                'Classes',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _showAddClassDialog,
                icon: const Icon(Icons.add, size: 16),
                label: Text(
                  'Add Class',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        // List of expandable class cards
        Expanded(
          child: _classes.isEmpty
              ? Center(
                  child: EmptyStateWidget(
                    icon: Icons.class_outlined,
                    title: 'No Classes Yet',
                    description:
                        'Add classes to assign teachers and enroll students.',
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _classes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final classModel = _classes[index];
                    final isExpanded = _expandedClasses[classModel.id] ?? false;
                    final students = _studentsMap[classModel.id];
                    final isLoadingStudents = _loadingStudentsMap[classModel.id] ?? false;

                    return _ClassCard(
                      classModel: classModel,
                      isExpanded: isExpanded,
                      onToggleExpand: () => _toggleExpand(classModel.id),
                      students: students,
                      isLoadingStudents: isLoadingStudents,
                      onAddClassStudent: () => _showAddStudentDialog(classModel),
                      onImportClassStudents: () => _importStudentsFromCsv(classModel),
                      onEditClass: () => _showEditClassDialog(classModel),
                      onDeleteClass: () => _showDeleteClassDialog(classModel),
                      onEditStudent: (student) => _showEditStudentDialog(student, classModel),
                      onDeleteStudent: (student) => _showDeleteStudentDialog(student, classModel),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ClassCard extends StatefulWidget {
  final ClassModel classModel;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final List<UserModel>? students;
  final bool isLoadingStudents;
  final VoidCallback onAddClassStudent;
  final VoidCallback onImportClassStudents;
  final VoidCallback onEditClass;
  final VoidCallback onDeleteClass;
  final Function(UserModel) onEditStudent;
  final Function(UserModel) onDeleteStudent;

  const _ClassCard({
    required this.classModel,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.students,
    required this.isLoadingStudents,
    required this.onAddClassStudent,
    required this.onImportClassStudents,
    required this.onEditClass,
    required this.onDeleteClass,
    required this.onEditStudent,
    required this.onDeleteStudent,
  });

  @override
  State<_ClassCard> createState() => _ClassCardState();
}

class _ClassCardState extends State<_ClassCard> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredStudents = widget.students?.where((s) {
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.trim().toLowerCase();
      return s.name.toLowerCase().contains(q) ||
          s.email.toLowerCase().contains(q) ||
          (s.rollNo ?? '').toLowerCase().contains(q);
    }).toList() ?? [];

    return Container(
      decoration: AppTheme.neumorphic(
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Class Header
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onToggleExpand,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppTheme.primaryGradient,
                      ),
                      child: const Icon(
                        Icons.class_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.classModel.name,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.isLoadingStudents
                                ? 'Loading students...'
                                : widget.students == null
                                    ? 'Tap to view students'
                                    : '${widget.students!.length} student(s) enrolled',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.edit_outlined,
                        color: AppTheme.primary,
                        size: 18,
                      ),
                      tooltip: 'Edit Class',
                      onPressed: widget.onEditClass,
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outlined,
                        color: AppTheme.error,
                        size: 18,
                      ),
                      tooltip: 'Delete Class',
                      onPressed: widget.onDeleteClass,
                    ),
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: widget.isExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.expand_more_rounded,
                        color: AppTheme.textMuted,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Collapsible Student Section
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.fastOutSlowIn,
            child: widget.isExpanded
                ? Container(
                    decoration: const BoxDecoration(
                      color: Color(0x06FFFFFF),
                      border: Border(
                        top: BorderSide(color: Color(0x12FFFFFF)),
                      ),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Student management tools header
                        Row(
                          children: [
                            Text(
                              'Students list',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const Spacer(),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryGreen,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                textStyle: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: widget.onAddClassStudent,
                              icon: const Icon(Icons.person_add_alt_1_rounded, size: 13),
                              label: const Text('Add Student'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: AppTheme.primaryCyan),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                textStyle: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: widget.onImportClassStudents,
                              icon: Icon(Icons.upload_file_rounded, size: 13, color: AppTheme.primaryCyan),
                              label: Text('Bulk CSV', style: TextStyle(color: AppTheme.primaryCyan)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Sleek inline search bar
                        TextField(
                          controller: _searchController,
                          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Search roll number or name...',
                            hintStyle: GoogleFonts.plusJakartaSans(color: AppTheme.textDisabled, fontSize: 12),
                            prefixIcon: Icon(Icons.search_rounded, size: 16, color: AppTheme.textMuted),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            fillColor: const Color(0xFF0F0C1E).withOpacity(0.5),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0x18FFFFFF)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0x18FFFFFF)),
                            ),
                          ),
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        // Student list view
                        if (widget.isLoadingStudents)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: CircularProgressIndicator(color: AppTheme.primaryCyan),
                            ),
                          )
                        else if (widget.students == null || widget.students!.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Column(
                                children: [
                                  Icon(Icons.people_outline_rounded, size: 28, color: AppTheme.textMuted.withOpacity(0.5)),
                                  const SizedBox(height: 6),
                                  Text(
                                    'No students in this class yet.',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      color: AppTheme.textMuted,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else if (filteredStudents.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Text(
                                'No matching students found.',
                                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.textMuted),
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filteredStudents.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, idx) {
                              final student = filteredStudents[idx];
                              return Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.backgroundVariant.withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0x12FFFFFF)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppTheme.primary.withOpacity(0.2),
                                      ),
                                      child: Center(
                                        child: Text(
                                          student.name.isNotEmpty ? student.name[0].toUpperCase() : 'S',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.primaryBlue,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  student.name,
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppTheme.textPrimary,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (student.rollNo != null && student.rollNo!.isNotEmpty) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.primaryCyan.withOpacity(0.15),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    student.rollNo!,
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.bold,
                                                      color: AppTheme.primaryCyan,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 1),
                                          Text(
                                            student.email,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 10,
                                              color: AppTheme.textMuted,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.edit_outlined,
                                        color: AppTheme.primary,
                                        size: 16,
                                      ),
                                      tooltip: 'Edit Student',
                                      onPressed: () => widget.onEditStudent(student),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete_outlined,
                                        color: AppTheme.error,
                                        size: 16,
                                      ),
                                      tooltip: 'Delete Student',
                                      onPressed: () => widget.onDeleteStudent(student),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
