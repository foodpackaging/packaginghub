import 'package:flutter/material.dart';
import 'package:b2b_store/shop_ui/constants.dart';
import 'package:b2b_store/shop_ui/controllers/cart_controller.dart';
import 'package:b2b_store/shared/services/api_service.dart';
import 'package:provider/provider.dart';

class AddressDetailsScreen extends StatefulWidget {
  const AddressDetailsScreen({super.key});

  @override
  State<AddressDetailsScreen> createState() => _AddressDetailsScreenState();
}

class _AddressDetailsScreenState extends State<AddressDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _addressController;
  final TextEditingController _houseController = TextEditingController();
  final TextEditingController _landmarkController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  final ApiService _apiService = ApiService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final cart = context.read<CartController>();
    _addressController = TextEditingController(text: cart.customDeliveryAddress ?? '');
    _houseController.text = cart.customHouseNumber ?? '';
    _landmarkController.text = cart.customLandmark ?? '';
    _phoneController.text = cart.customPhone ?? '';
    
    _loadProfilePhone();
  }

  Future<void> _loadProfilePhone() async {
    if (_phoneController.text.isEmpty) {
      final profile = await _apiService.getProfile();
      if (profile?.phone != null && mounted) {
        setState(() {
          _phoneController.text = profile!.phone!;
        });
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _addressController.dispose();
    _houseController.dispose();
    _landmarkController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _onSave() {
    if (_formKey.currentState!.validate()) {
      final cart = context.read<CartController>();
      cart.customDeliveryAddress = _addressController.text;
      cart.customHouseNumber = _houseController.text;
      cart.customLandmark = _landmarkController.text;
      cart.customPhone = _phoneController.text;
      
      // Pop back to Checkout Screen
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartController>();
    
    return Scaffold(
      appBar: AppBar(title: const Text('Enter Address Details')),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(defaultPadding),
              children: [
                if (cart.customLatitude != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: defaultPadding),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: successColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: successColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: successColor),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('GPS Location Confirmed', style: TextStyle(fontWeight: FontWeight.bold, color: successColor)),
                              Text('${cart.customLatitude!.toStringAsFixed(5)}, ${cart.customLongitude!.toStringAsFixed(5)}', style: const TextStyle(fontSize: 12, color: successColor)),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),

                const Text('Complete your address details to help our delivery executive reach you easily.', style: TextStyle(color: mutedText)),
                const SizedBox(height: defaultPadding * 1.5),

                TextFormField(
                  controller: _houseController,
                  decoration: const InputDecoration(
                    labelText: 'House / Flat / Block No. *',
                    hintText: 'e.g. Flat 302, Building A',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: defaultPadding),

                TextFormField(
                  controller: _addressController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Street / Area Name *',
                    hintText: 'e.g. Main Street, Sector 4',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: defaultPadding),

                TextFormField(
                  controller: _landmarkController,
                  decoration: const InputDecoration(
                    labelText: 'Nearby Landmark *',
                    hintText: 'e.g. Opposite City Mall',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: defaultPadding),

                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Receiver Phone Number *',
                    hintText: 'For delivery updates',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: defaultPadding * 2),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _onSave,
                    child: const Text('Save Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                )
              ],
            ),
          ),
    );
  }
}
