import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/manfred_api_client.dart';
import '../../user/application/user_context_provider.dart';
import '../domain/model_summary.dart';
import 'models_dto.dart';

abstract class ModelsRepository {
  Future<List<ModelSummary>> listModels();
}

class HttpModelsRepository implements ModelsRepository {
  const HttpModelsRepository({required ManfredApiClient apiClient})
      : _apiClient = apiClient;

  final ManfredApiClient _apiClient;

  @override
  Future<List<ModelSummary>> listModels() async {
    final payload = await _apiClient.getJson('/models');
    final all = ModelsListResponseDto.fromJson(payload)
        .data
        .map((dto) => dto.toDomain());
    // The backend may return duplicate ids when the same model is exposed
    // by multiple providers; keep the first occurrence so consumers like
    // _ModelPickerDialog never see duplicate keys.
    final uniqueById = <String, ModelSummary>{};
    for (final model in all) {
      uniqueById.putIfAbsent(model.id, () => model);
    }
    return uniqueById.values.toList(growable: false);
  }
}

final modelsRepositoryProvider = Provider<ModelsRepository>((ref) {
  return HttpModelsRepository(apiClient: ref.watch(manfredApiClientProvider));
});
