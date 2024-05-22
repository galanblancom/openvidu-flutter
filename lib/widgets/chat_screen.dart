import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:openvidu_flutter/utils/message.dart';
import 'package:openvidu_flutter/utils/session.dart';

class ChatScreen extends StatefulWidget {
  final Session session;
  final Widget? title;
  final Widget Function(Message)? chatBubble;
  final InputDecoration? textFieldDecoration;

  const ChatScreen({
    super.key,
    required this.session,
    this.title = const Text('Chat'),
    this.chatBubble,
    this.textFieldDecoration = const InputDecoration(
      hintText: 'Type a message',
      border: OutlineInputBorder(),
    ),
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.session.messageStream.listen((message) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: widget.title,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: widget.session.messages.length,
              itemBuilder: (context, index) {
                return widget.chatBubble == null
                    ? ChatBubble(
                        message: widget.session.messages[
                            widget.session.messages.length - index - 1],
                      )
                    : widget.chatBubble!(widget.session
                        .messages[widget.session.messages.length - index - 1]);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: widget.textFieldDecoration,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () {
                    if (_controller.text.trim().isNotEmpty) {
                      widget.session.localParticipant!
                          .sendMessage(_controller.text.trim());
                      _controller.clear();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatBubble extends StatelessWidget {
  final Message message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
        decoration: BoxDecoration(
          color: message.isMe ? Colors.blue : Colors.grey[300],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.message,
              style:
                  TextStyle(color: message.isMe ? Colors.white : Colors.black),
            ),
            const SizedBox(height: 5),
            Text(
              DateFormat('hh:mm a').format(message.time),
              style: TextStyle(
                  color: message.isMe ? Colors.white70 : Colors.black54,
                  fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
