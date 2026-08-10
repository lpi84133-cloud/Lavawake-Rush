import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/flow_settings.dart';
import '../core/trace.dart';
import '../models/relay_reply.dart';
import 'client_stamp.dart';

/// Single call to the configuration endpoint.
///
/// Every failure mode — transport, status, malformed body — collapses into a
/// denied reply. The boot sequence has one question to ask and must never have
/// to catch an exception to hear the answer.
class RelayExchange {
  RelayExchange({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<RelayReply> ask(Map<String, dynamic> body) async {
    try {
      final stamp = await ClientStamp.resolve();
      trace('relay', 'request $body');

      final response = await _client
          .post(
            Uri.parse(FlowSettings.relayEndpoint),
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'User-Agent': stamp,
            },
            body: jsonEncode(body),
          )
          .timeout(FlowSettings.relayTimeout);

      trace('relay', 'reply ${response.statusCode} ${response.body}');
      if (response.statusCode != 200) return const RelayReply.refused();

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return const RelayReply.refused();
      return RelayReply.fromJson(decoded.map((key, value) => MapEntry('$key', value)));
    } on Object catch (error) {
      trace('relay', 'failed: $error');
      return const RelayReply.unreachable();
    }
  }
}
