import 'dart:ui';

import 'package:vector_math/vector_math_64.dart' show Matrix4, Vector3, Quad;
import 'package:flutter/material.dart';
import 'types.dart';
import 'viewport_utils.dart';


// Return a new matrix representing the given matrix after applying the given
// scale.
Matrix4 matrixScale(Matrix4 matrix, double scale) {
  if (scale == 1.0) return matrix.clone();
  assert(scale != 0.0);
  final double currentScale = matrix.getMaxScaleOnAxis();
  final double totalScale = currentScale * scale;
  final double clampedScale = totalScale / currentScale;
  return matrix.clone()..scale(clampedScale);
}

Matrix4 matrixTranslate(
  Matrix4 matrix,
  Offset translation, {
  bool force = false,
  ImageControlMode? overrideImageControlMode,
  required Rect boundaryRect,
  required Rect imageViewport,
  required Rect viewport,
}) {
  if (translation == Offset.zero && !force) return matrix.clone();
  final Matrix4 nextMatrix = matrix.clone()
    ..translate(translation.dx, translation.dy);
  if (boundaryRect.isInfinite ||
      overrideImageControlMode == ImageControlMode.full) {
    return nextMatrix;
  }
  final viewportFit = computeViewportFit(matrix, imageViewport, boundaryRect);
  return constrainToBounds(
    viewportFit,
    matrix,
    boundaryRect,
    nextMatrix,
    imageViewport,
    viewport,
  );
}

// Transform the four corners of the viewport by the inverse of the given
// matrix. This gives the viewport after the child has been transformed by the
// given matrix. The viewport transforms as the inverse of the child (i.e.
// moving the child left is equivalent to moving the viewport right).
Quad transformViewport(Matrix4 matrix, Rect viewport) {
  final Matrix4 inverseMatrix = matrix.clone()..invert();
  return Quad.points(
    inverseMatrix.transform3(
      Vector3(viewport.topLeft.dx, viewport.topLeft.dy, 0.0),
    ),
    inverseMatrix.transform3(
      Vector3(viewport.topRight.dx, viewport.topRight.dy, 0.0),
    ),
    inverseMatrix.transform3(
      Vector3(viewport.bottomRight.dx, viewport.bottomRight.dy, 0.0),
    ),
    inverseMatrix.transform3(
      Vector3(viewport.bottomLeft.dx, viewport.bottomLeft.dy, 0.0),
    ),
  );
}

Quad rectToQuad(Rect rect) {
  return Quad.points(
    Vector3(rect.left, rect.top, 0.0),
    Vector3(rect.right, rect.top, 0.0),
    Vector3(rect.right, rect.bottom, 0.0),
    Vector3(rect.left, rect.bottom, 0.0),
  );
}

Offset exceedsBy(Quad boundary, Quad viewport) {
  final List<Vector3> viewportPoints = [
    viewport.point0,
    viewport.point1,
    viewport.point2,
    viewport.point3,
  ];
  Offset largestExcess = Offset.zero;
  for (final Vector3 point in viewportPoints) {
    final Vector3 pointInside = getNearestPointInside(point, boundary);
    final Offset excess = Offset(
      pointInside.x - point.x,
      pointInside.y - point.y,
    );
    if (excess.dx.abs() > largestExcess.dx.abs()) {
      largestExcess = Offset(excess.dx, largestExcess.dy);
    }
    if (excess.dy.abs() > largestExcess.dy.abs()) {
      largestExcess = Offset(largestExcess.dx, excess.dy);
    }
  }
  return roundOffset(largestExcess);
}

Vector3 getNearestPointInside(Vector3 point, Quad quad) {
  if (pointIsInside(point, quad)) return point;
  final List<Vector3> closestPoints = [
    getNearestPointOnLine(point, quad.point0, quad.point1),
    getNearestPointOnLine(point, quad.point1, quad.point2),
    getNearestPointOnLine(point, quad.point2, quad.point3),
    getNearestPointOnLine(point, quad.point3, quad.point0),
  ];
  double minDistance = double.infinity;
  late Vector3 closestOverall;
  for (final Vector3 closePoint in closestPoints) {
    final double distance = (point - closePoint).length;
    if (distance < minDistance) {
      minDistance = distance;
      closestOverall = closePoint;
    }
  }
  return closestOverall;
}

/// Returns true iff the point is inside the rectangle given by the Quad,
/// inclusively.
/// Algorithm from https://math.stackexchange.com/a/190373.
bool pointIsInside(Vector3 point, Quad quad) {
  final Vector3 aM = point - quad.point0;
  final Vector3 aB = quad.point1 - quad.point0;
  final Vector3 aD = quad.point3 - quad.point0;
  final double aMAB = aM.dot(aB);
  final double aBAB = aB.dot(aB);
  final double aMAD = aM.dot(aD);
  final double aDAD = aD.dot(aD);
  return 0 <= aMAB && aMAB <= aBAB && 0 <= aMAD && aMAD <= aDAD;
}

Vector3 getNearestPointOnLine(Vector3 point, Vector3 l1, Vector3 l2) {
  final double lengthSquared = (l2 - l1).length2;
  if (lengthSquared == 0) return l1;
  final Vector3 l1P = point - l1;
  final Vector3 l1L2 = l2 - l1;
  final double fraction = clampDouble(l1P.dot(l1L2) / lengthSquared, 0.0, 1.0);
  return l1 + l1L2 * fraction;
}

Offset roundOffset(Offset offset) {
  return Offset(
    double.parse(offset.dx.toStringAsFixed(9)),
    double.parse(offset.dy.toStringAsFixed(9)),
  );
}

Offset getMatrixTranslation(Matrix4 matrix) {
  final Vector3 nextTranslation = matrix.getTranslation();
  return Offset(nextTranslation.x, nextTranslation.y);
}
