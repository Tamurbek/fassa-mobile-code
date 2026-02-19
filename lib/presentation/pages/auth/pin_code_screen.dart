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
    String title = widget.isSettingNewPin 
      ? (_isConfirming ? "Confirm PIN" : "Set New PIN") 
      : "Enter PIN";
    
    String subtitle = widget.isSettingNewPin
      ? (_isConfirming ? "Enter the same 4 digits again" : "Create a 4-digit security PIN")
      : "Please enter your security PIN to continue";

    final bool isMobile = Responsive.isMobile(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: Column(
              children: [
                SizedBox(height: isMobile ? 60 : 80),
                Icon(Icons.lock_person_rounded, size: isMobile ? 80 : 100, color: AppColors.primary),
                const SizedBox(height: 24),
                Text(
                  title,
                  style: TextStyle(fontSize: isMobile ? 28 : 34, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: isMobile ? 16 : 18, color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 50),
                
                // PIN Dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    bool isSelected = index < _enteredPin.length;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      width: isMobile ? 20 : 24,
                      height: isMobile ? 20 : 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? AppColors.primary : Colors.grey.shade200,
                        border: Border.all(
                          color: isSelected ? AppColors.primary : Colors.grey.shade300,
                          width: 2,
                        ),
                      ),
                    );
                  }),
                ),
                
                const Spacer(),
                
                // Numeric Keypad
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: isMobile ? 20 : 40),
                  child: Column(
                    children: [
                      _buildKeypadRow(["1", "2", "3"]),
                      const SizedBox(height: 20),
                      _buildKeypadRow(["4", "5", "6"]),
                      const SizedBox(height: 20),
                      _buildKeypadRow(["7", "8", "9"]),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const SizedBox(width: 70), 
                          _buildKeyButton("0"),
                          _buildIconButton(Icons.backspace_rounded, _onBackspace),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: isMobile ? 40 : 60),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeypadRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: digits.map((d) => _buildKeyButton(d)).toList(),
    );
  }

  Widget _buildKeyButton(String digit) {
    return InkWell(
      onTap: () => _onDigitPress(digit),
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey.shade50,
        ),
        child: Center(
          child: Text(
            digit,
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey.shade50,
        ),
        child: Center(
          child: Icon(icon, size: 30, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

