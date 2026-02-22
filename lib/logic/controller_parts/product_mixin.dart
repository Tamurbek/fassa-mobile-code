import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'pos_controller_state.dart';

mixin ProductMixin on POSControllerState {
  Future<void> saveProduct(Map<String, dynamic> productData) async {
    try {
      if (productData['id'] != null) {
        await api.updateProduct(productData['id'], productData);
      } else {
        await api.createProduct(productData);
      }
      // This mixin will need access to fetchBackendData, 
      // which we'll manage in the main POSController
    } catch (e) {
      print("Error saving product: $e");
    }
  }

  Future<void> deleteProduct(String id) async {
    try {
      await api.deleteProduct(id);
    } catch (e) {
      print("Error deleting product: $e");
    }
  }

  Future<void> saveCategory(Map<String, dynamic> categoryData) async {
    try {
      if (categoryData['id'] != null) {
        await api.updateCategory(categoryData['id'], categoryData);
      } else {
        await api.createCategory(categoryData);
      }
    } catch (e) {
      print("Error saving category: $e");
    }
  }
}
