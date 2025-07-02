import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'anchor_info.dart';
import 'types.dart';
import 'package:window_manager/window_manager.dart';

class TopApplicationBar extends StatelessWidget {
  final ColorScheme colorScheme;
  final ValueNotifier<String> fileName;
  final bool isFullScreen;
  final bool isMaximazed;
  final VoidCallback onMinimize;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onToggleMaximize;
  final VoidCallback onExit;
  final VoidCallback onToggleImageControlMode;
  final VoidCallback onAnchorSelectionButton;
  final ValueNotifier<ImageControlMode>  imageControlMode;
  final ValueNotifier<AnchorInfo?> selectedAnchorInfo;

  const TopApplicationBar({
    super.key,
    required this.colorScheme,
    required this.fileName,
    required this.isFullScreen,
    required this.isMaximazed,
    required this.imageControlMode,
    required this.onMinimize,
    required this.onToggleFullscreen,
    required this.onToggleMaximize,
    required this.onExit,
    required this.onToggleImageControlMode,
    required this.onAnchorSelectionButton,
    required this.selectedAnchorInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        DragToMoveArea(
          child: Container(height: 40, color: colorScheme.surfaceContainerHigh),
        ),
        Row(
          children: [
            _getImageControlModeToggleButton(),

            _getAnchorButton(),

            const SizedBox(width: 30),

            Expanded(
              child: Center(
                child: IgnorePointer(
                  ignoring: true,
                  child: ValueListenableBuilder(
                    valueListenable: fileName,
                    builder: (context, value, child) {
                      return Text(
                        value,
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      );
                    }
                  ),
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen_outlined,
              ),
              color: colorScheme.onSurface,
              tooltip: isFullScreen ? 'Restore (F11)' : 'Fullscreen (F11)',
              onPressed: onToggleFullscreen,
            ),

            const SizedBox(width: 10),

            IconButton(
              icon: const Icon(Icons.remove),
              color: colorScheme.onSurface,
              tooltip: 'Minimize',
              onPressed: onMinimize,
            ),
            IconButton(
              icon: isMaximazed
                ? Icon(CupertinoIcons.rectangle_on_rectangle)
                : Icon(
                  CupertinoIcons.rectangle,
                  size: 20, // Make the single rectangle icon smaller
                ),
              color: colorScheme.onSurface,
              tooltip: isMaximazed ? 'Unmaximize' : 'Maximize',
              onPressed: onToggleMaximize,
            ),
            IconButton(
              icon: const Icon(Icons.close),
              color: colorScheme.onSurface,
              tooltip: 'Exit',
              onPressed: onExit,
            ),
          ],
        ),
      ],
    );
  }
  

  Widget _getImageControlModeToggleButton() {
    return ValueListenableBuilder<ImageControlMode>(
      valueListenable: imageControlMode,
      builder: (context, value, child) => (Stack(
        alignment: Alignment.center,
        children: [
          if (value == ImageControlMode.full)
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: colorScheme.primary.withAlpha(0),
                shape: BoxShape.circle,
                border: Border.all(color: colorScheme.primary, width: 2),
              ),
            ),
          SizedBox(
            width: 40,
            height: 40,
            child: IconButton(
              icon: Icon(
                Icons.open_with,
                color: value == ImageControlMode.full
                    ? colorScheme.primary
                    : colorScheme.onSurface,
              ),
              tooltip: 'Image Control Mode',
              onPressed: onToggleImageControlMode,
            ),
          ),
        ],
      )),
    );
  }

  ValueListenableBuilder<AnchorInfo?> _getAnchorButton() {
    return ValueListenableBuilder(
      valueListenable: selectedAnchorInfo,
      builder: (context, value, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            if (value != null)
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: colorScheme.primary, width: 2)
                ),
              ),
            IconButton(
              onPressed: onAnchorSelectionButton,
              icon: Icon(value != null ? value.icon : Icons.anchor_outlined),
              tooltip: value != null ? 'Cancel Anchor' : 'Anchor Selection',
              color: value != null ? colorScheme.primary : colorScheme.onSurface,
            ),
          ],
        );
      },
    );
  }

}
