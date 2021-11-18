import 'dart:async';

import 'package:stream_channel/isolate_channel.dart';
import 'enum.dart';
import 'isolate_contactor.dart';

class IsolateContactorController {
  late IsolateChannel _delegate;

  final StreamController _mainStreamController = StreamController.broadcast();
  final StreamController _messageStreamController =
      StreamController.broadcast();

  IsolateContactorController(dynamic params) {
    if (params is List) {
      _delegate = IsolateChannel.connectSend(params.last);
    } else {
      _delegate = IsolateChannel.connectReceive(params);
    }

    _delegate.stream.listen((event) {
      dynamic message = IsolateContactor.getRawMessage(IsolatePort.main, event);
      if (message != null) {
        _mainStreamController.add(message);
      }

      message = IsolateContactor.getRawMessage(IsolatePort.child, event);
      if (message != null) {
        _messageStreamController.add(message);
      }
    });
  }

  Stream get onMainMessage => _mainStreamController.stream;

  Stream get onMessage => _messageStreamController.stream;

  void sendIsolate(dynamic message) {
    _delegate.sink.add(<IsolatePort, dynamic>{IsolatePort.child: message});
  }

  void sendResult(dynamic message) {
    _delegate.sink.add(<IsolatePort, dynamic>{IsolatePort.main: message});
  }
}
