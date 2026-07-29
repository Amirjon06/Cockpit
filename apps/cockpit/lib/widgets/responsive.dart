import 'package:flutter/material.dart';

/// Width at/above which Cockpit's own screens (Home, Settings) switch from
/// the phone layout to the desktop/web layout. Mirrors `kStudioDesktop` in
/// `study_studio`'s `studio_scaffold.dart`, kept separate here since
/// `apps/cockpit` can't import that package's private widgets.
const double kAppDesktop = 900;

/// True when the current view should use the desktop/web layout.
bool isAppDesktop(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kAppDesktop;

/// Centers page content and caps its width on very wide screens so a phone
/// column doesn't stretch edge-to-edge on a large monitor.
class AppContentColumn extends StatelessWidget {
  const AppContentColumn({
    super.key,
    required this.child,
    this.maxWidth = 1160,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
