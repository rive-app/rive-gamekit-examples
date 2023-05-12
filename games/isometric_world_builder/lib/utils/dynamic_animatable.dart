import 'dart:math';

import 'package:flutter/animation.dart';

class DynamicAnimatable<T> {
  T start;
  T target;
  late T current;
  Duration duration;
  Curve curve;
  double elapsedTime = 0;

  DynamicAnimatable({
    required this.start,
    required this.target,
    this.duration = defaultDuration,
    this.curve = defaultCurve,
  }) {
    current = start;
  }

  late final baseTween = Tween<T>(begin: start, end: target);

  late final Animatable<T> _animatable = baseTween.chain(
    CurveTween(curve: curve),
  );

  static const Curve defaultCurve = Curves.linear;
  static const Duration defaultDuration = Duration(milliseconds: 750);

  void setTarget(
    T value, {
    Curve curve = defaultCurve,
    Duration duration = defaultDuration,
  }) {
    if (value == target) return;

    this.duration = duration;
    this.curve = curve;
    elapsedTime = 0;
    start = current;
    target = value;

    baseTween.begin = start;
    baseTween.end = target;
  }

  void immediateSetTarget(T value) {
    target = value;
    start = value;
    current = value;
    elapsedTime = duration.inMilliseconds.toDouble();
  }

  void tick(double delta) {
    elapsedTime += delta;
    final time = elapsedTime * 1000;
    if (current == target || time >= duration.inMilliseconds) return;
    final t = min(time, duration.inMilliseconds);
    current = _animatable.transform(t / duration.inMilliseconds);
  }
}
