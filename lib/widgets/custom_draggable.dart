import 'package:flutter/material.dart';

class CustomDraggable extends StatefulWidget {
  /// The initial X position of the draggable widget
  final double initialX;

  /// The initial Y position of the draggable widget
  final double initialY;

  /// The width of the draggable widget
  final double width;

  /// The height of the draggable widget
  final double height;

  /// The child widget that is to be made draggable
  final Widget child;

  /// Constructor for the CustomDraggable class
  /// Takes the initial X and Y positions, the child widget, and optionally the width and height of the widget
  const CustomDraggable({
    super.key,
    required this.initialX,
    required this.initialY,
    required this.child,
    this.width = 100.0,
    this.height = 150.0,
  });

//// Overriding the createState method to return a new instance of _CustomDraggableState
  @override
  State<CustomDraggable> createState() => _CustomDraggableState();
}

/// The state class for the CustomDraggable widget
class _CustomDraggableState extends State<CustomDraggable> {
  /// The current X position of the draggable widget
  late double _xPosition;

  /// The current Y position of the draggable widget
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
                _yPosition = MediaQuery.of(context).size.height - widget.height;
              } else {
                _yPosition = newY;
              }
            });
          }
        },
      ),
    );
  }
}
