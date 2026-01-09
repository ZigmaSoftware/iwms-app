class MainCategory {
  final String id;
  final String name;

  MainCategory({required this.id, required this.name});

  factory MainCategory.fromJson(Map<String, dynamic> json) {
    return MainCategory(
      id: json['unique_id'] ?? '',
      name: json['main_categoryName'] ?? json['name'] ?? '',
    );
  }
}
