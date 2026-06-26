import 'package:flutter/material.dart';

/// The message composer: quick-prompt chips, a rounded text field, and a
/// circular send button.
///
/// While [isProcessing], input is disabled and the button shows a spinner.
/// Submitting via the keyboard or the button calls [onSend] with the text.
class MessageInput extends StatelessWidget {
  const MessageInput({
    required this.controller,
    required this.isProcessing,
    required this.onSend,
    this.suggestions = const [],
    this.micAvailable = false,
    this.isListening = false,
    this.onMic,
    super.key,
  });

  final TextEditingController controller;
  final bool isProcessing;
  final ValueChanged<String> onSend;

  /// Always-available quick prompts shown as chips above the field.
  final List<String> suggestions;

  /// Voice input: shown only when speech recognition initialized.
  final bool micAvailable;
  final bool isListening;
  final VoidCallback? onMic;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (suggestions.isNotEmpty)
            SizedBox(
              height: 46,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: suggestions.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) => Center(
                  child: ActionChip(
                    label: Text(suggestions[i]),
                    onPressed: isProcessing
                        ? null
                        : () => onSend(suggestions[i]),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    enabled: !isProcessing,
                    textInputAction: TextInputAction.send,
                    onSubmitted: isProcessing ? null : onSend,
                    decoration: InputDecoration(
                      hintText: isListening
                          ? 'Listening…'
                          : 'Ask Aria a money question…',
                      filled: true,
                      fillColor: scheme.surfaceContainerHighest,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      suffixIcon: micAvailable
                          ? IconButton(
                              tooltip: isListening ? 'Stop' : 'Speak',
                              onPressed: isProcessing ? null : onMic,
                              icon: Icon(
                                isListening
                                    ? Icons.stop_circle
                                    : Icons.mic_none,
                                color: isListening ? scheme.error : null,
                              ),
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _SendButton(
                  isProcessing: isProcessing,
                  onPressed: () => onSend(controller.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.isProcessing, required this.onPressed});

  final bool isProcessing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 52,
      height: 52,
      child: FilledButton(
        style: FilledButton.styleFrom(
          shape: const CircleBorder(),
          padding: EdgeInsets.zero,
          backgroundColor: scheme.primary,
        ),
        onPressed: isProcessing ? null : onPressed,
        child: isProcessing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.arrow_upward),
      ),
    );
  }
}
