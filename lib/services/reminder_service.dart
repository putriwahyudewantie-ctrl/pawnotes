import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/note_model.dart';

class ReminderService {
  ReminderService._();

  static final ReminderService instance = ReminderService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  Future<void>? _initialization;
  bool? _permissionGranted;

  bool get isSupported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<String?> syncReminder(Note note) async {
    if (note.reminderDate == null) {
      if (isSupported && _initialization != null) {
        await _ensureInitialized();
        await _notifications.cancel(_notificationId(note.id));
      }
      return null;
    }
    if (!isSupported) {
      return 'Pengingat hanya tersedia di aplikasi Android dan iOS.';
    }
    await _ensureInitialized();

    final reminderDate = note.reminderDate!;
    if (!reminderDate.isAfter(DateTime.now())) {
      return 'Waktu pengingat sudah lewat dan tidak dapat dijadwalkan.';
    }
    if (!await _requestPermission()) {
      return 'Izin notifikasi belum diberikan. Aktifkan di pengaturan perangkat.';
    }

    await _notifications.zonedSchedule(
      _notificationId(note.id),
      note.isPrivate ? 'Pengingat catatan pribadi' : note.title,
      note.isPrivate
          ? 'Buka PawNotes untuk melihat catatan pribadi.'
          : 'Saatnya membuka catatan di PawNotes.',
      tz.TZDateTime.from(reminderDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'pawnotes_reminders',
          'Pengingat PawNotes',
          channelDescription: 'Pengingat untuk catatan PawNotes',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
    return null;
  }

  Future<void> cancelReminder(String noteId) async {
    if (!isSupported) return;
    await _ensureInitialized();
    await _notifications.cancel(_notificationId(noteId));
  }

  Future<void> _ensureInitialized() async {
    final initialized = _initialization;
    if (initialized != null) {
      await initialized;
      return;
    }

    final initialization = _initialize();
    _initialization = initialization;
    try {
      await initialization;
    } catch (_) {
      _initialization = null;
      rethrow;
    }
  }

  Future<void> _initialize() async {
    tz_data.initializeTimeZones();
    final timezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezone.identifier));
    await _notifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
  }

  Future<bool> _requestPermission() async {
    if (Platform.isAndroid) {
      final implementation = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (_permissionGranted == true) return true;
      if (_permissionGranted == false) {
        _permissionGranted = await implementation?.areNotificationsEnabled();
        return _permissionGranted ?? false;
      }
      _permissionGranted =
          await implementation?.requestNotificationsPermission() ?? false;
    } else {
      if (_permissionGranted != null) return _permissionGranted!;
      _permissionGranted =
          await _notifications
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    return _permissionGranted!;
  }

  int _notificationId(String value) {
    var hash = 0;
    for (final codeUnit in value.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7fffffff;
    }
    return hash;
  }
}
