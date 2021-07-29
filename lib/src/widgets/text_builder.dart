// ignore_for_file: unused_import

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:useful_tools/useful_tools.dart';

typedef TextInfoBuilder = Widget Function(List<TextInfo>? infos, bool error);

class TextBuilder extends StatefulWidget {
  const TextBuilder({
    Key? key,
    required this.keys,
    required this.layout,
    required this.builder,
  }) : super(key: key);

  final List keys;
  final TextLayoutCallback layout;
  final TextInfoBuilder builder;
  @override
  State<TextBuilder> createState() => _TextBuilderState();
}

class _TextBuilderState extends State<TextBuilder> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _subText();
  }

  @override
  void didUpdateWidget(TextBuilder o) {
    super.didUpdateWidget(o);
    if (widget.keys != o.keys || widget.layout != o.layout) _subText();
  }

  List<TextInfo>? textInfos;
  bool _error = false;

  void _subText() {
    final all = textCache!.putIfAbsent(widget.keys, widget.layout);

    if (all != _textStream) {
      _textStream?.removeListener(onTextListener);
      all.addListener(onTextListener);
      _textStream = all;
    }
  }

  TextStream? _textStream;

  void onTextListener(List<TextInfo>? infos, bool error) {
    setState(() {
      textInfos?.forEach(disposeTextInfo);
      textInfos = infos;
      _error = error;
    });
  }

  @override
  void dispose() {
    super.dispose();
    textInfos?.forEach(disposeTextInfo);
    _textStream?.removeListener(onTextListener);
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(textInfos, _error);
  }
}
