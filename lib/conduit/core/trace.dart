import 'package:flutter/foundation.dart';

/// Debug-only tracing.
///
/// The body runs inside an `assert`, so both the call and the message text are
/// dropped from release builds — log strings are as readable to a binary
/// scanner as they are to us.
void trace(String scope, Object? message) {
  assert(() {
    debugPrint('[LVR.$scope] $message');
    return true;
  }());
}
