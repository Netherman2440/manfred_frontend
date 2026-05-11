import '../domain/model_summary.dart';

class ModelSummaryDto {
  const ModelSummaryDto({
    required this.id,
    this.name,
    this.contextLength,
    this.pricingPromptPer1k,
    this.pricingCompletionPer1k,
  });

  factory ModelSummaryDto.fromJson(Map<String, dynamic> json) {
    return ModelSummaryDto(
      id: json['id'] as String,
      name: json['name'] as String?,
      contextLength: json['context_length'] as int?,
      pricingPromptPer1k: (json['pricing_prompt_per_1k'] as num?)?.toDouble(),
      pricingCompletionPer1k:
          (json['pricing_completion_per_1k'] as num?)?.toDouble(),
    );
  }

  final String id;
  final String? name;
  final int? contextLength;
  final double? pricingPromptPer1k;
  final double? pricingCompletionPer1k;

  ModelSummary toDomain() {
    return ModelSummary(
      id: id,
      displayName: (name != null && name!.isNotEmpty) ? name! : id,
      contextLength: contextLength,
      pricingPromptPer1k: pricingPromptPer1k,
      pricingCompletionPer1k: pricingCompletionPer1k,
    );
  }
}

class ModelsListResponseDto {
  const ModelsListResponseDto({required this.data});

  factory ModelsListResponseDto.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    if (rawData is! List) {
      throw FormatException(
        'Expected "data" to be a List, got ${rawData.runtimeType}',
      );
    }
    return ModelsListResponseDto(
      data: rawData
          .map((e) => ModelSummaryDto.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  final List<ModelSummaryDto> data;
}
