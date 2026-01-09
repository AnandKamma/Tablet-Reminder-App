import 'package:flutter/material.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';

/// A widget that displays a 3D pill model with rotation animation
class PillStatic3D extends StatefulWidget {
  final double? width;
  final double? height;

  const PillStatic3D({
    super.key,
    this.width,
    this.height,
  });

  @override
  State<PillStatic3D> createState() => _PillStatic3DState();
}

class _PillStatic3DState extends State<PillStatic3D> {
  Flutter3DController controller = Flutter3DController();

  @override
  void dispose() {
    controller.onModelLoaded.removeListener(() {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width ?? 80,
      height: widget.height ?? 80,
      child: Flutter3DViewer(
        src: 'assets/models/PillUpdatematrix.glb',
        controller: controller,
        progressBarColor: Colors.transparent,
        enableTouch: false,
        onLoad: (String modelAddress) {
          debugPrint('✅ Pill model loaded successfully: $modelAddress');
          controller.setCameraOrbit(90, 100, 150);
          controller.setCameraTarget(0, -1, 0);
          controller.startRotation(rotationSpeed: 15);
        },
        onError: (String error) {
          debugPrint('❌ Failed to load pill model: $error');
        },
      ),
    );
  }
}