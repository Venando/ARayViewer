import 'package:flutter/foundation.dart';
import 'list_extension.dart';

class ImageIndexController extends ValueNotifier<int?> {

  final String defaultFilePath;
  late List<String> imageFiles;

  ImageIndexController({required this.defaultFilePath})
      : super(-1);

  int getWrappedIndex(int currentIndexValue) {
    return imageFiles.getWrappedIndex(currentIndexValue);
  }

  void setCurrentIndex(int newValue) {
    value = imageFiles.getWrappedIndex(newValue);
  }

  String get activeFilePath =>
      (value != null && value! >= 0 && value! < imageFiles.length)
          ? imageFiles[value!]
          : defaultFilePath;

  void initialize({required List<String> imageFiles, required int initialIndex}) {
    this.imageFiles = imageFiles;
    value = initialIndex;
  }
}