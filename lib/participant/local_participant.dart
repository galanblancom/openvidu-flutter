import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:openvidu_flutter/utils/session.dart';
import 'participant.dart';

class LocalParticipant extends Participant {
  List<RTCIceCandidate> localIceCandidates = [];
  RTCSessionDescription? localSessionDescription;
  bool isFrontCameraActive = true;

  LocalParticipant(String participantName, Session session)
      : super(participantName, session) {
    session.localParticipant = this;
  }

  Future<void> switchCamera() async {
    if (videoTrack != null) {
      isFrontCameraActive = await Helper.switchCamera(videoTrack!);
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

  sendMessage(String message) {
    session.websocket.sendMessage(message, participantName);
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

  Future<bool> getIsFrontCamera() async {
    // Enumerate all available media devices
    List<MediaDeviceInfo> devices =
        await navigator.mediaDevices.enumerateDevices();

    // Filter the devices to find video input devices
    List<MediaDeviceInfo> videoDevices =
        devices.where((device) => device.kind == 'videoinput').toList();

    // Match the track with the devices
    for (var device in videoDevices) {
      if (device.deviceId == videoTrack?.getSettings()["deviceId"]) {
        // Check if the device label contains "front" or "back"
        if (device.label.toLowerCase().contains('front')) {
          return true;
        } else if (device.label.toLowerCase().contains('back')) {
          return false;
        }
      }
    }

    // If the label does not explicitly mention "front" or "back", you may need additional logic
    // or assume a default (e.g., false for back camera)
    return false; // Default assumption
  }
}
