import 'package:flutter/material.dart';
import '../services/audio_manager.dart';

/// Reusable pixel-art styled widgets for Spideyhood's retro arcade menus.

class PixelColors {
  PixelColors._();

  static const Color red = Color(0xFFD62828);
  static const Color darkRed = Color(0xFF9E1B1B);
  static const Color yellow = Color(0xFFFFD166);
  static const Color darkYellow = Color(0xFFC79A16);
  static const Color blue = Color(0xFF1D3557);
  static const Color lightBlue = Color(0xFF457B9D);
  static const Color cyan = Color(0xFF00F0FF);
  static const Color darkCharcoal = Color(0xFF121420);
  static const Color cardBg = Color(0xFF1B1F38);
  static const Color green = Color(0xFF06D6A0);
  static const Color darkGreen = Color(0xFF048A66);
  static const Color borderLight = Color(0xFFFFFFFF);
  static const Color borderDark = Color(0xFF000000);
}

/// Pixelated container with 3D retro arcade border and drop shadow.
class PixelContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color backgroundColor;
  final Color borderColor;
  final double borderWidth;
  final double elevation;
  final VoidCallback? onTap;

  const PixelContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.margin,
    this.backgroundColor = PixelColors.cardBg,
    this.borderColor = Colors.white,
    this.borderWidth = 3,
    this.elevation = 4,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: elevation > 0
            ? [
                BoxShadow(
                  color: PixelColors.borderDark,
                  offset: Offset(elevation, elevation),
                  spreadRadius: 0,
                  blurRadius: 0,
                ),
              ]
            : null,
      ),
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: content,
      );
    }
    return content;
  }
}

/// Retro 3D Arcade Button with tactile pressed feel and crisp pixel borders.
class PixelButton extends StatefulWidget {
  final String text;
  final IconData? icon;
  final Color color;
  final Color textColor;
  final VoidCallback? onPressed;
  final double fontSize;
  final EdgeInsetsGeometry padding;
  final bool isFullWidth;
  final bool isEnabled;

  const PixelButton({
    super.key,
    required this.text,
    this.icon,
    this.color = PixelColors.red,
    this.textColor = Colors.white,
    this.onPressed,
    this.fontSize = 14,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    this.isFullWidth = false,
    this.isEnabled = true,
  });

  @override
  State<PixelButton> createState() => _PixelButtonState();
}

class _PixelButtonState extends State<PixelButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final effectiveEnabled = widget.isEnabled && widget.onPressed != null;
    final baseColor = effectiveEnabled ? widget.color : Colors.grey.shade800;
    final txtColor = effectiveEnabled ? widget.textColor : Colors.white38;
    final offset = _isPressed ? const Offset(1, 1) : const Offset(3, 3);

    return GestureDetector(
      onTapDown: effectiveEnabled ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: effectiveEnabled
          ? (_) {
              setState(() => _isPressed = false);
              AudioManager.instance.playButtonClick();
              widget.onPressed?.call();
            }
          : null,
      onTapCancel: effectiveEnabled ? () => setState(() => _isPressed = false) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        width: widget.isFullWidth ? double.infinity : null,
        padding: widget.padding,
        transform: Matrix4.translationValues(
          _isPressed ? 2.0 : 0.0,
          _isPressed ? 2.0 : 0.0,
          0.0,
        ),
        decoration: BoxDecoration(
          color: baseColor,
          border: Border.all(
            color: effectiveEnabled ? Colors.white : Colors.white24,
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black,
              offset: offset,
              spreadRadius: 0,
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: widget.isFullWidth ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, color: txtColor, size: widget.fontSize + 4),
              const SizedBox(width: 8),
            ],
            Text(
              widget.text,
              style: TextStyle(
                color: txtColor,
                fontSize: widget.fontSize,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Retro segmented pixel-art progress bar with scanline / block styling.
class PixelProgressBar extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final double height;
  final Color fillColor;
  final Color backgroundColor;
  final int totalSegments;

  const PixelProgressBar({
    super.key,
    required this.progress,
    this.height = 20,
    this.fillColor = PixelColors.yellow,
    this.backgroundColor = Colors.black45,
    this.totalSegments = 16,
  });

  @override
  Widget build(BuildContext context) {
    final clampedProgress = progress.clamp(0.0, 1.0);
    final filledSegments = (clampedProgress * totalSegments).round();

    return Container(
      height: height,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black,
            offset: Offset(2, 2),
            spreadRadius: 0,
            blurRadius: 0,
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            children: List.generate(totalSegments, (index) {
              final isFilled = index < filledSegments;
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  color: isFilled ? fillColor : Colors.transparent,
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

/// Pixel badge tag for difficulty, status, or level indicators.
class PixelBadge extends StatelessWidget {
  final String text;
  final Color color;
  final Color textColor;
  final IconData? icon;

  const PixelBadge({
    super.key,
    required this.text,
    this.color = PixelColors.red,
    this.textColor = Colors.white,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Colors.black,
            offset: Offset(2, 2),
            spreadRadius: 0,
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: textColor, size: 12),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w900,
              fontSize: 10,
              fontFamily: 'monospace',
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}
