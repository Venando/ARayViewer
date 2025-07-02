import 'dart:async';
import 'dart:developer';
import 'dart:math' as math;

import 'package:cancellation_token/cancellation_token.dart';
import 'package:flutter/services.dart';
import 'anchor_info.dart';
import 'image_extension.dart';
import 'key_event_scrolling_helper.dart';
import 'matrix_utils.dart' as matrix_utils;
import 'viewport_utils.dart' as viewport_utils;
import 'side_highlightment.dart';
import 'zoom_controller.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4, Vector3;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'matrix_math.dart';
import 'package:window_manager/window_manager.dart';
import 'constants.dart' as constants;
import 'types.dart';


class ImageController extends StatefulWidget {
  const ImageController({
    super.key,
    required this.image,
    this.zoomController,
    this.scaleFactor = 600.0,
    this.minScale = 0.1,
    this.maxScale = 10.0,
    required this.imageControlMode,
    required this.fitModeNotifier,
    required this.anchorInfo,
  });

  final ImageProvider<Object> image;
  
  final double scaleFactor;
  
  final double minScale;
  final double maxScale;
  final boundaryMargin = EdgeInsets.zero;
  final ZoomController? zoomController;
  final ValueNotifier<ImageControlMode> imageControlMode;
  final ValueNotifier<FitMode> fitModeNotifier;
  final ValueNotifier<AnchorInfo?> anchorInfo;


  @override
  State<ImageController> createState() => _ImageControllerState();
}

typedef ImageZoomLevelChanged = void Function(double zoomLevel);

class _ImageControllerState extends State<ImageController> with WindowListener {

  final GlobalKey _parentKey = GlobalKey();
  final GlobalKey _childKey = GlobalKey();
  final TransformationController _transformer = TransformationController();
  CancellationToken imageScaleCalculationCancellationToken = CancellationToken();
  double lastCalculatedZoomLevel = 1.0;
  double imageToTransformScaleMultiplier = -1;
  Size lastViewportSize = Size.zero;
  ImageInfo? currentImageInfo;
  bool _animatedTransform = false;

  final EdgeData leftEdgeData = EdgeData();
  final EdgeData rightEdgeData = EdgeData();

  final KeyEventScrollingHelper _keyEventScrollingHelper = KeyEventScrollingHelper();
  ImageProvider<Object>? activeImageProvider;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    windowManager.addListener(this);
    widget.zoomController?.addListener(_onZoomLevelHasBeenSet);
    widget.imageControlMode.addListener(_onImageControlModeChanged);
    widget.fitModeNotifier.addListener(_onFitModeChanged);
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        FocusScope.of(context).requestFocus(_focusNode);
      }
    });
    super.initState();
  }

  @override
  void didUpdateWidget(covariant ImageController oldWidget) {
    super.didUpdateWidget(widget);
    if (oldWidget.image != widget.image) {
      _handleNewImage();
    }
  }

  void _handleNewImage() async {
    if (widget.anchorInfo.value == null) {
      _transformer.value = Matrix4.identity();
    }

    currentImageInfo = null;

    activeImageProvider = widget.image;

    await _updateZoomLevel();

    if (widget.anchorInfo.value != null) {
      _applyAnchor(widget.anchorInfo.value!);
    }
  }

  void _applyAnchor(AnchorInfo anchorInfo) {
    
    Offset aligmentOffset = constants.alignmentOffsets[anchorInfo.aligment] ?? Offset.zero;
    
    Vector3 defaultPosition = Vector3.zero();
    
    if (aligmentOffset.dx == 0 || aligmentOffset.dy == 0) {

      Vector3 centerTranslation = viewport_utils.getCenterTranslation(
        _transformer.value,
        _viewport,
        _boundaryRect,
      );
    
      defaultPosition = Vector3(
        aligmentOffset.dx == 0 ? centerTranslation.x : 0,
        aligmentOffset.dy == 0 ? centerTranslation.y : 0,
        0,
      );
    }
    
    _transformer.value = _transformer.value.clone()
      ..setTranslation(defaultPosition);
    
    _transformer.value = _matrixTranslate(_transformer.value, aligmentOffset);
  }

  @override
  Widget build(BuildContext context) {

    return Focus(
      focusNode: _focusNode..requestFocus(),
      autofocus: true,
      onKeyEvent: _onKeyEvent,
      onFocusChange: _onFocusChange,
      child: Listener(
        key: _parentKey,
        onPointerSignal: _receivedPointerSignal,
        behavior: HitTestBehavior.opaque,
        child: GestureDetector(
          onPanUpdate: _onPanGestureUpdate,
          child: Stack(
            children: [
              _buildTransformedImage(),
              SideHighlightment(
                highlightTrigger: leftEdgeData.hightlightTrigger,
                isLeft: true,
                cancelationTrigger: leftEdgeData.hightlightCancelTrigger,
                appearTime: constants.edgeArrowImageChangingProtectionTime,
              ),
              SideHighlightment(
                highlightTrigger: rightEdgeData.hightlightTrigger,
                isLeft: false,
                cancelationTrigger: rightEdgeData.hightlightCancelTrigger,
                appearTime: constants.edgeArrowImageChangingProtectionTime,
              ),
            ],
          ),
        ),
      ),
    );
  }

  AnimatedBuilder _buildTransformedImage() {
    return AnimatedBuilder(
    animation: _transformer,
    builder: (context, _) => TweenAnimationBuilder<Matrix4>(
      tween: Matrix4Tween(begin: _transformer.value, end: _transformer.value),
      duration: _animatedTransform
          ? const Duration(milliseconds: 200)
          : Duration.zero,
      curve: Curves.easeInOut,
      builder: (context, matrix, child) {
        return Transform(
          transform: matrix,
          child: KeyedSubtree(
            key: _childKey,
            child: Image(
              image: widget.image,
              fit: widget.fitModeNotifier.value == FitMode.original
                  ? BoxFit.scaleDown
                  : BoxFit.contain,
              alignment: Alignment.center,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
        );
      },
      child: null,
    ),
  );
  }
  
  void _receivedPointerSignal(PointerSignalEvent event) {
    final Offset local = event.localPosition;
    final double scaleChange;
    if (event is PointerScrollEvent) {
      // Ignore left and right mouse wheel scroll.
      if (event.scrollDelta.dy == 0.0) {
        return;
      }
      scaleChange = math.exp(-event.scrollDelta.dy / widget.scaleFactor);
    } else if (event is PointerScaleEvent) {
      scaleChange = event.scale;
    } else {
      return;
    }
    double resultScale = widget.zoomController?.zoom(scaleChange, false) ?? 1.0;
    _scaleTransformer(resultScale, local);
    lastCalculatedZoomLevel = resultScale;
    widget.zoomController?.applyZoom();
  }

  void _scaleTransformer(
    double desiredScale,
    Offset local, {
    ImageControlMode? overrideImageControlMode,
  }) {
    final double transformerScale = _transformer.value.getMaxScaleOnAxis();
    final double desiredTransformerScale =
        desiredScale / imageToTransformScaleMultiplier;

    final double transformerScaleChange =
        desiredTransformerScale / transformerScale;

    final Offset focalPointScene = _transformer.toScene(local);
    final scaledMatrix = matrix_utils.matrixScale(
      _transformer.value,
      transformerScaleChange,
    );

    // After scaling, translate such that the event's position is at the
    // same scene point before and after the scale.
    final Offset focalPointSceneScaled = toScene(scaledMatrix, local);

    _animatedTransform = true;

    _transformer.value = _matrixTranslate(
      scaledMatrix,
      (focalPointSceneScaled - focalPointScene),
      overrideImageControlMode: overrideImageControlMode,
    );
    
    _updateScrollSpeed();
  }

  // The Rect representing the child's parent.
  Rect get _viewport => viewport_utils.getViewport(_parentKey);

  Rect get _boundaryRect => viewport_utils.getBoundaryRect(
      _childKey,
      widget.boundaryMargin,
    );

  // The Rect representing the image.
  Rect get _imageViewport => viewport_utils.getImageViewport(
      _boundaryRect,
      currentImageInfo,
    );
  
  // Return a new matrix representing the given matrix after applying the given
  // translation.
  Matrix4 _matrixTranslate(
    Matrix4 matrix,
    Offset translation, {
    bool force = false,
    ImageControlMode? overrideImageControlMode,
  }) {
    return matrix_utils.matrixTranslate(
      matrix,
      translation,
      force: force,
      overrideImageControlMode: overrideImageControlMode,
      boundaryRect: _boundaryRect,
      imageViewport: _imageViewport,
      viewport: _viewport,
    );
  }

  
  void _onPanGestureUpdate(DragUpdateDetails details) {
    final Offset delta = details.delta;
    if (delta == Offset.zero) {
      return;
    }
    _animatedTransform = false;
    _transformer.value = _matrixTranslate(
      _transformer.value,
      delta / _transformer.value.getMaxScaleOnAxis(),
    );
  }

  Future _updateZoomLevel() async {
    if (widget.zoomController == null) {
      return; // No zoom controller provided, cannot update zoom level
    }

    imageToTransformScaleMultiplier = -1;
    widget.zoomController!.setPreferedZoom(imageToTransformScaleMultiplier);
    imageScaleCalculationCancellationToken.cancel();
    imageScaleCalculationCancellationToken = CancellationToken();

    var currectedMatrix = _matrixTranslate(
      _transformer.value,
      Offset.zero,
      force: true,
    );

    if (currectedMatrix != _transformer.value) {
      _animatedTransform = false;
      _transformer.value = currectedMatrix;
    }

    await _calculateImageToTransformScaleMultiplier()
        .then((multiplier) {
          widget.zoomController!.setPreferedZoom(multiplier);

          var isAnimating = _animatedTransform;
          widget.zoomController!.setZoom(
            multiplier * _transformer.value.getMaxScaleOnAxis(),
          );

          _animatedTransform = isAnimating;
        })
        .onError((error, stackTrace) {
          log('Error calculating zoom level: $error');
        });
  }

  void _updateScrollSpeed() {
    if (currentImageInfo == null) {
      return;
    }

    var image = currentImageInfo!.image;

    double scrollSpeed = calculateScrollSpeed(
      imageHeight: image.height.toDouble(),
      imageWidth: image.width.toDouble(),
      viewportHeight: _viewport.height,
      viewportWidth: _viewport.width,
      zoom: _transformer.value.getMaxScaleOnAxis(),
    );

    _keyEventScrollingHelper.setScrollingSpeed(
      Offset(scrollSpeed, scrollSpeed),
    );
  }

  double calculateScrollSpeed({
    required double imageWidth,
    required double imageHeight,
    required double viewportWidth,
    required double viewportHeight,
    required double zoom,
  }) {
    const double baseScrollSpeed = 50.0;
    const double zoomScalingExponent = 0.5;
    const double viewRatioScalingExponent = 0.5;
    const double minScrollSpeed = 5.0;

    // Calculate viewport-to-image ratio
    double vRatio = math.min(
      viewportWidth / (imageWidth * zoom),
      viewportHeight / (imageHeight * zoom),
    );

    // Zoom scaling: reduce speed at higher zoom levels
    double zoomScaling = 1 / math.pow(zoom, zoomScalingExponent);

    // Viewport scaling: increase speed when image fits in viewport
    double viewportScaling = math.max(1.0, math.pow(vRatio, viewRatioScalingExponent).toDouble());

    // Effective scroll speed
    double scrollSpeed = baseScrollSpeed * zoomScaling * viewportScaling;
    return math.max(scrollSpeed, minScrollSpeed);
  }

  Future<double> _calculateImageToTransformScaleMultiplier() async {
    
    if (imageToTransformScaleMultiplier != -1) {
      return imageToTransformScaleMultiplier; // Return cached value if available
    }

    while (!_isLayoutReady()) {
      await Future.delayed(
        Duration.zero,
      ).asCancellable(imageScaleCalculationCancellationToken);
    }

    Size viewportSize = _viewport.size;
    ImageInfo imageInfo = await _getImageInfo();
    final image = imageInfo.image;

    double fitScale = 1.0;

    if (widget.fitModeNotifier.value == FitMode.original) {
      // Calculate the scale applied by BoxFit.scaleDown
      double scaleX = viewportSize.width / image.width;
      double scaleY = viewportSize.height / image.height;

      if (scaleX < 1.0 || scaleY < 1.0) {
        fitScale = math.min(scaleX, scaleY);
      }
    } else {
      // Calculate the scale applied by BoxFit.contain
      double scaleX = viewportSize.width / image.width;
      double scaleY = viewportSize.height / image.height;
      fitScale = math.min(scaleX, scaleY);
    }
    
    imageToTransformScaleMultiplier = fitScale;
    return fitScale;
  }

  bool _isLayoutReady() {
    return _childKey.currentContext != null && _parentKey.currentContext != null;
  }

  Future<ImageInfo> _getImageInfo() async {
    if (currentImageInfo != null) {
      return currentImageInfo!; // Return cached value if available
    }
    final imageInfo = await getImageCompleter(widget.image).future;
    currentImageInfo = imageInfo;
    return imageInfo;
  }

  void setZoomLevel(double zoomLevel) {
    if (lastCalculatedZoomLevel == zoomLevel) {
      return; // No change in zoom level, nothing to do
    }
    Offset imageCenter = _getImageCenterOffset();
    _scaleTransformer(zoomLevel, imageCenter, overrideImageControlMode: ImageControlMode.full);
  }

  Offset _getImageCenterOffset() {
    if (_childKey.currentContext == null || _parentKey.currentContext == null) {
      return Offset.zero; // Contexts not available yet
    }
    
    Size viewportSize = _viewport.size;
    
    final positionRow = _transformer.value.getColumn(3);
    final double xOffset = positionRow.x;
    final double yOffset = positionRow.y;
    final double currentScale = _transformer.value.getMaxScaleOnAxis();
    
    final double centerX = currentScale * (viewportSize.width / 2) + xOffset;
    final double centerY = currentScale * (viewportSize.height / 2) + yOffset;
    
    var imageCenter = Offset(centerX, centerY);
    return imageCenter;
  }

  void _onZoomLevelHasBeenSet() {
    double zoomLevel = widget.zoomController!.value;
    setZoomLevel(zoomLevel);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback(_onFrame);
  }

  void _onFrame(Duration timeStamp) {
    
    if (_isLayoutReady()) {
      _arrowKeysScrollHandling();
      _checkViewportSize();
    }

    if (mounted) {
      WidgetsBinding.instance.scheduleFrameCallback(_onFrame);
    }
  }

  void _arrowKeysScrollHandling() {
    final offset = _keyEventScrollingHelper.getAccomulatedOffset();
    if (offset == Offset.zero) return;

    if (_tryToTranslate(offset)) {
      _animatedTransform = false;
    } else if (widget.imageControlMode.value != ImageControlMode.full) {
      _handleEdgeNavigation(offset);
    }
  }

  void _handleEdgeNavigation(Offset offset) {

    if (widget.imageControlMode.value == ImageControlMode.full) {
      return;
    }

    if (offset.dx == 0 || offset.dy != 0) return;

    final viewportFit = viewport_utils.computeViewportFit(
      _transformer.value,
      _imageViewport,
      _boundaryRect,
      strict: false,
    );

    if (!viewportFit.fitsWidth) return;

    final edgeData = offset.dx > 0 ? leftEdgeData : rightEdgeData;
    edgeData.triedToMoveTime.value = DateTime.now();
    edgeData.hightlightTrigger.value = !edgeData.hightlightTrigger.value;
  }

  bool _tryToTranslate(Offset offset) {
    var result = _matrixTranslate(_transformer.value, offset);
    var lengthSquared = (result.getTranslation() - _transformer.value.getTranslation()).length2;
    if (lengthSquared < constants.minTranslationLength) {
      return false;
    }
    _transformer.value = result;
    return true;
  }

  void _checkViewportSize() {
    Size viewportSize = _viewport.size;
    if (lastViewportSize != viewportSize) {
      lastViewportSize = viewportSize;
      _updateZoomLevel();
    }
  }

  void _onImageControlModeChanged() {
    _animatedTransform = true;
    _transformer.value = Matrix4.identity();
  }

  void _onFitModeChanged() {
    _animatedTransform = true;
    _transformer.value = Matrix4.identity();
    _updateZoomLevel();
    setState(() {});
  }

  void _onFocusChange(bool value) {
    _keyEventScrollingHelper.handleFocusChange(value);
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {

    if (_keyEventScrollingHelper.tryToHandleKey(node, event) == KeyEventResult.ignored) {
      return KeyEventResult.ignored;
    }

    return _handleEdgeArrowMovement(event);
  }

  KeyEventResult _handleEdgeArrowMovement(KeyEvent event) {
    
    if (widget.imageControlMode.value == ImageControlMode.full) {
      return KeyEventResult.handled;
    }
    
    if ((event is KeyRepeatEvent)) {
      return KeyEventResult.handled;
    }
    
    if (event is KeyUpEvent) {
      return KeyEventResult.handled;
    }
    
    const double offsetDistance = 10;
    
    switch (event.physicalKey) {
    
      case PhysicalKeyboardKey.arrowLeft:
        if (!_checkTranslation(const Offset(offsetDistance, 0))) {
          return _handleNextImageOpeningProtection(leftEdgeData);
        }
    
      case PhysicalKeyboardKey.arrowRight:
        if (!_checkTranslation(const Offset(-offsetDistance, 0))) {
          return _handleNextImageOpeningProtection(rightEdgeData);
        }
    }
    
    return KeyEventResult.handled;
  }

  KeyEventResult _handleNextImageOpeningProtection(EdgeData edgeData) {

    final viewportFit = viewport_utils.computeViewportFit(
      _transformer.value,
      _imageViewport,
      _boundaryRect,
      strict: false,
    );

    if (!viewportFit.fitsWidth) {
      return KeyEventResult.ignored;
    }

    var moveTime = edgeData.triedToMoveTime.value;

    if (!_isSecondClickDetected(moveTime)) {
      return KeyEventResult.handled;
    }

    edgeData.triedToMoveTime.value = DateTime(0);
    edgeData.hightlightCancelTrigger.value = !edgeData.hightlightCancelTrigger.value;
    _keyEventScrollingHelper.resetOffset();
    return KeyEventResult.ignored;
  }

  bool _isSecondClickDetected(DateTime dateTime) {
    return DateTime.now().difference(dateTime).inMilliseconds <
        constants.edgeArrowImageChangingProtectionTime;
  }

  bool _checkTranslation(Offset offset) {
    var result = _matrixTranslate(_transformer.value, offset);
    var lengthSquared =
        (result.getTranslation() - _transformer.value.getTranslation()).length2;
    return lengthSquared > constants.minTranslationLength;
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    imageScaleCalculationCancellationToken.cancel();
    widget.zoomController?.removeListener(_onZoomLevelHasBeenSet);
    widget.imageControlMode.removeListener(_onImageControlModeChanged);
    widget.fitModeNotifier.removeListener(_onFitModeChanged);
    _focusNode.dispose();
    super.dispose();
  }
}
