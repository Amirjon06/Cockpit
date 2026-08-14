import 'package:cockpit_ui/cockpit_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../domain/entities/me.dart';
import 'studio_palette.dart';

/// Org label shown under the user's name in the sidebar account card.
const String _kOrgLabel = 'Boardwalks LLC';

/// Groups thousands: 56485 -> "56,485".
String _formatCredits(int value) {
  final digits = value.abs().toString();
  final buf = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i != 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return buf.toString();
}

// ---------------------------------------------------------------------------
// Shared account menu (sign in/out, profile, settings)
// ---------------------------------------------------------------------------

Future<void> _handleAccount(
  BuildContext context,
  WidgetRef ref,
  String value,
) async {
  final auth = ref.read(authServiceProvider);
  final messenger = ScaffoldMessenger.of(context);
  try {
    if (value == 'Sign in') {
      await auth.signIn();
      ref.invalidate(meProvider);
    } else if (value == 'Sign out') {
      await auth.signOut();
      ref.invalidate(meProvider);
    } else {
      messenger.showSnackBar(SnackBar(content: Text('$value — coming soon')));
    }
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('$value failed: $e')));
  }
}

List<PopupMenuEntry<String>> _accountMenuItems(
  BuildContext context,
  Me? me,
  bool signedIn,
) {
  final theme = Theme.of(context);
  return [
    PopupMenuItem<String>(
      enabled: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            me?.displayName ?? (signedIn ? 'Signed in' : 'Guest'),
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            me?.email ?? me?.displayName ?? 'Not signed in',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    ),
    const PopupMenuDivider(),
    const PopupMenuItem<String>(value: 'Profile', child: Text('Profile')),
    const PopupMenuItem<String>(value: 'Settings', child: Text('Settings')),
    if (signedIn)
      const PopupMenuItem<String>(value: 'Sign out', child: Text('Sign out'))
    else
      const PopupMenuItem<String>(value: 'Sign in', child: Text('Sign in')),
  ];
}

// ---------------------------------------------------------------------------
// Mobile top bar: credits pill + avatar (horizontal)
// ---------------------------------------------------------------------------

/// App-chrome account controls for the mobile top bar: an **Octocredits** pill +
/// a **profile** avatar. Reads [meProvider] so it stays in sync with the sidebar.
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

/// A refined pill showing the user's Octocredit balance. Neutral surface with a
/// single gold bolt — reads as premium against the black/red theme instead of a
/// loud amber gradient.
class OctocreditsPill extends StatelessWidget {
  const OctocreditsPill({
    super.key,
    this.credits,
    this.loading = false,
    this.compact = false,
  });

  final int? credits;
  final bool loading;

  /// Compact hides the "credits" word (bolt + number only).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = loading
        ? '…'
        : (credits != null ? _formatCredits(credits!) : '—');

    return Semantics(
      label: 'Octocredits: $label',
      button: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: CockpitSpacing.md,
          vertical: 7,
        ),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(CockpitRadii.pill),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bolt_rounded,
                size: 16, color: StudyPalette.amberBright),
            const SizedBox(width: 4),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (!compact) ...[
              const SizedBox(width: 5),
              Text(
                'credits',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
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

/// Circular profile control (mobile top bar). Tapping opens the account menu.
class ProfileAvatar extends ConsumerWidget {
  const ProfileAvatar({super.key, this.me});

  final Me? me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(authServiceProvider).isSignedIn;
    final initials = me?.initials ?? (signedIn ? '?' : 'G');

    return PopupMenuButton<String>(
      tooltip: 'Account',
      offset: const Offset(0, 44),
      onSelected: (value) => _handleAccount(context, ref, value),
      itemBuilder: (context) => _accountMenuItems(context, me, signedIn),
      child: _Avatar(initials: initials, radius: 18),
    );
  }
}

// ---------------------------------------------------------------------------
// Desktop sidebar: credits chip + profile card (vertical)
// ---------------------------------------------------------------------------

/// The account block that lives at the bottom of the desktop nav rail: a
/// full-width credits chip stacked over a tappable profile row. Replaces the
/// cramped pill-beside-avatar treatment.
class AccountCard extends ConsumerWidget {
  const AccountCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final me = ref.watch(meProvider);
    final signedIn = ref.watch(authServiceProvider).isSignedIn;
    final data = me.valueOrNull;
    final credits = me.isLoading
        ? '…'
        : (data?.credits != null ? _formatCredits(data!.credits!) : '—');
    final name = data?.displayName ?? (signedIn ? 'Signed in' : 'Guest');
    final initials = data?.initials ?? (signedIn ? '?' : 'G');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Credits chip.
        Material(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(CockpitRadii.md),
          child: InkWell(
            borderRadius: BorderRadius.circular(CockpitRadii.md),
            onTap: () => _handleAccount(context, ref, 'Top up credits'),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: CockpitSpacing.md,
                vertical: CockpitSpacing.sm,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(CockpitRadii.md),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bolt_rounded,
                      size: 18, color: StudyPalette.amberBright),
                  const SizedBox(width: CockpitSpacing.sm),
                  Text(
                    credits,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'CREDITS',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: CockpitSpacing.sm),
        // Profile row -> account menu.
        PopupMenuButton<String>(
          tooltip: 'Account',
          offset: const Offset(0, -8),
          position: PopupMenuPosition.over,
          onSelected: (value) => _handleAccount(context, ref, value),
          itemBuilder: (context) => _accountMenuItems(context, data, signedIn),
          padding: EdgeInsets.zero,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: CockpitSpacing.sm,
              vertical: CockpitSpacing.sm,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(CockpitRadii.md),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              children: [
                _Avatar(initials: initials, radius: 17),
                const SizedBox(width: CockpitSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        _kOrgLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.unfold_more_rounded,
                    size: 18, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Shared avatar chip: initials on a red-tinted disc with a subtle ring.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials, required this.radius});
  final String initials;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: scheme.primary.withValues(alpha: 0.16),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.5)),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: theme.textTheme.labelLarge?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w800,
          fontSize: radius * 0.72,
        ),
      ),
    );
  }
}
