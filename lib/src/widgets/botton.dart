import 'package:flutter/material.dart';

Widget btn1(
    {VoidCallback? onTap,
    VoidCallback? onLongPress,
    VoidCallback? onTapCancel,
    void Function(TapDownDetails details)? onTapDown,
    Widget? child,
    double elevation = 0.0,
    Color? bgColor,
    Color? splashColor = const Color.fromARGB(255, 228, 228, 228),
    double? radius,
    EdgeInsets? padding,
    ShapeBorder? shape,
    bool background = true}) {
  var borderRadius = radius == null ? null : BorderRadius.circular(radius);

  child = InkWell(
    splashFactory: InkRipple.splashFactory,
    splashColor: splashColor,
    borderRadius: borderRadius,
    customBorder: shape,
    onTap: onTap,
    onLongPress: onLongPress,
    onTapCancel: onTapCancel,
    onTapDown: onTapDown,
    highlightColor: splashColor?.withAlpha(190),
    child: Padding(
      padding: padding ?? EdgeInsets.zero,
      child: child,
    ),
  );

  return RepaintBoundary(
    child: background
        ? Material(
            elevation: elevation,
            shape: shape,
            borderRadius: borderRadius,
            color: bgColor,
            child: RepaintBoundary(child: child),
          )
        : child,
  );
}

Widget btn2(
    {VoidCallback? onTap, required String text, required IconData icon}) {
  return RepaintBoundary(
    child: InkWell(
      borderRadius: BorderRadius.circular(4.0),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(2.0),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(4.0),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 36,
              color: Colors.grey.shade600,
            ),
            Text(
              text,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget reloadBotton(VoidCallback onTap) {
  return Center(
    child: btn1(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      bgColor: Colors.blue,
      splashColor: Colors.blue[200],
      radius: 40,
      child: const Text(
        '重新加载',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
      onTap: onTap,
    ),
  );
}

Widget loadingIndicator({double radius = 30}) {
  return Center(
      child: SizedBox(
          width: radius,
          height: radius,
          child: const CircularProgressIndicator(strokeWidth: 3.0)));
}
