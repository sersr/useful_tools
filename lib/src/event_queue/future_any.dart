import 'dart:async';

class FutureAny {
  final _tasks = <Future>[];

  int get length => _tasks.length;

  bool get isEmpty => _tasks.isEmpty;
  bool get isNotEmpty => _tasks.isNotEmpty;

  Completer<void>? _completer;
  Completer<void>? _completerWaitAll;

  Future<void>? get any {
    _set();
    return _completer?.future;
  }

  Future<void>? get wait {
    _setWaitAll();
    return _completerWaitAll?.future;
  }

  void _set() {
    if (_completer == null || _completer!.isCompleted) {
      if (isNotEmpty) _completer = Completer<void>();
    }
  }

  void _setWaitAll() {
    if (_completerWaitAll == null || _completerWaitAll!.isCompleted) {
      if (isNotEmpty) _completerWaitAll = Completer<void>();
    }
  }

  void _completed() {
    /// any
    if (_completer?.isCompleted == false) {
      _completer!.complete();
    }

    /// waitAll
    if (isEmpty && _completerWaitAll?.isCompleted == false) {
      _completerWaitAll!.complete();
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
