import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'pos_controller_state.dart';

mixin TableMixin on POSControllerState {
  void updateTablePosition(String tableId, double x, double y) {
    tablePositions[tableId] = {"x": x, "y": y};
    tablePositions.refresh();
  }

  Future<void> syncTablePositionWithBackend(String tableId) async {
    final String? backendId = tableBackendIds[tableId];
    if (backendId == null) return;

    final pos = tablePositions[tableId];
    if (pos == null) return;

    try {
      await api.updateTable(backendId, {
        "x": pos['x'],
        "y": pos['y'],
      });
      storage.write('table_positions', Map.from(tablePositions));
    } catch (e) {
      print("Error syncing table position: $e");
    }
  }

  Future<void> updateAreaDimensions(String areaName, double width, double height) async {
    final String? areaId = tableAreaBackendIds[areaName];
    if (areaId == null) return;

    try {
      await api.updateTableArea(areaId, {
        "name": areaName,
        "width_m": width,
        "height_m": height,
      });
      tableAreaDetails[areaName] = {"width_m": width, "height_m": height};
      tableAreaDetails.refresh();
    } catch (e) {
      print("Error updating area dimensions: $e");
    }
  }

  // Reservations
  Future<void> createReservation({
    required String tableId,
    required String customerName,
    required String? phone,
    required DateTime startTime,
    required int guests,
    String? note,
  }) async {
    final String? backendTableId = tableBackendIds[tableId];
    if (backendTableId == null) throw "Table ID not found";

    try {
      await api.createReservation({
        "table_id": backendTableId,
        "customer_name": customerName,
        "customer_phone": phone,
        "guests_count": guests,
        "start_time": startTime.toIso8601String(),
        "note": note,
        "cafe_id": cafeId,
      });
      // Refresh reservations
      final res = await api.getReservations();
      reservations.assignAll(List<Map<String, dynamic>>.from(res));
    } catch (e) {
      print("Error creating reservation: $e");
      rethrow;
    }
  }

  Map<String, dynamic>? getActiveReservationForTable(String tableId) {
    final String? bTableId = tableBackendIds[tableId];
    if (bTableId == null) return null;

    final now = DateTime.now();
    for (var r in reservations) {
      if (r['table_id'] == bTableId && r['status'] == 'CONFIRMED' || r['status'] == 'PENDING') {
        final start = DateTime.parse(r['start_time'].toString());
        // If reservation is within next 2 hours or currently active
        // Let's say we mark as reserved if it's within 1 hour of the current time
        if (start.isAfter(now.subtract(const Duration(minutes: 30))) && 
            start.isBefore(now.add(const Duration(hours: 3)))) {
          return r;
        }
      }
    }
    return null;
  }
}
