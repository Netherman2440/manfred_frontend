class ComposerState {
  const ComposerState({
    required this.draft,
    required this.isSending,
    required this.isStreaming,
    required this.isStopping,
    required this.errorMessage,
    required this.pendingUserMessage,
    required this.streamingText,
    required this.activeSessionId,
    required this.activeAgentId,
    required this.activeAgentName,
  });

  const ComposerState.initial()
    : draft = '',
      isSending = false,
      isStreaming = false,
      isStopping = false,
      errorMessage = null,
      pendingUserMessage = null,
      streamingText = '',
      activeSessionId = null,
      activeAgentId = null,
      activeAgentName = null;

  final String draft;
  final bool isSending;
  final bool isStreaming;
  final bool isStopping;
  final String? errorMessage;
  final String? pendingUserMessage;
  final String streamingText;
  final String? activeSessionId;
  final String? activeAgentId;
  final String? activeAgentName;

  bool get isBusy => isSending || isStreaming || isStopping;

  bool get canStop => isStreaming && activeSessionId != null && !isStopping;

  ComposerState copyWith({
    String? draft,
    bool? isSending,
    bool? isStreaming,
    bool? isStopping,
    String? errorMessage,
    String? pendingUserMessage,
    String? streamingText,
    String? activeSessionId,
    String? activeAgentId,
    String? activeAgentName,
    bool clearErrorMessage = false,
    bool clearPendingUserMessage = false,
    bool clearStreamingText = false,
    bool clearActiveRun = false,
  }) {
    return ComposerState(
      draft: draft ?? this.draft,
      isSending: isSending ?? this.isSending,
      isStreaming: isStreaming ?? this.isStreaming,
      isStopping: isStopping ?? this.isStopping,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
      pendingUserMessage: clearPendingUserMessage
          ? null
          : pendingUserMessage ?? this.pendingUserMessage,
      streamingText: clearStreamingText
          ? ''
          : streamingText ?? this.streamingText,
      activeSessionId: clearActiveRun
          ? null
          : activeSessionId ?? this.activeSessionId,
      activeAgentId: clearActiveRun
          ? null
          : activeAgentId ?? this.activeAgentId,
      activeAgentName: clearActiveRun
          ? null
          : activeAgentName ?? this.activeAgentName,
    );
  }
}
