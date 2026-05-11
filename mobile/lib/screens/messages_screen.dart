import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'message_thread_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _api = ApiService();
  List _conversations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _api.getInbox();
      if (!mounted) return;
      setState(() => _conversations = data);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.gold))
          : _conversations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.chat_bubble_outline,
                          size: 64, color: AppColors.textMuted),
                      const SizedBox(height: 16),
                      Text('No messages yet',
                          style: GoogleFonts.inter(
                              color: AppColors.textMuted, fontSize: 16)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.gold,
                  backgroundColor: AppColors.surface,
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _conversations.length,
                    separatorBuilder: (ctx, i) =>
                        const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final c = _conversations[i];
                      final unread = c['unread'] as int? ?? 0;
                      return GestureDetector(
                        onTap: () async {
                          await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => MessageThreadScreen(
                                        partnerId: c['partner_id'],
                                        partnerUsername:
                                            c['partner_username'],
                                      )));
                          _load();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: unread > 0
                                    ? AppColors.gold.withAlpha(80)
                                    : AppColors.border),
                          ),
                          child: Row(
                            children: [
                              // Avatar
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: unread > 0
                                      ? goldGradient
                                      : const LinearGradient(colors: [
                                          AppColors.surfaceLight,
                                          AppColors.surfaceLight
                                        ]),
                                ),
                                child: Center(
                                  child: Text(
                                    (c['partner_username'] ?? 'U')
                                        .substring(0, 1)
                                        .toUpperCase(),
                                    style: GoogleFonts.orbitron(
                                        color: unread > 0
                                            ? AppColors.background
                                            : AppColors.textMuted,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(c['partner_username'] ?? '',
                                        style: GoogleFonts.inter(
                                            color: AppColors.textPrimary,
                                            fontWeight: unread > 0
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            fontSize: 14)),
                                    const SizedBox(height: 2),
                                    Text(c['last_message'] ?? '',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                            color: AppColors.textMuted,
                                            fontSize: 12)),
                                  ],
                                ),
                              ),
                              if (unread > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    gradient: goldGradient,
                                    borderRadius:
                                        BorderRadius.circular(20),
                                  ),
                                  child: Text('$unread',
                                      style: GoogleFonts.inter(
                                          color: AppColors.background,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700)),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
