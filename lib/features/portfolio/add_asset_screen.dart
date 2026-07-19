import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/asset_list.dart';
import '../../shared/models/asset_model.dart';
import '../../shared/models/portfolio_write_target.dart';
import '../../shared/models/tefas_fund_model.dart';
import '../../shared/providers.dart';
import '../../shared/models/transaction_model.dart';
import '../../shared/services/search_service.dart';
import '../../shared/services/supabase_service.dart';
import '../../shared/services/tefas_service.dart';
import '../../shared/services/asset_service.dart';
import '../../shared/services/transaction_service.dart';
import '../../shared/widgets/portfolio_picker.dart';
import 'fund_detail_sheet.dart';

class AddAssetScreen extends ConsumerStatefulWidget {
  const AddAssetScreen({super.key});

  @override
  ConsumerState<AddAssetScreen> createState() => _AddAssetScreenState();
}

class _AddAssetScreenState extends ConsumerState<AddAssetScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Hisse/kripto/döviz arama
  SearchResult? _selectedAsset;
  final _searchController = TextEditingController();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _commissionController = TextEditingController();
  final _platformController = TextEditingController();
  final _noteController = TextEditingController();
  final _customNameController = TextEditingController();
  final _customSymbolController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  List<SearchResult> _searchResults = [];
  bool _isSearching = false;
  bool _isCustom = false;
  bool _isSaving = false;
  String? _targetPortfolioId;

  // Döviz — DB'den dinamik yüklenmiş liste
  List<AssetInfo> _dynamicCurrencies = [];
  bool _isLoadingCurrencies = false;

  // TEFAS / BEFAS fon browser
  List<TefasFund> _tefasFunds = [];
  List<TefasFund> _befasFunds = [];
  bool _isLoadingTefas = false;
  bool _isLoadingBefas = false;
  bool _hasMoreTefas = true;
  bool _hasMoreBefas = true;
  int _tefasPage = 1;
  int _befasPage = 1;
  FundSortOption _tefasSortBy = FundSortOption.nameAsc;
  FundSortOption _befasSortBy = FundSortOption.nameAsc;
  final _fundSearchCtrl = TextEditingController();
  List<TefasFund> _fundSearchResults = [];
  bool _isFundSearching = false;
  bool _showFundSearchResults = false;
  bool _isFetchingFundPrice = false;

  final _tabs = [
    {'label': 'BIST', 'key': 'bist', 'type': AssetType.stock},
    {'label': 'Yabancı/ETF', 'key': 'foreign', 'type': AssetType.stock},
    {'label': 'Kripto', 'key': 'crypto', 'type': AssetType.crypto},
    {'label': 'TEFAS Fonu', 'key': 'tefas', 'type': AssetType.fund},
    {'label': 'BEFAS Fonu', 'key': 'befas', 'type': AssetType.fund},
    {'label': 'Döviz', 'key': 'currency', 'type': AssetType.currency},
    {'label': 'Emtia', 'key': 'commodity', 'type': AssetType.commodity},
    {'label': 'Nakit', 'key': 'cash', 'type': AssetType.cash},
    {'label': 'Gayrimenkul', 'key': 'realestate', 'type': AssetType.realEstate},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    Future.microtask(_loadCurrencies);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedAsset = null;
          _searchController.clear();
          _searchResults = [];
          _isCustom = false;
          _fundSearchCtrl.clear();
          _fundSearchResults = [];
          _showFundSearchResults = false;
          _quantityController.clear();
          _priceController.clear();
          _commissionController.clear();
          _platformController.clear();
          _noteController.clear();
        });
        if (_currentKey == 'tefas' && _tefasFunds.isEmpty) {
          _loadTefasFunds();
        } else if (_currentKey == 'befas' && _befasFunds.isEmpty) {
          _loadBefasFunds();
        } else if (_currentKey == 'currency' && _dynamicCurrencies.isEmpty) {
          _loadCurrencies();
        }
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _commissionController.dispose();
    _platformController.dispose();
    _noteController.dispose();
    _customNameController.dispose();
    _customSymbolController.dispose();
    _fundSearchCtrl.dispose();
    super.dispose();
  }

  String get _currentKey => _tabs[_tabController.index]['key'] as String;
  AssetType get _currentType =>
      _tabs[_tabController.index]['type'] as AssetType;
  bool get _hasSearch => ['bist', 'foreign', 'crypto'].contains(_currentKey);
  bool get _hasPredefined => ['currency', 'commodity'].contains(_currentKey);
  bool get _isManualOnly => ['cash', 'realestate'].contains(_currentKey);
  bool get _isCashTab => _currentKey == 'cash';
  bool get _hasFundList => ['tefas', 'befas'].contains(_currentKey);

  Color get _typeColor {
    switch (_currentKey) {
      case 'bist':
        return AppColors.market;
      case 'foreign':
        return AppColors.market;
      case 'crypto':
        return AppColors.cashFlow;
      case 'tefas':
        return AppColors.planning;
      case 'befas':
        return AppColors.planning;
      case 'currency':
        return AppColors.profit;
      case 'commodity':
        return AppColors.cashFlow;
      case 'cash':
        return AppColors.profit;
      case 'realestate':
        return AppColors.planning;
      default:
        return AppColors.market;
    }
  }

  String get _searchHint {
    switch (_currentKey) {
      case 'bist':
        return 'THYAO, GARAN, AKBNK...';
      case 'foreign':
        return 'AAPL, TSLA, SPY, QQQ...';
      case 'crypto':
        return 'Bitcoin, ETH, Solana...';
      default:
        return 'Ara...';
    }
  }

  String get _quantityLabel {
    switch (_currentKey) {
      case 'bist':
      case 'foreign':
        return 'Lot / Adet';
      case 'crypto':
        return 'Miktar';
      case 'currency':
        return 'Tutar';
      case 'tefas':
      case 'befas':
        return 'Pay Adedi';
      case 'cash':
        return 'Tutar (₺)';
      case 'realestate':
        return 'Metrekare / Adet';
      default:
        return 'Miktar';
    }
  }

  String get _priceLabel {
    switch (_currentKey) {
      case 'bist':
        return 'Alış Fiyatı (₺)';
      case 'foreign':
        return 'Alış Fiyatı (\$)';
      case 'crypto':
        return 'Alış Fiyatı (\$)';
      case 'tefas':
      case 'befas':
        return 'Alış Fiyatı (₺/Pay)';
      case 'currency':
        return 'Kur (₺)';
      case 'cash':
        return 'Birim (₺)';
      case 'realestate':
        return 'Birim Fiyatı (₺)';
      default:
        return 'Fiyat';
    }
  }

  // ──────────────────── Hisse/Kripto Arama ────────────────────

  Future<void> _search(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    // BIST için yerel sonuçları anında göster; API sonuçlarını ardından ekle
    if (_currentKey == 'bist' && query.length >= 2) {
      final local = SearchService.filterBistLocal(query);
      if (local.isNotEmpty) {
        setState(() {
          _searchResults = local;
          _isSearching = true; // API hâlâ yükleniyor olabilir
        });
      } else {
        setState(() => _isSearching = true);
      }
    } else {
      setState(() => _isSearching = true);
    }

    List<SearchResult> results = [];
    switch (_currentKey) {
      case 'bist':
        results = await SearchService.searchBist(query);
        break;
      case 'foreign':
        results = await SearchService.searchForeign(query);
        break;
      case 'crypto':
        results = await SearchService.searchCrypto(query);
        break;
    }
    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  void _selectResult(SearchResult result) {
    setState(() {
      _selectedAsset = result;
      _searchController.text = '${result.symbol} — ${result.name}';
      _searchResults = [];
    });
  }

  void _selectPredefined(AssetInfo asset) {
    setState(() {
      _selectedAsset = SearchResult(
        symbol: asset.symbol,
        name: asset.name,
        apiSource: asset.apiSource,
        apiId: asset.apiId,
        currency: asset.currency,
        type: _currentType,
      );
    });
  }

  // ──────────────────── Döviz Yükleme ────────────────────

  Future<void> _loadCurrencies() async {
    if (_isLoadingCurrencies) return;
    setState(() => _isLoadingCurrencies = true);
    try {
      final data = await supabase
          .from('exchange_rates')
          .select('currency')
          .order('currency', ascending: true);
      final codes = (data as List)
          .map((r) => r['currency'] as String)
          .where((c) => c != 'TRY')
          .toList();
      if (!mounted) return;
      if (codes.isNotEmpty) {
        setState(() {
          _dynamicCurrencies = codes
              .map(AssetList.currencyToAssetInfo)
              .toList();
        });
      } else {
        setState(() {
          _dynamicCurrencies = AssetList.currencies;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _dynamicCurrencies = AssetList.currencies;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingCurrencies = false);
      }
    }
  }

  // ──────────────────── TEFAS/BEFAS Fon Browser ────────────────────

  Future<void> _loadTefasFunds({bool loadMore = false}) async {
    if (_isLoadingTefas) return;
    setState(() => _isLoadingTefas = true);
    try {
      final page = loadMore ? _tefasPage + 1 : 1;
      final result = await TefasService.getFunds(
        page: page,
        isBefas: false,
        sortBy: _tefasSortBy,
      );
      setState(() {
        if (loadMore) {
          _tefasFunds.addAll(result.funds);
          _tefasPage = page;
        } else {
          // Yeni veri geldiyse güncelle; gelmezse mevcut listeyi koru
          if (result.funds.isNotEmpty) {
            _tefasFunds = result.funds;
          }
          _tefasPage = 1;
        }
        if (result.funds.isNotEmpty) {
          _hasMoreTefas = result.hasMore;
        }
        _isLoadingTefas = false;
      });

      // Yeni veri gelmedi VE hiç veri yok → hata göster
      if (!loadMore && _tefasFunds.isEmpty && mounted) {
        final errorMsg =
            TefasService.lastError ?? 'API şu an yanıt döndürmüyor olabilir.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('TEFAS verisi alınamadı: $errorMsg'),
            backgroundColor: AppColors.loss,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoadingTefas = false);
    }
  }

  Future<void> _loadBefasFunds({bool loadMore = false}) async {
    if (_isLoadingBefas) return;
    setState(() => _isLoadingBefas = true);
    try {
      final page = loadMore ? _befasPage + 1 : 1;
      final result = await TefasService.getFunds(
        page: page,
        isBefas: true,
        sortBy: _befasSortBy,
      );
      setState(() {
        if (loadMore) {
          _befasFunds.addAll(result.funds);
          _befasPage = page;
        } else {
          // Yeni veri geldiyse güncelle; gelmezse mevcut listeyi koru
          if (result.funds.isNotEmpty) {
            _befasFunds = result.funds;
          }
          _befasPage = 1;
        }
        if (result.funds.isNotEmpty) {
          _hasMoreBefas = result.hasMore;
        }
        _isLoadingBefas = false;
      });

      // Yeni veri gelmedi VE hiç veri yok → hata göster
      if (!loadMore && _befasFunds.isEmpty && mounted) {
        final errorMsg =
            TefasService.lastError ?? 'API şu an yanıt döndürmüyor olabilir.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('BEFAS verisi alınamadı: $errorMsg'),
            backgroundColor: AppColors.loss,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoadingBefas = false);
    }
  }

  Future<void> _searchFundList(String query) async {
    if (query.length < 2) {
      setState(() {
        _fundSearchResults = [];
        _showFundSearchResults = false;
      });
      return;
    }
    setState(() => _isFundSearching = true);
    final isBefas = _currentKey == 'befas';
    final results = await TefasService.searchFunds(query, isBefas: isBefas);
    setState(() {
      _fundSearchResults = results;
      _showFundSearchResults = true;
      _isFundSearching = false;
    });
  }

  void _openFundDetail(TefasFund fund) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FundDetailSheet(
        fund: fund,
        color: _typeColor,
        onAddToPortfolio: () => _selectFund(fund),
      ),
    );
  }

  void _selectFund(TefasFund fund) async {
    setState(() {
      _selectedAsset = SearchResult(
        symbol: fund.code,
        name: fund.name,
        apiSource: fund.isBefas ? 'befas' : 'tefas',
        apiId: fund.code,
        currency: 'TRY',
        type: AssetType.fund,
      );
      _fundSearchCtrl.clear();
      _fundSearchResults = [];
      _showFundSearchResults = false;
      if (fund.price != null && fund.price! > 0) {
        _priceController.text = fund.price!.toStringAsFixed(
          fund.price! < 1 ? 6 : 4,
        );
        _isFetchingFundPrice = false;
      } else {
        _priceController.clear();
        _isFetchingFundPrice = true;
      }
    });

    // Fiyat listeden gelmediyse API'den çek
    if (fund.price == null || fund.price! <= 0) {
      final price = await TefasService.getFundCurrentPrice(
        fund.code,
        isBefas: fund.isBefas,
      );
      if (!mounted) return;
      setState(() {
        _isFetchingFundPrice = false;
        if (price != null && price > 0) {
          _priceController.text = price.toStringAsFixed(price < 1 ? 6 : 4);
        }
      });
    }
  }

  // ──────────────────── Build ────────────────────

  @override
  Widget build(BuildContext context) {
    final isTotalView = ref.watch(isTotalViewProvider);
    final portfolios = ref.watch(portfoliosProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Varlık Ekle'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Kaydet',
                    style: TextStyle(
                      color: _typeColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: _typeColor,
          unselectedLabelColor: Theme.of(context).textTheme.bodyMedium?.color,
          indicatorColor: _typeColor,
          tabs: _tabs.map((t) => Tab(text: t['label'] as String)).toList(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isTotalView) ...[
              TargetPortfolioField(
                portfolios: portfolios,
                selectedPortfolioId: _targetPortfolioId,
                onChanged: (id) => setState(() => _targetPortfolioId = id),
              ),
              const SizedBox(height: 16),
            ],
            // Hisse/kripto arama
            if (_hasSearch) ...[
              _buildSearchField(context),
              const SizedBox(height: 16),
            ],
            // Döviz/emtia listesi
            if (_hasPredefined && _selectedAsset == null) ...[
              _buildPredefinedList(context),
              const SizedBox(height: 16),
            ],
            // Manuel giriş alanları
            if (_isManualOnly || _isCustom) ...[
              _buildManualFields(context),
              const SizedBox(height: 16),
            ],
            // TEFAS / BEFAS fon browser
            if (_hasFundList && _selectedAsset == null) ...[
              _buildFundBrowser(context),
              const SizedBox(height: 16),
            ],
            // Seçilen varlık kartı
            if (_selectedAsset != null) ...[
              _buildSelectedAsset(context),
              const SizedBox(height: 16),
            ],
            // Form
            if (_selectedAsset != null || _isManualOnly || _isCustom) ...[
              _buildTransactionDetails(context),
              const SizedBox(height: 16),
              _buildExtraDetails(context),
              const SizedBox(height: 16),
              _buildTotalSummary(context),
            ],
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  // ──────────────────── Hisse/Kripto Arama Widget ────────────────────

  Widget _buildSearchField(BuildContext context) {
    final popular = AssetList.getPopular(_currentKey);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          onChanged: _search,
          decoration: InputDecoration(
            hintText: _searchHint,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _isSearching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchResults = [];
                        _selectedAsset = null;
                      });
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Theme.of(context).dividerColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Theme.of(context).dividerColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: _typeColor, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
          ),
        ),
        if (_searchResults.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _searchResults.length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, color: Theme.of(context).dividerColor),
              itemBuilder: (context, index) {
                final r = _searchResults[index];
                return ListTile(
                  dense: true,
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _typeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        r.symbol.length > 3
                            ? r.symbol.substring(0, 3)
                            : r.symbol,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _typeColor,
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    r.symbol,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: Text(
                    r.name,
                    style: const TextStyle(fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _typeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      r.currency,
                      style: TextStyle(
                        fontSize: 10,
                        color: _typeColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  onTap: () => _selectResult(r),
                );
              },
            ),
          )
        else if (_searchController.text.isEmpty &&
            popular.isNotEmpty &&
            _selectedAsset == null) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _currentKey == 'bist'
                    ? 'Popüler BIST Hisseleri'
                    : _currentKey == 'foreign'
                    ? 'Popüler Hisse & ETF'
                    : 'Popüler Kripto Paralar',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${popular.length} varlık',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: popular.length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, color: Theme.of(context).dividerColor),
              itemBuilder: (ctx, i) {
                final a = popular[i];
                final sym = a.symbol.length > 5
                    ? a.symbol.substring(0, 5)
                    : a.symbol;
                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _typeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        sym,
                        style: TextStyle(
                          fontSize: sym.length > 4 ? 9 : 10,
                          fontWeight: FontWeight.w800,
                          color: _typeColor,
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    a.symbol,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: Text(
                    a.name,
                    style: const TextStyle(fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _typeColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      a.currency,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _typeColor,
                      ),
                    ),
                  ),
                  onTap: () => _selectPredefined(a),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  // ──────────────────── TEFAS/BEFAS Fon Browser Widget ────────────────────

  Widget _buildFundBrowser(BuildContext context) {
    final isBefas = _currentKey == 'befas';
    final funds = isBefas ? _befasFunds : _tefasFunds;
    final isLoading = isBefas ? _isLoadingBefas : _isLoadingTefas;
    final hasMore = isBefas ? _hasMoreBefas : _hasMoreTefas;
    final displayFunds = _showFundSearchResults ? _fundSearchResults : funds;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Arama kutusu
        TextField(
          controller: _fundSearchCtrl,
          onChanged: _searchFundList,
          decoration: InputDecoration(
            hintText: isBefas
                ? 'BEFAS fon kodu veya adıyla ara...'
                : 'TEFAS fon kodu veya adıyla ara...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _isFundSearching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : _fundSearchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _fundSearchCtrl.clear();
                      setState(() {
                        _fundSearchResults = [];
                        _showFundSearchResults = false;
                      });
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Theme.of(context).dividerColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Theme.of(context).dividerColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: _typeColor, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Sıralama seçenekleri
        if (!_showFundSearchResults)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildSortChip('İsim A-Z', FundSortOption.nameAsc, isBefas),
                const SizedBox(width: 6),
                _buildSortChip('Kod A-Z', FundSortOption.codeAsc, isBefas),
                const SizedBox(width: 6),
                _buildSortChip('Fiyat ↓', FundSortOption.priceDesc, isBefas),
                const SizedBox(width: 6),
                _buildSortChip(
                  '1Y Getiri ↓',
                  FundSortOption.return1YearDesc,
                  isBefas,
                ),
                const SizedBox(width: 6),
                _buildSortChip(
                  'Büyüklük ↓',
                  FundSortOption.totalSizeDesc,
                  isBefas,
                ),
              ],
            ),
          ),
        const SizedBox(height: 10),

        // İlk yüklenme spinner
        if (isLoading && funds.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  CircularProgressIndicator(color: _typeColor),
                  const SizedBox(height: 12),
                  Text(
                    'Fonlar yükleniyor...',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  ),
                ],
              ),
            ),
          )
        // İlk açılışta henüz yüklenmedi
        else if (funds.isEmpty && !isLoading && !_showFundSearchResults) ...[
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Icon(
                    Icons.account_balance_outlined,
                    size: 48,
                    color: _typeColor.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isBefas ? 'BEFAS Fonları' : 'TEFAS Fonları',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _typeColor,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Fonları listelemek için dokunun',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: isBefas
                        ? () => _loadBefasFunds()
                        : () => _loadTefasFunds(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Fonları Yükle'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _typeColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ]
        // Arama sonucu yok
        else if (_showFundSearchResults &&
            _fundSearchResults.isEmpty &&
            !_isFundSearching)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                '"${_fundSearchCtrl.text}" için sonuç bulunamadı',
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
            ),
          )
        // Fon listesi
        else ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _showFundSearchResults
                    ? '${_fundSearchResults.length} sonuç'
                    : '${funds.length} fon listeleniyor',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[500],
                  fontSize: 11,
                ),
              ),
              Text(
                'Detay için tıklayın',
                style: TextStyle(
                  fontSize: 11,
                  color: _typeColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...displayFunds.map((fund) => _buildFundItem(fund)),
          if (!_showFundSearchResults) ...[
            if (isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (hasMore)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => isBefas
                        ? _loadBefasFunds(loadMore: true)
                        : _loadTefasFunds(loadMore: true),
                    icon: const Icon(Icons.expand_more),
                    label: const Text('Daha Fazla Yükle'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _typeColor,
                      side: BorderSide(
                        color: _typeColor.withValues(alpha: 0.4),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ],
    );
  }

  Widget _buildSortChip(String label, FundSortOption option, bool isBefas) {
    final current = isBefas ? _befasSortBy : _tefasSortBy;
    final isSelected = current == option;
    return GestureDetector(
      onTap: () {
        if (isSelected) return;
        setState(() {
          if (isBefas) {
            _befasSortBy = option;
            _befasFunds = [];
            _befasPage = 1;
            _hasMoreBefas = true;
          } else {
            _tefasSortBy = option;
            _tefasFunds = [];
            _tefasPage = 1;
            _hasMoreTefas = true;
          }
        });
        if (isBefas) {
          _loadBefasFunds();
        } else {
          _loadTefasFunds();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? _typeColor.withValues(alpha: 0.15)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _typeColor : Theme.of(context).dividerColor,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
            color: isSelected
                ? _typeColor
                : Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
      ),
    );
  }

  Widget _buildFundItem(TefasFund fund) {
    final r1y = fund.return1Year;
    final hasReturn = r1y != null;
    final positive = hasReturn && r1y >= 0;
    final returnColor = positive
        ? AppColors.profitFor(Theme.of(context).brightness)
        : const Color(0xFFFF1744);

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openFundDetail(fund),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Fon kodu badge
              Container(
                width: 52,
                height: 40,
                decoration: BoxDecoration(
                  color: _typeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    fund.code.length > 4
                        ? fund.code.substring(0, 4)
                        : fund.code,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _typeColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // İsim ve tür
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fund.name.isNotEmpty ? fund.name : fund.code,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (fund.type != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        fund.type!,
                        style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Sağ taraf: fiyat + 1Y getiri
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (fund.price != null)
                    Text(
                      '₺${fund.price!.toStringAsFixed(fund.price! < 1 ? 4 : 2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  if (fund.price == null)
                    Text(
                      'Detay için dokun',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[500],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  if (hasReturn) ...[
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: returnColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${positive ? '+' : ''}${r1y.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: returnColor,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right, size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────── Döviz/Emtia Listesi ────────────────────

  Widget _buildPredefinedList(BuildContext context) {
    final List<AssetInfo> list;
    if (_currentKey == 'currency') {
      if (_isLoadingCurrencies) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: CircularProgressIndicator(),
          ),
        );
      }
      list = _dynamicCurrencies.isNotEmpty
          ? _dynamicCurrencies
          : AssetList.currencies;
    } else {
      list = AssetList.getPopular(_currentKey);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Seç',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              '${list.length} ${_currentKey == 'currency' ? 'döviz' : 'emtia'}',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...list.map(
          (a) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _typeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    a.symbol.length > 3 ? a.symbol.substring(0, 3) : a.symbol,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: _typeColor,
                    ),
                  ),
                ),
              ),
              title: Text(
                a.symbol,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(a.name),
              trailing: Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: _typeColor,
              ),
              onTap: () => _selectPredefined(a),
            ),
          ),
        ),
      ],
    );
  }

  // ──────────────────── Seçili Varlık Kartı ────────────────────

  Widget _buildSelectedAsset(BuildContext context) {
    final asset = _selectedAsset!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _typeColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _typeColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _typeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                asset.symbol.length > 4
                    ? asset.symbol.substring(0, 4)
                    : asset.symbol,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: _typeColor,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  asset.symbol,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                Text(
                  asset.name,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _typeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    asset.apiSource.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      color: _typeColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => setState(() {
              _selectedAsset = null;
              _searchController.clear();
              _priceController.clear();
            }),
          ),
        ],
      ),
    );
  }

  // ──────────────────── Manuel Giriş ────────────────────

  Widget _buildManualFields(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildTextField(
              _customSymbolController,
              _isCashTab ? 'Etiket (opsiyonel)' : 'Sembol / Kod',
              _isCashTab ? 'örn. Cüzdan, Akbank, Ziraat' : 'örn. THYAO',
              required: !_isCashTab,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              _customNameController,
              _isCashTab ? 'Açıklama (opsiyonel)' : 'Varlık Adı',
              _isCashTab
                  ? 'örn. Vadesiz Hesap, Nakit'
                  : 'örn. Türk Hava Yolları',
              required: !_isCashTab,
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────── İşlem Detayları ────────────────────

  Widget _buildTransactionDetails(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'İşlem Detayları',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (_isCashTab)
                  // Nakit için sadece tutar alanı — birim fiyat sabit 1 TRY
                  _buildTextField(
                    _quantityController,
                    _quantityLabel,
                    '0,00',
                    isNumber: true,
                    required: true,
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          _quantityController,
                          _quantityLabel,
                          '0',
                          isNumber: true,
                          required: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          _priceController,
                          _priceLabel,
                          _isFetchingFundPrice ? 'Yükleniyor...' : '0,00',
                          isNumber: true,
                          required: true,
                          suffixIcon: _isFetchingFundPrice
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        _commissionController,
                        'Komisyon (opsiyonel)',
                        '0,00',
                        isNumber: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: _buildDatePicker(context)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExtraDetails(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ek Bilgiler',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildTextField(
                  _platformController,
                  'Platform / Aracı Kurum',
                  'örn. İş Yatırım, Binance',
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  _noteController,
                  'Not (opsiyonel)',
                  'Bu işlem hakkında bir not...',
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTotalSummary(BuildContext context) {
    final quantity =
        double.tryParse(_quantityController.text.replaceAll(',', '.')) ?? 0;
    // Nakit için birim fiyat sabit 1 TRY; diğerleri için kullanıcı girer.
    final price = _isCashTab
        ? 1.0
        : (double.tryParse(_priceController.text.replaceAll(',', '.')) ?? 0);
    final commission =
        double.tryParse(_commissionController.text.replaceAll(',', '.')) ?? 0;
    final total = (quantity * price) + commission;
    return Card(
      color: _typeColor.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Toplam Maliyet',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              '₺${total.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _typeColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    String hint, {
    bool isNumber = false,
    bool required = false,
    int maxLines = 1,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      inputFormatters: isNumber
          ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))]
          : null,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _typeColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
      validator: required
          ? (v) => (v == null || v.isEmpty) ? '$label zorunlu' : null
          : null,
    );
  }

  Widget _buildDatePicker(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime(2000),
          lastDate: DateTime.now(),
        );
        if (picked != null) setState(() => _selectedDate = picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined, size: 16, color: _typeColor),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tarih',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  '${_selectedDate.day}.${_selectedDate.month}.${_selectedDate.year}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────── Kaydet ────────────────────

  Future<void> _save() async {
    final isManual = _isManualOnly || _isCustom;
    if (!isManual && _selectedAsset == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen bir varlık seçin'),
          backgroundColor: AppColors.loss,
        ),
      );
      return;
    }
    // Nakit için sadece tutar zorunlu; diğerleri için tutar + fiyat zorunlu.
    if (_quantityController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tutar zorunlu'),
          backgroundColor: AppColors.loss,
        ),
      );
      return;
    }
    if (!_isCashTab && _priceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Miktar ve fiyat zorunlu'),
          backgroundColor: AppColors.loss,
        ),
      );
      return;
    }

    final rawName = isManual
        ? _customNameController.text
        : _selectedAsset!.name;
    final name = (_isCashTab && rawName.isEmpty) ? 'Nakit' : rawName;
    // Nakit için sembol boş bırakılırsa 'NAKİT' varsayılan değeri kullan.
    final rawSymbol = isManual
        ? _customSymbolController.text.toUpperCase()
        : _selectedAsset!.symbol;
    final symbol = (_isCashTab && rawSymbol.isEmpty) ? 'NAKİT' : rawSymbol;
    final apiSource = isManual ? 'manual' : _selectedAsset!.apiSource;
    final apiId = isManual ? null : _selectedAsset!.apiId;
    final currency = isManual ? 'TRY' : _selectedAsset!.currency;
    final type = isManual ? _currentType : _selectedAsset!.type;
    final portfolioId = resolveWritePortfolioId(
      activePortfolioId: ref.read(activePortfolioProvider),
      selectedPortfolioId: _targetPortfolioId,
    );
    if (portfolioId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('İşlemin kaydedileceği portföyü seçin'),
          backgroundColor: AppColors.loss,
        ),
      );
      return;
    }

    final buyPrice = _isCashTab
        ? 1.0
        : double.parse(_priceController.text.replaceAll(',', '.'));

    final asset = AssetModel(
      id: '',
      portfolioId: portfolioId,
      name: name,
      symbol: symbol,
      type: type,
      quantity: double.parse(_quantityController.text.replaceAll(',', '.')),
      buyPrice: buyPrice,
      buyDate: _selectedDate,
      platform: _platformController.text.isEmpty
          ? null
          : _platformController.text,
      commission: _commissionController.text.isEmpty
          ? null
          : double.parse(_commissionController.text.replaceAll(',', '.')),
      note: _noteController.text.isEmpty ? null : _noteController.text,
      apiSource: apiSource,
      apiId: apiId,
      currency: currency,
    );

    setState(() => _isSaving = true);
    AssetModel? savedAsset;
    var transactionSaved = false;
    try {
      final saved = await AssetService.save(asset);
      savedAsset = saved;

      // Alış işlemini geçmişe kaydet
      final buyTx = TransactionModel(
        id: '',
        assetId: saved.id,
        type: TransactionType.buy,
        quantity: saved.quantity,
        price: saved.buyPrice,
        commission: saved.commission,
        date: saved.buyDate,
        note: saved.note,
        symbol: saved.symbol,
        assetName: saved.name,
      );
      await TransactionService.save(buyTx);
      transactionSaved = true;
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Varlık eklendi!'),
          backgroundColor: AppColors.profit,
        ),
      );
    } catch (_) {
      if (savedAsset != null && !transactionSaved) {
        try {
          await AssetService.delete(savedAsset.id);
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Varlık ekleme tamamlanamadı. Portföyü yenileyip kontrol edin',
          ),
          backgroundColor: AppColors.loss,
        ),
      );
    }
  }
}
