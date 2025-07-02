import 'package:flutter/material.dart';

class ImageViewerScaffold extends StatelessWidget {
  final ColorScheme colorScheme;
  final bool isFullScreen;
  final String fileName;
  final Widget imageRenderArea;
  final Widget topAppBar;
  final Widget hiddenTopAppBar;
  final Widget bottomPanel;
  final Widget hiddenBottomPanel;
  final Widget anchorSelectionGrid;

  const ImageViewerScaffold({
    super.key,
    required this.colorScheme,
    required this.isFullScreen,
    required this.fileName,
    required this.imageRenderArea,
    required this.topAppBar,
    required this.hiddenTopAppBar,
    required this.bottomPanel,
    required this.hiddenBottomPanel,
    required this.anchorSelectionGrid
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Stack(
        children: [
          // Image render area (fills available space)
          Positioned.fill(
            top: isFullScreen ? 0 : 40, // Height of top application bar
            bottom: isFullScreen ? 0 : 40, // Height of bottom panel
            child: imageRenderArea,
          ),
          // Top panel with drag-to-move area
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 40,
            child: isFullScreen ? hiddenTopAppBar : topAppBar,
          ),
          // Bottom panel
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 40,
            child: isFullScreen ? hiddenBottomPanel : bottomPanel,
          ),
          // Anchor selection grid positioned at the top left
          Positioned(
            top: 50,
            left: 10,
            width: 115,
            height: 115,
            child: anchorSelectionGrid,
          ),
        ],
      ),
    );
  }
}
