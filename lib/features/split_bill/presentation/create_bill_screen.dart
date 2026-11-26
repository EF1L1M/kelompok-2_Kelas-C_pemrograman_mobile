import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/extensions/format_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/patungin_patterns.dart';
import '../../../repositories/bill_settlement_repository.dart';
import '../../../repositories/group_repository.dart';
import '../../../repositories/open_source_api_repository.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../cubit/bill_split_cubit.dart';
import '../cubit/bill_state.dart';

class CreateBillScreen extends StatefulWidget {
  final String groupId;
  final String? editBillId;

  const CreateBillScreen({
    super.key,
    required this.groupId,
    this.editBillId,
  });

  @override
  State<CreateBillScreen> createState() => _CreateBillScreenState();
}

class _CreateBillScreenState extends State<CreateBillScreen> {
  late final BillSplitCubit _splitCubit;
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _taxCtrl = TextEditingController();
  final TextEditingController _serviceCtrl = TextEditingController();
  final TextEditingController _discountCtrl = TextEditingController();
  bool _isSubmitting = false;
  String? _lastSyncedCurrency;
  String? _lastSyncedOcrBadge;

  static const List<String> _supportedCurrencies = [
    'IDR',
    'USD',
    'SGD',
    'EUR',
    'JPY',
    'MYR',
  ];

  @override
  void initState() {
    super.initState();
    _splitCubit = BillSplitCubit(
      apiRepository: context.read<OpenSourceApiRepository>(),
      settlementRepository: context.read<BillSettlementRepository>(),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final currentUser = context.read<AuthCubit>().currentUser;
      if (currentUser == null) return;

      final memberProfiles = await context
          .read<GroupRepository>()
          .getGroupMembersWithProfiles(
            groupId: widget.groupId,
            requesterUid: currentUser.uid,
          );
      final members = memberProfiles.map((m) => m.user).toList();

      RichBillDetail? existing;
      if (widget.editBillId != null) {
        existing = await context
            .read<BillSettlementRepository>()
            .watchRichBillDetail(
              groupId: widget.groupId,
              billId: widget.editBillId!,
            )
            .first;
      }

      if (!mounted) return;
      _splitCubit.initializeDraft(
        members: members,
        existingBill: existing,
      );
      _syncControllersFromState(_splitCubit.state);
    });
  }

  void _syncControllersFromState(BillState state) {
    if (state is BillLoaded) {
      _lastSyncedCurrency = state.currencyCode;
      _lastSyncedOcrBadge = state.ocrIsolateBadge;
      _titleCtrl.text = state.title;
      _taxCtrl.text = state.taxOrigin.toStringAsFixed(
        state.currencyCode == 'IDR' ? 0 : 2,
      );
      _serviceCtrl.text = state.serviceOrigin.toStringAsFixed(
        state.currencyCode == 'IDR' ? 0 : 2,
      );
      _discountCtrl.text = state.discountOrigin.toStringAsFixed(
        state.currencyCode == 'IDR' ? 0 : 2,
      );
    }
  }

  @override
  void dispose() {
    _splitCubit.close();
    _titleCtrl.dispose();
    _taxCtrl.dispose();
    _serviceCtrl.dispose();
    _discountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthCubit>().currentUser;
    if (currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return BlocProvider.value(
      value: _splitCubit,
      child: BlocConsumer<BillSplitCubit, BillState>(
        listener: (context, state) {
          if (state is BillLoaded &&
              (_titleCtrl.text != state.title ||
                  _lastSyncedCurrency != state.currencyCode ||
                  _lastSyncedOcrBadge != state.ocrIsolateBadge)) {
            _syncControllersFromState(state);
          } else if (state is BillError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage),
                backgroundColor: AppTheme.statusRejected,
              ),
            );
          }
        },
        builder: (context, state) {
          return Scaffold(
            backgroundColor: AppTheme.warmCream,
            appBar: AppBar(
              title: Text(
                widget.editBillId != null
                    ? 'Ubah Rincian Struk'
                    : 'Catat & Bagi Struk',
              ),
            ),
            body: switch (state) {
              BillInitial() => const Center(child: CircularProgressIndicator()),
              BillLoading(:final loadingStep) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const OrganicPebbleBadge(
                          size: 74,
                          color: AppTheme.sageWash,
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(strokeWidth: 2.8),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          loadingStep,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: AppTheme.darkSlate,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              BillError(:final errorMessage) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(errorMessage),
                  ),
                ),
              BillLoaded() => _buildLoadedContent(
                  context,
                  state,
                  currentUser.uid,
                ),
            },
          );
        },
      ),
    );
  }

  Widget _buildLoadedContent(
    BuildContext context,
    BillLoaded state,
    String creatorUid,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 100),
      children: [
        // 1. Pita Organik Pindai Struk (Smart OCR)
        _buildOcrRibbon(context, state),
        const SizedBox(height: 24),

        // 2. Info Tagihan & Mata Uang (Terbuka di atas kertas, tanpa kotak kaku)
        _buildHeaderAndCurrencySection(context, state),
        const SizedBox(height: 22),
        const DashedDivider(),
        const SizedBox(height: 22),

        // 3. Daftar Item & Pembagian Anggota bergaya Buku Catatan
        _buildInteractiveItemsSection(context, state),
        const SizedBox(height: 22),
        const DashedDivider(),
        const SizedBox(height: 22),

        // 4. Pajak Restoran, Layanan & Diskon
        _buildChargesSection(context, state),
        const SizedBox(height: 26),

        // 5. Ringkasan Pembagian dalam bentuk Struk Kertas Bergerigi!
        _buildScallopedSplitSummary(context, state, creatorUid),
        const SizedBox(height: 26),

        // 6. Tombol Pil Simpan Tagihan (dilindungi anti double-submit)
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: (state.allItemsAssigned &&
                    state.grandTotalIdr > 0 &&
                    !_isSubmitting)
                ? () async {
                    setState(() => _isSubmitting = true);
                    try {
                      final saved = await _splitCubit.submitBill(
                        groupId: widget.groupId,
                        creatorUid: creatorUid,
                        existingBillId: widget.editBillId,
                      );
                      if (saved != null && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Tagihan "${saved.title}" berhasil disimpan!',
                            ),
                            backgroundColor: AppTheme.primaryEmerald,
                          ),
                        );
                        context.pushReplacement(
                          '/groups/${widget.groupId}/bills/${saved.billId}',
                        );
                        return;
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Gagal menyimpan tagihan: $e'),
                            backgroundColor: AppTheme.statusRejected,
                          ),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _isSubmitting = false);
                    }
                  }
                : null,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_circle_outline_rounded),
            label: Text(
              _isSubmitting
                  ? 'Menyimpan Tagihan...'
                  : state.items.isEmpty
                      ? 'Tambahkan Menu Pesanan Terlebih Dahulu'
                      : !state.allItemsAssigned
                          ? 'Pilih Anggota di Setiap Item Dulu'
                          : state.grandTotalIdr <= 0
                              ? 'Total Tagihan Harus Lebih dari Rp 0'
                              : 'Simpan & Bagikan (${state.grandTotalIdr.toRupiah()})',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOcrRibbon(BuildContext context, BillLoaded state) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF143C2E), Color(0xFF1F6B51)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(14),
          bottomLeft: Radius.circular(14),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: CustomPaint(
        painter: const OrganicCanvasPainter(
          blobColor: Color(0x16FAF6F0),
          dotColor: Color(0x14FAF6F0),
          showArcs: false,
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const OrganicPebbleBadge(
                    size: 40,
                    color: AppTheme.butterWash,
                    child: Icon(
                      Icons.document_scanner_rounded,
                      size: 20,
                      color: AppTheme.deepForest,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pindai Struk Otomatis',
                          style: TextStyle(
                            color: AppTheme.warmCream,
                            fontWeight: FontWeight.w900,
                            fontSize: 15.5,
                          ),
                        ),
                        Text(
                          'Langsung baca item, pajak & kurs dari foto struk.',
                          style: TextStyle(
                            color: AppTheme.warmCream.withValues(alpha: 0.8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (state.ocrIsolateBadge != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: Color(0xFF9AF0C7),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          state.ocrIsolateBadge!,
                          style: const TextStyle(
                            color: AppTheme.warmCream,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.warmCream,
                      foregroundColor: AppTheme.deepForest,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    onPressed: () => _pickImageAndRunOcr(context),
                    icon: const Icon(Icons.camera_alt_rounded, size: 17),
                    label: const Text(
                      'Pindai Struk',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  ...ReceiptPresetType.values.map(
                    (preset) => ActionChip(
                      backgroundColor:
                          AppTheme.warmCream.withValues(alpha: 0.14),
                      side: BorderSide(
                        color: AppTheme.warmCream.withValues(alpha: 0.28),
                      ),
                      shape: const StadiumBorder(),
                      label: Text(
                        preset.label,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.warmCream,
                        ),
                      ),
                      onPressed: () {
                        final dummyBytes = Uint8List.fromList(
                          List<int>.generate(95000, (i) => (i * 17) % 256),
                        );
                        _splitCubit.scanReceiptWithOcr(
                          imageBytes: dummyBytes,
                          preset: preset,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImageAndRunOcr(BuildContext context) async {
    final ReceiptPresetType? selectedPreset =
        await showModalBottomSheet<ReceiptPresetType>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4.5,
                decoration: BoxDecoration(
                  color: AppTheme.softBorder,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Pilih Contoh Struk untuk Dipindai',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            const Text(
              'Ekstrak nama tempat, item pesanan, pajak, dan mata uang secara otomatis:',
              style: TextStyle(fontSize: 12.5, color: AppTheme.mutedInk),
            ),
            const SizedBox(height: 12),
            ...ReceiptPresetType.values.map(
              (preset) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const OrganicPebbleBadge(
                  size: 42,
                  color: AppTheme.sageWash,
                  child: Icon(
                    Icons.receipt_long_rounded,
                    size: 20,
                    color: AppTheme.primaryEmerald,
                  ),
                ),
                title: Text(
                  preset.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                subtitle: const Text(
                  'Ekstrak item, pajak, dan layanan otomatis',
                  style: TextStyle(fontSize: 12),
                ),
                onTap: () => Navigator.pop(ctx, preset),
              ),
            ),
          ],
        ),
      ),
    );

    if (selectedPreset != null) {
      final dummyBytes = Uint8List.fromList(
        List<int>.generate(95000, (i) => (i * 23) % 256),
      );
      await _splitCubit.scanReceiptWithOcr(
        imageBytes: dummyBytes,
        preset: selectedPreset,
      );
    }
  }

  Widget _buildHeaderAndCurrencySection(
    BuildContext context,
    BillLoaded state,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Judul & Mata Uang',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 17,
            letterSpacing: -0.3,
            color: AppTheme.darkSlate,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _titleCtrl,
          onChanged: (v) => _splitCubit.updateHeaderAndCharges(title: v),
          decoration: const InputDecoration(
            labelText: 'Nama Tempat / Acara',
            prefixIcon: Icon(Icons.storefront_outlined),
          ),
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _supportedCurrencies.map((code) {
              final selected = state.currencyCode == code;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => _splitCubit.changeCurrencyAndFetchRate(code),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? AppTheme.darkSlate : AppTheme.paperWhite,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: selected
                            ? AppTheme.darkSlate
                            : AppTheme.softBorder,
                      ),
                    ),
                    child: Text(
                      code,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                        color:
                            selected ? AppTheme.warmCream : AppTheme.darkSlate,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        if (state.currencyCode != 'IDR') ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.skyWash,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.currency_exchange_rounded,
                  color: Color(0xFF1F638C),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '1 ${state.currencyCode} = ${state.exchangeRate.toRupiah()} (${state.rateDate.toIndoDate()})',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: Color(0xFF154969),
                        ),
                      ),
                      Text(
                        state.rateSourceInfo,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF1F638C),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _showManualRateDialog(context, state),
                  child: const Text('Ubah'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInteractiveItemsSection(BuildContext context, BillLoaded state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Siapa Pesan Apa?',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                      letterSpacing: -0.3,
                      color: AppTheme.darkSlate,
                    ),
                  ),
                  Text(
                    'Ketuk nama teman pada tiap menu pesanan.',
                    style: TextStyle(fontSize: 12.5, color: AppTheme.mutedInk),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                backgroundColor: AppTheme.paperWhite,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
              ),
              onPressed: () => _showAddOrEditItemDialog(context, state),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Menu Baru'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (state.items.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: BoxDecoration(
              color: AppTheme.paperWhite,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(14),
                bottomLeft: Radius.circular(14),
                bottomRight: Radius.circular(24),
              ),
              border: Border.all(color: AppTheme.softBorder),
            ),
            child: Column(
              children: [
                const OrganicPebbleBadge(
                  size: 56,
                  color: AppTheme.warmSand,
                  child: Icon(
                    Icons.restaurant_menu_rounded,
                    size: 26,
                    color: AppTheme.mutedInk,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Belum ada menu pesanan',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                    color: AppTheme.darkSlate,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Tambahkan menu manual atau gunakan Pindai Struk di atas untuk mengisi otomatis.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: AppTheme.mutedInk),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => _showAddOrEditItemDialog(context, state),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Tambah Menu Pertama'),
                ),
              ],
            ),
          )
        else
          ...List.generate(state.items.length, (idx) {
          final item = state.items[idx];
          final itemIdr = item.totalIdr(state.exchangeRate);
          final perPersonIdr = item.assignedMemberUids.isEmpty
              ? 0.0
              : itemIdr / item.assignedMemberUids.length;
          final allSelected =
              item.assignedMemberUids.length == state.groupMembers.length;
          final isUnassigned = item.assignedMemberUids.isEmpty;

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: isUnassigned ? AppTheme.apricotWash : AppTheme.paperWhite,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(idx.isEven ? 24 : 14),
                topRight: Radius.circular(idx.isEven ? 14 : 24),
                bottomLeft: Radius.circular(idx.isEven ? 14 : 24),
                bottomRight: Radius.circular(idx.isEven ? 24 : 14),
              ),
              border: Border.all(
                color: isUnassigned
                    ? AppTheme.statusRejected.withValues(alpha: 0.6)
                    : AppTheme.softBorder,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item.qty}x ${item.name}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              color: AppTheme.darkSlate,
                            ),
                          ),
                          Text(
                            state.currencyCode == 'IDR'
                                ? '@ ${item.unitPriceOrigin.toRupiah()} = ${itemIdr.toRupiah()}'
                                : '${item.totalOrigin.toCurrency(state.currencyCode)} → ${itemIdr.toRupiah()}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.mutedInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!allSelected)
                      TextButton(
                        onPressed: () =>
                            _splitCubit.selectAllMembersForItem(item.id),
                        child: const Text(
                          'Semua',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    IconButton(
                      tooltip: 'Edit Item',
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: () => _showAddOrEditItemDialog(
                        context,
                        state,
                        existingItem: item,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Hapus Item',
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: AppTheme.statusRejected,
                      ),
                      onPressed: () => _splitCubit.removeDraftItem(item.id),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: state.groupMembers.map((member) {
                    final isChecked =
                        item.assignedMemberUids.contains(member.uid);
                    final pal = PatunginPalette.forKey(member.uid);
                    return GestureDetector(
                      onTap: () => _splitCubit.toggleMemberOnItem(
                        itemId: item.id,
                        memberUid: member.uid,
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: isChecked ? pal.bg : AppTheme.warmCream,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isChecked ? pal.fg : AppTheme.softBorder,
                            width: isChecked ? 1.4 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 9,
                              backgroundColor:
                                  isChecked ? pal.fg : AppTheme.softBorder,
                              child: Icon(
                                isChecked
                                    ? Icons.check_rounded
                                    : Icons.add_rounded,
                                size: 11,
                                color: isChecked
                                    ? Colors.white
                                    : AppTheme.mutedInk,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${member.fullName.split(' ').first} · ${isChecked ? perPersonIdr.toRupiah() : "Rp 0"}',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: isChecked
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                                color: isChecked ? pal.fg : AppTheme.mutedInk,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                if (isUnassigned)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Pilih minimal 1 orang untuk menu ini.',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.statusRejected,
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildChargesSection(BuildContext context, BillLoaded state) {
    final suffix = state.currencyCode;
    final subtotalOrigin = state.items.fold<double>(
      0.0,
      (acc, item) => acc + item.totalOrigin,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pajak, Layanan & Diskon ($suffix)',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 17,
            letterSpacing: -0.3,
            color: AppTheme.darkSlate,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Otomatis dibagi proporsional mengikuti porsi pesanan tiap orang.',
          style: TextStyle(fontSize: 12.5, color: AppTheme.mutedInk),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              shape: const StadiumBorder(),
              backgroundColor: AppTheme.paperWhite,
              label: const Text(
                'PB1 10%',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              onPressed: () {
                final val = state.currencyCode == 'IDR'
                    ? (subtotalOrigin * 0.10).roundToDouble()
                    : double.parse((subtotalOrigin * 0.10).toStringAsFixed(2));
                _taxCtrl.text = val.toStringAsFixed(
                  state.currencyCode == 'IDR' ? 0 : 2,
                );
                _splitCubit.updateHeaderAndCharges(taxOrigin: val);
              },
            ),
            ActionChip(
              shape: const StadiumBorder(),
              backgroundColor: AppTheme.paperWhite,
              label: const Text(
                'Layanan 5%',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              onPressed: () {
                final val = state.currencyCode == 'IDR'
                    ? (subtotalOrigin * 0.05).roundToDouble()
                    : double.parse((subtotalOrigin * 0.05).toStringAsFixed(2));
                _serviceCtrl.text = val.toStringAsFixed(
                  state.currencyCode == 'IDR' ? 0 : 2,
                );
                _splitCubit.updateHeaderAndCharges(serviceOrigin: val);
              },
            ),
            ActionChip(
              shape: const StadiumBorder(),
              backgroundColor: AppTheme.warmSand,
              label: const Text(
                'Reset 0',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              onPressed: () {
                _taxCtrl.text = '0';
                _serviceCtrl.text = '0';
                _discountCtrl.text = '0';
                _splitCubit.updateHeaderAndCharges(
                  taxOrigin: 0,
                  serviceOrigin: 0,
                  discountOrigin: 0,
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _taxCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'Pajak ($suffix)'),
                onChanged: (v) => _splitCubit.updateHeaderAndCharges(
                  taxOrigin: double.tryParse(v) ?? 0,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _serviceCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'Layanan ($suffix)'),
                onChanged: (v) => _splitCubit.updateHeaderAndCharges(
                  serviceOrigin: double.tryParse(v) ?? 0,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _discountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'Diskon ($suffix)'),
                onChanged: (v) => _splitCubit.updateHeaderAndCharges(
                  discountOrigin: double.tryParse(v) ?? 0,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Ringkasan pembagian bergaya struk fisik bergerigi (scalloped paper receipt)
  Widget _buildScallopedSplitSummary(
    BuildContext context,
    BillLoaded state,
    String creatorUid,
  ) {
    return ScallopedReceiptSurface(
      topEdge: true,
      bottomEdge: true,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  'Pratinjau Pembagian',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: AppTheme.darkSlate,
                  ),
                ),
              ),
              InkStampBadge(
                text: 'Selisih Rp 0',
                color: AppTheme.primaryEmerald,
                angleRadians: -0.05,
              ),
            ],
          ),
          const SizedBox(height: 14),
          const DashedDivider(),
          const SizedBox(height: 12),
          ...state.computedSplits.map((split) {
            final isCreator = split.user.uid == creatorUid;
            final pal = PatunginPalette.forKey(split.user.uid);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: pal.bg,
                    child: Text(
                      split.user.initials,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: pal.fg,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${split.user.fullName}${isCreator ? " (Penalang)" : ""}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                            color: AppTheme.darkSlate,
                          ),
                        ),
                        Text(
                          'Menu ${split.itemsSubtotalIdr.toRupiah()} · +Pjk ${split.taxShareIdr.toRupiah()} · +Lyn ${split.serviceShareIdr.toRupiah()} · -Dsk ${split.discountShareIdr.toRupiah()}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.mutedInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    split.totalDueIdr.toRupiah(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14.5,
                      color: AppTheme.primaryEmerald,
                    ),
                  ),
                ],
              ),
            );
          }),
          const DashedDivider(),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TOTAL KESELURUHAN',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12.5,
                  letterSpacing: 0.7,
                  color: AppTheme.mutedInk,
                ),
              ),
              Text(
                state.grandTotalIdr.toRupiah(),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  letterSpacing: -0.5,
                  color: AppTheme.primaryEmerald,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showManualRateDialog(BuildContext context, BillLoaded state) {
    final ctrl = TextEditingController(
      text: state.exchangeRate.toStringAsFixed(0),
    );
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Atur Kurs Manual (${state.currencyCode} ke IDR)'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Nilai Kurs Rupiah per 1 Unit',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final parsed = double.tryParse(ctrl.text);
              if (parsed != null && parsed > 0) {
                _splitCubit.updateManualExchangeRate(parsed);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Simpan Kurs'),
          ),
        ],
      ),
    );
  }

  void _showAddOrEditItemDialog(
    BuildContext context,
    BillLoaded state, {
    DraftBillItem? existingItem,
  }) {
    final nameCtrl = TextEditingController(text: existingItem?.name ?? '');
    final qtyCtrl = TextEditingController(
      text: (existingItem?.qty ?? 1).toString(),
    );
    final priceCtrl = TextEditingController(
      text: existingItem != null
          ? existingItem.unitPriceOrigin.toString()
          : '',
    );

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existingItem == null ? 'Tambah Menu Pesanan' : 'Edit Menu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Nama Menu'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Jumlah (Qty)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: priceCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Harga Satuan (${state.currencyCode})',
              ),
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
              final name = nameCtrl.text.trim();
              final qty = int.tryParse(qtyCtrl.text) ?? 1;
              final price = double.tryParse(priceCtrl.text) ?? 0;
              if (name.isNotEmpty && price > 0) {
                if (existingItem == null) {
                  _splitCubit.addDraftItem(
                    name: name,
                    qty: qty,
                    unitPriceOrigin: price,
                  );
                } else {
                  _splitCubit.updateDraftItem(
                    itemId: existingItem.id,
                    name: name,
                    qty: qty,
                    unitPriceOrigin: price,
                  );
                }
                Navigator.pop(ctx);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}
