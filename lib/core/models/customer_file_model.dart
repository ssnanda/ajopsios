/// GET /ops/files row shape (ops_get_file_row in class-ajcore-rest-api.php).
class CustomerFile {
  final int id;
  final String title;
  final String category;
  final String description;
  final String fileUrl;
  final String filename;
  final List<String> tags;
  final String status; // active | archived
  final String createdAt;

  const CustomerFile({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.fileUrl,
    required this.filename,
    required this.tags,
    required this.status,
    required this.createdAt,
  });

  factory CustomerFile.fromJson(Map<String, dynamic> json) {
    return CustomerFile(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      title: json['title'] as String? ?? '',
      category: json['category'] as String? ?? '',
      description: json['description'] as String? ?? '',
      fileUrl: json['file_url'] as String? ?? '',
      filename: json['filename'] as String? ?? '',
      tags: (json['tags'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      status: json['status'] as String? ?? 'active',
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  String get displayTitle => title.isNotEmpty ? title : filename;
}
