import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/api/manfred_api_client.dart';

class UserContext {
  const UserContext({required this.userId, required this.apiBaseUrl});

  final String userId;
  final String apiBaseUrl;
}

final userContextProvider = Provider<UserContext>((ref) {
  return const UserContext(
    userId: 'default-user',
    apiBaseUrl: String.fromEnvironment(
      'MANFRED_API_BASE_URL',
      defaultValue: 'http://127.0.0.1:3000/api/v1',
    ),
  );
});

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final manfredApiClientProvider = Provider<ManfredApiClient>((ref) {
  final userContext = ref.watch(userContextProvider);
  return ManfredApiClient(
    client: ref.watch(httpClientProvider),
    baseUrl: userContext.apiBaseUrl,
  );
});
