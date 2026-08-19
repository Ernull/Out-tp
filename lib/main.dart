import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CONSTANTS & THEME
// ─────────────────────────────────────────────────────────────────────────────

class AppColors {
  static const Color deepBlack = Color(0xFF0B0C10);
  static const Color darkGray = Color(0xFF1F2833);
  static const Color mediumGray = Color(0xFF2A3040);
  static const Color neonCyan = Color(0xFF5CEBFF);
  static const Color gold = Color(0xFFD4AF37);
  static const Color white = Color(0xFFFFFFFF);
  static const Color softWhite = Color(0xFFE0E0E0);
  static const Color errorRed = Color(0xFFFF4C6B);
  static const Color glassBg = Color(0x1AFFFFFF);
  static const Color glassBorder = Color(0x33FFFFFF);
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN ENTRY POINT
// ─────────────────────────────────────────────────────────────────────────────

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
      title: 'Enterprise Secure Portal',
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

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN 1: SECURE AUTHENTICATION
// ─────────────────────────────────────────────────────────────────────────────

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
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _scaleAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.elasticOut),
    );
    _animController.forward();

    _focusNode.addListener(() {
      setState(() => _isFocused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _licenseController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _authenticate() async {
    final key = _licenseController.text.trim();
    if (key.isEmpty) {
      _showStylishSnackBar('Please enter a valid License Key.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final url = Uri.parse(
        'https://testtok-production.up.railway.app/api/tapsi/get-license/$key',
      );
      final response = await http.get(url).timeout(
        const Duration(seconds: 20),
      );

      if (!mounted) return;

      final body = jsonDecode(response.body);

      if (response.statusCode == 200 && body['success'] == true) {
        final String cookies = body['cookies'] ?? '';
        final String localStorage = body['local_storage'] ?? '{}';

        _showStylishSnackBar('Access Granted. Initializing portal...');

        await Future.delayed(const Duration(milliseconds: 600));

        if (!mounted) return;

        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                PortalWebEngineScreen(
                  cookies: cookies,
                  localStorage: localStorage,
                ),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.92, end: 1.0).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
                  child: child,
                ),
              );
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      } else {
        final msg = body['message'] ?? 'Authentication failed. Invalid key.';
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
              isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
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
              padding: const EdgeInsets.symmetric(horizontal: 28),
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
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
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
              const SizedBox(height: 28),
              _buildTitle(),
              const SizedBox(height: 8),
              _buildSubtitle(),
              const SizedBox(height: 36),
              _buildLicenseField(),
              const SizedBox(height: 28),
              _buildAuthButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconSection() {
    return Container(
      width: 80,
      height: 80,
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
        size: 42,
        color: AppColors.neonCyan,
      ),
    );
  }

  Widget _buildTitle() {
    return const Text(
      'SYSTEM ACCESS',
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
          hintText: 'LICENSE-XXXX-XXXX',
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
            borderSide: BorderSide(
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
          onPressed: _isLoading ? null : _authenticate,
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
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN 2: PORTAL WEB ENGINE
// ─────────────────────────────────────────────────────────────────────────────

class PortalWebEngineScreen extends StatefulWidget {
  final String cookies;
  final String localStorage;

  const PortalWebEngineScreen({
    super.key,
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

  final List<String> _targetDomains = [
    '.tapsi.cab',
    '.tapsi.ir',
    '.tapsi.markets',
  ];

  @override
  void initState() {
    super.initState();
    _initializeSession();
  }

  Future<void> _initializeSession() async {
    final cookieManager = CookieManager.instance();

    // Clear old cookies
    await cookieManager.deleteAllCookies();

    // Parse and set cookies for all target domains
    await _setCookiesForAllDomains(cookieManager);

    if (mounted) {
      setState(() => _isReady = true);
    }
  }

  Future<void> _setCookiesForAllDomains(CookieManager cookieManager) async {
    final cookieParts = widget.cookies.split(';');

    for (final domain in _targetDomains) {
      for (final cookiePart in cookieParts) {
        final trimmed = cookiePart.trim();
        if (trimmed.isEmpty) continue;

        final eqIndex = trimmed.indexOf('=');
        if (eqIndex <= 0) continue;

        final name = trimmed.substring(0, eqIndex).trim();
        final value = trimmed.substring(eqIndex + 1).trim();

        final url = WebUri('https://${domain.replaceFirst('.', '')}');

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

  String _buildLocalStorageScript() {
    final escapedJson = widget.localStorage
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r');

    return """
    (function() {
      try {
        var data = JSON.parse('$escapedJson');
        for (var key in data) {
          if (data.hasOwnProperty(key)) {
            window.localStorage.setItem(key, typeof data[key] === 'string' ? data[key] : JSON.stringify(data[key]));
          }
        }
      } catch(e) {
        console.error('LocalStorage injection error:', e);
      }
    })();
    """;
  }

  Future<void> _resetSession() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => _buildResetDialog(),
    );

    if (confirmed == true) {
      final cookieManager = CookieManager.instance();
      await cookieManager.deleteAllCookies();

      if (_webViewController != null) {
        await _webViewController!.clearHistory();
        await InAppWebViewController.clearAllCache();
      }

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const AuthenticationScreen(),
          transitionsBuilder:
              (context, animation, secondaryAnimation, child) {
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
                  'This will clear all session data and return to the authentication screen.',
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
    return Scaffold(
      backgroundColor: AppColors.deepBlack,
      body: SafeArea(
        child: Stack(
          children: [
            if (_isReady)
              InAppWebView(
                initialUrlRequest: URLRequest(
                  url: WebUri('https://app.tapsi.cab/profile/'),
                ),
                initialUserScripts: UnmodifiableListView([
                  UserScript(
                    source: _buildLocalStorageScript(),
                    injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                  ),
                ]),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  domStorageEnabled: true,
                  databaseEnabled: true,
                  clearSessionCache: false,
                  clearCache: false,
                  cacheEnabled: true,
                  mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                  useWideViewPort: true,
                  supportZoom: true,
                  userAgent:
                      'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
                ),
                onWebViewCreated: (controller) {
                  _webViewController = controller;
                },
                onProgressChanged: (controller, progress) {
                  setState(() => _progress = progress / 100.0);
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
      floatingActionButton: _isReady
          ? Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.neonCyan.withOpacity(0.35),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: FloatingActionButton(
                onPressed: _resetSession,
                backgroundColor: AppColors.darkGray.withOpacity(0.9),
                shape: CircleBorder(
                  side: BorderSide(
                    color: AppColors.neonCyan.withOpacity(0.6),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: AppColors.neonCyan,
                  size: 24,
                ),
              ),
            )
          : null,
    );
  }
}

