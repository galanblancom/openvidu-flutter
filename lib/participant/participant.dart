import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'dart:async';

import 'package:openviduflutter/utils/session.dart';

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

  switchCamera() {
    if (videoTrack != null) {
      Helper.switchCamera(videoTrack!);
    }
  }

  toggleVideo() {
    if (videoTrack != null) {
      videoTrack!.enabled = !videoTrack!.enabled;
      isVideoActive = videoTrack!.enabled;
    }
  }

  toggleAudio() {
    if (audioTrack != null) {
      audioTrack!.enabled = !audioTrack!.enabled;
      isAudioActive = audioTrack!.enabled;
    }
  }

  Future<void> dispose() async {
    try {
      await renderer.dispose();
      await peerConnection?.close();
    } catch (e) {
      print('Dispose PeerConnection: $e');
    }
  }
}
