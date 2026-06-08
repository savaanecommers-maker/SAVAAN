import 'api_client.dart';

class NotificationItem {
  final String id;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic>? data;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    required this.createdAt,
    this.data,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) => NotificationItem(
    id:        json['_id']?.toString() ?? json['id']?.toString() ?? '',
    title:     json['title'] as String? ?? '',
    body:      json['body']  as String? ?? '',
    type:      json['type']  as String? ?? 'system',
    isRead:    json['is_read'] as bool? ?? false,
    createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    data:      json['data'] as Map<String, dynamic>?,
  );
}

class NotificationService {
  Future<List<NotificationItem>> getNotifications() async {
    final res = await ApiClient.get('/api/notifications');
    if (!res.isSuccess) return [];
    try {
      final list = res.data!['_list'] as List? ?? [];
      return list.map((e) => NotificationItem.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> markAsRead(String notificationId) async {
    await ApiClient.put('/api/notifications/$notificationId/read', {});
  }

  Future<int> getUnreadCount() async {
    final items = await getNotifications();
    return items.where((n) => !n.isRead).length;
  }
}
