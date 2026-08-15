import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:b2b_store/shared/models/return_request.dart';
import 'package:b2b_store/shared/services/api_service.dart';
import 'package:b2b_store/shop_ui/constants.dart';
import 'package:b2b_store/shop_ui/route/route_constants.dart';

class MyReturnsScreen extends StatefulWidget {
  const MyReturnsScreen({super.key});

  @override
  State<MyReturnsScreen> createState() => _MyReturnsScreenState();
}

class _MyReturnsScreenState extends State<MyReturnsScreen> {
  final _apiService = ApiService();
  List<ReturnRequest> _returns = [];
  bool _loading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetch();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _fetch());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetch() async {
    final results = await _apiService.getMyReturnRequests();
    if (mounted) setState(() { _returns = results; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Returns & Refunds',
            style: TextStyle(color: navyDark, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: navyDark),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: accentRed))
          : _returns.isEmpty
              ? _buildEmpty()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _returns.length,
                  itemBuilder: (context, i) =>
                      _ReturnListCard(rr: _returns[i]),
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 64),
        width: double.infinity,
        decoration: BoxDecoration(
          color: accentRed.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.assignment_return_outlined,
                size: 52, color: accentRed.withOpacity(0.4)),
            const SizedBox(height: 16),
            const Text('No return requests',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: navyDark)),
            const SizedBox(height: 8),
            Text(
              'When you request a return on an order,\nit will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Return List Card (mirrors OrdersScreen card style) ────────────────────────

class _ReturnListCard extends StatelessWidget {
  const _ReturnListCard({required this.rr});
  final ReturnRequest rr;

  @override
  Widget build(BuildContext context) {
    final meta = _statusMeta(rr.status);
    final shortId = 'RET-${rr.id.replaceAll('-', '').substring(0, 10).toUpperCase()}';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Body ──
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: meta.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Icon(Icons.assignment_return_rounded,
                        color: meta.color, size: 28),
                  ),
                ),
                const SizedBox(width: 14),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shortId,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: navyDark),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        rr.reason,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Colors.grey[600], fontSize: 13, height: 1.4),
                      ),
                      const SizedBox(height: 10),
                      // Status pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: meta.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: meta.color.withOpacity(0.25)),
                        ),
                        child: Text(
                          meta.label.toUpperCase(),
                          style: TextStyle(
                              color: meta.color,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Progress bar ──
          _buildMiniProgress(rr),

          // ── Footer tap row ──
          Divider(height: 1, color: Colors.grey[100]),
          InkWell(
            onTap: () => Navigator.pushNamed(
              context,
              returnDetailsScreenRoute,
              arguments: rr.id,
            ),
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(14)),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('View return details',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: navyDark,
                          fontSize: 14)),
                  Text(
                    DateFormat('d MMM, yyyy').format(rr.createdAt),
                    style:
                        TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniProgress(ReturnRequest rr) {
    if (rr.isRejected) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Row(
          children: [
            Icon(Icons.cancel_outlined, size: 13, color: accentRed),
            const SizedBox(width: 5),
            Text('Return rejected',
                style: TextStyle(
                    color: accentRed,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    final steps = ['Requested', 'Approved', 'Returning', 'Received', 'Refunded'];
    final currentIdx = _stepIndex(rr.status);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Row(
        children: steps.asMap().entries.map((e) {
          final i = e.key;
          final isComplete = i < currentIdx;
          final isActive = i == currentIdx;
          final isLast = i == steps.length - 1;
          final dotColor = isComplete || isActive ? accentRed : Colors.grey[300]!;

          return Expanded(
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isComplete
                        ? accentRed
                        : isActive
                            ? accentRed
                            : Colors.grey[300],
                    shape: BoxShape.circle,
                    border: isActive
                        ? Border.all(
                            color: accentRed.withOpacity(0.3), width: 2)
                        : null,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: isComplete ? accentRed : Colors.grey[200],
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  int _stepIndex(String status) {
    switch (status) {
      case 'pending':          return 0;
      case 'approved':         return 1;
      case 'pickup_scheduled':
      case 'drop_off_pending': return 2;
      case 'received':         return 3;
      case 'refunded':         return 4;
      default:                 return 0;
    }
  }
}

// ── Status helpers ─────────────────────────────────────────────────────────────

class _StatusMeta {
  final Color color;
  final String label;
  _StatusMeta(this.color, this.label);
}

_StatusMeta _statusMeta(String status) {
  switch (status) {
    case 'pending':          return _StatusMeta(Colors.orange, 'Under Review');
    case 'approved':         return _StatusMeta(Colors.blue, 'Approved');
    case 'rejected':         return _StatusMeta(accentRed, 'Rejected');
    case 'pickup_scheduled': return _StatusMeta(Colors.purple, 'Pickup Scheduled');
    case 'drop_off_pending': return _StatusMeta(Colors.purple, 'Drop-off Pending');
    case 'received':         return _StatusMeta(Colors.teal, 'Item Received');
    case 'refunded':         return _StatusMeta(Colors.green, 'Refunded ✓');
    default:                 return _StatusMeta(Colors.grey, status);
  }
}
