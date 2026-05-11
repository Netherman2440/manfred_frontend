enum ToolKind { function, webSearch, mcp }

class ToolSummary {
  const ToolSummary({
    required this.name,
    this.description,
    required this.kind,
  });

  final String name;
  final String? description;
  final ToolKind kind;
}
