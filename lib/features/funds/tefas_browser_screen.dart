import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/tefas_fund_model.dart';
import '../../shared/services/tefas_service.dart';
import '../portfolio/fund_detail_sheet.dart';
import '../portfolio/add_asset_screen.dart';

class TefasBrowserScreen extends StatefulWidget {
  const TefasBrowserScreen({super.key});

  @override
  State<TefasBrowserScreen> createState() => _TefasBrowserScreenState();
}

class _TefasBrowserScreenState extends State<TefasBrowserScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // TEFAS
  final List<TefasFund> _tefasFunds = [];
  bool _tefasLoading = false;
  bool _tefasHasMore = true;
  int _tefasPage = 1;
  FundSortOption _tefasSortBy = FundSortOption.nameAsc;
  final _tefasSearchCtrl = TextEditingController();
  List<TefasFund>? _tefasSearchResults;
  bool _tefasSearching = false;

  // BEFAS
  final List<TefasFund> _befasFunds = [];
  bool _befasLoading = false;
  bool _befasHasMore = true;
  int _befasPage = 1;
  FundSortOption _befasSortBy = FundSortOption.nameAsc;
  final _befasSearchCtrl = TextEditingController();
  List<TefasFund>? _befasSearchResults;
  bool _befasSearching = false;

  // Scroll controllers for infinite scroll
  final _tefasScrollCtrl = ScrollController();
  final _befasScrollCtrl = ScrollController();

  static const Color _tefasColor = AppColors.primary;
  static const Color _befasColor = Color(0xFF5E35B1);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _tefasScrollCtrl.addListener(_onTefasScroll);
    _befasScrollCtrl.addListener(_onBefasScroll);
    _loadTefas();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _tefasSearchCtrl.dispose();
    _befasSearchCtrl.dispose();
    _tefasScrollCtrl.dispose();
    _befasScrollCtrl.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    if (_tabController.index == 1 && _befasFunds.isEmpty) {
      _loadBefas();
    }
  }

  void _onTefasScroll() {
    if (_tefasScrollCtrl.position.pixels >=
            _tefasScrollCtrl.position.maxScrollExtent - 200 &&
        !_tefasLoading &&
        _tefasHasMore &&
        _tefasSearchResults == null) {
      _loadTefas();
    }
  }

  void _onBefasScroll() {
    if (_befasScrollCtrl.position.pixels >=
            _befasScrollCtrl.position.maxScrollExtent - 200 &&
        !_befasLoading &&
        _befasHasMore &&
        _befasSearchResults == null) {
      _loadBefas();
    }
  }

  Future<void> _loadTefas() async {
    if (_tefasLoading || !_tefasHasMore) return;
    setState(() => _tefasLoading = true);
    final result = await TefasService.getFunds(
      page: _tefasPage,
      size: 50,
      isBefas: false,
      sortBy: _tefasSortBy,
    );
    if (mounted) {
      setState(() {
        _tefasFunds.addAll(result.funds);
        _tefasHasMore = result.hasMore;
        _tefasPage++;
        _tefasLoading = false;
      });
    }
  }

  Future<void> _loadBefas() async {
    if (_befasLoading || !_befasHasMore) return;
    setState(() => _befasLoading = true);
    final result = await TefasService.getFunds(
      page: _befasPage,
      size: 50,
      isBefas: true,
      sortBy: _befasSortBy,
    );
    if (mounted) {
      setState(() {
        _befasFunds.addAll(result.funds);
        _befasHasMore = result.hasMore;
        _befasPage++;
        _befasLoading = false;
      });
    }
  }

  void _changeTefasSort(FundSortOption sort) {
    if (_tefasSortBy == sort) return;
    setState(() {
      _tefasSortBy = sort;
      _tefasFunds.clear();
      _tefasPage = 1;
      _tefasHasMore = true;
    });
    _loadTefas();
  }

  void _changeBefasSort(FundSortOption sort) {
    if (_befasSortBy == sort) return;
    setState(() {
      _befasSortBy = sort;
      _befasFunds.clear();
      _befasPage = 1;
      _befasHasMore = true;
    });
    _loadBefas();
  }

  Future<void> _searchTefas(String query) async {
    if (query.trim().length < 2) {
      setState(() => _tefasSearchResults = null);
      return;
    }
    setState(() => _tefasSearching = true);
    final results = await TefasService.searchFunds(query, isBefas: false);
    if (mounted) {
      setState(() {
        _tefasSearchResults = results;
        _tefasSearching = false;
      });
    }
  }

  Future<void> _searchBefas(String query) async {
    if (query.trim().length < 2) {
      setState(() => _befasSearchResults = null);
      return;
    }
    setState(() => _befasSearching = true);
    final results = await TefasService.searchFunds(query, isBefas: true);
    if (mounted) {
      setState(() {
        _befasSearchResults = results;
        _befasSearching = false;
      });
    }
  }

  Future<void> _refreshAll() async {
    setState(() {
      _tefasFunds.clear();
      _befasFunds.clear();
      _tefasPage = 1;
      _befasPage = 1;
      _tefasHasMore = true;
      _befasHasMore = true;
      _tefasSearchResults = null;
      _befasSearchResults = null;
      _tefasSearchCtrl.clear();
      _befasSearchCtrl.clear();
    });
    await Future.wait([_loadTefas(), _loadBefas()]);
  }

  void _openDetail(TefasFund fund) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FundDetailSheet(
        fund: fund,
        color: fund.isBefas ? _befasColor : _tefasColor,
        onAddToPortfolio: () {
          // Detail sheet'i kapat, sonra AddAssetScreen'e yönlendir
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddAssetScreen()),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Fon Piyasası',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Yenile',
            onPressed: _refreshAll,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'TEFAS'),
            Tab(text: 'BEFAS (Emeklilik)'),
          ],
          indicatorColor: _tefasColor,
          labelColor: _tefasColor,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _FundList(
            funds: _tefasSearchResults ?? _tefasFunds,
            isLoading: _tefasLoading,
            isSearching: _tefasSearching,
            hasMore: _tefasHasMore && _tefasSearchResults == null,
            searchCtrl: _tefasSearchCtrl,
            scrollCtrl: _tefasScrollCtrl,
            color: _tefasColor,
            isBefas: false,
            onSearch: _searchTefas,
            onTap: _openDetail,
            sortBy: _tefasSortBy,
            onSortChanged: _changeTefasSort,
            showSortBar: _tefasSearchResults == null,
          ),
          _FundList(
            funds: _befasSearchResults ?? _befasFunds,
            isLoading: _befasLoading,
            isSearching: _befasSearching,
            hasMore: _befasHasMore && _befasSearchResults == null,
            searchCtrl: _befasSearchCtrl,
            scrollCtrl: _befasScrollCtrl,
            color: _befasColor,
            isBefas: true,
            onSearch: _searchBefas,
            onTap: _openDetail,
            sortBy: _befasSortBy,
            onSortChanged: _changeBefasSort,
            showSortBar: _befasSearchResults == null,
          ),
        ],
      ),
    );
  }
}

// ──────────────────────── Fund List Widget ────────────────────────

class _FundList extends StatelessWidget {
  final List<TefasFund> funds;
  final bool isLoading;
  final bool isSearching;
  final bool hasMore;
  final TextEditingController searchCtrl;
  final ScrollController scrollCtrl;
  final Color color;
  final bool isBefas;
  final ValueChanged<String> onSearch;
  final ValueChanged<TefasFund> onTap;
  final FundSortOption sortBy;
  final ValueChanged<FundSortOption> onSortChanged;
  final bool showSortBar;

  const _FundList({
    required this.funds,
    required this.isLoading,
    required this.isSearching,
    required this.hasMore,
    required this.searchCtrl,
    required this.scrollCtrl,
    required this.color,
    required this.isBefas,
    required this.onSearch,
    required this.onTap,
    this.sortBy = FundSortOption.nameAsc,
    required this.onSortChanged,
    this.showSortBar = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Arama Çubuğu
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: searchCtrl,
            onChanged: onSearch,
            decoration: InputDecoration(
              hintText: 'Fon kodu veya adı ile ara...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        searchCtrl.clear();
                        onSearch('');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),

        // Sıralama Çubuğu
        if (showSortBar)
          _SortBar(current: sortBy, color: color, onChanged: onSortChanged),

        // Liste
        Expanded(
          child: isLoading && funds.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : isSearching
              ? const Center(child: CircularProgressIndicator())
              : funds.isEmpty
              ? _EmptyState(isBefas: isBefas)
              : ListView.builder(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: funds.length + (hasMore ? 1 : 0),
                  itemBuilder: (ctx, i) {
                    if (i == funds.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    return _FundCard(
                      fund: funds[i],
                      color: color,
                      onTap: () => onTap(funds[i]),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ──────────────────────── Fund Card ────────────────────────

class _FundCard extends StatelessWidget {
  final TefasFund fund;
  final Color color;
  final VoidCallback onTap;

  const _FundCard({
    required this.fund,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ret1m = fund.return1Month;
    final ret1y = fund.return1Year;
    final retYtd = fund.returnYtd;

    // En anlamlı getiriyi öne çıkar
    final mainRet = ret1m ?? retYtd ?? ret1y;
    final mainLabel = ret1m != null
        ? '1 Ay'
        : retYtd != null
        ? 'YBB'
        : '1 Yıl';

    final positive = (mainRet ?? 0) >= 0;
    final retColor = positive
        ? const Color(0xFF00C853)
        : const Color(0xFFFF1744);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Fon Kodu Rozeti
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  fund.code,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Fon Adı ve Kategori
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fund.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (fund.category != null || fund.type != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        fund.category ?? fund.type ?? '',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Getiri
              if (mainRet != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: retColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${positive ? '+' : ''}${mainRet.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: retColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      mainLabel,
                      style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                    ),
                  ],
                )
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────── Sort Bar ────────────────────────

class _SortBar extends StatelessWidget {
  final FundSortOption current;
  final Color color;
  final ValueChanged<FundSortOption> onChanged;

  const _SortBar({
    required this.current,
    required this.color,
    required this.onChanged,
  });

  static const _options = [
    (label: 'İsim A-Z', option: FundSortOption.nameAsc),
    (label: 'Kod A-Z', option: FundSortOption.codeAsc),
    (label: 'Fiyat ↓', option: FundSortOption.priceDesc),
    (label: '1Y Getiri ↓', option: FundSortOption.return1YearDesc),
    (label: 'Büyüklük ↓', option: FundSortOption.totalSizeDesc),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final item = _options[i];
          final selected = current == item.option;
          return GestureDetector(
            onTap: () => onChanged(item.option),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: selected
                    ? color.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? color : Colors.grey.withValues(alpha: 0.35),
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Text(
                item.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  color: selected ? color : Colors.grey[600],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ──────────────────────── Empty State ────────────────────────

class _EmptyState extends StatelessWidget {
  final bool isBefas;
  const _EmptyState({required this.isBefas});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isBefas
                  ? Icons.account_balance_outlined
                  : Icons.pie_chart_outline,
              size: 56,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              isBefas ? 'BEFAS fonu bulunamadı' : 'TEFAS fonu bulunamadı',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              'Veriler yüklenirken lütfen bekleyin\nveya yenile butonuna basın.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}
