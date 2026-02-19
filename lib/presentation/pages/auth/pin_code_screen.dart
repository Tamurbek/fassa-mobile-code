import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../logic/pos_controller.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/responsive.dart';
import '../main_navigation_screen.dart';

class PinCodeScreen extends StatefulWidget {
  final bool isSettingNewPin;
  const PinCodeScreen({super.key, this.isSettingNewPin = false});

  @override
  State<PinCodeScreen> createState() => _PinCodeScreenState();
}

class _PinCodeScreenState extends State<PinCodeScreen> {
  final POSController pos = Get.find<POSController>();
  String _enteredPin = "";
  String _firstPin = ""; 
  bool _isConfirming = false;

  void _onDigitPress(String digit) {
    if (_enteredPin.length < 4) {
      setState(() {
        _enteredPin += digit;
      });

      if (_enteredPin.length == 4) {
        _handlePinComplete();
      }
    }
  }

  void _onBackspace() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  void _handlePinComplete() async {
    if (widget.isSettingNewPin) {
      if (!_isConfirming) {
        setState(() {
          _firstPin = _enteredPin;
          _enteredPin = "";
          _isConfirming = true;
        });
      } else {
        if (_enteredPin == _firstPin) {
          pos.setPinCode(_enteredPin);
          pos.authenticatePin(true);
          Get.snackbar("Success", "PIN code established successfully", 
            backgroundColor: Colors.green, colorText: Colors.white);
          Get.offAll(() => const MainNavigationScreen());
        } else {
          Get.snackbar("Error", "PIN codes do not match. Try again.", 
            backgroundColor: Colors.red, colorText: Colors.white);
          setState(() {
            _enteredPin = "";
          });
        }
      }
    } else {
      if (_enteredPin == pos.pinCode.value) {
        pos.authenticatePin(true);
        Get.offAll(() => const MainNavigationScreen());
      } else {
        Get.snackbar("Error", "Incorrect PIN code", 
          backgroundColor: Colors.red, colorText: Colors.white);
        setState(() {
          _enteredPin = "";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String titleText = widget.isSettingNewPin 
      ? (_isConfirming ? "confirm_pin".tr : "set_new_pin".tr) 
      : "enter_pin".tr;
    
    String subtitleText = widget.isSettingNewPin
      ? (_isConfirming ? "confirm_pin_msg".tr : "set_pin_msg".tr)
      : "pin_subtitle".tr;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F7FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 400,
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 30,
                              offset: const Offset(0, 15),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildHeaderIcon(),
                            const SizedBox(height: 24),
                            Text(
                              titleText,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1A1A1A),
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              subtitleText,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF6B7280),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 32),
                            _buildPinIndicators(),
                            const SizedBox(height: 32),
                            _buildKeypad(),
                            const SizedBox(height: 24),
                            TextButton(
                              onPressed: () {},
                              child: Text(
                                'forgot_pin'.tr,
                                style: const TextStyle(
                                  color: Color(0xFF9CA3AF),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildFooter(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            const Icon(Icons.print_rounded, color: Color(0xFFFF9500), size: 28),
            const SizedBox(width: 12),
            const Text(
              'POS Terminal #04',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const Spacer(),
            _buildTopBarIcon(Icons.settings_outlined),
            const SizedBox(width: 12),
            _buildTopBarIcon(Icons.help_outline_rounded),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBarIcon(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: const Color(0xFF4B5563), size: 20),
    );
  }

  Widget _buildHeaderIcon() {
    return Container(
      width: 80,
      height: 80,
      decoration: const BoxDecoration(
        color: Color(0xFFFFF7ED),
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Icon(
          Icons.lock_rounded,
          color: Color(0xFFFF9500),
          size: 36,
        ),
      ),
    );
  }

  Widget _buildPinIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final bool isFilled = index < _enteredPin.length;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled ? const Color(0xFFFF9500) : Colors.white,
            border: Border.all(
              color: isFilled ? const Color(0xFFFF9500) : const Color(0xFFD1D5DB),
              width: 2,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildKeypad() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildKeypadButton('1'),
            const SizedBox(width: 12),
            _buildKeypadButton('2'),
            const SizedBox(width: 12),
            _buildKeypadButton('3'),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildKeypadButton('4'),
            const SizedBox(width: 12),
            _buildKeypadButton('5'),
            const SizedBox(width: 12),
            _buildKeypadButton('6'),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildKeypadButton('7'),
            const SizedBox(width: 12),
            _buildKeypadButton('8'),
            const SizedBox(width: 12),
            _buildKeypadButton('9'),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 72), 
            const SizedBox(width: 12),
            _buildKeypadButton('0'),
            const SizedBox(width: 12),
            _buildKeypadButton('', isBackspace: true),
          ],
        ),
      ],
    );
  }

  Widget _buildKeypadButton(String digit, {bool isBackspace = false}) {
    return Material(
      color: const Color(0xFFF9FAFB),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => isBackspace ? _onBackspace() : _onDigitPress(digit),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: isBackspace
                ? const Icon(Icons.backspace_outlined, color: Color(0xFF4B5563), size: 22)
                : Text(
                    digit,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.verified_user_rounded, color: Color(0xFF9CA3AF), size: 14),
              const SizedBox(width: 8),
              Text(
                'secure_encryption'.tr,
                style: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '© 2024 POS System Cloud. ${'all_rights_reserved'.tr}',
            style: const TextStyle(
              color: Color(0xFFD1D5DB),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

