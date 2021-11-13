// ignore_for_file: unused_import

import 'dart:math' as math;
import 'dart:ui' as ui;

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
  bool _sync = false;

  void _subText() {
    assert(textCache != null, 'CacheBinding 没有绑定');
    final all = textCache!.putIfAbsent(widget.keys, widget.layout);

    if (all != _textStream) {
      // 避免调用无用的微任务操作
      _textStream?.removeListener(onTextListener);
      all.addListener(onTextListener);
      _textStream = all;
    }
  }

  TextStream? _textStream;

  void onTextListener(List<TextInfo>? infos, bool sync) {
    setState(() {
      textInfos?.forEach(TextInfo.disposeTextInfo);
      textInfos = infos;
      _sync = sync;
    });
  }

  @override
  void dispose() {
    super.dispose();
    textInfos?.forEach(TextInfo.disposeTextInfo);
    _textStream?.removeListener(onTextListener);
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(textInfos, _sync);
  }
}
