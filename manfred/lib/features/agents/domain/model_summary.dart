class ModelSummary {
  const ModelSummary({
    required this.id,
    required this.displayName,
    this.contextLength,
    this.pricingPromptPer1k,
    this.pricingCompletionPer1k,
  });

  final String id;
  final String displayName;
  final int? contextLength;
  final double? pricingPromptPer1k;
  final double? pricingCompletionPer1k;
}
