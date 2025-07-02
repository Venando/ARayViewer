import 'dart:async';
import 'package:flutter/rendering.dart';

Completer<ImageInfo> getImageCompleter(ImageProvider<Object> image) {
  final imageStream = image.resolve(const ImageConfiguration());
  final completer = Completer<ImageInfo>();
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (ImageInfo info, bool _) {
      completer.complete(info);
      imageStream.removeListener(listener);
    },
    onError: (dynamic error, StackTrace? stackTrace) {
      completer.completeError(error, stackTrace);
      imageStream.removeListener(listener);
    },
  );
  imageStream.addListener(listener);
  return completer;
}
