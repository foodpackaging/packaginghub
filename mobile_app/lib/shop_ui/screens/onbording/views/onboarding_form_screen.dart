import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:b2b_store/shared/services/api_service.dart';
import 'package:b2b_store/shared/providers/auth_provider.dart';
import 'package:b2b_store/shop_ui/constants.dart';
import 'package:b2b_store/shop_ui/route/route_constants.dart';

class OnboardingFormScreen extends ConsumerStatefulWidget {
  const OnboardingFormScreen({super.key});

  @override
  ConsumerState<OnboardingFormScreen> createState() => _OnboardingFormScreenState();
}

class _OnboardingFormScreenState extends ConsumerState<OnboardingFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();

  String _firstName = '';
  String _lastName = '';
  String _phone = '';
  String _workEmail = '';
  String _companyType = 'Restaurant';
  String _role = 'Owner';
  String _roleDescription = '';
  String _gstNumber = '';
  bool _isLoading = false;

  void _onNext() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() => _isLoading = true);

      try {
        // Save Step 1 data but DON'T mark as complete yet
        await _apiService.updateProfile({
          'first_name': _firstName,
          'last_name': _lastName,
          'phone': _phone,
          'work_email': _workEmail,
          'company_type': _companyType,
          'role': _role,
          'role_description': _role == 'Other' ? _roleDescription : null,
          'gst_number': _gstNumber,
        });

        if (mounted) {
          // Go to Step 2: Address
          Navigator.pushNamed(context, onboardingAddressScreenRoute);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save step 1: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Account Setup (1/2)"),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            onPressed: () async {
              await ref.read(userProfileProvider.notifier).logout();
            },
            icon: const Icon(Icons.logout),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(defaultPadding),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Business Details",
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                "Step 1: Provide your basic business information.",
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: defaultPadding * 2),
              
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(labelText: "First Name", hintText: "John"),
                      validator: (value) => value!.isEmpty ? "Required" : null,
                      onSaved: (value) => _firstName = value!,
                    ),
                  ),
                  const SizedBox(width: defaultPadding),
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(labelText: "Last Name", hintText: "Doe"),
                      validator: (value) => value!.isEmpty ? "Required" : null,
                      onSaved: (value) => _lastName = value!,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: defaultPadding),

              TextFormField(
                decoration: const InputDecoration(
                  labelText: "Phone Number", 
                  hintText: "9876543210",
                  prefixIcon: Icon(Icons.phone_android, size: 20),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) => value!.length < 10 ? "Enter valid phone number" : null,
                onSaved: (value) => _phone = value!,
              ),
              const SizedBox(height: defaultPadding),

              TextFormField(
                decoration: const InputDecoration(
                  labelText: "Work Email", 
                  hintText: "orders@business.com",
                  prefixIcon: Icon(Icons.work_outline, size: 20),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) => value!.isEmpty ? "Required" : null,
                onSaved: (value) => _workEmail = value!,
              ),
              const SizedBox(height: defaultPadding),

              DropdownButtonFormField<String>(
                value: _companyType,
                decoration: const InputDecoration(
                  labelText: "Company Type",
                  prefixIcon: Icon(Icons.business, size: 20),
                ),
                items: const [
                  DropdownMenuItem(value: 'Factory', child: Text("Factory")),
                  DropdownMenuItem(value: 'Restaurant', child: Text("Restaurant")),
                  DropdownMenuItem(value: 'Hotel', child: Text("Hotel")),
                ],
                onChanged: (value) => setState(() => _companyType = value!),
              ),
              const SizedBox(height: defaultPadding),

              DropdownButtonFormField<String>(
                value: _role,
                decoration: const InputDecoration(
                  labelText: "Your Role",
                  prefixIcon: Icon(Icons.person_outline, size: 20),
                ),
                items: const [
                  DropdownMenuItem(value: 'Owner', child: Text("Owner")),
                  DropdownMenuItem(value: 'Manager', child: Text("Manager")),
                  DropdownMenuItem(value: 'Staff', child: Text("Staff")),
                  DropdownMenuItem(value: 'Other', child: Text("Other")),
                ],
                onChanged: (value) => setState(() => _role = value!),
              ),
              
              if (_role == 'Other') ...[
                const SizedBox(height: defaultPadding),
                TextFormField(
                  decoration: const InputDecoration(labelText: "Please specify your role"),
                  validator: (value) => (_role == 'Other' && value!.isEmpty) ? "Please specify" : null,
                  onSaved: (value) => _roleDescription = value!,
                ),
              ],
              
              const SizedBox(height: defaultPadding),

              TextFormField(
                decoration: const InputDecoration(
                  labelText: "GST Number", 
                  hintText: "22AAAAA0000A1Z5",
                  prefixIcon: Icon(Icons.receipt_long, size: 20),
                ),
                validator: (value) => value!.isEmpty ? "Enter GST number" : null,
                onSaved: (value) => _gstNumber = value!,
              ),
              const SizedBox(height: defaultPadding * 3),

              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _onNext,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("Next: Business Address", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
              const SizedBox(height: defaultPadding),
            ],
          ),
        ),
      ),
    );
  }
}
