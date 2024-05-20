import 'package:flutter/material.dart';

class CustomDraggable extends StatefulWidget {
  final double initialX;
  final double initialY;
  final double width;
  final double height;
  final Widget child;

  const CustomDraggable({
    super.key,
    required this.initialX,
    required this.initialY,
    required this.child,
    this.width = 100.0,
    this.height = 150.0,
  });

  @override
  _CustomDraggableState createState() => _CustomDraggableState();
}

class _CustomDraggableState extends State<CustomDraggable> {
  late double _xPosition;
  late double _yPosition;

  @override
  void initState() {
    super.initState();
    _xPosition = widget.initialX;
    _yPosition = widget.initialY;
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _xPosition,
      top: _yPosition,
      child: Draggable(
        feedback: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: Colors.black,
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  Icons.open_with,
                  color: Colors.white,
                ),
              ],
            )),
        child: widget.child,
        onDragEnd: (details) {
          if (context.mounted) {
            setState(() {
              double newX = details.offset.dx;
              double newY = details.offset.dy;

              if (newX < 0) {
                _xPosition = 0;
              } else if (newX >
                  MediaQuery.of(context).size.width - widget.width) {
                _xPosition = MediaQuery.of(context).size.width - widget.width;
              } else {
                _xPosition = newX;
              }

              if (newY < 0) {
                _yPosition = 0;
              } else if (newY >
                  MediaQuery.of(context).size.height - widget.height) {
                _yPosition = MediaQuery.of(context).size.height -
                    (widget.height + widget.height / 2);
              } else {
                _yPosition = newY - widget.height / 2;
              }
            });
          }
        },
      ),
    );
  }
}
