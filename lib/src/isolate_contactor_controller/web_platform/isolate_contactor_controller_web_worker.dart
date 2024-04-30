import 'dart:async';
import 'dart:html';

import 'package:isolate_contactor/src/utils/exception.dart';
import 'package:isolate_contactor/src/utils/utils.dart';

import '../../isolate_contactor.dart';
import '../isolate_contactor_controller_web.dart';

class IsolateContactorControllerImplWorker<R, P>
    implements IsolateContactorControllerImpl<R, P> {
  late Worker _delegate;

  final StreamController<R> _mainStreamController =
      StreamController.broadcast();
  final StreamController<P> _isolateStreamController =
      StreamController.broadcast();

  final bool autoMarkAsInitialized;
  final void Function()? onDispose;
  final IsolateConverter<R> workerConverter;
  dynamic _initialParams;

  @override
  Completer<void> ensureInitialized = Completer();

  IsolateContactorControllerImplWorker(
    dynamic params, {
    required this.autoMarkAsInitialized,
    required this.onDispose,
    required IsolateConverter<R> converter, // Converter for native
    required this.workerConverter, // Converter for Worker (Web Only)
  }) {
    if (params is List) {
      _delegate = params.last.controller;
      _initialParams = params.first;
    } else {
      _delegate = params;
    }

    _delegate.onMessage.listen((event) {
      if (event.data == IsolateState.dispose.isValidJson(event.data)) {
        onDispose!();
        close();
        return;
      }

      if (IsolateState.initialized.isValidJson(event.data)) {
        if (!ensureInitialized.isCompleted) {
          ensureInitialized.complete();
        }
        return;
      }

      if (IsolateException.isValidObject(event.data)) {
        final exception = IsolateException.fromJson(event.data);
        _mainStreamController.addError(
            exception.error.toString(), StackTrace.empty);
        return;
      }

      // Decode json from string which sent from isolate
      _mainStreamController.add(workerConverter(event.data));
    });

    // Compatible with version `<=4.1.0`.
    if (autoMarkAsInitialized && !ensureInitialized.isCompleted) {
      ensureInitialized.complete();
    }
  }

  @override
  Worker get controller => _delegate;

  /// Get initial params for `createOwnIsolate`
  @override
  dynamic get initialParams => _initialParams;

  @override
  Stream<R> get onMessage => _mainStreamController.stream;

  @override
  Stream<P> get onIsolateMessage => _isolateStreamController.stream;

  @override
  Future<void> initialized() => throw UnimplementedError();

  @override
  void sendIsolate(P message) {
    try {
      _delegate.postMessage(message);
    } catch (_) {
      // The delegate may be closed
    }
  }

  @override
  void sendIsolateState(Object state) {
    try {
      _delegate.postMessage(state);
    } catch (_) {
      // The delegate may be closed
    }
  }

  @override
  void sendResult(R message) => throw UnimplementedError();

  @override
  void sendResultError(IsolateException exception) =>
      throw UnimplementedError();

  @override
  Future<void> close() async {
    _delegate.terminate();
    await Future.wait([
      _mainStreamController.close(),
      _isolateStreamController.close(),
    ]);
  }
}
