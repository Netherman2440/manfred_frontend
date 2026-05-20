import 'package:flutter/material.dart';

import '../../../features/chat/application/summarize_snackbar_emitter.dart';
import '../../../features/chat/domain/summarize_result.dart';
import '../../theme/manfred_fonts.dart';
import '../../theme/manfred_theme.dart';

/// Production [SummarizeSnackbarEmitter] backed by a top-level
/// [GlobalKey<ScaffoldMessengerState>]. Wired in `main.dart`.
class ScaffoldMessengerSummarizeEmitter implements SummarizeSnackbarEmitter {
  ScaffoldMessengerSummarizeEmitter({required this.scaffoldMessengerKey});

  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey;

  @override
  void show(SummarizeResult result, {VoidCallback? onRetry}) {
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) {
      return;
    }

    // No-op for SummarizeNoUnobserved — controller already suppresses it,
    // this is a defensive guard if the contract changes.
    if (result is SummarizeNoUnobserved) {
      return;
    }

    final snackBar = _buildSnackBar(result, onRetry: onRetry);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }

  SnackBar _buildSnackBar(SummarizeResult result, {VoidCallback? onRetry}) {
    final variant = _variantFor(result);
    final isError = variant.severity == _Severity.error;
    return SnackBar(
      backgroundColor: ManfredColors.panelOverlay,
      behavior: SnackBarBehavior.floating,
      padding: EdgeInsets.zero,
      duration: isError
          ? const Duration(seconds: 8)
          : const Duration(seconds: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ManfredShapes.inputRadius),
        side: const BorderSide(color: ManfredColors.borderSubtle),
      ),
      content: _SummarizeSnackBarContent(
        variant: variant,
        onRetry: variant.allowsRetry ? onRetry : null,
      ),
    );
  }

  _SnackBarVariant _variantFor(SummarizeResult result) {
    switch (result) {
      case SummarizeSuccess(:final preview):
        return _SnackBarVariant(
          color: ManfredColors.accentGreen,
          severity: _Severity.success,
          tag: 'summarized',
          headline: 'Observations saved',
          secondary:
              'Manfred folded the latest context into long-term memory.',
          preview: preview,
        );
      case SummarizeLocked():
        return const _SnackBarVariant(
          color: ManfredColors.accentAmber,
          severity: _Severity.warning,
          tag: 'already running',
          headline: 'Another observer has the lock',
          secondary:
              'A summary is in progress for this agent. Try again in a minute.',
        );
      case SummarizeBelowThreshold(:final detail):
        return _SnackBarVariant(
          color: ManfredColors.accentAmber,
          severity: _Severity.warning,
          tag: 'not enough yet',
          headline: 'Not enough new context to summarize.',
          detail: (detail != null && detail.isNotEmpty) ? detail : null,
        );
      case SummarizeError(:final detail):
        return _SnackBarVariant(
          color: ManfredColors.accentRed,
          severity: _Severity.error,
          tag: 'failed',
          headline: "Couldn't save observations",
          secondary:
              'The observer ran into an error. Your conversation is intact; '
              'nothing was written.',
          detail: (detail != null && detail.isNotEmpty) ? detail : null,
          allowsRetry: true,
        );
      case SummarizeNoUnobserved():
        // Defensive — never reached; we guard above.
        return const _SnackBarVariant(
          color: ManfredColors.accentBlue,
          severity: _Severity.warning,
          tag: 'nothing',
          headline: 'Nothing to summarize',
        );
      case SummarizeNotFound():
        return const _SnackBarVariant(
          color: ManfredColors.accentRed,
          severity: _Severity.error,
          tag: 'not found',
          headline: 'Session not found',
          secondary:
              'Something went wrong — try opening the session again.',
        );
      case SummarizeFeatureDisabled():
        return const _SnackBarVariant(
          color: ManfredColors.accentRed,
          severity: _Severity.error,
          tag: 'disabled',
          headline: 'Summaries are disabled for this build',
          secondary: 'Slash command hidden until the next app launch.',
        );
      case SummarizeTransportError(:final message):
        return _SnackBarVariant(
          color: ManfredColors.accentRed,
          severity: _Severity.error,
          tag: 'connection',
          headline: 'Connection issue',
          secondary:
              "Couldn't reach the observer (network or timeout). "
              'The session is fine.',
          detail: (message != null && message.isNotEmpty) ? message : null,
          allowsRetry: true,
        );
    }
  }
}

enum _Severity { success, warning, error }

class _SnackBarVariant {
  const _SnackBarVariant({
    required this.color,
    required this.severity,
    required this.tag,
    required this.headline,
    this.secondary,
    this.preview,
    this.detail,
    this.allowsRetry = false,
  });

  final Color color;
  final _Severity severity;
  final String tag;
  final String headline;
  final String? secondary;
  final String? preview;
  final String? detail;
  final bool allowsRetry;
}

class _SummarizeSnackBarContent extends StatelessWidget {
  const _SummarizeSnackBarContent({
    required this.variant,
    required this.onRetry,
  });

  final _SnackBarVariant variant;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final headlineStyle = ManfredFonts.sans(
      const TextStyle(
        fontSize: 14,
        height: 1.3,
        fontWeight: FontWeight.w600,
        color: ManfredColors.textPrimary,
        letterSpacing: -0.1,
      ),
    );
    final secondaryStyle = ManfredFonts.sans(
      const TextStyle(
        fontSize: 13,
        height: 1.45,
        color: ManfredColors.textSecondary,
      ),
    );
    final detailStyle = ManfredFonts.mono(
      const TextStyle(
        fontSize: 11,
        height: 1.4,
        color: ManfredColors.textMuted,
      ),
    );
    final tagStyle = ManfredFonts.mono(
      TextStyle(
        fontSize: 10,
        height: 1.0,
        letterSpacing: 1.4,
        color: variant.color,
        fontWeight: FontWeight.w500,
      ),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(width: 3, color: variant.color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: variant.color.withValues(alpha: 0.13),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  variant.tag.toUpperCase(),
                                  style: tagStyle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  variant.headline,
                                  style: headlineStyle,
                                ),
                              ),
                            ],
                          ),
                          if (variant.secondary != null) ...<Widget>[
                            const SizedBox(height: 4),
                            Text(variant.secondary!, style: secondaryStyle),
                          ],
                          if (variant.preview != null) ...<Widget>[
                            const SizedBox(height: 10),
                            _PreviewBlock(
                              preview: variant.preview!,
                              accent: variant.color,
                            ),
                          ],
                          if (variant.detail != null) ...<Widget>[
                            const SizedBox(height: 8),
                            Text(
                              variant.detail!,
                              style: detailStyle,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _SnackBarActions(onRetry: onRetry),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewBlock extends StatelessWidget {
  const _PreviewBlock({required this.preview, required this.accent});

  final String preview;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final style = ManfredFonts.serif(
      const TextStyle(
        fontSize: 13.5,
        height: 1.55,
        fontStyle: FontStyle.italic,
        color: ManfredColors.textPrimary,
      ),
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(4),
        border: Border(
          left: BorderSide(color: accent, width: 2),
          top: const BorderSide(color: ManfredColors.borderSubtle),
          right: const BorderSide(color: ManfredColors.borderSubtle),
          bottom: const BorderSide(color: ManfredColors.borderSubtle),
        ),
      ),
      child: Text(
        '"$preview"',
        style: style,
        maxLines: 3,
        overflow: TextOverflow.fade,
      ),
    );
  }
}

class _SnackBarActions extends StatelessWidget {
  const _SnackBarActions({required this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        final actions = <Widget>[
          if (onRetry != null)
            _SnackBarActionButton(
              label: 'retry',
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                onRetry!();
              },
            ),
          _SnackBarActionButton(
            label: 'dismiss',
            onPressed: () =>
                ScaffoldMessenger.of(context).hideCurrentSnackBar(),
          ),
        ];
        return Row(mainAxisSize: MainAxisSize.min, children: actions);
      },
    );
  }
}

class _SnackBarActionButton extends StatelessWidget {
  const _SnackBarActionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final style = ManfredFonts.mono(
      const TextStyle(
        fontSize: 11,
        color: ManfredColors.textMuted,
        letterSpacing: 0.6,
      ),
    );
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(label, style: style),
      ),
    );
  }
}
