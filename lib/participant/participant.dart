import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'dart:async';
import 'package:openvidu_flutter/utils/session.dart';
import 'package:logging/logging.dart';

var _logger = Logger('Participant');

class Participant {
  String? connectionId;
  String participantName;
  Session session;
  List<RTCIceCandidate> iceCandidateList = [];
  RTCPeerConnection? peerConnection;
  RTCVideoRenderer renderer = RTCVideoRenderer();
  MediaStream? mediaStream;
  MediaStreamTrack? audioTrack;
  MediaStreamTrack? videoTrack;
  bool isAudioActive = true;
  bool isVideoActive = true;

  Participant(this.participantName, this.session);

  Participant.withConnectionId(
      this.connectionId, this.participantName, this.session);

  Future<void> dispose() async {
    try {
      await audioTrack?.stop();
      await videoTrack?.stop();
      await mediaStream?.dispose();
      await renderer.dispose();
      await peerConnection?.close();
    } catch (e) {
      _logger.info('Dispose PeerConnection: $e');
    }
  }
}
