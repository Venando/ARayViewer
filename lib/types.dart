import 'package:flutter/material.dart';

enum ImageControlMode { limited, full }

enum FitMode { stretch, original }

class EdgeData {
  final ValueNotifier<DateTime> triedToMoveTime = ValueNotifier<DateTime>(
    DateTime(0),
  );
  final ValueNotifier<bool> hightlightTrigger = ValueNotifier(false);
  final ValueNotifier<bool> hightlightCancelTrigger = ValueNotifier(false);
}

class ViewportFit {
  final bool fitsWidth;
  final bool fitsHeight;

  ViewportFit({required this.fitsWidth, required this.fitsHeight});
}
