import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/extensions/format_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/patungin_patterns.dart';
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
      backgroundColor: AppTheme.warmCream,
      appBar: AppBar(
        title: const Text('Kabar Patungan'),
        actions: [
          TextButton.icon(
            onPressed: () => repo.markAllNotificationsAsRead(currentUser.uid),
            icon: const Icon(Icons.done_all_rounded, size: 18),
            label: const Text('Baca Semua'),
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
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OrganicPebbleBadge(
                      size: 88,
                      color: AppTheme.warmSand,
                      variant: 1,
                      child: Icon(
                        Icons.notifications_none_rounded,
                        size: 42,
                        color: AppTheme.mutedInk,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Masih Sepi di Sini',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: AppTheme.darkSlate,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Kabar tagihan baru, pengingat ramah dari teman, dan konfirmasi lunas akan muncul di lini masa ini.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: AppTheme.mutedInk,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 36),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final notif = list[index];
              final iconData = _iconForType(notif.type);
              final iconColor = _colorForType(notif.type);
              final isLast = index == list.length - 1;

              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Jalur timeline vertikal dengan simpul bulat organik
                    SizedBox(
                      width: 44,
                      child: Column(
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              OrganicPebbleBadge(
                                size: 40,
                                color: iconColor.withValues(alpha: 0.14),
                                variant: index,
                                child: Icon(
                                  iconData,
                                  color: iconColor,
                                  size: 20,
                                ),
                              ),
                              if (!notif.isRead)
                                Positioned(
                                  top: -2,
                                  right: -2,
                                  child: Container(
                                    width: 11,
                                    height: 11,
                                    decoration: BoxDecoration(
                                      color: AppTheme.terracotta,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppTheme.warmCream,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (!isLast)
                            Expanded(
                              child: Container(
                                width: 1.8,
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                color: AppTheme.softBorder,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Gelembung percakapan organik (bukan kotak kartu kaku)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: InkWell(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(6),
                            topRight: Radius.circular(22),
                            bottomLeft: Radius.circular(22),
                            bottomRight: Radius.circular(22),
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
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(16, 13, 16, 14),
                            decoration: BoxDecoration(
                              color: notif.isRead
                                  ? AppTheme.paperWhite
                                  : AppTheme.sageWash.withValues(alpha: 0.65),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(6),
                                topRight: Radius.circular(22),
                                bottomLeft: Radius.circular(22),
                                bottomRight: Radius.circular(22),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        notif.type.label,
                                        style: TextStyle(
                                          fontWeight: notif.isRead
                                              ? FontWeight.w700
                                              : FontWeight.w900,
                                          fontSize: 13.5,
                                          color: AppTheme.darkSlate,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      notif.createdAt.toRelativeTime(),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.mutedInk,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  notif.message,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF39423C),
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
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
        NotifType.newBill => const Color(0xFF1F638C),
        NotifType.pending => AppTheme.honeyAmber,
        NotifType.reminder => const Color(0xFF5B3FA8),
        NotifType.verified => AppTheme.statusPaid,
        NotifType.rejected => AppTheme.statusRejected,
      };
}
