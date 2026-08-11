import 'package:flutter/material.dart';

class ResetRefreshIcon extends StatelessWidget {
  final double size;
  final double textSize;

  const ResetRefreshIcon({
    Key? key,
    this.size = 44,
    this.textSize = 7,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/images/reset.png',
        fit: BoxFit.contain,
      ),
    );
  }
}
