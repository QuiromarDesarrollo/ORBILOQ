import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../domain/destinatario_internacional.dart';

/// Busca dentro del catálogo sin cambiar el destino hasta elegir una opción.
class DespachoDestinoSelector extends StatefulWidget {
  const DespachoDestinoSelector({
    super.key,
    required this.datos,
    required this.selectedId,
    required this.enabled,
    required this.onSelected,
  });

  final List<Map<String, dynamic>> datos;
  final String? selectedId;
  final bool enabled;
  final ValueChanged<String> onSelected;

  @override
  State<DespachoDestinoSelector> createState() =>
      _DespachoDestinoSelectorState();
}

class _DespachoDestinoSelectorState extends State<DespachoDestinoSelector>
    with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _focus = FocusNode(debugLabel: 'Destinatario del despacho');
  bool _searching = false;
  bool _settingText = false;
  int _catalogRevision = 0;
  late String _catalogSignature;

  List<_DestinoOption> get _options => [
    for (final row in widget.datos)
      if ('${row['id'] ?? ''}'.isNotEmpty) _DestinoOption.fromRow(row),
  ];

  String get _selectedLabel {
    for (final option in _options) {
      if (option.id == widget.selectedId) return option.label;
    }
    return '';
  }

  String get _signature => _options
      .map(
        (option) => '${option.id}\u0000${option.label}\u0000${option.detail}',
      )
      .join('\u0001');

  List<_DestinoOption> _filtered(String value) {
    final query = _normalize(value);
    return _options.where((option) => option.search.contains(query)).toList();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _catalogSignature = _signature;
    _restoreSelectedLabel();
    _controller.addListener(_textChanged);
    _focus.addListener(_focusChanged);
  }

  @override
  void didChangeMetrics() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(DespachoDestinoSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    final signature = _signature;
    final catalogChanged = signature != _catalogSignature;
    if (catalogChanged) {
      _catalogSignature = signature;
      // RawAutocomplete conserva resultados. Un catálogo nuevo reinicia esa
      // caché; los cambios de tamaño/teclado mantienen controller y foco.
      _catalogRevision++;
    }
    if (catalogChanged ||
        oldWidget.selectedId != widget.selectedId ||
        !widget.enabled) {
      _searching = false;
      _focus.unfocus();
      _restoreSelectedLabel();
    }
  }

  void _textChanged() {
    if (mounted && !_settingText) setState(() {});
  }

  void _restoreSelectedLabel() {
    final label = _selectedLabel;
    _settingText = true;
    _controller.value = TextEditingValue(
      text: label,
      selection: TextSelection.collapsed(offset: label.length),
    );
    _settingText = false;
  }

  void _focusChanged() {
    if (!mounted) return;
    if (_focus.hasFocus) {
      _beginSearch();
    } else if (_searching) {
      _endSearch();
    }
  }

  void _beginSearch() {
    if (!widget.enabled || _searching) return;
    setState(() => _searching = true);
    // También notifica al autocomplete al abrir un campo inicialmente vacío.
    // El setter restablece la selección; clear() sería idéntico al valor actual
    // y el SDK aún no habría calculado las primeras sugerencias.
    _controller.text = '';
  }

  void _endSearch() {
    if (!mounted) return;
    setState(() => _searching = false);
    _focus.unfocus();
    _restoreSelectedLabel();
  }

  void _select(_DestinoOption option) {
    if (!widget.enabled || option.id == null) return;
    setState(() => _searching = false);
    _focus.unfocus();
    widget.onSelected(option.id!);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focus.removeListener(_focusChanged);
    _controller.removeListener(_textChanged);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final view = View.of(context);
    final deviceInsets = EdgeInsets.fromViewPadding(
      view.viewInsets,
      view.devicePixelRatio,
    );
    // Dialog elimina viewInsets para su contenido. El popup está en el overlay
    // y sí necesita el teclado real para calcular el espacio utilizable.
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(viewInsets: deviceInsets),
      child: RawAutocomplete<_DestinoOption>(
        key: ValueKey('despacho-destino-selector-$_catalogRevision'),
        textEditingController: _controller,
        focusNode: _focus,
        optionsViewOpenDirection:
            deviceInsets.bottom > 0
                ? OptionsViewOpenDirection.mostSpace
                : OptionsViewOpenDirection.down,
        displayStringForOption: (option) => option.label,
        optionsBuilder: (value) {
          if (!widget.enabled) return const Iterable<_DestinoOption>.empty();
          final matches = _filtered(value.text);
          // Una fila informativa mantiene visible el panel al no hallar opciones.
          return matches.isEmpty ? [_DestinoOption.empty(value.text)] : matches;
        },
        onSelected: _select,
        fieldViewBuilder:
            (context, controller, focus, submit) => Focus(
              onKeyEvent: (_, event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.escape &&
                    _searching) {
                  _endSearch();
                  return KeyEventResult.handled;
                }
                if (event is KeyDownEvent &&
                    (event.logicalKey == LogicalKeyboardKey.enter ||
                        event.logicalKey == LogicalKeyboardKey.numpadEnter) &&
                    _searching) {
                  if (_filtered(controller.text).isNotEmpty) submit();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: TextField(
                key: const ValueKey('despacho-destino-busqueda'),
                controller: controller,
                focusNode: focus,
                enabled: widget.enabled,
                textInputAction: TextInputAction.done,
                onTap: _beginSearch,
                onTapOutside: (_) => _endSearch(),
                onSubmitted: (_) {
                  if (_filtered(controller.text).isNotEmpty) submit();
                },
                decoration: InputDecoration(
                  hintText: 'Buscar y seleccionar destinatario o sede',
                  hintMaxLines: 2,
                  prefixIcon: const Icon(Icons.search, size: 21),
                  suffixIcon: IconButton(
                    key: const ValueKey('despacho-destino-toggle'),
                    tooltip:
                        _searching && controller.text.isNotEmpty
                            ? 'Limpiar búsqueda'
                            : _searching
                            ? 'Cerrar opciones'
                            : 'Mostrar destinos',
                    onPressed:
                        !widget.enabled
                            ? null
                            : () {
                              if (_searching && controller.text.isNotEmpty) {
                                controller.clear();
                                focus.requestFocus();
                              } else if (_searching) {
                                _endSearch();
                              } else {
                                _beginSearch();
                                focus.requestFocus();
                              }
                            },
                    icon: Icon(
                      _searching && controller.text.isNotEmpty
                          ? Icons.close
                          : _searching
                          ? Icons.expand_less
                          : Icons.expand_more,
                    ),
                  ),
                ),
              ),
            ),
        optionsViewBuilder:
            (context, select, options) => _DestinoOptionsPanel(
              options: options.toList(),
              selectedId: widget.selectedId,
              highlightedIndex: AutocompleteHighlightedOption.of(context),
              onSelected: select,
              emptyCatalog: widget.datos.isEmpty,
            ),
      ),
    );
  }
}

class _DestinoOption {
  const _DestinoOption({
    required this.id,
    required this.name,
    required this.label,
    required this.detail,
  });

  factory _DestinoOption.fromRow(Map<String, dynamic> row) {
    final data = row['datos'] is Map ? row['datos'] as Map : row;
    final name = '${data['nombre'] ?? ''}'.trim();
    final sede = '${data['sede'] ?? ''}'.trim();
    final city = '${data['ciudad'] ?? ''}'.trim();
    final address = '${data['direccion'] ?? ''}'.trim();
    final details = [
      if (sede.isNotEmpty) sede,
      if (city.isNotEmpty) city,
      if (address.isNotEmpty) address,
      if (esDestinatarioInternacional(data)) ...[
        'Internacional',
        if ('${data['pais_destino'] ?? ''}'.trim().isNotEmpty)
          '${data['pais_destino']}',
      ],
    ];
    final location = sede.isNotEmpty ? sede : city;
    return _DestinoOption(
      id: '${row['id']}',
      name: name,
      label: '$name${location.isEmpty ? '' : ' · $location'}',
      detail: details.join(' · '),
    );
  }

  factory _DestinoOption.empty(String query) =>
      _DestinoOption(id: null, name: '', label: query, detail: '');

  final String? id;
  final String name, label, detail;
  String get search => _normalize('$name $detail');
}

String _normalize(String value) {
  var result = value.trim().toLowerCase();
  const source = 'áéíóúüñ';
  const target = 'aeiouun';
  for (var i = 0; i < source.length; i++) {
    result = result.replaceAll(source[i], target[i]);
  }
  return result.replaceAll(RegExp(r'\s+'), ' ');
}

class _DestinoOptionsPanel extends StatefulWidget {
  const _DestinoOptionsPanel({
    required this.options,
    required this.selectedId,
    required this.highlightedIndex,
    required this.onSelected,
    required this.emptyCatalog,
  });

  final List<_DestinoOption> options;
  final String? selectedId;
  final int highlightedIndex;
  final ValueChanged<_DestinoOption> onSelected;
  final bool emptyCatalog;

  @override
  State<_DestinoOptionsPanel> createState() => _DestinoOptionsPanelState();
}

class _DestinoOptionsPanelState extends State<_DestinoOptionsPanel> {
  final _scroll = ScrollController();
  final _optionKeys = <String?, GlobalKey>{};

  @override
  void didUpdateWidget(_DestinoOptionsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.highlightedIndex != widget.highlightedIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            !_scroll.hasClients ||
            widget.options.isEmpty ||
            widget.highlightedIndex < 0 ||
            widget.highlightedIndex >= widget.options.length) {
          return;
        }
        final option = widget.options[widget.highlightedIndex];
        final selectedContext = _optionKeys[option.id]?.currentContext;
        if (selectedContext != null) {
          Scrollable.ensureVisible(selectedContext, alignment: .5);
        } else {
          _scroll.jumpTo(
            widget.highlightedIndex == 0 ? 0 : _scroll.position.maxScrollExtent,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
        final showHint = constraints.maxHeight >= 64 + 52 * scale;
        return ConstrainedBox(
          key: const ValueKey('despacho-destino-options'),
          constraints: BoxConstraints(
            maxHeight: math.min(360, constraints.maxHeight),
          ),
          child: SizedBox(
            width: constraints.maxWidth,
            child: Material(
              elevation: 2,
              shadowColor: AppColors.petroleo.withValues(alpha: .12),
              color: Colors.white,
              surfaceTintColor: Colors.transparent,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: AppColors.cardBorder),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Scrollbar(
                      controller: _scroll,
                      child: ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        shrinkWrap: true,
                        itemCount: widget.options.length,
                        itemBuilder: (context, index) {
                          final option = widget.options[index];
                          if (option.id == null) {
                            return Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                widget.emptyCatalog
                                    ? 'No hay destinatarios registrados.'
                                    : 'No hay destinatarios que coincidan.',
                              ),
                            );
                          }
                          final selected = option.id == widget.selectedId;
                          final highlighted = index == widget.highlightedIndex;
                          return KeyedSubtree(
                            key: _optionKeys.putIfAbsent(
                              option.id,
                              GlobalKey.new,
                            ),
                            child: Semantics(
                              button: true,
                              selected: selected,
                              child: InkWell(
                                key: ValueKey('destino-opcion-${option.id}'),
                                onTap: () => widget.onSelected(option),
                                child: Container(
                                  constraints: const BoxConstraints(
                                    minHeight: 56,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        selected
                                            ? AppColors.lima.withValues(
                                              alpha: .18,
                                            )
                                            : highlighted
                                            ? scheme.primary.withValues(
                                              alpha: .06,
                                            )
                                            : null,
                                    border:
                                        highlighted
                                            ? Border.all(
                                              color: scheme.primary.withValues(
                                                alpha: .35,
                                              ),
                                            )
                                            : null,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              option.name,
                                              style: theme.textTheme.bodyMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                            if (option.detail.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                option.detail,
                                                style:
                                                    theme.textTheme.bodySmall,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      if (selected) ...[
                                        const SizedBox(width: 10),
                                        Icon(
                                          Icons.check_circle,
                                          color: scheme.primary,
                                          size: 22,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  if (showHint) ...[
                    Divider(height: 1, color: scheme.outlineVariant),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Escribe para filtrar por nombre, sede o ciudad',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
