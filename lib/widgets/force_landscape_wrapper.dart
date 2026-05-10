import 'package:flutter/material.dart';
import '../utils/orientation_lock.dart';

class ForceLandscapeWrapper extends StatelessWidget {
  final Widget child;
  const ForceLandscapeWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<OrientationMode>(
      valueListenable: OrientationLock.mode,
      builder: (context, mode, _) {
        final mq = MediaQuery.of(context);
        final isPortrait = mq.size.height > mq.size.width;

        if (mode == OrientationMode.landscape && isPortrait) {
          return _rotate(context, mq, quarterTurns: 1);
        }
        if (mode == OrientationMode.portrait && !isPortrait) {
          return _rotate(context, mq, quarterTurns: 1);
        }
        return child;
      },
    );
  }

  Widget _rotate(BuildContext context, MediaQueryData mq,
      {required int quarterTurns}) {
    final rotatedSize = Size(mq.size.height, mq.size.width);
    return MediaQuery(
      data: mq.copyWith(
        size: rotatedSize,
        padding: EdgeInsets.zero,
        viewPadding: EdgeInsets.zero,
        viewInsets: EdgeInsets.zero,
      ),
      child: RotatedBox(
        quarterTurns: quarterTurns,
        child: child,
      ),
    );
  }
}
