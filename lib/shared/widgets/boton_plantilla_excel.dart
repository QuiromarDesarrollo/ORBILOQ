import 'package:orbiloq_wms/shared/widgets/wms_alert.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../data/plantillas_excel.dart';
export '../../data/plantillas_excel.dart' show PlantillaExcel, PlantillasExcel;

class BotonPlantillaExcel extends StatefulWidget {
  const BotonPlantillaExcel({super.key, this.tipo, this.generar, this.nombre, this.habilitado = true});
  final PlantillaExcel? tipo;
  final FutureOr<Uint8List> Function()? generar;
  final String? nombre;
  final bool habilitado;
  @override
  State<BotonPlantillaExcel> createState() => _BotonPlantillaExcelState();
}
class _BotonPlantillaExcelState extends State<BotonPlantillaExcel> {
  bool ocupado = false;
  Future<void> descargar() async {
    setState(() => ocupado = true);
    try {
      final bytes = widget.generar != null ? await widget.generar!() : PlantillasExcel.generar(widget.tipo!);
      await FilePicker.platform.saveFile(dialogTitle: 'Descargar plantilla Excel',
        fileName: 'plantilla_${widget.nombre ?? widget.tipo!.name}.xlsx', bytes: bytes,
        type: FileType.custom, allowedExtensions: ['xlsx']);
    } catch (e) {
      if (mounted) mostrarAvisoSnack(context, SnackBar(content: Text('No se pudo descargar la plantilla: $e')));
    } finally {
      if (mounted) setState(() => ocupado = false);
    }
  }
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: ocupado || !widget.habilitado ? null : descargar,
    icon: const Icon(Icons.download_outlined), label: Text(ocupado ? 'Preparando plantilla…' : 'Descargar plantilla Excel'));
}
