import 'package:flutter/material.dart';
import 'anchor_info.dart';

class AnchorSelectionGrid extends StatelessWidget {
  
  final ValueNotifier<bool> isVisible;

  final void Function(AnchorInfo) onAnchorSelected;

  const AnchorSelectionGrid({
    super.key,
    required this.isVisible,
    required this.onAnchorSelected,
  });

  static const List<AnchorInfo> _anchors = [
    AnchorInfo(label: 'Top Left', icon: Icons.north_west, aligment: Alignment.topLeft),
    AnchorInfo(label: 'Top Center', icon: Icons.north, aligment: Alignment.topCenter),
    AnchorInfo(label: 'Top Right', icon: Icons.north_east, aligment: Alignment.topRight),
    AnchorInfo(label: 'Center Left', icon: Icons.west, aligment: Alignment.centerLeft),
    AnchorInfo(label: 'Center', icon: Icons.fiber_manual_record, aligment: Alignment.center),
    AnchorInfo(label: 'Center Right', icon: Icons.east, aligment: Alignment.centerRight),
    AnchorInfo(label: 'Bottom Left', icon: Icons.south_west, aligment: Alignment.bottomLeft),
    AnchorInfo(label: 'Bottom Center', icon: Icons.south, aligment: Alignment.bottomCenter),
    AnchorInfo(label: 'Bottom Right', icon: Icons.south_east, aligment: Alignment.bottomRight),
  ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isVisible,
      builder: (context, visible, child) {
        if (!visible) return SizedBox.shrink();
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainer.withAlpha(190),
            borderRadius: BorderRadius.circular(16),
          ),
          child: GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            children: _anchors.map((anchor) {
              return IconButton(
                onPressed: () {
                  onAnchorSelected(anchor);
                },
                icon: Icon(anchor.icon),
                tooltip: anchor.label,
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
