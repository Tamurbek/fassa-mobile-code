import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/services/api_service.dart';
import '../../../logic/pos_controller.dart';
import 'pin_code_screen.dart';

class StaffSelectionPage extends StatefulWidget {
  const StaffSelectionPage({super.key});

  @override
  State<StaffSelectionPage> createState() => _StaffSelectionPageState();
}

class _StaffSelectionPageState extends State<StaffSelectionPage> {
  List<dynamic> _staff = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStaff();
  }

  Future<void> _fetchStaff() async {
    try {
      final staff = await ApiService().getTerminalStaff();
      setState(() {
        _staff = staff;
        _isLoading = false;
      });
    } catch (e) {
      Get.snackbar('Xatolik', 'Xodimlarni yuklab bo\'lmadi');
      setState(() => _isLoading = false);
    }
  }

  void _selectStaff(dynamic staffMember) {
    // Show PIN screen for the selected staff member
    Get.to(() => PinCodeScreen(
      selectedUser: staffMember,
      isFromTerminal: true,
    ));
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
              ApiService().setToken(null);
              Get.offAllNamed('/login'); // Assuming route exists
            },
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.all(24.0),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200,
                childAspectRatio: 0.8,
                crossAxisSpacing: 24,
                mainAxisSpacing: 24,
              ),
              itemCount: _staff.length,
              itemBuilder: (context, index) {
                final member = _staff[index];
                return _buildStaffCard(member);
              },
            ),
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
              role,
              style: TextStyle(fontSize: 13, color: roleColor, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
