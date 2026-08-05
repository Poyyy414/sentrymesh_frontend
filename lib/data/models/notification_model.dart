class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.read,
    required this.createdAt,
  });

  final String id;
  final String type;
  final String title;
  final String message;
  final bool read;
  final DateTime createdAt;

  factory NotificationModel.fromJson(Map<String, Object?> json) {
    return NotificationModel(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      read: json['read'] == true,
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
