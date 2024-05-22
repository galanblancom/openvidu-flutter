import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:openvidu_flutter/participant/participant.dart';
import 'package:openvidu_flutter/participant/remote_participant.dart';
import 'package:openvidu_flutter/utils/utils.dart';

class ParticipantWidget extends StatefulWidget {
  final Participant participant;
  const ParticipantWidget({super.key, required this.participant});

  @override
  State<ParticipantWidget> createState() => _ParticipantWidgetState();
}

class _ParticipantWidgetState extends State<ParticipantWidget> {
  /// Refreshes the participant widget.
  void refresh() {
    if (context.mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    if (widget.participant is RemoteParticipant) {
      (widget.participant as RemoteParticipant).onStreamChangeEvent =
          (Map<String, dynamic> params) {
        refresh();
      };
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Stack(
        children: [
          widget.participant.isVideoActive
              ? RTCVideoView(widget.participant.renderer)
              : _noVideoPlaceholder(widget.participant.participantName),
          Positioned(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius:
                    const BorderRadius.only(bottomRight: Radius.circular(8.0)),
              ),
              padding: const EdgeInsets.only(left: 8.0, right: 8.0),
              child: Text(
                widget.participant.participantName,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius:
                    const BorderRadius.only(bottomRight: Radius.circular(8.0)),
              ),
              padding:
                  const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 8.0),
              child: Row(
                children: [
                  widget.participant.isAudioActive
                      ? const Icon(Icons.mic, color: Colors.white)
                      : const Icon(Icons.mic_off, color: Colors.white),
                  const SizedBox(width: 8),
                  widget.participant.isVideoActive
                      ? const Icon(Icons.videocam, color: Colors.white)
                      : const Icon(Icons.videocam_off, color: Colors.white),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _noVideoPlaceholder(String participantName) {
    var randomColor = getColorFromString(participantName);
    return Center(
      child: Container(
        width: 50.0,
        height: 50.0,
        decoration: BoxDecoration(
          color: randomColor.withOpacity(0.5),
          border: Border.all(color: randomColor, width: 3.0),
          borderRadius: const BorderRadius.all(Radius.circular(8.0)),
        ),
        child: Center(
          child: Text(
            participantName[0].toUpperCase(),
            style: const TextStyle(fontSize: 20, color: Colors.black),
          ),
        ),
      ),
    );
  }
}
