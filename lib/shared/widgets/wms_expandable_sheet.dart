import 'package:flutter/material.dart';

Future<T?> showWmsExpandableSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  Color? backgroundColor,
  bool showDragHandle = true,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: isScrollControlled,
  useSafeArea: true,
  backgroundColor: backgroundColor,
  constraints: const BoxConstraints(maxWidth: double.infinity),
  builder:
      (ctx) =>
          _ExpandableSheet(builder: builder, showDragHandle: showDragHandle),
);

class _ExpandableSheet extends StatefulWidget {
  const _ExpandableSheet({required this.builder, required this.showDragHandle});
  final bool showDragHandle;
  final WidgetBuilder builder;
  @override
  State<_ExpandableSheet> createState() => _ExpandableSheetState();
}

class _ExpandableSheetState extends State<_ExpandableSheet> {
  bool _fullscreen = false;
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return SafeArea(
      child: SizedBox(
        width: _fullscreen ? size.width : size.width.clamp(0.0, 640.0),
        height: _fullscreen ? size.height : null,
        child: Column(
          mainAxisSize: _fullscreen ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                if (widget.showDragHandle && !_fullscreen)
                  Container(
                    width: 32,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: .4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip:
                        _fullscreen ? 'Restaurar tamaño' : 'Ampliar pantalla',
                    icon: Icon(
                      _fullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                    ),
                    onPressed: () => setState(() => _fullscreen = !_fullscreen),
                  ),
                ),
              ],
            ),
            Flexible(child: widget.builder(context)),
          ],
        ),
      ),
    );
  }
}
