import 'package:flutter/material.dart';

class AgentSummary {
  const AgentSummary({
    required this.name,
    this.color,
    this.description,
  });

  final String name;
  final Color? color;
  final String? description;
}
