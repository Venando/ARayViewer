import 'dart:async';
import 'dart:collection';
import 'dart:core';
import 'dart:io';
import 'dart:math';
import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'constants.dart' as constants;
import 'list_extension.dart';

class ImageEntry {
  final String path;
  final ImageProvider<Object> imageProvider;

  ImageEntry({required this.path, required this.imageProvider});
}

typedef ImageCallback =
    void Function(String imagePath, ImageProvider<Object> image);

class ImagePrecacheService {
  final BuildContext context;

  ImagePrecacheService(this.context);

  // Cache storage
  final Map<String, DoubleLinkedQueueEntry<ImageEntry>> _pathToEntry = {};
  final DoubleLinkedQueue<ImageEntry> _cacheQueue =
      DoubleLinkedQueue<ImageEntry>();
  final Map<String, bool> _loadStatus = {};

  // Loading queue management
  final List<String> _pendingQueue = [];
  bool _isProcessingQueue = false;

  // Request handling
  ImageCallback? _imageCallback;
  String? _requestedImagePath;

  void onCurrentIndexChanged({
    required List<String>? imageFiles,
    required int? currentIndex,
    required int lastOffset,
  }) {
    if (imageFiles == null || currentIndex == null) return;

    final indicesToPrecache = _getIndicesToCache(
      imageFiles: imageFiles,
      currentIndex: currentIndex,
      lastOffset: lastOffset,
    );

    String priorityLoadingImage =
        imageFiles[imageFiles.getWrappedIndex(currentIndex + lastOffset)];

    _scheduleImagesForLoading(
      imagesToLoad: indicesToPrecache
          .map((index) => imageFiles[index])
          .toList(),
      priorityImage: priorityLoadingImage,
    );

    _evictExcessImages();
  }

  bool isImageLoaded(String imagePath) {
    return _loadStatus[imagePath] ?? false;
  }

  void setImageCallback(ImageCallback callback) {
    _imageCallback = callback;
  }

  void requestImage(String imagePath) {
    _requestedImagePath = null;

    if (_loadStatus.containsKey(imagePath)) {
      if (isImageLoaded(imagePath)) {
        final entry = _pathToEntry[imagePath]?.element;
        if (entry != null) {
          _imageCallback?.call(imagePath, entry.imageProvider);
          return;
        }
        //  Should not happen, but if the entry is missing, reload
        dev.log('Cache synchronization error for $imagePath, reloading...');
        _loadStatus.remove(imagePath);
        _scheduleImagesForLoading(imagesToLoad: [imagePath]);
      }
      _requestedImagePath = imagePath;
    } else {
      _requestedImagePath = imagePath;
      _pendingQueue.contains(imagePath)
          ? _prioritizeImage(imagePath)
          : _scheduleImagesForLoading(imagesToLoad: [imagePath]);
    }
  }

  void dispose() {
    _pendingQueue.clear();
    _loadStatus.clear();
    _pathToEntry.clear();
    while (_cacheQueue.isNotEmpty) {
      final entry = _cacheQueue.removeFirst();
      entry.imageProvider.evict();
    }
    _cacheQueue.clear();
    _imageCallback = null;
    _requestedImagePath = null;
  }

  /// Calculates which image indices to cache based on current position
  Set<int> _getIndicesToCache({
    required List<String> imageFiles,
    required int currentIndex,
    required int lastOffset,
  }) {
    final indicesToPrecache = <int>{};
    for (final offset in [
      1,
      constants.shiftPagingSpeed,
      constants.ctrlPagingSpeed,
    ]) {
      indicesToPrecache.add(imageFiles.getWrappedIndex(currentIndex - offset));
      indicesToPrecache.add(imageFiles.getWrappedIndex(currentIndex + offset));
    }
    indicesToPrecache.add(
      imageFiles.getWrappedIndex(currentIndex + lastOffset * 2),
    );
    return indicesToPrecache;
  }

  void _scheduleImagesForLoading({
    required List<String> imagesToLoad,
    String priorityImage = '',
  }) {
    int availableSlots = constants.maxAsyncLoading - _getLoadingImageCount();

    if (imagesToLoad.remove(priorityImage)) {
      imagesToLoad.add(priorityImage);
    }

    for (int i = imagesToLoad.length - 1; i >= 0; i--) {
      String imagePath = imagesToLoad[i];

      if (!_updateImagePriority(imagePath)) {
        if (availableSlots > 0) {
          _cacheImage(imagePath);
          availableSlots--;
        } else {
          _pendingQueue.remove(imagePath);
          _pendingQueue.add(imagePath);
        }
      }
    }

    _prioritizeImage(priorityImage);
    _prioritizeImage(_requestedImagePath);

    while (_pendingQueue.length > constants.maxLoadingQueue) {
      _pendingQueue.removeAt(0);
    }

    _processQueue();
  }

  /// Moves image to end of queue if it exists
  void _prioritizeImage(String? imagePath) {
    if (imagePath != null &&
        imagePath.isNotEmpty &&
        _pendingQueue.remove(imagePath)) {
      _pendingQueue.add(imagePath);
    }
  }

  void _processQueue() async {
    if (_pendingQueue.isEmpty || _isProcessingQueue) return;

    _isProcessingQueue = true;

    while (_pendingQueue.isNotEmpty) {
      int canLoad = min(
        constants.maxAsyncLoading - _getLoadingImageCount(),
        _pendingQueue.length,
      );

      if (canLoad <= 0) {
        await Future.delayed(const Duration(milliseconds: 10));
        continue;
      }
      for (int i = 0; i < canLoad; i++) {
        final imagePath = _pendingQueue.removeLast();
        _cacheImage(imagePath);
      }
      _evictExcessImages();
    }
    _isProcessingQueue = false;
  }

  int _getLoadingImageCount() {
    return _loadStatus.values.where((loaded) => !loaded).length;
  }

  /// Updates priority of cached image if it exists
  bool _updateImagePriority(String imagePath) {
    final entry = _pathToEntry[imagePath];
    if (entry != null) {
      entry.remove();
      _cacheQueue.addLast(entry.element);
      _pathToEntry[imagePath] = _cacheQueue.lastEntry()!;
      return true;
    }
    return false;
  }

  void _cacheImage(String imagePath) {
    try {
      final file = File(imagePath);
      if (!file.existsSync()) {
        dev.log('File does not exist: $imagePath');
        return;
      }
      final image = Image.file(file).image;
      final imageEntry = ImageEntry(path: imagePath, imageProvider: image);
      _cacheQueue.addLast(imageEntry);
      _pathToEntry[imagePath] = _cacheQueue.lastEntry()!;
      _loadStatus[imagePath] = false;
      _loadImageIntoMemory(imagePath, image);
    } catch (e, stackTrace) {
      dev.log('Error caching image $imagePath: $e', stackTrace: stackTrace);
    }
  }

  Future<void> _loadImageIntoMemory(
    String imagePath,
    ImageProvider<Object> image,
  ) async {
    final completer = Completer<void>();
    image
        .resolve(ImageConfiguration.empty)
        .addListener(
          ImageStreamListener(
            (ImageInfo info, bool synchronousCall) {
              if (_loadStatus.containsKey(imagePath)) {
                _loadStatus[imagePath] = true;
              }
              if (_requestedImagePath == imagePath) {
                _imageCallback?.call(imagePath, image);
                _requestedImagePath = null;
              }
              completer.complete();
            },
            onError: (dynamic error, StackTrace? stackTrace) {
              _loadStatus[imagePath] = false;
              dev.log(
                'Failed to load image $imagePath: $error',
                stackTrace: stackTrace,
              );
              completer.completeError(error, stackTrace);
            },
          ),
        );
    return completer.future;
  }

  void _evictExcessImages() {
    while (_cacheQueue.length > constants.maxCachedImageNumber) {
      final entry = _cacheQueue.removeFirst();
      _pathToEntry.remove(entry.path);
      _loadStatus.remove(entry.path);
      entry.imageProvider.evict();
    }
  }
}
