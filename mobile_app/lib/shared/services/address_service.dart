import 'package:b2b_store/core/services/api_client.dart';
import 'package:b2b_store/shared/models/address.dart';

/// CRUD for the business's saved delivery addresses.
///
/// Mutations that can change which address is default return the full refreshed
/// list, so callers never have to reason about the single-default invariant
/// themselves — they just replace their local list with what the server returns.
class AddressService {
  final ApiClient _client = ApiClient.instance;

  List<Address> _parseList(dynamic response) =>
      (((response as Map<String, dynamic>)['addresses'] as List?) ?? [])
          .map((json) => Address.fromJson(json as Map<String, dynamic>))
          .toList();

  Future<List<Address>> list() async => _parseList(await _client.get('/addresses'));

  Future<Address> create(Address address, {bool makeDefault = false}) async {
    final response = await _client.post('/addresses', body: {
      ...address.toRequestBody(),
      if (makeDefault) 'is_default': true,
    });
    return Address.fromJson(response['address'] as Map<String, dynamic>);
  }

  Future<Address> update(String id, Address address, {bool makeDefault = false}) async {
    final response = await _client.patch('/addresses/$id', body: {
      ...address.toRequestBody(),
      if (makeDefault) 'is_default': true,
    });
    return Address.fromJson(response['address'] as Map<String, dynamic>);
  }

  Future<List<Address>> setDefault(String id) async =>
      _parseList(await _client.post('/addresses/$id/default'));

  Future<List<Address>> delete(String id) async =>
      _parseList(await _client.delete('/addresses/$id'));
}
