class FoodItem {
  final String id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final String category;
  final double rating;
  final int timeEstimate; // in minutes
  final String preparationArea;

  const FoodItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    this.category = "General",
    this.rating = 4.5,
    this.timeEstimate = 20,
    this.preparationArea = "Kitchen",
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'price': price,
    'imageUrl': imageUrl,
    'category': category,
    'rating': rating,
    'timeEstimate': timeEstimate,
    'preparationArea': preparationArea,
  };

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    // Check if it's from backend (has category as object) or local (has category as string)
    String categoryName = "General";
    if (json['category'] != null) {
      if (json['category'] is String) {
        categoryName = json['category'];
      } else if (json['category'] is Map) {
        categoryName = json['category']['name'] ?? "General";
      }
    }

    return FoodItem(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      imageUrl: json['image'] ?? json['imageUrl'] ?? '',
      category: categoryName,
      rating: (json['rating'] as num?)?.toDouble() ?? 4.5,
      timeEstimate: json['timeEstimate'] ?? 20,
      preparationArea: json['preparationArea'] ?? 'Kitchen',
    );
  }
}
