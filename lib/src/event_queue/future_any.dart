import 'dart:async';

class FutureAny {
  final _tasks = <Future>{};

  int get length => _tasks.length;

  bool get isEmpty => length == 0;
  bool get isNotEmpty => !isEmpty;
  
  Completer<void>? _completer;

  Future? get future {
    if (_tasks.isNotEmpty) _set();
    return _completer?.future;
  }

  Future? get waitAll async {
    while (isNotEmpty) {
      await future;
    }
  }

  void _set() {
    if (_completer == null || _completer!.isCompleted) {
      _completer = Completer<void>();
    }
  }

  void _completed() {
    if (_completer?.isCompleted == false) {
      _completer?.complete();
    }
  }

  void add(Future task) {
    _tasks.add(task
      ..whenComplete(() {
        _tasks.remove(task);
        _completed();
      }));
  }

  void addAll(Iterable<Future> tasks) {
    for (final _task in tasks) {
      add(_task);
    }
  }
}
