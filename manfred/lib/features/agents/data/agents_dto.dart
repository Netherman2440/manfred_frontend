import 'package:flutter/material.dart';

import '../domain/agent_detail.dart';
import '../domain/agent_summary.dart';

// ---------------------------------------------------------------------------
// Color helpers
// ---------------------------------------------------------------------------

Color? parseHexColor(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  final cleaned = hex.replaceFirst('#', '');
  if (cleaned.length != 6) return null;
  final value = int.tryParse('FF$cleaned', radix: 16);
  if (value == null) return null;
  return Color(value);
}

String? formatHexColor(Color? color) {
  if (color == null) return null;
  final r = color.r.round().toRadixString(16).padLeft(2, '0');
  final g = color.g.round().toRadixString(16).padLeft(2, '0');
  final b = color.b.round().toRadixString(16).padLeft(2, '0');
  return '#$r$g$b'.toUpperCase();
}

// ---------------------------------------------------------------------------
// Agent summary DTO
// ---------------------------------------------------------------------------

class AgentSummaryDto {
  const AgentSummaryDto({
    required this.name,
    this.color,
    this.description,
  });

  factory AgentSummaryDto.fromJson(Map<String, dynamic> json) {
    return AgentSummaryDto(
      name: json['name'] as String,
      color: json['color'] as String?,
      description: json['description'] as String?,
    );
  }

  final String name;
  final String? color;
  final String? description;

  AgentSummary toDomain() {
    return AgentSummary(
      name: name,
      color: parseHexColor(color),
      description: description,
    );
  }
}

// ---------------------------------------------------------------------------
// Agent detail DTO
// ---------------------------------------------------------------------------

class AgentDetailDto {
  const AgentDetailDto({
    required this.name,
    this.color,
    this.description,
    this.model,
    required this.systemPrompt,
    required this.tools,
  });

  factory AgentDetailDto.fromJson(Map<String, dynamic> json) {
    final rawTools = json['tools'];
    final tools = rawTools is List
        ? rawTools.map((t) => t.toString()).toList(growable: false)
        : const <String>[];
    return AgentDetailDto(
      name: json['name'] as String,
      color: json['color'] as String?,
      description: json['description'] as String?,
      model: json['model'] as String?,
      systemPrompt: (json['system_prompt'] as String?) ?? '',
      tools: tools,
    );
  }

  final String name;
  final String? color;
  final String? description;
  final String? model;
  final String systemPrompt;
  final List<String> tools;

  AgentDetail toDomain() {
    return AgentDetail(
      name: name,
      color: parseHexColor(color),
      description: description,
      model: model,
      systemPrompt: systemPrompt,
      tools: tools,
    );
  }
}

// ---------------------------------------------------------------------------
// Response wrappers
// ---------------------------------------------------------------------------

class AgentsListResponseDto {
  const AgentsListResponseDto({required this.data});

  factory AgentsListResponseDto.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'] as List<dynamic>;
    return AgentsListResponseDto(
      data: rawData
          .map((e) => AgentSummaryDto.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  final List<AgentSummaryDto> data;
}

class AgentDetailResponseDto {
  const AgentDetailResponseDto({required this.data});

  factory AgentDetailResponseDto.fromJson(Map<String, dynamic> json) {
    return AgentDetailResponseDto(
      data: AgentDetailDto.fromJson(json['data'] as Map<String, dynamic>),
    );
  }

  final AgentDetailDto data;
}
