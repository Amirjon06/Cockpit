import 'package:cockpit_ui/cockpit_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../domain/entities/me.dart';
import 'studio_palette.dart';

/// App-chrome account controls: an **Octocredits** pill + a **profile** avatar.
/// Used both in the desktop nav rail and the mobile top bar, so it reads the
/// same [meProvider] and looks consistent everywhere.
class AccountBar extends ConsumerWidget {
  const AccountBar({super.key, this.compact = false});

  /// Tighter spacing for the mobile top bar.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OctocreditsPill(
          credits: me.valueOrNull?.credits,
          loading: me.isLoading,
          compact: compact,
        ),
        SizedBox(width: compact ? CockpitSpacing.sm : CockpitSpacing.md),
        ProfileAvatar(me: me.valueOrNull),
      ],
    );
  }
}

/// A small pill showing the user's Octocredit balance.
class OctocreditsPill extends StatelessWidget {
  const OctocreditsPill({
    super.key,
    this.credits,
    this.loading = false,
    this.compact = false,
  });

  final int? credits;
  final bool loading;

  /// Compact hides the "Octocredits" word (bolt + number only) for tight spots
  /// like the desktop nav rail.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = loading ? '…' : (credits?.toString() ?? '—');

    return Semantics(
      label: 'Octocredits: $label',
      button: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: CockpitSpacing.sm,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: const LinearGradient(
            colors: [StudyPalette.amberBright, StudyPalette.warning],
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bolt_rounded, size: 16, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (!compact) ...[
              const SizedBox(width: 4),
              Text(
                'Octocredits',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Circular profile control. Tapping opens a small account menu (auth start —
/// sign-out is a placeholder until the Octopilot/Firebase session is wired).
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, this.me});

  final Me? me;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final initials = me?.initials ?? '?';
    final subtitle = me?.email ?? me?.displayName ?? 'Not signed in';

    return PopupMenuButton<String>(
      tooltip: 'Account',
      offset: const Offset(0, 44),
      onSelected: (value) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
          SnackBar(content: Text('$value — coming soon')),
        );
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                me?.displayName ?? 'Guest',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(subtitle, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(value: 'Profile', child: Text('Profile')),
        const PopupMenuItem<String>(value: 'Settings', child: Text('Settings')),
        const PopupMenuItem<String>(value: 'Sign out', child: Text('Sign out')),
      ],
      child: CircleAvatar(
        radius: 18,
        backgroundColor: scheme.primary.withValues(alpha: 0.12),
        child: Text(
          initials,
          style: theme.textTheme.labelLarge?.copyWith(
            color: scheme.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
