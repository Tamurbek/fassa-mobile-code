import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import '../../../data/services/api_service.dart';
import '../../../logic/pos_controller.dart';
import 'pin_code_screen.dart';
import '../main_navigation_screen.dart';

class StaffSelectionPage extends StatefulWidget {
  final String? cafeId;
  final bool isFromTerminal;
  
  const StaffSelectionPage({
    super.key, 
    this.cafeId,
    this.isFromTerminal = true,
  });

  @override
  State<StaffSelectionPage> createState() => _StaffSelectionPageState();
}

class _StaffSelectionPageState extends State<StaffSelectionPage> {
  List<dynamic> _staff = [];
  String _selectedRole = 'WAITER';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStaff();
  }

  Future<void> _fetchStaff() async {
    try {
      final List<dynamic> staff;
      if (widget.cafeId != null) {
        staff = await ApiService().getStaffPublic(widget.cafeId!);
      } else {
        staff = await ApiService().getTerminalStaff();
      }
      
      if (mounted) {
        setState(() {
          _staff = staff;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching staff: $e");
      Get.snackbar('Xatolik', 'Xodimlarni yuklab bo\'lmadi: $e', 
        backgroundColor: Colors.red, colorText: Colors.white);
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _selectStaff(dynamic staffMember) {
    String enteredPin = "";
    
    Get.dialog(
      StatefulBuilder(
        builder: (context, setDialogState) {
          void onDigitPress(String digit) async {
            if (enteredPin.length < 4) {
              setDialogState(() => enteredPin += digit);
              
              if (enteredPin.length == 4) {
                try {
                  final userId = staffMember['id'].toString();
                  // We need to pass device information to avoid backend session errors
                  final response = await ApiService().loginWithPin(
                    userId, 
                    enteredPin,
                    deviceId: Get.find<POSController>().currentTerminal.value?['id']?.toString() ?? "unknown_device",
                    deviceName: Get.find<POSController>().currentTerminal.value?['name'] ?? "POS Terminal"
                  );
                  
                  Get.find<POSController>().setCurrentUser(response['user']);
                  Get.find<POSController>().authenticatePin(true);
                  
                  Get.back(); // Close dialog
                  Get.offAllNamed('/main');
                  
                  Get.snackbar("Muvaffaqiyatli", "Xush kelibsiz, ${response['user']['name']}!", 
                    backgroundColor: Colors.green, colorText: Colors.white);
                } catch (e) {
                  String errorMsg = "PIN kod noto'g'ri";
                  if (e is DioException) {
                    final dynamic responseData = e.response?.data;
                    if (responseData != null && responseData is Map && responseData.containsKey('detail')) {
                      errorMsg = responseData['detail']?.toString() ?? errorMsg;
                    }
                  }
                  Get.snackbar("Xato", errorMsg, 
                    backgroundColor: Colors.red, colorText: Colors.white);
                  setDialogState(() => enteredPin = "");
                }
              }
            }
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            contentPadding: const EdgeInsets.all(24),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_outline, color: Colors.orange, size: 32),
                ),
                const SizedBox(height: 16),
                Text(
                  staffMember['name'],
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const Text(
                  'PIN kodni kiriting',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 24),
                // PIN Indicators
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    bool isFilled = index < enteredPin.length;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isFilled ? Colors.orange : Colors.transparent,
                        border: Border.all(color: isFilled ? Colors.orange : Colors.grey.shade300, width: 2),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 32),
                // Keypad
                Column(
                  children: [
                    for (var row in [['1', '2', '3'], ['4', '5', '6'], ['7', '8', '9']])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var digit in row)
                              _buildKeypadButton(digit, () => onDigitPress(digit)),
                          ],
                        ),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(width: 72),
                        const SizedBox(width: 12),
                        _buildKeypadButton('0', () => onDigitPress('0')),
                        const SizedBox(width: 12),
                        _buildKeypadButton('⌫', () {
                          if (enteredPin.isNotEmpty) {
                            setDialogState(() => enteredPin = enteredPin.substring(0, enteredPin.length - 1));
                          }
                        }, isDelete: true),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Get.back(),
                  child: const Text('Bekor qilish', style: TextStyle(color: Colors.grey)),
                ),
              ],
            ),
          );
        }
      ),
      barrierDismissible: false,
    );
  }

  Widget _buildKeypadButton(String label, VoidCallback onTap, {bool isDelete = false}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      width: 72,
      height: 72,
      child: Material(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: isDelete ? 20 : 24,
                fontWeight: FontWeight.bold,
                color: isDelete ? Colors.red : Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('Xodimni tanlang', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () {
              if (widget.isFromTerminal) {
                 ApiService().clearTerminalToken();
              }
              ApiService().setToken(null);
              
              final pos = Get.find<POSController>();
              pos.setDeviceRole(null);
              pos.setWaiterCafeId(null);
              pos.setCurrentTerminal(null);
              pos.logout(forced: false);
            },
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              _buildFilterBar(),
              Expanded(
                child: _buildStaffGrid(),
              ),
            ],
          ),
    );
  }

  Widget _buildFilterBar() {
    final roles = [
      {'id': 'WAITER', 'name': 'Ofitsiant', 'icon': Icons.flatware},
      {'id': 'CASHIER', 'name': 'Kassir', 'icon': Icons.point_of_sale},
      {'id': 'CAFE_ADMIN', 'name': 'Admin', 'icon': Icons.admin_panel_settings},
    ];

    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: roles.length,
        itemBuilder: (context, index) {
          final role = roles[index];
          final bool isSelected = _selectedRole == role['id'];
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ChoiceChip(
              label: Row(
                children: [
                   Icon(
                    role['icon'] as IconData, 
                    size: 18, 
                    color: isSelected ? Colors.white : Colors.grey
                  ),
                  const SizedBox(width: 8),
                  Text(role['name'] as String),
                ],
              ),
              selected: isSelected,
              onSelected: (bool selected) {
                if (selected) {
                  setState(() => _selectedRole = role['id'] as String);
                }
              },
              selectedColor: const Color(0xFFFF9500),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
              ),
              backgroundColor: Colors.grey.shade100,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStaffGrid() {
    final filteredStaff = _staff.where((s) => s['role'] == _selectedRole).toList();

    if (filteredStaff.isEmpty && !_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Ushbu bo\'limda xodimlar mavjud emas',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          childAspectRatio: 0.8,
          crossAxisSpacing: 24,
          mainAxisSpacing: 24,
        ),
        itemCount: filteredStaff.length,
        itemBuilder: (context, index) {
          final member = filteredStaff[index];
          return _buildStaffCard(member);
        },
      ),
    );
  }

  Widget _buildStaffCard(dynamic member) {
    final role = member['role'];
    Color roleColor;
    IconData roleIcon;

    switch (role) {
      case 'WAITER':
        roleColor = Colors.blue;
        roleIcon = Icons.flatware;
        break;
      case 'KITCHEN':
        roleColor = Colors.orange;
        roleIcon = Icons.soup_kitchen;
        break;
      case 'CAFE_ADMIN':
        roleColor = Colors.purple;
        roleIcon = Icons.admin_panel_settings;
        break;
      default:
        roleColor = Colors.grey;
        roleIcon = Icons.person;
    }

    return GestureDetector(
      onTap: () => _selectStaff(member),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: roleColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(roleIcon, color: roleColor, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              member['name'],
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
            ),
            const SizedBox(height: 4),
            Text(
              role.toString(),
              style: TextStyle(fontSize: 13, color: roleColor, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
