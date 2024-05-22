class Message {
  final String message;
  final String from;
  final String nickname;
  final DateTime time;
  final bool isMe;

  Message(this.message, this.from, this.nickname, this.time, this.isMe);
}
