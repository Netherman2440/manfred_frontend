import '../domain/tool_summary.dart';

class ToolSummaryDto {
  const ToolSummaryDto({
    required this.name,
    this.description,
    required this.type,
  });

  factory ToolSummaryDto.fromJson(Map<String, dynamic> json) {
    return ToolSummaryDto(
      name: json['name'] as String,
      description: json['description'] as String?,
      type: (json['type'] as String?) ?? 'function',
    );
  }

  final String name;
  final String? description;
  final String type;

  ToolSummary toDomain() {
    return ToolSummary(
      name: name,
      description: description,
      kind: _parseKind(type),
    );
  }

  static ToolKind _parseKind(String type) {
    switch (type) {
      case 'web_search':
        return ToolKind.webSearch;
      case 'mcp':
        return ToolKind.mcp;
      default:
        return ToolKind.function;
    }
  }
}

class ToolsListResponseDto {
  const ToolsListResponseDto({required this.data});

  factory ToolsListResponseDto.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'] as List<dynamic>;
    return ToolsListResponseDto(
      data: rawData
          .map((e) => ToolSummaryDto.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  final List<ToolSummaryDto> data;
}
