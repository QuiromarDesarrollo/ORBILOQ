import 'package:orbiloq_wms/shared/widgets/bienvenida_usuario.dart';
import '../../../shared/widgets/wms_loader.dart';
import 'package:flutter/material.dart';
import 'conductor_design.dart';

class TransporteDestino {
  const TransporteDestino(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Navegación compartida del módulo. Los formularios conservan su propia ruta.
class TransporteScaffold extends StatelessWidget {
  const TransporteScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.destinos = const [],
    this.selected = 0,
    this.onSelected,
    this.usuario = 'Transporte',
    this.sidebarKey,
    this.mobileNavigation,
    this.loadingLabel,
    this.integratedNavigation = false,
  });
  final Widget body;
  final bool integratedNavigation;
  final String? loadingLabel;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar, mobileNavigation;
  final List<TransporteDestino> destinos;
  final int selected;
  final ValueChanged<int>? onSelected;
  final String usuario;
  final Key? sidebarKey;

  Widget _menu(BuildContext context, bool desktop) => Container(
    key: desktop ? sidebarKey : null,
    width: 238,
    color: ConductorDesign.navy,
    child: SafeArea(
      child: Column(
        children: [
          if (!integratedNavigation) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 20, 28),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/images/logo_orbiloq.png',
                      width: 40,
                      height: 40,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ORBILOQ',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 19,
                          ),
                        ),
                        Text(
                          'GRUPO QUIROMAR',
                          style: TextStyle(
                            color: Color(0xFFBFD0D8),
                            fontSize: 9,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(28, 0, 24, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'TRANSPORTE',
                  style: TextStyle(
                    color: Color(0xFF99B4C0),
                    fontSize: 10,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ] else
            const SizedBox(height: 12),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              children: [
                for (var i = 0; i < destinos.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Material(
                      color:
                          selected == i
                              ? const Color(0xFF20546A)
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          if (!desktop) Navigator.pop(context);
                          onSelected?.call(i);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(
                                width: 3,
                                color:
                                    selected == i
                                        ? ConductorDesign.lime
                                        : Colors.transparent,
                              ),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 13,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                destinos[i].icon,
                                size: 20,
                                color:
                                    selected == i
                                        ? ConductorDesign.lime
                                        : const Color(0xFFBFD0D8),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  destinos[i].label,
                                  style: TextStyle(
                                    color:
                                        selected == i
                                            ? Colors.white
                                            : const Color(0xFFBFD0D8),
                                    fontWeight:
                                        selected == i
                                            ? FontWeight.w700
                                            : FontWeight.w400,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (Navigator.canPop(context))
                  Material(
                    color: Colors.transparent,
                    child: ListTile(
                      leading: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 20,
                      ),
                      title: const Text(
                        'Volver al WMS',
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                      onTap: () {
                        if (!desktop) Navigator.pop(context);
                        Navigator.maybePop(context);
                      },
                    ),
                  ),
              ],
            ),
          ),
          if (!integratedNavigation)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Divider(color: Color(0xFF31586A)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 18,
                        backgroundColor: Color(0xFFE8EDC8),
                        child: Icon(
                          Icons.person_outline,
                          color: ConductorDesign.navy,
                          size: 19,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          usuario,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final desktop = c.maxWidth >= 900 && destinos.isNotEmpty;
      final contenido = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: c.maxWidth < 600 ? 16 : 28,
            ),
            child: const BienvenidaUsuario(),
          ),
          Expanded(child: body),
        ],
      );
      return WmsActionLoadingOverlay(
        label: loadingLabel,
        child: Scaffold(
          appBar: appBar,
          drawer:
              destinos.isNotEmpty && !desktop
                  ? Drawer(child: Builder(builder: (ctx) => _menu(ctx, false)))
                  : null,
          body:
              desktop
                  ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _menu(context, true),
                      Expanded(child: contenido),
                    ],
                  )
                  : contenido,
          bottomNavigationBar:
              bottomNavigationBar ?? (desktop ? null : mobileNavigation),
        ),
      );
    },
  );
}

/// Campos en dos columnas en escritorio y una sola en pantallas pequeñas.
class TransporteCampos extends StatelessWidget {
  const TransporteCampos({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final columns =
          c.maxWidth >= 620 && MediaQuery.textScalerOf(context).scale(14) < 21
              ? 2
              : 1;
      return Wrap(
        spacing: 18,
        runSpacing: 12,
        children: [
          for (final w in children)
            SizedBox(
              width: (c.maxWidth - (columns - 1) * 18) / columns,
              child: w,
            ),
        ],
      );
    },
  );
}

class TransporteAviso extends StatelessWidget {
  const TransporteAviso(
    this.title,
    this.message, {
    super.key,
    this.warning = false,
  });
  final String title, message;
  final bool warning;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: warning ? const Color(0xFFFFF6E8) : const Color(0xFFEDF6FA),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: warning ? const Color(0xFFF5E2BE) : const Color(0xFFD7EAF3),
      ),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          warning ? Icons.warning_amber_outlined : Icons.info_outline,
          color: ConductorDesign.navy,
          size: 21,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                message,
                style: const TextStyle(
                  color: ConductorDesign.muted,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class TransporteCategorias extends StatelessWidget {
  const TransporteCategorias({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
    required this.child,
    this.enabled = true,
  });
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;
  final Widget child;
  final bool enabled;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      Widget item(int i) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: TextButton(
          onPressed: enabled ? () => onSelected(i) : null,
          style: TextButton.styleFrom(
            backgroundColor:
                i == selected ? const Color(0xFFEDF2D4) : Colors.transparent,
            foregroundColor:
                i == selected ? ConductorDesign.navy : ConductorDesign.muted,
            padding: const EdgeInsets.all(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: const Color(0xFFE4EBE9),
                child: Text(
                  '${i + 1}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: ConductorDesign.navy,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(labels[i], style: const TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ),
      );
      if (c.maxWidth < 800) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [for (var i = 0; i < labels.length; i++) item(i)],
              ),
            ),
            const SizedBox(height: 14),
            child,
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 210,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [for (var i = 0; i < labels.length; i++) item(i)],
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(child: child),
        ],
      );
    },
  );
}
