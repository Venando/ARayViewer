import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4, Vector3, Quad;
import 'matrix_utils.dart';
import 'types.dart';

Rect getViewport(GlobalKey parentKey) {
  assert(parentKey.currentContext != null);
  final RenderBox parentRenderBox =
      parentKey.currentContext!.findRenderObject()! as RenderBox;
  return Offset.zero & parentRenderBox.size;
}

Rect getBoundaryRect(GlobalKey childKey, EdgeInsets boundaryMargin) {
  assert(childKey.currentContext != null);
  assert(
    !boundaryMargin.left.isNaN &&
        !boundaryMargin.right.isNaN &&
        !boundaryMargin.top.isNaN &&
        !boundaryMargin.bottom.isNaN,
  );
  final RenderBox childRenderBox =
      childKey.currentContext!.findRenderObject()! as RenderBox;
  final Size childSize = childRenderBox.size;
  Rect boundaryRect = boundaryMargin.inflateRect(Offset.zero & childSize);
  assert(
    !boundaryRect.isEmpty,
    "InteractiveViewer's child must have nonzero dimensions.",
  );
  assert(
    boundaryRect.isFinite ||
        (boundaryRect.left.isInfinite &&
            boundaryRect.top.isInfinite &&
            boundaryRect.right.isInfinite &&
            boundaryRect.bottom.isInfinite),
  );
  return boundaryRect;
}

Rect getImageViewport(Rect boundaryRect, ImageInfo? currentImageInfo) {
  if (currentImageInfo == null) return boundaryRect;
  var image = currentImageInfo.image;
  final bool isBigImage =
      boundaryRect.height < image.height || boundaryRect.width < image.width;
  if (isBigImage) {
    final double imageAspectRatio = image.height / image.width;
    final double boundaryAspectRatio = boundaryRect.height / boundaryRect.width;
    if ((boundaryAspectRatio - imageAspectRatio).abs() > 0.01) {
      double newWidth = boundaryRect.width;
      double newHeight = boundaryRect.height;
      double newLeft = boundaryRect.left;
      double newTop = boundaryRect.top;
      if (boundaryAspectRatio > imageAspectRatio) {
        newHeight = boundaryRect.width * imageAspectRatio;
        newTop = boundaryRect.top + (boundaryRect.height - newHeight) / 2;
      } else {
        newWidth = boundaryRect.height / imageAspectRatio;
        newLeft = boundaryRect.left + (boundaryRect.width - newWidth) / 2;
      }
      return Rect.fromLTWH(newLeft, newTop, newWidth, newHeight);
    }
  }
  return Rect.fromLTWH(
    boundaryRect.width / 2 - image.width.toDouble() / 2,
    boundaryRect.height / 2 - image.height.toDouble() / 2,
    image.width.toDouble(),
    image.height.toDouble(),
  );
}

ViewportFit computeViewportFit(
  Matrix4 matrix,
  Rect imageViewport,
  Rect boundaryRect, {
  bool strict = true,
}) {
  var scale = matrix.getMaxScaleOnAxis();
  final scaledWidth = imageViewport.width * scale;
  final scaledHeight = imageViewport.height * scale;
  return ViewportFit(
    fitsWidth: strict
        ? scaledWidth >= boundaryRect.width
        : scaledWidth > boundaryRect.width,
    fitsHeight: strict
        ? scaledHeight >= boundaryRect.height
        : scaledHeight > boundaryRect.height,
  );
}

Vector3 getCenterTranslation(Matrix4 matrix, Rect viewport, Rect boundaryRect) {
  double scale = matrix.getMaxScaleOnAxis();
  double scaledWidth = viewport.width * scale;
  double scaledHeight = viewport.height * scale;
  return Vector3(
    (boundaryRect.width - scaledWidth) / 2,
    (boundaryRect.height - scaledHeight) / 2,
    0.0,
  );
}

Matrix4 constrainToBounds(
  ViewportFit viewportFit,
  Matrix4 matrix,
  Rect boundaryRect,
  Matrix4 nextMatrix,
  Rect imageViewport,
  Rect viewport,
) {
  Vector3 centerTranslation = getCenterTranslation(
    nextMatrix,
    viewport,
    boundaryRect,
  );
  if (!viewportFit.fitsWidth || !viewportFit.fitsHeight) {
    final nextTranslation = nextMatrix.getTranslation();
    nextMatrix.setTranslation(
      Vector3(
        viewportFit.fitsWidth ? nextTranslation.x : centerTranslation.x,
        viewportFit.fitsHeight ? nextTranslation.y : centerTranslation.y,
        0.0,
      ),
    );
  }
  final Quad boundariesQuad = rectToQuad(imageViewport);
  final Quad nextViewport = transformViewport(nextMatrix, viewport);
  Offset offendingDistance = exceedsBy(boundariesQuad, nextViewport);
  offendingDistance = Offset(
    !viewportFit.fitsWidth ? 0.0 : offendingDistance.dx,
    !viewportFit.fitsHeight ? 0.0 : offendingDistance.dy,
  );
  if (offendingDistance == Offset.zero) return nextMatrix;
  final Offset nextTotalTranslation = getMatrixTranslation(nextMatrix);
  final double currentScale = matrix.getMaxScaleOnAxis();
  final Offset correctedTotalTranslation = Offset(
    nextTotalTranslation.dx - offendingDistance.dx * currentScale,
    nextTotalTranslation.dy - offendingDistance.dy * currentScale,
  );
  final Matrix4 correctedMatrix = matrix.clone()
    ..setTranslation(
      Vector3(
        viewportFit.fitsWidth
            ? correctedTotalTranslation.dx
            : centerTranslation.x,
        viewportFit.fitsHeight
            ? correctedTotalTranslation.dy
            : centerTranslation.y,
        0.0,
      ),
    );
  return correctedMatrix;
}
