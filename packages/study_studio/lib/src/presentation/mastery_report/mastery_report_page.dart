import 'package:cockpit_ui/cockpit_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/providers.dart';
import '../building/build_preview.dart';

/// Screen 8 — AI Mastery Report.
///
/// Post-session analytics summarising mastery, learning activities, topic
/// breakdown, and a personalised study plan. Mock data mirrors the design
/// reference until the backend scoring pipeline is wired.
class MasteryReportPage extends ConsumerWidget {
  const MasteryReportPage({super.key, required this.studioId});

  final String studioId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(studioProvider(studioId));

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (_) => _MasteryReportBody(
                studioId: studioId,
                examTitle: BuildPreview.studioName,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MasteryReportBody extends StatelessWidget {
  const _MasteryReportBody({required this.studioId, required this.examTitle});

  final String studioId;
  final String examTitle;

  static const _mastery = 0.84;
  static const _sessionDate = 'May 18, 2025';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
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
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    "Today's Session  •  $_sessionDate",
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: CockpitSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: CockpitSpacing.md),
                    _MasteryOverview(mastery: _mastery),
                    const SizedBox(height: CockpitSpacing.lg),
                    const _AiAssessmentCard(),
                  ],
                ),
              ),
              const SizedBox(height: CockpitSpacing.xl),
              Padding(
                padding: const EdgeInsets.only(left: CockpitSpacing.lg),
                child: Text(
                  'Learning Journey',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: CockpitSpacing.md),
              const _LearningJourneyRow(),
              const SizedBox(height: CockpitSpacing.xl),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: CockpitSpacing.lg,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 400;
                    if (wide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Expanded(flex: 3, child: _MasteryByTopicCard()),
                          const SizedBox(width: CockpitSpacing.md),
                          Expanded(
                            flex: 2,
                            child: Column(
                              children: [
                                const _ConfidencePerformanceCard(),
                                const SizedBox(height: CockpitSpacing.md),
                                const _SkillsRow(),
                              ],
                            ),
                          ),
                        ],
                      );
                    }
                    return const Column(
                      children: [
                        _MasteryByTopicCard(),
                        SizedBox(height: CockpitSpacing.md),
                        _ConfidencePerformanceCard(),
                        SizedBox(height: CockpitSpacing.md),
                        _SkillsRow(),
                      ],
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: CockpitSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: CockpitSpacing.lg),
                    const _StudyPlanCard(),
                    const SizedBox(height: CockpitSpacing.xl),
                    _GradientButton(
                      icon: Icons.auto_awesome,
                      label: 'Explore Knowledge Graph',
                      trailing: true,
                      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Knowledge Graph — coming soon'),
                        ),
                      ),
                    ),
                    const SizedBox(height: CockpitSpacing.md),
                    Center(
                      child: TextButton.icon(
                        onPressed: () => context.go(base),
                        icon: Icon(
                          Icons.menu_book_outlined,
                          color: scheme.primary,
                        ),
                        label: Text(
                          'Continue Studying',
                          style: TextStyle(
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
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
              children: [
                Text(
                  examTitle,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: CockpitSpacing.xs,
                  children: [
                    Icon(Icons.auto_awesome, size: 14, color: scheme.primary),
                    Text(
                      'AI Mastery Report',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: CockpitSpacing.sm),
          _CircleButton(icon: Icons.ios_share, onTap: () => soon('Share')),
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
// Mastery overview
// ---------------------------------------------------------------------------

class _MasteryOverview extends StatelessWidget {
  const _MasteryOverview({required this.mastery});

  final double mastery;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final pct = (mastery * 100).round();
    final success = CockpitColors.brand.success;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: CircularProgressIndicator(
                  value: 1,
                  strokeWidth: 10,
                  valueColor: AlwaysStoppedAnimation(
                    scheme.surfaceContainerHighest,
                  ),
                ),
              ),
              SizedBox(
                width: 120,
                height: 120,
                child: CircularProgressIndicator(
                  value: mastery,
                  strokeWidth: 10,
                  strokeCap: StrokeCap.round,
                  valueColor: AlwaysStoppedAnimation(scheme.primary),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$pct%',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Mastery',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: CockpitSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Exam Readiness',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: CockpitSpacing.xs),
              Row(
                children: [
                  Text(
                    'High',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: success,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: CockpitSpacing.xs),
                  Icon(Icons.trending_up_rounded, size: 20, color: success),
                ],
              ),
              const SizedBox(height: CockpitSpacing.sm),
              Text(
                'Based on all learning activities completed today.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: CockpitSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: CockpitSpacing.md,
                  vertical: CockpitSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(CockpitRadii.md),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.trending_up_rounded,
                      size: 18,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: CockpitSpacing.sm),
                    Expanded(
                      child: Text(
                        '+18% improvement since you created this Study Studio',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
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
// AI Assessment
// ---------------------------------------------------------------------------

class _AiAssessmentCard extends StatelessWidget {
  const _AiAssessmentCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(CockpitSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(CockpitRadii.xl),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary.withValues(alpha: 0.08),
            scheme.secondary.withValues(alpha: 0.06),
          ],
        ),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.12)),
      ),
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
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      scheme.primary,
                      scheme.primary.withValues(alpha: 0.75),
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.smart_toy_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: CockpitSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Assessment',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: CockpitSpacing.xs),
                    Text(
                      "Excellent progress today. You've demonstrated strong "
                      'conceptual understanding and consistent recall.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: CockpitSpacing.sm),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: scheme.secondary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(CockpitRadii.md),
                ),
                child: Icon(
                  Icons.emoji_events_rounded,
                  color: scheme.secondary,
                  size: 32,
                ),
              ),
            ],
          ),
          const SizedBox(height: CockpitSpacing.lg),
          Text(
            'To reach full mastery, focus on:',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: CockpitSpacing.sm),
          Wrap(
            spacing: CockpitSpacing.sm,
            runSpacing: CockpitSpacing.sm,
            children: const [
              TagChip(label: 'Routing'),
              TagChip(label: 'Subnetting'),
              TagChip(label: 'TCP/IP troubleshooting'),
            ],
          ),
          const SizedBox(height: CockpitSpacing.lg),
          Row(
            children: [
              Expanded(
                child: Container(height: 1, color: scheme.outlineVariant),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: CockpitSpacing.lg,
                ),
                child: Column(
                  children: [
                    Text(
                      'Est. time to 95% mastery',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: CockpitSpacing.xs),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '38 min',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: CockpitSpacing.xs),
                        Icon(Icons.schedule, size: 18, color: scheme.primary),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(height: 1, color: scheme.outlineVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Learning journey
// ---------------------------------------------------------------------------

class _LearningJourneyRow extends StatelessWidget {
  const _LearningJourneyRow();

  @override
  Widget build(BuildContext context) {
    const items = [
      _JourneyItem(
        icon: Icons.chat_bubble_outline_rounded,
        iconColor: Color(0xFF30A46C),
        title: 'Teach Me',
        subtitle: 'Completed',
        subtitleColor: Color(0xFF30A46C),
        completed: true,
      ),
      _JourneyItem(
        icon: Icons.help_outline_rounded,
        iconColor: Color(0xFF8B5CF6),
        title: 'Quiz Me',
        subtitle: '15 / 18',
        detail: '83%',
      ),
      _JourneyItem(
        icon: Icons.bolt_rounded,
        iconColor: Color(0xFF8B5CF6),
        title: 'Lightning Recall',
        subtitle: '91%',
        detail: 'Recall Speed',
      ),
      _JourneyItem(
        icon: Icons.style_rounded,
        iconColor: Color(0xFF8B5CF6),
        title: 'Flashcards',
        subtitle: '81%',
        detail: 'Mastery',
      ),
      _JourneyItem(
        icon: Icons.track_changes_rounded,
        iconColor: Color(0xFFE5484D),
        title: 'Scenario Mode',
        subtitle: '12 / 14',
        detail: 'Solved',
      ),
    ];

    return SizedBox(
      height: 108,
      child: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: const EdgeInsets.only(
            left: CockpitSpacing.lg,
            right: CockpitSpacing.lg,
          ),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(width: CockpitSpacing.sm),
                items[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _JourneyItem extends StatelessWidget {
  const _JourneyItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.detail,
    this.subtitleColor,
    this.completed = false,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? detail;
  final Color? subtitleColor;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      width: 100,
      padding: const EdgeInsets.all(CockpitSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(CockpitRadii.lg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Stack(
        children: [
          if (completed)
            Positioned(
              top: 0,
              right: 0,
              child: Icon(
                Icons.check_circle_rounded,
                size: 16,
                color: CockpitColors.brand.success,
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              const Spacer(),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: subtitleColor ?? scheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (detail != null)
                Text(
                  detail!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mastery by topic
// ---------------------------------------------------------------------------

class _TopicMastery {
  const _TopicMastery(this.name, this.value);
  final String name;
  final double value;
}

class _MasteryByTopicCard extends StatelessWidget {
  const _MasteryByTopicCard();

  static const _topics = [
    _TopicMastery('OSI Model', 0.96),
    _TopicMastery('Switching', 0.91),
    _TopicMastery('Ethernet', 0.89),
    _TopicMastery('Routing', 0.68),
    _TopicMastery('Subnetting', 0.61),
    _TopicMastery('TCP/IP', 0.72),
    _TopicMastery('Network Security', 0.74),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final warning = CockpitColors.brand.warning;

    return _OutlinedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mastery by Topic',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: CockpitSpacing.lg),
          for (final t in _topics) ...[
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    t.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(CockpitRadii.pill),
                    child: LinearProgressIndicator(
                      value: t.value,
                      minHeight: 6,
                      backgroundColor: scheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation(
                        t.value >= 0.8 ? scheme.primary : warning,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: CockpitSpacing.sm),
                SizedBox(
                  width: 36,
                  child: Text(
                    '${(t.value * 100).round()}%',
                    textAlign: TextAlign.right,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: CockpitSpacing.sm),
          ],
          InkWell(
            onTap: () {},
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'View All Topics (12)',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Icon(Icons.chevron_right, size: 16, color: scheme.primary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Confidence vs performance
// ---------------------------------------------------------------------------

class _ConfidencePerformanceCard extends StatelessWidget {
  const _ConfidencePerformanceCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final success = CockpitColors.brand.success;
    final error = CockpitColors.brand.error;

    return _OutlinedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Confidence vs Performance',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: CockpitSpacing.lg),
          _InsightRow(
            icon: Icons.warning_amber_rounded,
            iconColor: error,
            title: 'Overconfident on Routing',
            body: 'You were highly confident but answered incorrectly 2 times.',
          ),
          const SizedBox(height: CockpitSpacing.md),
          _InsightRow(
            icon: Icons.check_circle_outline_rounded,
            iconColor: success,
            title: 'Underestimated Ethernet',
            body: 'You were unsure but answered every question correctly.',
          ),
          const SizedBox(height: CockpitSpacing.md),
          InkWell(
            onTap: () {},
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'View Full Analysis',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Icon(Icons.chevron_right, size: 16, color: scheme.primary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: CockpitSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.3,
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
// Skills cards
// ---------------------------------------------------------------------------

class _SkillsRow extends StatelessWidget {
  const _SkillsRow();

  @override
  Widget build(BuildContext context) {
    return const IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _StrongestSkillsCard()),
          SizedBox(width: CockpitSpacing.sm),
          Expanded(child: _NeedsPracticeCard()),
        ],
      ),
    );
  }
}

class _StrongestSkillsCard extends StatelessWidget {
  const _StrongestSkillsCard();

  static const _skills = [
    'Network Architecture',
    'OSI Layers',
    'Ethernet Standards',
    'Switching Concepts',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final success = CockpitColors.brand.success;

    return _OutlinedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events_outlined, size: 16, color: success),
              const SizedBox(width: CockpitSpacing.xs),
              Expanded(
                child: Text(
                  'Strongest Skills',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: CockpitSpacing.md),
          for (final skill in _skills)
            Padding(
              padding: const EdgeInsets.only(bottom: CockpitSpacing.xs),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, size: 14, color: success),
                  const SizedBox(width: CockpitSpacing.xs),
                  Expanded(
                    child: Text(
                      skill,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _NeedsPracticeCard extends StatelessWidget {
  const _NeedsPracticeCard();

  static const _topics = ['Routing', 'Subnetting', 'IP Addressing'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final warning = CockpitColors.brand.warning;

    return _OutlinedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.local_fire_department_rounded,
                size: 16,
                color: warning,
              ),
              const SizedBox(width: CockpitSpacing.xs),
              Expanded(
                child: Text(
                  'Needs More Practice',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: CockpitSpacing.md),
          for (final topic in _topics)
            Padding(
              padding: const EdgeInsets.only(bottom: CockpitSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    topic,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  TextButton(
                    onPressed: () {},
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(
                      'Review Now',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Study plan
// ---------------------------------------------------------------------------

class _StudyPlanCard extends StatelessWidget {
  const _StudyPlanCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    const tasks = [
      ('Routing lesson', '8 min'),
      ('Flashcards (12 cards)', '12 min'),
      ('Scenario Mode (2 scenarios)', '10 min'),
    ];

    return _OutlinedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 18,
                color: scheme.primary,
              ),
              const SizedBox(width: CockpitSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Personalized Study Plan',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Recommended for Tomorrow',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Icon(Icons.schedule_rounded, size: 28, color: scheme.primary),
                  Text(
                    '20 min',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Estimated Session Time',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: CockpitSpacing.lg),
          for (final (task, duration) in tasks)
            Padding(
              padding: const EdgeInsets.only(bottom: CockpitSpacing.sm),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: CockpitSpacing.md),
                  Expanded(
                    child: Text(task, style: theme.textTheme.bodyMedium),
                  ),
                  Text(
                    duration,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: CockpitSpacing.sm),
          Row(
            children: [
              Icon(Icons.trending_up_rounded, size: 16, color: scheme.primary),
              const SizedBox(width: CockpitSpacing.xs),
              Expanded(
                child: Text(
                  'Target: Raise mastery to 88%+',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared widgets
// ---------------------------------------------------------------------------

class _OutlinedCard extends StatelessWidget {
  const _OutlinedCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(CockpitSpacing.lg),
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
    this.trailing = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool trailing;

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
                if (!trailing) ...[
                  Icon(icon, color: Colors.white, size: 18),
                  const SizedBox(width: CockpitSpacing.sm),
                ],
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (trailing) ...[
                  const SizedBox(width: CockpitSpacing.sm),
                  Icon(icon, color: Colors.white, size: 18),
                  const Text(' →', style: TextStyle(color: Colors.white)),
                ],
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
