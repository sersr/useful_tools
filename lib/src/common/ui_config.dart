import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> uiOverlay({bool hide = true}) async {
  if (hide) {
    return SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  } else {
    return SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }
}

void uiStyle({bool dark = true}) {
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: dark ? Brightness.dark : Brightness.light,
    systemNavigationBarColor: Colors.white,
  ));
}

Future<void> setOrientation(bool portrait) async {
  if (portrait) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitDown,
      DeviceOrientation.portraitUp,
    ]);
  } else {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }
}

// class ZoomTransition extends PageTransitionsBuilder {
//   const ZoomTransition();

//   static const curve = Cubic(0.44, 0.12, 0.47, 0.73);
//   static const curve2 = Cubic(0.24, 0.1, 0.47, 0.73);

//   static final firstScale = Tween<double>(begin: 0.875, end: 1.0);

//   static final secondaryScale = Tween<double>(begin: 1.0, end: 1.0725);
//   static final secondaryScaleReverse = Tween<double>(begin: 1.0, end: 1.0525);

//   // reverse
//   static final firstCurveReverse =
//       CurveTween(curve: const Interval(0.867, 1.0, curve: curve));
//   static final secondaryCurveReverse =
//       CurveTween(curve: const Interval(0.625, 1.0, curve: curve2));
//   static final intervalCurve =
//       CurveTween(curve: const Interval(0.0, 0.525, curve: curve));

//   @override
//   Widget buildTransitions<T>(
//       PageRoute<T> route,
//       BuildContext context,
//       Animation<double> animation,
//       Animation<double> secondaryAnimation,
//       Widget child) {
//     final reverseOutter = animation.status == AnimationStatus.reverse;
//     final reverseInner = secondaryAnimation.status == AnimationStatus.reverse;

//     final opacity = reverseOutter
//         ? kAlwaysDismissedAnimation
//         : intervalCurve.animate(animation);

//     final scaleFirst = reverseOutter
//         ? kAlwaysDismissedAnimation
//         : intervalCurve.animate(animation).drive(firstScale);

//     final scaleSecondary = reverseInner
//         ? secondaryCurveReverse
//             .animate(secondaryAnimation)
//             .drive(secondaryScale)
//         : intervalCurve.animate(secondaryAnimation).drive(secondaryScale);

//     return RepaintBoundary(
//       child: FadeTransition(
//         opacity: opacity,
//         child: ScaleTransition(
//           scale: scaleFirst,
//           child: ScaleTransition(
//             scale: scaleSecondary,
//             child: child,
//           ),
//         ),
//       ),
//     );
//   }
// }
