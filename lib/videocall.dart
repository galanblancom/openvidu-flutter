import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:openviduflutter/api/api-service.dart';
import 'package:openviduflutter/main.dart';
import 'package:openviduflutter/participant/local-participant.dart';
import 'package:openviduflutter/participant/participant.dart';
import 'package:openviduflutter/utils/custom-websocket.dart';
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
  late ApiService apiService;
  Session? session;

  double _xPosition = 0.0;
  double _yPosition = 0.0;

  @override
  void initState() {
    super.initState();
    apiService = ApiService(widget.sessionId, widget.server, widget.secret);
    _connect();

    Future.delayed(Duration.zero, () {
      setState(() {
        _xPosition = MediaQuery.of(context).size.width - 100;
        _yPosition = MediaQuery.of(context).size.height - 300;
      });
    });
  }

  void _hangUp() {
    if (session != null) {
      Navigator.of(context)
          .pushReplacement(MaterialPageRoute(builder: (context) => MyHome()));
    }
  }

  void _switchCamera() {
    session?.localParticipant?.switchCamera().then((value) {
      refresh();
    });
  }

  void _toggleVideo() {
    session?.localToggleVideo();
    refresh();
  }

  void _toggleMic() {
    session?.localToggleAudio();
    refresh();
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
    session?.leaveSession();
    super.dispose();
  }

  refresh() {
    if (context.mounted) {
      setState(() {});
    }
  }

  startWebSocket() {
    CustomWebSocket webSocket = CustomWebSocket(session!);
    webSocket.onErrorEvent = (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error)));
      }
    };
    webSocket.onRemoteParticipantStreamChangeEvent = () {
      refresh();
    };
    webSocket.connect();
    session?.setWebSocket(webSocket);
  }

  Future<void> _connect() async {
    apiService.createSession().then((sessionId) {
      apiService.createToken().then((token) {
        session = Session(sessionId, token);
        session!.onNotifySetRemoteMediaStream = (String connectionId) {
          refresh();
        } as OnNotifySetRemoteMediaStreamEvent?;
        session!.onRemoveRemoteParticipant = (String connectionId) {
          refresh();
        } as OnRemoveRemoteParticipantEvent?;

        var localParticipant = LocalParticipant(widget.userName, session!);
        localParticipant.renderer.initialize().then((value) {
          localParticipant.startLocalCamera().then((stream) => refresh());
        });

        startWebSocket();
      });
    });
  }

  _body() {
    var remoteParticipants = session?.remoteParticipants.entries ?? [];

    return Stack(children: [
      Column(
        children: <Widget>[
          Expanded(
            child: remoteParticipants.isEmpty
                ? Column(children: [buildLocalRenderer(fullScreen: true)])
                : remoteParticipants.length == 1
                    ? Column(children: [
                        buildRendererContainer(remoteParticipants.elementAt(0)),
                      ])
                    : remoteParticipants.length == 2
                        ? Column(
                            children: remoteParticipants.map((participantPair) {
                              return buildRendererContainer(participantPair);
                            }).toList(),
                          )
                        : remoteParticipants.length == 3
                            ? Column(
                                children: [
                                  buildRendererContainer(
                                      remoteParticipants.elementAt(0)),
                                  Expanded(
                                    child: Row(
                                      children: [
                                        buildRendererContainer(
                                            remoteParticipants.elementAt(1)),
                                        buildRendererContainer(
                                            remoteParticipants.elementAt(2)),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : remoteParticipants.length == 4
                                ? Column(
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            buildRendererContainer(
                                                remoteParticipants
                                                    .elementAt(0)),
                                            buildRendererContainer(
                                                remoteParticipants
                                                    .elementAt(1)),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Row(
                                          children: [
                                            buildRendererContainer(
                                                remoteParticipants
                                                    .elementAt(2)),
                                            buildRendererContainer(
                                                remoteParticipants
                                                    .elementAt(3)),
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
                                    itemCount: remoteParticipants.length,
                                    itemBuilder: (context, index) {
                                      return Column(
                                        children: [
                                          buildRendererContainer(
                                              remoteParticipants
                                                  .elementAt(index)),
                                        ],
                                      );
                                    },
                                  ),
          ),
          _buttons(),
        ],
      ),
      (session?.remoteParticipants.entries ?? []).isEmpty
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
                  if (context.mounted) {
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
                  }
                },
              ),
            ),
    ]);
  }

  Widget buildLocalRenderer({bool fullScreen = false}) {
    if (session?.localParticipant?.renderer == null) {
      if (fullScreen) {
        return const Expanded(
            child: Center(child: CircularProgressIndicator()));
      }
      return const Center(child: CircularProgressIndicator());
    }

    if (fullScreen) {
      return Expanded(child: buildLocalRendererBody(fullScreen: fullScreen));
    }

    return buildLocalRendererBody(fullScreen: fullScreen);
  }

  buildLocalRendererBody({bool fullScreen = false}) {
    return Container(
      width: fullScreen ? null : 100.0,
      height: fullScreen ? null : 150.0,
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
                session!.localParticipant!.isVideoActive
                    ? RTCVideoView(session!.localParticipant!.renderer,
                        mirror:
                            session?.localParticipant?.isFrontCameraActive ??
                                false)
                    : _noVideoInitial(
                        session!.localParticipant!.participantName, fullScreen),
                Positioned(
                    child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: const BorderRadius.only(
                        bottomRight: Radius.circular(8.0)),
                  ),
                  padding: const EdgeInsets.only(
                      left: 8.0, right: 8.0, bottom: 4.0, top: 2.0),
                  child: session?.localParticipant?.participantName == null
                      ? const SizedBox.shrink()
                      : Text(session!.localParticipant!.participantName,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: fullScreen ? null : 8)),
                ))
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color getRandomLightColor() {
    final Random random = Random();
    // Generate random RGB values between 128 and 255 to ensure light colors
    int red = 128 + random.nextInt(128); // 128-255
    int green = 128 + random.nextInt(128); // 128-255
    int blue = 128 + random.nextInt(128); // 128-255
    return Color.fromARGB(255, red, green, blue);
  }

  Color getColorFromString(String input) {
    // Hash the input string using SHA-256
    var bytes = utf8.encode(input);
    var digest = sha256.convert(bytes);

    // Use the first 3 bytes of the hash to generate RGB values
    int red = (digest.bytes[0] % 128) + 128; // 128-255
    int green = (digest.bytes[1] % 128) + 128; // 128-255
    int blue = (digest.bytes[2] % 128) + 128; // 128-255

    return Color.fromARGB(255, red, green, blue);
  }

  Widget buildRendererContainer(MapEntry<String, Participant> remotePair) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Stack(
          children: [
            remotePair.value.isVideoActive
                ? RTCVideoView(remotePair.value.renderer)
                : _noVideoInitial(remotePair.value.participantName),
            Positioned(
                child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius:
                    const BorderRadius.only(bottomRight: Radius.circular(8.0)),
              ),
              padding: const EdgeInsets.only(left: 8.0, right: 8.0),
              child: Text(
                remotePair.value.participantName,
                style: const TextStyle(color: Colors.white),
              ),
            )),
            Positioned(
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: const BorderRadius.only(
                      bottomRight: Radius.circular(8.0)),
                ),
                padding:
                    const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 8.0),
                child: Row(
                  children: [
                    remotePair.value.isAudioActive
                        ? const Icon(Icons.mic, color: Colors.white)
                        : const Icon(Icons.mic_off, color: Colors.white),
                    const SizedBox(width: 8),
                    remotePair.value.isVideoActive
                        ? const Icon(Icons.videocam, color: Colors.white)
                        : const Icon(Icons.videocam_off, color: Colors.white),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  _noVideoInitial(String participantName, [bool fullScreen = true]) {
    var randomColor = getColorFromString(participantName);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Center(
          child: Container(
            width: fullScreen ? 150.0 : 50.0,
            height: fullScreen ? 150.0 : 50.0,
            decoration: BoxDecoration(
              color: randomColor.withOpacity(0.5),
              border: Border.all(color: randomColor, width: 3.0),
              borderRadius: const BorderRadius.all(Radius.circular(8.0)),
            ),
            child: Center(
              child: Text(participantName[0].toUpperCase(),
                  style: TextStyle(
                      fontSize: fullScreen ? 80 : 20, color: Colors.black)),
            ),
          ),
        )
      ],
    );
  }

  _buttons() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          _noHeroFloatingActionButton(
            onPressed: _toggleVideo,
            tooltip: session?.localParticipant?.isVideoActive ?? true
                ? 'Turn on video'
                : 'Turn off video',
            icon: Icon(session?.localParticipant?.isVideoActive ?? true
                ? Icons.videocam
                : Icons.videocam_off),
          ),
          if (session?.localParticipant?.isVideoActive ?? true)
            _noHeroFloatingActionButton(
              onPressed: _switchCamera,
              tooltip: 'Switch Camera',
              icon: const Icon(Icons.switch_camera),
            ),
          _noHeroFloatingActionButton(
            onPressed: _hangUp,
            tooltip: 'Hang Up',
            backgroundColor: Colors.red,
            icon: const Icon(
              Icons.call_end,
              color: Colors.white,
            ),
          ),
          _noHeroFloatingActionButton(
            onPressed: _toggleMic,
            tooltip: session?.localParticipant?.isAudioActive ?? true
                ? 'Mute Mic'
                : 'Unmute Mic',
            icon: Icon(session?.localParticipant?.isAudioActive ?? true
                ? Icons.mic
                : Icons.mic_off),
          ),
        ],
      ),
    );
  }

  Widget _noHeroFloatingActionButton({
    required VoidCallback onPressed,
    required String tooltip,
    required Icon icon,
    Color? backgroundColor,
  }) {
    return FloatingActionButton(
      heroTag: null,
      onPressed: onPressed,
      tooltip: tooltip,
      backgroundColor: backgroundColor,
      child: icon,
    );
  }
}
