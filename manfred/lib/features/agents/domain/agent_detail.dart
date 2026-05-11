import 'package:flutter/material.dart';

class AgentDetail {
  const AgentDetail({
    required this.name,
    this.color,
    this.description,
    this.model,
    required this.systemPrompt,
    required this.tools,
  });

  final String name;
  final Color? color;
  final String? description;
  final String? model;
  final String systemPrompt;
  final List<String> tools;

  AgentDetail copyWith({
    String? name,
    Color? color,
    bool clearColor = false,
    String? description,
    bool clearDescription = false,
    String? model,
    bool clearModel = false,
    String? systemPrompt,
    List<String>? tools,
  }) {
    return AgentDetail(
      name: name ?? this.name,
      color: clearColor ? null : color ?? this.color,
      description: clearDescription ? null : description ?? this.description,
      model: clearModel ? null : model ?? this.model,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      tools: tools ?? this.tools,
    );
  }
}
