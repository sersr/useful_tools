import 'package:flutter/material.dart';

import 'overlay_side.dart';

enum OverlayAliment {
  start,
  center,
  end,
}

class OverlayHorizontalController extends OverlaySideDefault {
  OverlayHorizontalController({
    required Widget content,
    BorderRadius? radius,
    Duration? stay,
    Color? color,
    bool? closeOndismissed,
    this.rightSide = false,
    Curve? curve,
    this.align = OverlayAliment.center,
    Object? showKey,
  })  : showKey = showKey ?? Object(),
        super(
          stay: stay,
          content: content,
          radius: radius,
          color: color,
          curve: curve,
          closeOndismissed: closeOndismissed,
        );
  final bool rightSide;
  @override
  late final positionRight = rightSide ? 0 : null;
  @override
  late final positionLeft = rightSide ? null : 0;

  @override
  final Object showKey;

  Alignment? _alignment;
  @override
  Alignment? get alignment {
    if (_alignment != null) return _alignment;
    if (rightSide) {
      switch (align) {
        case OverlayAliment.center:
          _alignment = Alignment.centerLeft;
          break;
        case OverlayAliment.start:
          _alignment = Alignment.topLeft;
          break;
        case OverlayAliment.end:
          _alignment = Alignment.bottomLeft;
          break;

        default:
      }
    } else {
      switch (align) {
        case OverlayAliment.center:
          _alignment = Alignment.centerRight;
          break;
        case OverlayAliment.start:
          _alignment = Alignment.topRight;
          break;
        case OverlayAliment.end:
          _alignment = Alignment.bottomRight;
          break;

        default:
      }
    }
    return _alignment;
  }

  final OverlayAliment align;

  @override
  Widget buildChild(BuildContext context) {
    return SafeArea(child: super.buildChild(context));
  }
}
