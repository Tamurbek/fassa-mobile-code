import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../theme/app_colors.dart';
import '../../theme/responsive.dart';
import '../../logic/pos_controller.dart';
import 'home_screen.dart';

class TableSelectionScreen extends StatefulWidget {
  const TableSelectionScreen({super.key});

  @override
  State<TableSelectionScreen> createState() => _TableSelectionScreenState();
}

class _TableSelectionScreenState extends State<TableSelectionScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _locations = ["Zal", "Hovli", "Navis"];
  
  final Map<String, List<String>> _tablesByLocation = {
    "Zal": List.generate(12, (index) => (index + 1).toString().padLeft(2, '0')),
    "Hovli": List.generate(8, (index) => (index + 21).toString().padLeft(2, '0')),
    "Navis": List.generate(6, (index) => (index + 41).toString().padLeft(2, '0')),
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _locations.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final POSController pos = Get.find<POSController>();
    final bool isMobile = Responsive.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text("select_table".tr),
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: GestureDetector(
            onTap: () => Get.back(),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFF9500),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF9500).withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
            ),
          ),
        ),
        actions: [
          if (pos.isAdmin)
            Obx(() => IconButton(
              icon: Icon(pos.isEditMode.value ? Icons.check_circle : Icons.edit_location_alt_rounded),
              onPressed: () => pos.toggleEditMode(),
              color: pos.isEditMode.value ? Colors.green : null,
              tooltip: pos.isEditMode.value ? "Save Layout" : "Edit Layout",
            )),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: _locations.map((loc) => Tab(text: loc)).toList(),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 1200),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                     _StatusIndicator(color: Colors.green, label: "available".tr),
                     const SizedBox(width: 20),
                     _StatusIndicator(color: Colors.red, label: "occupied".tr),
                     const SizedBox(width: 20),
                     _StatusIndicator(color: Colors.orange, label: "Tahrirlanmoqda"),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: _locations.map((location) {
                    return _FloorPlanView(
                      location: location,
                      tables: _tablesByLocation[location]!,
                      pos: pos,
                    );
                  }).toList(),
                ),
              ),
              Obx(() => pos.isEditMode.value 
                ? Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.amber.withOpacity(0.1),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: Colors.orange),
                        const SizedBox(width: 8),
                        Text("dragging_tip".tr, style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )
                : const SizedBox.shrink()
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FloorPlanView extends StatelessWidget {
  final String location;
  final List<String> tables;
  final POSController pos;

  const _FloorPlanView({
    required this.location,
    required this.tables,
    required this.pos,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double floorWidth = constraints.maxWidth;
        final double floorHeight = constraints.maxHeight;

        return Obx(() => Stack(
          children: tables.map((tableNum) {
            final String tableId = "$location-$tableNum";
            final position = pos.tablePositions[tableId] ?? _getDefaultPosition(tableNum, floorWidth, floorHeight);
            
            final bool isOccupied = pos.allOrders.any((o) => 
              o['table'] == tableId && 
              !["Completed", "Cancelled"].contains(o['status'])
            );

            final String? lockedByUser = pos.lockedTables[tableId];
            final bool isLockedByMe = lockedByUser != null && lockedByUser == (pos.currentUser.value?['name'] ?? "User");
            final bool isLockedByOther = lockedByUser != null && !isLockedByMe;

            return Positioned(
              left: position['x']!,
              top: position['y']!,
              child: GestureDetector(
                onPanUpdate: pos.isEditMode.value ? (details) {
                  double newX = position['x']! + details.delta.dx;
                  double newY = position['y']! + details.delta.dy;
                  
                  // Boundaries
                  newX = newX.clamp(0.0, floorWidth - 80);
                  newY = newY.clamp(0.0, floorHeight - 80);
                  
                  pos.updateTablePosition(tableId, newX, newY);
                } : null,
                onPanEnd: pos.isEditMode.value ? (_) {
                  pos.syncTablePositionWithBackend(tableId);
                } : null,
                onTap: pos.isEditMode.value ? null : (isOccupied || isLockedByOther ? () {
                  if (isLockedByOther) {
                    Get.snackbar("Xatolik", "Ushbu stolni hozirda $lockedByUser tahrirlamoqda", 
                      backgroundColor: Colors.orange, colorText: Colors.white);
                  }
                } : () {
                  pos.setTable(tableId);
                  Get.to(() => const HomeScreen());
                }),
                child: _TableWidget(
                  tableNum: tableNum,
                  isOccupied: isOccupied,
                  isEditMode: pos.isEditMode.value,
                  lockedByUser: lockedByUser,
                  isLockedByOther: isLockedByOther,
                ),
              ),
            );
          }).toList(),
        ));
      },
    );
  }

  Map<String, double> _getDefaultPosition(String tableNum, double width, double height) {
    int index = int.parse(tableNum) % 20;
    int cols = (width / 100).floor().clamp(1, 10);
    double x = (index % cols) * 100.0 + 20;
    double y = (index ~/ cols) * 100.0 + 20;
    return {"x": x, "y": y};
  }
}

class _TableWidget extends StatelessWidget {
  final String tableNum;
  final bool isOccupied;
  final bool isEditMode;
  final String? lockedByUser;
  final bool isLockedByOther;

  const _TableWidget({
    required this.tableNum,
    required this.isOccupied,
    required this.isEditMode,
    this.lockedByUser,
    this.isLockedByOther = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: isLockedByOther 
            ? Colors.orange.withOpacity(0.1) 
            : (isOccupied ? Colors.red.withOpacity(0.1) : (isEditMode ? Colors.blue.withOpacity(0.05) : AppColors.white)),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isEditMode 
              ? Colors.blue.withOpacity(0.5) 
              : (isLockedByOther ? Colors.orange.withOpacity(0.5) : (isOccupied ? Colors.red.withOpacity(0.3) : Colors.grey.shade200)),
          width: (isEditMode || isLockedByOther) ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isEditMode ? Icons.drag_indicator : (isLockedByOther ? Icons.lock_clock_rounded : Icons.table_restaurant), 
            color: isEditMode 
                ? Colors.blue 
                : (isLockedByOther ? Colors.orange : (isOccupied ? Colors.red : AppColors.primary)),
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            tableNum,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: isLockedByOther ? Colors.orange : (isOccupied ? Colors.red : AppColors.textPrimary),
            ),
          ),
          if (isLockedByOther)
            Text(
              lockedByUser ?? "User",
              style: const TextStyle(fontSize: 8, color: Colors.orange, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          else if (isOccupied && !isEditMode)
            Text(
              "occupied".tr,
              style: const TextStyle(fontSize: 8, color: Colors.red),
            ),
        ],
      ),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  final Color color;
  final String label;

  const _StatusIndicator({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }
}


