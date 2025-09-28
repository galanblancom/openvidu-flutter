import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'request_config.dart';

Logger _logger = Logger('ApiClient');

class ApiClient {
  final HttpClient client = HttpClient();

  void setBadCertificateCallBack(
      bool Function(X509Certificate, String, int)? callback) {
    client.badCertificateCallback = callback;
  }

  Map<String, String> get getDefaultHeaders {
    final Map<String, String> defaultHeaders = <String, String>{};
    return defaultHeaders;
  }

  /// Use this instead of [getAction], [postAction] and [putAction]
  Future<dynamic> request(Config config, {bool autoLogin = false}) async {
    _logger
        .info('[${config.method}] Sending request: ${config.uri.toString()}');

    final HttpClientRequest clientRequest = await client
        .openUrl(config.method, config.uri)
        .then((HttpClientRequest request) => _addHeaders(request, config))
        .then((HttpClientRequest request) => _addCookies(request, config))
        .then((HttpClientRequest request) => _addBody(request, config));

    final HttpClientResponse response = await clientRequest.close();

    _logger.info(
        '[${config.method}] Received: ${response.reasonPhrase} [${response.statusCode}] - ${config.uri.toString()}');

    if (response.statusCode == HttpStatus.ok) {
      return config.hasResponse
          ? Future.value(config.responseType?.parse(response))
          : Future<HttpClientResponse>.value(response);
    }

    return await _processError(response, config,
        onAutoLoginSuccess: () => request(config));
  }

  HttpClientRequest _addBody(HttpClientRequest request, Config config) {
    if (config.hasBody) {
      request.headers.contentType = config.body?.getContentType();
      request.contentLength =
          const Utf8Encoder().convert(config.body?.getBody() ?? "").length;
      request.write(config.body?.getBody());
    }

    return request;
  }

  HttpClientRequest _addCookies(HttpClientRequest request, Config config) {
    config.cookies.forEach((String key, dynamic value) => value is Cookie
        ? request.cookies.add(value)
        : request.cookies.add(Cookie(key, value)));

    return request;
  }

  HttpClientRequest _addHeaders(HttpClientRequest request, Config config) {
    // Add default headers
    getDefaultHeaders.forEach(
        (String key, dynamic value) => request.headers.add(key, value));

    // Add config headers
    config.headers.forEach(
        (String key, dynamic value) => request.headers.add(key, value));

    return request;
  }

  Future<dynamic> _processError(HttpClientResponse response, Config config,
      {required Future<dynamic> Function() onAutoLoginSuccess}) async {
    final PenkalaError penkalaError =
        await PenkalaError.parseError(response, config);

    return Future<dynamic>.error(penkalaError);
  }
}

class PenkalaError {
  final HttpClientResponse response;
  final Config config;

  bool shouldShow = true;
  ErrorType errorType;
  final StringBuffer _presentableError = StringBuffer();

  PenkalaError(
    this.response,
    this.config, {
    this.errorType = ErrorType.unknown,
  });

  String? get errorString =>
      _presentableError.isEmpty ? null : _presentableError.toString();

  @override
  String toString() {
    return 'PenkalaError :: $errorString';
  }

  /// Get more info about Request error
  /// Will set up error type and string for specific error
  /// Toggles [shouldShow] flag to false if error dialog is not needed to pop up for this error
  Future<Null> _processError() async {
    _logger.info(
        'Processing error : [${response.statusCode}] - ${response.reasonPhrase}');
    final String responseData = await utf8.decodeStream(response);
    final Map<dynamic, dynamic> errorJson = jsonDecode(responseData);

    switch (response.statusCode) {
      /// Start auto-login procedure if we receive status code 498
      /// 498 Invalid Token (Esri)
      /// Returned by ArcGIS for Server. Code 498 indicates an expired or otherwise invalid token.
      case 498:
        continue unknown;

      /// Error 401 is thrown when user is unauthorized to access this endpoint.
      /// App should never call endpoint that will receive '401' if user is logged in
      case 401:
        errorType = ErrorType.unauthorized;
        break;

      /// Error 409 is thrown when an already openVidu named session is alive.
      case 409:
        errorType = ErrorType.sessionAlready;
        break;

      /// Bad gateway. Usually means there is server fix/deploy on the way.
      case 502:
        errorType = ErrorType.badGateway;
        break;

      /// Bad request. Get error code from response data JSON saved in field
      /// 'error_code'. This will give us detailed info about error defined by server for this app.
      ///
      /// Codes are defined here: https://docs.hot-soup.com/penkala-api/index.html#response-codes
      case 400:
        switch (errorJson['error_code'] ?? -1) {
          case 186:
            errorType = ErrorType.missingSignatureImages;
            break;
          case 187:
            errorType = ErrorType.signatureApprovalNeeded;
            break;
          default:
            errorType = ErrorType.badRequest;
            break;
        }
        break;
      unknown:
      default:
        errorType = ErrorType.unknown;

        _logger.info(
            'UNKNOWN ERROR! ${response.statusCode} - [${response.reasonPhrase}]');
        _logger.info('URL: ${config.uri.toString()}');
        _logger.info('Headers: ${config.headers.toString()}');
        _logger.info('Body: ${config.body?.getBody()}');
        _logger.info('Data: $responseData');

        break;
    }

    if (errorType == ErrorType.sessionAlready) {
      _presentableError.writeln('409 - Session already created. Join in..');
      _logger.info(_presentableError);
    } else if (errorType == ErrorType.badGateway) {
      _presentableError.writeln('502 - Bad Gateway (deploy is on the way?)');
    } else {
      try {
        if (errorJson.containsKey('errors')) {
          _logger.info(errorJson['errors']);
        } else {
          _presentableError
              .writeln(errorJson['error_msg'] ?? 'Something went wrong!');
        }

        _logger.info('Error: ${errorType.toString()}');
      } catch (exception) {
        _logger.info('Exception proccessing error: $exception');
      }
    }
  }

  static Future<PenkalaError> parseError(
      HttpClientResponse response, Config config) async {
    final PenkalaError error = PenkalaError(response, config);
    await error._processError();
    return Future<PenkalaError>.value(error);
  }
}

enum ErrorType {
  tokenExpired,
  badGateway,
  badRequest,
  unauthorized,
  unknown,
  noConnection,
  signatureApprovalNeeded,
  missingSignatureImages,
  sessionAlready
}
