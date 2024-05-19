import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:openviduflutter/screens/prepare_videocall.dart';
import 'package:logging/logging.dart';

void _setupLogging() {
  // Set the log level and configure the logger
  Logger.root.level =
      Level.ALL; // Set the logging level to ALL for debugging purposes
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });
}

void main() {
  // Initialize the logging framework
  _setupLogging();

  runApp(
    const MaterialApp(
      home: PrepareVideocall(),
      debugShowCheckedModeBanner: false,
      debugShowMaterialGrid: false,
    ),
  );
}
