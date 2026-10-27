import 'package:flutter/material.dart';
import 'package:maseef_app/theme/maseef_theme.dart';

/// The round MASEEF logo. Falls back to a villa icon only if the asset fails.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Image.asset(
        'assets/images/Favicon.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        excludeFromSemantics: true,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: size,
            height: size,
            color: MaseefColors.deep,
            alignment: Alignment.center,
            child: Icon(
              Icons.villa_rounded,
              color: Colors.white,
              size: size / 2,
            ),
          );
        },
      ),
    );
  }
}

/// Logo plus the MASEEF wordmark, used in the details page header.
class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key, this.markSize = 36});

  final double markSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandMark(size: markSize),
        const SizedBox(width: 10),
        const Text(
          'MASEEF',
          textDirection: TextDirection.ltr,
          style: TextStyle(
            color: MaseefColors.deep,
            fontSize: 19,
            fontWeight: FontWeight.w700,
            height: 1,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}
