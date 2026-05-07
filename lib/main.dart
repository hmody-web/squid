import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // قفل الاتجاه عمودياً فقط (غيّر إلى landscape إذا أردت)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Squid Jump',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0e62ad)),
        useMaterial3: true,
      ),
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  InAppWebViewController? _webViewController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAndSendHighScore();
  }

  /// تحميل النتيجة العالية المحفوظة وإرسالها للصفحة بعد تحميلها
  Future<void> _loadAndSendHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    final highScore = prefs.getInt('highScore') ?? 0;

    // إرسال النتيجة للصفحة بعد تأخير قصير لضمان تحميلها
    Future.delayed(const Duration(milliseconds: 800), () {
      _webViewController?.evaluateJavascript(
        source: 'setHighScoreFromFlutter($highScore);',
      );
    });
  }

  /// حفظ النتيجة العالية في SharedPreferences
  Future<void> _saveHighScore(int score) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt('highScore') ?? 0;
    if (score > current) {
      await prefs.setInt('highScore', score);
      debugPrint('✅ High Score saved: $score');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0e62ad),
      body: Stack(
        children: [
          // ==================== WebView ====================
          InAppWebView(
            initialFile: 'assets/web/index.html',
            initialSettings: InAppWebViewSettings(
              // السماح بالوصول للملفات المحلية
              allowFileAccessFromFileURLs: true,
              allowUniversalAccessFromFileURLs: true,

              // السماح بتشغيل الصوت بدون تدخل المستخدم
              mediaPlaybackRequiresUserGesture: false,

              // تفعيل JavaScript
              javaScriptEnabled: true,

              // دعم localStorage
              databaseEnabled: true,
              domStorageEnabled: true,

              // إخفاء شريط التمرير
              horizontalScrollBarEnabled: false,
              verticalScrollBarEnabled: false,

              // منع التكبير بالإصبعين
              supportZoom: false,
              builtInZoomControls: false,
              displayZoomControls: false,

              // شفافية الخلفية
              transparentBackground: true,
            ),

            onWebViewCreated: (controller) {
              _webViewController = controller;

              // ==================== JavaScript Channel ====================
              // استقبال الرسائل من صفحة الويب (حفظ النتيجة)
              controller.addJavaScriptHandler(
                handlerName: 'FlutterChannel',
                callback: (args) async {
                  if (args.isEmpty) return;
                  final message = args[0].toString();

                  // معالجة رسالة حفظ النتيجة العالية
                  if (message.startsWith('saveHighScore:')) {
                    final scoreStr = message.split(':').last;
                    final score = int.tryParse(scoreStr) ?? 0;
                    await _saveHighScore(score);
                  }

                  debugPrint('📩 Flutter received: $message');
                },
              );
            },

            onLoadStart: (controller, url) {
              setState(() => _isLoading = true);
            },

            onLoadStop: (controller, url) async {
              setState(() => _isLoading = false);

              // إرسال النتيجة العالية للصفحة بعد تحميلها
              await _loadAndSendHighScore();

              debugPrint('✅ Page loaded: $url');
            },

            onConsoleMessage: (controller, consoleMessage) {
              // عرض رسائل console من JavaScript في debug
              debugPrint('🌐 JS Console: ${consoleMessage.message}');
            },

            onReceivedError: (controller, request, error) {
              debugPrint('❌ WebView Error: ${error.description}');
            },

            // منع فتح روابط خارجية
            shouldOverrideUrlLoading: (controller, navigationAction) async {
              final url = navigationAction.request.url?.toString() ?? '';
              // السماح فقط بالملفات المحلية
              if (url.startsWith('file://') || url == 'about:blank') {
                return NavigationActionPolicy.ALLOW;
              }
              // منع أي رابط خارجي
              debugPrint('🚫 Blocked external URL: $url');
              return NavigationActionPolicy.CANCEL;
            },
          ),

          // ==================== شاشة التحميل ====================

        ],
      ),
    );
  }

  @override
  void dispose() {
    // إعادة شريط الحالة عند الخروج من الصفحة
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }
}