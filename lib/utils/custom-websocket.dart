import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:logging/logging.dart';
import 'package:openviduflutter/constants/json-constants.dart';
import 'package:openviduflutter/participant/remote-participant.dart';
import 'package:openviduflutter/utils/pair.dart';
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

  CustomWebSocket(this.session);

  void connect() async {
    try {
      webSocket = await WebSocket.connect(getWebSocketAddress());

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

  String getWebSocketAddress() {
    final uri = Uri.parse(session.token);
    final port = uri.port != -1 ? ':${uri.port}' : '';
    return '${uri.scheme}://${uri.host}$port/openvidu';
  }

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

  void handleServerError(Map<String, dynamic> json) {
    final error = json[JsonConstants.error];
    final errorCode = error['code'];
    final errorMessage = error['message'];
    _logger.severe('Server error code $errorCode: $errorMessage');
  }

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
      default:
        _logger.severe(
            " *************************************************************** ");
        _logger.severe(
            " *************** Unknown server event '$method'  *************** ");
        _logger.severe(
            " *************************************************************** ");
    }
  }

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

  void leaveRoom() {
    idLeaveRoom = sendJson(JsonConstants.leaveRoomMethod);
  }

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

  void changeStreamAudio(String streamId, bool newValue) {
    streamPropertyChange(
      streamId: streamId,
      property: 'audioActive',
      newValue: newValue,
      reason: 'publishAudio',
    );
  }

  void changeStreamVideo(String streamId, bool newValue) {
    streamPropertyChange(
      streamId: streamId,
      property: 'videoActive',
      newValue: newValue,
      reason: 'publishVideo',
    );
  }

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

    session.createRemotePeerConnection(remoteParticipant.connectionId!);
    return remoteParticipant;
  }

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

  void onConnected() {
    print('Connected');
    pingMessageHandler();
    joinRoom();
  }

  void onDisconnected() {
    print('Disconnected');
    websocketCancelled = true;
  }

  void onError(String error) {
    if (onErrorEvent != null) {
      onErrorEvent!(error);
    }
    session.leaveSession();
  }

  void pingMessageHandler() {
    pingTimer = Timer.periodic(Duration(seconds: pingMessageInterval), (timer) {
      final pingParams = <String, String>{
        'interval': '5000',
      };
      idPing = sendJson(JsonConstants.pingMethod, pingParams);
    });
  }

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
        print('Error in addRemoteParticipantsAlreadyInRoom: ${e.toString()}');
      }
    }
  }

  disconnect() {
    webSocket?.close();
    pingTimer?.cancel();
  }
}
