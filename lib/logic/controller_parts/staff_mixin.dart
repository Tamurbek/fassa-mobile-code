import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'pos_controller_state.dart';
import '../../data/models/food_item.dart';

mixin StaffMixin on POSControllerState {
  void callWaiter(Map<String, dynamic> waiter) {
    if (!isAdmin && !isCashier) return;
    socket.emitCallWaiter({
      'waiter_id': waiter['id'],
      'waiter_name': waiter['name'],
      'sender_name': currentUser.value?['name'] ?? "Admin",
      'message': "Tezda kassa yoniga keling",
    });
    Get.snackbar("Signal yuborildi", "${waiter['name']}ga signal yuborildi", backgroundColor: Colors.blue, colorText: Colors.white);
  }

  Future<void> addUser(Map<String, dynamic> userData) async {
    final newUser = await api.createUser(userData);
    users.add(newUser);
    storage.write('all_users', users.toList());
  }

  Future<void> updateUserProfile(String id, Map<String, dynamic> userData) async {
    final updatedUser = await api.updateUser(id, userData);
    int index = users.indexWhere((u) => u['id'] == id);
    if (index != -1) {
      users[index] = updatedUser;
      users.refresh();
      storage.write('all_users', users.toList());
    }
  }

  Future<void> deleteUser(String id) async {
    await api.deleteUser(id);
    users.removeWhere((u) => u['id'] == id);
    storage.write('all_users', users.toList());
  }
}
