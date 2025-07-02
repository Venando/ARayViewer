import 'dart:ui';
import 'package:vector_math/vector_math_64.dart';

Offset toScene(Matrix4 value, Offset viewportPoint) {
  // On viewportPoint, perform the inverse transformation of the scene to get
  // where the point would be in the scene before the transformation.
  final Matrix4 inverseMatrix = Matrix4.inverted(value);
  final Vector3 untransformed = inverseMatrix.transform3(
    Vector3(viewportPoint.dx, viewportPoint.dy, 0),
  );
  return Offset(untransformed.x, untransformed.y);
}

Offset transformOffset(Matrix4 value, Offset viewportPoint) {
  final Vector3 untransformed = value.transform3(
    Vector3(viewportPoint.dx, viewportPoint.dy, 0),
  );
  return Offset(untransformed.x, untransformed.y);
}
