import 'dart:typed_data';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/network/api_response.dart';
import '../../../core/utils/isolate_workers.dart';
import '../../../models/erd_models.dart';
import '../../../repositories/bill_settlement_repository.dart';
import '../../../repositories/open_source_api_repository.dart';
import 'bill_state.dart';

// ============================================================================
// BILL SPLIT CUBIT & PROPORTIONAL CALCULATION ENGINE
// Penanggung Jawab: Anggota 2 (Tabel 1.3, FR-03, FR-04, BR-01..BR-05, Bab 2.9)
// Menerapkan Higher-Order Functions (.fold, .where, .map) TANPA for-loop
// konvensional pada algoritma pembagian proporsional dan pembulatan Rp0.
// ============================================================================

class BillSplitCubit extends Cubit<BillState> {
  final OpenSourceApiRepository _apiRepository;
  final BillSettlementRepository _settlementRepository;

  BillSplitCubit({
    required OpenSourceApiRepository apiRepository,
    required BillSettlementRepository settlementRepository,
  })  : _apiRepository = apiRepository,
        _settlementRepository = settlementRepository,
        super(const BillInitial());

  /// Inisialisasi editor tagihan baru atau mode edit tagihan (UFD-3a & UFD-3b)
  void initializeDraft({
    required List<AppUser> members,
    RichBillDetail? existingBill,
  }) {
    final defaultMemberUids = members.map((m) => m.uid).toSet();

    if (existingBill != null) {
      final b = existingBill.bill;
      final rate = b.exchangeRate <= 0 ? 1.0 : b.exchangeRate;
      final draftItems = existingBill.items.map((item) {
        final assigned = (existingBill.assignmentsByItem[item.itemId] ?? const [])
            .map((a) => a.debtorUid)
            .toSet();
        return DraftBillItem(
          id: item.itemId,
          name: item.itemName,
          qty: item.qty,
          unitPriceOrigin: item.unitPrice,
          assignedMemberUids:
              assigned.isEmpty ? Set<String>.from(defaultMemberUids) : assigned,
        );
      }).toList();

      _recalculateAndEmit(
        title: b.title,
        currencyCode: b.currencyCode,
        exchangeRate: rate,
        rateDate: b.rateDate,
        rateSourceInfo: 'Kurs terkunci pada tagihan (${b.currencyCode})',
        items: draftItems,
        taxOrigin: b.taxAmountIdr / rate,
        serviceOrigin: b.serviceAmountIdr / rate,
        discountOrigin: b.discountAmountIdr / rate,
        groupMembers: members,
      );
      return;
    }

    final initialItems = [
      DraftBillItem(
        id: 'item_${DateTime.now().millisecondsSinceEpoch}_1',
        name: 'Ayam Bakar Madu Satu Ekor (Sharing)',
        qty: 1,
        unitPriceOrigin: 90000,
        assignedMemberUids: Set<String>.from(defaultMemberUids),
      ),
      DraftBillItem(
        id: 'item_${DateTime.now().millisecondsSinceEpoch}_2',
        name: 'Es Kopi Susu Gula Aren',
        qty: 2,
        unitPriceOrigin: 22000,
        assignedMemberUids: defaultMemberUids.take(2).toSet(),
      ),
    ];

    _recalculateAndEmit(
      title: 'Makan Malam Bersama',
      currencyCode: 'IDR',
      exchangeRate: 1.0,
      rateDate: DateTime.now(),
      rateSourceInfo: 'Mata Uang Lokal (IDR = 1.0)',
      items: initialItems,
      taxOrigin: 13400, // PB1 10%
      serviceOrigin: 6700, // Layanan 5%
      discountOrigin: 5000,
      groupMembers: members,
    );
  }

  /// Ekstraksi Foto Struk via Open-Source OCR di dalam `Isolate.run` (UFD-3a)
  Future<void> scanReceiptWithOcr({
    required Uint8List imageBytes,
    required ReceiptPresetType preset,
  }) async {
    final currentLoaded = state is BillLoaded ? state as BillLoaded : null;
    if (currentLoaded == null) return;

    emit(
      const BillLoading(
        'Memindai struk & mengekstrak rincian item...',
      ),
    );

    final ApiResponse<ParsedReceiptDraft> ocrResult =
        await _apiRepository.processReceiptWithOpenSourceOcr(
      imageBytes: imageBytes,
      preset: preset,
    );

    switch (ocrResult) {
      case ApiSuccess<ParsedReceiptDraft>(:final data):
        final allMemberUids =
            currentLoaded.groupMembers.map((m) => m.uid).toSet();

        final extractedItems = data.items
            .asMap()
            .entries
            .map(
              (entry) => DraftBillItem(
                id: 'ocr_${DateTime.now().millisecondsSinceEpoch}_${entry.key}',
                name: entry.value.name,
                qty: entry.value.qty,
                unitPriceOrigin: entry.value.unitPrice,
                assignedMemberUids: Set<String>.from(allMemberUids),
              ),
            )
            .toList();

        // Jika mata uang hasil deteksi OCR != IDR, langsung ambil kurs dari Frankfurter API v2!
        double rate = 1.0;
        DateTime rateDate = DateTime.now();
        String rateSource = 'Mata Uang Lokal (IDR)';

        if (data.detectedCurrency != 'IDR') {
          emit(
            BillLoading(
              'Mengambil kurs ${data.detectedCurrency} ke IDR...',
            ),
          );
          final rateResp = await _apiRepository.fetchExchangeRateToIdr(
            data.detectedCurrency,
          );
          if (rateResp is ApiSuccess<ExchangeRateResult>) {
            rate = rateResp.data.rateToIdr;
            rateDate = rateResp.data.rateDate;
            rateSource = rateResp.data.sourceEndpoint;
          }
        }

        _recalculateAndEmit(
          title: data.merchantTitle,
          currencyCode: data.detectedCurrency,
          exchangeRate: rate,
          rateDate: rateDate,
          rateSourceInfo: rateSource,
          items: extractedItems,
          taxOrigin: data.detectedTaxAmount,
          serviceOrigin: data.detectedServiceAmount,
          discountOrigin: data.detectedDiscountAmount,
          groupMembers: currentLoaded.groupMembers,
          ocrIsolateBadge:
              'Berhasil mengekstrak ${extractedItems.length} item dari "${data.merchantTitle}"',
        );

      case ApiFailure<ParsedReceiptDraft>(:final errorMessage):
        emit(
          BillError(
            errorMessage: errorMessage,
            previousLoadedState: currentLoaded,
          ),
        );
        emit(currentLoaded);

      case ApiLoading<ParsedReceiptDraft>():
        break;
    }
  }

  /// Ganti Mata Uang Tagihan & Ambil Kurs dari Frankfurter API v2 (UFD-3b & BR-02)
  Future<void> changeCurrencyAndFetchRate(String newCurrencyCode) async {
    final currentLoaded = state is BillLoaded ? state as BillLoaded : null;
    if (currentLoaded == null) return;

    final code = newCurrencyCode.toUpperCase();
    emit(
      BillLoading(
        'Memperbarui nilai tukar $code ke IDR...',
      ),
    );

    final response = await _apiRepository.fetchExchangeRateToIdr(code);
    switch (response) {
      case ApiSuccess<ExchangeRateResult>(:final data):
        _recalculateAndEmit(
          title: currentLoaded.title,
          currencyCode: code,
          exchangeRate: data.rateToIdr,
          rateDate: data.rateDate,
          rateSourceInfo: data.sourceEndpoint,
          items: currentLoaded.items,
          taxOrigin: currentLoaded.taxOrigin,
          serviceOrigin: currentLoaded.serviceOrigin,
          discountOrigin: currentLoaded.discountOrigin,
          groupMembers: currentLoaded.groupMembers,
          ocrIsolateBadge: currentLoaded.ocrIsolateBadge,
        );

      case ApiFailure<ExchangeRateResult>(:final errorMessage):
        emit(
          BillError(
            errorMessage: errorMessage,
            previousLoadedState: currentLoaded,
          ),
        );
        emit(currentLoaded);

      case ApiLoading<ExchangeRateResult>():
        break;
    }
  }

  /// Override Kurs Manual (Mitigasi Risiko Tabel 2.10 & NFR-03)
  void updateManualExchangeRate(double customRate) {
    final current = state is BillLoaded ? state as BillLoaded : null;
    if (current == null || customRate <= 0) return;

    _recalculateAndEmit(
      title: current.title,
      currencyCode: current.currencyCode,
      exchangeRate: customRate,
      rateDate: DateTime.now(),
      rateSourceInfo: 'Input Kurs Manual (Terkunci pada Tagihan)',
      items: current.items,
      taxOrigin: current.taxOrigin,
      serviceOrigin: current.serviceOrigin,
      discountOrigin: current.discountOrigin,
      groupMembers: current.groupMembers,
      ocrIsolateBadge: current.ocrIsolateBadge,
    );
  }

  void updateHeaderAndCharges({
    String? title,
    double? taxOrigin,
    double? serviceOrigin,
    double? discountOrigin,
  }) {
    final current = state is BillLoaded ? state as BillLoaded : null;
    if (current == null) return;

    _recalculateAndEmit(
      title: title ?? current.title,
      currencyCode: current.currencyCode,
      exchangeRate: current.exchangeRate,
      rateDate: current.rateDate,
      rateSourceInfo: current.rateSourceInfo,
      items: current.items,
      taxOrigin: taxOrigin ?? current.taxOrigin,
      serviceOrigin: serviceOrigin ?? current.serviceOrigin,
      discountOrigin: discountOrigin ?? current.discountOrigin,
      groupMembers: current.groupMembers,
      ocrIsolateBadge: current.ocrIsolateBadge,
    );
  }

  void addDraftItem({
    required String name,
    required int qty,
    required double unitPriceOrigin,
  }) {
    final current = state is BillLoaded ? state as BillLoaded : null;
    if (current == null) return;

    final allUids = current.groupMembers.map((m) => m.uid).toSet();
    final updatedItems = [
      ...current.items,
      DraftBillItem(
        id: 'item_${DateTime.now().microsecondsSinceEpoch}',
        name: name.trim(),
        qty: qty,
        unitPriceOrigin: unitPriceOrigin,
        assignedMemberUids: allUids,
      ),
    ];

    _recalculateAndEmit(
      title: current.title,
      currencyCode: current.currencyCode,
      exchangeRate: current.exchangeRate,
      rateDate: current.rateDate,
      rateSourceInfo: current.rateSourceInfo,
      items: updatedItems,
      taxOrigin: current.taxOrigin,
      serviceOrigin: current.serviceOrigin,
      discountOrigin: current.discountOrigin,
      groupMembers: current.groupMembers,
      ocrIsolateBadge: current.ocrIsolateBadge,
    );
  }

  void updateDraftItem({
    required String itemId,
    required String name,
    required int qty,
    required double unitPriceOrigin,
  }) {
    final current = state is BillLoaded ? state as BillLoaded : null;
    if (current == null) return;

    final updatedItems = current.items
        .map(
          (item) => item.id == itemId
              ? item.copyWith(
                  name: name.trim(),
                  qty: qty,
                  unitPriceOrigin: unitPriceOrigin,
                )
              : item,
        )
        .toList();

    _recalculateAndEmit(
      title: current.title,
      currencyCode: current.currencyCode,
      exchangeRate: current.exchangeRate,
      rateDate: current.rateDate,
      rateSourceInfo: current.rateSourceInfo,
      items: updatedItems,
      taxOrigin: current.taxOrigin,
      serviceOrigin: current.serviceOrigin,
      discountOrigin: current.discountOrigin,
      groupMembers: current.groupMembers,
      ocrIsolateBadge: current.ocrIsolateBadge,
    );
  }

  void removeDraftItem(String itemId) {
    final current = state is BillLoaded ? state as BillLoaded : null;
    if (current == null) return;

    final updatedItems =
        current.items.where((item) => item.id != itemId).toList();

    _recalculateAndEmit(
      title: current.title,
      currencyCode: current.currencyCode,
      exchangeRate: current.exchangeRate,
      rateDate: current.rateDate,
      rateSourceInfo: current.rateSourceInfo,
      items: updatedItems,
      taxOrigin: current.taxOrigin,
      serviceOrigin: current.serviceOrigin,
      discountOrigin: current.discountOrigin,
      groupMembers: current.groupMembers,
      ocrIsolateBadge: current.ocrIsolateBadge,
    );
  }

  /// Toggle centang anggota pada item tertentu -> Kalkulasi split langsung
  /// berubah seketika secara reaktif (FR-04 & Bukti Demo Tabel 1.3)
  void toggleMemberOnItem({
    required String itemId,
    required String memberUid,
  }) {
    final current = state is BillLoaded ? state as BillLoaded : null;
    if (current == null) return;

    final updatedItems = current.items.map((item) {
      if (item.id != itemId) return item;
      final nextSet = Set<String>.from(item.assignedMemberUids);
      if (nextSet.contains(memberUid)) {
        nextSet.remove(memberUid);
      } else {
        nextSet.add(memberUid);
      }
      return item.copyWith(assignedMemberUids: nextSet);
    }).toList();

    _recalculateAndEmit(
      title: current.title,
      currencyCode: current.currencyCode,
      exchangeRate: current.exchangeRate,
      rateDate: current.rateDate,
      rateSourceInfo: current.rateSourceInfo,
      items: updatedItems,
      taxOrigin: current.taxOrigin,
      serviceOrigin: current.serviceOrigin,
      discountOrigin: current.discountOrigin,
      groupMembers: current.groupMembers,
      ocrIsolateBadge: current.ocrIsolateBadge,
    );
  }

  /// Pilih semua anggota untuk item tertentu dengan satu ketukan
  void selectAllMembersForItem(String itemId) {
    final current = state is BillLoaded ? state as BillLoaded : null;
    if (current == null) return;

    final allUids = current.groupMembers.map((m) => m.uid).toSet();
    final updatedItems = current.items.map((item) {
      if (item.id != itemId) return item;
      return item.copyWith(assignedMemberUids: Set<String>.from(allUids));
    }).toList();

    _recalculateAndEmit(
      title: current.title,
      currencyCode: current.currencyCode,
      exchangeRate: current.exchangeRate,
      rateDate: current.rateDate,
      rateSourceInfo: current.rateSourceInfo,
      items: updatedItems,
      taxOrigin: current.taxOrigin,
      serviceOrigin: current.serviceOrigin,
      discountOrigin: current.discountOrigin,
      groupMembers: current.groupMembers,
      ocrIsolateBadge: current.ocrIsolateBadge,
    );
  }

  // ==========================================================================
  // INTI ALGORITMA PEMBAGIAN PROPORSIONAL (BR-01, BR-02, BR-03, BAB 2.9)
  // Menggunakan Higher-Order Functions (.fold, .where, .map) TANPA for-loop!
  // ==========================================================================
  void _recalculateAndEmit({
    required String title,
    required String currencyCode,
    required double exchangeRate,
    required DateTime rateDate,
    required String rateSourceInfo,
    required List<DraftBillItem> items,
    required double taxOrigin,
    required double serviceOrigin,
    required double discountOrigin,
    required List<AppUser> groupMembers,
    String? ocrIsolateBadge,
  }) {
    // 1. Konversi subtotal, pajak, layanan, diskon ke IDR & bulatkan ke Rupiah (BR-02 & BR-03)
    final double subtotalIdr = items.fold<double>(
      0.0,
      (sum, item) => sum + item.totalIdr(exchangeRate),
    );
    final double taxIdr = (taxOrigin * exchangeRate).roundToDouble();
    final double serviceIdr = (serviceOrigin * exchangeRate).roundToDouble();
    final double discountIdr = (discountOrigin * exchangeRate).roundToDouble();
    final double grandTotalIdr =
        (subtotalIdr + taxIdr + serviceIdr - discountIdr).roundToDouble();

    // 2. Hitung subtotal item per anggota menggunakan .map() dan .where() + .fold()
    final List<ComputedParticipantSplit> rawSplits = groupMembers.map((member) {
      final double memberSubtotal = items
          .where((item) => item.assignedMemberUids.contains(member.uid))
          .fold<double>(
            0.0,
            (sum, item) =>
                sum +
                (item.totalIdr(exchangeRate) / item.assignedMemberUids.length),
          );

      // BR-01: Proporsi pajak, biaya layanan, dan diskon berdasarkan subtotal_i / Σ subtotal
      final double ratio =
          subtotalIdr > 0 ? (memberSubtotal / subtotalIdr) : 0.0;
      final double memberTax = taxIdr * ratio;
      final double memberService = serviceIdr * ratio;
      final double memberDiscount = discountIdr * ratio;

      final double exactTotal =
          memberSubtotal + memberTax + memberService - memberDiscount;

      return ComputedParticipantSplit(
        user: member,
        itemsSubtotalIdr: memberSubtotal.roundToDouble(),
        taxShareIdr: memberTax.roundToDouble(),
        serviceShareIdr: memberService.roundToDouble(),
        discountShareIdr: memberDiscount.roundToDouble(),
        totalDueIdr: exactTotal.roundToDouble(),
      );
    }).toList();

    // 3. BR-03: Pembulatan ke Rupiah; selisih pembulatan ditambahkan ke anggota
    //    dengan subtotal terbesar agar total seluruh peserta == grandTotalIdr (Selisih Rp0!)
    final double sumRounded = rawSplits.fold<double>(
      0.0,
      (sum, s) => sum + s.totalDueIdr,
    );
    final double diffIdr =
        subtotalIdr > 0 ? (grandTotalIdr - sumRounded).roundToDouble() : 0.0;

    List<ComputedParticipantSplit> finalSplits = rawSplits;
    if (diffIdr != 0 && rawSplits.isNotEmpty) {
      // Cari peserta dengan itemsSubtotalIdr terbesar menggunakan .reduce()
      final ComputedParticipantSplit largestParticipant = rawSplits.reduce(
        (curr, next) =>
            next.itemsSubtotalIdr > curr.itemsSubtotalIdr ? next : curr,
      );

      finalSplits = rawSplits.map((split) {
        if (split.user.uid == largestParticipant.user.uid) {
          return ComputedParticipantSplit(
            user: split.user,
            itemsSubtotalIdr: split.itemsSubtotalIdr,
            taxShareIdr: split.taxShareIdr,
            serviceShareIdr: split.serviceShareIdr,
            discountShareIdr: split.discountShareIdr,
            totalDueIdr: split.totalDueIdr + diffIdr,
            roundingAdjustmentIdr: diffIdr,
          );
        }
        return split;
      }).toList();
    }

    emit(
      BillLoaded(
        title: title,
        currencyCode: currencyCode,
        exchangeRate: exchangeRate,
        rateDate: rateDate,
        rateSourceInfo: rateSourceInfo,
        items: items,
        taxOrigin: taxOrigin,
        serviceOrigin: serviceOrigin,
        discountOrigin: discountOrigin,
        groupMembers: groupMembers,
        computedSplits: finalSplits,
        subtotalIdr: subtotalIdr,
        taxIdr: taxIdr,
        serviceIdr: serviceIdr,
        discountIdr: discountIdr,
        grandTotalIdr: grandTotalIdr,
        ocrIsolateBadge: ocrIsolateBadge,
      ),
    );
  }

  /// Simpan Tagihan ke Database (BILLS, BILL_ITEMS, ITEM_ASSIGNMENTS, BILL_PARTICIPANTS)
  /// dan picu Push Notification "Tagihan Baru" (UFD-3b, BR-05, FR-06)
  Future<BillModel?> submitBill({
    required String groupId,
    required String creatorUid,
    String? existingBillId,
  }) async {
    final current = state is BillLoaded ? state as BillLoaded : null;
    if (current == null || !current.allItemsAssigned) return null;

    final String billId =
        existingBillId ?? 'bill_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();

    final billModel = BillModel(
      billId: billId,
      groupId: groupId,
      creatorUid: creatorUid,
      title: current.title.trim().isEmpty
          ? 'Tagihan Patungan'
          : current.title.trim(),
      currencyCode: current.currencyCode,
      exchangeRate: current.exchangeRate,
      rateDate: current.rateDate,
      subtotalIdr: current.subtotalIdr,
      taxAmountIdr: current.taxIdr,
      serviceAmountIdr: current.serviceIdr,
      discountAmountIdr: current.discountIdr,
      grandTotalIdr: current.grandTotalIdr,
      receiptUrl: current.ocrIsolateBadge != null ? 'ocr_scanned_receipt.jpg' : '',
      status: BillStatus.open,
      createdAt: now,
    );

    final List<BillItemModel> itemModels = current.items
        .map(
          (draft) => BillItemModel(
            itemId: draft.id,
            billId: billId,
            itemName: draft.name,
            qty: draft.qty,
            unitPrice: draft.unitPriceOrigin,
            priceIdr: draft.totalIdr(current.exchangeRate),
          ),
        )
        .toList();

    final Map<String, List<ItemAssignmentModel>> assignmentsByItem = {
      for (final draft in current.items)
        draft.id: draft.assignedMemberUids.map((uid) {
          final share = (draft.totalIdr(current.exchangeRate) /
                  draft.assignedMemberUids.length)
              .roundToDouble();
          return ItemAssignmentModel(
            assignmentId: 'asg_${draft.id}_$uid',
            itemId: draft.id,
            debtorUid: uid,
            shareIdr: share,
          );
        }).toList(),
    };

    // Hanya sertakan anggota yang memiliki tagihan > 0 sebagai BILL_PARTICIPANTS
    // BR-05: Bagian milik Bill Creator otomatis berstatus `paid` karena ia yang menalangi!
    final List<BillParticipantModel> participants = current.computedSplits
        .where((s) => s.totalDueIdr > 0)
        .map((split) {
          final isCreator = split.user.uid == creatorUid;
          return BillParticipantModel(
            participantId: 'part_${billId}_${split.user.uid}',
            billId: billId,
            debtorUid: split.user.uid,
            itemsSubtotalIdr: split.itemsSubtotalIdr,
            taxShareIdr: split.taxShareIdr,
            serviceShareIdr: split.serviceShareIdr,
            discountShareIdr: split.discountShareIdr,
            totalDueIdr: split.totalDueIdr,
            paymentStatus:
                isCreator ? PaymentStatus.paid : PaymentStatus.unpaid,
            claimedAt: isCreator ? now : null,
            verifiedAt: isCreator ? now : null,
          );
        })
        .toList();

    return _settlementRepository.saveNewOrUpdatedBill(
      bill: billModel,
      items: itemModels,
      assignmentsByItem: assignmentsByItem,
      participants: participants,
      isEdit: existingBillId != null,
    );
  }
}
