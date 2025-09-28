import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:crypto/crypto.dart';

/// Generates a random color
Color getRandomLightColor() {
  final Random random = Random();
  // Generate random RGB values between 128 and 255 to ensure light colors
  int red = 128 + random.nextInt(128); // 128-255
  int green = 128 + random.nextInt(128); // 128-255
  int blue = 128 + random.nextInt(128); // 128-255
  return Color.fromARGB(255, red, green, blue);
}

/// Generates a color from a given string
Color getColorFromString(String input) {
  // Hash the input string using SHA-256
  List<int> bytes = utf8.encode(input);
  Digest digest = sha256.convert(bytes);

  // Use the first 3 bytes of the hash to generate RGB values
  int red = (digest.bytes[0] % 128) + 128; // 128-255
  int green = (digest.bytes[1] % 128) + 128; // 128-255
  int blue = (digest.bytes[2] % 128) + 128; // 128-255

  return Color.fromARGB(255, red, green, blue);
}
