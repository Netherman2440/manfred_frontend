/// Result of a synchronous call to `POST /chat/sessions/{id}/summarize`.
///
/// The backend has a single endpoint but multiple shapes: success +
/// observation preview, locked, below-threshold, error, no-unobserved
/// (204), missing session (404), feature disabled (503) and transport
/// failures. We flatten all of these into one sealed result so the
/// presentation layer can pattern-match without re-decoding the body.
sealed class SummarizeResult {
  const SummarizeResult();
}

/// Observer ran and persisted new observations. `preview` is up to 200
/// characters of the newly-saved memory file.
final class SummarizeSuccess extends SummarizeResult {
  const SummarizeSuccess(this.preview);

  final String preview;
}

/// Another observer is already holding the lock for the
/// (user, agent_name) pair. Caller should retry shortly.
final class SummarizeLocked extends SummarizeResult {
  const SummarizeLocked();
}

/// Endpoint returned `below_threshold` (not enough new tokens to fold
/// into long-term memory). `detail` is the backend's free-form message,
/// typically of shape `<n> < <threshold>`.
final class SummarizeBelowThreshold extends SummarizeResult {
  const SummarizeBelowThreshold(this.detail);

  final String? detail;
}

/// Observer crashed mid-run. `detail` is the backend-supplied error
/// message.
final class SummarizeError extends SummarizeResult {
  const SummarizeError(this.detail);

  final String? detail;
}

/// 204 No Content — there were no unobserved items to fold. UI should
/// stay silent (no SnackBar).
final class SummarizeNoUnobserved extends SummarizeResult {
  const SummarizeNoUnobserved();
}

/// 404 Not Found — session does not exist or is not owned by the
/// current user.
final class SummarizeNotFound extends SummarizeResult {
  const SummarizeNotFound();
}

/// 503 Service Unavailable — `OBSERVATIONAL_MEMORY_ENABLED=false` on
/// the backend. Caller should sticky-disable the command for the
/// current session.
final class SummarizeFeatureDisabled extends SummarizeResult {
  const SummarizeFeatureDisabled();
}

/// Network failure, HTTP timeout, unexpected status code, or invalid
/// JSON body. `message` is the diagnostic string for logging.
final class SummarizeTransportError extends SummarizeResult {
  const SummarizeTransportError(this.message);

  final String? message;
}
