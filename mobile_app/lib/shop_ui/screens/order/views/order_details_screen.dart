import 'dart:async';
import 'package:b2b_store/shared/models/order.dart';
import 'package:b2b_store/shared/models/return_request.dart';
import 'package:b2b_store/shared/services/api_service.dart';
import 'package:b2b_store/shop_ui/constants.dart';
import 'package:b2b_store/shop_ui/route/route_constants.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class OrderDetailsScreen extends StatefulWidget {
  const OrderDetailsScreen({super.key, required this.orderId});

  final String orderId;

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  final ApiService _apiService = ApiService();
  late Future<Order?> _orderFuture;
  List<ReturnRequest> _returnRequests = [];
  bool _loadingReturn = false;
  StreamSubscription<List<ReturnRequest>>? _returnSub;

  /// IDs of order items already covered by non-rejected return requests
  /// (used to exclude from the item picker in the bottom sheet)
  Set<String> get _returnedItemIds => _returnRequests
      .where((r) => !r.isRejected)
      .expand((r) => r.returnedItemIds)
      .toSet();

  /// IDs of order items covered by ANY return request including rejected ones
  /// (used to decide whether the return button should appear at all)
  Set<String> get _allCoveredItemIds => _returnRequests
      .expand((r) => r.returnedItemIds)
      .toSet();

  @override
  void initState() {
    super.initState();
    _orderFuture = _apiService.getOrderById(widget.orderId);
    _startReturnStream();
  }

  void _startReturnStream() {
    _returnSub = _apiService
        .watchReturnRequestsForOrder(widget.orderId)
        .listen((list) {
      if (mounted) setState(() => _returnRequests = list);
    });
  }

  @override
  void dispose() {
    _returnSub?.cancel();
    super.dispose();
  }

  bool _isWithinReturnWindow(Order order) {
    return DateTime.now().difference(order.createdAt).inDays <= 7;
  }

  bool _canRequestReturn(Order order) {
    if (!order.isCompleted) return false;
    if (!_isWithinReturnWindow(order)) return false;
    final items = order.items ?? [];
    // An item is only eligible if it hasn't been covered by ANY return request
    // (including rejected ones — admin rejection is final, no re-submitting)
    return items.any((item) => !_allCoveredItemIds.contains(item.id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Order Details', style: TextStyle(color: navyDark, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: navyDark),
      ),
      body: FutureBuilder<Order?>(
        future: _orderFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: accentRed));
          }

          final initialOrder = snapshot.data;
          if (initialOrder == null) {
            return const Center(child: Text('Order not found'));
          }

          return StreamBuilder<Order?>(
            stream: _apiService.watchOrder(widget.orderId),
            initialData: initialOrder,
            builder: (context, streamSnapshot) {
              final liveOrder = streamSnapshot.data ?? initialOrder;
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _buildHeader(liveOrder),
                  const SizedBox(height: 24),
                  _buildDetailedTimeline(liveOrder),
                  const SizedBox(height: 32),
                  _buildSummaryBox(liveOrder),
                  const SizedBox(height: 24),
                  _buildPaymentBox(liveOrder),
                  const SizedBox(height: 24),
                  // Return section
                  if (_returnRequests.isNotEmpty) ...[
                    ..._returnRequests.map((rr) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildViewReturnButton(rr),
                    )),
                    if (_canRequestReturn(liveOrder)) ...[
                      _buildReturnMoreButton(liveOrder),
                      const SizedBox(height: 8),
                    ],
                    const SizedBox(height: 12),
                  ] else if (_canRequestReturn(liveOrder)) ...[
                    _buildReturnButton(liveOrder),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        '${7 - DateTime.now().difference(liveOrder.createdAt).inDays} day(s) left to request a return',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ] else if (liveOrder.isCompleted && !_isWithinReturnWindow(liveOrder) && _returnRequests.isEmpty) ...[
                    _buildReturnExpiredBanner(),
                    const SizedBox(height: 24),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHeader(Order order) {
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
            "Order# ${order.orderNumber}",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: accentRed),
          ),
        ),
        const SizedBox(height: 12),
        _buildStatusBadge(order.status),
        const SizedBox(height: 16),
        InkWell(
          onTap: () {
            // help logic
          },
          child: const Text(
            "Get help with this order",
            style: TextStyle(
              color: navyDark,
              decoration: TextDecoration.underline,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Order date: ${DateFormat('d MMM, yyyy h:mm a').format(order.createdAt)}",
          style: TextStyle(color: Colors.grey[500], fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'delivered':
      case 'picked_up':
        color = Colors.green;
        break;
      case 'cancelled':
        color = accentRed;
        break;
      case 'packed':
      case 'processing':
        color = navyDark;
        break;
      default:
        color = Colors.orange;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildDetailedTimeline(Order order) {
    final isDelivery = order.isDelivery;
    final status = order.status.toLowerCase();
    
    bool hasEta = order.estimatedDeliveryTime != null || order.etaMinutes != null;

    bool isAcceptedCompleted = status != 'pending';
    bool isProcessingCompleted = ['packed', 'out_for_delivery', 'delivered', 'picked_up'].contains(status) || 
                                 (isDelivery && status == 'processing' && hasEta);
    bool isPackedOrOut = ['packed', 'out_for_delivery', 'delivered', 'picked_up'].contains(status);
    bool isCompleted = ['delivered', 'picked_up'].contains(status);
    bool isCancelled = status == 'cancelled';
    
    if (isCancelled) {
       return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: accentRed.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
              const Icon(Icons.cancel, color: accentRed),
              const SizedBox(width: 12),
              const Text("Order Cancelled", style: TextStyle(color: accentRed, fontWeight: FontWeight.bold, fontSize: 16)),
          ]),
       );
    }

    List<_TimelineStep> steps = [];
    
    steps.add(_TimelineStep(
      title: "Order Accepted", 
      isCompleted: isAcceptedCompleted, 
      isActive: status == 'pending'
    ));
    
    steps.add(_TimelineStep(
      title: "Processing", 
      isCompleted: isProcessingCompleted, 
      isActive: status == 'processing' && !(isDelivery && hasEta)
    ));
    
    if (isDelivery) {
       String etaText = "";
       bool isDelayed = order.isDelayed;
       if (order.estimatedDeliveryTime != null) {
          etaText = "To be delivered by ${DateFormat('h:mm a').format(order.estimatedDeliveryTime!)}";
       } else if (order.etaMinutes != null) {
          etaText = "Estimated time: ${order.etaMinutes} mins";
       }
       
       steps.add(_TimelineStep(
         title: status == 'out_for_delivery' ? "Out for Delivery" : "Delivery", 
         subtitle: etaText.isNotEmpty ? etaText : null,
         isDelayed: isDelayed,
         isCompleted: isCompleted,
         isActive: status == 'out_for_delivery' || (status == 'processing' && hasEta)
       ));
    } else {
       steps.add(_TimelineStep(
         title: "Order Packed", 
         subtitle: "Ready for pickup at store", 
         isCompleted: isPackedOrOut && status != 'packed', 
         isActive: status == 'packed'
       ));
       bool isPaid = order.paymentStatus == 'paid';
       steps.add(_TimelineStep(
         title: "Payment", 
         subtitle: isPaid ? "Paid successfully" : "Pending payment at store",
         isCompleted: isPaid, 
         isActive: !isPaid && isPackedOrOut
       ));
    }
    
    steps.add(_TimelineStep(
      title: "Order Completed", 
      subtitle: isDelivery ? "Delivered successfully" : "Picked up by customer", 
      isCompleted: isCompleted, 
      isActive: isCompleted, 
      isLast: true
    ));
    
    return Container(
       padding: const EdgeInsets.all(20),
       decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4))],
       ),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           const Text("Track Order", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: navyDark)),
           const SizedBox(height: 24),
           ...steps.map((s) => _buildTimelineRow(s)).toList(),
         ],
       ),
    );
  }

  Widget _buildTimelineRow(_TimelineStep step) {
    Color dotColor = step.isCompleted || step.isActive ? accentRed : Colors.grey[300]!;
    Color textColor = step.isActive || step.isCompleted ? navyDark : Colors.grey[400]!;
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: step.isCompleted ? accentRed : Colors.white,
                border: Border.all(color: dotColor, width: 2),
                shape: BoxShape.circle,
              ),
              child: step.isCompleted 
                ? const Icon(Icons.check, size: 12, color: Colors.white) 
                : step.isActive
                  ? Center(child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: accentRed, shape: BoxShape.circle)))
                  : null,
            ),
            if (!step.isLast)
              Container(
                width: 2,
                height: 40,
                color: step.isCompleted ? accentRed : Colors.grey[200]!,
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: step.isLast ? 0 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: TextStyle(fontWeight: step.isActive ? FontWeight.bold : FontWeight.w600, color: textColor, fontSize: 15),
                ),
                if (step.subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text.rich(
                    TextSpan(
                      children: [
                         TextSpan(text: step.subtitle),
                         if (step.isDelayed)
                           const TextSpan(text: " (Delayed)", style: TextStyle(color: accentRed, fontWeight: FontWeight.bold)),
                      ]
                    ),
                    style: TextStyle(color: step.isDelayed ? accentRed : (step.isActive || step.isCompleted ? Colors.grey[600] : Colors.grey[400]), fontSize: 13),
                  ),
                ]
              ],
            ),
          ),
        )
      ],
    );
  }

  Widget _buildSummaryBox(Order order) {
    final items = order.items ?? [];
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    "${item.quantity}x ${item.productName}",
                    style: const TextStyle(fontWeight: FontWeight.w600, color: navyDark, fontSize: 14),
                  ),
                ),
                Text("₹${item.totalPrice.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.w600, color: navyDark)),
              ],
            ),
          )),
          const SizedBox(height: 8),
          Divider(color: Colors.grey[300]),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Subtotal", style: TextStyle(color: Colors.grey[700], fontSize: 14)),
              Text("₹${order.subtotal.toStringAsFixed(2)}", style: TextStyle(color: Colors.grey[700], fontSize: 14)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Delivery costs", style: TextStyle(color: Colors.grey[700], fontSize: 14)),
              Text(
                order.deliveryCharge == 0 ? "Free" : "₹${order.deliveryCharge.toStringAsFixed(2)}",
                style: TextStyle(color: Colors.grey[700], fontSize: 14),
              ),
            ],
          ),
          if (order.discountAmount > 0) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Discount", style: TextStyle(color: Colors.grey[700], fontSize: 14)),
                Text("- ₹${order.discountAmount.toStringAsFixed(2)}", style: TextStyle(color: Colors.grey[700], fontSize: 14)),
              ],
            ),
          ],
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Total (incl. VAT)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: navyDark)),
              Text("₹${order.totalAmount.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: navyDark)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentBox(Order order) {
    String paymentMethodStr = "";
    switch (order.paymentMethod) {
      case 'cod': paymentMethodStr = "Cash on delivery"; break;
      case 'razorpay': paymentMethodStr = "Razorpay"; break;
      case 'upi': paymentMethodStr = "UPI"; break;
      case 'pay_at_store': paymentMethodStr = "Pay at store"; break;
      default: paymentMethodStr = order.paymentMethod;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("Paid with", style: TextStyle(fontWeight: FontWeight.bold, color: navyDark, fontSize: 15)),
          Row(
            children: [
              Icon(Icons.payments_outlined, size: 18, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(paymentMethodStr, style: TextStyle(color: Colors.grey[700], fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Return Widgets ─────────────────────────────────────────────────────────

  Widget _buildReturnButton(Order order) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _loadingReturn ? null : () => _showReturnBottomSheet(order),
        icon: const Icon(Icons.assignment_return_outlined, size: 18),
        label: const Text('Request Return', style: TextStyle(fontWeight: FontWeight.bold)),
        style: OutlinedButton.styleFrom(
          foregroundColor: navyDark,
          side: const BorderSide(color: navyDark),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildReturnMoreButton(Order order) {
    final remaining = (order.items ?? [])
        .where((i) => !_returnedItemIds.contains(i.id))
        .length;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _loadingReturn ? null : () => _showReturnBottomSheet(order),
        icon: const Icon(Icons.add_circle_outline, size: 18),
        label: Text(
          'Return More Items ($remaining remaining)',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: navyDark,
          side: const BorderSide(color: navyDark),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildReturnExpiredBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.grey[500], size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'The 7-day return window for this order has expired.',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewReturnButton(ReturnRequest rr) {
    final statusColors = {
      'pending': Colors.orange,
      'approved': Colors.blue,
      'rejected': accentRed,
      'pickup_scheduled': Colors.purple,
      'drop_off_pending': Colors.purple,
      'received': Colors.teal,
      'refunded': Colors.green,
    };
    final color = statusColors[rr.status] ?? Colors.grey;

    return InkWell(
      onTap: () => Navigator.pushNamed(
        context,
        returnDetailsScreenRoute,
        arguments: rr.id,
      ),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.assignment_return_rounded, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Return Request',
                    style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    rr.statusLabel,
                    style: TextStyle(color: color.withOpacity(0.8), fontSize: 13),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color.withOpacity(0.6), size: 22),
          ],
        ),
      ),
    );
  }

  void _showReturnBottomSheet(Order order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReturnBottomSheet(
        order: order,
        alreadyReturnedItemIds: _returnedItemIds,
        onSubmit: (reason, selectedItems, refundAmount) async {
          Navigator.pop(context);
          setState(() => _loadingReturn = true);
          try {
            final returnItemsJson = selectedItems.map((item) {
              final proportion = order.subtotal > 0 ? item.totalPrice / order.subtotal : 0.0;
              final itemDiscount = order.discountAmount * proportion;
              final itemRefund = item.totalPrice - itemDiscount;
              return {
                'order_item_id': item.id,
                'product_name': item.productName,
                'quantity': item.quantity,
                'item_total': item.totalPrice,
                'refund_amount': double.parse(itemRefund.toStringAsFixed(2)),
              };
            }).toList();

            await _apiService.createReturnRequest(
              orderId: order.id,
              reason: reason,
              returnItems: returnItemsJson,
              refundAmount: double.parse(refundAmount.toStringAsFixed(2)),
            );
            if (mounted) {
              setState(() => _loadingReturn = false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Return request submitted!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              setState(() => _loadingReturn = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to submit: $e'),
                  backgroundColor: accentRed,
                ),
              );
            }
          }
        },
      ),
    );
  }
}

// ── Return Bottom Sheet ──────────────────────────────────────────────────────

class _ReturnBottomSheet extends StatefulWidget {
  const _ReturnBottomSheet({
    required this.order,
    required this.alreadyReturnedItemIds,
    required this.onSubmit,
  });

  final Order order;
  final Set<String> alreadyReturnedItemIds;
  final Future<void> Function(
    String reason,
    List<OrderItem> selectedItems,
    double refundAmount,
  ) onSubmit;

  @override
  State<_ReturnBottomSheet> createState() => _ReturnBottomSheetState();
}

class _ReturnBottomSheetState extends State<_ReturnBottomSheet> {
  final _reasonController = TextEditingController();
  final Set<String> _selectedIds = {};
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  List<OrderItem> get _selectableItems => (widget.order.items ?? [])
      .where((i) => !widget.alreadyReturnedItemIds.contains(i.id))
      .toList();

  List<OrderItem> get _selectedItems =>
      _selectableItems.where((i) => _selectedIds.contains(i.id)).toList();

  double _itemRefund(OrderItem item) {
    final subtotal = widget.order.subtotal;
    if (subtotal <= 0) return item.totalPrice;
    final proportion = item.totalPrice / subtotal;
    final itemDiscount = widget.order.discountAmount * proportion;
    return item.totalPrice - itemDiscount;
  }

  double get _totalRefund =>
      _selectedItems.fold(0.0, (sum, item) => sum + _itemRefund(item));

  Future<void> _handleSubmit() async {
    if (_selectedIds.isEmpty) {
      setState(() => _error = 'Please select at least one item to return.');
      return;
    }
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      setState(() => _error = 'Please describe the reason for your return.');
      return;
    }
    setState(() { _submitting = true; _error = null; });
    await widget.onSubmit(reason, _selectedItems, _totalRefund);
  }

  @override
  Widget build(BuildContext context) {
    final selectable = _selectableItems;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
            ),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: accentRed.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.assignment_return_outlined, color: accentRed, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Request a Return', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: navyDark)),
                      Text('Order #${widget.order.orderNumber}', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Item Selection ──
            const Text('Select items to return', style: TextStyle(fontWeight: FontWeight.bold, color: navyDark, fontSize: 14)),
            const SizedBox(height: 4),
            Text('Tap items you want to return', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            const SizedBox(height: 10),

            Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: selectable.asMap().entries.map((entry) {
                  final i = entry.key;
                  final item = entry.value;
                  final isSelected = _selectedIds.contains(item.id);
                  final isLast = i == selectable.length - 1;
                  return InkWell(
                    onTap: () => setState(() {
                      if (isSelected) _selectedIds.remove(item.id);
                      else _selectedIds.add(item.id);
                      _error = null;
                    }),
                    borderRadius: BorderRadius.vertical(
                      top: i == 0 ? const Radius.circular(12) : Radius.zero,
                      bottom: isLast ? const Radius.circular(12) : Radius.zero,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? accentRed.withOpacity(0.05) : Colors.transparent,
                        border: !isLast ? Border(bottom: BorderSide(color: Colors.grey[200]!)) : null,
                        borderRadius: BorderRadius.vertical(
                          top: i == 0 ? const Radius.circular(12) : Radius.zero,
                          bottom: isLast ? const Radius.circular(12) : Radius.zero,
                        ),
                      ),
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 22, height: 22,
                            decoration: BoxDecoration(
                              color: isSelected ? accentRed : Colors.white,
                              border: Border.all(color: isSelected ? accentRed : Colors.grey[300]!, width: 1.5),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: isSelected
                                ? const Icon(Icons.check, size: 14, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${item.quantity}x ${item.productName}',
                                  style: TextStyle(
                                    color: navyDark,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                ),
                                if (widget.order.discountAmount > 0 && isSelected) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Refund: ₹${_itemRefund(item).toStringAsFixed(2)}',
                                    style: TextStyle(color: Colors.green[600], fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '₹${item.totalPrice.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: navyDark,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  decoration: (widget.order.discountAmount > 0 && isSelected)
                                      ? TextDecoration.lineThrough
                                      : null,
                                  decorationColor: Colors.grey,
                                ),
                              ),
                              if (widget.order.discountAmount > 0 && isSelected)
                                Text(
                                  '₹${_itemRefund(item).toStringAsFixed(2)}',
                                  style: TextStyle(color: Colors.green[600], fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // ── Refund Preview ──
            if (_selectedIds.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    if (widget.order.discountAmount > 0) ...[
                      _refundRow(
                        'Items subtotal',
                        '₹${_selectedItems.fold(0.0, (s, i) => s + i.totalPrice).toStringAsFixed(2)}',
                        grey: true,
                      ),
                      _refundRow(
                        'Proportional discount',
                        '- ₹${(_selectedItems.fold(0.0, (s, i) => s + i.totalPrice) - _totalRefund).toStringAsFixed(2)}',
                        grey: true,
                        isDiscount: true,
                      ),
                      Divider(height: 16, color: Colors.green.withOpacity(0.2)),
                    ],
                    _refundRow('Estimated Refund', '₹${_totalRefund.toStringAsFixed(2)}', bold: true, green: true),
                    const SizedBox(height: 4),
                    Text(
                      'Delivery charges are non-refundable for partial returns.',
                      style: TextStyle(color: Colors.grey[500], fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // ── Reason ──
            const Text('Reason for return *', style: TextStyle(fontWeight: FontWeight.bold, color: navyDark, fontSize: 14)),
            const SizedBox(height: 8),
            TextField(
              controller: _reasonController,
              maxLines: 3,
              onChanged: (_) => setState(() => _error = null),
              decoration: InputDecoration(
                hintText: 'e.g. Item arrived damaged, wrong product received...',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                filled: true,
                fillColor: Colors.grey[50],
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: navyDark, width: 1.5)),
                errorText: _error,
              ),
            ),
            const SizedBox(height: 12),

            // Policy note
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withOpacity(0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.orange[700], size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Returns are subject to review. The store team will respond within 1–2 business days.',
                      style: TextStyle(color: Colors.orange[800], fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Submit
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_submitting || _selectedIds.isEmpty) ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: navyDark,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[300],
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _submitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(
                        _selectedIds.isEmpty
                            ? 'Select items to continue'
                            : 'Submit Return Request',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _refundRow(String label, String value, {
    bool bold = false, bool green = false, bool grey = false, bool isDiscount = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(
            color: grey ? Colors.grey[500] : (green ? Colors.green[700] : navyDark),
            fontSize: bold ? 14 : 13,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          )),
          Text(value, style: TextStyle(
            color: isDiscount ? Colors.red[400] : (green ? Colors.green[700] : navyDark),
            fontSize: bold ? 15 : 13,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
          )),
        ],
      ),
    );
  }
}




class _DottedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[400]!
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    const double dashHeight = 4;
    const double dashSpace = 4;
    double startY = 0;

    while (startY < size.height) {
      canvas.drawLine(
        Offset(size.width / 2, startY),
        Offset(size.width / 2, startY + dashHeight),
        paint,
      );
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TimelineStep {
  final String title;
  final String? subtitle;
  final bool isCompleted;
  final bool isActive;
  final bool isLast;
  final bool isDelayed;
  
  _TimelineStep({
    required this.title, 
    this.subtitle, 
    required this.isCompleted, 
    required this.isActive, 
    this.isLast = false, 
    this.isDelayed = false
  });
}

class _ReturnStep {
  final String label;
  final List<String> activeStatuses;
  _ReturnStep(this.label, this.activeStatuses);
}
