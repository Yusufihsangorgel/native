// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('mac-os')
library;

import 'dart:isolate';

import 'package:objective_c/src/internal.dart';
import 'package:test/test.dart';

void _failToMakeBlock((bool, SendPort) args) {
  final (blocking, reply) = args;
  final originalError = ArgumentError('Missing trampoline');
  try {
    if (blocking) {
      newBlockingBlockPort(
        (port, context, direct) => throw originalError,
        (_) {},
        true,
      );
    } else {
      newBlockPort((port, context) => throw originalError, (_) {}, true);
    }
    // ignore: avoid_catching_errors
  } on ArgumentError catch (error) {
    reply.send(identical(error, originalError));
  }
  // The failed maker must close its port so this isolate can exit naturally.
}

void main() {
  for (final blocking in [false, true]) {
    test('${blocking ? 'Blocking' : 'Listener'} maker failure preserves the '
        'legacy error and closes the port', () async {
      final reply = ReceivePort();
      final exited = ReceivePort();
      final isolate = await Isolate.spawn(
        _failToMakeBlock,
        (blocking, reply.sendPort),
        onExit: exited.sendPort,
        onError: reply.sendPort,
      );
      try {
        expect(await reply.first, isTrue);
        await exited.first.timeout(const Duration(seconds: 5));
      } finally {
        isolate.kill(priority: Isolate.immediate);
        reply.close();
        exited.close();
      }
    });
  }
}
