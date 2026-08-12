import 'package:flutter/material.dart';

/// Prevents landscape-only game scenes from rendering a cropped, overflowing
/// world while Android is still rotating the activity (or rotation is locked).
class LandscapeGameBody extends StatelessWidget {
  const LandscapeGameBody({
    super.key,
    required this.landscapeChild,
    required this.onExit,
  });

  final Widget landscapeChild;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLandscape = constraints.maxWidth > constraints.maxHeight;
        if (isLandscape) return landscapeChild;

        return ColoredBox(
          color: const Color(0xFFFFF5F8),
          child: SafeArea(
            child: Stack(
              children: [
                Positioned(
                  left: 12,
                  top: 8,
                  child: IconButton.filledTonal(
                    tooltip: 'Volver',
                    onPressed: onExit,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                ),
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.screen_rotation_rounded,
                          size: 68,
                          color: Color(0xFF7C3A87),
                        ),
                        SizedBox(height: 18),
                        Text(
                          'Gira tu teléfono',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'El jardín y la casa se disfrutan en horizontal.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
