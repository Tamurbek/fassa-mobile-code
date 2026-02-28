import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/models/food_item.dart';
import '../../data/models/preparation_area_model.dart';
import 'pos_controller_state.dart';

mixin ProductMixin on POSControllerState {
  Future<void> addProduct(FoodItem item) async {
    try {
      final json = item.toJson();
      json['cafe_id'] = cafeId;
      json['image'] = item.imageUrl;
      final cat = categoriesObjects.firstWhereOrNull((c) => c['name'] == item.category);
      if (cat != null) json['category_id'] = cat['id'];

      final newItem = await api.createProduct(json);
      products.add(FoodItem.fromJson(newItem));
      saveProducts();
    } catch (e) { print("Error adding product: $e"); }
  }

  Future<void> updateProduct(FoodItem item) async {
    try {
      final json = item.toJson();
      json.remove('id');
      json['cafe_id'] = cafeId;
      json['image'] = item.imageUrl;
      final cat = categoriesObjects.firstWhereOrNull((c) => c['name'] == item.category);
      if (cat != null) json['category_id'] = cat['id'];

      final updatedItem = await api.updateProduct(item.id, json);
      int index = products.indexWhere((p) => p.id == item.id);
      if (index != -1) {
        products[index] = FoodItem.fromJson(updatedItem);
        saveProducts();
      }
    } catch (e) { print("Error updating product: $e"); }
  }

  Future<void> deleteProduct(String id) async {
    try {
      await api.deleteProduct(id);
      products.removeWhere((p) => p.id == id);
      saveProducts();
    } catch (e) { print("Error deleting product: $e"); }
  }

  Future<void> mergeProducts(FoodItem source, FoodItem target) async {
    if (source.id == target.id) return;
    if (source.hasVariants) {
      Get.snackbar("Xato", "Variantlari bor mahsulotni boshqa mahsulotga birlashtirib bo'lmaydi");
      return;
    }

    try {
      final newVariants = List<FoodVariant>.from(target.variants);
      newVariants.add(FoodVariant(id: '', name: source.name, price: source.price));

      final updatedTarget = FoodItem(
        id: target.id,
        name: target.name,
        description: target.description,
        price: target.price,
        imageUrl: target.imageUrl,
        category: target.category,
        preparationArea: target.preparationArea,
        preparationAreaId: target.preparationAreaId,
        hasVariants: true,
        variants: newVariants,
      );

      await updateProduct(updatedTarget);
      await deleteProduct(source.id);
      saveProducts();
      Get.snackbar("Muvaffaqiyatli", "${source.name} ${target.name} variantiga aylantirildi");
    } catch (e) {
      print("Error merging products: $e");
    }
  }

  Future<void> extractVariant(FoodItem parent, int variantIndex) async {
    final variant = parent.variants[variantIndex];
    try {
      final json = parent.toJson();
      json.remove('id');
      json['name'] = variant.name;
      json['price'] = variant.price;
      json['has_variants'] = false;
      json['variants'] = [];
      json['cafe_id'] = cafeId;
      json['image'] = parent.imageUrl;
      final cat = categoriesObjects.firstWhereOrNull((c) => c['name'] == parent.category);
      if (cat != null) json['category_id'] = cat['id'];

      final newItem = await api.createProduct(json);
      products.add(FoodItem.fromJson(newItem));

      final newVariants = List<FoodVariant>.from(parent.variants)..removeAt(variantIndex);
      final updatedParent = FoodItem(
        id: parent.id,
        name: parent.name,
        description: parent.description,
        price: parent.price,
        imageUrl: parent.imageUrl,
        category: parent.category,
        preparationArea: parent.preparationArea,
        preparationAreaId: parent.preparationAreaId,
        hasVariants: newVariants.isNotEmpty,
        variants: newVariants,
      );
      await updateProduct(updatedParent);
      saveProducts();
      Get.snackbar("Muvaffaqiyatli", "${variant.name} alohida mahsulotga aylantirildi");
    } catch (e) {
      print("Error extracting variant: $e");
    }
  }

  Future<void> moveVariantToProduct(FoodItem sourceParent, int variantIndex, FoodItem targetProduct) async {
    if (sourceParent.id == targetProduct.id) return;
    
    final variant = sourceParent.variants[variantIndex];
    try {
      // 1. Add variant to target
      final targetVariants = List<FoodVariant>.from(targetProduct.variants)..add(variant);
      final updatedTarget = FoodItem(
        id: targetProduct.id,
        name: targetProduct.name,
        description: targetProduct.description,
        price: targetProduct.price,
        imageUrl: targetProduct.imageUrl,
        category: targetProduct.category,
        preparationArea: targetProduct.preparationArea,
        preparationAreaId: targetProduct.preparationAreaId,
        hasVariants: true,
        variants: targetVariants,
        isAvailable: targetProduct.isAvailable,
      );
      await updateProduct(updatedTarget);

      // 2. Remove variant from source
      final sourceVariants = List<FoodVariant>.from(sourceParent.variants)..removeAt(variantIndex);
      final updatedSource = FoodItem(
        id: sourceParent.id,
        name: sourceParent.name,
        description: sourceParent.description,
        price: sourceParent.price,
        imageUrl: sourceParent.imageUrl,
        category: sourceParent.category,
        preparationArea: sourceParent.preparationArea,
        preparationAreaId: sourceParent.preparationAreaId,
        hasVariants: sourceVariants.isNotEmpty,
        variants: sourceVariants,
        isAvailable: sourceParent.isAvailable,
      );
      await updateProduct(updatedSource);
      
      saveProducts();
      Get.snackbar("Muvaffaqiyatli", "${variant.name} ${targetProduct.name} mahsulotiga o'tkazildi");
    } catch (e) {
      print("Error moving variant: $e");
    }
  }

  Future<void> addVariantToProduct(FoodItem parent, String name, double price) async {
    try {
      final newVariants = List<FoodVariant>.from(parent.variants)..add(FoodVariant(id: '', name: name, price: price));
      final updatedParent = FoodItem(
        id: parent.id,
        name: parent.name,
        description: parent.description,
        price: parent.price,
        imageUrl: parent.imageUrl,
        category: parent.category,
        preparationArea: parent.preparationArea,
        preparationAreaId: parent.preparationAreaId,
        hasVariants: true,
        variants: newVariants,
      );
      await updateProduct(updatedParent);
      saveProducts();
    } catch (e) {
      print("Error adding variant: $e");
    }
  }

  Future<void> toggleProductAvailability(FoodItem item) async {
    final updatedItem = FoodItem(
      id: item.id,
      name: item.name,
      description: item.description,
      price: item.price,
      imageUrl: item.imageUrl,
      category: item.category,
      preparationArea: item.preparationArea,
      preparationAreaId: item.preparationAreaId,
      hasVariants: item.hasVariants,
      variants: item.variants,
      isAvailable: !item.isAvailable,
    );
    await updateProduct(updatedItem);
  }

  Future<void> toggleVariantAvailability(FoodItem parent, int variantIndex) async {
    final variants = List<FoodVariant>.from(parent.variants);
    final variant = variants[variantIndex];
    variants[variantIndex] = FoodVariant(
      id: variant.id,
      name: variant.name,
      price: variant.price,
      isAvailable: !variant.isAvailable,
    );
    
    final updatedParent = FoodItem(
      id: parent.id,
      name: parent.name,
      description: parent.description,
      price: parent.price,
      imageUrl: parent.imageUrl,
      category: parent.category,
      preparationArea: parent.preparationArea,
      preparationAreaId: parent.preparationAreaId,
      hasVariants: parent.hasVariants,
      variants: variants,
      isAvailable: parent.isAvailable,
    );
    await updateProduct(updatedParent);
  }

  Future<void> reorderProducts(int oldIndex, int newIndex) async {
    final item = products.removeAt(oldIndex);
    products.insert(newIndex, item);
    products.refresh();
    
    // Save to local storage for instant feedback
    saveProducts();

    try {
      final reorderData = products.asMap().entries.map((entry) => {
        "id": entry.value.id,
        "sort_order": entry.key
      }).toList();
      await api.reorderProducts(reorderData);
    } catch (e) {
      print("Error reordering products: $e");
    }
  }

  Future<void> addCategory(String category) async {
    if (categories.contains(category)) return;
    try {
      final newCat = await api.createCategory({
        "name": category,
        "cafe_id": cafeId,
        "sort_order": categories.length
      });
      categoriesObjects.add(newCat);
      categories.add(newCat['name']);
      storage.write('categories_objects', categoriesObjects.toList());
      saveCategories();
    } catch (e) { print("Error adding category: $e"); }
  }
  
  Future<void> updateCategory(String oldName, String newName) async {
    final catObj = categoriesObjects.firstWhereOrNull((c) => c['name'] == oldName);
    if (catObj == null) return;
    try {
      final updatedCat = await api.updateCategory(catObj['id'], {"name": newName});
      int objIndex = categoriesObjects.indexWhere((c) => c['id'] == catObj['id']);
      if (objIndex != -1) categoriesObjects[objIndex] = updatedCat;
      int nameIndex = categories.indexOf(oldName);
      if (nameIndex != -1) categories[nameIndex] = newName;
      storage.write('categories_objects', categoriesObjects.toList());
      saveCategories();
      fetchBackendData(); // Refresh products with new category name
    } catch (e) { print("Error updating category: $e"); }
  }

  Future<void> deleteCategory(String category) async {
    if (category == "All") return;
    final catObj = categoriesObjects.firstWhereOrNull((c) => c['name'] == category);
    if (catObj == null) return;
    try {
      await api.deleteCategory(catObj['id']);
      categoriesObjects.removeWhere((c) => c['id'] == catObj['id']);
      categories.remove(category);
      storage.write('categories_objects', categoriesObjects.toList());
      saveCategories();
    } catch (e) { print("Error deleting category: $e"); }
  }

  Future<void> addPreparationArea(PreparationAreaModel area) async {
    try {
      final json = area.toJson();
      json['cafe_id'] = cafeId;
      final newArea = await api.createPreparationArea(json);
      preparationAreas.add(PreparationAreaModel.fromJson(newArea));
      savePreparationAreas();
    } catch (e) { print("Error adding preparation area: $e"); }
  }

  Future<void> updatePreparationArea(PreparationAreaModel area) async {
    try {
      final json = area.toJson();
      json.remove('id');
      final updatedArea = await api.updatePreparationArea(area.id, json);
      int index = preparationAreas.indexWhere((a) => a.id == area.id);
      if (index != -1) {
        preparationAreas[index] = PreparationAreaModel.fromJson(updatedArea);
        savePreparationAreas();
      }
    } catch (e) { print("Error updating preparation area: $e"); }
  }

  Future<void> deletePreparationArea(String id) async {
    try {
      await api.deletePreparationArea(id);
      preparationAreas.removeWhere((a) => a.id == id);
      savePreparationAreas();
    } catch (e) { print("Error deleting preparation area: $e"); }
  }
}
