import 'package:flutter/material.dart';

/// Conserva el contenido y las acciones del aviso al ampliar/restaurar.
class WmsExpandableAlertDialog extends StatefulWidget {
  const WmsExpandableAlertDialog({
    super.key,
    this.title,
    this.icon,
    this.content,
    this.actions,
    this.backgroundColor,
    this.shape,
  });
  final Widget? title, icon, content;
  final List<Widget>? actions;
  final Color? backgroundColor;
  final ShapeBorder? shape;

  @override
  State<WmsExpandableAlertDialog> createState() =>
      _WmsExpandableAlertDialogState();
}

class _WmsExpandableAlertDialogState extends State<WmsExpandableAlertDialog> {
  bool _fullscreen = false;
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return AlertDialog(
      scrollable: true,
      backgroundColor: widget.backgroundColor,
      shape: _fullscreen ? const RoundedRectangleBorder() : widget.shape,
      insetPadding:
          _fullscreen
              ? EdgeInsets.zero
              : const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      constraints:
          _fullscreen
              ? BoxConstraints.tightFor(
                width: size.width,
                height: (size.height - keyboard).clamp(0.0, double.infinity),
              )
              : null,
      icon: widget.icon,
      title: Row(
        children: [
          Expanded(child: widget.title ?? const SizedBox.shrink()),
          IconButton(
            tooltip: _fullscreen ? 'Restaurar tamaño' : 'Ampliar pantalla',
            icon: Icon(_fullscreen ? Icons.fullscreen_exit : Icons.fullscreen),
            onPressed: () => setState(() => _fullscreen = !_fullscreen),
          ),
        ],
      ),
      content: widget.content,
      actions: widget.actions,
    );
  }
}
