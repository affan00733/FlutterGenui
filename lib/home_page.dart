import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:genui/genui.dart';
import 'package:genui_template/conversation.dart';
import 'package:genui_template/data/profile_repository.dart';
import 'package:genui_template/domain/persona.dart';
import 'package:genui_template/format.dart';
import 'package:genui_template/model/model_provider.dart';
import 'package:genui_template/prompt.dart';
import 'package:genui_template/theme_controller.dart';
import 'package:genui_template/widgets/widgets.dart';
import 'package:speech_to_text/speech_to_text.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // The active LLM — the swappable "Intelligence" layer. Starts on whichever
  // provider's key was supplied at launch; switchable live from the app bar.
  ModelProvider _provider = ModelProvider.initial;

  // Who the experience adapts to. Switching it regenerates the system prompt so
  // the same question yields a different UX.
  Persona _persona = Persona.novice;

  // Whether the A2UI source panel is shown. Hidden by default so the demo leads
  // with the product (phone), then revealed via the {} toggle to prove the UI
  // is model-generated.
  bool _showSource = false;

  // Voice-to-UI: speak a money question and watch the tool generate.
  final SpeechToText _speech = SpeechToText();
  bool _speechReady = false;
  bool _listening = false;

  // First-run onboarding gate.
  bool _onboarded = false;

  // Titles (first prompt) of past conversations, newest first.
  final List<String> _pastSessions = [];

  late GenUiSession _session;
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  StreamSubscription<ConversationEvent>? _eventsSub;

  // The conversation transcript: user turns, assistant text replies, and
  // generated-surface turns in order, so follow-ups read as a real chat.
  final List<_Turn> _turns = [];

  // The assistant text bubble being streamed into for the current reply (text
  // arrives as deltas), or null between replies.
  _AssistantTurn? _currentAssistant;

  @override
  void initState() {
    super.initState();
    _createSession();
    unawaited(_initSpeech());
  }

  Future<void> _initSpeech() async {
    try {
      final ok = await _speech.initialize(
        onStatus: (status) {
          if (mounted) setState(() => _listening = status == 'listening');
        },
        onError: (_) {
          if (mounted) setState(() => _listening = false);
        },
      );
      if (mounted) setState(() => _speechReady = ok);
    } on Object catch (_) {
      // Speech unavailable (unsupported browser, or web plugin not registered
      // after a hot restart). Degrade gracefully — the mic button just hides.
      if (mounted) setState(() => _speechReady = false);
    }
  }

  // Starts/stops dictation. Final result is sent as a message automatically.
  void _toggleMic() {
    if (_listening) {
      unawaited(_speech.stop());
      return;
    }
    unawaited(
      _speech.listen(
        onResult: (result) {
          _textController.text = result.recognizedWords;
          if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
            sendMessage(result.recognizedWords);
          }
        },
      ),
    );
  }

  // Builds the GenUI pipeline for the current provider + persona and wires
  // transcript + error handling. Called on init and on every switch.
  void _createSession() {
    _session = GenUiSession(
      modelClientBuilder: _provider.builder,
      systemPrompt: buildSystemPrompt(
        persona: _persona,
        profile: ProfileRepository.profile,
        market: ProfileRepository.market,
      ),
      persona: _persona,
    );
    _eventsSub = _session.events.listen((event) {
      if (!mounted) return;
      switch (event) {
        // Plain-text replies (clarifications, follow-up questions) stream in as
        // deltas; accumulate them into one assistant bubble.
        case ConversationContentReceived(:final text):
          if (text.trim().isEmpty && _currentAssistant == null) break;
          setState(() {
            final current = _currentAssistant;
            if (current == null) {
              final turn = _AssistantTurn(text);
              _turns.add(turn);
              _currentAssistant = turn;
            } else {
              current.text += text;
            }
          });
          _scrollToBottom();
        // Each generated surface becomes a turn; start a fresh assistant bubble
        // for any text that follows it.
        case ConversationSurfaceAdded(:final surfaceId):
          setState(() {
            _turns.add(_SurfaceTurn(surfaceId));
            _currentAssistant = null;
          });
          _scrollToBottom();
        case ConversationError(:final error):
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Request failed: $error')),
          );
        default:
          break;
      }
    });
  }

  // Applies [apply] (provider/persona change), clears the transcript, and
  // rebuilds the session. History is per-session, so a switch starts fresh.
  void _rebuildSession(VoidCallback apply) {
    final previous = _session;
    unawaited(_eventsSub?.cancel());
    setState(() {
      apply();
      _turns.clear();
      _currentAssistant = null;
      _createSession();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
  }

  void _switchProvider(ModelProvider provider) {
    if (provider == _provider) return;
    _rebuildSession(() => _provider = provider);
  }

  // Archives the current conversation (by its first prompt) and starts fresh.
  void _newConversation() {
    for (final turn in _turns) {
      if (turn is _UserTurn) {
        _pastSessions.insert(0, turn.text);
        break;
      }
    }
    _rebuildSession(() {});
  }

  // "Reopens" a past conversation by starting fresh and re-asking its prompt.
  void _openSession(String prompt) {
    _newConversation();
    sendMessage(prompt);
  }

  void _switchPersona(Persona persona) {
    if (persona == _persona) return;
    _rebuildSession(() => _persona = persona);
  }

  @override
  void dispose() {
    unawaited(_eventsSub?.cancel());
    _textController.dispose();
    _scrollController.dispose();
    _session.dispose();
    super.dispose();
  }

  // Sends the user's text and records it as a transcript turn. The model keeps
  // the full history, so follow-ups like "make it 10 years" have context.
  void sendMessage(String text) {
    if (text.trim().isEmpty) return;
    _textController.clear();
    // No key for the chosen model — answer in-chat instead of a cryptic error.
    if (!_provider.hasApiKey) {
      setState(() {
        _currentAssistant = null;
        _turns
          ..add(_UserTurn(text))
          ..add(
            _AssistantTurn(
              'No API key set for **${_provider.label}**. Relaunch with '
              '`--dart-define=${_provider.apiKeyEnv}=YOUR_KEY`, or open the '
              'menu (☰) and pick a model you have a key for.',
            ),
          );
      });
      _scrollToBottom();
      return;
    }
    setState(() {
      _currentAssistant = null;
      _turns.add(_UserTurn(text));
    });
    _session.sendMessage(text);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        unawaited(
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          ),
        );
      }
    });
  }

  static const _suggestions = <String>[
    'Review my finances',
    'Pay off my card or invest?',
    'How do I pay off my debts?',
    "What's my net worth?",
    r'Can I afford a $2,400 laptop?',
    'Am I saving enough for retirement?',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ValueListenableBuilder<ConversationState>(
        valueListenable: _session.conversationState,
        builder: (context, state, _) {
          final isProcessing = state.isWaiting;
          final phoneChild = _onboarded
              ? _miniApp(isProcessing)
              : _Onboarding(onDone: () => setState(() => _onboarded = true));
          return Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _PhoneFrame(child: phoneChild)),
                  // Raw A2UI — hidden by default, revealed via the {} toggle.
                  if (_showSource) ...[
                    const VerticalDivider(width: 1),
                    SizedBox(
                      width: 380,
                      child: A2uiSourceView(source: _session.a2uiSource),
                    ),
                  ],
                ],
              ),
              // Presenter-only control to prove the UI is model-generated.
              Positioned(
                top: 12,
                right: 16,
                child: _SourceToggle(
                  showSource: _showSource,
                  onToggle: () => setState(() => _showSource = !_showSource),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // The in-phone app: its own header + sessions/model drawer, the transcript,
  // and the composer.
  Widget _miniApp(bool isProcessing) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surfaceContainer,
        titleSpacing: 4,
        title: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                Icons.auto_awesome,
                size: 17,
                color: scheme.onPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Text('Aria', style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Toggle dark mode',
            icon: Icon(
              themeMode.value == ThemeMode.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
            onPressed: () => setState(toggleThemeMode),
          ),
          _PersonaToggle(current: _persona, onChanged: _switchPersona),
          const SizedBox(width: 8),
        ],
      ),
      drawer: _AppDrawer(
        isLive: ProfileRepository.isLive,
        sessions: _pastSessions,
        currentModel: _provider,
        onNewConversation: () {
          Navigator.pop(context);
          _newConversation();
        },
        onOpenSession: (prompt) {
          Navigator.pop(context);
          _openSession(prompt);
        },
        onModel: (provider) {
          Navigator.pop(context);
          _switchProvider(provider);
        },
      ),
      body: Column(
        children: [
          Expanded(
            child: _turns.isEmpty && !isProcessing
                ? _EmptyState(onPick: sendMessage)
                : _Transcript(
                    turns: _turns,
                    isProcessing: isProcessing,
                    scrollController: _scrollController,
                    surfaceFor: _session.contextFor,
                  ),
          ),
          if (isProcessing) const LinearProgressIndicator(minHeight: 2),
          MessageInput(
            controller: _textController,
            isProcessing: isProcessing,
            onSend: sendMessage,
            suggestions: _suggestions,
            micAvailable: _speechReady,
            isListening: _listening,
            onMic: _toggleMic,
          ),
        ],
      ),
    );
  }
}

/// One entry in the conversation transcript.
sealed class _Turn {
  const _Turn();
}

class _UserTurn extends _Turn {
  const _UserTurn(this.text);
  final String text;
}

/// A streamed plain-text reply from the assistant. Mutable so deltas can be
/// appended as they arrive.
class _AssistantTurn extends _Turn {
  _AssistantTurn(this.text);
  String text;
}

class _SurfaceTurn extends _Turn {
  const _SurfaceTurn(this.surfaceId);
  final String surfaceId;
}

/// Renders the ordered list of user messages and generated surfaces.
class _Transcript extends StatelessWidget {
  const _Transcript({
    required this.turns,
    required this.isProcessing,
    required this.scrollController,
    required this.surfaceFor,
  });

  final List<_Turn> turns;
  final bool isProcessing;
  final ScrollController scrollController;
  final SurfaceContext Function(String surfaceId) surfaceFor;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: turns.length + (isProcessing ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= turns.length) {
          return const _ThinkingBubble();
        }
        final turn = turns[index];
        return switch (turn) {
          _UserTurn(:final text) => _UserBubble(text: text),
          _AssistantTurn(:final text) => _AssistantBubble(text: text),
          _SurfaceTurn(:final surfaceId) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Surface(surfaceContext: surfaceFor(surfaceId)),
          ),
        };
      },
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 460),
        decoration: BoxDecoration(
          color: scheme.primary,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(color: scheme.onPrimary),
        ),
      ),
    );
  }
}

class _AssistantBubble extends StatelessWidget {
  const _AssistantBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 560),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: MarkdownBody(
          data: stripEmoji(text),
          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
            p: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: scheme.onSurface),
          ),
        ),
      ),
    );
  }
}

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Text('Aria is building a tool…', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// Wraps the app in a centered phone-style frame so the generated UI reads as a
/// real mobile app during the demo.
class _PhoneFrame extends StatelessWidget {
  const _PhoneFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        constraints: const BoxConstraints(maxWidth: 430),
        decoration: BoxDecoration(
          color: const Color(0xFF15171A), // phone bezel
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 36,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        padding: const EdgeInsets.all(8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: ColoredBox(
            color: scheme.surface,
            child: Column(
              children: [
                // Notch / status strip.
                SizedBox(
                  height: 24,
                  child: Center(
                    child: Container(
                      width: 80,
                      height: 5,
                      decoration: BoxDecoration(
                        color: scheme.outlineVariant,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows whether the financial data is loaded live from Supabase or is the
/// bundled demo profile — makes the "real data" claim verifiable at a glance.
class _DataBadge extends StatelessWidget {
  const _DataBadge();

  @override
  Widget build(BuildContext context) {
    final live = ProfileRepository.isLive;
    final color = live ? const Color(0xFF2E7D32) : Theme.of(context)
        .colorScheme
        .onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            live ? 'Live data' : 'Demo data',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Floating presenter control (outside the phone) that reveals the raw A2UI
/// source to prove the UI is model-generated.
class _SourceToggle extends StatelessWidget {
  const _SourceToggle({required this.showSource, required this.onToggle});

  final bool showSource;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      elevation: 1,
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: showSource ? 'Hide A2UI source' : 'Show A2UI source',
        isSelected: showSource,
        icon: const Icon(Icons.data_object_outlined),
        selectedIcon: const Icon(Icons.data_object),
        onPressed: onToggle,
      ),
    );
  }
}

/// The app's slide-out menu: recent conversations, a new-conversation action,
/// the live-data status, and the swappable model picker.
class _AppDrawer extends StatelessWidget {
  const _AppDrawer({
    required this.isLive,
    required this.sessions,
    required this.currentModel,
    required this.onNewConversation,
    required this.onOpenSession,
    required this.onModel,
  });

  final bool isLive;
  final List<String> sessions;
  final ModelProvider currentModel;
  final VoidCallback onNewConversation;
  final ValueChanged<String> onOpenSession;
  final ValueChanged<ModelProvider> onModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.auto_awesome,
                      size: 19,
                      color: scheme.onPrimary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Aria', style: theme.textTheme.titleMedium),
                  ),
                  const _DataBadge(),
                ],
              ),
            ),
            const Divider(height: 1),
            if (!isLive)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Using demo data. To go live, relaunch with '
                        'SUPABASE_URL and SUPABASE_ANON_KEY '
                        '(see docs/supabase_setup.md).',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ListTile(
              leading: const Icon(Icons.add_comment_outlined),
              title: const Text('New conversation'),
              onTap: onNewConversation,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'Recent',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            if (sessions.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text('No past conversations yet.'),
              )
            else
              for (final session in sessions)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.chat_bubble_outline, size: 20),
                  title: Text(
                    session,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => onOpenSession(session),
                ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'Model',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            for (final provider in ModelProvider.values)
              ListTile(
                dense: true,
                leading: Icon(
                  provider == currentModel
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 20,
                ),
                title: Text(provider.label),
                onTap: () => onModel(provider),
              ),
          ],
        ),
      ),
    );
  }
}

/// First-run onboarding: three intro slides shown inside the phone.
class _Onboarding extends StatefulWidget {
  const _Onboarding({required this.onDone});

  final VoidCallback onDone;

  @override
  State<_Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<_Onboarding> {
  final _controller = PageController();
  int _page = 0;

  static const _slides = <({IconData icon, String title, String body})>[
    (
      icon: Icons.insights,
      title: 'Meet Aria',
      body: 'Your AI money copilot. Ask any financial question and Aria builds '
          'an interactive tool to answer it — not a wall of text.',
    ),
    (
      icon: Icons.auto_awesome,
      title: 'Tools, made for the moment',
      body: 'Pay off debt or invest? Budget, retire, rent or buy? Aria '
          'assembles the right interactive instrument, pre-filled with your '
          'real numbers.',
    ),
    (
      icon: Icons.lock_outline,
      title: 'Grounded and safe',
      body: 'Your accounts are the source of truth — Aria never invents '
          'numbers, and only uses approved, on-brand components.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final last = _page == _slides.length - 1;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              onPageChanged: (i) => setState(() => _page = i),
              itemCount: _slides.length,
              itemBuilder: (context, i) {
                final slide = _slides[i];
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        slide.icon,
                        size: 44,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      slide.title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      slide.body,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < _slides.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _page ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _page ? scheme.primary : scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: last
                  ? widget.onDone
                  : () => unawaited(
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      ),
                    ),
              child: Text(last ? 'Get started' : 'Next'),
            ),
          ),
          TextButton(onPressed: widget.onDone, child: const Text('Skip')),
        ],
      ),
    );
  }
}

/// App-bar toggle between Novice and Expert — the adaptation axis. Switching it
/// regenerates the prompt so the same question yields a different UX.
class _PersonaToggle extends StatelessWidget {
  const _PersonaToggle({required this.current, required this.onChanged});

  final Persona current;
  final ValueChanged<Persona> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<Persona>(
      showSelectedIcon: false,
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      segments: [
        for (final persona in Persona.values)
          ButtonSegment<Persona>(
            value: persona,
            label: Text(persona.label),
          ),
      ],
      selected: {current},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}

/// Shown before the first question: a short pitch plus tappable starter prompts
/// that each map to a different instrument, so a demo can begin in one click.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onPick});

  final ValueChanged<String> onPick;

  static const _starters = <String>[
    r'Should I pay off my $10,000 credit card or invest it?',
    r'Save $50,000 for a house down payment in 4 years',
    r'Grow $10,000 plus $300 a month for 20 years — how much?',
    'Compare a high-yield savings account vs an S&P 500 index fund',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.insights,
                size: 48,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Ask Aria a money question',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Aria builds an interactive tool for your decision, '
                'pre-filled with your numbers, instead of just answering '
                'in text.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final prompt in _starters)
                    ActionChip(
                      label: Text(prompt),
                      onPressed: () => onPick(prompt),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
