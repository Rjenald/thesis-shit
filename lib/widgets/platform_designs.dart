import 'package:flutter/material.dart';

// Design 1: Classic Simple Platform
class SimplePlatform extends StatelessWidget {
  final double width;
  final double height;
  final Offset position;

  const SimplePlatform({
    Key? key,
    this.width = 60,
    this.height = 10,
    this.position = const Offset(0, 0),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.green[400],
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: Colors.green[700]!, width: 2),
        ),
      ),
    );
  }
}

// Design 2: Glass Morphism Platform
class GlassPlatform extends StatelessWidget {
  final double width;
  final double height;
  final Offset position;

  const GlassPlatform({
    Key? key,
    this.width = 60,
    this.height = 10,
    this.position = const Offset(0, 0),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.blue[300]!.withOpacity(0.6),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: Colors.blue[600]!.withOpacity(0.8),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.blue[400]!.withOpacity(0.4),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
    );
  }
}

// Design 3: Gradient Neon Platform
class NeonPlatform extends StatelessWidget {
  final double width;
  final double height;
  final Offset position;

  const NeonPlatform({
    Key? key,
    this.width = 60,
    this.height = 10,
    this.position = const Offset(0, 0),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.purple[400]!, Colors.pink[400]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(5),
          boxShadow: [
            BoxShadow(
              color: Colors.purple[400]!.withOpacity(0.7),
              blurRadius: 15,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: Colors.pink[400]!.withOpacity(0.5),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}

// Design 4: Retro Pixel Platform
class PixelPlatform extends StatelessWidget {
  final double width;
  final double height;
  final Offset position;

  const PixelPlatform({
    Key? key,
    this.width = 60,
    this.height = 10,
    this.position = const Offset(0, 0),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.orange[600],
          border: Border.all(color: Colors.orange[900]!, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.orange[900]!.withOpacity(0.6),
              offset: const Offset(3, 3),
              blurRadius: 0,
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: 2,
              left: 2,
              child: Container(
                width: 4,
                height: 4,
                color: Colors.orange[300],
              ),
            ),
            Positioned(
              top: 2,
              right: 2,
              child: Container(
                width: 4,
                height: 4,
                color: Colors.orange[300],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Design 5: Floating Spring Platform
class SpringPlatform extends StatefulWidget {
  final double width;
  final double height;
  final Offset position;

  const SpringPlatform({
    Key? key,
    this.width = 60,
    this.height = 10,
    this.position = const Offset(0, 0),
  }) : super(key: key);

  @override
  State<SpringPlatform> createState() => _SpringPlatformState();
}

class _SpringPlatformState extends State<SpringPlatform>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _animation = Tween<double>(begin: 0, end: 4).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Positioned(
          left: widget.position.dx,
          top: widget.position.dy - _animation.value,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red[400]!, Colors.yellow[400]!],
              ),
              borderRadius: BorderRadius.circular(5),
              boxShadow: [
                BoxShadow(
                  color: Colors.red[400]!.withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Icon(
                Icons.star,
                color: Colors.white,
                size: 8,
              ),
            ),
          ),
        );
      },
    );
  }
}
