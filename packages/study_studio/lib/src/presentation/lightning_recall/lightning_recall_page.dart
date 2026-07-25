import 'dart:async';

import 'package:cockpit_ui/cockpit_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/providers.dart';
import '../building/build_preview.dart';

const _weakTopics = ['Routing', 'TCP/IP', 'Subnetting'];

/// Screen 9 — Lightning Recall.
///
/// Rapid-fire recall session with countdown timer, streak tracking, and
/// instant feedback. Mock data mirrors the design reference until the
/// backend recall pipeline is wired.
class LightningRecallPage extends ConsumerStatefulWidget {
  const LightningRecallPage({super.key, required this.studioId});

  final String studioId;

  @override
  ConsumerState<LightningRecallPage> createState() =>
      _LightningRecallPageState();
}

class _LightningRecallPageState extends ConsumerState<LightningRecallPage> {
  static const _totalQuestions = 50;

  static const _questions = [
    _RecallQuestion(
      text: 'Which OSI layer handles routing?',
      answer: 'network layer',
      hint: 'Think about Layer 3.',
      explanation: 'The Network Layer (Layer 3) is responsible for routing.',
    ),
    _RecallQuestion(
      text: 'What does TCP stand for?',
      answer: 'transmission control protocol',
      hint: 'A reliable transport protocol.',
      explanation:
          'TCP stands for Transmission Control Protocol — it provides '
          'reliable, ordered delivery at the transport layer.',
    ),
    _RecallQuestion(
      text: 'Which device operates at Layer 2 of the OSI model?',
      answer: 'switch',
      hint: 'It forwards frames using MAC addresses.',
      explanation:
          'A switch operates at the Data Link Layer (Layer 2) and uses '
          'MAC addresses to forward frames.',
    ),
  ];

  final _answerController = TextEditingController();
  Timer? _countdownTimer;

  int _questionIndex = 17;
  int _streak = 18;
  int _countdown = 7;
  bool _paused = false;
  bool _showHint = false;
  bool _showFeedback = true;
  bool _answeredCorrectly = true;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _answerController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    if (_paused) return;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _paused) return;
      setState(() {
        if (_countdown > 0) {
          _countdown--;
        } else {
          _countdownTimer?.cancel();
        }
      });
    });
  }

  _RecallQuestion get _current =>
      _questions[_questionIndex % _questions.length];

  double get _progress => (_questionIndex + 1) / _totalQuestions;

  void _submitAnswer() {
    final input = _answerController.text.trim().toLowerCase();
    if (input.isEmpty) return;
    final correct = _current.matches(input);
    setState(() {
      _showFeedback = true;
      _answeredCorrectly = correct;
      if (correct) _streak++;
    });
    _countdownTimer?.cancel();
  }

  void _nextQuestion() {
    if (_questionIndex + 1 >= _totalQuestions) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session complete — great work!')),
      );
      return;
    }
    setState(() {
      _questionIndex++;
      _answerController.clear();
      _showHint = false;
      _showFeedback = false;
      _answeredCorrectly = false;
      _countdown = 7;
    });
    _startCountdown();
  }

  void _skip() => _nextQuestion();

  void _togglePause() {
    setState(() => _paused = !_paused);
    if (_paused) {
      _countdownTimer?.cancel();
    } else {
      _startCountdown();
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(studioProvider(widget.studioId));

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (_) => _LightningRecallBody(
                studioId: widget.studioId,
                examTitle: BuildPreview.studioName,
                questionIndex: _questionIndex,
                totalQuestions: _totalQuestions,
                progress: _progress,
                streak: _streak,
                countdown: _countdown,
                paused: _paused,
                showHint: _showHint,
                showFeedback: _showFeedback,
                answeredCorrectly: _answeredCorrectly,
                question: _current,
                answerController: _answerController,
                onSubmit: _submitAnswer,
                onHint: () => setState(() => _showHint = true),
                onSkip: _skip,
                onTogglePause: _togglePause,
                onNext: _nextQuestion,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecallQuestion {
  const _RecallQuestion({
    required this.text,
    required this.answer,
    required this.hint,
    required this.explanation,
  });

  final String text;
  final String answer;
  final String hint;
  final String explanation;

  bool matches(String input) {
    final normalized = input.trim().toLowerCase();
    return normalized.contains(answer) ||
        (answer.contains('network') && normalized.contains('layer 3')) ||
        (answer.contains('layer 3') && normalized.contains('network'));
  }
}

class _LightningRecallBody extends StatelessWidget {
  const _LightningRecallBody({
    required this.studioId,
    required this.examTitle,
    required this.questionIndex,
    required this.totalQuestions,
    required this.progress,
    required this.streak,
    required this.countdown,
    required this.paused,
    required this.showHint,
    required this.showFeedback,
    required this.answeredCorrectly,
    required this.question,
    required this.answerController,
    required this.onSubmit,
    required this.onHint,
    required this.onSkip,
    required this.onTogglePause,
    required this.onNext,
  });

  final String studioId;
  final String examTitle;
  final int questionIndex;
  final int totalQuestions;
  final double progress;
  final int streak;
  final int countdown;
  final bool paused;
  final bool showHint;
  final bool showFeedback;
  final bool answeredCorrectly;
  final _RecallQuestion question;
  final TextEditingController answerController;
  final VoidCallback onSubmit;
  final VoidCallback onHint;
  final VoidCallback onSkip;
  final VoidCallback onTogglePause;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final base = '/study/$studioId';

    return Column(
      children: [
        _Header(examTitle: examTitle, onBack: () => context.go(base)),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: CockpitSpacing.xl),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: CockpitSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _SessionSummaryCard(),
                    const SizedBox(height: CockpitSpacing.lg),
                    _QuestionProgress(
                      index: questionIndex,
                      total: totalQuestions,
                      progress: progress,
                    ),
                    const SizedBox(height: CockpitSpacing.md),
                    const _FlowStateCard(),
                    const SizedBox(height: CockpitSpacing.lg),
                    _QuestionCard(
                      streak: streak,
                      countdown: countdown,
                      paused: paused,
                      showHint: showHint,
                      question: question,
                      answerController: answerController,
                      onSubmit: onSubmit,
                      onHint: onHint,
                    ),
                    if (showFeedback) ...[
                      const SizedBox(height: CockpitSpacing.md),
                      _FeedbackCard(
                        correct: answeredCorrectly,
                        explanation: question.explanation,
                      ),
                      const SizedBox(height: CockpitSpacing.md),
                      const _MetricsRow(),
                    ],
                    const SizedBox(height: CockpitSpacing.lg),
                    _ControlRow(
                      paused: paused,
                      onSkip: onSkip,
                      onTogglePause: onTogglePause,
                      onEnd: () => context.go(base),
                    ),
                    const SizedBox(height: CockpitSpacing.md),
                    _GradientButton(
                      icon: Icons.bolt_rounded,
                      label: 'Next Question',
                      onTap: onNext,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({required this.examTitle, required this.onBack});

  final String examTitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    void soon(String label) => ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label — coming soon')));

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CockpitSpacing.md,
        CockpitSpacing.sm,
        CockpitSpacing.md,
        CockpitSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CircleButton(icon: Icons.arrow_back_ios_new, onTap: onBack),
          const SizedBox(width: CockpitSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  examTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: CockpitSpacing.xs,
                  runSpacing: CockpitSpacing.xxs,
                  children: [
                    Icon(Icons.bolt_rounded, size: 14, color: scheme.primary),
                    Text(
                      'Lightning Recall',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '•',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      'Rapid Recall',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: CockpitSpacing.sm),
          _CircleButton(
            icon: Icons.bar_chart_rounded,
            onTap: () => soon('Analytics'),
          ),
          const SizedBox(width: CockpitSpacing.xs),
          _CircleButton(
            icon: Icons.more_horiz,
            onTap: () => soon('More options'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Session summary
// ---------------------------------------------------------------------------

class _SessionSummaryCard extends StatelessWidget {
  const _SessionSummaryCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return _OutlinedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.bolt_rounded,
                  size: 20,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: CockpitSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lightning Recall',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Rapid-fire questions to build instant recall.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: CockpitSpacing.lg),
          LayoutBuilder(
            builder: (context, constraints) {
              final stats = [
                const _SessionStat(
                  icon: Icons.layers_outlined,
                  value: '50',
                  label: 'Total',
                ),
                const _SessionStat(
                  icon: Icons.schedule_outlined,
                  value: '4 min',
                  label: 'Session',
                ),
                const _SessionStat(
                  icon: Icons.local_fire_department_rounded,
                  value: '12',
                  label: 'Keep it up!',
                  valueColor: true,
                ),
                const _SessionStat(
                  icon: Icons.workspace_premium_outlined,
                  value: '47',
                  label: 'Personal Best',
                ),
              ];

              if (constraints.maxWidth < 360) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var i = 0; i < stats.length; i++) ...[
                        if (i > 0)
                          Container(
                            width: 1,
                            height: 44,
                            margin: const EdgeInsets.symmetric(
                              horizontal: CockpitSpacing.md,
                            ),
                            color: scheme.outlineVariant,
                          ),
                        stats[i],
                      ],
                    ],
                  ),
                );
              }

              return Row(
                children: [
                  for (var i = 0; i < stats.length; i++) ...[
                    if (i > 0)
                      Container(
                        width: 1,
                        height: 44,
                        margin: const EdgeInsets.symmetric(
                          horizontal: CockpitSpacing.sm,
                        ),
                        color: scheme.outlineVariant,
                      ),
                    Expanded(child: stats[i]),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: CockpitSpacing.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: CockpitSpacing.md,
              vertical: CockpitSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(CockpitRadii.md),
            ),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: CockpitSpacing.sm,
              runSpacing: CockpitSpacing.xs,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.track_changes_rounded,
                      size: 14,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: CockpitSpacing.xs),
                    Text(
                      'Weak topics included:',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                for (final topic in _weakTopics) TagChip(label: topic),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionStat extends StatelessWidget {
  const _SessionStat({
    required this.icon,
    required this.value,
    required this.label,
    this.valueColor = false,
  });

  final IconData icon;
  final String value;
  final String label;
  final bool valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      children: [
        Icon(icon, size: 16, color: scheme.onSurfaceVariant),
        const SizedBox(height: CockpitSpacing.xs),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: valueColor ? scheme.primary : null,
          ),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: valueColor ? scheme.primary : scheme.onSurfaceVariant,
            fontSize: 10,
            fontWeight: valueColor ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Progress
// ---------------------------------------------------------------------------

class _QuestionProgress extends StatelessWidget {
  const _QuestionProgress({
    required this.index,
    required this.total,
    required this.progress,
  });

  final int index;
  final int total;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final pct = (progress * 100).round();

    return Column(
      children: [
        Row(
          children: [
            Text.rich(
              TextSpan(
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                children: [
                  const TextSpan(text: 'Question '),
                  TextSpan(
                    text: '${index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  TextSpan(text: ' / $total'),
                ],
              ),
            ),
            const Spacer(),
            Text(
              '$pct% Complete',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: CockpitSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(CockpitRadii.pill),
          child: LinearProgressIndicator(
            value: progress.clamp(0, 1),
            minHeight: 6,
            backgroundColor: scheme.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Flow state
// ---------------------------------------------------------------------------

class _FlowStateCard extends StatelessWidget {
  const _FlowStateCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return _OutlinedCard(
      padding: const EdgeInsets.symmetric(
        horizontal: CockpitSpacing.lg,
        vertical: CockpitSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: scheme.primary),
              const SizedBox(width: CockpitSpacing.xs),
              Text(
                'Flow State',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                'Excellent',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: CockpitSpacing.md),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    for (var i = 0; i < 7; i++)
                      Expanded(
                        child: Container(
                          height: 8,
                          margin: EdgeInsets.only(
                            right: i < 6 ? CockpitSpacing.xs : 0,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              CockpitRadii.pill,
                            ),
                            gradient: i < 5
                                ? LinearGradient(
                                    colors: [
                                      scheme.primary,
                                      Color.lerp(
                                        scheme.primary,
                                        const Color(0xFFEC4899),
                                        i / 4,
                                      )!,
                                    ],
                                  )
                                : null,
                            color: i >= 5
                                ? scheme.surfaceContainerHighest
                                : null,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: CockpitSpacing.sm),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primary.withValues(alpha: 0.15),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.35),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.diamond_rounded,
                  size: 14,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: CockpitSpacing.sm),
          Text(
            "You're in the zone! Keep the streak going.",
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Question card
// ---------------------------------------------------------------------------

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.streak,
    required this.countdown,
    required this.paused,
    required this.showHint,
    required this.question,
    required this.answerController,
    required this.onSubmit,
    required this.onHint,
  });

  final int streak;
  final int countdown;
  final bool paused;
  final bool showHint;
  final _RecallQuestion question;
  final TextEditingController answerController;
  final VoidCallback onSubmit;
  final VoidCallback onHint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final countdownProgress = countdown / 7;

    return Container(
      padding: const EdgeInsets.all(CockpitSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(CockpitRadii.xl),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary.withValues(alpha: 0.06), scheme.surface],
        ),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bolt_rounded, size: 16, color: scheme.primary),
                  const SizedBox(width: CockpitSpacing.xs),
                  Text(
                    'Streak $streak',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: CockpitSpacing.sm),
          SizedBox(
            width: 88,
            height: 88,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 88,
                  height: 88,
                  child: CircularProgressIndicator(
                    value: 1,
                    strokeWidth: 6,
                    valueColor: AlwaysStoppedAnimation(
                      scheme.surfaceContainerHighest,
                    ),
                  ),
                ),
                SizedBox(
                  width: 88,
                  height: 88,
                  child: CircularProgressIndicator(
                    value: paused ? countdownProgress : countdownProgress,
                    strokeWidth: 6,
                    strokeCap: StrokeCap.round,
                    valueColor: AlwaysStoppedAnimation(scheme.primary),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$countdown',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'SECONDS',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontSize: 9,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: CockpitSpacing.lg),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: CockpitSpacing.md,
              vertical: CockpitSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(CockpitRadii.pill),
            ),
            child: Text(
              'QUESTION',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: CockpitSpacing.md),
          Text(
            question.text,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          const SizedBox(height: CockpitSpacing.lg),
          TextField(
            controller: answerController,
            enabled: !paused,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onSubmit(),
            decoration: InputDecoration(
              hintText: 'Type your answer...',
              filled: true,
              fillColor: scheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(CockpitRadii.lg),
                borderSide: BorderSide(color: scheme.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(CockpitRadii.lg),
                borderSide: BorderSide(color: scheme.outlineVariant),
              ),
            ),
          ),
          const SizedBox(height: CockpitSpacing.xs),
          Text(
            'Press Enter to submit',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (showHint) ...[
            const SizedBox(height: CockpitSpacing.sm),
            Text(
              question.hint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: CockpitSpacing.md),
          TextButton.icon(
            onPressed: paused ? null : onHint,
            icon: Icon(Icons.lightbulb_outline_rounded, color: scheme.primary),
            label: Text(
              "Can't recall? Show hint",
              style: TextStyle(
                color: scheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Feedback + metrics
// ---------------------------------------------------------------------------

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({required this.correct, required this.explanation});

  final bool correct;
  final String explanation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final success = CockpitColors.brand.success;

    return Container(
      padding: const EdgeInsets.all(CockpitSpacing.md),
      decoration: BoxDecoration(
        color: success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(CockpitRadii.lg),
        border: Border.all(color: success.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.check_circle_rounded, color: success, size: 22),
              const SizedBox(width: CockpitSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      correct ? 'Correct! 🎉' : 'Not quite',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: success,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      explanation,
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: CockpitSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () => ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(explanation))),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: CockpitSpacing.sm,
                  vertical: CockpitSpacing.xs,
                ),
                visualDensity: VisualDensity.compact,
                side: BorderSide(color: success.withValues(alpha: 0.4)),
                foregroundColor: success,
              ),
              icon: const Icon(Icons.psychology_outlined, size: 14),
              label: const Text('Why this is correct'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricsRow extends StatelessWidget {
  const _MetricsRow();

  @override
  Widget build(BuildContext context) {
    const metrics = [
      _MetricTile(
        icon: Icons.schedule_rounded,
        label: 'Avg. Response Time',
        value: '2.3s',
        detail: 'Great pace!',
      ),
      _MetricTile(
        icon: Icons.track_changes_rounded,
        label: 'Accuracy',
        value: '87%',
        detail: 'Excellent',
      ),
      _MetricTile(
        icon: Icons.psychology_outlined,
        label: 'Recall Power',
        value: 'High',
        detail: 'Keep it strong!',
      ),
    ];

    return Row(
      children: [
        for (var i = 0; i < metrics.length; i++) ...[
          if (i > 0) const SizedBox(width: CockpitSpacing.sm),
          Expanded(child: metrics[i]),
        ],
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
  });

  final IconData icon;
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return _OutlinedCard(
      padding: const EdgeInsets.all(CockpitSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(height: CockpitSpacing.xs),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontSize: 10,
              height: 1.2,
            ),
          ),
          const SizedBox(height: CockpitSpacing.xs),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Controls
// ---------------------------------------------------------------------------

class _ControlRow extends StatelessWidget {
  const _ControlRow({
    required this.paused,
    required this.onSkip,
    required this.onTogglePause,
    required this.onEnd,
  });

  final bool paused;
  final VoidCallback onSkip;
  final VoidCallback onTogglePause;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final error = CockpitColors.brand.error;

    return Row(
      children: [
        Expanded(
          child: _OutlineActionButton(
            icon: Icons.skip_next_rounded,
            label: 'Skip',
            onTap: onSkip,
          ),
        ),
        const SizedBox(width: CockpitSpacing.sm),
        Expanded(
          child: _OutlineActionButton(
            icon: paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            label: paused ? 'Resume' : 'Pause',
            onTap: onTogglePause,
            filled: true,
          ),
        ),
        const SizedBox(width: CockpitSpacing.sm),
        Expanded(
          child: _OutlineActionButton(
            icon: Icons.stop_circle_outlined,
            label: 'End Session',
            onTap: onEnd,
            borderColor: error,
            foregroundColor: error,
          ),
        ),
      ],
    );
  }
}

class _OutlineActionButton extends StatelessWidget {
  const _OutlineActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
    this.borderColor,
    this.foregroundColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;
  final Color? borderColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fg = foregroundColor ?? scheme.onSurface;
    final border = borderColor ?? scheme.outlineVariant;
    final bg = filled ? scheme.primary.withValues(alpha: 0.08) : scheme.surface;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(CockpitRadii.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CockpitRadii.lg),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(CockpitRadii.lg),
            border: Border.all(color: border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: CockpitSpacing.md,
              horizontal: CockpitSpacing.xs,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: fg),
                const SizedBox(height: CockpitSpacing.xs),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared widgets
// ---------------------------------------------------------------------------

class _OutlinedCard extends StatelessWidget {
  const _OutlinedCard({
    required this.child,
    this.padding = const EdgeInsets.all(CockpitSpacing.lg),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(CockpitRadii.lg),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: child,
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(CockpitRadii.pill),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: theme.colorScheme.onSurface),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final violet = _shiftHue(scheme.primary, -28);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CockpitRadii.pill),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(CockpitRadii.pill),
            gradient: LinearGradient(colors: [scheme.secondary, violet]),
          ),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: CockpitSpacing.sm),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Color _shiftHue(Color base, double degrees) {
  final hsl = HSLColor.fromColor(base);
  final h = (hsl.hue + degrees) % 360;
  return hsl.withHue(h < 0 ? h + 360 : h).toColor();
}
