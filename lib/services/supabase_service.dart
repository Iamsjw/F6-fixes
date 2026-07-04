import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../models/session_model.dart';
import '../models/attendance_model.dart';

class SupabaseService {
  static const String _projectUrl = 'https://fgmdixxhzwhgaiajcxal.supabase.co';
  static const String _anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZnbWRpeHhoendoZ2FpYWpjeGFsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc2NzM1NzQsImV4cCI6MjA5MzI0OTU3NH0.YDXk2lWWlN5SAN1MoXnL0JSVj8c7F_ZI_EOGclb3eas';

  static SupabaseClient get client => Supabase.instance.client;
  static User? get currentAuthUser => client.auth.currentUser;

  static List<ClassModel>? _cachedClasses;
  static List<SubjectModel>? _cachedSubjects;

  // ─── Rate Limiting for Session Code ─────────────────────────────────────────
  static int _failedCodeAttempts = 0;
  static DateTime? _lockoutUntil;

  static bool isSessionCodeLockedOut() {
    if (_lockoutUntil != null) {
      if (DateTime.now().isAfter(_lockoutUntil!)) {
        _failedCodeAttempts = 0;
        _lockoutUntil = null;
        return false;
      }
      return true;
    }
    return false;
  }

  static Duration? getRemainingLockoutDuration() {
    if (_lockoutUntil != null) {
      final diff = _lockoutUntil!.difference(DateTime.now());
      return diff.isNegative ? Duration.zero : diff;
    }
    return null;
  }

  static void recordFailedCodeAttempt() {
    _failedCodeAttempts++;
    if (_failedCodeAttempts >= 5) {
      _lockoutUntil = DateTime.now().add(const Duration(minutes: 10));
    }
  }

  static void recordSuccessfulCodeAttempt() {
    _failedCodeAttempts = 0;
    _lockoutUntil = null;
  }

  // ─── IST Helper ─────────────────────────────────────────────────────────────
  static DateTime nowIST() {
    return DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
  }

  // ─── Cache Control ──────────────────────────────────────────────────────────
  static void clearCache() {
    _cachedClasses = null;
    _cachedSubjects = null;
  }

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: _projectUrl,
      anonKey: _anonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.implicit,
        autoRefreshToken: true,
      ),
    );
  }

  // ─── Auth ──────────────────────────────────────────────────────────────────
  static Future<AuthResponse> signIn(String email, String password) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  static Future<AuthResponse> signUp(
    String email,
    String password,
    String name,
    String role,
  ) async {
    final response = await client.auth.signUp(
      email: email,
      password: password,
      data: {'name': name, 'role': role},
    );
    if (response.user != null) {
      await client.from('users').upsert({
        'id': response.user!.id,
        'name': name,
        'email': email,
        'role': role,
      });
    }
    return response;
  }

  static Future<void> signOut() async {
    clearCache();
    await client.auth.signOut();
  }

  static Future<void> resetPasswordForEmail(String email) async {
    await client.auth.resetPasswordForEmail(email.trim());
  }

  static Future<AuthResponse> verifyPasswordResetOtp({
    required String email,
    required String token,
  }) async {
    return await client.auth.verifyOTP(
      email: email.trim(),
      token: token.trim(),
      type: OtpType.recovery,
    );
  }

  static Future<UserResponse> updatePassword(String newPassword) async {
    return await client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  // ─── User Profile ──────────────────────────────────────────────────────────
  static Future<UserModel?> getUserProfile(String userId) async {
    try {
      final data = await client
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (data == null) return null;
      return UserModel.fromMap(data);
    } catch (_) {
      return null;
    }
  }

  static Future<UserModel?> getCurrentUserProfile() async {
    final user = currentAuthUser;
    if (user == null) return null;
    return getUserProfile(user.id);
  }

  // ─── Classes & Subjects ───────────────────────────────────────────────────
  static Future<List<ClassModel>> getClasses({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedClasses != null && _cachedClasses!.isNotEmpty) {
      return _cachedClasses!;
    }
    try {
      debugPrint('[Supabase] getClasses called');
      final data = await client.from('classes').select().order('name');
      debugPrint('[Supabase] getClasses returned ${data.length} classes');
      final list = (data as List)
          .map((e) => ClassModel.fromMap(e as Map<String, dynamic>))
          .toList();
      _cachedClasses = list;
      return list;
    } catch (e, stackTrace) {
      debugPrint('[Supabase] getClasses failed: $e');
      debugPrint('[Supabase] Stack trace: $stackTrace');
      return _cachedClasses ?? [];
    }
  }

  static Future<List<SubjectModel>> getSubjects({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedSubjects != null && _cachedSubjects!.isNotEmpty) {
      return _cachedSubjects!;
    }
    try {
      debugPrint('[Supabase] getSubjects called');
      final data = await client.from('subjects').select().order('name');
      debugPrint('[Supabase] getSubjects returned ${data.length} subjects');
      final list = (data as List)
          .map((e) => SubjectModel.fromMap(e as Map<String, dynamic>))
          .toList();
      _cachedSubjects = list;
      return list;
    } catch (e, stackTrace) {
      debugPrint('[Supabase] getSubjects failed: $e');
      debugPrint('[Supabase] Stack trace: $stackTrace');
      return _cachedSubjects ?? [];
    }
  }

  // ─── Teacher Assignments ──────────────────────────────────────────────────
  static Future<List<AssignmentModel>> getTeacherAssignments(
    String teacherId,
  ) async {
    try {
      debugPrint(
        '[Supabase] getTeacherAssignments called for teacherId=$teacherId',
      );
      var query = client
          .from('teacher_assignments')
          .select('*, classes(name), subjects(name)');
      if (teacherId.isNotEmpty) {
        query = query.eq('teacher_id', teacherId);
      }
      final data = await query;
      debugPrint(
        '[Supabase] getTeacherAssignments returned ${data.length} assignments',
      );
      return (data as List).map((e) {
        final map = e as Map<String, dynamic>;
        return AssignmentModel.fromMap({
          ...map,
          'class_name': (map['classes'] as Map?)?['name'],
          'subject_name': (map['subjects'] as Map?)?['name'],
        });
      }).toList();
    } catch (e, stackTrace) {
      debugPrint('[Supabase] getTeacherAssignments failed: $e');
      debugPrint('[Supabase] Stack trace: $stackTrace');
      return [];
    }
  }

  // ─── Sessions ─────────────────────────────────────────────────────────────
  static Future<SessionModel?> createSession({
    required String teacherId,
    required String classId,
    required String subjectId,
    required String code,
    required String securityLevel,
    required int rssiThreshold,
    required int durationSeconds,
    String? lectureTime,
    List<String>? classIds,
  }) async {
    try {
      final now = DateTime.now().toUtc();
      final endTime = now.add(Duration(seconds: durationSeconds));
      final data = await client
          .from('sessions')
          .insert({
            'teacher_id': teacherId,
            'class_id': classId,
            'subject_id': subjectId,
            'code': code,
            'security_level': securityLevel,
            'rssi_threshold': rssiThreshold,
            'start_time': now.toIso8601String(),
            'end_time': endTime.toIso8601String(),
            'is_active': true,
            'lecture_time': lectureTime,
            'class_ids': classIds,
          })
          .select()
          .single();
      return SessionModel.fromMap(data);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> endSession(String sessionId) async {
    try {
      await client
          .from('sessions')
          .update({
            'is_active': false,
            'end_time': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', sessionId);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> updateSessionSecurityLevel(
    String sessionId,
    String securityLevel,
  ) async {
    try {
      await client
          .from('sessions')
          .update({'security_level': securityLevel})
          .eq('id', sessionId);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<SessionModel?> getActiveSessionByCode(String code) async {
    if (isSessionCodeLockedOut()) {
      return null;
    }

    try {
      final nowUtcStr = DateTime.now().toUtc().toIso8601String();
      final data = await client
          .from('sessions')
          .select()
          .eq('code', code)
          .eq('is_active', true)
          .gte('end_time', nowUtcStr)
          .maybeSingle();
      if (data == null) {
        recordFailedCodeAttempt();
        return null;
      }
      recordSuccessfulCodeAttempt();
      return SessionModel.fromMap(data);
    } catch (_) {
      recordFailedCodeAttempt();
      return null;
    }
  }

  static Future<SessionModel?> getActiveSessionForTeacher(
    String teacherId,
  ) async {
    try {
      final data = await client
          .from('sessions')
          .select()
          .eq('teacher_id', teacherId)
          .eq('is_active', true)
          .maybeSingle();
      if (data == null) return null;
      return SessionModel.fromMap(data);
    } catch (_) {
      return null;
    }
  }

  // ─── Attendance ───────────────────────────────────────────────────────────
  static Future<bool> markAttendance({
    required String studentId,
    required String sessionId,
  }) async {
    try {
      // Check for duplicate
      final existing = await client
          .from('attendance')
          .select()
          .eq('student_id', studentId)
          .eq('session_id', sessionId)
          .eq('status', 'present')
          .maybeSingle();
      if (existing != null) return false; // already marked

      final timestampUtc = DateTime.now().toUtc().toIso8601String();
      final attendanceRecord = await client
          .from('attendance')
          .insert({
            'student_id': studentId,
            'session_id': sessionId,
            'timestamp': timestampUtc,
            'status': 'present',
          })
          .select()
          .single();

      // Log the action — best-effort only; do NOT fail the whole operation
      try {
        await client.from('attendance_logs').insert({
          'attendance_id': attendanceRecord['id'],
          'action': 'marked',
          'performed_by': studentId,
          'student_id': studentId,
          'session_id': sessionId,
          'timestamp': timestampUtc,
        });
      } catch (logErr) {
        if (kDebugMode) debugPrint('[Supabase] attendance_logs insert failed: $logErr');
      }

      return true;
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('duplicate') || errStr.contains('unique')) {
        return false;
      }
      if (kDebugMode) debugPrint('[Supabase] markAttendance failed: $e');
      return false;
    }
  }

  static Future<bool> revokeAttendance({
    required String attendanceId,
    required String teacherId,
    required String studentId,
    required String sessionId,
    String? reason,
  }) async {
    try {
      // Pure binary Present/Absent model: delete record when marking absent/revoking
      await client
          .from('attendance')
          .delete()
          .eq('id', attendanceId);

      await client.from('attendance_logs').insert({
        'action': 'removed',
        'performed_by': teacherId,
        'student_id': studentId,
        'session_id': sessionId,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'reason': reason ?? '',
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Sets attendance status (present/absent) for a student and a session.
  static Future<bool> setAttendanceStatus({
    required String studentId,
    required String sessionId,
    required String status,
  }) async {
    try {
      final existing = await client
          .from('attendance')
          .select()
          .eq('student_id', studentId)
          .eq('session_id', sessionId)
          .maybeSingle();

      if (status == 'absent') {
        if (existing != null) {
          await client
              .from('attendance')
              .delete()
              .eq('id', existing['id']);
        }
        return true;
      }

      if (existing != null) {
        await client
            .from('attendance')
            .update({
              'status': 'present',
              'timestamp': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', existing['id']);
      } else {
        await client.from('attendance').insert({
          'student_id': studentId,
          'session_id': sessionId,
          'timestamp': DateTime.now().toUtc().toIso8601String(),
          'status': 'present',
        });
      }
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[Supabase] setAttendanceStatus failed: $e');
      return false;
    }
  }

  static Future<List<AttendanceModel>> getSessionAttendance(
    String sessionId,
  ) async {
    try {
      final data = await client
          .from('attendance')
          .select('*, users(name, email)')
          .eq('session_id', sessionId)
          .eq('status', 'present')
          .order('timestamp');
      return (data as List).map((e) {
        final map = e as Map<String, dynamic>;
        return AttendanceModel.fromMap({
          ...map,
          'student_name': (map['users'] as Map?)?['name'],
          'student_email': (map['users'] as Map?)?['email'],
        });
      }).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<AttendanceModel>> getStudentAttendanceHistory(
    String studentId,
  ) async {
    try {
      final data = await client
          .from('attendance')
          .select('*, sessions(*, subjects(name))')
          .eq('student_id', studentId)
          .order('timestamp', ascending: false);
      return (data as List)
          .map((e) => AttendanceModel.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<bool> hasStudentMarkedAttendance({
    required String studentId,
    required String sessionId,
  }) async {
    try {
      final data = await client
          .from('attendance')
          .select()
          .eq('student_id', studentId)
          .eq('session_id', sessionId)
          .eq('status', 'present')
          .maybeSingle();
      return data != null;
    } catch (_) {
      return false;
    }
  }

  // ─── Teacher Reports ──────────────────────────────

  /// Get all sessions for a teacher with attendance stats.
  /// Returns a list of maps with session data + present_count, total_count.
  static Future<List<Map<String, dynamic>>> getTeacherSessionsWithStats(
    String teacherId,
  ) async {
    try {
      debugPrint('[Reports] Loading sessions for teacher: $teacherId');
      // Fetch all sessions for this teacher with class/subject names
      final sessions = await client
          .from('sessions')
          .select('*, classes(name), subjects(name)')
          .eq('teacher_id', teacherId)
          .order('start_time', ascending: false);
      if (sessions.isEmpty) return [];

      // Fetch attendance stats for all these sessions
      final sessionIds = (sessions as List).map((s) => s['id']).toList();
      final attendance = await client
          .from('attendance')
          .select('session_id, status')
          .filter('session_id', 'in', sessionIds);

      // Aggregate attendance by session
      final stats = <String, Map<String, int>>{};
      for (final a in attendance) {
        final sid = a['session_id'] as String;
        stats.putIfAbsent(sid, () => {'present': 0, 'total': 0});
        stats[sid]!['total'] = stats[sid]!['total']! + 1;
        if (a['status'] == 'present') {
          stats[sid]!['present'] = stats[sid]!['present']! + 1;
        }
      }

      // Merge stats into session data
      final result = (sessions as List).map((session) {
        final sid = session['id'] as String;
        final s = stats[sid] ?? {'present': 0, 'total': 0};
        return {
          ...session as Map<String, dynamic>,
          'present_count': s['present'],
          'total_count': s['total'],
        };
      }).toList();

      debugPrint('[Reports] Loaded ${result.length} sessions with stats');
      return result;
    } catch (e, stackTrace) {
      debugPrint('[Reports] Failed to get teacher sessions: $e');
      debugPrint('[Reports] Stack: $stackTrace');
      return [];
    }
  }

  /// Get attendance records for a specific teacher session.
  /// Supports combined sessions by reading both class_id and class_ids.
  static Future<List<Map<String, dynamic>>> getSessionAttendanceForReport(
    String sessionId,
  ) async {
    try {
      final sessionData = await client
          .from('sessions')
          .select('class_id, class_ids')
          .eq('id', sessionId)
          .maybeSingle();
      if (sessionData == null) return [];

      // Build list of all class IDs (combined sessions use class_ids JSON array)
      final List<String> allClassIds = [];
      final rawClassIds = sessionData['class_ids'];
      if (rawClassIds != null) {
        final List<dynamic> list = rawClassIds is List
            ? rawClassIds
            : (rawClassIds is String ? jsonDecode(rawClassIds) : []);
        allClassIds.addAll(list.map((e) => e.toString()));
      }
      final primaryId = sessionData['class_id'] as String?;
      if (primaryId != null && primaryId.isNotEmpty && !allClassIds.contains(primaryId)) {
        allClassIds.insert(0, primaryId);
      }
      if (allClassIds.isEmpty) return [];

      final studentsData = await client
          .from('users')
          .select('id, name, email')
          .inFilter('class_id', allClassIds)
          .eq('role', 'student');
      final students = (studentsData as List).cast<Map<String, dynamic>>();

      final attendanceData = await client
          .from('attendance')
          .select('*, users(name, email)')
          .eq('session_id', sessionId);
      final attendanceList = (attendanceData as List).cast<Map<String, dynamic>>();

      final attendanceMap = {
        for (var att in attendanceList) att['student_id'] as String: att
      };

      final merged = <Map<String, dynamic>>[];
      for (var student in students) {
        final studentId = student['id'] as String;
        if (attendanceMap.containsKey(studentId)) {
          merged.add(attendanceMap[studentId]!);
        } else {
          merged.add({
            'id': '',
            'student_id': studentId,
            'session_id': sessionId,
            'timestamp': DateTime.now().toUtc().toIso8601String(),
            'status': 'absent',
            'users': {
              'name': student['name'],
              'email': student['email'],
            }
          });
        }
      }

      // Sort by student name alphabetically
      merged.sort((a, b) {
        final nameA = (a['users']?['name'] as String? ?? '').toLowerCase();
        final nameB = (b['users']?['name'] as String? ?? '').toLowerCase();
        return nameA.compareTo(nameB);
      });

      return merged;
    } catch (e) {
      debugPrint('[Reports] Failed to get session attendance: $e');
      return [];
    }
  }

  // ─── Realtime ─────────────────────────────────────────────────────────────
  static RealtimeChannel subscribeToSessionAttendance(
    String sessionId,
    void Function(List<Map<String, dynamic>>) onUpdate,
  ) {
    debugPrint('[Realtime] Subscribing to attendance for session: $sessionId');
    Timer? debounceTimer;

    return client
        .channel('attendance_$sessionId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'attendance',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'session_id',
            value: sessionId,
          ),
          callback: (payload) {
            debugPrint(
              '[Realtime] Attendance change detected: ${payload.toString()}',
            );
            debounceTimer?.cancel();
            debounceTimer = Timer(const Duration(milliseconds: 300), () {
              getSessionAttendance(sessionId)
                  .then((records) {
                    debugPrint(
                      '[Realtime] Fetched ${records.length} records, pushing to UI',
                    );
                    onUpdate(records.map((e) => e.toMap()).toList());
                  })
                  .catchError((e) {
                    debugPrint('[Realtime] Error fetching attendance: $e');
                  });
            });
          },
        )
        .subscribe();
  }

  // ─── Connection Test ──────────────────────────────────────
  static Future<Map<String, dynamic>> testConnection() async {
    final result = {
      'isInitialized': false,
      'isAuthenticated': false,
      'currentUserId': '',
      'currentUserRole': '',
      'usersTableAccess': false,
      'classesTableAccess': false,
      'error': '',
    };

    try {
      // Check if Supabase is initialized
      final client = Supabase.instance.client;
      result['isInitialized'] = true;

      // Check authentication
      final user = currentAuthUser;
      if (user == null) {
        result['error'] = 'Not authenticated';
        return result;
      }
      result['isAuthenticated'] = true;
      result['currentUserId'] = user.id;

      // Check current user's role
      final profile = await getUserProfile(user.id);
      if (profile == null) {
        result['error'] = 'User profile not found in users table';
        return result;
      }
      result['currentUserRole'] = profile.role;

      // Test users table access
      try {
        await client.from('users').select('id').limit(1);
        result['usersTableAccess'] = true;
      } catch (e) {
        result['error'] = 'Users table access failed: $e';
      }

      // Test classes table access
      try {
        await client.from('classes').select('id').limit(1);
        result['classesTableAccess'] = true;
      } catch (e) {
        result['error'] = '${result['error']}\nClasses table access failed: $e';
      }

      return result;
    } catch (e, stackTrace) {
      debugPrint('[Supabase] testConnection failed: $e');
      debugPrint('[Supabase] Stack trace: $stackTrace');
      result['error'] = e.toString();
      return result;
    }
  }

  // ─── Admin: User Management ─────────────────────────────

  static Future<UserModel?> createUser({
    required String email,
    required String password,
    required String name,
    required String role,
    String? rollNo,
    String? classId,
  }) async {
    try {
      // Use a temporary non-persistent client with implicit flow so it does not
      // require asyncStorage for PKCE and does not overwrite current user session.
      final tempClient = SupabaseClient(
        _projectUrl,
        _anonKey,
        authOptions: const AuthClientOptions(
          authFlowType: AuthFlowType.implicit,
        ),
      );
      final response = await tempClient.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'name': name.trim(), 'role': role},
      );

      final user = response.user;
      if (user != null) {
        final userData = <String, dynamic>{
          'id': user.id,
          'name': name.trim(),
          'email': email.trim(),
          'role': role,
        };
        if (rollNo != null && rollNo.trim().isNotEmpty) {
          userData['roll_no'] = rollNo.trim();
        }
        if (classId != null && classId.trim().isNotEmpty) {
          userData['class_id'] = classId.trim();
        }

        // Try upsert with all attributes first; fallback to basic if DB table lacks optional columns
        try {
          await client.from('users').upsert(userData);
        } catch (dbErr) {
          if (kDebugMode) debugPrint('[Admin] Upsert with optional columns failed ($dbErr), retrying basic');
          userData.remove('roll_no');
          userData.remove('class_id');
          await client.from('users').upsert(userData);
        }

        final profile = await getUserProfile(user.id);
        return profile ?? UserModel.fromMap(userData);
      }
      throw 'No user object returned from Supabase Auth.';
    } on AuthException catch (e) {
      if (kDebugMode) debugPrint('[Admin] AuthException: ${e.message}');
      throw e.message;
    } catch (e) {
      if (kDebugMode) debugPrint('[Admin] Failed to create user: $e');
      throw e.toString();
    }
  }

  /// List all users by role. Note: class_id join removed because the
  /// actual users table lacks a foreign key to classes. To re-enable
  /// class name lookups, add class_id column and FK to classes table.
  static Future<List<UserModel>> listUsers({String? role}) async {
    try {
      debugPrint('[Admin] listUsers called with role=$role');
      debugPrint('[Admin] Current user: ${currentAuthUser?.id}');
      var query = client.from('users').select();
      if (role != null) {
        query = query.eq('role', role);
      }
      final data = await query.order('name');
      debugPrint('[Admin] listUsers returned ${data.length} users');
      return (data as List)
          .map((e) => UserModel.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (e, stackTrace) {
      debugPrint('[Admin] Failed to list users: $e');
      debugPrint('[Admin] Stack trace: $stackTrace');
      return [];
    }
  }

  /// Fetch all students belonging to a specific class.
  /// This complies with RLS policies restricting global user queries.
  static Future<List<UserModel>> getStudentsByClass(String classId) async {
    try {
      debugPrint('[Supabase] getStudentsByClass called for classId=$classId');
      final data = await client
          .from('users')
          .select('*, classes(name)')
          .eq('class_id', classId)
          .eq('role', 'student')
          .order('name');
      debugPrint('[Supabase] getStudentsByClass returned ${data.length} students');
      return (data as List)
          .map((e) => UserModel.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (e, stackTrace) {
      debugPrint('[Supabase] getStudentsByClass failed: $e');
      debugPrint('[Supabase] Stack trace: $stackTrace');
      return [];
    }
  }

  static Future<List<UserModel>> getStudentsByClasses(List<String> classIds) async {
    try {
      debugPrint('[Supabase] getStudentsByClasses called for classIds=$classIds');
      if (classIds.isEmpty) return [];
      
      final data = await client
          .from('users')
          .select('*, classes(name)')
          .inFilter('class_id', classIds)
          .eq('role', 'student');
      
      final students = (data as List)
          .map((e) => UserModel.fromMap(e as Map<String, dynamic>))
          .toList();
          
      // Sort students alphabetically by roll_no, or name if roll_no is null
      students.sort((a, b) {
        if (a.rollNo != null && b.rollNo != null) {
          return a.rollNo!.toLowerCase().compareTo(b.rollNo!.toLowerCase());
        } else if (a.rollNo != null) {
          return -1;
        } else if (b.rollNo != null) {
          return 1;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      
      debugPrint('[Supabase] getStudentsByClasses returned ${students.length} students');
      return students;
    } catch (e, stackTrace) {
      debugPrint('[Supabase] getStudentsByClasses failed: $e');
      debugPrint('[Supabase] Stack trace: $stackTrace');
      return [];
    }
  }

  static Future<List<AttendanceModel>> getAttendanceForSessions(List<String> sessionIds) async {
    try {
      if (sessionIds.isEmpty) return [];
      final data = await client
          .from('attendance')
          .select()
          .inFilter('session_id', sessionIds);
      return (data as List)
          .map((e) => AttendanceModel.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[Supabase] getAttendanceForSessions failed: $e');
      return [];
    }
  }

  static Future<List<SessionModel>> getSessionsForSubjectReport({
    required String subjectId,
    required List<String> classIds,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      debugPrint(
        '[Supabase] getSessionsForSubjectReport: subjectId=$subjectId, classIds=$classIds, range=$startDate to $endDate',
      );
      if (classIds.isEmpty) return [];

      final data = await client
          .from('sessions')
          .select('*, classes(name), subjects(name)')
          .eq('subject_id', subjectId)
          .gte('start_time', startDate.toUtc().toIso8601String())
          .lte('start_time', endDate.toUtc().toIso8601String())
          .order('start_time', ascending: true);

      final filtered = (data as List).where((e) {
        final map = e as Map<String, dynamic>;
        final String? primaryClassId = map['class_id'] as String?;
        if (primaryClassId != null && classIds.contains(primaryClassId)) {
          return true;
        }
        final rawClassIds = map['class_ids'];
        if (rawClassIds != null) {
          List<String> ids = [];
          if (rawClassIds is List) {
            ids = rawClassIds.map((item) => item.toString()).toList();
          } else if (rawClassIds is String) {
            try {
              final list = jsonDecode(rawClassIds) as List;
              ids = list.map((item) => item.toString()).toList();
            } catch (_) {}
          }
          if (ids.any((id) => classIds.contains(id))) {
            return true;
          }
        }
        return false;
      }).toList();

      return filtered.map((e) {
        final map = e as Map<String, dynamic>;
        return SessionModel.fromMap({
          ...map,
          'class_name': (map['classes'] as Map?)?['name'],
          'subject_name': (map['subjects'] as Map?)?['name'],
        });
      }).toList();
    } catch (e, stackTrace) {
      debugPrint('[Supabase] getSessionsForSubjectReport failed: $e');
      debugPrint('[Supabase] Stack trace: $stackTrace');
      return [];
    }
  }

  // ─── Admin: Class Management ─────────────────────────────

  static Future<ClassModel?> createClass(String name) async {
    try {
      final data = await client
          .from('classes')
          .insert({'name': name})
          .select()
          .single();
      return ClassModel.fromMap(data);
    } catch (e) {
      debugPrint('[Admin] Failed to create class: $e');
      return null;
    }
  }

  static Future<bool> updateClass(String id, String name) async {
    try {
      await client.from('classes').update({'name': name}).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('[Admin] Failed to update class: $e');
      return false;
    }
  }

  static Future<bool> deleteClass(String id) async {
    try {
      await client.from('classes').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('[Admin] Failed to delete class: $e');
      return false;
    }
  }

  // ─── Admin: Subject Management ─────────────────────────────

  static Future<SubjectModel?> createSubject(String name) async {
    try {
      final data = await client
          .from('subjects')
          .insert({'name': name})
          .select()
          .single();
      return SubjectModel.fromMap(data);
    } catch (e) {
      debugPrint('[Admin] Failed to create subject: $e');
      return null;
    }
  }

  static Future<bool> updateSubject(String id, String name) async {
    try {
      await client.from('subjects').update({'name': name}).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('[Admin] Failed to update subject: $e');
      return false;
    }
  }

  static Future<bool> deleteSubject(String id) async {
    try {
      await client.from('subjects').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('[Admin] Failed to delete subject: $e');
      return false;
    }
  }

  // ─── Admin: Teacher Assignments ──────────────────────────

  static Future<AssignmentModel?> assignTeacherToClass({
    required String teacherId,
    required String classId,
    required String subjectId,
  }) async {
    try {
      final data = await client
          .from('teacher_assignments')
          .insert({
            'teacher_id': teacherId,
            'class_id': classId,
            'subject_id': subjectId,
          })
          .select()
          .single();
      return AssignmentModel.fromMap(data);
    } catch (e) {
      debugPrint('[Admin] Failed to assign teacher: $e');
      return null;
    }
  }

  static Future<bool> removeTeacherAssignment(String assignmentId) async {
    try {
      await client.from('teacher_assignments').delete().eq('id', assignmentId);
      return true;
    } catch (e) {
      debugPrint('[Admin] Failed to remove assignment: $e');
      return false;
    }
  }

  /// Update user profile (name, email, role, class_id).
  static Future<bool> updateUser(
    String userId, {
    required Map<String, dynamic> data,
  }) async {
    try {
      await client.from('users').update(data).eq('id', userId);
      return true;
    } catch (e) {
      debugPrint('[Admin] Failed to update user: $e');
      return false;
    }
  }

  /// Delete user from users table.
  /// Note: This does NOT delete from auth.users (requires service role key).
  static Future<bool> deleteUser(String userId) async {
    try {
      await client.from('users').delete().eq('id', userId);
      return true;
    } catch (e) {
      debugPrint('[Admin] Failed to delete user: $e');
      return false;
    }
  }

  // ─── Admin: Student Enrollment ───────────────────────────

  static Future<bool> enrollStudentInClass({
    required String studentId,
    required String classId,
  }) async {
    try {
      await client
          .from('users')
          .update({'class_id': classId})
          .eq('id', studentId);
      return true;
    } catch (e) {
      debugPrint('[Admin] Failed to enroll student: $e');
      return false;
    }
  }

  // ─── Admin: Reports ───────────────────────────────────────

  /// Get attendance records for a class with session and subject info.
  /// Consolidated sessions reference to avoid duplicate table alias errors.
  static Future<List<Map<String, dynamic>>> getClassAttendanceReport(
    String classId, {
    String? studentId,
    List<String>? subjectIds,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var studentsQuery = client
          .from('users')
          .select('id, name, email')
          .eq('class_id', classId)
          .eq('role', 'student');
      if (studentId != null) {
        studentsQuery = studentsQuery.eq('id', studentId);
      }
      final studentsData = await studentsQuery;
      final students = (studentsData as List).cast<Map<String, dynamic>>();

      if (students.isEmpty) return [];

      var sessionsQuery = client
          .from('sessions')
          .select('*, subjects(name)')
          .eq('class_id', classId);
      if (subjectIds != null && subjectIds.isNotEmpty) {
        sessionsQuery = sessionsQuery.inFilter('subject_id', subjectIds);
      }
      if (startDate != null) {
        sessionsQuery = sessionsQuery.gte('start_time', startDate.toUtc().toIso8601String());
      }
      if (endDate != null) {
        final adjustedEnd = endDate.add(const Duration(days: 1));
        sessionsQuery = sessionsQuery.lte('start_time', adjustedEnd.toUtc().toIso8601String());
      }
      final sessionsData = await sessionsQuery.order('start_time');
      final sessions = (sessionsData as List).cast<Map<String, dynamic>>();

      if (sessions.isEmpty) return [];

      var attendanceQuery = client
          .from('attendance')
          .select('''
            *,
            sessions!inner(class_id, subject_id, start_time, subjects(name)),
            users!inner(name, email)
          ''')
          .eq('sessions.class_id', classId);

      if (studentId != null) {
        attendanceQuery = attendanceQuery.eq('student_id', studentId);
      }
      if (subjectIds != null && subjectIds.isNotEmpty) {
        attendanceQuery = attendanceQuery.inFilter('sessions.subject_id', subjectIds);
      }
      if (startDate != null) {
        attendanceQuery = attendanceQuery.gte('sessions.start_time', startDate.toUtc().toIso8601String());
      }
      if (endDate != null) {
        final adjustedEnd = endDate.add(const Duration(days: 1));
        attendanceQuery = attendanceQuery.lte('sessions.start_time', adjustedEnd.toUtc().toIso8601String());
      }

      final attendanceData = await attendanceQuery;
      final attendanceList = (attendanceData as List).cast<Map<String, dynamic>>();

      final attendanceMap = {
        for (var att in attendanceList)
          "${att['session_id']}_${att['student_id']}": att
      };

      final merged = <Map<String, dynamic>>[];
      for (var session in sessions) {
        final sessionId = session['id'] as String;
        for (var student in students) {
          final studentId = student['id'] as String;
          final key = "${sessionId}_$studentId";
          if (attendanceMap.containsKey(key)) {
            merged.add(attendanceMap[key]!);
          } else {
            merged.add({
              'id': '',
              'student_id': studentId,
              'session_id': sessionId,
              'timestamp': session['start_time'],
              'status': 'absent',
              'sessions': {
                'class_id': classId,
                'subject_id': session['subject_id'],
                'subjects': {
                  'name': session['subjects']?['name'] ?? 'Unknown',
                }
              },
              'users': {
                'name': student['name'],
                'email': student['email'],
              }
            });
          }
        }
      }

      // Sort by timestamp descending
      merged.sort((a, b) {
        final tsA = DateTime.tryParse(a['timestamp'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        final tsB = DateTime.tryParse(b['timestamp'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        return tsB.compareTo(tsA);
      });

      return merged;
    } catch (e) {
      debugPrint('[Admin] Failed to get class report: $e');
      return [];
    }
  }

  static Future<List<AttendanceModel>> getStudentAttendanceReport(
    String studentId,
  ) async {
    return getStudentAttendanceHistory(studentId);
  }
}
