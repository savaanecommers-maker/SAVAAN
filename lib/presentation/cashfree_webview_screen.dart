import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class CashfreeWebViewScreen extends StatefulWidget {
  final String paymentSessionId;
  final String orderNumber;
  final double total;

  const CashfreeWebViewScreen({
    super.key,
    required this.paymentSessionId,
    required this.orderNumber,
    required this.total,
  });

  @override
  State<CashfreeWebViewScreen> createState() => _CashfreeWebViewScreenState();
}

class _CashfreeWebViewScreenState extends State<CashfreeWebViewScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  static const Color _teal = Color(0xFF0D9488);

  @override
  void initState() {
    super.initState();

    final sessionId   = widget.paymentSessionId;
    final orderNumber = widget.orderNumber;

    // Return URL pattern Flutter watches for to detect completion
    const returnBase = 'https://api.savaan.in/api/payments/cashfree/return';

    final html = '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { font-family: -apple-system, sans-serif; background: #f8fafc; }
    .loader {
      display: flex; flex-direction: column;
      align-items: center; justify-content: center;
      height: 100vh; gap: 16px;
    }
    .spinner {
      width: 40px; height: 40px;
      border: 3px solid #e2e8f0;
      border-top-color: #0D9488;
      border-radius: 50%;
      animation: spin 0.8s linear infinite;
    }
    @keyframes spin { to { transform: rotate(360deg); } }
    p { color: #64748b; font-size: 14px; }
  </style>
</head>
<body>
  <div class="loader" id="loader">
    <div class="spinner"></div>
    <p>Loading payment...</p>
  </div>
  <script src="https://sdk.cashfree.com/js/v3/cashfree.js"></script>
  <script>
    window.onload = function () {
      try {
        const cashfree = Cashfree({ mode: "production" });
        cashfree.checkout({
          paymentSessionId: "$sessionId",
          returnUrl: "$returnBase?order_id=$orderNumber&status={status}",
        });
        document.getElementById("loader").style.display = "none";
      } catch(e) {
        document.getElementById("loader").innerHTML =
          "<p style='color:red;padding:20px'>Failed to load payment. Please go back and try again.</p>";
      }
    };
  </script>
</body>
</html>
''';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
        onNavigationRequest: (req) {
          final url = req.url;
          // Detect return URL from Cashfree
          if (url.startsWith(returnBase)) {
            final uri    = Uri.parse(url);
            final status = uri.queryParameters['status'] ?? '';
            if (mounted) {
              Navigator.pop(context, status == 'SUCCESS' ? 'success' : 'failed');
            }
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadHtmlString(html, baseUrl: 'https://api.savaan.in');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _teal,
        foregroundColor: Colors.white,
        title: const Text('Secure Payment',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context, 'cancelled'),
        ),
        elevation: 0,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const Center(child: CircularProgressIndicator(color: _teal)),
        ],
      ),
    );
  }
}
