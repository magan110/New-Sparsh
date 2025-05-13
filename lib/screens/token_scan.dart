import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'token_summary_model.dart';
import 'token_details.dart';
import 'token_summary.dart';

class TokenScanPage extends StatefulWidget {
  const TokenScanPage({super.key});
  @override
  State<TokenScanPage> createState() => _TokenScanPageState();
}

class _TokenScanPageState extends State<TokenScanPage> {
  MobileScannerController? _cameraController;
  String? _scannedValue;
  String? _pinValidationMessage;
  bool _isTokenValid = false;
  int _remainingAttempts = 3;
  final List<TextEditingController> pinControllers =
  List.generate(3, (_) => TextEditingController());
  List<FocusNode> pinFocusNodes = List.generate(3, (_) => FocusNode());
  bool _isTorchOn = false;
  bool _isProcessingScan = false;
  DateTime? _lastScanTime;

  final List<TokenCard> _attemptedCards = [];
  String? _apiAutoPin;
  bool _showMaxAttemptsError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeCamera();
    });
  }

  Future<void> _initializeCamera() async {
    try {
      if (_cameraController != null) {
        await _cameraController?.stop();
        _cameraController?.dispose();
      }

      setState(() {
        _cameraController = MobileScannerController(
          detectionSpeed: DetectionSpeed.normal,
          facing: CameraFacing.back,
          formats: [BarcodeFormat.qrCode],
          torchEnabled: false,
        );
      });

      await _cameraController?.start();
    } catch (e) {
      print('Camera initialization error: $e');
      // Retry camera initialization after a short delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _initializeCamera();
      });
    }
  }


  void _validateToken(String value) {
    final now = DateTime.now();
    if (_lastScanTime != null &&
        now.difference(_lastScanTime!) < const Duration(milliseconds: 500)) {
      return;
    }
    _lastScanTime = now;

    if (_scannedValue == value || _isProcessingScan) return;

    setState(() {
      _isProcessingScan = true;
      _scannedValue = value;
      _isTokenValid = false;
      _pinValidationMessage = null;
      _remainingAttempts = 3;
      _apiAutoPin = null;
      _showMaxAttemptsError = false;
    });

    _fetchTokenDetails(value);
  }

  Future<void> _fetchTokenDetails(String value) async {
    try {
      final response = await http.post(
        Uri.parse('https://qa.birlawhite.com:55232/api/TokenValidate/validate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'tokenNum': value,
          'tokenCvv': '',
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic> && data.containsKey('tokenCvv')) {
          setState(() {
            _apiAutoPin = data['tokenCvv']?.toString();
          });
        }
      }
    } catch (_) {
      // Handle error silently
    } finally {
      setState(() {
        _isProcessingScan = false;
      });
      _showPinDialog();
    }
  }

  Future<void> _validatePin(String value) async {
    if (_remainingAttempts <= 0) {
      setState(() {
        _showMaxAttemptsError = true;
      });
      return;
    }

    final tokenNum = _scannedValue;
    try {
      final response = await http.post(
        Uri.parse('https://qa.birlawhite.com:55232/api/TokenValidate/validate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'tokenNum': tokenNum, 'tokenCvv': value}),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 &&
          response.body.contains('Validate Successfully')) {
        final scanResponse = await http.post(
            Uri.parse('https://qa.birlawhite.com:55232/api/TokenScan/scan'),
            body: {'token': tokenNum}
        ).timeout(const Duration(seconds: 5));

        Map<String, dynamic> detail = {};
        if (scanResponse.statusCode == 200) {
          detail = jsonDecode(scanResponse.body);
        }

        setState(() {
          _pinValidationMessage = '✅ PIN $value is Correct!';
          _isTokenValid = true;
          _addAttemptedToken(value, true, detail);
        });

        await Future.delayed(const Duration(milliseconds: 800));
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
        _restartScan();
      } else {
        setState(() {
          _remainingAttempts--;
          _pinValidationMessage =
          '❌ PIN $value is Incorrect. $_remainingAttempts attempts left.';
          _addAttemptedToken(value, false, {});

          if (_remainingAttempts <= 0) {
            _isTokenValid = false;
            _showMaxAttemptsError = true;
            Future.delayed(const Duration(milliseconds: 900), () {
              if (Navigator.of(context).canPop()) Navigator.of(context).pop();
              _showMaxRetryDialog();
            });
          }
        });
      }
    } catch (e) {
      setState(() {
        _remainingAttempts--;
        _pinValidationMessage =
        '❌ Error. $_remainingAttempts attempts left.';
        _addAttemptedToken(value, false, {});

        if (_remainingAttempts <= 0) {
          _isTokenValid = false;
          _showMaxAttemptsError = true;
          Future.delayed(const Duration(milliseconds: 900), () {
            if (Navigator.of(context).canPop()) Navigator.of(context).pop();
            _showMaxRetryDialog();
          });
        }
      });
    }
  }

  void _addAttemptedToken(String enteredPin, bool isValid, Map<String, dynamic> detail) {
    setState(() {
      _attemptedCards.insert(
        0,
        TokenCard(
          token: _scannedValue ?? '',
          id: isValid ? (detail['id']?.toString() ?? '') : '',
          date: isValid ? (detail['date']?.toString() ?? '') : '',
          value: isValid ? (detail['value']?.toString() ?? '') : '',
          handling: isValid ? (detail['handling']?.toString() ?? '') : '',
          isValid: isValid,
          pin: enteredPin,
        ),
      );
    });

    final summary = TokenSummaryModel();
    summary.addScan(
      isValid: isValid,
      value: isValid ? int.tryParse(detail['value']?.toString() ?? '0') ?? 0 : 0,
      tokenDetail: detail,
    );
  }

  void _restartScan() {
    setState(() {
      _scannedValue = null;
      _isTokenValid = false;
      _pinValidationMessage = null;
      _remainingAttempts = 3;
      _showMaxAttemptsError = false;
      _isProcessingScan = false;
      for (var controller in pinControllers) {
        controller.clear();
      }
      pinFocusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    _cameraController?.stop();
    _cameraController?.dispose();
    for (var node in pinFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _showMaxRetryDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Max Attempts Reached'),
        content: const Text('You have entered wrong PIN 3 times.\nPlease contact IT or Company Officer.'),
        actions: [
          TextButton(
            child: const Text("OK"),
            onPressed: () {
              Navigator.of(context).pop();
              _restartScan();
            },
          )
        ],
      ),
    );
  }

void _showPinDialog() {
  String autoPin = (_apiAutoPin ?? '').trim();
  for (int i = 0; i < 3; i++) {
    pinControllers[i].text = (autoPin.length == 3) ? autoPin[i] : '';
  }

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setStateInner) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            contentPadding: const EdgeInsets.all(20),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade300,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      "Enter PIN to Validate Token",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text("Token No.", style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _scannedValue ?? '',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text("Enter Pin Code :", style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (index) {
                      return Container(
                        width: 50,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        child: TextField(
                          controller: pinControllers[index],
                          focusNode: pinFocusNodes[index],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          maxLength: 1,
                          obscureText: false,
                          autofocus: index == 0,
                          enabled: !_showMaxAttemptsError,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            counterText: '',
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onChanged: (value) async {
                            if (value.isNotEmpty) {
                              if (index < 2) {
                                FocusScope.of(context).requestFocus(pinFocusNodes[index + 1]);
                              }
                              String pin = pinControllers.map((c) => c.text).join();
                              if (pin.length == 3 && 
                                  pinControllers.every((c) => c.text.isNotEmpty && RegExp(r'\d').hasMatch(c.text))) {
                                FocusScope.of(context).unfocus();
                                await _validatePin(pin);
                                setStateInner(() {});
                              }
                            } else if (index > 0) {
                              FocusScope.of(context).requestFocus(pinFocusNodes[index - 1]);
                            }
                          },
                          onTap: () {
                            pinControllers[index].selection = TextSelection.fromPosition(
                              TextPosition(offset: pinControllers[index].text.length),
                            );
                          },
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  if (_showMaxAttemptsError)
                    const Text(
                      "❌ You have reached the maximum attempts.",
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  if (_pinValidationMessage != null && !_showMaxAttemptsError)
                    Text(
                      _pinValidationMessage ?? '',
                      style: TextStyle(
                        color: _pinValidationMessage!.contains('❌') ? Colors.red : Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            SizedBox(
              height: 280,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _cameraController != null
                          ? MobileScanner(
                        controller: _cameraController,
                        onDetect: (capture) {
                          final barcode = capture.barcodes.first;
                          if (barcode.rawValue != null &&
                              barcode.format == BarcodeFormat.qrCode) {
                            _validateToken(barcode.rawValue!);
                          }
                        },
                        scanWindow: Rect.largest,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, child) {
                          return Center(child: Text('Camera error: $error'));
                        },
                      )
                          : const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 20,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                        child: IconButton(
                          icon: Icon(
                            _isTorchOn ? Icons.flash_off : Icons.flash_on,
                            color: Colors.black,
                          ),
                          onPressed: () {
                            _cameraController?.toggleTorch().then((_) {
                              setState(() {
                                _isTorchOn = !_isTorchOn;
                              });
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                  if (_isProcessingScan)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black54,
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Scan a token',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              height: 1,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 8),
            _buildTopNav(context, 'Details'),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  if (_attemptedCards.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        "Token/PIN Attempts:",
                        style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ..._attemptedCards,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopNav(BuildContext context, String activeTab) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300, width: 1.0),
          borderRadius: BorderRadius.circular(8.0),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(context, 'Details', activeTab == 'Details',
                const TokenDetailsPage(activeTab: 'Details')),
            _navItem(context, 'Summary', activeTab == 'Summary',
                const TokenSummaryScreen(activeTab: 'Summary')),
          ],
        ),
      ),
    );
  }

  Widget _navItem(
      BuildContext context, String label, bool isActive, Widget targetPage) {
    return GestureDetector(
      onTap: () {
        if (!isActive) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => targetPage),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? const Color.fromRGBO(0, 112, 183, 1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.black,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

class TokenCard extends StatefulWidget {
  final String token;
  final String id;
  final String date;
  final String value;
  final String handling;
  final bool isValid;
  final String pin;

  const TokenCard({
    super.key,
    required this.token,
    required this.id,
    required this.date,
    required this.value,
    required this.handling,
    required this.isValid,
    required this.pin,
  });

  @override
  State<TokenCard> createState() => _TokenCardState();
}

class _TokenCardState extends State<TokenCard> {
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => isExpanded = !isExpanded),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: widget.isValid ? Colors.blue : Colors.red,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.token,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.white,
              child: widget.isValid
                  ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.id.isNotEmpty) Text('ID: ${widget.id}'),
                  if (widget.date.isNotEmpty)
                    Text('Valid Upto: ${widget.date}'),
                  if (widget.value.isNotEmpty)
                    Text('Value To Pay: ₹${widget.value}'),
                  if (widget.handling.isNotEmpty)
                    Text('Handling: ₹${widget.handling}'),
                  Row(
                    children: [
                      const Text('PIN: '),
                      Container(
                        width: 50,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.blue),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(widget.pin,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Accepted',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              )
                  : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Error - ${widget.token}',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.red)),
                  const Text(
                    'Please check with IT or Company Officer',
                    style: TextStyle(
                      fontSize: 16,
                    ),
                  ),
                  Row(
                    children: [
                      const Text('Tried PIN: '),
                      Container(
                        width: 50,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.red),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(widget.pin,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Rejected',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}