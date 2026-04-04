import 'dart:async';
import 'dart:convert';

import 'package:eventsource/eventsource.dart';

import '../constants.dart';
import '../data/models/sugar_log_event.dart';
import 'auth_helper.dart';

class SugarLogStreamService {
  EventSource? _eventSource;
  final StreamController<SugarLogEvent> _controller =
      StreamController<SugarLogEvent>.broadcast();
  StreamSubscription<Event>? _subscription;

  Stream<SugarLogEvent> get stream => _controller.stream;

  Future<void> start() async {
    final token = await AuthHelper.getNetworkToken();
    if (token == null) {
      return;
    }
    await stop();
    try {
      _eventSource = await EventSource.connect(
        '$baseUrl/api/sugarlogs/stream',
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'text/event-stream',
        },
      );
      _subscription = _eventSource?.listen(
        (event) {
          if (event.event != 'sugar-log-updated' || event.data == null) {
            return;
          }
          try {
            final decoded = jsonDecode(event.data!) as Map<String, dynamic>;
            _controller.add(SugarLogEvent.fromJson(decoded));
          } catch (error) {
            _controller.addError(error);
          }
        },
        onError: (error) => _controller.addError(error),
      );
    } catch (error) {
      _controller.addError(error);
    }
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    _eventSource?.client.close();
    _eventSource = null;
  }

  Future<void> dispose() async {
    await stop();
    await _controller.close();
  }
}
