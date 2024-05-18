import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'dart:async';

import 'package:openvidutest/utils/session.dart';

class Participant {
  String? connectionId;
  String participantName;
  Session session;
  List<RTCIceCandidate> iceCandidateList = [];
  RTCPeerConnection? peerConnection;
  MediaStream? mediaStream;
  MediaStreamTrack? audioTrack;
  MediaStreamTrack? videoTrack;

  Participant(this.participantName, this.session);

  Participant.withConnectionId(
      this.connectionId, this.participantName, this.session);

  String? get getConnectionId => connectionId;

  set setConnectionId(String? connectionId) => this.connectionId = connectionId;

  String get getParticipantName => participantName;

  List<RTCIceCandidate> get getIceCandidateList => iceCandidateList;

  RTCPeerConnection? get getPeerConnection => peerConnection;

  set setPeerConnection(RTCPeerConnection? peerConnection) =>
      this.peerConnection = peerConnection;

  MediaStreamTrack? get getAudioTrack => audioTrack;

  set setAudioTrack(MediaStreamTrack? audioTrack) =>
      this.audioTrack = audioTrack;

  MediaStreamTrack? get getVideoTrack => videoTrack;

  set setVideoTrack(MediaStreamTrack? videoTrack) =>
      this.videoTrack = videoTrack;

  MediaStream? get getMediaStream => mediaStream;

  set setMediaStream(MediaStream? mediaStream) =>
      this.mediaStream = mediaStream;

  Future<void> dispose() async {
    try {
      await peerConnection?.close();
    } catch (e) {
      print('Dispose PeerConnection: $e');
    }
  }
}
