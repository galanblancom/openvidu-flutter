import 'package:openvidu_flutter/participant/participant.dart';
import 'package:openvidu_flutter/utils/session.dart';

typedef OnRemoteParticipantStreamChangeEvent = void Function(
    Map<String, dynamic>);

class RemoteParticipant extends Participant {
  OnRemoteParticipantStreamChangeEvent? onStreamChangeEvent;

  RemoteParticipant(
      String connectionId, String participantName, Session session)
      : super.withConnectionId(connectionId, participantName, session) {
    session.addRemoteParticipant(this);
  }

  void changeCameraStatus(bool newValue) {
    mediaStream?.getVideoTracks().forEach((element) {
      element.enabled = newValue;
    });

    isVideoActive = newValue;
  }

  void changeMicrophoneStatus(bool newValue) {
    mediaStream?.getAudioTracks().forEach((element) {
      element.enabled = newValue;
    });

    isAudioActive = newValue;
  }
}
