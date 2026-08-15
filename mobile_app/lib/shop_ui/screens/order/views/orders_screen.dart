import 'package:flutter/material.dart';
import 'package:b2b_store/shared/models/order.dart';
import 'package:b2b_store/shared/services/api_service.dart';
import 'package:b2b_store/shop_ui/constants.dart';
import 'package:b2b_store/shop_ui/route/route_constants.dart';
import 'package:intl/intl.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final _apiService = ApiService();
  late Future<List<Order>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  void _fetchOrders() {
    _ordersFuture = _apiService.getMyOrders();
  }

  @override
  Widget build(BuildContext context) {
    const Color bgColor = Color(0xFFF5F5F5); // light grey background

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text("My Orders", style: TextStyle(color: navyDark, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: navyDark),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pushNamed(context, myReturnsScreenRoute),
            icon: const Icon(Icons.assignment_return_outlined, size: 16, color: accentRed),
            label: const Text('Returns', style: TextStyle(color: accentRed, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      ),
      body: FutureBuilder<List<Order>>(
        future: _ordersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: accentRed));
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          
          final allOrders = snapshot.data ?? [];
          final activeOrders = allOrders.where((o) => o.status != 'delivered' && o.status != 'picked_up' && o.status != 'cancelled').toList();
          final pastOrders = allOrders.where((o) => o.status == 'delivered' || o.status == 'picked_up' || o.status == 'cancelled').toList();

          return DefaultTabController(
            length: 2,
            child: Column(
              children: [
                Container(
                  color: Colors.white,
                  child: const TabBar(
                    labelColor: accentRed,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: accentRed,
                    indicatorWeight: 3,
                    labelStyle: TextStyle(fontWeight: FontWeight.bold),
                    tabs: [
                      Tab(text: "Active Orders"),
                      Tab(text: "Past Orders"),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildOrderList(activeOrders, isActive: true),
                      _buildOrderList(pastOrders, isActive: false),
                    ],
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrderList(List<Order> orders, {required bool isActive}) {
    if (orders.isEmpty) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 80),
          width: double.infinity,
          decoration: BoxDecoration(
            color: accentRed.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.topRight,
                children: [
                  const Icon(Icons.shopping_cart_outlined, size: 48, color: accentRed),
                  Container(
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.remove_circle, size: 20, color: accentRed),
                  )
                ],
              ),
              const SizedBox(height: 16),
              Text(
                "You have no ${isActive ? 'active' : 'past'} orders.",
                style: const TextStyle(color: navyDark, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        final firstItem = order.items?.isNotEmpty == true ? order.items!.first : null;
        final itemCount = order.items?.length ?? 0;
        final itemImage = firstItem?.productImage;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 70,
                        height: 70,
                        color: Colors.grey[100],
                        child: (itemImage != null && itemImage.isNotEmpty)
                            ? Image.network(itemImage, fit: BoxFit.cover)
                            : const Icon(Icons.shopping_bag, color: Colors.grey),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            firstItem?.productName ?? "B2B Order #${order.orderNumber}",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: navyDark),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            itemCount > 1 ? "$itemCount Items" : (firstItem?.quantity != null ? "${firstItem!.quantity}x ${firstItem.productName}" : ""),
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "\u20B9${order.totalAmount.toStringAsFixed(2)}",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: accentRed),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
              Divider(height: 1, color: Colors.grey[200]),
              InkWell(
                onTap: () {
                  Navigator.pushNamed(context, orderDetailsScreenRoute, arguments: order.id);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "View order details",
                        style: TextStyle(fontWeight: FontWeight.bold, color: navyDark, fontSize: 14),
                      ),
                      Text(
                        "Order date: ${DateFormat('d MMM, yyyy').format(order.createdAt)}",
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              )
            ],
          ),
        );
      },
    );
  }
}
