import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Primary action for AI moments: violet → cyan gradient, 52 dp tall.
class AiButton extends StatelessWidget {
  const AiButton({super.key, required this.label, required this.icon, required this.onPressed, this.expanded = true});

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final child = Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Ink(
        height: 52,
        decoration: BoxDecoration(
          gradient: AppColors.aiGradient,
          borderRadius: BorderRadius.circular(AppSpacing.radius),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.radius),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
            child: Row(
              mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.black, size: 22),
                const SizedBox(width: AppSpacing.s),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return Semantics(button: true, enabled: enabled, label: label, excludeSemantics: true, child: Material(type: MaterialType.transparency, child: child));
  }
}
