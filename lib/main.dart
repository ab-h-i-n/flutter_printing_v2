import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as image;
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Webpage to Printer',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
      ),
      home: const PrinterConnectionScreen(),
    );
  }
}

class PrinterConnectionScreen extends StatefulWidget {
  const PrinterConnectionScreen({super.key});

  @override
  State<PrinterConnectionScreen> createState() =>
      _PrinterConnectionScreenState();
}

class _PrinterConnectionScreenState extends State<PrinterConnectionScreen> {
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _checkExistingConnection();
  }

  Future<void> _checkExistingConnection() async {
    final bool isConnected = await PrintBluetoothThermal.connectionStatus;
    if (isConnected) {
      _navigateToUrlEntry();
    }
  }

  Future<void> _requestBluetoothPermission() async {
    await Permission.location.request();
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
  }

  Future<void> _showPrinterSelectionDialog() async {
    await _requestBluetoothPermission();

    final List<BluetoothInfo>? pairedDevices =
        await PrintBluetoothThermal.pairedBluetooths;

    if (!mounted) return;
    if (pairedDevices == null || pairedDevices.isEmpty) {
      _showMessage('No paired Bluetooth devices found. Please pair your printer first.');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Printer'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: pairedDevices.length,
              itemBuilder: (context, index) {
                final device = pairedDevices[index];
                return ListTile(
                  leading: const Icon(Icons.print),
                  title: Text(device.name),
                  subtitle: Text(device.macAdress),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await _connectToPrinter(device);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _connectToPrinter(BluetoothInfo device) async {
    setState(() => _isConnecting = true);

    try {
      final bool isConnected = await PrintBluetoothThermal.connect(
        macPrinterAddress: device.macAdress,
      );

      if (!mounted) return;
      if (isConnected) {
        _showMessage('Connected to ${device.name}');
        _navigateToUrlEntry();
      } else {
        _showMessage('Failed to connect to ${device.name}');
      }
    } catch (e) {
      if (mounted) _showMessage('Error connecting to printer: $e');
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  void _navigateToUrlEntry() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const UrlEntryScreen()),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect Printer'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.print,
                size: 80,
                color: Colors.blue,
              ),
              const SizedBox(height: 24),
              const Text(
                'Connect to Thermal Printer',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Please connect to your Bluetooth thermal printer to continue.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 32),
              _isConnecting
                  ? const Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Connecting...'),
                      ],
                    )
                  : ElevatedButton.icon(
                      onPressed: _showPrinterSelectionDialog,
                      icon: const Icon(Icons.bluetooth),
                      label: const Text('Select Printer'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class UrlEntryScreen extends StatefulWidget {
  const UrlEntryScreen({super.key});

  @override
  State<UrlEntryScreen> createState() => _UrlEntryScreenState();
}

class _UrlEntryScreenState extends State<UrlEntryScreen> {
  final TextEditingController _urlController = TextEditingController();
  bool _isLoading = false;

  Future<void> _loadWebpage() async {
    final String url = _urlController.text.trim();

    if (url.isEmpty) {
      _showMessage('Please enter a URL');
      return;
    }

    final Uri? parsedUri = Uri.tryParse(url);
    if (parsedUri == null || !parsedUri.hasScheme) {
      _showMessage('Please enter a valid URL (e.g., https://example.com)');
      return;
    }

    setState(() => _isLoading = true);

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => WebViewScreen(url: url),
      ),
    );

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enter URL'),
        leading: const Icon(Icons.bluetooth_connected),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.language,
              size: 60,
              color: Colors.blue,
            ),
            const SizedBox(height: 24),
            const Text(
              'Enter Webpage URL',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Enter the URL of the webpage you want to print',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'Webpage URL',
                hintText: 'https://example.com',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => _loadWebpage(),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _loadWebpage,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.open_in_browser),
              label: Text(_isLoading ? 'Loading...' : 'Load Webpage'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WebViewScreen extends StatefulWidget {
  final String url;

  const WebViewScreen({super.key, required this.url});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _webViewController;
  final GlobalKey _webviewKey = GlobalKey();

  bool _isPageLoading = true;
  bool _isPrinting = false;
  bool _isCapturing = false;
  Uint8List? _capturedImageBytes;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isPageLoading = true;
              _capturedImageBytes = null;
            });
          },
          onPageFinished: (String url) {
            setState(() => _isPageLoading = false);
            Future.delayed(
              const Duration(milliseconds: 1000),
              _captureFullPage,
            );
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<bool> _waitForElement({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    const String checkElementScript =
        "document.getElementById('printable-content') !== null";
    final stopwatch = Stopwatch()..start();
    while (stopwatch.elapsed < timeout) {
      final result = await _webViewController
          .runJavaScriptReturningResult(checkElementScript);
      if (result == true || result.toString() == 'true') return true;
      await Future.delayed(const Duration(milliseconds: 250));
    }
    return false;
  }

  Future<void> _captureFullPage() async {
    if (_isCapturing) return;
    setState(() => _isCapturing = true);

    try {
      final bool elementExists = await _waitForElement();
      if (!mounted || !elementExists) {
        _showMessage('Element with id="printable-content" not found.');
        return;
      }

      final dynamic dimensionsResult =
          await _webViewController.runJavaScriptReturningResult("""
        (function() {
          var element = document.getElementById('printable-content');
          var rect = element.getBoundingClientRect();
          return {
            'x': Math.round(rect.left),
            'y': Math.round(rect.top),
            'width': Math.round(rect.width),
            'height': Math.round(rect.height),
            'totalHeight': Math.round(element.scrollHeight)
          };
        })();
      """);

      if (!mounted) return;

      final Map<String, dynamic> dimensions =
          jsonDecode(dimensionsResult.toString());
      final int width = dimensions['width'] ?? 0;
      final int totalHeight = dimensions['totalHeight'] ?? 0;

      if (width == 0 || totalHeight == 0) {
        _showMessage('Printable content has zero dimensions.');
        return;
      }

      await _webViewController.runJavaScript("""
        document.getElementById('printable-content').scrollTo(0, 0);
      """);
      await Future.delayed(const Duration(milliseconds: 300));

      final double pixelRatio = MediaQuery.of(context).devicePixelRatio;
      final int viewportHeight =
          (MediaQuery.of(context).size.height * pixelRatio).round();
      final int screenshotsNeeded = (totalHeight / viewportHeight).ceil();

      debugPrint('Capturing $screenshotsNeeded screenshots for total height: $totalHeight');

      List<Uint8List> screenshotParts = [];

      for (int i = 0; i < screenshotsNeeded; i++) {
        if (!mounted) break;

        final int scrollPosition = i * viewportHeight;
        await _webViewController.runJavaScript("""
          document.getElementById('printable-content').scrollTo(0, $scrollPosition);
        """);

        await Future.delayed(const Duration(milliseconds: 200));

        final RenderRepaintBoundary boundary =
            _webviewKey.currentContext!.findRenderObject() as RenderRepaintBoundary;

        final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
        final ByteData? byteData =
            await image.toByteData(format: ui.ImageByteFormat.png);

        if (byteData != null) {
          screenshotParts.add(byteData.buffer.asUint8List());
        }

        debugPrint('Captured screenshot ${i + 1}/$screenshotsNeeded');
      }

      if (screenshotParts.isNotEmpty) {
        final Uint8List fullImage = await _stitchScreenshots(
            screenshotParts, width, totalHeight, pixelRatio);
        setState(() {
          _capturedImageBytes = fullImage;
        });
        _showMessage('Screenshot captured successfully!');
      } else {
        _showMessage('Failed to capture any screenshots.');
      }
    } catch (e) {
      debugPrint('Error capturing content: $e');
      if (mounted) _showMessage('Error capturing content: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<Uint8List> _stitchScreenshots(List<Uint8List> screenshots, int width,
      int totalHeight, double pixelRatio) async {
    final image.Image fullImage = image.Image(
        width: (width * pixelRatio).round(),
        height: (totalHeight * pixelRatio).round());

    int currentY = 0;

    for (final Uint8List screenshotData in screenshots) {
      final image.Image? part = image.decodeImage(screenshotData);
      if (part == null) continue;

      final int partHeight = (currentY + part.height > fullImage.height)
          ? fullImage.height - currentY
          : part.height;

      for (int y = 0; y < partHeight; y++) {
        for (int x = 0; x < part.width; x++) {
          if (x < fullImage.width) {
            final image.Pixel color = part.getPixel(x, y);
            fullImage.setPixel(x, currentY + y, color);
          }
        }
      }

      currentY += partHeight;
    }

    return Uint8List.fromList(image.encodePng(fullImage));
  }

  Future<void> _printBill() async {
    if (_capturedImageBytes == null) {
      _showMessage('No image to print.');
      return;
    }
    setState(() => _isPrinting = true);
    try {
      final CapabilityProfile profile = await CapabilityProfile.load();
      final Generator generator = Generator(PaperSize.mm58, profile);
      List<int> bytes = [];

      final image.Image? capturedImage = image.decodeImage(_capturedImageBytes!);
      if (capturedImage == null) {
        _showMessage('Failed to decode image for printing.');
        return;
      }
      
      const int targetWidth = 384;
      final image.Image resizedImage =
          image.copyResize(capturedImage, width: targetWidth);

      bytes += generator.image(resizedImage);
      bytes += generator.feed(2);
      bytes += generator.cut();

      await PrintBluetoothThermal.writeBytes(bytes);
      _showMessage('Print command sent successfully!');
    } catch (e) {
      _showMessage('Error printing: $e');
      debugPrint('Print error: $e');
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bill Preview'),
        actions: [
          IconButton(
            onPressed: (_isCapturing || _isPageLoading) ? null : _captureFullPage,
            icon: _isCapturing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Recapture Content',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isPageLoading || _isCapturing) const LinearProgressIndicator(),
          Expanded(
            child: RepaintBoundary(
              key: _webviewKey,
              child: WebViewWidget(
                controller: _webViewController,
              ),
            ),
          ),
          if (_capturedImageBytes != null)
            Container(
              height: 250,
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                border: Border(top: BorderSide(color: Colors.grey.shade400)),
              ),
              child: Center(child: Image.memory(_capturedImageBytes!)),
            ),
        ],
      ),
      floatingActionButton: (_capturedImageBytes != null && !_isPageLoading)
          ? FloatingActionButton.extended(
              onPressed: _isPrinting ? null : _printBill,
              icon: _isPrinting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.print),
              label: Text(_isPrinting ? 'Printing...' : 'Print Bill'),
            )
          : null,
    );
  }
}