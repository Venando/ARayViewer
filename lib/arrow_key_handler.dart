import 'package:flutter/services.dart';
import 'constants.dart';

typedef IndexGetter = int Function();
typedef IndexSetter = void Function(int);
typedef WrappedIndexGetter = int Function(int);

class ArrowKeyHandler {
  final IndexGetter getCurrentIndex;
  final IndexSetter setCurrentIndex;
  final WrappedIndexGetter getWrappedIndex;

  int lastOffset = 0;

  ArrowKeyHandler({
    required this.getCurrentIndex,
    required this.setCurrentIndex,
    required this.getWrappedIndex
  });

  void handleArrowKey(LogicalKeyboardKey logicalKey) {
    if (logicalKey != LogicalKeyboardKey.arrowLeft &&
        logicalKey != LogicalKeyboardKey.arrowRight) {
      return; // Only handle arrow keys
    }

    int valueOffset = logicalKey == LogicalKeyboardKey.arrowLeft ? -1 : 1;

    int valueMultiplier = 1;
    if (HardwareKeyboard.instance.isShiftPressed) {
      valueMultiplier = shiftPagingSpeed;
    } else if (HardwareKeyboard.instance.isControlPressed) {
      valueMultiplier = ctrlPagingSpeed;
    }

    var currentIndexValue = getCurrentIndex();
    var modifiedOffset = valueOffset * valueMultiplier;

    currentIndexValue += modifiedOffset;

    currentIndexValue = getWrappedIndex(currentIndexValue);

    if (currentIndexValue == getCurrentIndex()) {
      return; // No change in index, do nothing
    }

    lastOffset = modifiedOffset;

    setCurrentIndex(currentIndexValue);
  }

  void handleArrowKeyHoldEvent(KeyRepeatEvent event) {
    var logicalKey = event.logicalKey;

    if (logicalKey != LogicalKeyboardKey.arrowLeft &&
        logicalKey != LogicalKeyboardKey.arrowRight) {
      return; // Only handle arrow keys
    }

    handleArrowKey(logicalKey);
  }

  int getLastOffset() {
    return lastOffset;
  }
}