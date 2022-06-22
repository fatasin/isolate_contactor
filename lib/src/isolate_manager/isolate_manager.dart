import 'dart:async';
import 'dart:collection';

import 'package:isolate_contactor/isolate_contactor.dart';

class IsolateQueue<R> {
  final Completer<R> completer = Completer<R>();
  final dynamic params;

  IsolateQueue(this.params);
}

class IsolateManager<R> {
  /// Number of concurrent isolates
  final int numOfIsolates;

  /// Isolate function
  final FutureOr<R> Function(dynamic) isolateFunction;

  /// Initial parameters
  final dynamic initialParams;

  /// Is using your own isolate function
  final bool isOwnIsolate;

  /// Allow print debug log
  final bool isDebug;

  /// Get value as stream
  Stream<R> get onMessage => _streamController.stream;

  IsolateManager({
    required this.numOfIsolates,
    required this.isolateFunction,
    this.initialParams,
    this.isOwnIsolate = false,
    this.isDebug = false,
  });

  /// Queue of isolates
  final Queue<IsolateQueue<R>> _queue = Queue();

  /// Map<IsolateContactor instance, isBusy>
  final Map<IsolateContactor<R>, bool> _isolates = {};

  /// Controller for stream
  final StreamController<R> _streamController = StreamController.broadcast();

  /// Start initialize IsolateManager
  Future<void> start() async {
    if (isOwnIsolate) {
      await Future.wait(
        [
          for (int i = 0; i < numOfIsolates; i++)
            IsolateContactor.createOwnIsolate<R>(
              isolateFunction,
              isolateParams: initialParams,
              debugMode: isDebug,
            ).then((value) => _isolates.addAll({value: false}))
        ],
      );
    } else {
      await Future.wait(
        [
          for (int i = 0; i < numOfIsolates; i++)
            IsolateContactor.create<R>(
              isolateFunction,
              debugMode: isDebug,
            ).then((value) => _isolates.addAll({value: false}))
        ],
      );
    }

    for (final isolate in _isolates.keys) {
      isolate.onMessage.listen((value) {
        _streamController.sink.add(value);
        if (_queue.isNotEmpty) {
          final queue = _queue.removeFirst();
          _excute(isolate, queue);
        }
      });

      /// Allow calling `compute` before `start`
      if (_queue.isNotEmpty) {
        final queue = _queue.removeFirst();
        _excute(isolate, queue);
      }
    }
  }

  /// Stop isolate manager
  void stop() {
    for (final isolate in _isolates.keys) {
      isolate.dispose();
    }
  }

  /// Compute isolate manager
  Future<R> compute(dynamic params) async {
    final queue = IsolateQueue<R>(params);

    print(_isolates);

    for (final isolate in _isolates.keys) {
      if (_isolates[isolate] == false) {
        return _excute(isolate, queue);
      }
    }

    _queue.add(queue);

    return queue.completer.future;
  }

  Future<R> _excute(IsolateContactor<R> isolate, IsolateQueue<R> queue) async {
    _isolates[isolate] = true;

    isolate.sendMessage(queue.params).then((value) {
      queue.completer.complete(value);
      _isolates[isolate] = false;
    });

    return queue.completer.future;
  }
}
