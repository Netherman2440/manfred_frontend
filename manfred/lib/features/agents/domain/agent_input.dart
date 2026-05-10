import 'package:flutter/material.dart';

class AgentInput {
  const AgentInput({
    required this.name,
    this.color,
    this.description,
    this.model,
    required this.tools,
    required this.systemPrompt,
  });

  final String name;
  final Color? color;
  final String? description;
  final String? model;
  final List<String> tools;
  final String systemPrompt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      if (color != null) 'color': _formatHexColor(color),
      if (description != null && description!.isNotEmpty)
        'description': description,
      if (model != null) 'model': model,
      'tools': tools,
      'system_prompt': systemPrompt,
    };
  }

  static String? _formatHexColor(Color? color) {
    if (color == null) return null;
    final r = color.r.round().toRadixString(16).padLeft(2, '0');
    final g = color.g.round().toRadixString(16).padLeft(2, '0');
    final b = color.b.round().toRadixString(16).padLeft(2, '0');
    return '#$r$g$b'.toUpperCase();
  }
}
