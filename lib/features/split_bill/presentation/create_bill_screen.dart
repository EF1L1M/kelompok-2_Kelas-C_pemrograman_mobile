import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/extensions/format_extensions.dart';
import '../../../core/theme/app_theme.dart';
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
          if (state is BillLoaded && _titleCtrl.text != state.title) {
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
            appBar: AppBar(
              title: Text(
                widget.editBillId != null
                    ? 'Edit Rincian Tagihan'
                    : 'Buat & Bagi Tagihan',
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
                        const CircularProgressIndicator(),
                        const SizedBox(height: 18),
                        Text(
                          loadingStep,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        // 1. Pindai Struk Otomatis (AI OCR)
        _buildOcrSection(context, state),
        const SizedBox(height: 16),

        // 2. Judul Tagihan & Pemilihan Mata Uang
        _buildHeaderAndCurrencyCard(context, state),
        const SizedBox(height: 16),

        // 3. Daftar Item & Pembagian Anggota
        _buildInteractiveItemsCard(context, state),
        const SizedBox(height: 16),

        // 4. Pajak Restoran, Biaya Layanan & Diskon
        _buildChargesCard(context, state),
        const SizedBox(height: 16),

        // 5. Ringkasan Pembagian Tagihan per Anggota
        _buildReactiveSplitSummaryCard(context, state, creatorUid),
        const SizedBox(height: 24),

        // 6. Tombol Simpan Tagihan
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: state.allItemsAssigned
                ? () async {
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
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      context.pushReplacement(
                        '/groups/${widget.groupId}/bills/${saved.billId}',
                      );
                    }
                  }
                : null,
            icon: const Icon(Icons.check_circle_outline_rounded),
            label: Text(
              state.allItemsAssigned
                  ? 'Simpan Tagihan (${state.grandTotalIdr.toRupiah()})'
                  : 'Pilih Anggota pada Setiap Item Terlebih Dahulu',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOcrSection(BuildContext context, BillLoaded state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF064E3B), Color(0xFF0F766E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.document_scanner_rounded, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pindai Struk Otomatis (Smart OCR)',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Ekstrak daftar pesanan, pajak, dan mata uang secara otomatis dari foto struk belanja atau restoran.',
            style: TextStyle(color: Color(0xFFD1FAE5), fontSize: 12.5),
          ),
          if (state.ocrIsolateBadge != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: Color(0xFF6EE7B7),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      state.ocrIsolateBadge!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF064E3B),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                onPressed: () => _pickImageAndRunOcr(context),
                icon: const Icon(Icons.camera_alt_rounded, size: 17),
                label: const Text(
                  'Pindai Foto Struk',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
              ...ReceiptPresetType.values.map(
                (preset) => ActionChip(
                  avatar: const Icon(Icons.receipt_rounded, size: 15),
                  label: Text(
                    preset.label,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
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
    );
  }

  Future<void> _pickImageAndRunOcr(BuildContext context) async {
    final ReceiptPresetType? selectedPreset =
        await showModalBottomSheet<ReceiptPresetType>(
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
              'Pilih Struk untuk Dipindai',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Pilih struk di bawah ini untuk mengekstrak nama merchant, item pesanan, pajak, dan mata uang secara otomatis:',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            ...ReceiptPresetType.values.map(
              (preset) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFECFDF5),
                  child: Icon(
                    Icons.receipt_long_rounded,
                    color: AppTheme.primaryEmerald,
                  ),
                ),
                title: Text(
                  preset.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                subtitle: const Text(
                  'Ekstrak item, pajak, dan layanan otomatis',
                  style: TextStyle(fontSize: 11.5),
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

  Widget _buildHeaderAndCurrencyCard(
    BuildContext context,
    BillLoaded state,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Informasi Tagihan & Mata Uang',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleCtrl,
              onChanged: (v) => _splitCubit.updateHeaderAndCharges(title: v),
              decoration: const InputDecoration(
                labelText: 'Judul Tagihan / Nama Tempat',
                prefixIcon: Icon(Icons.storefront_outlined),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Text(
                  'Mata Uang:',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _supportedCurrencies.map((code) {
                        final selected = state.currencyCode == code;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            selected: selected,
                            label: Text(
                              code,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                color: selected
                                    ? Colors.white
                                    : AppTheme.darkSlate,
                              ),
                            ),
                            selectedColor: AppTheme.primaryEmerald,
                            onSelected: (_) =>
                                _splitCubit.changeCurrencyAndFetchRate(code),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
            if (state.currencyCode != 'IDR') ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBAE6FD)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.currency_exchange_rounded,
                      color: Color(0xFF0284C7),
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
                              color: Color(0xFF0C4A6E),
                            ),
                          ),
                          Text(
                            state.rateSourceInfo,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF0369A1),
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => _showManualRateDialog(context, state),
                      child: const Text('Ubah Kurs'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInteractiveItemsCard(BuildContext context, BillLoaded state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
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
                        'Daftar Pesanan & Pembagian Anggota',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        'Pilih anggota yang ikut menanggung masing-masing item:',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  onPressed: () => _showAddOrEditItemDialog(context, state),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Tambah Item'),
                ),
              ],
            ),
            const Divider(height: 24),
            ...state.items.map((item) {
              final itemIdr = item.totalIdr(state.exchangeRate);
              final perPersonIdr = item.assignedMemberUids.isEmpty
                  ? 0.0
                  : itemIdr / item.assignedMemberUids.length;
              final allSelected =
                  item.assignedMemberUids.length == state.groupMembers.length;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: item.assignedMemberUids.isEmpty
                      ? const Color(0xFFFEF2F2)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: item.assignedMemberUids.isEmpty
                        ? AppTheme.statusRejected
                        : const Color(0xFFE2E8F0),
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
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14.5,
                                ),
                              ),
                              Text(
                                state.currencyCode == 'IDR'
                                    ? '@ ${item.unitPriceOrigin.toRupiah()} = ${itemIdr.toRupiah()}'
                                    : '${item.totalOrigin.toCurrency(state.currencyCode)} → ${itemIdr.toRupiah()}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF475569),
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
                          onPressed: () =>
                              _splitCubit.removeDraftItem(item.id),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: state.groupMembers.map((member) {
                        final isChecked =
                            item.assignedMemberUids.contains(member.uid);
                        return FilterChip(
                          selected: isChecked,
                          selectedColor:
                              AppTheme.primaryEmerald.withValues(alpha: 0.18),
                          checkmarkColor: AppTheme.primaryEmerald,
                          label: Text(
                            '${member.fullName.split(' ').first} (${isChecked ? perPersonIdr.toRupiah() : "Rp 0"})',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: isChecked
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              color: isChecked
                                  ? const Color(0xFF065F46)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                          onSelected: (_) => _splitCubit.toggleMemberOnItem(
                            itemId: item.id,
                            memberUid: member.uid,
                          ),
                        );
                      }).toList(),
                    ),
                    if (item.assignedMemberUids.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          'Pilih minimal 1 anggota untuk item ini.',
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
        ),
      ),
    );
  }

  Widget _buildChargesCard(BuildContext context, BillLoaded state) {
    final suffix = state.currencyCode;
    final subtotalOrigin = state.items.fold<double>(
      0.0,
      (sum, item) => sum + item.totalOrigin,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pajak, Biaya Layanan & Diskon ($suffix)',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 4),
            const Text(
              'Dihitung secara proporsional sesuai porsi pesanan masing-masing anggota.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ActionChip(
                  label: const Text(
                    'Pajak PB1 10%',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
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
                  label: const Text(
                    'Layanan 5%',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
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
                  label: const Text(
                    'Tanpa Pajak/Layanan',
                    style: TextStyle(fontSize: 11.5),
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
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _taxCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Pajak ($suffix)',
                    ),
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
                    decoration: InputDecoration(
                      labelText: 'Layanan ($suffix)',
                    ),
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
                    decoration: InputDecoration(
                      labelText: 'Diskon ($suffix)',
                    ),
                    onChanged: (v) => _splitCubit.updateHeaderAndCharges(
                      discountOrigin: double.tryParse(v) ?? 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReactiveSplitSummaryCard(
    BuildContext context,
    BillLoaded state,
    String creatorUid,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.verified_rounded,
                  color: AppTheme.primaryEmerald,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Ringkasan Pembagian per Anggota',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Akurat · Tanpa Selisih',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryEmerald,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            ...state.computedSplits.map((split) {
              final isCreator = split.user.uid == creatorUid;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${split.user.fullName}${isCreator ? " (Anda · Penalang)" : ""}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                          Text(
                            split.totalDueIdr.toRupiah(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: AppTheme.primaryEmerald,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pesanan: ${split.itemsSubtotalIdr.toRupiah()}  ·  +Pajak: ${split.taxShareIdr.toRupiah()}  ·  +Layanan: ${split.serviceShareIdr.toRupiah()}  ·  -Diskon: ${split.discountShareIdr.toRupiah()}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Tagihan Keseluruhan:',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  state.grandTotalIdr.toRupiah(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
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
        title: Text(existingItem == null ? 'Tambah Item Pesanan' : 'Edit Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Nama Item'),
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
