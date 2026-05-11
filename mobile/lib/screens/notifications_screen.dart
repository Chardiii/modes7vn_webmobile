import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _api = ApiService();
  List<dynamic> _items = [];
  bool _loading = true;
  int _page = 1;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({int page = 1}) async {
    setState(() => _loading = true);
    try {
      final data = await _api.getNotifications(page: page);
      if (!mounted) return;
      setState(() {
        _items      = data['notifications'] as List? ?? [];
        _page       = data['page'] ?? 1;
        _totalPages = data['pages'] ?? 1;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markRead(Map n) async {
    if (n['is_read'] == true) return;
    try {
      await _api.markNotificationRead(n['id']);
      setState(() => n['is_read'] = true);
    } catch (_) {}
  }

  Future<void> _markAllRead() async {
    try {
      await _api.markAllNotificationsRead();
      setState(() {
        for (final n in _items) {
          n['is_read'] = true;
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All notifications marked as read')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  IconData _icon(String type) {
    switch (type) {
      case 'order':   return Icons.shopping_bag_outlined;
      case 'message': return Icons.chat_bubble_outline;
      case 'account': return Icons.verified_user_outlined;
      case 'review':  return Icons.star_outline;
      case 'stock':   return Icons.warning_amber_outlined;
      default:        return Icons.notifications_outlined;
    }
  }

  Color _color(String type) {
    switch (type) {
      case 'order':   return AppColors.goldMid;
      case 'message': return Colors.blue;
      case 'account': return AppColors.success;
      case 'review':  return Colors.purple;
      case 'stock':   return AppColors.error;
      default:        return AppColors.textMuted;
    }
  }

  String _timeAgo(String iso) {
    try {
      final dt   = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inSeconds < 60)  return 'just now';
      if (diff.inMinutes < 60)  return '${diff.inMinutes}m ago';
      if (diff.inHours < 24)    return '${diff.inHours}h ago';
      if (diff.inDays < 7)      return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _items.where((n) => n['is_read'] == false).length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Notifications',
            style: GoogleFonts.orbitron(
                fontSize: 16, fontWeight: FontWeight.w700)),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: Text('Mark all read',
                  style: GoogleFonts.inter(
                      color: AppColors.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : RefreshIndicator(
              color: AppColors.gold,
              backgroundColor: AppColors.surface,
              onRefresh: () => _load(page: 1),
              child: _items.isEmpty
                  ? _EmptyState()
                  : Column(
                      children: [
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 12),
                            itemCount: _items.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 6),
                            itemBuilder: (ctx, i) {
                              final n    = _items[i];
                              final type = n['type'] ?? '';
                              final read = n['is_read'] == true;
                              return _NotifTile(
                                title:   n['title'] ?? '',
                                body:    n['body']  ?? '',
                                time:    _timeAgo(n['created_at'] ?? ''),
                                icon:    _icon(type),
                                color:   _color(type),
                                isRead:  read,
                                onTap:   () => _markRead(n),
                              );
                            },
                          ),
                        ),
                        if (_totalPages > 1)
                          _Pagination(
                            page:       _page,
                            totalPages: _totalPages,
                            onPrev:     () => _load(page: _page - 1),
                            onNext:     () => _load(page: _page + 1),
                          ),
                      ],
                    ),
            ),
    );
  }
}

// ── Tile ──────────────────────────────────────────────────────────────────────

class _NotifTile extends StatelessWidget {
  final String title;
  final String body;
  final String time;
  final IconData icon;
  final Color color;
  final bool isRead;
  final VoidCallback onTap;

  const _NotifTile({
    required this.title,
    required this.body,
    required this.time,
    required this.icon,
    required this.color,
    required this.isRead,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isRead
              ? AppColors.surface
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isRead
                ? AppColors.border
                : color.withAlpha(80),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(title,
                            style: GoogleFonts.inter(
                                color: AppColors.textPrimary,
                                fontWeight: isRead
                                    ? FontWeight.w500
                                    : FontWeight.w700,
                                fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 6, top: 3),
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(body,
                      style: GoogleFonts.inter(
                          color: AppColors.textMuted, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(time,
                      style: GoogleFonts.inter(
                          color: AppColors.textMuted.withAlpha(150),
                          fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined,
              size: 56, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text('No notifications yet',
              style: GoogleFonts.inter(
                  color: AppColors.textMuted, fontSize: 14)),
          const SizedBox(height: 4),
          Text('Pull down to refresh',
              style: GoogleFonts.inter(
                  color: AppColors.textMuted, fontSize: 12)),
        ],
      ),
    );
  }
}

// ── Pagination ────────────────────────────────────────────────────────────────

class _Pagination extends StatelessWidget {
  final int page;
  final int totalPages;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _Pagination({
    required this.page,
    required this.totalPages,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: page > 1 ? onPrev : null,
            icon: const Icon(Icons.chevron_left),
            color: page > 1 ? AppColors.gold : AppColors.textMuted,
          ),
          Text('$page / $totalPages',
              style: GoogleFonts.inter(
                  color: AppColors.textMuted, fontSize: 13)),
          IconButton(
            onPressed: page < totalPages ? onNext : null,
            icon: const Icon(Icons.chevron_right),
            color: page < totalPages ? AppColors.gold : AppColors.textMuted,
          ),
        ],
      ),
    );
  }
}
