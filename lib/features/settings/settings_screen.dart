import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/providers.dart';
import '../../shared/models/portfolio_model.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/services/portfolio_service.dart';
import '../../shared/services/supabase_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String? _syncCode;
  DateTime? _lastPriceUpdate;

  @override
  void initState() {
    super.initState();
    _loadSyncCode();
    _loadLastPriceUpdate();
  }

  Future<void> _loadSyncCode() async {
    final code = await PortfolioService.getSyncCode();
    if (mounted) setState(() => _syncCode = code);
  }

  Future<void> _loadLastPriceUpdate() async {
    try {
      final data = await supabase
          .from('prices')
          .select('updated_at')
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (data != null && mounted) {
        setState(() {
          _lastPriceUpdate = DateTime.parse(data['updated_at'] as String);
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final activePortfolio = ref.watch(activePortfolioProvider);
    final portfolios = ref.watch(portfoliosProvider);
    final currency = ref.watch(currencyProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = AppColors.accentFor(Theme.of(context).brightness);

    final activePortfolioData = portfolios.firstWhere(
      (p) => p.id == activePortfolio,
      orElse: () => PortfolioModel(
        id: '',
        userId: '',
        name: 'Portföy',
        emoji: '💼',
        createdAt: DateTime.now(),
      ),
    );

    final updateStr = _lastPriceUpdate == null
        ? 'Henüz güncellenmedi'
        : '${_lastPriceUpdate!.toLocal().day}.${_lastPriceUpdate!.toLocal().month}.${_lastPriceUpdate!.toLocal().year} '
              '${_lastPriceUpdate!.toLocal().hour.toString().padLeft(2, '0')}:'
              '${_lastPriceUpdate!.toLocal().minute.toString().padLeft(2, '0')}';

    final bg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  'Ayarlar',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.2,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Aktif Portföy ──
              _buildPortfolioHeroCard(context, activePortfolioData, isDark),
              const SizedBox(height: 24),

              // ── Hesap Senkronizasyonu ──
              _sectionLabel(
                'Hesap Senkronizasyonu',
                Icons.sync_rounded,
                accent,
                isDark,
              ),
              const SizedBox(height: 8),
              _buildSyncCard(context, isDark, bg, border),
              const SizedBox(height: 20),

              // ── Görünüm ──
              _sectionLabel(
                'Görünüm',
                Icons.palette_outlined,
                AppColors.planning,
                isDark,
              ),
              const SizedBox(height: 8),
              _settingsCard(
                isDark,
                bg,
                border,
                children: [
                  _settingRow(
                    context,
                    isDark,
                    Icons.contrast_rounded,
                    AppColors.planning,
                    'Tema',
                    'Uygulama görünüm modu',
                  ),
                  const SizedBox(height: 12),
                  _buildThemeToggle(context, themeMode, isDark),
                  _settingDivider(isDark),
                  _settingRow(
                    context,
                    isDark,
                    Icons.currency_exchange_rounded,
                    AppColors.gold,
                    'Para Birimi',
                    'Değer gösterim birimi',
                  ),
                  const SizedBox(height: 12),
                  _buildCurrencyToggle(context, currency, isDark),
                ],
              ),
              const SizedBox(height: 20),

              // ── Portföy ──
              _sectionLabel(
                'Portföy',
                Icons.pie_chart_outline,
                AppColors.market,
                isDark,
              ),
              const SizedBox(height: 8),
              _settingsCard(
                isDark,
                bg,
                border,
                children: [
                  Row(
                    children: [
                      _iconBox(Icons.update_rounded, AppColors.market),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Son Fiyat Güncellemesi',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: isDark
                                    ? AppColors.darkText
                                    : AppColors.lightText,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              updateStr,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _iconBox(
                        Icons.cloud_done_rounded,
                        AppColors.profitFor(Theme.of(context).brightness),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Portföyler ──
              _sectionLabel(
                'Portföyler',
                Icons.person_outline_rounded,
                AppColors.market,
                isDark,
              ),
              const SizedBox(height: 8),
              _settingsCard(
                isDark,
                bg,
                border,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                children: [
                  ...portfolios.asMap().entries.map((entry) {
                    final i = entry.key;
                    final p = entry.value;
                    final isActive = p.id == activePortfolio;
                    return Column(
                      children: [
                        if (i > 0)
                          Divider(
                            height: 1,
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                          ),
                        _buildPortfolioTile(context, p, isActive, isDark),
                      ],
                    );
                  }),
                  Divider(
                    height: 1,
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: _iconBox(Icons.add_rounded, AppColors.market),
                    title: const Text(
                      'Yeni Portföy Ekle',
                      style: TextStyle(
                        color: AppColors.market,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    onTap: () => _showAddPortfolioSheet(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Hakkında ──
              _sectionLabel(
                'Hakkında',
                Icons.info_outline_rounded,
                AppColors.silver,
                isDark,
              ),
              const SizedBox(height: 8),
              _settingsCard(
                isDark,
                bg,
                border,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: _iconBox(Icons.apps_rounded, accent),
                    title: Text(
                      'Fidus',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: isDark
                            ? AppColors.darkText
                            : AppColors.lightText,
                      ),
                    ),
                    subtitle: Text(
                      'Versiyon 1.0.0',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: _iconBox(
                      Icons.lock_outline_rounded,
                      AppColors.profitFor(Theme.of(context).brightness),
                    ),
                    title: Text(
                      'Gizlilik',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: isDark
                            ? AppColors.darkText
                            : AppColors.lightText,
                      ),
                    ),
                    subtitle: Text(
                      'Veriler şifreli olarak Fidus sunucusunda saklanır',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Tehlikeli Bölge ──
              _sectionLabel(
                'Tehlikeli Bölge',
                Icons.warning_amber_rounded,
                AppColors.loss,
                isDark,
              ),
              const SizedBox(height: 8),
              _settingsCard(
                isDark,
                bg,
                border,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: _iconBox(
                      Icons.delete_forever_rounded,
                      AppColors.loss,
                    ),
                    title: const Text(
                      'Tüm Verileri Sil',
                      style: TextStyle(
                        color: AppColors.loss,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      'Bu işlem geri alınamaz',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                    onTap: () => _confirmClearAll(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────── Sync Card ───────────────
  Widget _buildSyncCard(
    BuildContext context,
    bool isDark,
    Color bg,
    Color border,
  ) {
    final accent = AppColors.accentFor(Theme.of(context).brightness);
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBox(Icons.vpn_key_rounded, accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Senkronizasyon Kodun',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: isDark
                            ? AppColors.darkText
                            : AppColors.lightText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Bu kodu başka cihazda girerek hesabını aç',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () {
              if (_syncCode != null) {
                Clipboard.setData(ClipboardData(text: _syncCode!));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Kod kopyalandı'),
                    backgroundColor: accent,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accent.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _syncCode ?? '••••-••••-••••',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3,
                      color: accent,
                      fontFamily: 'monospace',
                    ),
                  ),
                  Icon(
                    Icons.copy_rounded,
                    size: 18,
                    color: accent.withValues(alpha: 0.7),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showSyncCodeEntry(context),
              icon: const Icon(Icons.smartphone_rounded, size: 16),
              label: const Text('Başka Cihazdan Hesap Aktar'),
              style: OutlinedButton.styleFrom(
                foregroundColor: accent,
                side: BorderSide(color: accent.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSyncCodeEntry(BuildContext context) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hesap Aktarma',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Mevcut veriler silinecek ve girdiğin hesaptaki veriler yüklenecek.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Senkronizasyon Kodu',
                  hintText: 'XXXX-XXXX-XXXX',
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final code = controller.text.trim().toUpperCase();
                    if (code.length < 12) return;
                    Navigator.pop(ctx);
                    await _transferAccount(context, code);
                  },
                  child: const Text('Hesabı Aktar'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _transferAccount(BuildContext context, String code) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Emin misin?',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Bu cihazdaki mevcut veriler silinecek ve girilen hesap yüklenecek. Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Devam Et',
              style: TextStyle(
                color: AppColors.accentFor(Theme.of(ctx).brightness),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final success = await AuthService.signInWithCode(code);
    if (!context.mounted) return;

    if (success) {
      ref.invalidate(activePortfolioProvider);
      ref.invalidate(portfoliosProvider);
      ref.invalidate(assetsProvider);
      ref.invalidate(cashflowProvider);
      ref.invalidate(goalsProvider);
      ref.invalidate(transactionsProvider);
      await _loadSyncCode();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hesap başarıyla aktarıldı'),
          backgroundColor: AppColors.profit,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kod bulunamadı. Doğru kodu girdiğinden emin ol.'),
          backgroundColor: AppColors.loss,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ─────────────── Helpers ───────────────

  Widget _settingsCard(
    bool isDark,
    Color bg,
    Color border, {
    required List<Widget> children,
    EdgeInsetsGeometry? padding,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  Widget _sectionLabel(String title, IconData icon, Color color, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 6),
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _iconBox(IconData icon, Color color) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }

  Widget _settingRow(
    BuildContext context,
    bool isDark,
    IconData icon,
    Color color,
    String title,
    String subtitle,
  ) {
    return Row(
      children: [
        _iconBox(icon, color),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _settingDivider(bool isDark) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Divider(
      height: 1,
      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
    ),
  );

  // ─────────────── Portfolio Hero Card ───────────────
  Widget _buildPortfolioHeroCard(
    BuildContext context,
    PortfolioModel portfolio,
    bool isDark,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF145078), const Color(0xFF00A87E)]
              : [const Color(0xFF0A7A66), const Color(0xFF0EC9A0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? const Color(0xFF003F4C) : AppColors.lightPrimary)
                .withValues(alpha: isDark ? 0.5 : 0.22),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Center(
              child: Text(
                portfolio.emoji,
                style: const TextStyle(fontSize: 26),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  portfolio.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Aktif Portföy',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────── Theme Toggle ───────────────
  Widget _buildThemeToggle(
    BuildContext context,
    ThemeMode current,
    bool isDark,
  ) {
    final accent = AppColors.accentFor(Theme.of(context).brightness);
    final options = [
      (ThemeMode.system, Icons.brightness_auto_rounded, 'Sistem'),
      (ThemeMode.light, Icons.light_mode_rounded, 'Açık'),
      (ThemeMode.dark, Icons.dark_mode_rounded, 'Koyu'),
    ];

    return Row(
      children: options.asMap().entries.map((entry) {
        final i = entry.key;
        final mode = entry.value.$1;
        final icon = entry.value.$2;
        final label = entry.value.$3;
        final isSelected = current == mode;

        return Expanded(
          child: GestureDetector(
            onTap: () =>
                ref.read(themeModeProvider.notifier).setThemeMode(mode),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? accent
                    : (isDark
                          ? AppColors.darkBackground
                          : AppColors.lightBackground),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? accent
                      : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: isSelected
                        ? Colors.white
                        : (isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : (isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─────────────── Currency Toggle ───────────────
  Widget _buildCurrencyToggle(
    BuildContext context,
    String current,
    bool isDark,
  ) {
    const options = [('TRY', '₺'), ('USD', '\$'), ('EUR', '€')];

    return Row(
      children: options.asMap().entries.map((entry) {
        final i = entry.key;
        final code = entry.value.$1;
        final symbol = entry.value.$2;
        final isSelected = current == code;

        return Expanded(
          child: GestureDetector(
            onTap: () => ref.read(currencyProvider.notifier).setCurrency(code),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.gold
                    : (isDark
                          ? AppColors.darkBackground
                          : AppColors.lightBackground),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? AppColors.gold
                      : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    symbol,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? AppColors.darkText : AppColors.lightText),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    code,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.85)
                          : (isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─────────────── Portfolio Tile ───────────────
  Widget _buildPortfolioTile(
    BuildContext context,
    PortfolioModel portfolio,
    bool isActive,
    bool isDark,
  ) {
    final accent = AppColors.accentFor(Theme.of(context).brightness);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isActive
              ? accent.withValues(alpha: 0.15)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder)
                    .withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10),
          border: isActive ? Border.all(color: accent, width: 1.5) : null,
        ),
        child: Center(
          child: Text(portfolio.emoji, style: const TextStyle(fontSize: 18)),
        ),
      ),
      title: Text(
        portfolio.name,
        style: TextStyle(
          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
          fontSize: 14,
          color: isDark ? AppColors.darkText : AppColors.lightText,
        ),
      ),
      subtitle: isActive
          ? Text(
              'Aktif',
              style: TextStyle(
                fontSize: 11,
                color: accent,
                fontWeight: FontWeight.w600,
              ),
            )
          : null,
      trailing: isActive
          ? Icon(Icons.check_circle_rounded, color: accent, size: 20)
          : TextButton(
              onPressed: () async {
                await ref
                    .read(activePortfolioProvider.notifier)
                    .switchPortfolio(portfolio.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${portfolio.name} portföyüne geçildi'),
                      backgroundColor: AppColors.primary,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text(
                'Seç',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
      onLongPress: ref.read(portfoliosProvider).length <= 1
          ? null
          : () => _confirmDeletePortfolio(context, portfolio),
    );
  }

  // ─────────────── Add Portfolio Sheet ───────────────
  void _showAddPortfolioSheet(BuildContext context) {
    final nameController = TextEditingController();
    String selectedEmoji = '💼';
    const emojis = ['💼', '👤', '🏠', '💰', '🌱', '🎯', '📈', '🚀', '💎', '🌍'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Yeni Portföy',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 48,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: emojis.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (ctx, index) {
                        final isSelected = selectedEmoji == emojis[index];
                        return GestureDetector(
                          onTap: () => setModalState(
                            () => selectedEmoji = emojis[index],
                          ),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isDark
                                            ? AppColors.primary
                                            : AppColors.lightPrimary)
                                        .withValues(alpha: 0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? (isDark
                                          ? AppColors.primary
                                          : AppColors.lightPrimary)
                                    : (isDark
                                          ? AppColors.darkBorder
                                          : AppColors.lightBorder),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                emojis[index],
                                style: const TextStyle(fontSize: 22),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Portföy Adı',
                      hintText: 'örn. Kişisel, Şirket',
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final name = nameController.text.trim();
                        if (name.isEmpty) return;
                        await ref
                            .read(portfoliosProvider.notifier)
                            .create(name, selectedEmoji);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: const Text('Portföy Oluştur'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ─────────────── Delete Portfolio ───────────────
  void _confirmDeletePortfolio(BuildContext context, PortfolioModel portfolio) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Portföyü Sil',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text(
          '"${portfolio.name}" portföyünü silmek istiyor musun? İçindeki tüm veriler kalıcı olarak silinir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () async {
              final active = ref.read(activePortfolioProvider);
              await ref.read(portfoliosProvider.notifier).delete(portfolio.id);
              if (active == portfolio.id) {
                final remaining = ref.read(portfoliosProvider);
                if (remaining.isNotEmpty) {
                  await ref
                      .read(activePortfolioProvider.notifier)
                      .switchPortfolio(remaining.first.id);
                }
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Sil', style: TextStyle(color: AppColors.loss)),
          ),
        ],
      ),
    );
  }

  // ─────────────── Clear All ───────────────
  void _confirmClearAll(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Tüm Verileri Sil',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Tüm varlıklar, nakit akışları ve hedefler kalıcı olarak silinir. Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () async {
              final portfolioId = ref.read(activePortfolioProvider);
              if (portfolioId.isNotEmpty) {
                await supabase
                    .from('assets')
                    .delete()
                    .eq('portfolio_id', portfolioId);
                await supabase
                    .from('cashflows')
                    .delete()
                    .eq('portfolio_id', portfolioId);
                await supabase
                    .from('goals')
                    .delete()
                    .eq('portfolio_id', portfolioId);
              }
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Tüm veriler silindi.'),
                    backgroundColor: AppColors.loss,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Sil', style: TextStyle(color: AppColors.loss)),
          ),
        ],
      ),
    );
  }
}
