import 'package:flutter/material.dart';
import 'constants.dart';
import 'types.dart';
import 'zoom_controller.dart';

class BottomPanel extends StatelessWidget {
  const BottomPanel({
    super.key,
    required ZoomController zoomController,
    required ColorScheme colorScheme,
    required ValueNotifier<FitMode> fitMode,
    required void Function() onToggleFitMode,
  }) : _onToggleFitMode = onToggleFitMode, _fitMode = fitMode,
       _zoomController = zoomController,
       _colorScheme = colorScheme;

  final ValueNotifier<FitMode> _fitMode;
  final ZoomController _zoomController;
  final ColorScheme _colorScheme;
  final VoidCallback _onToggleFitMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      color: _colorScheme.surfaceContainerHigh,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            icon: ValueListenableBuilder<FitMode>(
              valueListenable: _fitMode,
              builder: (context, fitMode, _) => Icon(
                fitMode == FitMode.original ? Icons.aspect_ratio : Icons.fit_screen,
                color: _colorScheme.secondary,
              ),
            ),
            tooltip: 'Stretch/Original Size',
            onPressed: _onToggleFitMode,
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<double>(
            valueListenable: _zoomController,
            builder: (context, zoom, _) => SizedBox(
              width: 40,
              child: Text(
              '${(zoom * 100).toStringAsFixed(0)}%',
              style: TextStyle(color: _colorScheme.onSurface, fontSize: 14),
              textAlign: TextAlign.right,
              ),
            ),
          ),
          ValueListenableBuilder<double>(
            valueListenable: _zoomController,
            builder: (context, value, child) => Slider(
              value: value,
              onChanged: (double value) {
                _zoomController.value = value;
              },
              min: minZoom,
              max: maxZoom,
              divisions: null,
              activeColor: _colorScheme.primary,
              inactiveColor: _colorScheme.primary.withAlpha(90),
              thumbColor: _colorScheme.secondary,
            ),
          ),

          const SizedBox(width: 16),
        ],
      ),
    );
  }
}
