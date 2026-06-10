import 'package:flutter/material.dart';
import '../data/api_client.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // uses ApiClient directly

  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  bool _showUnreadOnly = false;

  static const Color _ink     = Color(0xFF0F172A);
  static const Color _teal    = Color(0xFF0D9488);
  static const Color _slate   = Color(0xFF64748B);
  static const Color _border  = Color(0xFFE2E8F0);
  static const Color _surface = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final loggedIn = await ApiClient.isLoggedIn;
      if (!mounted) return;
      if (!loggedIn) { setState(() => _isLoading = false); return; }
      final res = await ApiClient.get('/api/notifications');
      if (mounted) {
        setState(() {
          if (res.isSuccess) {
            final raw = res.data!;
            final list = raw['_list'] as List? ?? raw['notifications'] as List? ?? [];
            _notifications = List<Map<String, dynamic>>.from(list);
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Notifications error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead(String id) async {
    setState(() {
      final i = _notifications.indexWhere((n) => (n['_id'] ?? n['id'])?.toString() == id);
      if (i != -1) _notifications[i] = {..._notifications[i], 'is_read': true};
    });
    await ApiClient.put('/api/notifications/$id/read', {});
  }

  Future<void> _markAllRead() async {
    setState(() {
      _notifications = _notifications.map((n) => {...n, 'is_read': true}).toList();
    });
    // Single bulk call instead of N sequential calls
    ApiClient.put('/api/notifications/mark-all-read', {});
  }

  Future<void> _deleteNotification(String id) async {
    setState(() {
      _notifications.removeWhere((n) => (n['_id'] ?? n['id'])?.toString() == id);
    });
    await ApiClient.delete('/api/notifications/$id');
  }

  int get _unreadCount =>
      _notifications.where((n) => n['is_read'] != true).length;

  List<Map<String, dynamic>> get _filtered =>
      _showUnreadOnly
          ? _notifications.where((n) => n['is_read'] != true).toList()
          : _notifications;

  // Group into Today / Yesterday / Earlier
  Map<String, List<Map<String, dynamic>>> get _grouped {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final yestStart = todayStart.subtract(const Duration(days: 1));

    final groups = <String, List<Map<String, dynamic>>>{
      'Today': [],
      'Yesterday': [],
      'Earlier': [],
    };

    for (final n in _filtered) {
      final dt = n['created_at'] != null
          ? DateTime.tryParse(n['created_at'].toString())
          : null;
      if (dt == null) {
        groups['Earlier']!.add(n);
      } else if (dt.isAfter(todayStart)) {
        groups['Today']!.add(n);
      } else if (dt.isAfter(yestStart)) {
        groups['Yesterday']!.add(n);
      } else {
        groups['Earlier']!.add(n);
      }
    }

    // Remove empty groups
    groups.removeWhere((_, v) => v.isEmpty);
    return groups;
  }

  // Notification type → icon + color
  Map<String, dynamic> _typeInfo(String? type) {
    switch (type?.toLowerCase()) {
      case 'order':
        return {'icon': Icons.receipt_long_outlined,   'color': const Color(0xFF6366F1)};
      case 'promo':
        return {'icon': Icons.local_offer_outlined,    'color': const Color(0xFFF59E0B)};
      case 'system':
        return {'icon': Icons.info_outline_rounded,    'color': _slate};
      default:
        return {'icon': Icons.notifications_outlined,  'color': _teal};
    }
  }

  String _timeAgo(String? isoDate) {
    if (isoDate == null) return '';
    final dt = DateTime.tryParse(isoDate);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    final months = ['Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${dt.day} ${months[dt.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          _buildTopBar(),
          _buildFilterTabs(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _teal))
                : _filtered.isEmpty
                ? _buildEmpty()
                : RefreshIndicator(
              color: _teal,
              onRefresh: _loadNotifications,
              child: _buildList(),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
            ),
            child: const Icon(Icons.arrow_back, size: 20, color: _ink),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Notifications',
                style: TextStyle(fontSize: 20,
                    fontWeight: FontWeight.bold, color: _ink)),
            if (_unreadCount > 0)
              Text('$_unreadCount unread',
                  style: TextStyle(fontSize: 12, color: _teal,
                      fontWeight: FontWeight.w500)),
          ]),
        ),
        if (_unreadCount > 0)
          GestureDetector(
            onTap: _markAllRead,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: _teal.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _teal.withValues(alpha: 0.2)),
              ),
              child: const Text('Mark all read',
                  style: TextStyle(fontSize: 12, color: _teal,
                      fontWeight: FontWeight.w600)),
            ),
          ),
      ]),
    );
  }

  Widget _buildFilterTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(children: [
        _tab('All', !_showUnreadOnly),
        const SizedBox(width: 8),
        _tab('Unread${_unreadCount > 0 ? ' ($_unreadCount)' : ''}',
            _showUnreadOnly),
      ]),
    );
  }

  Widget _tab(String label, bool active) {
    return GestureDetector(
      onTap: () => setState(() =>
      _showUnreadOnly = label.startsWith('Unread')),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: active ? _teal : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? _teal : _border),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 13,
              color: active ? Colors.white : _slate,
              fontWeight: active ? FontWeight.w600 : FontWeight.normal,
            )),
      ),
    );
  }

  Widget _buildList() {
    final groups = _grouped;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: groups.entries.expand((entry) {
        return [
          // Group header
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Text(entry.key,
                style: TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _slate)),
          ),
          // Notifications in group
          ...entry.value.map((n) => _buildNotificationCard(n)),
        ];
      }).toList(),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> n) {
    final id = (n['_id'] ?? n['id'])?.toString() ?? '';
    final isRead = n['is_read'] == true;
    final typeInfo = _typeInfo(n['type']?.toString());
    final color = typeInfo['color'] as Color;
    final icon = typeInfo['icon'] as IconData;

    return Dismissible(
      key: Key(id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 22),
      ),
      onDismissed: (_) => _deleteNotification(id),
      child: GestureDetector(
        onTap: isRead ? null : () => _markAsRead(id),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isRead ? Colors.white : _teal.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isRead ? _border : _teal.withValues(alpha: 0.2),
            ),
            boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.025),
              blurRadius: 6, offset: const Offset(0, 2),
            )],
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Icon container
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(n['title']?.toString() ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                          color: _ink,
                        )),
                  ),
                  if (!isRead)
                    Container(
                      width: 8, height: 8,
                      margin: const EdgeInsets.only(left: 8, top: 3),
                      decoration: const BoxDecoration(
                          color: _teal, shape: BoxShape.circle),
                    ),
                ]),
                const SizedBox(height: 4),
                Text(n['body']?.toString() ?? '',
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13, color: _slate, height: 1.4)),
                const SizedBox(height: 6),
                Row(children: [
                  Icon(Icons.access_time_rounded,
                      size: 11, color: _slate.withValues(alpha: 0.5)),
                  const SizedBox(width: 4),
                  Text(_timeAgo(n['created_at']?.toString()),
                      style: TextStyle(fontSize: 11,
                          color: _slate.withValues(alpha: 0.5))),
                  const SizedBox(width: 8),
                  if (n['type'] != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _capitalize(n['type']?.toString() ?? ''),
                        style: TextStyle(fontSize: 10, color: color,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.notifications_none_rounded, size: 64,
            color: _slate.withValues(alpha: 0.25)),
        const SizedBox(height: 16),
        Text(
          _showUnreadOnly ? 'No unread notifications' : 'No notifications yet',
          style: const TextStyle(fontSize: 17,
              fontWeight: FontWeight.w600, color: _ink),
        ),
        const SizedBox(height: 8),
        Text(
          _showUnreadOnly
              ? "You're all caught up!"
              : "We'll notify you about orders, deals & more",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: _slate),
        ),
        if (_showUnreadOnly) ...[
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () => setState(() => _showUnreadOnly = false),
            child: Text('View all notifications',
                style: TextStyle(fontSize: 13, color: _teal,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ]),
    );
  }
}