// ==========================================
// CORE ENGINE SCREEN (WEBVIEW) WITH FILE LOGGER
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
  
  // 🟢 لیست ذخیره لاگ‌های شبکه و کنسول
  final List<String> _debugLogs = [];

  @override
  void initState() {
    super.initState();
    _extractToken();
    _initializeEngine();
  }

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
      RegExp exp3 = RegExp(r'"(eyJ[a-zA-Z0-9-_.]+)"');
      var match3 = exp3.firstMatch(widget.localStorageStr);
      if (match3 != null) {
        _extractedJwt = match3.group(1)!;
      }
    } catch (e) {
      _debugLogs.add("[DART] Token extraction failed: $e");
    }
  }

  Future<void> _initializeEngine() async {
    CookieManager cookieManager = CookieManager.instance();
    
    List<String> targetDomains = [
      ".tapsi.cab", "app.tapsi.cab", "api.tapsi.cab", 
      ".tapsi.ir", "accounts.tapsi.ir", "accounts-api.tapsi.ir",
      ".tapsi.markets", "www.tapsi.markets"
    ];

    if (widget.cookies.isNotEmpty && widget.cookies != 'empty') {
      List<String> cookiePairs = widget.cookies.split(';');
      for (String pair in cookiePairs) {
        List<String> parts = pair.trim().split('=');
        if (parts.length >= 2) {
          String name = parts[0].trim();
          String value = parts.sublist(1).join('=').trim();
          
          for (String d in targetDomains) {
            String urlStr = "https://" + (d.startsWith('.') ? d.substring(1) : d);
            await cookieManager.setCookie(
              url: WebUri(urlStr), name: name, value: value, domain: d, isSecure: true, sameSite: HTTPCookieSameSitePolicy.NONE,
            );
          }
        }
      }
    }

    if (_extractedJwt.isNotEmpty) {
      for (String d in targetDomains) {
        String urlStr = "https://" + (d.startsWith('.') ? d.substring(1) : d);
        await cookieManager.setCookie(
          url: WebUri(urlStr), name: "token", value: _extractedJwt, domain: d, isSecure: true, sameSite: HTTPCookieSameSitePolicy.NONE,
        );
        await cookieManager.setCookie(
          url: WebUri(urlStr), name: "accessToken", value: _extractedJwt, domain: d, isSecure: true, sameSite: HTTPCookieSameSitePolicy.NONE,
        );
        if (d.contains('tapsi.markets')) {
          await cookieManager.setCookie(
            url: WebUri(urlStr), name: "tokenMS", value: _extractedJwt, domain: d, isSecure: true, sameSite: HTTPCookieSameSitePolicy.NONE,
          );
        }
      }
    }

    setState(() => _isEngineReady = true);
  }

  String _buildInjectionScript() {
    String safeLs = jsonEncode(widget.localStorageStr);
    
    return """
      try {
        var host = window.location.hostname;
        
        if (host.includes('tapsi.cab') || host.includes('accounts.tapsi.ir') || host.includes('tapsi.markets')) {
            var jwt = "$_extractedJwt";
            var rootDomain = host;
            var parts = host.split('.');
            if (parts.length > 2) {
                rootDomain = '.' + parts.slice(-2).join('.');
            } else {
                rootDomain = '.' + host;
            }

            if (jwt) {
               window.localStorage.setItem('token', jwt);
               window.localStorage.setItem('accessToken', jwt);
               document.cookie = "token=" + jwt + "; path=/; domain=" + rootDomain + "; secure; samesite=none";
               document.cookie = "accessToken=" + jwt + "; path=/; domain=" + rootDomain + "; secure; samesite=none";
            }
            
            var rawData = $safeLs;
            if (rawData && rawData !== '{}') {
               var lsData = JSON.parse(rawData);
               for (var key in lsData) {
                  var val = typeof lsData[key] === 'string' ? lsData[key] : JSON.stringify(lsData[key]);
                  window.localStorage.setItem(key, val);
                  window.sessionStorage.setItem(key, val);
               }
            }
        }
        
        // 🟢 تزریق رهگیر ریکوئست‌های شبکه (Network Interceptor)
        var originalFetch = window.fetch;
        window.fetch = async function() {
          var url = typeof arguments[0] === 'string' ? arguments[0] : (arguments[0].url || 'unknown_url');
          if(url.includes('tapsi')) {
             window.flutter_inappwebview.callHandler('networkLog', '[REQ] ' + url);
          }
          try {
            var response = await originalFetch.apply(this, arguments);
            if(url.includes('tapsi')) {
                window.flutter_inappwebview.callHandler('networkLog', '[RES] ' + response.status + ' | ' + response.url);
            }
            return response;
          } catch(e) {
            window.flutter_inappwebview.callHandler('networkLog', '[ERR] ' + url + ' | ' + e);
            throw e;
          }
        };

      } catch(e) {
        console.error("Injection Engine Error: ", e);
      }
      
      window.open = function(url, target, features) {
        window.location.href = url;
        return null;
      };
      
      document.addEventListener('click', function(e) {
        var a = e.target.closest('a');
        if (a && a.getAttribute('target') === '_blank') {
          a.setAttribute('target', '_self');
        }
      }, true);
    """;
  }

  // 🟢 متد ساخت فایل و باز کردن منوی اشتراک‌گذاری
  Future<void> _exportLogs() async {
    try {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('در حال جمع‌آوری و ساخت فایل لاگ...')),
      );

      CookieManager cookieManager = CookieManager.instance();
      List<Cookie> cabCookies = await cookieManager.getCookies(url: WebUri("https://app.tapsi.cab"));
      List<Cookie> marketCookies = await cookieManager.getCookies(url: WebUri("https://www.tapsi.markets"));
      
      String marketLs = await webViewController?.evaluateJavascript(source: "JSON.stringify(window.localStorage);") ?? "{}";
      String currentUrl = (await webViewController?.getUrl())?.toString() ?? "unknown";

      StringBuffer sb = StringBuffer();
      sb.writeln("=== TAPSI DEBUG LOGS ===");
      sb.writeln("TIME: ${DateTime.now().toIso8601String()}");
      sb.writeln("CURRENT URL: $currentUrl");
      sb.writeln("\n--- CAB COOKIES ---");
      for (var c in cabCookies) { sb.writeln("${c.name} = ${c.value} (Domain: ${c.domain})"); }
      sb.writeln("\n--- MARKET COOKIES ---");
      for (var c in marketCookies) { sb.writeln("${c.name} = ${c.value} (Domain: ${c.domain})"); }
      sb.writeln("\n--- MARKET LOCAL STORAGE ---");
      sb.writeln(marketLs);
      sb.writeln("\n--- NETWORK & CONSOLE ---");
      for (var log in _debugLogs) { sb.writeln(log); }

      // 🟢 دریافت مسیر موقت سیستم‌عامل
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/Tapsi_Logs_${DateTime.now().millisecondsSinceEpoch}.txt';
      final file = File(filePath);
      
      // 🟢 ذخیره اطلاعات داخل فایل
      await file.writeAsString(sb.toString());
      
      // 🟢 باز کردن دیالوگ اشتراک‌گذاری سیستم‌عامل
      await Share.shareXFiles([XFile(filePath)], text: 'فایل دیباگ تپسی مارکت');

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطا در خروجی لاگ: $e')));
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
            children: const [
              SizedBox(width: 40, height: 40, child: CircularProgressIndicator(color: Color(0xFF5CEBFF), strokeWidth: 2)),
              SizedBox(height: 24),
              Text('INITIALIZING CORE ENGINE...', style: TextStyle(color: Color(0xFF5CEBFF), letterSpacing: 3.0, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          )
        )
      );
    }

    UserScript injectionScript = UserScript(
      source: _buildInjectionScript(),
      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
      forMainFrameOnly: false, 
    );

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        if (webViewController != null && await webViewController!.canGoBack()) {
          webViewController!.goBack();
        } else {
          if (context.mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0C10),
        body: SafeArea(
          child: Stack(
            children: [
              InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri("https://app.tapsi.cab/profile/")),
                initialUserScripts: UnmodifiableListView<UserScript>([injectionScript]),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  domStorageEnabled: true,
                  clearCache: false,
                  thirdPartyCookiesEnabled: true, 
                  supportMultipleWindows: false,
                  javaScriptCanOpenWindowsAutomatically: false,
                  userAgent: "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Mobile Safari/537.36",
                ),
                onWebViewCreated: (controller) {
                  webViewController = controller;
                  // 🟢 دریافت لاگ‌های شبکه از محیط وب
                  controller.addJavaScriptHandler(handlerName: 'networkLog', callback: (args) {
                    if (args.isNotEmpty) _debugLogs.add(args[0].toString());
                  });
                },
                // 🟢 دریافت لاگ‌های کنسول (خطاهای جاوااسکریپت)
                onConsoleMessage: (controller, consoleMessage) {
                  _debugLogs.add("[CONSOLE] ${consoleMessage.messageLevel}: ${consoleMessage.message}");
                },
                onLoadStop: (controller, url) async {
                  if (url != null && url.host == 'app.tapsi.cab') {
                    bool? isReloaded = await controller.evaluateJavascript(source: "window.sessionStorage.getItem('core_init');") == 'true';
                    if (!isReloaded) {
                      await controller.evaluateJavascript(source: "window.sessionStorage.setItem('core_init', 'true');");
                      controller.reload();
                    }
                  }
                },
              ),
              // 🟢 دکمه شناور برای استخراج لاگ‌ها
              Positioned(
                bottom: 20,
                right: 20,
                child: FloatingActionButton(
                  backgroundColor: const Color(0xFF5CEBFF),
                  mini: true,
                  onPressed: _exportLogs,
                  child: const Icon(Icons.bug_report_rounded, color: Colors.black),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
