class AgentEditorTarget {
  const AgentEditorTarget.create() : agentName = null;
  const AgentEditorTarget.edit(String name)
      : assert(name != '', 'edit target name must not be empty'),
        agentName = name;

  final String? agentName;

  bool get isCreate => agentName == null;
}
