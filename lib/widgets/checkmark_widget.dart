import 'package:flutter/material.dart';

/// A dedicated widget for displaying checkmarks after successful scans
/// This widget is designed to be more reliable than inline checkmarks
class CheckmarkWidget extends StatefulWidget {
  final bool isVisible;
  final String sectionId;
  final String fieldLabel;

  const CheckmarkWidget({
    Key? key,
    required this.isVisible,
    required this.sectionId,
    required this.fieldLabel,
  }) : super(key: key);

  @override
  State<CheckmarkWidget> createState() => _CheckmarkWidgetState();
}

class _CheckmarkWidgetState extends State<CheckmarkWidget> 
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
  }

  @override
  void didUpdateWidget(CheckmarkWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Animate when visibility changes
    if (widget.isVisible != oldWidget.isVisible) {
      if (widget.isVisible) {
        print('✅ CHECKMARK WIDGET: Showing checkmark for ${widget.sectionId} - ${widget.fieldLabel}');
        _animationController.forward();
      } else {
        print('❌ CHECKMARK WIDGET: Hiding checkmark for ${widget.sectionId} - ${widget.fieldLabel}');
        _animationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) {
      return const SizedBox(width: 32); // Maintain space even when not visible
    }

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            margin: const EdgeInsets.only(left: 8, bottom: 4),
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check,
              color: Colors.white,
              size: 16.0,
            ),
          ),
        );
      },
    );
  }
} 