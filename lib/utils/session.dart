import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:openviduflutter/participant/local-participant.dart';
import 'package:openviduflutter/participant/remote-participant.dart';
import 'package:openviduflutter/utils/custom-websocket.dart';

typedef OnNotifySetRemoteMediaStreamEvent = void Function(String id);
typedef OnRemoveRemoteParticipantEvent = void Function(String id);

class Session {
  LocalParticipant? localParticipant;
  Map<String, RemoteParticipant> remoteParticipants = {};
  String id;
  String token;
  OnNotifySetRemoteMediaStreamEvent? onNotifySetRemoteMediaStream;
  OnRemoveRemoteParticipantEvent? onRemoveRemoteParticipant;

  final List<Map<String, List<String>>> iceServersDefault = [
    {
      'urls': ['stun:stun.l.google.com:19302']
    },
  ];
  List<Map<String, dynamic>> iceServers = [];
  late RTCVideoRenderer localRenderer;
  late CustomWebSocket websocket;
  //final BuildContext context;

  Map<String, dynamic> get _configuration => {
        'iceServers': iceServers.isEmpty ? iceServersDefault : iceServers,
        /*'sdpSemantics': "unified_plan",
        'bundlePolicy': "max_bundle",
        'rtcpMuxPolicy': "require",
        'tcpCandidatePolicy': "enabled",
        'keyType': "ecdsa",
        'continualGatheringPolicy': "gather_continually",*/
      };

  Session(this.id, this.token) {
    _initialize();
  }

  Future<void> _initialize() async {
    await WebRTC.initialize();
  }

  void setWebSocket(CustomWebSocket websocket) {
    this.websocket = websocket;
  }

  Future<RTCPeerConnection> createLocalPeerConnection() async {
    RTCPeerConnection peerConnection =
        await createPeerConnection(_configuration);

    peerConnection.onIceCandidate = (RTCIceCandidate candidate) {
      websocket.onIceCandidate(candidate, localParticipant!.connectionId!);
    };

    peerConnection.onSignalingState = (RTCSignalingState? state) {
      if (state == RTCSignalingState.RTCSignalingStateStable) {
        for (var candidate in localParticipant!.iceCandidateList) {
          peerConnection.addCandidate(candidate);
        }
        localParticipant!.iceCandidateList.clear();
      }
    };

    if (localParticipant?.audioTrack != null) {
      peerConnection.addTransceiver(
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.SendOnly),
        track: localParticipant!.audioTrack!,
      );
    }

    if (localParticipant?.videoTrack != null) {
      peerConnection.addTransceiver(
        init: RTCRtpTransceiverInit(
          direction: TransceiverDirection.SendOnly,
        ),
        track: localParticipant!.videoTrack!,
      );
    }

    return peerConnection;
  }

  Future<void> createRemotePeerConnection(String connectionId) async {
    RTCPeerConnection peerConnection =
        await createPeerConnection(_configuration);

    peerConnection.onIceCandidate = (RTCIceCandidate candidate) {
      websocket.onIceCandidate(candidate, connectionId);
    };

    peerConnection.onTrack = (RTCTrackEvent event) {
      _setRemoteMediaStream(
          event.streams[0], remoteParticipants[connectionId]!);
    };

    peerConnection.onSignalingState = (RTCSignalingState? state) {
      if (state == RTCSignalingState.RTCSignalingStateStable) {
        for (var candidate
            in remoteParticipants[connectionId]!.iceCandidateList) {
          peerConnection.addCandidate(candidate);
        }
        remoteParticipants[connectionId]!.iceCandidateList.clear();
      }
    };

    peerConnection.addTransceiver(
      kind: RTCRtpMediaType.RTCRtpMediaTypeAudio,
      init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
    );
    peerConnection.addTransceiver(
      kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
      init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
    );

    remoteParticipants[connectionId]!.peerConnection = peerConnection;
  }

  Future<void> createOfferForPublishing(
      Map<String, dynamic> constraints) async {
    RTCSessionDescription offer =
        await localParticipant!.peerConnection!.createOffer(constraints);
    await localParticipant!.peerConnection!
        .setLocalDescription(offer)
        .then((_) => websocket.publishVideo(offer));
  }

  Future<void> createAnswerForSubscribing(RemoteParticipant remoteParticipant,
      String streamId, Map<String, dynamic> constraints) async {
    RTCSessionDescription answer =
        await remoteParticipant.peerConnection!.createAnswer(constraints);
    await remoteParticipant.peerConnection!.setLocalDescription(answer).then(
        (_) => websocket.receiveVideoFrom(answer, remoteParticipant, streamId));
  }

  void setIceServers(List<Map<String, dynamic>> iceServers) {
    this.iceServers = iceServers;
  }

  void addRemoteParticipant(RemoteParticipant remoteParticipant) {
    remoteParticipants[remoteParticipant.connectionId!] = remoteParticipant;
  }

  Future<void> removeRemoteParticipant(String id) async {
    await remoteParticipants[id]?.renderer.dispose();
    await remoteParticipants.remove(id)?.dispose();
    onRemoveRemoteParticipant!(id);
  }

  void leaveSession() async {
    websocket.leaveRoom();
    await websocket.disconnect();

    localParticipant!.dispose();
    for (var remoteParticipant in remoteParticipants.values) {
      remoteParticipant.dispose();
    }
  }

  void _setRemoteMediaStream(
      MediaStream stream, RemoteParticipant participant) {
    participant.mediaStream = stream;
    //participant.isAudioActive = stream.getAudioTracks().first.enabled;
    //participant.isCameraActive = stream.getVideoTracks().first.enabled;
    participant.renderer.initialize().then((value) {
      participant.renderer.srcObject = stream;
      if (onNotifySetRemoteMediaStream != null) {
        onNotifySetRemoteMediaStream!(participant.connectionId!);
      }
    });
  }

  void localToggleAudio() {
    localParticipant!.toggleAudio();
    websocket.changeStreamAudio(
        localParticipant!.connectionId!, localParticipant!.isAudioActive);
  }

  void localToggleVideo() {
    localParticipant!.toggleVideo();
    websocket.changeStreamVideo(
        localParticipant!.connectionId!, localParticipant!.isVideoActive);
  }
}
