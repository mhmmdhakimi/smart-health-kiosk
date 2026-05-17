import 'package:flutter/material.dart';

class NoAnimRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  NoAnimRoute({required this.page, super.settings})
    : super(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      );
}
