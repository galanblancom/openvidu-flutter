class Message {
  final String message;
  final String from;
  final String nickname;
  final DateTime time;
  final bool isMe;
  bool isReaded;

  Message(this.message, this.from, this.nickname, this.time, this.isMe,
      this.isReaded);
}
