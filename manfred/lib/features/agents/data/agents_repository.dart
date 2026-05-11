import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../core/api/manfred_api_client.dart';
import '../../sessions/data/sessions_dto.dart' show SessionsListResponseDto;
import '../../sessions/domain/session_list_entry.dart';
import '../../user/application/user_context_provider.dart';
import '../domain/agent_detail.dart';
import '../domain/agent_input.dart';
import '../domain/agent_summary.dart';
import 'agents_dto.dart';

// ---------------------------------------------------------------------------
// Domain exceptions
// ---------------------------------------------------------------------------

class AgentAlreadyExists implements Exception {
  const AgentAlreadyExists();
}

class AgentValidationError implements Exception {
  const AgentValidationError(this.fieldErrors);

  final Map<String, String> fieldErrors;
}

class AgentNotFound implements Exception {
  const AgentNotFound(this.name);

  final String name;
}

// ---------------------------------------------------------------------------
// Abstract + implementation
// ---------------------------------------------------------------------------

abstract class AgentsRepository {
  Future<List<AgentSummary>> listAgents();
  Future<AgentDetail> getAgent(String name);
  Future<AgentDetail> createAgent(AgentInput input);
  Future<AgentDetail> updateAgent(String name, AgentInput input);
  Future<List<SessionListEntry>> getAgentSessions(String name);
  Future<void> deleteAgent(String name);
}

class HttpAgentsRepository implements AgentsRepository {
  HttpAgentsRepository({required ManfredApiClient apiClient})
      : _apiClient = apiClient;

  final ManfredApiClient _apiClient;

  @override
  Future<List<AgentSummary>> listAgents() async {
    final payload = await _apiClient.getJson('/agents');
    return AgentsListResponseDto.fromJson(payload)
        .data
        .map((dto) => dto.toDomain())
        .toList(growable: false);
  }

  @override
  Future<AgentDetail> getAgent(String name) async {
    try {
      final payload = await _apiClient.getJson('/agents/$name');
      return AgentDetailResponseDto.fromJson(payload).data.toDomain();
    } on ApiError catch (e) {
      if (e.statusCode == 404) throw AgentNotFound(name);
      rethrow;
    }
  }

  @override
  Future<AgentDetail> createAgent(AgentInput input) async {
    try {
      final payload = await _apiClient.postJson(
        '/agents',
        body: input.toJson(),
      );
      return AgentDetailResponseDto.fromJson(payload).data.toDomain();
    } on ApiError catch (e) {
      if (e.statusCode == 409) throw const AgentAlreadyExists();
      if (e.statusCode == 422) throw AgentValidationError(_parse422(e));
      rethrow;
    }
  }

  @override
  Future<AgentDetail> updateAgent(String name, AgentInput input) async {
    try {
      final payload = await _apiClient.putJson(
        '/agents/$name',
        body: input.toJson(),
      );
      return AgentDetailResponseDto.fromJson(payload).data.toDomain();
    } on ApiError catch (e) {
      if (e.statusCode == 404) throw AgentNotFound(name);
      if (e.statusCode == 422) throw AgentValidationError(_parse422(e));
      rethrow;
    }
  }

  @override
  Future<List<SessionListEntry>> getAgentSessions(String name) async {
    final payload = await _apiClient.getJson('/agents/$name/sessions');
    return SessionsListResponseDto.fromJson(payload)
        .data
        .map((dto) => dto.toDomain())
        .toList(growable: false);
  }

  @override
  Future<void> deleteAgent(String name) async {
    try {
      await _apiClient.deleteRequest('/agents/$name');
    } on ApiError catch (e) {
      if (e.statusCode == 404) throw AgentNotFound(name);
      rethrow;
    }
  }

  Map<String, String> _parse422(ApiError error) {
    final details = error.details;
    if (details is Map<String, dynamic>) {
      // FastAPI shape: {"detail": [{"loc": ["body", "name"], "msg": "..."}]}
      final detail = details['detail'];
      if (detail is List) {
        final fieldErrors = <String, String>{};
        for (final item in detail) {
          if (item is! Map) continue;
          final loc = item['loc'];
          final msg = item['msg'];
          if (loc is List && loc.isNotEmpty && msg is String) {
            fieldErrors[loc.last.toString()] = msg;
          }
        }
        if (fieldErrors.isNotEmpty) return fieldErrors;
      }
      // Flat map shape: {"name": "required", "color": "invalid hex"}
      final fieldErrors = <String, String>{};
      details.forEach((key, value) {
        if (value is String) fieldErrors[key] = value;
      });
      if (fieldErrors.isNotEmpty) return fieldErrors;
    }
    return <String, String>{'error': error.message};
  }
}

final agentsRepositoryProvider = Provider<AgentsRepository>((ref) {
  return HttpAgentsRepository(apiClient: ref.watch(manfredApiClientProvider));
});
