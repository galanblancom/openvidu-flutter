import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:logging/logging.dart';
import 'package:openvidu_flutter/constants/json_constants.dart';
import 'package:openvidu_flutter/participant/remote_participant.dart';
import 'package:openvidu_flutter/utils/pair.dart';
import 'session.dart';

typedef OnErrorEvent = void Function(String error);

class CustomWebSocket {
  final _logger = Logger("CustomWebSocket");

  final int pingMessageInterval = 5;
  final Session session;
  WebSocket? webSocket;
  Timer? pingTimer;
  bool websocketCancelled = false;
  int rpcId = 0;
  int idPing = -1;
  int idJoinRoom = -1;
  int idLeaveRoom = -1;
  int idPublishVideo = -1;
  final Map<int, Pair<String, String>> idsPrepareReceiveVideo = {};
  final Map<int, String> idsReceiveVideo = {};
  final Set<int> idsOnIceCandidate = <int>{};
  String? mediaServer;
  OnErrorEvent? onErrorEvent;
  HttpClient? customClient;

  CustomWebSocket(this.session, {this.customClient});

  /// Connects to the WebSocket server
  void connect() async {
    try {
      webSocket = await WebSocket.connect(getWebSocketAddress(),
          customClient: customClient);

      webSocket!.listen((data) {
        onTextMessage(data);
      }, onError: (error) {
        onError(error.toString());
      }, onDone: () {
        onDisconnected();
      });

      onConnected();
    } catch (e) {
      onError(e.toString());
      websocketCancelled = true;
    }
  }

  /// Returns the WebSocket address
  String getWebSocketAddress() {
    final uri = Uri.parse(session.token);
    final port = uri.port != -1 ? ':${uri.port}' : '';
    return '${uri.scheme}://${uri.host}$port/openvidu';
  }

  /// Handles the text message received from the WebSocket server
  void onTextMessage(String text) async {
    final json = jsonDecode(text);
    if (json.containsKey(JsonConstants.result)) {
      handleServerResponse(json);
    } else if (json.containsKey(JsonConstants.error)) {
      handleServerError(json);
    } else {
      handleServerEvent(json);
    }
  }

  /// Handles the server response
  Future<void> handleServerResponse(Map<String, dynamic> json) async {
    final rpcId = json[JsonConstants.id];
    final result = json[JsonConstants.result];

    if (result.containsKey('value') && result['value'] == 'pong') {
      _logger.info('pong');
    } else if (rpcId == idJoinRoom) {
      final localParticipant = session.localParticipant;
      final localConnectionId = result[JsonConstants.id];
      localParticipant!.connectionId = localConnectionId;

      if (result.containsKey(JsonConstants.iceServers)) {
        final jsonIceServers = result[JsonConstants.iceServers];
        final List<Map<String, dynamic>> iceServers = [];
        for (final Map<String, dynamic> iceServer in jsonIceServers) {
          if (iceServer.containsKey("urls")) {
            final urls = (iceServer['urls'] as List)
                .map((url) => url.toString())
                .toList();
            final Map<String, dynamic> iceServerBuilder = {
              'urls': urls,
              'username': iceServer['username'] ?? '',
              'credential': iceServer['credential'] ?? '',
            };
            iceServers.add(iceServerBuilder);
          }
          if (iceServer.containsKey("url")) {
            final Map<String, dynamic> iceServerBuilder = {
              'urls': [iceServer['url']],
              'username': iceServer['username'] ?? '',
              'credential': iceServer['credential'] ?? '',
            };
            iceServers.add(iceServerBuilder);
          }
        }
        session.setIceServers(iceServers);
      }

      final localPeerConnection = await session.createLocalPeerConnection();
      localParticipant.peerConnection = localPeerConnection;

      final sdpConstraints = <String, String>{
        'offerToReceiveAudio': 'false',
        'offerToReceiveVideo': 'false',
      };
      session.createOfferForPublishing(sdpConstraints);

      if (result[JsonConstants.value].isNotEmpty) {
        addRemoteParticipantsAlreadyInRoom(result);
      }
    } else if (rpcId == idLeaveRoom) {
      webSocket?.close(WebSocketStatus.goingAway);
    } else if (rpcId == idPublishVideo) {
      final localParticipant = session.localParticipant;
      final remoteSdpAnswer = RTCSessionDescription(
        result['sdpAnswer'],
        'answer',
      );
      localParticipant!.peerConnection!.setRemoteDescription(remoteSdpAnswer);
    } else if (idsPrepareReceiveVideo.containsKey(rpcId)) {
      final participantAndStream = idsPrepareReceiveVideo.remove(rpcId);
      final remoteParticipant =
          session.remoteParticipants[participantAndStream!.first];
      final streamId = participantAndStream.second;
      final remoteSdpOffer = RTCSessionDescription(
        result['sdpOffer'],
        'offer',
      );
      remoteParticipant?.peerConnection
          ?.setRemoteDescription(remoteSdpOffer)
          .then((_) {
        subscriptionInitiatedFromServer(remoteParticipant, streamId);
      });
    } else if (idsReceiveVideo.containsKey(rpcId)) {
      final id = idsReceiveVideo.remove(rpcId);
      if (mediaServer == 'kurento') {
        final sessionDescription = RTCSessionDescription(
          result['sdpAnswer'],
          'answer',
        );
        session.remoteParticipants[id]!.peerConnection!
            .setRemoteDescription(sessionDescription);
      }
    } else if (idsOnIceCandidate.contains(rpcId)) {
      idsOnIceCandidate.remove(rpcId);
    } else {
      _logger.severe('Unrecognized server response: $result');
    }
  }

  /// Handles the server error
  void handleServerError(Map<String, dynamic> json) {
    final error = json[JsonConstants.error];
    final errorCode = error['code'];
    final errorMessage = error['message'];
    _logger.severe('Server error code $errorCode: $errorMessage');
  }

  /// Handles the server event
  void handleServerEvent(Map<String, dynamic> json) {
    if (!json.containsKey(JsonConstants.method)) {
      _logger.severe(
          "Server event lacks a field '${JsonConstants.method}'; JSON: $json");
      return;
    }
    final method = json[JsonConstants.method];

    if (!json.containsKey(JsonConstants.params)) {
      _logger.severe(
          "Server event '$method' lacks a field '${JsonConstants.params}'; JSON: $json");
      return;
    }
    final params = json[JsonConstants.params];

    switch (method) {
      case JsonConstants.iceCandidate:
        iceCandidateEvent(params);
        break;
      case JsonConstants.participantJoined:
        participantJoinedEvent(params);
        break;
      case JsonConstants.participantPublished:
        participantPublishedEvent(params);
        break;
      case JsonConstants.participantLeft:
        participantLeftEvent(params);
        break;
      case JsonConstants.streamPropertyChanged:
        streamPropertyChangedEvent(params);
        break;
      case JsonConstants.sendMessage:
        sendMessageEvent(params);
        break;
      default:
        _logger.severe(
            " *************************************************************** ");
        _logger.severe(
            " *************** Unknown server event '$method'  *************** ");
        _logger.severe(
            " *************************************************************** ");
    }
  }

  /// Sends the joinRoom to WebSocket server
  void joinRoom() {
    final joinRoomParams = {
      JsonConstants.metadata:
          '{"clientData": "${session.localParticipant?.participantName}"}',
      'secret': '',
      'session': session.id,
      'platform':
          '${Platform.isAndroid ? "Android" : "iOS"} ${Platform.operatingSystemVersion}',
      'token': session.token,
      'sdkVersion': '2.29.0',
    };
    idJoinRoom = sendJson(JsonConstants.joinRoomMethod, joinRoomParams);
  }

  /// Sends the leaveRoom to WebSocket server
  void leaveRoom() {
    idLeaveRoom = sendJson(JsonConstants.leaveRoomMethod);
  }

  /// Sends the publishVideo to the WebSocket server
  void publishVideo(RTCSessionDescription sessionDescription) {
    final Map<String, String> publishVideoParams = {
      'audioActive': 'true',
      'videoActive': 'true',
      'doLoopback': 'false',
      'frameRate': '30',
      'hasAudio': 'true',
      'hasVideo': 'true',
      'typeOfVideo': 'CAMERA',
      'videoDimensions': '{"width":320, "height":240}',
      'sdpOffer': sessionDescription.sdp!,
    };
    idPublishVideo =
        sendJson(JsonConstants.publishVideoMethod, publishVideoParams);
  }

  /// Sends the streamPropertyChange to the WebSocket server
  /// Used to change the audio and video status of a stream
  void streamPropertyChange(
      {required String streamId,
      required String property,
      required dynamic newValue,
      required String reason}) {
    final Map<String, dynamic> streamPropertyChangeParams = {
      'streamId': streamId,
      'property': property,
      'newValue': newValue,
      'reason': reason,
    };
    sendJson(
        JsonConstants.streamPropertyChangedMethod, streamPropertyChangeParams);
  }

  /// Sends the changeStreamAudio to the WebSocket server
  void changeStreamAudio(String streamId, bool newValue) {
    streamPropertyChange(
      streamId: streamId,
      property: 'audioActive',
      newValue: newValue,
      reason: 'publishAudio',
    );
  }

  /// Sends the changeStreamVideo to the WebSocket server
  void changeStreamVideo(String streamId, bool newValue) {
    streamPropertyChange(
      streamId: streamId,
      property: 'videoActive',
      newValue: newValue,
      reason: 'publishVideo',
    );
  }

  /// Sends the sendMessage to the WebSocket server
  sendMessage(String message, String nickname) {
    final Map<String, String> sendMessageParams = {
      'message':
          "{\"to\":[],\"data\":\"{\\\"message\\\":\\\"$message\\\",\\\"nickname\\\":\\\"$nickname\\\"}\",\"type\":\"signal:chat\"}",
    };
    sendJson(JsonConstants.sendMessage, sendMessageParams);
  }

  /// Sends the prepareReceiveVideoFrom to the WebSocket server
  void prepareReceiveVideoFrom(
      RemoteParticipant remoteParticipant, String streamId) {
    final prepareReceiveVideoFromParams = {
      'sender': streamId,
      'reconnect': 'false',
    };
    idsPrepareReceiveVideo[sendJson(JsonConstants.prepareReceiveVideoMethod,
            prepareReceiveVideoFromParams)] =
        Pair(remoteParticipant.connectionId!, streamId);
  }

  /// Sends the receiveVideoFrom to the WebSocket server
  void receiveVideoFrom(RTCSessionDescription sessionDescription,
      RemoteParticipant remoteParticipant, String streamId) {
    final receiveVideoFromParams = {
      'sender': streamId,
    };
    if (mediaServer == 'kurento') {
      receiveVideoFromParams['sdpOffer'] = sessionDescription.sdp!;
    } else {
      receiveVideoFromParams['sdpAnswer'] = sessionDescription.sdp!;
    }
    idsReceiveVideo[sendJson(
            JsonConstants.receiveVideoMethod, receiveVideoFromParams)] =
        remoteParticipant.connectionId!;
  }

  /// Sends the onIceCandidate to the WebSocket server
  void onIceCandidate(RTCIceCandidate iceCandidate, String? endpointName) {
    final Map<String, String> onIceCandidateParams = {
      'candidate': iceCandidate.candidate!,
      'sdpMid': iceCandidate.sdpMid!,
      'sdpMLineIndex': iceCandidate.sdpMLineIndex.toString(),
    };
    if (endpointName != null) {
      onIceCandidateParams['endpointName'] = endpointName;
    }
    idsOnIceCandidate.add(
        sendJson(JsonConstants.onIceCandidateMethod, onIceCandidateParams));
  }

  /// Handles the iceCandidateEvent response
  Future<void> iceCandidateEvent(Map<String, dynamic> params) async {
    final iceCandidate = RTCIceCandidate(
      params['candidate'],
      params['sdpMid'],
      params['sdpMLineIndex'],
    );
    final connectionId = params['senderConnectionId'];
    final isRemote = session.localParticipant!.connectionId != connectionId;
    final participant = isRemote
        ? session.remoteParticipants[connectionId]
        : session.localParticipant;
    final pc = participant!.peerConnection;

    switch (pc!.signalingState) {
      case RTCSignalingState.RTCSignalingStateClosed:
        _logger
            .warning('saveIceCandidate error: PeerConnection object is closed');
        break;
      case RTCSignalingState.RTCSignalingStateStable:
        if (await pc.getRemoteDescription() != null) {
          pc.addCandidate(iceCandidate);
        } else {
          participant.iceCandidateList.add(iceCandidate);
        }
        break;
      default:
        participant.iceCandidateList.add(iceCandidate);
    }
  }

  void participantJoinedEvent(Map<String, dynamic> params) {
    newRemoteParticipantAux(params);
  }

  void participantPublishedEvent(Map<String, dynamic> params) {
    final remoteParticipantId = params[JsonConstants.id];
    final remoteParticipant = session.remoteParticipants[remoteParticipantId]!;
    final streamId = params['streams'][0]['id'];
    remoteParticipant.isAudioActive = params['streams'][0]['audioActive'];
    remoteParticipant.isVideoActive = params['streams'][0]['videoActive'];
    subscribe(remoteParticipant, streamId);
  }

  void participantLeftEvent(Map<String, dynamic> params) {
    session.removeRemoteParticipant(params['connectionId']);
  }

  void streamPropertyChangedEvent(Map<String, dynamic> params) {
    final RemoteParticipant? remoteParticipant =
        session.remoteParticipants[params['connectionId']];
    if (remoteParticipant != null) {
      final property = params['property'];
      final newValue = params['newValue'];

      if (property == 'videoActive') {
        remoteParticipant.changeCameraStatus(bool.parse(newValue));
      } else if (property == 'audioActive') {
        remoteParticipant.changeMicrophoneStatus(bool.parse(newValue));
      }

      if (remoteParticipant.onStreamChangeEvent != null) {
        remoteParticipant.onStreamChangeEvent!(params);
      }
    }
  }

  void sendMessageEvent(Map<String, dynamic> params) {
    session.addMessageReceived(params);
  }

  RemoteParticipant newRemoteParticipantAux(
      Map<String, dynamic> participantJson) {
    final connectionId = participantJson[JsonConstants.id];
    String participantName = '';
    if (participantJson.containsKey(JsonConstants.metadata)) {
      final metadata = participantJson[JsonConstants.metadata];
      try {
        final json = jsonDecode(metadata);
        final clientData = json['clientData'];
        if (clientData != null) {
          participantName = clientData;
        }
      } catch (e) {
        participantName = metadata;
      }
    }
    final remoteParticipant =
        RemoteParticipant(connectionId, participantName, session);
    if (session.onAddRemoteParticipant != null) {
      session.onAddRemoteParticipant!(connectionId);
    }
    session.createRemotePeerConnection(remoteParticipant.connectionId!);
    return remoteParticipant;
  }

  /// Subscribes to a remote participant
  void subscribe(RemoteParticipant remoteParticipant, String streamId) {
    if (mediaServer == 'kurento') {
      subscriptionInitiatedFromClient(remoteParticipant, streamId);
    } else {
      prepareReceiveVideoFrom(remoteParticipant, streamId);
    }
  }

  void subscriptionInitiatedFromClient(
      RemoteParticipant remoteParticipant, String streamId) {
    final sdpConstraints = <String, String>{
      'offerToReceiveAudio': 'true',
      'offerToReceiveVideo': 'true',
    };

    remoteParticipant.peerConnection!.createOffer(sdpConstraints).then((sdp) {
      remoteParticipant.peerConnection!.setLocalDescription(sdp).then((_) {
        receiveVideoFrom(sdp, remoteParticipant, streamId);
      });
    });
  }

  void subscriptionInitiatedFromServer(
      RemoteParticipant remoteParticipant, String streamId) {
    final sdpConstraints = <String, String>{
      'offerToReceiveAudio': 'true',
      'offerToReceiveVideo': 'true',
    };
    session.createAnswerForSubscribing(
        remoteParticipant, streamId, sdpConstraints);
  }

  /// Handles the connection to the WebSocket server
  void onConnected() {
    _logger.info('Connected');
    pingMessageHandler();
    joinRoom();
  }

  /// Handles the disconnection from the WebSocket server
  void onDisconnected() {
    _logger.info('Disconnected');
    websocketCancelled = true;
  }

  /// Handles the error from the WebSocket server
  void onError(String error) {
    if (onErrorEvent != null) {
      onErrorEvent!(error);
    }
    session.leaveSession();
  }

  /// Sends a ping message to the WebSocket server
  void pingMessageHandler() {
    pingTimer = Timer.periodic(Duration(seconds: pingMessageInterval), (timer) {
      final pingParams = <String, String>{
        'interval': '5000',
      };
      idPing = sendJson(JsonConstants.pingMethod, pingParams);
    });
  }

  /// Sends a JSON message to the WebSocket server
  int sendJson(String method, [Map<String, dynamic>? params]) {
    final id = rpcId;
    rpcId++;

    final jsonObject = <String, dynamic>{
      'jsonrpc': JsonConstants.jsonRpcVersion,
      'method': method,
      'id': id,
      'params': params ?? {},
    };

    final jsonString = jsonEncode(jsonObject);
    webSocket?.add(jsonString);
    return id;
  }

  /// Adds remote participants already in the room
  void addRemoteParticipantsAlreadyInRoom(Map<String, dynamic> result) {
    final List<dynamic> participants = result[JsonConstants.value];

    for (var participantJson in participants) {
      RemoteParticipant remoteParticipant =
          newRemoteParticipantAux(participantJson);

      try {
        List<dynamic> streams = participantJson['streams'];
        for (var stream in streams) {
          String streamId = stream['id'];
          remoteParticipant.isAudioActive = stream['audioActive'];
          remoteParticipant.isVideoActive = stream['videoActive'];
          subscribe(remoteParticipant, streamId);
        }
      } catch (e) {
        // Sometimes when entering a room, the other participants have no stream
        // Catching this to prevent stopping the iteration of participants
        _logger.info(
            'Error in addRemoteParticipantsAlreadyInRoom: ${e.toString()}');
      }
    }
  }

  /// Disconnects from the WebSocket server
  disconnect() {
    webSocket?.close();
    pingTimer?.cancel();
  }
}
