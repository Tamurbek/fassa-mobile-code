import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/services/api_service.dart';
import '../../../logic/pos_controller.dart';
import '../../widgets/virtual_keyboard.dart';
import 'staff_selection_page.dart';

class TerminalLoginPage extends StatefulWidget {
  const TerminalLoginPage({super.key});

  @override
  State<TerminalLoginPage> createState() => _TerminalLoginPageState();
}

class _TerminalLoginPageState extends State<TerminalLoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _showKeyboard = false;
  late TextEditingController _activeController;

  @override
  void initState() {
    super.initState();
    _activeController = _usernameController;
    _usernameFocus.addListener(() {
      if (_usernameFocus.hasFocus) setState(() => _activeController = _usernameController);
    });
    _passwordFocus.addListener(() {
      if (_passwordFocus.hasFocus) setState(() => _activeController = _passwordController);
    });
  }

  @override
  void dispose() {
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      Get.snackbar('Xato', 'Barcha maydonlarni shakllantiring', backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final response = await ApiService().loginTerminal(
        _usernameController.text.trim(),
        _passwordController.text,
      );

      // Save terminal info
      Get.find<POSController>().setCurrentTerminal(response['terminal']);
      
      Get.snackbar('Muvaffaqiyatli', '${response['terminal']['name']} terminaliga ulandi', backgroundColor: Colors.green, colorText: Colors.white);

      Get.offAll(() => const StaffSelectionPage());
    } catch (e) {
      Get.snackbar('Xatolik', 'Login yoki parol noto\'g\'ri', backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 450),
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const SizedBox(width: 48),
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF9500).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(Icons.monitor, color: Color(0xFFFF9500), size: 40),
                          ),
                          IconButton(
                            icon: Icon(_showKeyboard ? Icons.keyboard_hide_rounded : Icons.keyboard_rounded, color: Colors.grey),
                            onPressed: () => setState(() => _showKeyboard = !_showKeyboard),
                            tooltip: "Klaviatura",
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'POS Terminal',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Terminal login va paroli orqali kiring',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF6B7280)),
                      ),
                      const SizedBox(height: 32),
                      TextField(
                        controller: _usernameController,
                        focusNode: _usernameFocus,
                        showCursor: true,
                        readOnly: _showKeyboard,
                        onTap: () { if (_showKeyboard) _usernameFocus.requestFocus(); },
                        decoration: InputDecoration(
                          labelText: 'Terminal Logini',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        focusNode: _passwordFocus,
                        obscureText: _obscurePassword,
                        showCursor: true,
                        readOnly: _showKeyboard,
                        onTap: () { if (_showKeyboard) _passwordFocus.requestFocus(); },
                        decoration: InputDecoration(
                          labelText: 'Parol',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF9500),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: _isLoading 
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Tizimga kirish', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => Get.back(),
                        child: const Text('Oddiy login orqali kirish', style: TextStyle(color: Color(0xFF6B7280))),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_showKeyboard)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: VirtualKeyboard(
                controller: _activeController,
                onEnter: _handleLogin,
              ),
            ),
        ],
      ),
    );
  }
}
