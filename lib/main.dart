import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;

// ────────────────────────────────────────────────────────────────────
// CONSTANTS & THEME
// ────────────────────────────────────────────────────────────────────

class AppColors {
  static const Color deepBlack = Color(0xFF0B0C10);
  static const Color darkGray = Color(0xFF1F2833);
  static const Color mediumGray = Color(0xFF2A3040);
  static const Color neonCyan = Color(0xFF5CEBFF);
  static const Color neonGreen = Color(0xFF00E676);
  static const Color gold = Color(0xFFD4AF37);
  static const Color white = Color(0xFFFFFFFF);
  static const Color softWhite = Color(0xFFE0E0E0);
  static const Color errorRed = Color(0xFFFF4C6B);
  static const Color glassBg = Color(0x1AFFFFFF);
  static const Color glassBorder = Color(0x33FFFFFF);
}

// ────────────────────────────────────────────────────────────────────
// SAVED LICENSES STORE (FOR QUICK SWITCHING BETWEEN LICENSES)
// ────────────────────────────────────────────────────────────────────

class SavedLicense {
  final String licenseKey;
  final DateTime lastUsed;

  SavedLicense({
    required this.licenseKey,
    required this.lastUsed,
  });

  Map<String, dynamic> toJson() => {
        'licenseKey': licenseKey,
        'lastUsed': lastUsed.toIso8601String(),
      };

  factory SavedLicense.fromJson(Map<String, dynamic> json) => SavedLicense(
        licenseKey: json['licenseKey']?.toString() ?? '',
        lastUsed: DateTime.tryParse(json['lastUsed']?.toString() ?? '') ??
            DateTime.now(),
      );
}

class LicenseHistoryStore {
  static File get _storeFile =>
      File('${Directory.systemTemp.path}/tapsi_saved_licenses.json');

  static Future<List<SavedLicense>> loadLicenses() async {
    try {
      final file = _storeFile;
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      final List<dynamic> decoded = jsonDecode(content);
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(SavedLicense.fromJson)
          .where((item) => item.licenseKey.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveLicense(String key) async {
    try {
      final list = await loadLicenses();
      list.removeWhere((item) => item.licenseKey == key);
      list.insert(
        0,
        SavedLicense(licenseKey: key, lastUsed: DateTime.now()),
      );
      if (list.length > 10) {
        list.removeRange(10, list.length);
      }
      await _storeFile.writeAsString(
        jsonEncode(list.map((e) => e.toJson()).toList()),
      );
    } catch (_) {}
  }

  static Future<void> removeLicense(String key) async {
    try {
      final list = await loadLicenses();
      list.removeWhere((item) => item.licenseKey == key);
      await _storeFile.writeAsString(
        jsonEncode(list.map((e) => e.toJson()).toList()),
      );
    } catch (_) {}
  }

  static Future<void> clearAll() async {
    try {
      if (await _storeFile.exists()) {
        await _storeFile.delete();
      }
    } catch (_) {}
  }
}

// ────────────────────────────────────────────────────────────────────
// DEEP SESSION SANITIZER (ELIMINATES ACCOUNT CONFLICT IN TAPSI & MARKET)
// ────────────────────────────────────────────────────────────────────

class SessionSanitizer {
  static const List<String> targetDomains = [
    '.tapsi.cab',
    'app.tapsi.cab',
    'tapsi.cab',
    '.tapsi.ir',
    'tapsi.ir',
    '.tapsi.markets',
    'tapsi.markets',
    '.tapsi.shop',
    'tapsi.shop',
  ];

  static Future<void> deepCleanAllWebData([
    InAppWebViewController? controller,
  ]) async {
    try {
      final cookieManager = CookieManager.instance();
      await cookieManager.deleteAllCookies();

      for (final domain in targetDomains) {
        final cleanHost = domain.startsWith('.') ? domain.substring(1) : domain;
        try {
          await cookieManager.deleteCookies(
            url: WebUri('https://$cleanHost'),
            domain: domain,
            path: '/',
          );
        } catch (_) {}
      }
    } catch (_) {}

    try {
      // Wipes LocalStorage, IndexedDB, WebSQL across all origins (including tapsi.markets)
      await WebStorageManager.instance().deleteAllData();
    } catch (_) {}

    try {
      await InAppWebViewController.clearAllCache(includeDiskFiles: true);
    } catch (_) {}

    if (controller != null) {
      try {
        await controller.evaluateJavascript(source: '''
          (function() {
            try { window.localStorage.clear(); } catch(e) {}
            try { window.sessionStorage.clear(); } catch(e) {}
            try {
              if (window.indexedDB && window.indexedDB.databases) {
                window.indexedDB.databases().then(function(dbs) {
                  dbs.forEach(function(db) {
                    if (db && db.name) window.indexedDB.deleteDatabase(db.name);
                  });
                });
              }
            } catch(e) {}
            try {
              if ('caches' in window) {
                caches.keys().then(function(names) {
                  for (var i = 0; i < names.length; i++) {
                    caches.delete(names[i]);
                  }
                });
              }
            } catch(e) {}
          })();
        ''');
        await controller.clearHistory();
      } catch (_) {}
    }
  }
}

// ────────────────────────────────────────────────────────────────────
// MAIN ENTRY POINT
// ────────────────────────────────────────────────────────────────────

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.deepBlack,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const SecurePortalApp());
}

class SecurePortalApp extends StatelessWidget {
  const SecurePortalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tapsi Link',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.deepBlack,
        fontFamily: 'Roboto',
        colorScheme: const ColorScheme.dark(
          primary: AppColors.neonCyan,
          secondary: AppColors.gold,
          surface: AppColors.darkGray,
          error: AppColors.errorRed,
        ),
      ),
      home: const AuthenticationScreen(),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
// SCREEN 1: LICENSE AUTHENTICATION (TAPSI ONLY)
// ────────────────────────────────────────────────────────────────────

class AuthenticationScreen extends StatefulWidget {
  const AuthenticationScreen({super.key});

  @override
  State<AuthenticationScreen> createState() => _AuthenticationScreenState();
}

class _AuthenticationScreenState extends State<AuthenticationScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _licenseController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isLoading = false;
  bool _isFocused = false;
  List<SavedLicense> _savedLicenses = [];

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _scaleAnim = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );
    _animController.forward();

    _focusNode.addListener(() {
      if (mounted) setState(() => _isFocused = _focusNode.hasFocus);
    });

    _loadSavedLicenses();
  }

  Future<void> _loadSavedLicenses() async {
    final list = await LicenseHistoryStore.loadLicenses();
    if (mounted) {
      setState(() => _savedLicenses = list);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _licenseController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isNotEmpty) {
      setState(() => _licenseController.text = text);
    } else {
      _showStylishSnackBar('Clipboard is empty.', isError: true);
    }
  }

  Future<void> _authenticate([String? overrideKey]) async {
    final rawKey = (overrideKey ?? _licenseController.text)
        .trim()
        .replaceAll(RegExp(r'\s+'), '');

    if (rawKey.isEmpty) {
      _showStylishSnackBar('Please enter a valid License Key.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Deep clean all previous WebView data before logging in with the license
      await SessionSanitizer.deepCleanAllWebData();

      final url = Uri.parse(
        'https://testtok-production1.up.railway.app/api/tapsi/get-license/${Uri.encodeComponent(rawKey)}',
      );
      final response = await http.get(url).timeout(
        const Duration(seconds: 20),
      );

      if (!mounted) return;

      final body = jsonDecode(response.body);

      if (response.statusCode == 200 && body['success'] == true) {
        final dynamic dataNode = body['data'] ?? {};
        final Map<String, dynamic> dataObj =
            dataNode is Map<String, dynamic> ? dataNode : {};

        // Safely extract cookies & local_storage whether server sends String or Map
        String cookies = '';
        final rawCookies = dataObj['cookies'];
        if (rawCookies is String) {
          cookies = rawCookies;
        } else if (rawCookies is Map) {
          cookies = rawCookies.entries
              .map((e) => '${e.key}=${e.value}')
              .join('; ');
        }

        String localStorage = '{}';
        final rawLs = dataObj['local_storage'];
        if (rawLs is String && rawLs.trim().isNotEmpty) {
          localStorage = rawLs;
        } else if (rawLs is Map) {
          localStorage = jsonEncode(rawLs);
        }

        await LicenseHistoryStore.saveLicense(rawKey);
        await _loadSavedLicenses();

        if (!mounted) return;
        _showStylishSnackBar('Access Granted. Initializing portal...');

        await Future.delayed(const Duration(milliseconds: 450));
        if (!mounted) return;

        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                PortalWebEngineScreen(
              licenseKey: rawKey,
              cookies: cookies,
              localStorage: localStorage,
            ),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.94, end: 1.0).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
                  child: child,
                ),
              );
            },
            transitionDuration: const Duration(milliseconds: 450),
          ),
        );
      } else {
        final msg =
            body['message']?.toString() ?? 'Authentication failed. Invalid key.';
        _showStylishSnackBar(msg, isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      _showStylishSnackBar('Connection error. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showStylishSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_rounded,
              color: isError ? AppColors.errorRed : AppColors.neonCyan,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: AppColors.softWhite,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.darkGray.withOpacity(0.95),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isError
                ? AppColors.errorRed.withOpacity(0.4)
                : AppColors.neonCyan.withOpacity(0.4),
            width: 1,
          ),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.8,
            colors: [
              Color(0xFF1A2332),
              AppColors.deepBlack,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: ScaleTransition(
                  scale: _scaleAnim,
                  child: _buildGlassCard(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 36),
      decoration: BoxDecoration(
        color: AppColors.glassBg,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.glassBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.neonCyan.withOpacity(0.06),
            blurRadius: 40,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildIconSection(),
              const SizedBox(height: 24),
              _buildTitle(),
              const SizedBox(height: 8),
              _buildSubtitle(),
              const SizedBox(height: 32),
              _buildLicenseField(),
              const SizedBox(height: 24),
              _buildAuthButton(),
              if (_savedLicenses.isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildSavedLicensesSection(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconSection() {
    return Container(
      width: 78,
      height: 78,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.neonCyan.withOpacity(0.2),
            AppColors.neonCyan.withOpacity(0.05),
          ],
        ),
        border: Border.all(
          color: AppColors.neonCyan.withOpacity(0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.neonCyan.withOpacity(0.3),
            blurRadius: 24,
            spreadRadius: 1,
          ),
        ],
      ),
      child: const Icon(
        Icons.fingerprint_rounded,
        size: 40,
        color: AppColors.neonCyan,
      ),
    );
  }

  Widget _buildTitle() {
    return const Text(
      'TAPSI LINK',
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: AppColors.white,
        letterSpacing: 4,
      ),
    );
  }

  Widget _buildSubtitle() {
    return Text(
      'Enter your license key to proceed',
      style: TextStyle(
        fontSize: 13,
        color: AppColors.softWhite.withOpacity(0.6),
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildLicenseField() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: _isFocused
            ? [
                BoxShadow(
                  color: AppColors.neonCyan.withOpacity(0.25),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
              ]
            : [],
      ),
      child: TextField(
        controller: _licenseController,
        focusNode: _focusNode,
        style: const TextStyle(
          color: AppColors.white,
          fontSize: 15,
          letterSpacing: 1.2,
        ),
        cursorColor: AppColors.neonCyan,
        decoration: InputDecoration(
          hintText: 'TAPSI-XXXX-XXXX',
          hintStyle: TextStyle(
            color: AppColors.softWhite.withOpacity(0.3),
            letterSpacing: 1.5,
          ),
          prefixIcon: Icon(
            Icons.vpn_key_rounded,
            color: _isFocused
                ? AppColors.neonCyan
                : AppColors.softWhite.withOpacity(0.4),
            size: 20,
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_licenseController.text.isNotEmpty)
                IconButton(
                  icon: Icon(
                    Icons.clear_rounded,
                    color: AppColors.softWhite.withOpacity(0.5),
                    size: 18,
                  ),
                  onPressed: () => setState(() => _licenseController.clear()),
                ),
              IconButton(
                icon: const Icon(
                  Icons.content_paste_rounded,
                  color: AppColors.neonCyan,
                  size: 20,
                ),
                onPressed: _pasteFromClipboard,
                tooltip: 'Paste License',
              ),
            ],
          ),
          filled: true,
          fillColor: AppColors.deepBlack.withOpacity(0.6),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(
              color: AppColors.glassBorder,
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(
              color: AppColors.neonCyan,
              width: 1.5,
            ),
          ),
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _authenticate(),
      ),
    );
  }

  Widget _buildAuthButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.neonCyan.withOpacity(_isLoading ? 0.1 : 0.35),
              blurRadius: 20,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isLoading ? null : () => _authenticate(),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.neonCyan,
            disabledBackgroundColor: AppColors.neonCyan.withOpacity(0.6),
            foregroundColor: AppColors.deepBlack,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 0,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.deepBlack,
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_open_rounded, size: 20),
                    SizedBox(width: 10),
                    Text(
                      'AUTHENTICATE',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildSavedLicensesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: () async {
                await LicenseHistoryStore.clearAll();
                await _loadSavedLicenses();
              },
              icon: const Icon(
                Icons.delete_sweep_rounded,
                size: 16,
                color: AppColors.errorRed,
              ),
              label: const Text(
                'حذف همه',
                style: TextStyle(fontSize: 11.5, color: AppColors.errorRed),
              ),
            ),
            Text(
              'لایسنس‌های اخیر:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.softWhite.withOpacity(0.75),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 140),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: _savedLicenses.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final item = _savedLicenses[index];
              return Container(
                decoration: BoxDecoration(
                  color: AppColors.deepBlack.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: ListTile(
                  dense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  leading: const Icon(
                    Icons.vpn_key_outlined,
                    color: AppColors.neonCyan,
                    size: 18,
                  ),
                  title: Text(
                    item.licenseKey,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: AppColors.softWhite.withOpacity(0.5),
                    ),
                    onPressed: () async {
                      await LicenseHistoryStore.removeLicense(item.licenseKey);
                      await _loadSavedLicenses();
                    },
                  ),
                  onTap: _isLoading
                      ? null
                      : () {
                          _licenseController.text = item.licenseKey;
                          _authenticate(item.licenseKey);
                        },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────
// SCREEN 2: TAPSI PORTAL WEB ENGINE (TAPSI + TAPSI MARKET FIXED)
// ────────────────────────────────────────────────────────────────────

class PortalWebEngineScreen extends StatefulWidget {
  final String licenseKey;
  final String cookies;
  final String localStorage;

  const PortalWebEngineScreen({
    super.key,
    required this.licenseKey,
    required this.cookies,
    required this.localStorage,
  });

  @override
  State<PortalWebEngineScreen> createState() => _PortalWebEngineScreenState();
}

class _PortalWebEngineScreenState extends State<PortalWebEngineScreen> {
  InAppWebViewController? _webViewController;
  bool _isReady = false;
  double _progress = 0;

  double _fallbackLat = 35.6997; // Tehran Azadi default
  double _fallbackLng = 51.3380;
  String _fallbackCityName = 'تهران (میدان آزادی)';

  final List<String> _targetDomains = [
    '.tapsi.cab',
    '.tapsi.ir',
    '.tapsi.markets',
    '.tapsi.shop',
  ];

  static const Set<String> _reservedCookieAttrs = {
    'path',
    'domain',
    'expires',
    'max-age',
    'secure',
    'httponly',
    'samesite',
  };

  @override
  void initState() {
    super.initState();
    _initializeSession();
  }

  Future<void> _initializeSession() async {
    // 1. Wipe all old cookies, localStorage, IndexedDB, and cache across all domains
    await SessionSanitizer.deepCleanAllWebData();

    // 2. Set cookies for Tapsi & Tapsi Market domains
    final cookieManager = CookieManager.instance();
    await _setCookiesForAllDomains(cookieManager);

    if (mounted) {
      setState(() => _isReady = true);
    }
  }

  Future<void> _setCookiesForAllDomains(CookieManager cookieManager) async {
    final cookieParts = widget.cookies.split(';');

    for (final domain in _targetDomains) {
      final url = WebUri('https://${domain.replaceFirst('.', '')}');

      for (final cookiePart in cookieParts) {
        final trimmed = cookiePart.trim();
        if (trimmed.isEmpty) continue;

        final eqIndex = trimmed.indexOf('=');
        if (eqIndex <= 0) continue;

        final name = trimmed.substring(0, eqIndex).trim();
        final value = trimmed.substring(eqIndex + 1).trim();

        if (_reservedCookieAttrs.contains(name.toLowerCase())) continue;

        await cookieManager.setCookie(
          url: url,
          name: name,
          value: value,
          domain: domain,
          isSecure: true,
          path: '/',
        );
      }
    }
  }

  /// Crucial Fix:
  /// 1. Injects Tapsi Cab's localStorage ONLY on `tapsi.cab` (so it NEVER corrupts `tapsi.markets` during SSO!).
  /// 2. On `tapsi.markets` / `tapsi.shop`, clears any stale previous account's localStorage ONCE at session start
  ///    before Market's scripts run, allowing Tapsi Market to open cleanly with the active Tapsi account!
  /// 3. Provides instant GPS fallback so "موقعیت من" on Tapsi Market's map never hangs.
  String _buildLocalStorageScript() {
    final safeJsJsonString = jsonEncode(widget.localStorage);
    final safeKeyGuard = jsonEncode(widget.licenseKey);

    return '''
    (function() {
      try {
        var host = window.location.hostname || '';
        var licenseId = $safeKeyGuard;

        if (host.indexOf('tapsi.cab') !== -1) {
          var cabInitKey = '__tapsi_cab_init_' + licenseId;
          if (window.sessionStorage.getItem(cabInitKey) !== '1') {
            window.localStorage.clear();
            window.sessionStorage.setItem(cabInitKey, '1');
          }
          var rawJson = $safeJsJsonString;
          var data = JSON.parse(rawJson);
          if (data && typeof data === 'object') {
            for (var key in data) {
              if (Object.prototype.hasOwnProperty.call(data, key)) {
                window.localStorage.setItem(
                  key,
                  typeof data[key] === 'string' ? data[key] : JSON.stringify(data[key])
                );
              }
            }
          }
        } else if (host.indexOf('tapsi.markets') !== -1 || host.indexOf('tapsi.shop') !== -1) {
          // Wipe any leftover account from previous sessions ONCE before Tapsi Market's SSO runs,
          // and DO NOT overwrite Market's localStorage with Tapsi Cab's keys!
          var marketInitKey = '__tapsi_market_init_' + licenseId;
          if (window.sessionStorage.getItem(marketInitKey) !== '1') {
            window.localStorage.clear();
            window.sessionStorage.setItem(marketInitKey, '1');
          }
        }
      } catch(e) {
        console.error('LocalStorage injection error:', e);
      }

      // Geolocation fallback so "موقعیت من" (My Location) in Tapsi & Tapsi Market works even if GPS is off
      try {
        if (navigator.geolocation) {
          var origGetCurrentPosition = navigator.geolocation.getCurrentPosition.bind(navigator.geolocation);
          navigator.geolocation.getCurrentPosition = function(success, error, options) {
            var resolved = false;
            var fallbackTimer = setTimeout(function() {
              if (!resolved && success) {
                resolved = true;
                success({
                  coords: {
                    latitude: window.__tapsiFallbackLat || $_fallbackLat,
                    longitude: window.__tapsiFallbackLng || $_fallbackLng,
                    accuracy: 15,
                    altitude: null,
                    altitudeAccuracy: null,
                    heading: null,
                    speed: null
                  },
                  timestamp: Date.now()
                });
              }
            }, 2500);

            origGetCurrentPosition(
              function(pos) {
                if (!resolved) {
                  resolved = true;
                  clearTimeout(fallbackTimer);
                  if (success) success(pos);
                }
              },
              function(err) {
                if (!resolved) {
                  resolved = true;
                  clearTimeout(fallbackTimer);
                  if (success) {
                    success({
                      coords: {
                        latitude: window.__tapsiFallbackLat || $_fallbackLat,
                        longitude: window.__tapsiFallbackLng || $_fallbackLng,
                        accuracy: 15,
                        altitude: null,
                        altitudeAccuracy: null,
                        heading: null,
                        speed: null
                      },
                      timestamp: Date.now()
                    });
                  } else if (error) {
                    error(err);
                  }
                }
              },
              { enableHighAccuracy: true, timeout: 2200, maximumAge: 0 }
            );
          };
        }
      } catch(e) {}
    })();
    ''';
  }

  Future<void> _forceSyncCurrentAccount() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Directionality(
          textDirection: TextDirection.rtl,
          child: Text('در حال پاکسازی کش و همگام‌سازی مجدد اکانت تپسی...'),
        ),
        duration: Duration(seconds: 2),
      ),
    );

    await SessionSanitizer.deepCleanAllWebData(_webViewController);
    await _setCookiesForAllDomains(CookieManager.instance());

    if (_webViewController != null) {
      await _webViewController!.evaluateJavascript(
        source: _buildLocalStorageScript(),
      );
      await _webViewController!.loadUrl(
        urlRequest: URLRequest(
          url: WebUri('https://app.tapsi.cab/profile/'),
        ),
      );
    }
  }

  void _showLocationPickerSheet() {
    final cities = <Map<String, dynamic>>[
      {'name': 'تهران (میدان آزادی)', 'lat': 35.6997, 'lng': 51.3380},
      {'name': 'تهران (ونک / ولیعصر)', 'lat': 35.7575, 'lng': 51.4100},
      {'name': 'تهران (صادقیه / غرب)', 'lat': 35.7219, 'lng': 51.3347},
      {'name': 'تهران (تهرانپارس / شرق)', 'lat': 35.7366, 'lng': 51.5366},
      {'name': 'مشهد (مرکز شهر)', 'lat': 36.2972, 'lng': 59.6067},
      {'name': 'اصفهان (دروازه شیراز)', 'lat': 32.6164, 'lng': 51.6660},
      {'name': 'شیراز (میدان نمازی)', 'lat': 29.6272, 'lng': 52.5199},
      {'name': 'کرج (فلکه اول گوهردشت)', 'lat': 35.8400, 'lng': 50.9715},
      {'name': 'تبریز (آبرسان)', 'lat': 38.0658, 'lng': 46.3268},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkGray,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.my_location_rounded, color: AppColors.neonCyan),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'تنظیم موقعیت مکانی نقشه (تپسی و سوپرمارکت)',
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'اگر GPS گوشی خاموش است، شهر مورد نظر را انتخاب کنید تا دکمه «موقعیت من» روی نقشه بلافاصله کار کند:',
                    style: TextStyle(
                      color: AppColors.softWhite.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: cities.length,
                      itemBuilder: (context, idx) {
                        final city = cities[idx];
                        final selected = _fallbackCityName == city['name'];
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            selected
                                ? Icons.radio_button_checked_rounded
                                : Icons.location_on_outlined,
                            color: selected
                                ? AppColors.neonCyan
                                : AppColors.softWhite.withOpacity(0.6),
                          ),
                          title: Text(
                            city['name'] as String,
                            style: TextStyle(
                              color: selected
                                  ? AppColors.neonCyan
                                  : AppColors.white,
                              fontWeight:
                                  selected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          onTap: () async {
                            setState(() {
                              _fallbackLat = city['lat'] as double;
                              _fallbackLng = city['lng'] as double;
                              _fallbackCityName = city['name'] as String;
                            });
                            await _webViewController?.evaluateJavascript(
                              source: '''
                                window.__tapsiFallbackLat = $_fallbackLat;
                                window.__tapsiFallbackLng = $_fallbackLng;
                              ''',
                            );
                            if (!context.mounted) return;
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Directionality(
                                  textDirection: TextDirection.rtl,
                                  child: Text(
                                    'موقعیت روی «$_fallbackCityName» تنظیم شد.',
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _resetSession() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => _buildResetDialog(),
    );

    if (confirmed == true) {
      await SessionSanitizer.deepCleanAllWebData(_webViewController);

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const AuthenticationScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 1.05, end: 1.0).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 450),
        ),
      );
    }
  }

  Widget _buildResetDialog() {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.darkGray.withOpacity(0.95),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.glassBorder, width: 1),
          boxShadow: [
            BoxShadow(
              color: AppColors.neonCyan.withOpacity(0.1),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.errorRed.withOpacity(0.1),
                    border: Border.all(
                      color: AppColors.errorRed.withOpacity(0.5),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: AppColors.errorRed,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'RESET SESSION',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'This will clear all Tapsi & Tapsi Market session data and return to the license screen.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.softWhite.withOpacity(0.7),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: AppColors.softWhite.withOpacity(0.3),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'CANCEL',
                            style: TextStyle(
                              color: AppColors.softWhite,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.errorRed,
                            foregroundColor: AppColors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'CONFIRM',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_webViewController != null &&
            await _webViewController!.canGoBack()) {
          await _webViewController!.goBack();
        } else {
          await _resetSession();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.deepBlack,
        appBar: _isReady
            ? AppBar(
                backgroundColor: AppColors.darkGray.withOpacity(0.9),
                elevation: 0,
                toolbarHeight: 50,
                leading: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: AppColors.softWhite,
                    size: 18,
                  ),
                  tooltip: 'بازگشت',
                  onPressed: () async {
                    if (_webViewController != null &&
                        await _webViewController!.canGoBack()) {
                      await _webViewController!.goBack();
                    }
                  },
                ),
                title: const Text(
                  'TAPSI LINK',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                    letterSpacing: 2,
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(
                      Icons.my_location_rounded,
                      color: AppColors.neonGreen,
                      size: 20,
                    ),
                    tooltip: 'تنظیم شهر روی نقشه',
                    onPressed: _showLocationPickerSheet,
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.sync_rounded,
                      color: AppColors.gold,
                      size: 20,
                    ),
                    tooltip: 'همگام‌سازی مجدد اکانت',
                    onPressed: _forceSyncCurrentAccount,
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: AppColors.softWhite,
                      size: 20,
                    ),
                    tooltip: 'رفرش صفحه',
                    onPressed: () => _webViewController?.reload(),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(
                      vertical: 7,
                      horizontal: 10,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.logout_rounded,
                        color: AppColors.neonCyan,
                        size: 20,
                      ),
                      onPressed: _resetSession,
                      tooltip: 'Reset Session',
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.deepBlack.withOpacity(0.8),
                        side: BorderSide(
                          color: AppColors.neonCyan.withOpacity(0.4),
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : null,
        body: SafeArea(
          child: Stack(
            children: [
              if (_isReady)
                InAppWebView(
                  initialUrlRequest: URLRequest(
                    url: WebUri('https://app.tapsi.cab/profile/'),
                  ),
                  initialUserScripts: UnmodifiableListView<UserScript>([
                    UserScript(
                      source: _buildLocalStorageScript(),
                      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                    ),
                  ]),
                  // Exact WebView settings that allow Tapsi Market SSO to open natively
                  // without hijacking image taps or losing Referer headers
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    domStorageEnabled: true,
                    databaseEnabled: true,
                    geolocationEnabled: true,
                    thirdPartyCookiesEnabled: true,
                    sharedCookiesEnabled: true,
                    supportMultipleWindows: false,
                    clearSessionCache: false,
                    clearCache: false,
                    cacheEnabled: true,
                    mixedContentMode:
                        MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                    useWideViewPort: true,
                    supportZoom: true,
                    userAgent:
                        'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
                  ),
                  onWebViewCreated: (controller) {
                    _webViewController = controller;
                  },
                  onProgressChanged: (controller, progress) {
                    if (mounted) {
                      setState(() => _progress = progress / 100.0);
                    }
                  },
                  onGeolocationPermissionsShowPrompt:
                      (controller, origin) async {
                    return GeolocationPermissionShowPromptResponse(
                      origin: origin,
                      allow: true,
                      retain: true,
                    );
                  },
                  onPermissionRequest: (controller, request) async {
                    return PermissionResponse(
                      resources: request.resources,
                      action: PermissionResponseAction.GRANT,
                    );
                  },
                )
              else
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.neonCyan.withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'INITIALIZING SECURE SESSION...',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.softWhite.withOpacity(0.6),
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              if (_isReady && _progress < 1.0)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.neonCyan.withOpacity(0.8),
                    ),
                    minHeight: 2.5,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
