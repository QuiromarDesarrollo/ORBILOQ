import 'package:flutter/material.dart';
import 'conductor_design.dart';

/// Barra de marca compartida por conductor y administración de transporte.
class TransporteAppBar extends StatelessWidget implements PreferredSizeWidget {
  const TransporteAppBar({super.key, required this.actions});
  final List<Widget> actions;
  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: ConductorDesign.navy,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 64,
      titleSpacing: 16,
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Image.asset(
              'assets/images/logo_orbiloq.png',
              semanticLabel: 'Logo de Orbiloq',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 10),
          const Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'ORBILOQ',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .8,
                  ),
                ),
                Text(
                  'Grupo Quiromar',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFFBFD0D8),
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      automaticallyImplyLeading: MediaQuery.sizeOf(context).width < 900,
      actions: actions,
    );
  }
}
