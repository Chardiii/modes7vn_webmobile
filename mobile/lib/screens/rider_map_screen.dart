import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/api_service.dart';
import '../theme.dart';

class RiderMapScreen extends StatefulWidget {
  const RiderMapScreen({super.key});

  @override
  State<RiderMapScreen> createState() => _RiderMapScreenState();
}

class _RiderMapScreenState extends State<RiderMapScreen> {
  final _api = ApiService();
  late final WebViewController _wvc;

  List<dynamic> _orders = [];
  bool _loading         = true;
  Map<String, dynamic>? _selected;

  @override
  void initState() {
    super.initState();
    _wvc = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'FlutterBridge',
        onMessageReceived: (msg) {
          // Message from JS: JSON string of the tapped order
          try {
            final o = jsonDecode(msg.message) as Map<String, dynamic>;
            setState(() => _selected = o);
          } catch (_) {}
        },
      )
      ..loadHtmlString(_buildHtml([]));
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _api.getRiderMapOrders();
      if (!mounted) return;
      setState(() => _orders = data);
      // Reload the WebView with the new order data
      await _wvc.loadHtmlString(_buildHtml(data));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _navigate(Map o) async {
    final q = Uri.encodeComponent(
        '${o['delivery_address']}, ${o['delivery_city']}, ${o['delivery_province']}');
    final uri =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$q');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ── Build the full Leaflet HTML page ──────────────────────────────────────
  String _buildHtml(List<dynamic> orders) {
    final ordersJson = jsonEncode(orders);
    return '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
<link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css">
<style>
  * { margin:0; padding:0; box-sizing:border-box; }
  html, body, #map { width:100%; height:100%; }
  .popup-box { font-family:sans-serif; font-size:13px; min-width:200px; }
  .popup-title { font-weight:800; font-size:14px; margin-bottom:6px; }
  .popup-row { margin-bottom:4px; color:#374151; }
  .popup-label { color:#9ca3af; font-size:11px; }
  .popup-cod { font-weight:800; color:#059669; font-size:15px; margin:6px 0; }
  .popup-btn {
    display:block; width:100%; padding:8px; margin-top:8px;
    background:#1d4ed8; color:#fff; border:none; border-radius:8px;
    font-weight:700; font-size:13px; cursor:pointer; text-align:center;
  }
</style>
</head>
<body>
<div id="map"></div>
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
<script>
  var orders = $ordersJson;

  var map = L.map('map', { zoomControl: true }).setView([12.8797, 121.7740], 6);

  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    attribution: '© OpenStreetMap',
    maxZoom: 19
  }).addTo(map);

  function makeIcon(color) {
    return L.divIcon({
      className: '',
      html: '<div style="width:22px;height:22px;border-radius:50% 50% 50% 0;background:' + color + ';border:3px solid #fff;box-shadow:0 2px 6px rgba(0,0,0,.4);transform:rotate(-45deg);"></div>',
      iconSize: [22, 22],
      iconAnchor: [11, 22],
      popupAnchor: [0, -24]
    });
  }

  var icons = {
    available: makeIcon('#10b981'),
    assigned:  makeIcon('#3b82f6'),
    shipped:   makeIcon('#f59e0b')
  };

  var bounds = [];

  orders.forEach(function(o) {
    var icon = o.is_mine
      ? (o.status === 'shipped' ? icons.shipped : icons.assigned)
      : icons.available;

    var badge = o.is_mine
      ? (o.status === 'shipped' ? 'PICKED UP' : 'ASSIGNED')
      : 'AVAILABLE';

    var popup = '<div class="popup-box">'
      + '<div class="popup-title">' + o.order_number + ' <small style="font-weight:500;color:#6b7280;">' + badge + '</small></div>'
      + '<div class="popup-row"><span class="popup-label">Address: </span>' + o.delivery_address + ', ' + o.delivery_city + '</div>'
      + '<div class="popup-row"><span class="popup-label">Buyer: </span>' + (o.buyer || '—') + (o.buyer_phone ? ' · ' + o.buyer_phone : '') + '</div>'
      + '<div class="popup-cod">₱' + parseFloat(o.total_amount).toFixed(2) + '</div>'
      + '<button class="popup-btn" onclick="tapped(' + JSON.stringify(JSON.stringify(o)) + ')">🗺️ Navigate</button>'
      + '</div>';

    var m = L.marker([o.lat, o.lng], { icon: icon }).addTo(map);
    m.bindPopup(popup, { maxWidth: 260 });
    bounds.push([o.lat, o.lng]);
  });

  if (bounds.length === 1) {
    map.setView(bounds[0], 14);
  } else if (bounds.length > 1) {
    map.fitBounds(bounds, { padding: [40, 40], maxZoom: 14 });
  }

  function tapped(jsonStr) {
    FlutterBridge.postMessage(jsonStr);
  }
</script>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    final mine  = _orders.where((o) => o['is_mine'] == true).length;
    final avail = _orders.length - mine;

    return Scaffold(
      appBar: AppBar(
        title: Text('Delivery Map',
            style: GoogleFonts.orbitron(
                fontSize: 16, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _load,
              tooltip: 'Refresh'),
        ],
      ),
      body: Column(
        children: [
          // ── Legend bar ─────────────────────────────────────────
          Container(
            color: AppColors.surface,
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                _Dot(color: AppColors.success),
                const SizedBox(width: 4),
                Text('$avail available',
                    style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
                _Dot(color: Colors.blue),
                const SizedBox(width: 4),
                Text('$mine mine',
                    style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                if (_loading)
                  const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.gold))
                else
                  Text(
                      '${_orders.length} pin${_orders.length != 1 ? 's' : ''}',
                      style: GoogleFonts.inter(
                          color: AppColors.textMuted, fontSize: 11)),
              ],
            ),
          ),

          // ── WebView map (fills remaining space) ────────────────
          Expanded(
            child: WebViewWidget(controller: _wvc),
          ),

          // ── Selected order card ────────────────────────────────
          if (_selected != null)
            _OrderCard(
              order: _selected!,
              onClose: () => setState(() => _selected = null),
              onNavigate: () => _navigate(_selected!),
            ),
        ],
      ),
    );
  }
}

// ── Dot ───────────────────────────────────────────────────────────────────────

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5)),
    );
  }
}

// ── Order card ────────────────────────────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  final Map order;
  final VoidCallback onClose;
  final VoidCallback onNavigate;

  const _OrderCard({
    required this.order,
    required this.onClose,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final isMine    = order['is_mine'] == true;
    final isShipped = order['status'] == 'shipped';

    final Color badgeColor;
    final String badgeLabel;
    if (!isMine) {
      badgeColor = AppColors.success;
      badgeLabel = 'AVAILABLE';
    } else if (isShipped) {
      badgeColor = AppColors.goldMid;
      badgeLabel = 'PICKED UP';
    } else {
      badgeColor = Colors.blue;
      badgeLabel = 'ASSIGNED';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(40),
              blurRadius: 10,
              offset: const Offset(0, -2)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(order['order_number'] ?? '',
                    style: GoogleFonts.orbitron(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: badgeColor.withAlpha(100)),
                ),
                child: Text(badgeLabel,
                    style: GoogleFonts.inter(
                        color: badgeColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onClose,
                child: const Icon(Icons.close,
                    color: AppColors.textMuted, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_outlined,
                  color: AppColors.gold, size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                    '${order['delivery_address'] ?? ''}, ${order['delivery_city'] ?? ''}',
                    style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.person_outline,
                  color: AppColors.textMuted, size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                    '${order['buyer'] ?? '—'}'
                    '${order['buyer_phone'] != null ? ' · ${order['buyer_phone']}' : ''}',
                    style: GoogleFonts.inter(
                        color: AppColors.textMuted, fontSize: 11)),
              ),
              ShaderMask(
                shaderCallback: (b) => goldGradient.createShader(b),
                child: Text(
                    '₱${(order['total_amount'] as num).toStringAsFixed(2)}',
                    style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: Container(
              decoration: BoxDecoration(
                gradient: goldGradient,
                borderRadius: BorderRadius.circular(40),
              ),
              child: ElevatedButton.icon(
                onPressed: onNavigate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: AppColors.background,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(40)),
                ),
                icon: const Icon(Icons.navigation_outlined, size: 16),
                label: Text('NAVIGATE',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 1)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
