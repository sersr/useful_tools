import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nop/event_queue.dart';
import 'package:nop/utils.dart';

class TextAsyncBuilder {
  static Future<R> runTextPainter<R>(Future<R> Function() task) {
    return EventQueue.run(textPainter, task);
  }

  static Future<List<TextPainter>> oneTextPainter({
    required String text,
    required double width,
    required TextStyle style,
    int? maxLines,
    String? ellipsis,
    TextDirection dir = TextDirection.ltr,
    bool Function(int endPosition, Characters paragraph, String currentLine)?
        addText,
  }) {
    return EventQueue.run(
      textPainter,
      () => textPainter(
        text: text,
        width: width,
        style: style,
        maxLines: maxLines,
        ellipsis: ellipsis,
        dir: dir,
        addText: addText,
      ),
    );
  }

  static bool printTryCount = false;

  /// 文本异步布局实现
  ///
  /// [TextPainter]只能在Main Isolate中使用
  /// 对于长文本来说,调用`layout`会占用很大的资源,对于低端手机会出现`jank`情况
  /// 在[ListView]中问题更为显著
  ///
  /// 使用`characters`包,正确的裁剪文本
  ///
  /// 裁剪尽可能短的文本进行`layout`,根据布局的信息就可以得到一行的长度,
  /// 每一次的`layout`之后,会回到事件循环中,由`engine`调度,
  /// 因为UI的优先级高于[Timer]
  ///
  /// 而vsync之间是有可能有间隙的,一般GC会在后面调用
  /// 这些时间dart事件机制会充分使用
  static Future<List<TextPainter>> textPainter({
    required String text,
    required double width,
    required TextStyle style,
    int? maxLines,
    String? ellipsis,
    TextDirection dir = TextDirection.ltr,
    bool Function(int endPosition, Characters paragraph, String currentLine)?
        addText,
  }) async {
    final paragraphs = LineSplitter.split(text).toList();

    final fontSize = style.fontSize!;
    final words = width ~/ fontSize;

    final linesText = <TextPainter>[];

    final t = TextPainter(textDirection: dir);

    final positionOffset = Offset(width, 0.1);

    var count = 0;

    for (var i = 0; i < paragraphs.length; i++) {
      final paragraph = paragraphs[i].characters;
      var start = 0;
      final paraLength = paragraph.length;

      while (start < paraLength) {
        if (maxLines != null && count >= maxLines) break;
        count++;
        final atEnd = count == maxLines;

        var end = math.min(start + words, paraLength);
        await idleWait;
        var tryCount = 0;
        // 确定每一行的字数
        while (true) {
          assert(tryCount++ == 0 ||
              !printTryCount ||
              Log.i('tryCount: $tryCount'));
          end += 4;
          final spc = paragraph.getRange(start, end);
          final s = spc.toString();
          t
            ..text = TextSpan(text: s, style: style)
            ..layout(maxWidth: width);

          await idleWait;

          if (t.computeLineMetrics().length > 1) {
            final textPosition = t.getPositionForOffset(positionOffset);
            var endOffset = textPosition.offset;
            var realLines = s.substring(0, endOffset).characters;
            final realLength = realLines.length;

            assert(endOffset == realLength ||
                Log.i('$realLines | $realLength | $endOffset'));
            if (atEnd) {
              realLines = spc.getRange(0, math.min(spc.length, realLength + 3));
            }

            if (realLines.isEmpty) break;

            end = start + realLines.length;
            break;
          }

          /// 经过一次布局之后,确定不会超过一行
          if (end >= paraLength) break;
        }

        await idleWait;
        final currentLine = paragraph.getRange(start, end).toString();
        start = end;
        if (addText == null || addText(end, paragraph, currentLine)) {
          TextPainter text;
          if (atEnd) {
            text = TextPainter(
              text: TextSpan(text: currentLine, style: style),
              maxLines: 1,
              ellipsis: ellipsis,
              textDirection: dir,
            )..layout(maxWidth: width);
          } else {
            text = TextPainter(
                text: TextSpan(text: currentLine, style: style),
                textDirection: dir)
              ..layout(maxWidth: width);
          }
          await idleWait;
          linesText.add(text);
        }
      }
    }
    return linesText;
  }
}
