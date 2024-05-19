import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:openviduflutter/videocall.dart';
import 'dart:math';
import 'dart:io';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';


void main() => runApp(const MaterialApp(
      home: MyHome(),
      debugShowCheckedModeBanner: false,
      debugShowMaterialGrid: false,
    ));

class MyHome extends StatefulWidget {
  const MyHome({super.key});

  @override
  _MyHomeState createState() => _MyHomeState();
}

class _MyHomeState extends State<MyHome> {
  bool isOnline = false;
  late TextEditingController _textSessionController;
  late TextEditingController _textUserNameController;
  late TextEditingController _textUrlController;
  late TextEditingController _textSecretController;
  late TextEditingController _textPortController;
  late TextEditingController _textIceServersController;

  @override
  void initState() {
    super.initState();

    _textSessionController = TextEditingController(text: 'mirel-galan');
    //'Session-flutter-test-${Random().nextInt(1000)}'
    _textUserNameController =
        TextEditingController(text: 'FlutterUser${Random().nextInt(1000)}');
    _textUrlController = TextEditingController(text: 'demos.openvidu.io');
    _textSecretController = TextEditingController(text: 'MY_SECRET');
    _textPortController = TextEditingController(text: '443');
    _textIceServersController =
        TextEditingController(text: 'stun.l.google.com:19302');

    _loadSharedPref();
    _liveConn();
  }

  Future<void> _loadSharedPref() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _textUrlController.text =
        prefs.getString('textUrl') ?? _textUrlController.text;
    _textSecretController.text =
        prefs.getString('textSecret') ?? _textSecretController.text;
    _textPortController.text =
        prefs.getString('textPort') ?? _textPortController.text;
    _textIceServersController.text =
        prefs.getString('textIceServers') ?? _textIceServersController.text;
  }

  Future<void> _saveSharedPref() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('textUrl', _textUrlController.text);
    await prefs.setString('textSecret', _textSecretController.text);
    await prefs.setString('textPort', _textPortController.text);
    await prefs.setString('textIceServers', _textIceServersController.text);
  }

  Future<void> _liveConn() async {
    await _checkOnline();
    Timer.periodic(const Duration(seconds: 5), (timer) async {
      await _checkOnline();
    });
  }

  Future<void> _checkOnline() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        if (!isOnline) {
          isOnline = true;
          setState(() {});
          print('Online..');
        }
      }
    } on SocketException catch (_) {
      if (isOnline) {
        isOnline = false;
        setState(() {});
        print('..Offline');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Flutter OpenVidu'), actions: <Widget>[
        Row(children: <Widget>[
          isOnline
              ? const Image(
                  image: AssetImage('assets/imgs/openvidu_logo.png'),
                  fit: BoxFit.fill,
                  width: 35,
                )
              : const Image(
                  image: AssetImage('assets/imgs/offline_icon.png'),
                  fit: BoxFit.fill,
                  width: 35,
                ),
        ]),
      ]),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(10.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              const SizedBox(height: 10),
              TextField(
                controller: _textSessionController,
                decoration: const InputDecoration(
                    contentPadding: EdgeInsets.all(5),
                    border: OutlineInputBorder(),
                    labelText: 'Session name',
                    hintText: 'Enter session name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _textUserNameController,
                decoration: const InputDecoration(
                    contentPadding: EdgeInsets.all(5),
                    border: OutlineInputBorder(),
                    labelText: 'Session username',
                    hintText: 'Enter username'),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _textUrlController,
                decoration: const InputDecoration(
                    contentPadding: EdgeInsets.all(5),
                    border: OutlineInputBorder(),
                    labelText: 'OpenVidu server url',
                    hintText: 'Enter OpenVidu server url'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _textPortController,
                decoration: const InputDecoration(
                    contentPadding: EdgeInsets.all(5),
                    border: OutlineInputBorder(),
                    labelText: 'OpenVidu server port',
                    hintText: 'Enter OpenVidu server port'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _textSecretController,
                decoration: const InputDecoration(
                    contentPadding: EdgeInsets.all(5),
                    border: OutlineInputBorder(),
                    labelText: 'OpenVidu server secret',
                    hintText: 'Enter OpenVidu server secret'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _textIceServersController,
                decoration: const InputDecoration(
                    contentPadding: EdgeInsets.all(5),
                    border: OutlineInputBorder(),
                    labelText: 'Ice server',
                    hintText: 'Enter ice server url'),
              ),
              const SizedBox(
                height: 30,
              ),
              CupertinoButton(
                padding: const EdgeInsets.all(15.0),
                color: Colors.green[400],
                disabledColor: Colors.grey,
                onPressed: isOnline
                    ? () => Navigator.pushReplacement(context,
                            MaterialPageRoute(builder: (context) {
                          _saveSharedPref();
                          return VideocallWidget(
                            server:
                                '${_textUrlController.text}:${_textPortController.text}',
                            sessionId: _textSessionController.text,
                            userName: _textUserNameController.text,
                            secret: _textSecretController.text,
                            iceServer: _textIceServersController.text,
                          );
                        }))
                    : null,
                child: Text(
                  isOnline ? 'Join' : 'Offline',
                  style: const TextStyle(fontSize: 20.0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
