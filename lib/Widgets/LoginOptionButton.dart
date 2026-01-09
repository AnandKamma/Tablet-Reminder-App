// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

class LoginOptions extends StatelessWidget {
  const LoginOptions({this.cardChild,this.iconbgColor,this.onPress,super.key});
  final Widget? cardChild;
  final Function()? onPress;
  final Color? iconbgColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: iconbgColor?? Colors.orange,
                width: 3
            )

        ),
        child: InkWell(
          onTap: onPress,
          splashColor: Colors.grey.shade200,
          highlightColor: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(child: cardChild),
          ),
        ),
      ),
    );
  }
}

class IconContent extends StatelessWidget {
  final IconData? icon;
  final Color? color;
  final double?  size;
  const IconContent({this.icon,this.color, this.size,super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: size,
          color: color,
        ),
        SizedBox(
          height: 5,
        ),
      ],
    );
  }
}
class NavigatetoRegorLog extends StatelessWidget {
  final String? intro;
  final String? whereto;
  final Function()? ontap;

  const NavigatetoRegorLog({
    this.intro,this.whereto,this.ontap
    ,super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: RichText(
          text: TextSpan(
            text: intro,
            style: TextStyle(
              color: Colors.black,
            ),
            children: [
              TextSpan(
                  text: whereto,
                  style: TextStyle(
                      color: Colors.blue.shade600,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline),
                  recognizer: TapGestureRecognizer()
                    ..onTap = ontap
              ),
            ],
          ),
        ),
      ),
    );
  }
}
