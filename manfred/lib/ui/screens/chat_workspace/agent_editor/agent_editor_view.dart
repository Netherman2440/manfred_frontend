import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/agents/application/agent_editor_provider.dart';
import '../../../../features/agents/application/agents_list_provider.dart';
import '../../../../features/agents/application/selected_agent_provider.dart';
import '../../../../features/agents/data/agents_repository.dart';
import '../../../../features/agents/domain/agent_input.dart';
import '../../../theme/manfred_theme.dart';
import 'color_picker_field.dart';
import 'model_dropdown_field.dart';
import 'system_prompt_field.dart';
import 'tools_picker_field.dart';

// ---------------------------------------------------------------------------
// Local form state
// ---------------------------------------------------------------------------

class _AgentEditorState {
  _AgentEditorState({
    required this.name,
    this.color,
    required this.description,
    this.model,
    required this.selectedTools,
    required this.systemPrompt,
  });

  factory _AgentEditorState.empty() {
    return _AgentEditorState(
      name: '',
      color: null,
      description: '',
      model: null,
      selectedTools: <String>{},
      systemPrompt: '',
    );
  }

  String name;
  Color? color;
  String description;
  String? model;
  Set<String> selectedTools;
  String systemPrompt;
}

// ---------------------------------------------------------------------------
// Main widget
// ---------------------------------------------------------------------------

class AgentEditorView extends ConsumerStatefulWidget {
  const AgentEditorView({super.key});

  @override
  ConsumerState<AgentEditorView> createState() => _AgentEditorViewState();
}

class _AgentEditorViewState extends ConsumerState<AgentEditorView> {
  late _AgentEditorState _formState;
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _systemPromptController;
  late FocusNode _nameFocusNode;

  bool _loading = true;
  bool _saving = false;
  bool _nameEditingActive = false;
  String? _nameError;

  // Initial values for dirty comparison (edit mode)
  String _initialName = '';
  String _initialDescription = '';
  String _initialSystemPrompt = '';
  String? _initialModel;
  Set<String> _initialTools = {};
  Color? _initialColor;

  @override
  void initState() {
    super.initState();
    _formState = _AgentEditorState.empty();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _systemPromptController = TextEditingController();
    _nameFocusNode = FocusNode();
    _nameFocusNode.addListener(_onNameFocusChanged);
    _nameController.addListener(_updateDirtyProvider);
    _descriptionController.addListener(_updateDirtyProvider);
    _systemPromptController.addListener(_updateDirtyProvider);

    final target = ref.read(agentEditorTargetProvider);
    // New agents start with the name field open; existing agents show styled text.
    _nameEditingActive = target == null || target.isCreate;

    _loadInitialData();
  }

  void _onNameFocusChanged() {
    if (!_nameFocusNode.hasFocus && _nameEditingActive) {
      setState(() => _nameEditingActive = false);
    }
  }

  Future<void> _loadInitialData() async {
    final target = ref.read(agentEditorTargetProvider);
    if (target == null || target.isCreate) {
      setState(() => _loading = false);
      return;
    }

    try {
      final detail = await ref
          .read(agentsRepositoryProvider)
          .getAgent(target.agentName!);
      if (!mounted) return;
      setState(() {
        // Store initial values before setting controllers so listeners see correct baseline
        _initialName = detail.name;
        _initialDescription = detail.description ?? '';
        _initialSystemPrompt = detail.systemPrompt;
        _initialModel = detail.model;
        _initialTools = detail.tools.toSet();
        _initialColor = detail.color;

        _formState = _AgentEditorState(
          name: detail.name,
          color: detail.color,
          description: detail.description ?? '',
          model: detail.model,
          selectedTools: detail.tools.toSet(),
          systemPrompt: detail.systemPrompt,
        );
        _nameController.text = detail.name;
        _descriptionController.text = detail.description ?? '';
        _systemPromptController.text = detail.systemPrompt;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameFocusNode.removeListener(_onNameFocusChanged);
    _nameFocusNode.dispose();
    _nameController.removeListener(_updateDirtyProvider);
    _nameController.dispose();
    _descriptionController.removeListener(_updateDirtyProvider);
    _descriptionController.dispose();
    _systemPromptController.removeListener(_updateDirtyProvider);
    _systemPromptController.dispose();
    ref.read(agentEditorIsDirtyProvider.notifier).state = false;
    super.dispose();
  }

  bool _isDirty() {
    final target = ref.read(agentEditorTargetProvider);
    if (target == null || target.isCreate) {
      return _nameController.text.isNotEmpty ||
          _descriptionController.text.isNotEmpty ||
          _systemPromptController.text.isNotEmpty ||
          _formState.selectedTools.isNotEmpty;
    }
    return _nameController.text != _initialName ||
        _descriptionController.text != _initialDescription ||
        _systemPromptController.text != _initialSystemPrompt ||
        _formState.model != _initialModel ||
        _formState.color != _initialColor ||
        !setEquals(_formState.selectedTools, _initialTools);
  }

  void _updateDirtyProvider() {
    if (mounted) {
      ref.read(agentEditorIsDirtyProvider.notifier).state = _isDirty();
    }
  }

  bool _validate() {
    final name = _nameController.text.trim();
    final nameRegex = RegExp(r'^[a-z][a-z0-9_-]{0,47}$');
    if (!nameRegex.hasMatch(name)) {
      setState(() {
        _nameError =
            'Name must start with a letter, 1-48 chars, lowercase, letters/digits/_/-';
      });
      return false;
    }
    setState(() => _nameError = null);
    return true;
  }

  Future<void> _onSave() async {
    if (!_validate()) return;
    setState(() => _saving = true);

    final target = ref.read(agentEditorTargetProvider);

    try {
      final input = AgentInput(
        name: _nameController.text.trim(),
        color: _formState.color,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        model: _formState.model,
        tools: _formState.selectedTools.toList()..sort(),
        systemPrompt: _systemPromptController.text,
      );

      final repo = ref.read(agentsRepositoryProvider);
      if (target == null || target.isCreate) {
        await repo.createAgent(input);
      } else {
        await repo.updateAgent(target.agentName!, input);
      }

      await ref.read(agentsListProvider.notifier).refresh();
      ref.invalidate(selectedAgentDetailProvider);
      ref.invalidate(agentDetailByNameProvider(input.name));

      if (mounted) {
        ref.read(workspaceModeProvider.notifier).state =
            WorkspaceMode.conversation;
        ref.read(agentEditorTargetProvider.notifier).state = null;
      }
    } on AgentAlreadyExists {
      _showError('An agent with this name already exists.');
    } on AgentValidationError catch (e) {
      _showError('Validation error: ${e.fieldErrors.values.join(', ')}');
    } catch (e) {
      _showError('Failed to save agent: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _onCancel() async {
    if (_isDirty()) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: ManfredColors.panelAltBackground,
          title: const Text('Discard changes?'),
          content: const Text('You have unsaved changes. Discard them?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep editing'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    if (mounted) {
      ref.read(workspaceModeProvider.notifier).state =
          WorkspaceMode.conversation;
      ref.read(agentEditorTargetProvider.notifier).state = null;
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: ManfredColors.accentRed.withValues(alpha: 0.85),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final target = ref.watch(agentEditorTargetProvider);
    final isEditMode = target != null && !target.isCreate;
    final title = isEditMode ? 'Edit: ${target.agentName}' : 'New agent';

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header
          Row(
            children: <Widget>[
              InkWell(
                onTap: _onCancel,
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.arrow_back_rounded, size: 16),
                      SizedBox(width: 4),
                      Text('Back'),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Text(title, style: textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 20),

          // Form content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(right: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Name + color row
                  _NameColorRow(
                    nameController: _nameController,
                    nameFocusNode: _nameFocusNode,
                    nameEditingActive: _nameEditingActive,
                    nameError: _nameError,
                    isEditMode: isEditMode,
                    selectedColor: _formState.color,
                    onEditTap: () => setState(() {
                      _nameEditingActive = true;
                      _nameFocusNode.requestFocus();
                    }),
                    onNameChanged: (_) => setState(() {
                      _formState.name = _nameController.text;
                      _nameError = null;
                    }),
                    onColorChanged: (c) {
                      setState(() => _formState.color = c);
                      _updateDirtyProvider();
                    },
                  ),

                  if (_nameError != null) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(
                      _nameError!,
                      style: textTheme.labelSmall?.copyWith(
                        color: ManfredColors.accentRed,
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Description
                  Text('Description', style: textTheme.labelMedium),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _descriptionController,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      hintText: 'Short description of this agent',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Model
                  Text('Model', style: textTheme.labelMedium),
                  const SizedBox(height: 6),
                  ModelDropdownField(
                    selectedModelId: _formState.model,
                    onChanged: (modelId) {
                      setState(() => _formState.model = modelId);
                      _updateDirtyProvider();
                    },
                  ),
                  const SizedBox(height: 16),

                  // Tools
                  Text('Tools', style: textTheme.labelMedium),
                  const SizedBox(height: 8),
                  ToolsPickerField(
                    selectedTools: _formState.selectedTools,
                    onChanged: (tools) {
                      setState(() => _formState.selectedTools = tools);
                      _updateDirtyProvider();
                    },
                  ),
                  const SizedBox(height: 16),

                  // System prompt
                  Text('System prompt', style: textTheme.labelMedium),
                  const SizedBox(height: 6),
                  SystemPromptField(controller: _systemPromptController),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              TextButton(
                onPressed: _saving ? null : _onCancel,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _saving ? null : _onSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ManfredColors.accentBlue,
                ),
                child: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Name + color inline row
// ---------------------------------------------------------------------------

class _NameColorRow extends StatelessWidget {
  const _NameColorRow({
    required this.nameController,
    required this.nameFocusNode,
    required this.nameEditingActive,
    required this.nameError,
    required this.isEditMode,
    required this.selectedColor,
    required this.onEditTap,
    required this.onNameChanged,
    required this.onColorChanged,
  });

  final TextEditingController nameController;
  final FocusNode nameFocusNode;
  final bool nameEditingActive;
  final String? nameError;
  final bool isEditMode;
  final Color? selectedColor;
  final VoidCallback onEditTap;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<Color> onColorChanged;

  Color get _displayColor => selectedColor ?? ManfredColors.panelAltBackground;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: nameEditingActive
              ? TextField(
                  controller: nameController,
                  focusNode: nameFocusNode,
                  enabled: !isEditMode,
                  onChanged: onNameChanged,
                  decoration: InputDecoration(
                    hintText: 'my-agent',
                    errorText: nameError,
                  ),
                )
              : GestureDetector(
                  onTap: isEditMode ? null : onEditTap,
                  child: Row(
                    children: <Widget>[
                      // Mirror the color square width so text is centered
                      const SizedBox(width: 40 + 12),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                nameController.text.isEmpty
                                    ? 'my-agent'
                                    : nameController.text,
                                style: textTheme.titleMedium?.copyWith(
                                  color:
                                      selectedColor ??
                                      ManfredColors.textSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                            if (!isEditMode) ...<Widget>[
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.edit_outlined,
                                size: 16,
                                color: ManfredColors.textSecondary,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: () => _showColorPicker(context),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _displayColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ManfredColors.borderStrong),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showColorPicker(BuildContext context) async {
    final picked = await showDialog<Color>(
      context: context,
      builder: (ctx) => ColorPaletteDialog(
        selectedColor: selectedColor,
        onColorSelected: (c) => Navigator.pop(ctx, c),
      ),
    );
    if (picked != null) {
      onColorChanged(picked);
    }
  }
}

