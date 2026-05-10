import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/manfred_api_client.dart';
import '../../user/application/user_context_provider.dart';
import '../domain/tool_summary.dart';
import 'tools_dto.dart';

abstract class ToolsRepository {
  Future<List<ToolSummary>> listTools();
}

class HttpToolsRepository implements ToolsRepository {
  const HttpToolsRepository({required ManfredApiClient apiClient})
      : _apiClient = apiClient;

  final ManfredApiClient _apiClient;

  @override
  Future<List<ToolSummary>> listTools() async {
    final payload = await _apiClient.getJson('/tools');
    return ToolsListResponseDto.fromJson(payload)
        .data
        .map((dto) => dto.toDomain())
        .toList(growable: false);
  }
}

final toolsRepositoryProvider = Provider<ToolsRepository>((ref) {
  return HttpToolsRepository(apiClient: ref.watch(manfredApiClientProvider));
});
