import 'package:flutter/material.dart';

import '../navigation/export.dart';
import '../overlay/export.dart';

typedef SnackbarDelegate = OverlayMixinDelegate;
typedef BannerDelegate = OverlayMixinDelegate;
typedef ToastDelegate = OverlayMixinDelegate;

late final _snackBarToken = Object();
late final _bannelToken = Object();
late final _toastToken = Object();

extension OverlayExt on NavInterface {
  SnackbarDelegate snackBar(
    Widget content, {
    Duration duration = const Duration(seconds: 3),
    Duration animationDuration = const Duration(milliseconds: 300),
    Duration delayDuration = Duration.zero,
    bool? closeOndismissed,
    Color? color,
  }) =>
      showOverlay(
        content,
        showKey: _snackBarToken,
        duration: duration,
        animationDuration: animationDuration,
        delayDuration: delayDuration,
        color: color,
        closeOndismissed: closeOndismissed,
        position: Position.bottom,
      );

  BannerDelegate banner(
    Widget content, {
    Duration duration = const Duration(seconds: 3),
    Duration animationDuration = const Duration(milliseconds: 300),
    Duration delayDuration = Duration.zero,
    Color? color,
    BorderRadius? radius = const BorderRadius.all(Radius.circular(8)),
  }) {
    return showOverlay(
      content,
      top: 0,
      right: 8,
      left: 8,
      margin: const EdgeInsets.only(top: 8),
      showKey: _bannelToken,
      duration: duration,
      animationDuration: animationDuration,
      delayDuration: delayDuration,
      radius: radius,
      color: color,
      position: Position.top,
    );
  }

  ToastDelegate toast(
    Widget content, {
    Duration duration = const Duration(seconds: 3),
    Duration animationDuration = const Duration(milliseconds: 300),
    BorderRadius? radius = const BorderRadius.all(Radius.circular(8)),
    Color? color,
    double bottomPadding = 80.0,
    EdgeInsets? padding,
    bool? closeOndismissed,
  }) {
    return showOverlay(
      Container(padding: padding, child: content),
      duration: duration,
      showKey: _toastToken,
      radius: radius,
      color: color,
      top: null,
      bottom: bottomPadding,
      onTap: (owner) {
        owner.hide();
      },
      closeOndismissed: true,
      transition: (child, self) {
        final owner = self.owner;
        return AnimatedBuilder(
          animation: owner.ignore,
          builder: (context, child) {
            return IgnorePointer(ignoring: owner.ignore.value, child: child);
          },
          child: Center(
            child: IntrinsicWidth(
              child: FadeTransition(
                opacity: owner.controller,
                child: RepaintBoundary(
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
extension Content on BuildContext {
  bool get isDarkMode {
    return MediaQuery.of(this).platformBrightness == ThemeMode.dark;
  }
}

extension NavigatorExt on NavInterface {
  Future<T?> push<T extends Object?>(Route<T> route) {
    final push = NavPushAction(route);
    _navDelegate(push);
    return push.result;
  }

  Future<T?> pushNamed<T extends Object?>(
    String routeName, {
    Object? arguments,
  }) {
    final action = NavPushNamedAction<T>(routeName, arguments);
    _navDelegate(action);
    return action.result;
  }

  Future<T?> pushReplacement<T extends Object?, TO extends Object?>(
      Route<T> newRoute,
      {TO? result}) {
    final action = NavPushReplacementdAction(newRoute, result);
    _navDelegate(action);
    return action.result;
  }

  void pop<T extends Object?>([T? result]) {
    final pop = NavPopAction(result);
    _navDelegate(pop);
  }

  Future<bool?> maybePop<T extends Object?>([T? result]) {
    final pop = NavMaybePopAction(result);
    _navDelegate(pop);
    return pop.result;
  }

  void replace<T extends Object?>(
      {required Route<dynamic> oldRoute, required Route<T> newRoute}) {
    final replace = NavReplaceAction(oldRoute, newRoute);
    _navDelegate(replace);
  }

  Future<String?> restorableReplace<T extends Object?>(
      {required Route<dynamic> oldRoute,
      required RestorableRouteBuilder<T> newRouteBuilder,
      Object? arguments}) {
    final action =
        NavRestorableReplaceAction(oldRoute, newRouteBuilder, arguments);
    _navDelegate(action);
    return action.result;
  }

  void replaceRouteBelow<T extends Object?>(
      {required Route<dynamic> anchorRoute, required Route<T> newRoute}) {
    final action = NavReplaceBelowAction(anchorRoute, newRoute);
    _navDelegate(action);
  }

  Future<T?> showDialog<T>({
    required WidgetBuilder builder,
    bool barrierDismissible = true,
    Color? barrierColor = Colors.black54,
    String? barrierLabel,
    bool useSafeArea = true,
    RouteSettings? routeSettings,
    RouteSettings? settings,
    CapturedThemes? themes,
  }) {
    final route = RawDialogRoute<T>(
      pageBuilder: (BuildContext buildContext, Animation<double> animation,
          Animation<double> secondaryAnimation) {
        final Widget pageChild = Builder(builder: builder);
        Widget dialog = themes?.wrap(pageChild) ?? pageChild;
        if (useSafeArea) {
          dialog = SafeArea(child: dialog);
        }
        return dialog;
      },
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor,
      barrierLabel: barrierLabel,
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: _buildMaterialDialogTransitions,
      settings: settings,
    );
    return push(route);
  }
}

Widget _buildMaterialDialogTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child) {
  return FadeTransition(
    opacity: CurvedAnimation(
      parent: animation,
      curve: Curves.easeOut,
    ),
    child: child,
  );
}

void _navDelegate(NavAction action) {
  NavigatorDelegate(action).init();
}

Tween<Offset>? _getOffsetFrom(Position position) {
  Tween<Offset>? offset;
  switch (position) {
    case Position.top:
      offset =
          Tween(begin: const Offset(0.0, -1.0), end: const Offset(0.0, 0.0));
      break;
    case Position.left:
      offset =
          Tween(begin: const Offset(-1.0, 0.0), end: const Offset(0.0, 0.0));
      break;
    case Position.bottom:
      offset =
          Tween(begin: const Offset(0.0, 1.0), end: const Offset(0.0, 0.0));
      break;
    case Position.right:
      offset =
          Tween(begin: const Offset(1.0, 0.0), end: const Offset(0.0, 0.0));
      break;
    default:
  }
  return offset;
}

OverlayMixinDelegate showOverlay(
  Widget content, {
  Duration duration = const Duration(seconds: 3),
  Duration animationDuration = const Duration(milliseconds: 300),
  Duration delayDuration = Duration.zero,
  bool? closeOndismissed,
  Color? color,
  BorderRadius? radius,
  bool removeAll = true,
  double? left = 0,
  double? right = 0,
  double? top = 0,
  double? bottom = 0,
  EdgeInsets? margin,
  Position position = Position.none,
  Object? showKey,
  void Function(OverlayMixin owner)? onTap,
  Widget Function(BuildContext context, Widget child)? builder,
  Widget Function(
          Widget child, UserGestureController<OverlayPannelBuilder> controller)?
      transition,
}) {
  final offset = _getOffsetFrom(position);

  final controller = OverlayPannelBuilder(
    showKey: showKey,
    closeOndismissed: closeOndismissed ?? true,
    stay: duration,
    builder: (context, self) {
      final key = GlobalKey();

      Widget Function(Widget child)? localTransition;
      if (transition != null) {
        localTransition = (Widget child) {
          return transition(child, self);
        };
      } else if (offset != null) {
        localTransition = (Widget child) {
          return AnimatedBuilder(
            animation: self.userGesture,
            builder: (context, _) {
              if (self.userGesture.value) {
                final position = self.owner.controller.drive(offset);

                return SlideTransition(position: position, child: child);
              }

              return CurvedAnimationWidget(
                builder: (context, animation) {
                  final position = animation.drive(offset);
                  return SlideTransition(position: position, child: child);
                },
                controller: self.owner.controller,
              );
            },
          );
        };
      }

      VoidCallback? _onTap;
      if (onTap != null) {
        _onTap = () {
          onTap(self.owner);
        };
      }
      return OverlaySideGesture(
        sizeKey: key,
        entry: self,
        top: position == Position.bottom ? null : top,
        left: position == Position.right ? null : left,
        right: position == Position.left ? null : right,
        bottom: position == Position.top ? null : bottom,
        transition: localTransition,
        onTap: _onTap,
        builder: (context) {
          Widget child = OverlayWidget(
            content: content,
            sizeKey: key,
            color: color,
            radius: radius,
            margin: margin,
            removeAll: removeAll,
            position: position,
          );
          if (builder != null) {
            child = builder(context, child);
          }
          return child;
        },
      );
    },
  );

  return OverlayMixinDelegate(controller, animationDuration,
      delayDuration: delayDuration)
    ..show();
}
