import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/exceptions/auth_exception.dart';
import '../../../core/extensions/format_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/erd_models.dart';
import '../../../repositories/bill_settlement_repository.dart';
import '../../../repositories/group_repository.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../cubit/settlement_cubit.dart';

class BillDetailScreen extends StatefulWidget {
  final String groupId;
  final String billId;

  const BillDetailScreen({
    super.key,
    required this.groupId,
    required this.billId,
  });

  @override
  State<BillDetailScreen> createState() => _BillDetailScreenState();
}

class _BillDetailScreenState extends State<BillDetailScreen> {
  late final SettlementCubit _settlementCubit;

  @override
  void initState() {
    super.initState();
    _settlementCubit =
        SettlementCubit(context.read<BillSettlementRepository>())
          ..watchBill(widget.billId);
  }

  @override
  void dispose() {
    _settlementCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthCubit>().currentUser;
    if (currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return BlocProvider.value(
      value: _settlementCubit,
      child: BlocConsumer<SettlementCubit, SettlementViewState>(
        listener: (context, state) {
          if (state.actionMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.actionMessage!),
                backgroundColor: state.isError
                    ? AppTheme.statusRejected
                    : AppTheme.primaryEmerald,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (context, state) {
          final detail = state.detail;
          if (state.isLoading || detail == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Rincian Tagihan')),
              body: const Center(child: CircularProgressIndicator()),
            );
          }

          final bill = detail.bill;
          final bool isBillCreator = bill.creatorUid == currentUser.uid;
          final GroupRole? groupRole = context
              .read<GroupRepository>()
              .getUserRoleInGroup(widget.groupId, currentUser.uid);
          final bool isGroupAdmin = groupRole == GroupRole.admin;

          final ParticipantWithProfile? myParticipant = detail.participants
              .where((p) => p.user.uid == currentUser.uid)
              .firstOrNull;

          return Scaffold(
            appBar: AppBar(
              title: const Text('Rincian & Pelunasan'),
              actions: [
                IconButton(
                  tooltip: 'Beralih Akun Peserta',
                  icon: const Icon(Icons.swap_horiz_rounded),
                  onPressed: () => _showSwitchParticipantSheet(
                    context,
                    detail: detail,
                    activeUid: currentUser.uid,
                  ),
                ),
                if (isBillCreator)
                  IconButton(
                    tooltip: 'Edit Tagihan',
                    icon: const Icon(Icons.edit_note_rounded),
                    onPressed: () => context.push(
                      '/groups/${widget.groupId}/create-bill?editBillId=${bill.billId}',
                    ),
                  ),
                if (isBillCreator || isGroupAdmin)
                  IconButton(
                    tooltip: 'Hapus Tagihan',
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppTheme.statusRejected,
                    ),
                    onPressed: () => _handleDeleteBill(
                      context,
                      billId: bill.billId,
                      requesterUid: currentUser.uid,
                    ),
                  ),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              children: [
                // 1. Kartu Header Tagihan & Progress Pelunasan
                _buildBillHeaderCard(detail),
                const SizedBox(height: 16),

                // 2. Panel Aksi Pembayaran / Verifikasi sesuai Peran Pengguna
                if (isBillCreator)
                  _buildCreatorVerificationPanel(
                    context,
                    detail: detail,
                    creatorUid: currentUser.uid,
                  )
                else if (myParticipant != null)
                  _buildDebtorActionPanel(
                    context,
                    detail: detail,
                    myParticipant: myParticipant,
                  ),
                const SizedBox(height: 16),

                // 3. Daftar Seluruh Peserta & Status Pelunasan
                _buildAllParticipantsStatusCard(
                  context,
                  detail: detail,
                  isBillCreator: isBillCreator,
                  currentUid: currentUser.uid,
                ),
                const SizedBox(height: 16),

                // 4. Rincian Pesanan pada Struk
                _buildReceiptItemsBreakdownCard(detail),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBillHeaderCard(RichBillDetail detail) {
    final bill = detail.bill;
    final isSettled = bill.status == BillStatus.settled;
    final totalParticipants = detail.participants.length;
    final paidParticipants = detail.paidCount;
    final progress =
        totalParticipants > 0 ? paidParticipants / totalParticipants : 1.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isSettled
                        ? AppTheme.statusPaid.withValues(alpha: 0.15)
                        : AppTheme.statusPending.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    bill.status.label,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: isSettled
                          ? AppTheme.statusPaid
                          : const Color(0xFFB45309),
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  bill.createdAt.toIndoDateTime(),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              bill.title,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Ditalangi oleh: ${detail.creator.fullName}',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF475569),
                fontWeight: FontWeight.w600,
              ),
            ),
            if (bill.currencyCode != 'IDR') ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Kurs Terkunci: 1 ${bill.currencyCode} = ${bill.exchangeRate.toRupiah()} (${bill.rateDate.toIndoDate()})',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0369A1),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Progress Pelunasan ($paidParticipants/$totalParticipants Lunas)',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569),
                  ),
                ),
                Text(
                  '${(progress * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryEmerald,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 7,
                backgroundColor: const Color(0xFFE2E8F0),
                color: AppTheme.primaryEmerald,
              ),
            ),
            const Divider(height: 24),
            _SummaryRow(
              label: 'Subtotal Pesanan',
              value: bill.subtotalIdr.toRupiah(),
            ),
            _SummaryRow(
              label: 'Pajak Restoran (PB1)',
              value: '+ ${bill.taxAmountIdr.toRupiah()}',
            ),
            _SummaryRow(
              label: 'Biaya Layanan',
              value: '+ ${bill.serviceAmountIdr.toRupiah()}',
            ),
            _SummaryRow(
              label: 'Diskon / Promo',
              value: '- ${bill.discountAmountIdr.toRupiah()}',
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Tagihan',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15.5,
                  ),
                ),
                Text(
                  bill.grandTotalIdr.toRupiah(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: AppTheme.primaryEmerald,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebtorActionPanel(
    BuildContext context, {
    required RichBillDetail detail,
    required ParticipantWithProfile myParticipant,
  }) {
    final bill = detail.bill;
    final part = myParticipant.participant;
    final status = part.paymentStatus;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _statusColor(status).withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Bagian Tagihan Anda',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              _StatusBadge(status: status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            part.totalDueIdr.toRupiah(),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppTheme.darkSlate,
            ),
          ),
          Text(
            'Rincian: Pesanan ${part.itemsSubtotalIdr.toRupiah()} + Pajak ${part.taxShareIdr.toRupiah()} + Layanan ${part.serviceShareIdr.toRupiah()} - Diskon ${part.discountShareIdr.toRupiah()}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 14),
          switch (status) {
            PaymentStatus.unpaid => SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showPaymentConfirmationDialog(
                    context,
                    detail: detail,
                    debtorUid: part.debtorUid,
                    amountIdr: part.totalDueIdr,
                  ),
                  icon: const Icon(Icons.payments_rounded),
                  label: const Text('Konfirmasi Sudah Bayar'),
                ),
              ),
            PaymentStatus.pending => Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.hourglass_top_rounded,
                      color: Color(0xFFD97706),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Menunggu verifikasi penerimaan dana dari ${detail.creator.fullName}.',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            PaymentStatus.rejected => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Konfirmasi pembayaran sebelumnya belum dapat diverifikasi. Silakan periksa kembali bukti transfer Anda dan kirim konfirmasi ulang.',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.statusRejected,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              _settlementCubit.resetRejectedToUnpaid(
                            billId: bill.billId,
                            debtorUid: part.debtorUid,
                          ),
                          child: const Text('Reset Status'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _showPaymentConfirmationDialog(
                            context,
                            detail: detail,
                            debtorUid: part.debtorUid,
                            amountIdr: part.totalDueIdr,
                          ),
                          child: const Text('Konfirmasi Ulang'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            PaymentStatus.paid => Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: AppTheme.statusPaid,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Pembayaran Anda telah diverifikasi lunas.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF065F46),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          },
        ],
      ),
    );
  }

  void _showPaymentConfirmationDialog(
    BuildContext context, {
    required RichBillDetail detail,
    required String debtorUid,
    required double amountIdr,
  }) {
    String selectedMethod = 'Transfer Bank / QRIS';
    final methods = [
      'Transfer Bank / QRIS',
      'GoPay / OVO / Dana',
      'Tunai (Cash)',
    ];

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Konfirmasi Pembayaran'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nominal dibayarkan ke ${detail.creator.fullName}:',
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 4),
              Text(
                amountIdr.toRupiah(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryEmerald,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Metode Pembayaran:',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ...methods.map(
                (m) {
                  final isSelected = selectedMethod == m;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      isSelected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      color: isSelected
                          ? AppTheme.primaryEmerald
                          : const Color(0xFF94A3B8),
                      size: 20,
                    ),
                    title: Text(
                      m,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    onTap: () => setDialogState(() => selectedMethod = m),
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _settlementCubit.markAsPaidPending(
                  billId: detail.bill.billId,
                  debtorUid: debtorUid,
                );
              },
              child: const Text('Kirim Konfirmasi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreatorVerificationPanel(
    BuildContext context, {
    required RichBillDetail detail,
    required String creatorUid,
  }) {
    final pendingClaims = detail.participants
        .where((p) => p.participant.paymentStatus == PaymentStatus.pending)
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDD6FE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.verified_user_rounded, color: Color(0xFF6D28D9)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Kelola Pelunasan Tagihan',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Color(0xFF4C1D95),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            pendingClaims.isEmpty
                ? 'Belum ada konfirmasi pembayaran baru yang menunggu verifikasi. Anda dapat mengirimkan pengingat pada peserta yang belum membayar di bawah.'
                : 'Terdapat ${pendingClaims.length} konfirmasi pembayaran yang menunggu verifikasi Anda:',
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF5B21B6)),
          ),
          if (pendingClaims.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...pendingClaims.map((claim) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            claim.user.fullName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'Nominal: ${claim.participant.totalDueIdr.toRupiah()}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppTheme.primaryEmerald,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.statusRejected,
                      ),
                      onPressed: () => _settlementCubit.verifyOrReject(
                        billId: detail.bill.billId,
                        requesterUid: creatorUid,
                        debtorUid: claim.user.uid,
                        isApproved: false,
                      ),
                      child: const Text('Tolak'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _settlementCubit.verifyOrReject(
                        billId: detail.bill.billId,
                        requesterUid: creatorUid,
                        debtorUid: claim.user.uid,
                        isApproved: true,
                      ),
                      child: const Text('Verifikasi Lunas'),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildAllParticipantsStatusCard(
    BuildContext context, {
    required RichBillDetail detail,
    required bool isBillCreator,
    required String currentUid,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Status Pembayaran Peserta',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                Text(
                  '${detail.paidCount}/${detail.participants.length} Lunas',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                    color: AppTheme.primaryEmerald,
                  ),
                ),
              ],
            ),
            const Divider(height: 22),
            ...detail.participants.map((item) {
              final part = item.participant;
              final status = part.paymentStatus;
              final isCreatorRow = item.user.uid == detail.bill.creatorUid;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 17,
                          backgroundColor:
                              AppTheme.primaryEmerald.withValues(alpha: 0.14),
                          child: Text(
                            item.user.initials,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primaryEmerald,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${item.user.fullName}${isCreatorRow ? " (Penalang)" : ""}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13.5,
                                ),
                              ),
                              Text(
                                'Bagian: ${part.totalDueIdr.toRupiah()}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: AppTheme.primaryEmerald,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _StatusBadge(status: status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Pesanan: ${item.assignedItems.map((e) => e.item.itemName).join(", ")}\n'
                      'Subtotal ${part.itemsSubtotalIdr.toRupiah()} · +Pajak ${part.taxShareIdr.toRupiah()} · +Layanan ${part.serviceShareIdr.toRupiah()} · -Diskon ${part.discountShareIdr.toRupiah()}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    if (isBillCreator && !isCreatorRow) ...[
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (status == PaymentStatus.unpaid ||
                              status == PaymentStatus.rejected)
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                              ),
                              onPressed: () =>
                                  _settlementCubit.sendReminderNudge(
                                billId: detail.bill.billId,
                                requesterUid: currentUid,
                                targetDebtorUid: item.user.uid,
                              ),
                              icon: const Icon(
                                Icons.notifications_active_outlined,
                                size: 16,
                              ),
                              label: const Text(
                                'Kirim Pengingat',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          if (status == PaymentStatus.pending) ...[
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.statusRejected,
                              ),
                              onPressed: () =>
                                  _settlementCubit.verifyOrReject(
                                billId: detail.bill.billId,
                                requesterUid: currentUid,
                                debtorUid: item.user.uid,
                                isApproved: false,
                              ),
                              child: const Text('Tolak'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () =>
                                  _settlementCubit.verifyOrReject(
                                billId: detail.bill.billId,
                                requesterUid: currentUid,
                                debtorUid: item.user.uid,
                                isApproved: true,
                              ),
                              child: const Text('Terima Lunas'),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptItemsBreakdownCard(RichBillDetail detail) {
    final bill = detail.bill;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daftar Pesanan Struk',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const Divider(height: 20),
            ...detail.items.map((item) {
              final assignees =
                  detail.assignmentsByItem[item.itemId] ?? const [];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item.qty}x ${item.itemName}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                            ),
                          ),
                          Text(
                            'Dibagi ${assignees.length} orang · @ ${item.unitPrice.toCurrency(bill.currencyCode)}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      item.priceIdr.toRupiah(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showSwitchParticipantSheet(
    BuildContext context, {
    required RichBillDetail detail,
    required String activeUid,
  }) {
    final authCubit = context.read<AuthCubit>();

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Beralih Akun Peserta',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'Pilih peserta untuk melihat tampilan tagihan dari sisi akun tersebut:',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            ...detail.participants.map((p) {
              final isMe = p.user.uid == activeUid;
              final isCreator = p.user.uid == detail.bill.creatorUid;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: isMe
                      ? AppTheme.primaryEmerald
                      : const Color(0xFFE2E8F0),
                  child: Text(
                    p.user.initials,
                    style: TextStyle(
                      color: isMe ? Colors.white : AppTheme.darkSlate,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                title: Text(
                  p.user.fullName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  isCreator
                      ? 'Penalang Tagihan'
                      : 'Peserta · ${p.participant.paymentStatus.label}',
                ),
                trailing: isMe
                    ? const Icon(
                        Icons.check_circle_rounded,
                        color: AppTheme.primaryEmerald,
                      )
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  if (!isMe) {
                    authCubit.switchDemoUser(p.user.uid);
                  }
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _handleDeleteBill(
    BuildContext context, {
    required String billId,
    required String requesterUid,
  }) async {
    try {
      await context.read<BillSettlementRepository>().deleteBill(
            billId: billId,
            requesterUid: requesterUid,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tagihan berhasil dihapus.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      }
    } on AppAuthException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AppTheme.statusRejected,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Color _statusColor(PaymentStatus status) => switch (status) {
        PaymentStatus.unpaid => AppTheme.statusUnpaid,
        PaymentStatus.pending => AppTheme.statusPending,
        PaymentStatus.paid => AppTheme.statusPaid,
        PaymentStatus.rejected => AppTheme.statusRejected,
      };
}

class _StatusBadge extends StatelessWidget {
  final PaymentStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final Color color = switch (status) {
      PaymentStatus.unpaid => AppTheme.statusUnpaid,
      PaymentStatus.pending => const Color(0xFFD97706),
      PaymentStatus.paid => AppTheme.statusPaid,
      PaymentStatus.rejected => AppTheme.statusRejected,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.shortLabel.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
