import 'dart:convert';

import 'api-client.dart';
import 'request-config.dart';

class ApiService {
  final String sessionId;
  final String url;
  final String secret;

  ApiService(this.sessionId, this.url, this.secret);

  Future<dynamic> createSession() {
    final Map<String, dynamic> bodyMap = <String, dynamic>{
      'customSessionId': sessionId
    };
    final Map<String, dynamic> headersMap = <String, dynamic>{
      'Authorization':
          'Basic ${base64Encode(utf8.encode('OPENVIDUAPP:$secret'))}'
    };
    return ApiClient()
        .request(Config(
            uri: Uri.parse('https://$url/api/sessions'),
            headers: headersMap,
            body: RequestBody.json(bodyMap),
            method: RequestMethod.post,
            responseType: ResponseBody.plain()))
        .then((dynamic jsonResponse) {
      return jsonResponse;
    }).catchError((error) {
      print('createSession error: $error');
      return sessionId;
    });
  }

  Future<dynamic> createToken({String role = 'PUBLISHER'}) {
    final Map<String, dynamic> bodyMap = <String, dynamic>{};
    final Map<String, dynamic> headersMap = <String, dynamic>{
      'Authorization':
          'Basic ${base64Encode(utf8.encode('OPENVIDUAPP:$secret'))}'
    };

    //api/sessions/<SESSION_ID>/connection
    return ApiClient()
        .request(Config(
            uri: Uri.parse('https://$url/api/sessions/$sessionId/connections'),
            headers: headersMap,
            body: RequestBody.json(bodyMap),
            method: RequestMethod.post,
            responseType: ResponseBody.plain()))
        .then((dynamic tokenResponse) {
      return tokenResponse;
    });
  }
}
