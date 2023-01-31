import 'dart:async';

import 'package:flutter/material.dart';

class AsyncText extends LeafRenderObjectWidget {
  const AsyncText.async(this.text, {Key? key})
      : needLayout = false,
        super(key: key);
  AsyncText({
    Key? key,
    required String? text,
    TextDirection textDirection = TextDirection.ltr,
    TextStyle? style,
    int? maxLines,
    String? ellipsis,
  })  : needLayout = true,
        text = TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: textDirection,
          maxLines: maxLines,
          ellipsis: ellipsis,
        ),
        super(key: key);

  final TextPainter text;
  final bool needLayout;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return AsyncTextRenderBox(text: text, needLayout: needLayout);
  }

  @override
  void updateRenderObject(
      BuildContext context, covariant AsyncTextRenderBox renderObject) {
    renderObject
      ..text = text
      ..needLayout = needLayout;
  }
}

class AsyncTextRenderBox extends RenderBox {
  AsyncTextRenderBox({required TextPainter text, required bool needLayout})
      : _textPainter = text,
        _needLayout = needLayout;

  TextPainter _textPainter;

  set text(TextPainter t) {
    _textPainter = t;
    markNeedsLayout();
  }

  bool _needLayout;
  set needLayout(bool n) {
    if (_needLayout == n) return;
    _needLayout = n;
    markNeedsLayout();
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    if (_needLayout) _textPainter.layout(maxWidth: constraints.maxWidth);
    return constraints.constrain(_textPainter.size);
  }

  @override
  void performLayout() {
    if (_needLayout) _textPainter.layout(maxWidth: constraints.maxWidth);
    size = constraints.constrain(_textPainter.size);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    _textPainter.paint(context.canvas, offset);
  }
}

typedef AsyncTextBuilder = AsyncBuilder<List<List<TextPainter>?>>;

class AsyncBuilder<T> extends StatefulWidget {
  const AsyncBuilder({
    Key? key,
    required this.builder,
    required this.layout,
    this.palceholder,
  }) : super(key: key);

  final Future<T> Function(BuildContext context, bool Function() mounted)
      layout;
  final Widget Function(BuildContext context, T data) builder;
  final Widget? palceholder;

  @override
  State<AsyncBuilder<T>> createState() => _AsyncBuilderState<T>();
}

class _AsyncBuilderState<T> extends State<AsyncBuilder<T>> {
  @override
  void didUpdateWidget(covariant AsyncBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _layoutText();
  }

  @override
  void initState() {
    super.initState();
    _layoutText();
  }

  var _layoutKey = Object();
  T? data;
  void _layoutText() async {
    final key = _layoutKey = Object();
    final newData = await widget.layout(context, getMouted);
    if (key == _layoutKey && mounted) {
      setState(() {
        data = newData;
      });
    }
  }

  bool getMouted() {
    return mounted;
  }

  @override
  Widget build(BuildContext context) {
    final localData = data;
    if (localData != null) {
      return widget.builder(context, localData);
    }
    return widget.palceholder ?? const SizedBox();
  }
}
