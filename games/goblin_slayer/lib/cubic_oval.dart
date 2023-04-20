import 'dart:ui';

import 'package:rive_gamekit/rive_gamekit.dart';

const _circleConstant = 0.552;
void cubicOval(RenderPath path, Offset center, Size size) {
  var w = size.width;
  var h = size.height;
  var cx = center.dx;
  var cy = center.dy;
  path.moveTo(center.dx - w, center.dy);
  path.cubicTo(
    cx - w,
    cy - (_circleConstant * h),
    cx - (_circleConstant * h),
    cy - h,
    cx,
    cy - h,
  );

  path.cubicTo(
    cx + (_circleConstant * w),
    cy - h,
    cx + w,
    cy - (_circleConstant * h),
    cx + w,
    cy,
  );

  path.cubicTo(
    cx + w,
    cy + (_circleConstant * h),
    cx + (_circleConstant * w),
    cy + h,
    cx,
    cy + h,
  );

  path.cubicTo(
    cx - (_circleConstant * w),
    cy + h,
    cx - w,
    cy + (_circleConstant * h),
    cx - w,
    cy,
  );

  path.close();
}
