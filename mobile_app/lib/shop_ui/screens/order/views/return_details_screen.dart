import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:b2b_store/shared/models/return_request.dart';
import 'package:b2b_store/shared/services/api_service.dart';
import 'package:b2b_store/shop_ui/constants.dart';

class ReturnDetailsScreen extends StatefulWidget {
  const ReturnDetailsScreen({super.key, required this.returnId});
  final String returnId;

  @override
  State<ReturnDetailsScreen> createState() => _ReturnDetailsScreenState();
}

class _ReturnDetailsScreenState extends State<ReturnDetailsScreen> {
  final _apiService = ApiService();
  ReturnRequest? _rr;
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
    final rr = await _apiService.getReturnRequestById(widget.returnId);
    if (mounted) setState(() { _rr = rr; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Return Details',
            style: TextStyle(color: navyDark, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: navyDark),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: navyDark, size: 20),
            onPressed: _fetch,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: accentRed))
          : _rr == null
              ? const Center(child: Text('Return not found'))
              : ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    _buildHeader(_rr!),
                    const SizedBox(height: 24),
                    _buildTimeline(_rr!),
                    const SizedBox(height: 24),
                    if (_rr!.returnItems.isNotEmpty) ...[
                      _buildReturnedItemsBox(_rr!),
                      const SizedBox(height: 16),
                    ],
                    _buildReasonBox(_rr!),
                    if (_rr!.returnMethod != null) ...[
                      const SizedBox(height: 16),
                      _buildMethodBox(_rr!),
                    ],
                    if (_rr!.adminNotes != null && _rr!.adminNotes!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildAdminNotesBox(_rr!),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(ReturnRequest rr) {
    final meta = _statusMeta(rr.status);
    final shortId = rr.id.replaceAll('-', '').substring(0, 12).toUpperCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: accentRed.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Return# RET-$shortId',
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 15, color: accentRed),
          ),
        ),
        const SizedBox(height: 12),
        _StatusBadge(status: rr.status, meta: meta),
        const SizedBox(height: 16),
        Text(
          'Requested: ${DateFormat('d MMM, yyyy h:mm a').format(rr.createdAt)}',
          style: TextStyle(color: Colors.grey[500], fontSize: 13),
        ),
        if (rr.pickupDate != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.calendar_today_outlined,
                  size: 13, color: Colors.grey[400]),
              const SizedBox(width: 6),
              Text(
                'Pickup: ${DateFormat('EEEE, d MMM yyyy').format(rr.pickupDate!)}',
                style: TextStyle(
                    color: Colors.purple[600],
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ── Timeline ───────────────────────────────────────────────────────────────

  Widget _buildTimeline(ReturnRequest rr) {
    final steps = _buildSteps(rr);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Track Return',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: navyDark)),
          const SizedBox(height: 24),
          ...steps.map(_buildTimelineRow).toList(),
        ],
      ),
    );
  }

  List<_TimelineStep> _buildSteps(ReturnRequest rr) {
    final status = rr.status;
    final isRejected = status == 'rejected';

    if (isRejected) {
      return [
        _TimelineStep(
            title: 'Return Requested',
            subtitle: DateFormat('d MMM, yyyy').format(rr.createdAt),
            isCompleted: true,
            isActive: false),
        _TimelineStep(
            title: 'Request Rejected',
            subtitle: rr.adminNotes ?? 'The store has declined this return.',
            isCompleted: false,
            isActive: true,
            isRejected: true,
            isLast: true),
      ];
    }

    bool isRequested = true;
    bool isApproved =
        ['approved', 'pickup_scheduled', 'drop_off_pending', 'received', 'refunded']
            .contains(status);
    bool isReturning =
        ['pickup_scheduled', 'drop_off_pending', 'received', 'refunded']
            .contains(status);
    bool isReceived = ['received', 'refunded'].contains(status);
    bool isRefunded = status == 'refunded';

    String returningTitle = 'Returning Item';
    String? returningSubtitle;
    if (status == 'pickup_scheduled' && rr.pickupDate != null) {
      returningTitle = 'Pickup Scheduled';
      returningSubtitle =
          'Our team will pick up on ${DateFormat('EEE, d MMM').format(rr.pickupDate!)}';
    } else if (status == 'drop_off_pending') {
      returningTitle = 'Drop-off Pending';
      returningSubtitle = 'Please bring the item to our store.';
    } else if (rr.returnMethod == 'pickup') {
      returningSubtitle = 'Pickup will be scheduled.';
    } else if (rr.returnMethod == 'drop_off') {
      returningSubtitle = 'Please drop the item at our store.';
    }

    return [
      _TimelineStep(
        title: 'Return Requested',
        subtitle: DateFormat('d MMM, yyyy').format(rr.createdAt),
        isCompleted: isRequested,
        isActive: status == 'pending',
      ),
      _TimelineStep(
        title: 'Return Approved',
        subtitle: isApproved
            ? 'Store has approved your return'
            : 'Awaiting store review',
        isCompleted: isApproved,
        isActive: status == 'pending',
      ),
      _TimelineStep(
        title: returningTitle,
        subtitle: returningSubtitle,
        isCompleted: isReturning && (isReceived || isRefunded),
        isActive: status == 'pickup_scheduled' || status == 'drop_off_pending',
      ),
      _TimelineStep(
        title: 'Item Received by Store',
        subtitle:
            isReceived ? 'Store has confirmed receipt' : 'Pending receipt',
        isCompleted: isReceived,
        isActive: status == 'received' && !isRefunded,
      ),
      _TimelineStep(
        title: 'Refund Initiated',
        subtitle:
            isRefunded ? 'Your refund has been processed.' : 'Pending refund',
        isCompleted: isRefunded,
        isActive: isRefunded,
        isLast: true,
      ),
    ];
  }

  Widget _buildTimelineRow(_TimelineStep step) {
    final Color dotColor = step.isRejected
        ? accentRed
        : step.isCompleted
            ? accentRed
            : step.isActive
                ? accentRed
                : Colors.grey[300]!;
    final Color lineColor =
        step.isCompleted ? accentRed : Colors.grey[200]!;
    final Color textColor =
        step.isActive || step.isCompleted ? navyDark : Colors.grey[400]!;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: step.isRejected
                    ? accentRed
                    : step.isCompleted
                        ? accentRed
                        : Colors.white,
                border: Border.all(color: dotColor, width: 2),
                shape: BoxShape.circle,
              ),
              child: step.isRejected
                  ? const Icon(Icons.close, size: 12, color: Colors.white)
                  : step.isCompleted
                      ? const Icon(Icons.check, size: 12, color: Colors.white)
                      : step.isActive
                          ? Center(
                              child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                      color: accentRed,
                                      shape: BoxShape.circle)),
                            )
                          : null,
            ),
            if (!step.isLast)
              Container(
                width: 2,
                height: 44,
                color: lineColor,
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: step.isLast ? 0 : 20, top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: TextStyle(
                    fontWeight:
                        step.isActive ? FontWeight.bold : FontWeight.w600,
                    color: step.isRejected ? accentRed : textColor,
                    fontSize: 15,
                  ),
                ),
                if (step.subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    step.subtitle!,
                    style: TextStyle(
                      color: step.isRejected
                          ? accentRed.withOpacity(0.8)
                          : step.isActive || step.isCompleted
                              ? Colors.grey[600]
                              : Colors.grey[400],
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Returned Items ─────────────────────────────────────────────────────────

  Widget _buildReturnedItemsBox(ReturnRequest rr) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.inventory_2_outlined, size: 16, color: accentRed),
              const SizedBox(width: 8),
              const Text('Returned Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: navyDark)),
            ],
          ),
          const SizedBox(height: 14),
          ...rr.returnItems.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item.quantity}x ${item.productName}',
                        style: const TextStyle(fontWeight: FontWeight.w600, color: navyDark, fontSize: 13),
                      ),
                      Text(
                        'Item total: ₹${item.itemTotal.toStringAsFixed(2)}',
                        style: TextStyle(color: Colors.grey[500], fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Text(
                  '₹${item.refundAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Colors.green[600],
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          )),
          if (rr.returnItems.length > 1) ...[
            Divider(color: Colors.grey[300]),
            const SizedBox(height: 6),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Estimated Refund', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: navyDark)),
              Text(
                '₹${rr.refundAmount.toStringAsFixed(2)}',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green[600]),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Delivery charges are not included in the refund.',
            style: TextStyle(color: Colors.grey[500], fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ── Reason Box ─────────────────────────────────────────────────────────────

  Widget _buildReasonBox(ReturnRequest rr) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.chat_bubble_outline_rounded,
                  size: 16, color: accentRed),
              const SizedBox(width: 8),
              const Text('Return Reason',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: navyDark)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            rr.reason,
            style: TextStyle(
                color: Colors.grey[700], fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }

  // ── Method Box ─────────────────────────────────────────────────────────────

  Widget _buildMethodBox(ReturnRequest rr) {
    final isPickup = rr.returnMethod == 'pickup';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.purple.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPickup
                      ? Icons.local_shipping_outlined
                      : Icons.store_outlined,
                  size: 16,
                  color: Colors.purple[600],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPickup ? 'We will pick up from you' : 'Drop off at store',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.purple[700],
                          fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isPickup
                          ? rr.pickupDate != null
                              ? 'Scheduled for ${DateFormat('EEEE, d MMM yyyy').format(rr.pickupDate!)}'
                              : 'Pickup date will be shared soon'
                          : 'Please bring the item to our store at your earliest convenience.',
                      style: TextStyle(
                          color: Colors.purple[400],
                          fontSize: 12,
                          height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Admin Notes ────────────────────────────────────────────────────────────

  Widget _buildAdminNotesBox(ReturnRequest rr) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.indigo.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.indigo.withOpacity(0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.storefront_outlined,
              color: Colors.indigo[400], size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Note from Store',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo[600],
                        fontSize: 13)),
                const SizedBox(height: 4),
                Text(rr.adminNotes!,
                    style: const TextStyle(
                        color: navyDark, fontSize: 13, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _TimelineStep {
  final String title;
  final String? subtitle;
  final bool isCompleted;
  final bool isActive;
  final bool isLast;
  final bool isRejected;

  _TimelineStep({
    required this.title,
    this.subtitle,
    required this.isCompleted,
    required this.isActive,
    this.isLast = false,
    this.isRejected = false,
  });
}

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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.meta});
  final String status;
  final _StatusMeta meta;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: meta.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: meta.color.withOpacity(0.2)),
      ),
      child: Text(
        meta.label.toUpperCase(),
        style: TextStyle(
            color: meta.color,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5),
      ),
    );
  }
}
