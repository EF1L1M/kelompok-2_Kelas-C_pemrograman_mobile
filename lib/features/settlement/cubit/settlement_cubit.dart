import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/exceptions/auth_exception.dart';
import '../../../repositories/bill_settlement_repository.dart';

class SettlementViewState {
  final RichBillDetail? detail;
  final bool isLoading;
  final String? actionMessage;
  final bool isError;

  const SettlementViewState({
    this.detail,
    this.isLoading = true,
    this.actionMessage,
    this.isError = false,
  });

  SettlementViewState copyWith({
    RichBillDetail? detail,
    bool? isLoading,
    String? actionMessage,
    bool? isError,
  }) =>
      SettlementViewState(
        detail: detail ?? this.detail,
        isLoading: isLoading ?? this.isLoading,
        actionMessage: actionMessage,
        isError: isError ?? false,
      );
}

class SettlementCubit extends Cubit<SettlementViewState> {
  final BillSettlementRepository _repository;
  StreamSubscription<RichBillDetail?>? _billSub;

  SettlementCubit(this._repository) : super(const SettlementViewState());

  void watchBill(String billId) {
    _billSub?.cancel();
    emit(state.copyWith(isLoading: true));
    _billSub = _repository.watchRichBillDetail(billId).listen((detail) {
      emit(
        SettlementViewState(
          detail: detail,
          isLoading: false,
        ),
      );
    });
  }

  /// Peserta menandai bagiannya "Sudah Bayar" (menunggu verifikasi pembuat tagihan)
  Future<void> markAsPaidPending({
    required String billId,
    required String debtorUid,
  }) async {
    try {
      await _repository.markAsPaidPending(
        billId: billId,
        debtorUid: debtorUid,
      );
      emit(
        state.copyWith(
          actionMessage:
              'Konfirmasi pembayaran berhasil dikirim dan menunggu verifikasi pembuat tagihan.',
        ),
      );
    } on AppAuthException catch (e) {
      emit(state.copyWith(actionMessage: e.message, isError: true));
    }
  }

  /// Pembuat tagihan memverifikasi (lunas) atau menolak klaim pembayaran
  Future<void> verifyOrReject({
    required String billId,
    required String requesterUid,
    required String debtorUid,
    required bool isApproved,
  }) async {
    try {
      await _repository.verifyOrRejectClaim(
        billId: billId,
        requesterUid: requesterUid,
        debtorUid: debtorUid,
        isApproved: isApproved,
      );
      emit(
        state.copyWith(
          actionMessage: isApproved
              ? 'Pembayaran berhasil diverifikasi lunas!'
              : 'Konfirmasi pembayaran ditolak. Notifikasi telah dikirim ke anggota terkait.',
        ),
      );
    } on AppAuthException catch (e) {
      emit(state.copyWith(actionMessage: e.message, isError: true));
    }
  }

  /// Peserta mengulang konfirmasi pembayaran
  Future<void> resetRejectedToUnpaid({
    required String billId,
    required String debtorUid,
  }) async {
    await _repository.resetRejectedToUnpaid(
      billId: billId,
      debtorUid: debtorUid,
    );
    emit(
      state.copyWith(
        actionMessage:
            'Status pembayaran direset. Silakan kirim konfirmasi ulang setelah melakukan pembayaran.',
      ),
    );
  }

  /// Pembuat tagihan mengirim pengingat pembayaran ke peserta
  Future<void> sendReminderNudge({
    required String billId,
    required String requesterUid,
    required String targetDebtorUid,
  }) async {
    try {
      await _repository.sendPaymentReminderNudge(
        billId: billId,
        requesterUid: requesterUid,
        targetDebtorUid: targetDebtorUid,
      );
      emit(
        state.copyWith(
          actionMessage: 'Pengingat pembayaran berhasil dikirim ke peserta.',
        ),
      );
    } on AppAuthException catch (e) {
      emit(state.copyWith(actionMessage: e.message, isError: true));
    }
  }

  @override
  Future<void> close() {
    _billSub?.cancel();
    return super.close();
  }
}
