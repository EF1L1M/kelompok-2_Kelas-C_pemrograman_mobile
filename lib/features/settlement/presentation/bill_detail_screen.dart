import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/exceptions/auth_exception.dart';
import '../../../core/extensions/format_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/patungin_patterns.dart';
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
  bool _isGroupAdmin = false;

  @override
  void initState() {
    super.initState();
    _settlementCubit =
        SettlementCubit(context.read<BillSettlementRepository>())
          ..watchBill(
            groupId: widget.groupId,
            billId: widget.billId,
          );
    _loadGroupRole();
  }

  Future<void> _loadGroupRole() async {
    final uid = context.read<AuthCubit>().currentUser?.uid;
    if (uid == null) return;
    final role = await context
        .read<GroupRepository>()
        .getUserRoleInGroup(widget.groupId, uid);
    if (mounted) {
      setState(() => _isGroupAdmin = role == GroupRole.admin);
    }
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
              ),
            );
          }
        },
        builder: (context, state) {
          final detail = state.detail;
          if (state.isLoading || detail == null) {
            return Scaffold(
              backgroundColor: AppTheme.warmCream,
              appBar: AppBar(title: const Text('Struk Tagihan')),
              body: const Center(child: CircularProgressIndicator()),
            );
          }

          final bill = detail.bill;
          final bool isBillCreator = bill.creatorUid == currentUser.uid;
          final bool isGroupAdmin = _isGroupAdmin;

          final ParticipantWithProfile? myParticipant = detail.participants
              .where((p) => p.user.uid == currentUser.uid)
              .firstOrNull;

          return Scaffold(
            backgroundColor: AppTheme.warmCream,
            appBar: AppBar(
              title: const Text('Struk & Pelunasan'),
              actions: [
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
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 44),
              children: [
                // 1. Struk Fisik Bergerigi Sungguhan + Progress Ring Melingkar
                _buildScallopedReceiptHeader(detail),
                const SizedBox(height: 22),

                // 2. Pita Aksi Organik sesuai Peran (Penalang / Peserta)
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
                const SizedBox(height: 24),

                // 3. Daftar Peserta bergaya Ledger Terbuka (tanpa kotak berulang)
                _buildParticipantsLedger(
                  context,
                  detail: detail,
                  isBillCreator: isBillCreator,
                  currentUid: currentUser.uid,
                ),
                const SizedBox(height: 24),

                // 4. Potongan Struk Daftar Item Pesanan
                _buildReceiptItemsSlip(detail),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildScallopedReceiptHeader(RichBillDetail detail) {
    final bill = detail.bill;
    final isSettled = bill.status == BillStatus.settled;
    final totalParticipants = detail.participants.length;
    final paidParticipants = detail.paidCount;
    final progress =
        totalParticipants > 0 ? paidParticipants / totalParticipants : 1.0;
    final stampColor = isSettled ? AppTheme.statusPaid : AppTheme.statusPending;

    return ScallopedReceiptSurface(
      topEdge: true,
      bottomEdge: true,
      notchYFraction: 0.48,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkStampBadge(
                      text: bill.status.label,
                      color: stampColor,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      bill.title,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: AppTheme.darkSlate,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ditalangi ${detail.creator.fullName} · ${bill.createdAt.toIndoDate()}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppTheme.mutedInk,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                children: [
                  CircularProgressRing(
                    progress: progress,
                    size: 62,
                    color: isSettled
                        ? AppTheme.statusPaid
                        : AppTheme.primaryEmerald,
                    centerText: '$paidParticipants/$totalParticipants',
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Lunas',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.mutedInk,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (bill.currencyCode != 'IDR') ...[
            const SizedBox(height: 12),
            DashedCouponChip(
              icon: Icons.currency_exchange_rounded,
              color: const Color(0xFF1F638C),
              label:
                  '1 ${bill.currencyCode} = ${bill.exchangeRate.toRupiah()} (${bill.rateDate.toIndoDate()})',
            ),
          ],
          const SizedBox(height: 18),
          const DashedDivider(),
          const SizedBox(height: 16),
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
          const SizedBox(height: 10),
          const DashedDivider(),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TOTAL STRUK',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 0.8,
                  color: AppTheme.mutedInk,
                ),
              ),
              Text(
                bill.grandTotalIdr.toRupiah(),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  letterSpacing: -0.6,
                  color: AppTheme.primaryEmerald,
                ),
              ),
            ],
          ),
        ],
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

    final Color tintBg = switch (status) {
      PaymentStatus.paid => AppTheme.sageWash,
      PaymentStatus.pending => AppTheme.butterWash,
      PaymentStatus.unpaid || PaymentStatus.rejected => AppTheme.apricotWash,
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tintBg,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(14),
          bottomLeft: Radius.circular(14),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Bagian Kamu',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: AppTheme.darkSlate,
                ),
              ),
              _StatusBadge(status: status),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            part.totalDueIdr.toRupiah(),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
              color: AppTheme.darkSlate,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Pesanan ${part.itemsSubtotalIdr.toRupiah()} + Pajak ${part.taxShareIdr.toRupiah()} + Layanan ${part.serviceShareIdr.toRupiah()} - Diskon ${part.discountShareIdr.toRupiah()}',
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.mutedInk,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          switch (status) {
            PaymentStatus.unpaid => SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.terracotta,
                  ),
                  onPressed: () => _showPaymentConfirmationDialog(
                    context,
                    detail: detail,
                    debtorUid: part.debtorUid,
                    amountIdr: part.totalDueIdr,
                  ),
                  icon: const Icon(Icons.payments_rounded),
                  label: const Text('Sudah Transfer? Konfirmasi'),
                ),
              ),
            PaymentStatus.pending => Row(
                children: [
                  const Icon(
                    Icons.hourglass_top_rounded,
                    color: AppTheme.honeyAmber,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Menunggu ${detail.creator.fullName} mengecek transferanmu.',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF7A4F09),
                      ),
                    ),
                  ),
                ],
              ),
            PaymentStatus.rejected => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Konfirmasi pembayaran sebelumnya ditolak ${detail.creator.fullName}. Cek bukti transfer lalu kirim ulang ya.',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.statusRejected,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              _settlementCubit.resetRejectedToUnpaid(
                            groupId: widget.groupId,
                            billId: bill.billId,
                            debtorUid: part.debtorUid,
                          ),
                          child: const Text('Reset'),
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
            PaymentStatus.paid => Row(
                children: [
                  const Icon(
                    Icons.verified_rounded,
                    color: AppTheme.statusPaid,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Lunas! Sudah diverifikasi oleh ${detail.creator.fullName}.',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryEmerald,
                      ),
                    ),
                  ),
                ],
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
    String selectedMethod = 'Transfer Bank';
    final methods = ['Transfer Bank', 'QRIS', 'GoPay / OVO / DANA', 'Tunai'];

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
                'Pastikan kamu sudah membayar ${amountIdr.toRupiah()} kepada ${detail.creator.fullName}.',
                style: const TextStyle(fontSize: 13, color: AppTheme.mutedInk),
              ),
              const SizedBox(height: 14),
              const Text(
                'Metode Pembayaran:',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: methods.map((m) {
                  final isSelected = selectedMethod == m;
                  return ChoiceChip(
                    label: Text(m, style: const TextStyle(fontSize: 12)),
                    selected: isSelected,
                    selectedColor: AppTheme.sageWash,
                    onSelected: (_) => setDialogState(() => selectedMethod = m),
                  );
                }).toList(),
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
                  groupId: widget.groupId,
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: pendingClaims.isEmpty ? AppTheme.sageWash : AppTheme.butterWash,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(14),
          topRight: Radius.circular(28),
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              OrganicPebbleBadge(
                size: 40,
                color: AppTheme.paperWhite,
                child: Icon(
                  pendingClaims.isEmpty
                      ? Icons.verified_user_rounded
                      : Icons.mark_chat_unread_rounded,
                  size: 20,
                  color: pendingClaims.isEmpty
                      ? AppTheme.primaryEmerald
                      : AppTheme.honeyAmber,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pendingClaims.isEmpty
                          ? 'Kamu Penalang Tagihan Ini'
                          : '${pendingClaims.length} Konfirmasi Menunggu Dicek',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14.5,
                        color: AppTheme.darkSlate,
                      ),
                    ),
                    Text(
                      pendingClaims.isEmpty
                          ? 'Kamu bisa kirim pengingat ramah ke teman yang belum lunas di bawah.'
                          : 'Periksa transfer masuk lalu verifikasi pelunasannya.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.mutedInk,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (pendingClaims.isNotEmpty) ...[
            const SizedBox(height: 14),
            ...pendingClaims.map((claim) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.paperWhite,
                  borderRadius: BorderRadius.circular(20),
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
                              fontSize: 13.5,
                            ),
                          ),
                          Text(
                            claim.participant.totalDueIdr.toRupiah(),
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.primaryEmerald,
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.statusRejected,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                      ),
                      onPressed: () => _settlementCubit.verifyOrReject(
                        groupId: widget.groupId,
                        billId: detail.bill.billId,
                        requesterUid: creatorUid,
                        debtorUid: claim.user.uid,
                        isApproved: false,
                      ),
                      child: const Text('Tolak'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                      ),
                      onPressed: () => _settlementCubit.verifyOrReject(
                        groupId: widget.groupId,
                        billId: detail.bill.billId,
                        requesterUid: creatorUid,
                        debtorUid: claim.user.uid,
                        isApproved: true,
                      ),
                      child: const Text('Lunas'),
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

  Widget _buildParticipantsLedger(
    BuildContext context, {
    required RichBillDetail detail,
    required bool isBillCreator,
    required String currentUid,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Daftar Patungan',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 17,
                letterSpacing: -0.3,
                color: AppTheme.darkSlate,
              ),
            ),
            Text(
              '${detail.paidCount}/${detail.participants.length} sudah beres',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
                color: AppTheme.primaryEmerald,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...List.generate(detail.participants.length, (index) {
          final item = detail.participants[index];
          final part = item.participant;
          final status = part.paymentStatus;
          final isCreatorRow = item.user.uid == detail.bill.creatorUid;
          final pal = PatunginPalette.forKey(item.user.uid);
          final isLast = index == detail.participants.length - 1;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: pal.bg,
                          child: Text(
                            item.user.initials,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: pal.fg,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${item.user.fullName}${isCreatorRow ? " · Penalang" : ""}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: AppTheme.darkSlate,
                                ),
                              ),
                              Text(
                                part.totalDueIdr.toRupiah(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14.5,
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
                    Padding(
                      padding: const EdgeInsets.only(left: 52),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.assignedItems
                                .map((e) => e.item.itemName)
                                .join(' · '),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.darkSlate,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Subtotal ${part.itemsSubtotalIdr.toRupiah()} · +Pajak ${part.taxShareIdr.toRupiah()} · +Layanan ${part.serviceShareIdr.toRupiah()} · -Diskon ${part.discountShareIdr.toRupiah()}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppTheme.mutedInk,
                            ),
                          ),
                          if (isBillCreator && !isCreatorRow) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (status == PaymentStatus.unpaid ||
                                    status == PaymentStatus.rejected)
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 7,
                                      ),
                                    ),
                                    onPressed: () =>
                                        _settlementCubit.sendReminderNudge(
                                      groupId: widget.groupId,
                                      billId: detail.bill.billId,
                                      requesterUid: currentUid,
                                      targetDebtorUid: item.user.uid,
                                    ),
                                    icon: const Icon(
                                      Icons.notifications_active_outlined,
                                      size: 16,
                                    ),
                                    label: const Text(
                                      'Ingatkan Ramah',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                if (status == PaymentStatus.pending) ...[
                                  OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.statusRejected,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 7,
                                      ),
                                    ),
                                    onPressed: () =>
                                        _settlementCubit.verifyOrReject(
                                      groupId: widget.groupId,
                                      billId: detail.bill.billId,
                                      requesterUid: currentUid,
                                      debtorUid: item.user.uid,
                                      isApproved: false,
                                    ),
                                    child: const Text('Tolak'),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 7,
                                      ),
                                    ),
                                    onPressed: () =>
                                        _settlementCubit.verifyOrReject(
                                      groupId: widget.groupId,
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
                    ),
                  ],
                ),
              ),
              if (!isLast) const DashedDivider(),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildReceiptItemsSlip(RichBillDetail detail) {
    final bill = detail.bill;
    return ScallopedReceiptSurface(
      topEdge: false,
      bottomEdge: true,
      color: AppTheme.warmSand,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CATATAN ITEM PESANAN',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 1.0,
              color: AppTheme.mutedInk,
            ),
          ),
          const SizedBox(height: 12),
          const DashedDivider(),
          const SizedBox(height: 12),
          ...detail.items.map((item) {
            final assignees = detail.assignmentsByItem[item.itemId] ?? const [];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
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
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                            color: AppTheme.darkSlate,
                          ),
                        ),
                        Text(
                          'Dibagi ${assignees.length} orang · @ ${item.unitPrice.toCurrency(bill.currencyCode)}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppTheme.mutedInk,
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
                      color: AppTheme.darkSlate,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
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
            groupId: widget.groupId,
            billId: billId,
            requesterUid: requesterUid,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tagihan berhasil dihapus.')),
        );
        context.pop();
      }
    } on AppAuthException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AppTheme.statusRejected,
          ),
        );
      }
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final PaymentStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final Color color = switch (status) {
      PaymentStatus.unpaid => AppTheme.statusUnpaid,
      PaymentStatus.pending => AppTheme.honeyAmber,
      PaymentStatus.paid => AppTheme.statusPaid,
      PaymentStatus.rejected => AppTheme.statusRejected,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.shortLabel,
        style: TextStyle(
          fontSize: 11.5,
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
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppTheme.mutedInk),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.darkSlate,
            ),
          ),
        ],
      ),
    );
  }
}
