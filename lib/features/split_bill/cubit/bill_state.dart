import '../../../models/erd_models.dart';

// ============================================================================
// ADVANCE DART: SEALED CLASS BillState (DART 3 PATTERN MATCHING)
// Penanggung Jawab: Anggota 2 (Tabel 1.3 & Bab 2.9)
// Digunakan untuk switch expression reaktif pada layar pembuatan & pembagian tagihan.
// ============================================================================

class DraftBillItem {
  final String id;
  final String name;
  final int qty;
  final double unitPriceOrigin; // Harga satuan dalam mata uang asal (IDR/USD/SGD/dll.)
  final Set<String> assignedMemberUids; // Anggota yang dicentang menanggung item ini

  const DraftBillItem({
    required this.id,
    required this.name,
    required this.qty,
    required this.unitPriceOrigin,
    required this.assignedMemberUids,
  });

  double get totalOrigin => qty * unitPriceOrigin;
  double totalIdr(double rate) => (totalOrigin * rate).roundToDouble();

  DraftBillItem copyWith({
    String? name,
    int? qty,
    double? unitPriceOrigin,
    Set<String>? assignedMemberUids,
  }) =>
      DraftBillItem(
        id: id,
        name: name ?? this.name,
        qty: qty ?? this.qty,
        unitPriceOrigin: unitPriceOrigin ?? this.unitPriceOrigin,
        assignedMemberUids: assignedMemberUids ?? this.assignedMemberUids,
      );
}

class ComputedParticipantSplit {
  final AppUser user;
  final double itemsSubtotalIdr;
  final double taxShareIdr;
  final double serviceShareIdr;
  final double discountShareIdr;
  final double totalDueIdr; // Setelah pembulatan + koreksi selisih Rp0 (BR-03)
  final double roundingAdjustmentIdr; // Dokumentasi koreksi Rp pada subtotal terbesar

  const ComputedParticipantSplit({
    required this.user,
    required this.itemsSubtotalIdr,
    required this.taxShareIdr,
    required this.serviceShareIdr,
    required this.discountShareIdr,
    required this.totalDueIdr,
    this.roundingAdjustmentIdr = 0,
  });
}

sealed class BillState {
  const BillState();
}

final class BillInitial extends BillState {
  const BillInitial();
}

final class BillLoading extends BillState {
  final String loadingStep;
  const BillLoading(this.loadingStep);
}

final class BillLoaded extends BillState {
  final String title;
  final String currencyCode;
  final double exchangeRate;
  final DateTime rateDate;
  final String rateSourceInfo;
  final List<DraftBillItem> items;
  final double taxOrigin;
  final double serviceOrigin;
  final double discountOrigin;
  final List<AppUser> groupMembers;
  final List<ComputedParticipantSplit> computedSplits;
  final double subtotalIdr;
  final double taxIdr;
  final double serviceIdr;
  final double discountIdr;
  final double grandTotalIdr;
  final String? ocrIsolateBadge;

  const BillLoaded({
    required this.title,
    required this.currencyCode,
    required this.exchangeRate,
    required this.rateDate,
    required this.rateSourceInfo,
    required this.items,
    required this.taxOrigin,
    required this.serviceOrigin,
    required this.discountOrigin,
    required this.groupMembers,
    required this.computedSplits,
    required this.subtotalIdr,
    required this.taxIdr,
    required this.serviceIdr,
    required this.discountIdr,
    required this.grandTotalIdr,
    this.ocrIsolateBadge,
  });

  /// Cek apakah semua item sudah memiliki minimal 1 anggota penanggung (UFD-3b)
  bool get allItemsAssigned =>
      items.isNotEmpty &&
      items.every((item) => item.assignedMemberUids.isNotEmpty);

  /// Jumlah total seluruh peserta (Harus sama dengan grandTotalIdr -> Selisih Rp0!)
  double get sumOfParticipantTotalsIdr => computedSplits.fold<double>(
        0.0,
        (sum, s) => sum + s.totalDueIdr,
      );

  double get roundingDifferenceIdr =>
      (grandTotalIdr - sumOfParticipantTotalsIdr).abs();
}

final class BillError extends BillState {
  final String errorMessage;
  final BillLoaded? previousLoadedState;

  const BillError({
    required this.errorMessage,
    this.previousLoadedState,
  });
}
