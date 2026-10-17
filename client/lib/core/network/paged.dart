/// Generic shape of the backend `*Page` schemas (`items`, `page`, `size`, ...).
class Paged<T> {
  const Paged({
    required this.items,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
  });

  factory Paged.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromItem,
  ) =>
      Paged(
        items: (json['items'] as List<dynamic>)
            .map((e) => fromItem(e as Map<String, dynamic>))
            .toList(),
        page: (json['page'] as num).toInt(),
        size: (json['size'] as num).toInt(),
        totalElements: (json['totalElements'] as num).toInt(),
        totalPages: (json['totalPages'] as num).toInt(),
      );

  final List<T> items;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;

  bool get isEmpty => items.isEmpty;
  bool get hasNext => page + 1 < totalPages;
}
