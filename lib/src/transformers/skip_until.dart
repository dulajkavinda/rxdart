import 'dart:async';

import 'package:rxdart/src/utils/forwarding_sink.dart';
import 'package:rxdart/src/utils/forwarding_stream.dart';

class _SkipUntilStreamSink<S, T> implements ForwardingSink<S> {
  final Stream<T> _otherStream;
  final EventSink<S> _outputSink;
  StreamSubscription<T> _otherSubscription;
  var _canAdd = false;

  _SkipUntilStreamSink(this._outputSink, this._otherStream);

  @override
  void add(S data) {
    if (_canAdd) {
      _outputSink.add(data);
    }
  }

  @override
  void addError(e, [st]) => _outputSink.addError(e, st);

  @override
  void close() {
    _otherSubscription?.cancel();
    _outputSink.close();
  }

  @override
  FutureOr onCancel() {}

  @override
  void onListen() => _otherSubscription = _otherStream
      .take(1)
      .listen(null, onError: addError, onDone: () => _canAdd = true);

  @override
  void onPause() {}

  @override
  void onResume() {}
}

/// Starts emitting events only after the given stream emits an event.
///
/// ### Example
///
///     MergeStream([
///       Stream.value(1),
///       TimerStream(2, Duration(minutes: 2))
///     ])
///     .transform(SkipUntilStreamTransformer(TimerStream(1, Duration(minutes: 1))))
///     .listen(print); // prints 2;
class SkipUntilStreamTransformer<S, T> extends StreamTransformerBase<S, S> {
  /// The [Stream] which is required to emit first, before this [Stream] starts emitting
  final Stream<T> otherStream;

  /// Constructs a [StreamTransformer] which starts emitting events
  /// only after [otherStream] emits an event.
  SkipUntilStreamTransformer(this.otherStream) {
    if (otherStream == null) {
      throw ArgumentError('otherStream cannot be null');
    }
  }

  @override
  Stream<S> bind(Stream<S> stream) {
    final forwardedStream = forwardStream<S>(stream);

    return Stream.eventTransformed(
        forwardedStream.stream,
        (sink) => forwardedStream
            .connect(_SkipUntilStreamSink<S, T>(sink, otherStream)));
  }
}

/// Extends the Stream class with the ability to skip events until another
/// Stream emits an item.
extension SkipUntilExtension<T> on Stream<T> {
  /// Starts emitting items only after the given stream emits an item.
  ///
  /// ### Example
  ///
  ///     MergeStream([
  ///         Stream.fromIterable([1]),
  ///         TimerStream(2, Duration(minutes: 2))
  ///       ])
  ///       .skipUntil(TimerStream(true, Duration(minutes: 1)))
  ///       .listen(print); // prints 2;
  Stream<T> skipUntil<S>(Stream<S> otherStream) =>
      transform(SkipUntilStreamTransformer<T, S>(otherStream));
}
