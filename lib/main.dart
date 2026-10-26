import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
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
// MODELS & LOCAL ACCOUNT STORAGE (NO EXTERNAL PLUGIN NEEDED)
// ────────────────────────────────────────────────────────────────────

class SavedAccount {
  final String keyOrLabel;
  final String rawInput;
  final DateTime lastUsed;

  SavedAccount({
    required this.keyOrLabel,
    required this.rawInput,
    required this.lastUsed,
  });

  Map<String, dynamic> toJson() => {
        'keyOrLabel': keyOrLabel,
        'rawInput': rawInput,
        'lastUsed': lastUsed.toIso8601String(),
      };

  factory SavedAccount.fromJson(Map<String, dynamic> json) => SavedAccount(
        keyOrLabel: json['keyOrLabel']?.toString() ?? 'Unknown',
        rawInput: json['rawInput']?.toString() ?? '',
        lastUsed: DateTime.tryParse(json['lastUsed']?.toString() ?? '') ??
            DateTime.now(),
      );
}

class AccountHistoryStore {
  static File get _storeFile =>
      File('${Directory.systemTemp.path}/tapsi_link_accounts_v2.json');

  static Future<List<SavedAccount>> loadAccounts() async {
    try {
      final file = _storeFile;
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      final List<dynamic> decoded = jsonDecode(content);
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(SavedAccount.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveAccount(String label, String rawInput) async {
    try {
      final list = await loadAccounts();
      list.removeWhere(
        (item) => item.rawInput == rawInput || item.keyOrLabel == label,
      );
      list.insert(
        0,
        SavedAccount(
          keyOrLabel: label,
          rawInput: rawInput,
          lastUsed: DateTime.now(),
        ),
      );
      if (list.length > 10) {
        list.removeRange(10, list.length);
      }
      await _storeFile.writeAsString(
        jsonEncode(list.map((e) => e.toJson()).toList()),
      );
    } catch (_) {}
  }

  static Future<void> removeAccount(String rawInput) async {
    try {
      final list = await loadAccounts();
      list.removeWhere((item) => item.rawInput == rawInput);
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
// DEEP SESSION SANITIZER (FIXES ACCOUNT CONFLICT ACROSS ALL DOMAINS)
// ────────────────────────────────────────────────────────────────────

class SessionSanitizer {
  static final List<String> allDomains = [
    'tapsi.cab',
    '.tapsi.cab',
    'app.tapsi.cab',
    'supermarket.tapsi.cab',
    'tapsi.ir',
    '.tapsi.ir',
    'tapsi.markets',
    '.tapsi.markets',
    'tapsi.shop',
    '.tapsi.shop',
    'okala.com',
    '.okala.com',
    'www.okala.com',
    'api.okala.com',
  ];

  /// Completely wipes Cookies, LocalStorage, SessionStorage, IndexedDB, and WebView Cache
  static Future<void> deepCleanAllWebData([
    InAppWebViewController? controller,
  ]) async {
    try {
      final cookieManager = CookieManager.instance();
      await cookieManager.deleteAllCookies();

      for (final domain in allDomains) {
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
      // Wipes LocalStorage, IndexedDB, WebSQL for ALL origins (fixes Tapsi vs Supermarket conflict)
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
                  for (let name of names) caches.delete(name);
                });
              }
            } catch(e) {}
            try {
              if (navigator.serviceWorker) {
                navigator.serviceWorker.getRegistrations().then(function(registrations) {
                  for (let registration of registrations) registration.unregister();
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
      title: 'Tapsi Link Pro',
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
// SCREEN 1: SMART MULTI-FORMAT AUTHENTICATION
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
  String _selectedStartTarget = 'tapsi'; // 'tapsi', 'supermarket', 'okala'
  List<SavedAccount> _savedAccounts = [];

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
    _scaleAnim = Tween<double>(begin: 0.90, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );
    _animController.forward();

    _focusNode.addListener(() {
      if (mounted) setState(() => _isFocused = _focusNode.hasFocus);
    });

    _loadSavedAccounts();
  }

  Future<void> _loadSavedAccounts() async {
    final accounts = await AccountHistoryStore.loadAccounts();
    if (mounted) {
      setState(() => _savedAccounts = accounts);
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
      setState(() {
        _licenseController.text = text;
      });
      _showStylishSnackBar('از کلیپ‌بورد جایگذاری شد.');
    } else {
      _showStylishSnackBar('کلیپ‌بورد خالی است.', isError: true);
    }
  }

  /// Normalizes any server or raw JSON structure into {cookies, localStorage, directUrl}
  Map<String, String> _extractSessionPayload(dynamic decoded) {
    String cookies = '';
    Map<String, dynamic> localStorageMap = {};
    String directUrl = '';

    if (decoded is Map) {
      final dynamic dataNode =
          decoded['data'] ?? decoded['clientSideData'] ?? decoded;

      if (dataNode is Map) {
        // 1. Extract Cookies
        final rawCookies =
            dataNode['cookies'] ?? decoded['cookies'] ?? dataNode['cookie'];
        if (rawCookies is String) {
          cookies = rawCookies;
        } else if (rawCookies is Map) {
          cookies = rawCookies.entries
              .map((e) => '${e.key}=${e.value}')
              .join('; ');
        } else if (rawCookies is List) {
          cookies = rawCookies.map((e) => e.toString()).join('; ');
        }

        // 2. Extract LocalStorage
        final rawLs = dataNode['local_storage'] ??
            dataNode['localStorage'] ??
            dataNode['metadata'] ??
            decoded['local_storage'] ??
            decoded['localStorage'];

        if (rawLs is String && rawLs.trim().isNotEmpty) {
          try {
            final parsedLs = jsonDecode(rawLs);
            if (parsedLs is Map) {
              parsedLs.forEach((k, v) => localStorageMap[k.toString()] = v);
            }
          } catch (_) {
            localStorageMap['raw_session'] = rawLs;
          }
        } else if (rawLs is Map) {
          rawLs.forEach((k, v) => localStorageMap[k.toString()] = v);
        }

        // 3. Extract direct redirect URL if provided
        final rawUrl = dataNode['url'] ??
            dataNode['redirect_url'] ??
            decoded['url'] ??
            decoded['redirect_url'];
        if (rawUrl is String && rawUrl.startsWith('http')) {
          directUrl = rawUrl;
        }
      }
    }

    // Also synchronize accessToken / refreshToken between cookies and localStorage
    // so both Tapsi and Supermarket/Okala recognize the exact same user account!
    final tokenFromCookie = _findTokenInCookies(cookies);
    if (tokenFromCookie != null && tokenFromCookie.isNotEmpty) {
      localStorageMap.putIfAbsent('accessToken', () => tokenFromCookie);
      localStorageMap.putIfAbsent('token', () => tokenFromCookie);
    } else {
      // Check if token exists in localStorage but missing in cookies
      final lsToken = (localStorageMap['accessToken'] ??
              localStorageMap['token'] ??
              localStorageMap['access_token'])
          ?.toString();
      if (lsToken != null &&
          lsToken.isNotEmpty &&
          !cookies.contains('accessToken=')) {
        cookies = cookies.isEmpty
            ? 'accessToken=$lsToken'
            : '$cookies; accessToken=$lsToken';
      }
    }

    return {
      'cookies': cookies,
      'localStorage': jsonEncode(localStorageMap),
      'directUrl': directUrl,
    };
  }

  String? _findTokenInCookies(String cookies) {
    for (final part in cookies.split(';')) {
      final trimmed = part.trim();
      final idx = trimmed.indexOf('=');
      if (idx > 0) {
        final k = trimmed.substring(0, idx).trim();
        final v = trimmed.substring(idx + 1).trim();
        if ((k == 'accessToken' || k == 'token' || k == 'access_token') &&
            v.isNotEmpty) {
          return v;
        }
      }
    }
    return null;
  }

  String _resolveInitialUrl(String directUrl) {
    if (directUrl.isNotEmpty) return directUrl;
    switch (_selectedStartTarget) {
      case 'supermarket':
        return 'https://app.tapsi.cab/';
      case 'okala':
        return 'https://www.okala.com/';
      case 'tapsi':
      default:
        return 'https://app.tapsi.cab/profile/';
    }
  }

  Future<void> _authenticate([String? overrideInput]) async {
    final rawInput = (overrideInput ?? _licenseController.text).trim();
    if (rawInput.isEmpty) {
      _showStylishSnackBar(
        'لطفاً کلید لایسنس، لینک یا JSON نشست را وارد کنید.',
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Step 1: Deep clean ALL old WebView data first so previous accounts never leak
      await SessionSanitizer.deepCleanAllWebData();

      String cookies = '';
      String localStorage = '{}';
      String directUrl = '';
      String displayLabel = rawInput;

      // Case A: User pasted a direct URL (e.g. https://app.tapsi.cab/?&code=... or railway link)
      if (rawInput.startsWith('http://') || rawInput.startsWith('https://')) {
        if (rawInput.contains('/api/tapsi/get-license/') ||
            rawInput.contains('.up.railway.app/acc/')) {
          final resp = await http
              .get(Uri.parse(rawInput))
              .timeout(const Duration(seconds: 20));
          if (resp.statusCode == 200 && resp.body.trim().startsWith('{')) {
            final decoded = jsonDecode(resp.body);
            final extracted = _extractSessionPayload(decoded);
            cookies = extracted['cookies'] ?? '';
            localStorage = extracted['localStorage'] ?? '{}';
            directUrl = extracted['directUrl'] ?? '';
          } else {
            directUrl = rawInput;
          }
        } else {
          directUrl = rawInput;
        }
        displayLabel = 'URL: ${Uri.tryParse(rawInput)?.host ?? 'Direct'}';
      }
      // Case B: User pasted Raw JSON (e.g. {"cookies":"accessToken=...", ...})
      else if (rawInput.startsWith('{') && rawInput.endsWith('}')) {
        final decoded = jsonDecode(rawInput);
        final extracted = _extractSessionPayload(decoded);
        cookies = extracted['cookies'] ?? '';
        localStorage = extracted['localStorage'] ?? '{}';
        directUrl = extracted['directUrl'] ?? '';
        displayLabel = 'JSON Session';
      }
      // Case C: User pasted raw cookie string directly (e.g. accessToken=eyJ...)
      else if (rawInput.contains('accessToken=') || rawInput.contains('=') && rawInput.contains(';')) {
        cookies = rawInput;
        final extracted = _extractSessionPayload({'cookies': rawInput});
        cookies = extracted['cookies'] ?? rawInput;
        localStorage = extracted['localStorage'] ?? '{}';
        displayLabel = 'Direct Token';
      }
      // Case D: Standard License Key or Phone Number lookup via API
      else {
        final normalizedKey = rawInput
            .replaceAll(RegExp(r'\s+'), '')
            .toUpperCase();
        displayLabel = normalizedKey;

        final url = Uri.parse(
          'https://testtok-production1.up.railway.app/api/tapsi/get-license/${Uri.encodeComponent(normalizedKey)}',
        );
        final response = await http.get(url).timeout(
          const Duration(seconds: 20),
        );

        if (!mounted) return;

        dynamic body;
        try {
          body = jsonDecode(response.body);
        } catch (_) {
          throw Exception('پاسخ سرور معتبر نیست (${response.statusCode}).');
        }

        if (response.statusCode == 200 &&
            (body['success'] == true ||
                body['data'] != null ||
                body['cookies'] != null)) {
          final extracted = _extractSessionPayload(body);
          cookies = extracted['cookies'] ?? '';
          localStorage = extracted['localStorage'] ?? '{}';
          directUrl = extracted['directUrl'] ?? '';
        } else {
          final msg = body is Map
              ? (body['message']?.toString() ??
                  'کلید لایسنس نامعتبر یا منقضی شده است.')
              : 'کلید لایسنس نامعتبر است.';
          _showStylishSnackBar(msg, isError: true);
          return;
        }
      }

      await AccountHistoryStore.saveAccount(displayLabel, rawInput);
      await _loadSavedAccounts();

      if (!mounted) return;
      _showStylishSnackBar('نشست قبلی پاکسازی شد. در حال ورود به اکانت جدید...');

      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;

      final targetUrl = _resolveInitialUrl(directUrl);

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              PortalWebEngineScreen(
            accountLabel: displayLabel,
            cookies: cookies,
            localStorage: localStorage,
            initialUrl: targetUrl,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    } on TimeoutException {
      if (!mounted) return;
      _showStylishSnackBar(
        'مهلت اتصال به سرور تمام شد. اینترنت یا فیلترشکن خود را بررسی کنید.',
        isError: true,
      );
    } catch (e) {
      if (!mounted) return;
      _showStylishSnackBar(
        'خطا در برقراری ارتباط یا پردازش اطلاعات: ${e.toString().replaceAll('Exception: ', '')}',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showStylishSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Directionality(
          textDirection: TextDirection.rtl,
          child: Row(
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
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: AppColors.darkGray.withOpacity(0.96),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isError
                ? AppColors.errorRed.withOpacity(0.45)
                : AppColors.neonCyan.withOpacity(0.45),
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
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
              const SizedBox(height: 20),
              _buildTitle(),
              const SizedBox(height: 6),
              _buildSubtitle(),
              const SizedBox(height: 24),
              _buildTargetSelector(),
              const SizedBox(height: 18),
              _buildLicenseField(),
              const SizedBox(height: 20),
              _buildAuthButton(),
              if (_savedAccounts.isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildSavedAccountsSection(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconSection() {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.neonCyan.withOpacity(0.22),
            AppColors.neonCyan.withOpacity(0.05),
          ],
        ),
        border: Border.all(
          color: AppColors.neonCyan.withOpacity(0.55),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.neonCyan.withOpacity(0.28),
            blurRadius: 24,
            spreadRadius: 1,
          ),
        ],
      ),
      child: const Icon(
        Icons.fingerprint_rounded,
        size: 38,
        color: AppColors.neonCyan,
      ),
    );
  }

  Widget _buildTitle() {
    return const Text(
      'TAPSI LINK PRO',
      style: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: AppColors.white,
        letterSpacing: 3.5,
      ),
    );
  }

  Widget _buildSubtitle() {
    return Text(
      'ورود بدون تداخل اکانت • پشتیبانی از لایسنس، لینک و JSON',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 12.5,
        color: AppColors.softWhite.withOpacity(0.65),
      ),
    );
  }

  Widget _buildTargetSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.deepBlack.withOpacity(0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          _buildTargetChip('tapsi', 'تپسی', Icons.local_taxi_rounded),
          _buildTargetChip(
            'supermarket',
            'سوپرمارکت',
            Icons.shopping_bag_rounded,
          ),
          _buildTargetChip('okala', 'اکالا', Icons.storefront_rounded),
        ],
      ),
    );
  }

  Widget _buildTargetChip(String id, String label, IconData icon) {
    final isSelected = _selectedStartTarget == id;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedStartTarget = id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.neonCyan.withOpacity(0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSelected
                ? Border.all(color: AppColors.neonCyan.withOpacity(0.6))
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? AppColors.neonCyan
                    : AppColors.softWhite.withOpacity(0.5),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? AppColors.neonCyan
                      : AppColors.softWhite.withOpacity(0.65),
                ),
              ),
            ],
          ),
        ),
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
          fontSize: 14.5,
          letterSpacing: 1.0,
        ),
        cursorColor: AppColors.neonCyan,
        decoration: InputDecoration(
          hintText: 'TAPSI-XXXX-XXXX / JSON / URL',
          hintStyle: TextStyle(
            color: AppColors.softWhite.withOpacity(0.3),
            letterSpacing: 1.2,
            fontSize: 13,
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
                  tooltip: 'پاک کردن',
                ),
              IconButton(
                icon: const Icon(
                  Icons.content_paste_rounded,
                  color: AppColors.neonCyan,
                  size: 20,
                ),
                onPressed: _pasteFromClipboard,
                tooltip: 'جایگذاری از کلیپ‌بورد',
              ),
            ],
          ),
          filled: true,
          fillColor: AppColors.deepBlack.withOpacity(0.65),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
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
      height: 54,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
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
              borderRadius: BorderRadius.circular(18),
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
                      'AUTHENTICATE & CLEAN LOGIN',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildSavedAccountsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: () async {
                await AccountHistoryStore.clearAll();
                await _loadSavedAccounts();
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
              'لایسنس‌ها و اکانت‌های اخیر (سوییچ سریع):',
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
          constraints: const BoxConstraints(maxHeight: 150),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: _savedAccounts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final item = _savedAccounts[index];
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
                    Icons.account_circle_outlined,
                    color: AppColors.neonCyan,
                    size: 20,
                  ),
                  title: Text(
                    item.keyOrLabel,
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
                      await AccountHistoryStore.removeAccount(item.rawInput);
                      await _loadSavedAccounts();
                    },
                  ),
                  onTap: _isLoading
                      ? null
                      : () {
                          _licenseController.text = item.rawInput;
                          _authenticate(item.rawInput);
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
// SCREEN 2: ISOLATED PORTAL WEB ENGINE (WITH GPS, POPUP & SSO FIX)
// ────────────────────────────────────────────────────────────────────

class PortalWebEngineScreen extends StatefulWidget {
  final String accountLabel;
  final String cookies;
  final String localStorage;
  final String initialUrl;

  const PortalWebEngineScreen({
    super.key,
    required this.accountLabel,
    required this.cookies,
    required this.localStorage,
    required this.initialUrl,
  });

  @override
  State<PortalWebEngineScreen> createState() => _PortalWebEngineScreenState();
}

class _PortalWebEngineScreenState extends State<PortalWebEngineScreen> {
  InAppWebViewController? _webViewController;
  bool _isReady = false;
  double _progress = 0;
  String _currentUrl = '';

  // Selected fallback city coordinates for quick map/address fixing when GPS is off
  double _fallbackLat = 35.6997; // Tehran Azadi Square default
  double _fallbackLng = 51.3380;
  String _fallbackCityName = 'تهران';

  static const Set<String> _reservedCookieAttributes = {
    'path',
    'domain',
    'expires',
    'max-age',
    'secure',
    'httponly',
    'samesite',
    'priority',
  };

  @override
  void initState() {
    super.initState();
    _initializeCleanSession();
  }

  Future<void> _initializeCleanSession() async {
    // 1. Complete wipe of any leftover cookies, localStorage, IndexedDB, or cache
    await SessionSanitizer.deepCleanAllWebData();

    // 2. Set cookies across all Tapsi, Supermarket, and Okala domains
    final cookieManager = CookieManager.instance();
    await _setCookiesForAllDomains(cookieManager);

    if (mounted) {
      setState(() => _isReady = true);
    }
  }

  Future<void> _setCookiesForAllDomains(CookieManager cookieManager) async {
    final cookieParts = widget.cookies.split(';');
    final Map<String, String> validCookies = {};

    for (final cookiePart in cookieParts) {
      final trimmed = cookiePart.trim();
      if (trimmed.isEmpty) continue;

      final eqIndex = trimmed.indexOf('=');
      if (eqIndex <= 0) continue;

      final name = trimmed.substring(0, eqIndex).trim();
      final value = trimmed.substring(eqIndex + 1).trim();

      if (_reservedCookieAttributes.contains(name.toLowerCase())) continue;
      if (name.isEmpty) continue;

      validCookies[name] = value;
    }

    for (final domain in SessionSanitizer.allDomains) {
      final cleanHost = domain.startsWith('.') ? domain.substring(1) : domain;
      final url = WebUri('https://$cleanHost');

      for (final entry in validCookies.entries) {
        try {
          await cookieManager.setCookie(
            url: url,
            name: entry.key,
            value: entry.value,
            domain: domain.startsWith('.') ? domain : null,
            isSecure: true,
            path: '/',
            sameSite: HTTPCookieSameSitePolicy.NONE,
          );
        } catch (_) {}
      }
    }
  }

  /// Injects LocalStorage ONLY ONCE per session per origin so user actions
  /// (like adding addresses, cart items, or SSO redirects) are never overwritten!
  /// Also provides automatic Geolocation fallback so "موقعیت من" always works.
  String _buildSmartUserScript() {
    // Encode raw JSON string as a safe JS string literal via jsonEncode
    final safeJsJsonString = jsonEncode(widget.localStorage);

    return '''
    (function() {
      try {
        var sessionGuardKey = '__tapsi_link_session_v2_' + ${jsonEncode(widget.accountLabel)};
        if (window.sessionStorage.getItem(sessionGuardKey) !== '1') {
          // Wipe any stale keys from previous account on this origin first
          window.localStorage.clear();
          var rawJson = $safeJsJsonString;
          var data = JSON.parse(rawJson);
          if (data && typeof data === 'object') {
            for (var key in data) {
              if (Object.prototype.hasOwnProperty.call(data, key)) {
                var val = data[key];
                window.localStorage.setItem(
                  key,
                  typeof val === 'string' ? val : JSON.stringify(val)
                );
              }
            }
          }
          window.sessionStorage.setItem(sessionGuardKey, '1');
        }
      } catch (e) {
        console.error('Session initialization error:', e);
      }

      // Fix Geolocation hanging in WebView when GPS is off or blocked by VPN
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
      } catch (e) {}
    })();
    ''';
  }

  /// Force re-syncs current account across Tapsi and Supermarket if user notices any mismatch
  Future<void> _forceSyncCurrentAccount() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Directionality(
          textDirection: TextDirection.rtl,
          child: Text('در حال پاکسازی کش دامنه و همگام‌سازی مجدد اکانت فعلی...'),
        ),
        duration: Duration(seconds: 2),
      ),
    );

    final currentUrl = await _webViewController?.getUrl();
    await SessionSanitizer.deepCleanAllWebData(_webViewController);
    await _setCookiesForAllDomains(CookieManager.instance());

    if (_webViewController != null) {
      await _webViewController!.evaluateJavascript(
        source: _buildSmartUserScript(),
      );
      await _webViewController!.loadUrl(
        urlRequest: URLRequest(
          url: currentUrl ?? WebUri('https://app.tapsi.cab/profile/'),
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
                          'تنظیم موقعیت مکانی هوشمند (رفع قفل نقشه)',
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
                    'اگر GPS گوشی خاموش است یا دکمه «موقعیت من» در سوپرمارکت/اکالا کار نمی‌کند، شهر مورد نظر را انتخاب کنید:',
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
                                    'موقعیت روی «$_fallbackCityName» تنظیم شد. اکنون روی دکمه «موقعیت من» در نقشه بزنید.',
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
                scale: Tween<double>(begin: 1.04, end: 1.0).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    }
  }

  Widget _buildResetDialog() {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.darkGray.withOpacity(0.96),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.glassBorder, width: 1),
        ),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.errorRed.withOpacity(0.12),
                  border: Border.all(
                    color: AppColors.errorRed.withOpacity(0.5),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: AppColors.errorRed,
                  size: 26,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'خروج و پاکسازی کامل اکانت',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.white,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'تمام کوکی‌ها، حافظه LocalStorage و دیتابیس‌های تپسی و سوپرمارکت/اکالا به طور کامل پاک می‌شوند تا با اکانت بعدی تداخل نداشته باشند.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.softWhite.withOpacity(0.75),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 46,
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
                          'انصراف',
                          style: TextStyle(
                            color: AppColors.softWhite,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 46,
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
                          'پاکسازی و خروج',
                          style: TextStyle(fontWeight: FontWeight.w700),
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
        appBar: _isReady ? _buildPortalAppBar() : null,
        body: SafeArea(
          child: Stack(
            children: [
              if (_isReady)
                InAppWebView(
                  initialUrlRequest: URLRequest(
                    url: WebUri(widget.initialUrl),
                  ),
                  initialUserScripts: UnmodifiableListView<UserScript>([
                    UserScript(
                      source: _buildSmartUserScript(),
                      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                    ),
                  ]),
                  gestureRecognizers: {
                    Factory<OneSequenceGestureRecognizer>(
                      () => EagerGestureRecognizer(),
                    ),
                  },
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    javaScriptCanOpenWindowsAutomatically: true,
                    supportMultipleWindows: true,
                    domStorageEnabled: true,
                    databaseEnabled: true,
                    geolocationEnabled: true,
                    thirdPartyCookiesEnabled: true,
                    sharedCookiesEnabled: true,
                    clearSessionCache: false,
                    clearCache: false,
                    cacheEnabled: true,
                    allowsInlineMediaPlayback: true,
                    mediaPlaybackRequiresUserGesture: false,
                    mixedContentMode:
                        MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                    useWideViewPort: true,
                    loadWithOverviewMode: true,
                    supportZoom: false,
                    userAgent:
                        'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
                  ),
                  onWebViewCreated: (controller) {
                    _webViewController = controller;
                  },
                  onLoadStart: (controller, url) {
                    if (mounted) {
                      setState(() => _currentUrl = url?.toString() ?? '');
                    }
                  },
                  onProgressChanged: (controller, progress) {
                    if (mounted) {
                      setState(() => _progress = progress / 100.0);
                    }
                  },
                  // Fixes buttons that open new windows / target="_blank" in Okala & Tapsi
                  onCreateWindow: (controller, createWindowAction) async {
                    final targetUrl = createWindowAction.request.url;
                    if (targetUrl != null) {
                      await controller.loadUrl(
                        urlRequest: URLRequest(url: targetUrl),
                      );
                    }
                    return false;
                  },
                  // Fixes "موقعیت من" (My Location) button on the map
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
                  onReceivedServerTrustAuthRequest:
                      (controller, challenge) async {
                    return ServerTrustAuthResponse(
                      action: ServerTrustAuthResponseAction.PROCEED,
                    );
                  },
                )
              else
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.neonCyan,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'پاکسازی نشست قبلی و آماده‌سازی اکانت...',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.softWhite.withOpacity(0.7),
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
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.neonCyan,
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

  PreferredSizeWidget _buildPortalAppBar() {
    final isOkala = _currentUrl.contains('okala');
    return AppBar(
      backgroundColor: AppColors.darkGray.withOpacity(0.95),
      elevation: 0,
      toolbarHeight: 52,
      titleSpacing: 8,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: AppColors.softWhite,
          size: 18,
        ),
        tooltip: 'بازگشت به صفحه قبل',
        onPressed: () async {
          if (_webViewController != null &&
              await _webViewController!.canGoBack()) {
            await _webViewController!.goBack();
          }
        },
      ),
      title: Row(
        children: [
          _buildQuickNavPill(
            label: 'تپسی',
            isActive: !isOkala,
            onTap: () {
              _webViewController?.loadUrl(
                urlRequest: URLRequest(
                  url: WebUri('https://app.tapsi.cab/'),
                ),
              );
            },
          ),
          const SizedBox(width: 6),
          _buildQuickNavPill(
            label: 'اکالا',
            isActive: isOkala,
            onTap: () {
              _webViewController?.loadUrl(
                urlRequest: URLRequest(
                  url: WebUri('https://www.okala.com/'),
                ),
              );
            },
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(
            Icons.my_location_rounded,
            color: AppColors.neonGreen,
            size: 20,
          ),
          tooltip: 'تنظیم شهر / رفع قفل نقشه',
          onPressed: _showLocationPickerSheet,
        ),
        IconButton(
          icon: const Icon(
            Icons.sync_problem_rounded,
            color: AppColors.gold,
            size: 20,
          ),
          tooltip: 'همگام‌سازی و رفع تداخل اکانت',
          onPressed: _forceSyncCurrentAccount,
        ),
        IconButton(
          icon: const Icon(
            Icons.refresh_rounded,
            color: AppColors.softWhite,
            size: 20,
          ),
          tooltip: 'بارگذاری مجدد',
          onPressed: () => _webViewController?.reload(),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: IconButton(
            icon: const Icon(
              Icons.logout_rounded,
              color: AppColors.errorRed,
              size: 20,
            ),
            tooltip: 'تعویض اکانت / خروج امن',
            onPressed: _resetSession,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickNavPill({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.neonCyan.withOpacity(0.18)
              : AppColors.deepBlack.withOpacity(0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive
                ? AppColors.neonCyan.withOpacity(0.6)
                : AppColors.glassBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: isActive ? AppColors.neonCyan : AppColors.softWhite,
          ),
        ),
      ),
    );
  }
}
