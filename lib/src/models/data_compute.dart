import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// Take your time to use function with isolate function, bye bye laggy
class DataCompute {
  // [function] insert your function here with args
  // [args] insert parameter to function
  Future<dynamic> isolate(Future Function(dynamic) function,
      {dynamic args}) async {
    if (kIsWeb) {
      return await compute(function, args);
      // return await function(args);
    }
    final ReceivePort receivePort = ReceivePort();
    RootIsolateToken rootToken = RootIsolateToken.instance!;
    await Isolate.spawn<_IsolateData>(
      _isolateEntry,
      _IsolateData(
        token: rootToken,
        function: function,
        answerPort: receivePort.sendPort,
        args: args,
      ),
    );
    return await receivePort.first;
  }

  // entry isolates for multi threading
  void _isolateEntry(_IsolateData isolateData) async {
    BackgroundIsolateBinaryMessenger.ensureInitialized(isolateData.token);
    final dynamic answer = await isolateData.function(isolateData.args);
    isolateData.answerPort.send(answer);
  }
}

// Isolate model for compute function needed
class _IsolateData {
  final RootIsolateToken token;
  final Function(dynamic) function;
  final SendPort answerPort;
  final dynamic args;

  // Isolate model for compute function needed
  _IsolateData({
    required this.token,
    required this.function,
    required this.answerPort,
    this.args,
  });
}
