class SubCategory {
  final String id;
  final String name;
  final String mainCategoryId;

  SubCategory({
    required this.id,
    required this.name,
    required this.mainCategoryId,
  });

  factory SubCategory.fromJson(Map<String, dynamic> json) {
    return SubCategory(
      id: json['unique_id'] ?? '',
      name: json['sub_categoryName'] ?? json['name'] ?? '',
      mainCategoryId: json['main_category_id'] ?? '',
    );
  }
}
