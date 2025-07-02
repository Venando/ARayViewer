
import 'dart:collection';
import 'package:flutter/material.dart';

final UnmodifiableListView<String> supportedImageExtensions = UnmodifiableListView([
  '.jpg',
  '.jpeg',
  '.png',
  '.gif',
  '.bmp',
  '.webp'
]);

const double minZoom = 0.01;
const double maxZoom = 3.0;

const int ctrlPagingSpeed = 5;
const int shiftPagingSpeed = 10;

const int maxCachedImageNumber = 30;
const int maxAsyncLoading = 3;
const int maxLoadingQueue = 10;

const int edgeArrowImageChangingProtectionTime = 800; // in milliseconds

const double minTranslationLength = 0.001;

const String applicationName = "ARay Viewer";

const double offsetValue = 50000;

final Map<Alignment, Offset> alignmentOffsets = {
  Alignment.topLeft: Offset(offsetValue, offsetValue),
  Alignment.topCenter: Offset(0, offsetValue),
  Alignment.topRight: Offset(-offsetValue, offsetValue),
  Alignment.centerLeft: Offset(offsetValue, 0),
  Alignment.center: Offset(0, 0),
  Alignment.centerRight: Offset(-offsetValue, 0),
  Alignment.bottomLeft: Offset(offsetValue, -offsetValue),
  Alignment.bottomCenter: Offset(0, -offsetValue),
  Alignment.bottomRight: Offset(-offsetValue, -offsetValue),
};
  