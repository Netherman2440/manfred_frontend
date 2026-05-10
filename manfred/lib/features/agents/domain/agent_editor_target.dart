class AgentEditorTarget {
  const AgentEditorTarget.create() : agentName = null;
  const AgentEditorTarget.edit(this.agentName);

  final String? agentName;

  bool get isCreate => agentName == null;
}
