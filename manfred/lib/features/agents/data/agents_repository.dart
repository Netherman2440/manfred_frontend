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
      if (e.statusCode == 422) throw AgentValidationError(_parse422(e.message));
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
      if (e.statusCode == 422) throw AgentValidationError(_parse422(e.message));
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

  Map<String, String> _parse422(String rawMessage) {
    // Best-effort: return a generic map with the raw message
    return <String, String>{'error': rawMessage};
  }
}

final agentsRepositoryProvider = Provider<AgentsRepository>((ref) {
  return HttpAgentsRepository(apiClient: ref.watch(manfredApiClientProvider));
});
