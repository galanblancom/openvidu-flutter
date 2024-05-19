import 'package:openviduflutter/utils/session.dart';
import 'participant.dart';

class RemoteParticipant extends Participant {
  RemoteParticipant(
      String connectionId, String participantName, Session session)
      : super.withConnectionId(connectionId, participantName, session) {
    session.addRemoteParticipant(this);
  }

  changeCameraStatus(bool newValue) {
    mediaStream?.getVideoTracks().forEach((element) {
      element.enabled = newValue;
    });

    isCameraActive = newValue;
  }

  changeMicrophoneStatus(bool newValue) {
    mediaStream?.getAudioTracks().forEach((element) {
      element.enabled = newValue;
    });

    isAudioActive = newValue;
  }
}
