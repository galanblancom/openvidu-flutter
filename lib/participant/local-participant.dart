import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:openvidutest/utils/session.dart';
import 'participant.dart';

class LocalParticipant extends Participant {
  late MediaStream localStream;
  List<RTCIceCandidate> localIceCandidates = [];
  RTCSessionDescription? localSessionDescription;

  LocalParticipant(String participantName, Session session)
      : super(participantName, session) {
    session.localParticipant = this;
  }

  void storeIceCandidate(RTCIceCandidate iceCandidate) {
    localIceCandidates.add(iceCandidate);
  }

  List<RTCIceCandidate> getLocalIceCandidates() {
    return localIceCandidates;
  }

  void storeLocalSessionDescription(RTCSessionDescription sessionDescription) {
    localSessionDescription = sessionDescription;
  }

  RTCSessionDescription? getLocalSessionDescription() {
    return localSessionDescription;
  }
/*
  @override
  Future<void> dispose() async {
    super.dispose();
    localRenderer.srcObject = null;
    localStream.dispose();
  }*/

  Future<MediaStream> startLocalCamera() async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': {
        'mandatory': {
          'minWidth': '320',
          'minHeight': '240',
          'minFrameRate': '30',
        },
        'facingMode': 'user',
        'optional': [],
      }
    };
    localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    localStream.getAudioTracks().forEach((track) {
      audioTrack = track;
    });
    localStream.getVideoTracks().forEach((track) {
      videoTrack = track;
    });
    return localStream;
  }
}
