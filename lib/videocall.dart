import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:openvidutest/api/api-service.dart';
import 'package:openvidutest/participant/local-participant.dart';
import 'package:openvidutest/participant/remote-participant.dart';
import 'package:openvidutest/utils/custom-websocket.dart';
import 'package:openvidutest/utils/session.dart';

class VideocallWidget extends StatefulWidget {
  const VideocallWidget({
    super.key,
    required this.server,
    required this.sessionId,
    required this.userName,
    required this.secret,
    required this.iceServer,
  });

  final String server;
  final String sessionId;
  final String userName;
  final String secret;
  final String iceServer;

  @override
  _VideocallWidgetState createState() => _VideocallWidgetState();
}

class _VideocallWidgetState extends State<VideocallWidget> {
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();

  late ApiService apiService;
  Session? session;
  //Signaling? _signaling;

  @override
  void initState() {
    super.initState();

    apiService = ApiService(widget.sessionId, widget.server, widget.secret);

    initRenderers();
  }

  Future<void> initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    _connect();
  }

  void _hangUp() {
    if (session != null) {
      Navigator.of(context).pop();
    }
  }

  void _switchCamera() {
    //_signaling?.switchCamera();
  }

  void _muteMic() {
    //_signaling?.muteMic();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: OrientationBuilder(builder: (context, orientation) {
        return Stack(children: <Widget>[
          Positioned(
              left: 0.0,
              right: 0.0,
              top: 0.0,
              bottom: 0.0,
              child: Container(
                margin: const EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                decoration: const BoxDecoration(color: Colors.black54),
                child: RTCVideoView(_remoteRenderer),
              )),
          Positioned(
            left: 20.0,
            top: 40.0,
            child: Container(
              width: orientation == Orientation.portrait ? 90.0 : 120.0,
              height: orientation == Orientation.portrait ? 120.0 : 90.0,
              decoration: const BoxDecoration(color: Colors.green),
              child: RTCVideoView(_localRenderer),
            ),
          ),
        ]);
      }),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: SizedBox(
          width: 200.0,
          child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                FloatingActionButton(
                  onPressed: _switchCamera,
                  heroTag: "btn_switchCamera",
                  child: const Icon(Icons.switch_camera),
                ),
                FloatingActionButton(
                  onPressed: _hangUp,
                  heroTag: "btn_hangUp",
                  tooltip: 'Hangup',
                  backgroundColor: Colors.pink,
                  child: const Icon(Icons.call_end),
                ),
                FloatingActionButton(
                  onPressed: _muteMic,
                  heroTag: "btn_muteMic",
                  child: const Icon(Icons.mic_off),
                )
              ])),
    );
  }

  @override
  void dispose() {
    super.dispose();
    session?.leaveSession();
    //_signaling?.close();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
  }

  startWebSocket() {
    CustomWebSocket webSocket = CustomWebSocket(session!);
    webSocket.connect();
    session?.setWebSocket(webSocket);
  }

  Future<void> _connect() async {
    apiService.createSession().then((sessionId) {
      apiService.createToken().then((token) {
        session = Session(sessionId, token);
        session!.onSetRemoteMediaStream = (MediaStream mediaStream) {
          setState(() {
            _remoteRenderer.srcObject = mediaStream;
          });
        } as OnSetRemoteMediaStreamEvent?;
        session!.onRemoveRemoteParticipant = (String id) {
          setState(() {
            _remoteRenderer.srcObject = null;
          });
        } as OnRemoveRemoteParticipantEvent?;

        var localParticipant = LocalParticipant(widget.userName, session!);
        localParticipant.startLocalCamera().then((stream) => setState(() {
              _localRenderer.srcObject = localParticipant.localStream;
            }));

        startWebSocket();
      });
    });
  }
}
