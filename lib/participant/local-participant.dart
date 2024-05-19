import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:openviduflutter/utils/session.dart';
import 'participant.dart';

class LocalParticipant extends Participant {
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

  Future<void> startLocalCamera() async {
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
    mediaStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    mediaStream!.getAudioTracks().forEach((track) {
      audioTrack = track;
    });
    mediaStream!.getVideoTracks().forEach((track) {
      videoTrack = track;
    });

    renderer.srcObject = mediaStream;
  }
}
