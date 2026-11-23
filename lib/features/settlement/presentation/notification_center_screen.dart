import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/extensions/format_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/erd_models.dart';
import '../../../repositories/bill_settlement_repository.dart';
import '../../auth/cubit/auth_cubit.dart';

class NotificationCenterScreen extends StatelessWidget {
  const NotificationCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthCubit>().currentUser;
    if (currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final repo = context.read<BillSettlementRepository>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikasi'),
        actions: [
          TextButton.icon(
            onPressed: () => repo.markAllNotificationsAsRead(currentUser.uid),
            icon: const Icon(Icons.done_all_rounded, size: 18),
            label: const Text('Tandai Dibaca'),
          ),
        ],
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: repo.watchUserNotifications(currentUser.uid),
        builder: (context, snapshot) {
          final list = snapshot.data ?? const [];

          if (list.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.notifications_none_rounded,
                      size: 56,
                      color: Color(0xFF94A3B8),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Belum Ada Notifikasi',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Pemberitahuan tagihan baru, pengingat pembayaran, dan konfirmasi pelunasan akan muncul di sini.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final notif = list[index];
              final iconData = _iconForType(notif.type);
              final iconColor = _colorForType(notif.type);

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  color:
                      notif.isRead ? Colors.white : const Color(0xFFF0FDF4),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: iconColor.withValues(alpha: 0.14),
                      child: Icon(iconData, color: iconColor, size: 20),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            notif.type.label,
                            style: TextStyle(
                              fontWeight: notif.isRead
                                  ? FontWeight.w700
                                  : FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Text(
                          notif.createdAt.toRelativeTime(),
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        notif.message,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                    onTap: () async {
                      await repo.markNotificationAsRead(notif.notifId);
                      if (context.mounted &&
                          notif.groupId.isNotEmpty &&
                          notif.billId.isNotEmpty) {
                        context.push(
                          '/groups/${notif.groupId}/bills/${notif.billId}',
                        );
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  IconData _iconForType(NotifType type) => switch (type) {
        NotifType.newBill => Icons.receipt_long_rounded,
        NotifType.pending => Icons.hourglass_top_rounded,
        NotifType.reminder => Icons.notifications_active_rounded,
        NotifType.verified => Icons.verified_rounded,
        NotifType.rejected => Icons.cancel_rounded,
      };

  Color _colorForType(NotifType type) => switch (type) {
        NotifType.newBill => const Color(0xFF0284C7),
        NotifType.pending => AppTheme.statusPending,
        NotifType.reminder => const Color(0xFF7C3AED),
        NotifType.verified => AppTheme.statusPaid,
        NotifType.rejected => AppTheme.statusRejected,
      };
}
