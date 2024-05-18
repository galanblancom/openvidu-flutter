import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:openviduflutter/api/api-service.dart';
import 'package:openviduflutter/main.dart';
import 'package:openviduflutter/participant/local-participant.dart';
import 'package:openviduflutter/utils/custom-websocket.dart';
import 'package:openviduflutter/utils/pair.dart';
import 'package:openviduflutter/utils/session.dart';

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
  final Map<String, Pair<String, RTCVideoRenderer>> _renderers = {};

  bool _isMuted = false;
  late ApiService apiService;
  Session? session;

  double _xPosition = 0.0;
  double _yPosition = 0.0;

  @override
  void initState() {
    super.initState();
    apiService = ApiService(widget.sessionId, widget.server, widget.secret);
    initRenderers();

    Future.delayed(Duration.zero, () {
      setState(() {
        _xPosition = MediaQuery.of(context).size.width - 100;
        _yPosition = MediaQuery.of(context).size.height - 300;
      });
    });
  }

  Future<void> initRenderers() async {
    await _localRenderer.initialize();
    //await _remoteRenderer.initialize();
    _connect();
  }

  void _hangUp() {
    if (session != null) {
      Navigator.of(context)
          .pushReplacement(MaterialPageRoute(builder: (context) => MyHome()));
    }
  }

  void _switchCamera() {
    session?.localParticipant?.switchCamera();
  }

  void _muteMic() {
    session?.localParticipant?.muteMic();
    setState(() {
      _isMuted = !_isMuted;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Call'),
      ),
      body: _body(),
    );
  }

  @override
  void dispose() {
    for (var renderer in _renderers.values) {
      renderer.second.dispose();
    }
    session?.leaveSession();
    super.dispose();
  }

  startWebSocket() {
    CustomWebSocket webSocket = CustomWebSocket(session!);
    webSocket.onErrorEvent = (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error)));
      }
    };
    webSocket.connect();
    session?.setWebSocket(webSocket);
  }

  Future<void> _connect() async {
    apiService.createSession().then((sessionId) {
      apiService.createToken().then((token) {
        session = Session(sessionId, token);
        session!.onSetRemoteMediaStream =
            (String connectionId, MediaStream mediaStream) {
          setState(() {
            var remoteRenderer = RTCVideoRenderer();
            remoteRenderer.initialize().then((value) {
              remoteRenderer.srcObject = mediaStream;
              _renderers[mediaStream.id] = Pair(connectionId, remoteRenderer);
            });
          });
        } as OnSetRemoteMediaStreamEvent?;
        session!.onRemoveRemoteParticipant = (String connectionId) {
          setState(() {
            var id = _renderers.entries
                .firstWhere((element) => element.value.first == connectionId)
                .key;
            _renderers[id]!.second.dispose();
            _renderers.remove(id);
          });
        } as OnRemoveRemoteParticipantEvent?;

        var localParticipant = LocalParticipant(widget.userName, session!);
        localParticipant.startLocalCamera().then((stream) => setState(() {
              _localRenderer.srcObject = localParticipant.mediaStream;
            }));

        startWebSocket();
      });
    });
  }

  _body() {
    return Stack(children: [
      Column(
        children: <Widget>[
          Expanded(
            child: _renderers.isEmpty
                ? Column(children: [buildRendererContainer(_localRenderer)])
                : _renderers.length == 1
                    ? Column(children: [
                        buildRendererContainer(
                            _renderers[_renderers.keys.elementAt(0)]!.second),
                      ])
                    : _renderers.length == 2
                        ? Column(
                            children: _renderers.values.map((renderer) {
                              return buildRendererContainer(renderer.second);
                            }).toList(),
                          )
                        : _renderers.length == 3
                            ? Column(
                                children: [
                                  buildRendererContainer(
                                      _renderers[_renderers.keys.elementAt(0)]!
                                          .second),
                                  Expanded(
                                    child: Row(
                                      children: [
                                        buildRendererContainer(_renderers[
                                                _renderers.keys.elementAt(1)]!
                                            .second),
                                        buildRendererContainer(_renderers[
                                                _renderers.keys.elementAt(2)]!
                                            .second),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : _renderers.length == 4
                                ? Column(
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            buildRendererContainer(_renderers[
                                                    _renderers.keys
                                                        .elementAt(0)]!
                                                .second),
                                            buildRendererContainer(_renderers[
                                                    _renderers.keys
                                                        .elementAt(1)]!
                                                .second),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Row(
                                          children: [
                                            buildRendererContainer(_renderers[
                                                    _renderers.keys
                                                        .elementAt(2)]!
                                                .second),
                                            buildRendererContainer(_renderers[
                                                    _renderers.keys
                                                        .elementAt(3)]!
                                                .second),
                                          ],
                                        ),
                                      ),
                                    ],
                                  )
                                : GridView.builder(
                                    padding: const EdgeInsets.all(0.0),
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount:
                                          2, // Adjust based on desired number of columns
                                      crossAxisSpacing: 1.0,
                                      mainAxisSpacing: 1.0,
                                      childAspectRatio: 1.0,
                                    ),
                                    itemCount: _renderers.length,
                                    itemBuilder: (context, index) {
                                      return Column(
                                        children: [
                                          buildRendererContainer(_renderers[
                                                  _renderers.keys
                                                      .elementAt(index)]!
                                              .second),
                                        ],
                                      );
                                    },
                                  ),
          ),
          _buttons(),
        ],
      ),
      _renderers.keys.isEmpty
          ? const SizedBox.shrink()
          : Positioned(
              left: _xPosition,
              top: _yPosition,
              child: Draggable(
                feedback: Container(
                  width: 100.0,
                  height: 150.0,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Container(),
                ),
                child: buildLocalRenderer(),
                onDragEnd: (details) {
                  setState(() {
                    if (details.offset.dx < 0) {
                      _xPosition = 0;
                    } else if (details.offset.dx >
                        MediaQuery.of(context).size.width - 100) {
                      _xPosition = MediaQuery.of(context).size.width - 100;
                    } else {
                      _xPosition = details.offset.dx;
                    }
                    if (details.offset.dy < 0) {
                      _yPosition = 0;
                    } else if (details.offset.dy >
                        MediaQuery.of(context).size.height - 150) {
                      _yPosition = MediaQuery.of(context).size.height - 225;
                    } else {
                      _yPosition = details.offset.dy - 75;
                    }
                  });
                },
              ),
            ),
    ]);
  }

  Widget buildLocalRenderer() {
    return Container(
      width: 100.0,
      height: 150.0,
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                RTCVideoView(_localRenderer, mirror: true),
                Positioned(
                    child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: const BorderRadius.only(
                        bottomRight: Radius.circular(8.0)),
                  ),
                  padding: const EdgeInsets.only(left: 8.0, right: 8.0),
                  child: session?.localParticipant?.participantName == null
                      ? const SizedBox.shrink()
                      : Text(session!.localParticipant!.participantName,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 8)),
                ))
              ],
            ),
          ),
        ],
      ),
    );
  }

  getParticipantNameByRenderer(RTCVideoRenderer renderer) {
    return session
            ?.remoteParticipants[_renderers.entries
                .firstWhere((element) => element.key == renderer.srcObject?.id)
                .value
                .first]
            ?.participantName ??
        '';
  }

  Widget buildRendererContainer(RTCVideoRenderer renderer) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Stack(children: [
          RTCVideoView(renderer),
          Positioned(
              child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius:
                  const BorderRadius.only(bottomRight: Radius.circular(8.0)),
            ),
            padding: const EdgeInsets.only(left: 8.0, right: 8.0),
            child: renderer.srcObject?.id == null || _renderers.isEmpty
                ? Text(
                    "${session?.localParticipant?.participantName}",
                    style: const TextStyle(color: Colors.white),
                  )
                : Text(
                    getParticipantNameByRenderer(renderer),
                    style: const TextStyle(color: Colors.white),
                  ),
          ))
        ]),
      ),
    );
  }

  _buttons() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          _noHeroFloatingActionButton(
            onPressed: _switchCamera,
            tooltip: 'Switch Camera',
            icon: Icons.switch_camera,
          ),
          _noHeroFloatingActionButton(
            onPressed: _hangUp,
            tooltip: 'Hang Up',
            backgroundColor: Colors.red,
            icon: Icons.call_end,
          ),
          _noHeroFloatingActionButton(
            onPressed: _muteMic,
            tooltip: _isMuted ? 'Unmute Mic' : 'Mute Mic',
            icon: _isMuted ? Icons.mic_off : Icons.mic,
          ),
        ],
      ),
    );
  }

  Widget _noHeroFloatingActionButton({
    required VoidCallback onPressed,
    required String tooltip,
    required IconData icon,
    Color? backgroundColor,
  }) {
    return FloatingActionButton(
      heroTag: null,
      onPressed: onPressed,
      tooltip: tooltip,
      backgroundColor: backgroundColor,
      child: Icon(icon),
    );
  }
}
