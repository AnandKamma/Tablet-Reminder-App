
import 'package:flutter/material.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
class FadePageRoute extends PageRouteBuilder {
  final String? routeName;
  FadePageRoute({this.routeName})
      : super(
      transitionDuration: Duration(milliseconds: 500),
      pageBuilder: (context, animation, secondaryAnimation) {
        final MaterialApp? app =
        context.findAncestorWidgetOfExactType<MaterialApp>();
        if (app == null ||
            app.routes == null ||
            !app.routes!.containsKey(routeName)) {
          throw Exception('Route $routeName not found!');
        }
        final WidgetBuilder builder = app.routes![routeName]!;
        return builder(context);
      },
      transitionsBuilder:
          (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      });
}

class ColoriseText extends StatelessWidget {
  final String text;
  final Duration duration;
  ColoriseText(
      {required this.text,
        this.duration = const Duration(milliseconds: 300),
        super.key});

  static List<Color> coloriseColors = [
    Color(0xFF212a25),
    Colors.white70,
    Color(0xFF212a25),
  ];
  static const TextStyle colorizeTextStyle = TextStyle(
      fontSize: 45.0,
      fontFamily: 'Lato',
      fontWeight: FontWeight.bold
  );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      child: AnimatedTextKit(
        animatedTexts: [
          ColorizeAnimatedText(
            text,
            textStyle: colorizeTextStyle,
            colors: coloriseColors,
            textAlign: TextAlign.center,
            speed: duration,
          ),
        ],
        isRepeatingAnimation: false,
        totalRepeatCount: 1,
      ),
    );
  }
}
class FadeToCalibrationRoute extends PageRouteBuilder {
  final Widget page;
  FadeToCalibrationRoute({required this.page})
      : super(
    transitionDuration: Duration(milliseconds: 400),
    reverseTransitionDuration: Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOut,
        ),
        child: child,
      );
    },
  );
}


class RotateWords extends StatelessWidget {
  final String? label1;
  final String? label2;
  final String? label3;

  const RotateWords({this.label1, this.label2, this.label3, super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DefaultTextStyle(
          style: const TextStyle(
            color: Color(0xFF38463e),
            fontSize: 40.0,
            fontFamily: 'LuckiestGuy',
          ),
          child: AnimatedTextKit(
            animatedTexts: [
              RotateAnimatedText(label1!,
                  duration: Duration(milliseconds: 800)),
              RotateAnimatedText(label2!,
                  duration: Duration(milliseconds: 800)),
              RotateAnimatedText(label3!,
                  duration: Duration(milliseconds: 800)),
            ],
            repeatForever: true,
            isRepeatingAnimation: true,
          ),
        )
      ],
    );

  }
}

