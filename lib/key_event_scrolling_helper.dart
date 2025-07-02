import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class KeyEventScrollingHelper {

  static const double offsetPerSecond = 12;
  static const Offset minScrollSpeed = Offset(0, 0);

  Map<PhysicalKeyboardKey, double> keyActivationTime = <PhysicalKeyboardKey, double>{};

  List<PhysicalKeyboardKey> arrowKeys = [PhysicalKeyboardKey.arrowDown, PhysicalKeyboardKey.arrowLeft, PhysicalKeyboardKey.arrowUp, PhysicalKeyboardKey.arrowRight];

  Offset _scrollSpeed = Offset(1, 1);

  Offset getAccomulatedOffset() {

    if (keyActivationTime.isEmpty) {
      return Offset.zero;
    }

    Offset baseOffset = Offset.zero;

    double secondsNow = _getTimeInSeconds();

    for (MapEntry<PhysicalKeyboardKey, double> keyActionEntry in keyActivationTime.entries) {

      double secondsPassed = secondsNow - keyActionEntry.value;
      baseOffset += _getOffset(keyActionEntry.key, secondsPassed);
    }

    for (var key in keyActivationTime.keys) {
      keyActivationTime[key] = secondsNow;
    }

    return baseOffset;
  }

  double _getTimeInSeconds() {
    return DateTime.now().millisecondsSinceEpoch / 1000.0;
  }
  
  Offset _getOffset(PhysicalKeyboardKey key, double seconds) {
    double offsetDistance = seconds * offsetPerSecond;
    switch (key) {
      case PhysicalKeyboardKey.arrowUp:
        return Offset(0, offsetDistance * _scrollSpeed.dy);
      case PhysicalKeyboardKey.arrowDown:
        return Offset(0, -offsetDistance * _scrollSpeed.dy);
      case PhysicalKeyboardKey.arrowLeft:
        return Offset(offsetDistance * _scrollSpeed.dx, 0);
      case PhysicalKeyboardKey.arrowRight:
        return Offset(-offsetDistance * _scrollSpeed.dx, 0);
    }
    return Offset.zero;
  }

  void handleFocusChange(bool value) {
    if (!value) {
      keyActivationTime.clear();
    }
  }

  void resetOffset() {
    keyActivationTime.clear();
  }
  
  KeyEventResult tryToHandleKey(FocusNode node, KeyEvent event) {

    if (event.deviceType != KeyEventDeviceType.keyboard) {
      return KeyEventResult.ignored;
    }

    if (!arrowKeys.contains(event.physicalKey)) {
      return KeyEventResult.ignored;
    }

    if (event is! KeyDownEvent && event is! KeyRepeatEvent && event is! KeyUpEvent) {
      return KeyEventResult.ignored;
    }

    if (event is KeyDownEvent) {
      keyActivationTime[event.physicalKey] = _getTimeInSeconds();
    }

    if (event is KeyUpEvent) {
      keyActivationTime.remove(event.physicalKey);
    }

    return KeyEventResult.handled;
  }
  
  void setScrollingSpeed(Offset scrollSpeed) {
    _scrollSpeed = Offset(
      minScrollSpeed.dx + scrollSpeed.dx,
      minScrollSpeed.dy + scrollSpeed.dy,
    );
  }

}
