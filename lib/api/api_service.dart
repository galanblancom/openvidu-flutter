import 'dart:convert';
import 'dart:io';
import 'api_client.dart';
import 'request_config.dart';
import 'package:logging/logging.dart';

var _logger = Logger('ApiService');

class ApiService {
  final String sessionId;
  final String url;
  final String secret;
  final bool Function(X509Certificate, String, int)? badCertificateCallback;
  late ApiClient apiClient;

  ApiService(this.sessionId, this.url, this.secret,
      [this.badCertificateCallback]) {
    apiClient = ApiClient();
    apiClient.setBadCertificateCallBack(badCertificateCallback);
  }

  Future<dynamic> createSession() {
    final Map<String, dynamic> bodyMap = <String, dynamic>{
      'customSessionId': sessionId
    };
    final Map<String, dynamic> headersMap = <String, dynamic>{
      'Authorization':
          'Basic ${base64Encode(utf8.encode('OPENVIDUAPP:$secret'))}'
    };
    return apiClient
        .request(Config(
            uri: Uri.parse('https://$url/api/sessions'),
            headers: headersMap,
            body: RequestBody.json(bodyMap),
            method: RequestMethod.post,
            responseType: ResponseBody.plain()))
        .then((dynamic jsonResponse) {
      return jsonResponse;
    }).catchError((error) {
      _logger.info('createSession error: $error');
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
    return apiClient
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
