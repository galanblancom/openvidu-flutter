import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'dart:async';

import 'package:openviduflutter/utils/session.dart';

class Participant {
  String? connectionId;
  String participantName;
  Session session;
  List<RTCIceCandidate> iceCandidateList = [];
  RTCPeerConnection? peerConnection;
  MediaStream? mediaStream;
  MediaStreamTrack? audioTrack;
  MediaStreamTrack? videoTrack;
  bool isAudioActive = true;
  bool isCameraActive = true;

  Participant(this.participantName, this.session);

  Participant.withConnectionId(
      this.connectionId, this.participantName, this.session);

  switchCamera() {
    if (videoTrack != null) {
      Helper.switchCamera(videoTrack!);
    }
  }

  toggleCamera() {
    if (videoTrack != null) {
      videoTrack!.enabled = !videoTrack!.enabled;
      isCameraActive = videoTrack!.enabled;
    }
  }

  toggleMicrophone() {
    if (audioTrack != null) {
      audioTrack!.enabled = !audioTrack!.enabled;
      isAudioActive = audioTrack!.enabled;
    }
  }

  Future<void> dispose() async {
    try {
      await peerConnection?.close();
    } catch (e) {
      print('Dispose PeerConnection: $e');
    }
  }
}
