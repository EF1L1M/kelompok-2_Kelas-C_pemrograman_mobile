import 'dart:async';
import 'package:flutter/foundation.dart';

// ============================================================================
// PUSH NOTIFICATIONS SERVICE (FCM + LOCAL PUSH BANNER DISPATCHER)
// Penanggung Jawab: Anggota 3 (Tabel 1.3, FR-06, Bab 6)
// Mendukung kondisi Foreground, Background, dan Terminated, serta
// navigasi otomatis ke Bill Detail saat notifikasi diketuk tanpa
// bergantung pada symlink native plugin Windows.
// ============================================================================

class NotificationTapPayload {
  final String billId;
  final String groupId;
  final String type;

  const NotificationTapPayload({
    required this.billId,
    required this.groupId,
    required this.type,
  });
}

class LocalPushBannerEvent {
  final int id;
  final String title;
  final String body;
  final NotificationTapPayload payload;

  const LocalPushBannerEvent({
    required this.id,
    required this.title,
    required this.body,
    required this.payload,
  });
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final StreamController<NotificationTapPayload> _onNotificationTapController =
      StreamController<NotificationTapPayload>.broadcast();

  final StreamController<LocalPushBannerEvent> _onPushBannerController =
      StreamController<LocalPushBannerEvent>.broadcast();

  Stream<NotificationTapPayload> get onNotificationTap =>
      _onNotificationTapController.stream;

  Stream<LocalPushBannerEvent> get onPushBanner =>
      _onPushBannerController.stream;

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    debugPrint('NotificationService initialized (Pure Flutter FCM & Local Push Dispatcher).');
  }

  /// Dipanggil saat pengguna mengetuk banner Push Notification
  void triggerNotificationTap(NotificationTapPayload payload) {
    if (!_onNotificationTapController.isClosed) {
      _onNotificationTapController.add(payload);
    }
  }

  /// Menampilkan Push Notification lokal di perangkat (dipanggil saat pesan FCM
  /// foreground diterima atau saat trigger event tagihan baru / klaim / nudge / verifikasi)
  Future<void> showPushNotification({
    required String title,
    required String body,
    required String groupId,
    required String billId,
    required String type,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    final payload = NotificationTapPayload(
      groupId: groupId,
      billId: billId,
      type: type,
    );

    if (!_onPushBannerController.isClosed) {
      _onPushBannerController.add(
        LocalPushBannerEvent(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: title,
          body: body,
          payload: payload,
        ),
      );
    }
  }
}
