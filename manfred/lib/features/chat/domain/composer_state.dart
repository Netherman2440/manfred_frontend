class ComposerState {
  const ComposerState({
    required this.draft,
    required this.isSending,
    required this.errorMessage,
  });

  const ComposerState.initial()
    : draft = '',
      isSending = false,
      errorMessage = null;

  final String draft;
  final bool isSending;
  final String? errorMessage;

  ComposerState copyWith({
    String? draft,
    bool? isSending,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return ComposerState(
      draft: draft ?? this.draft,
      isSending: isSending ?? this.isSending,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
    );
  }
}
