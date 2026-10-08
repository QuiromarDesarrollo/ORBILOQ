import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../application/auth_providers.dart';
import '../../../application/dashboard_acceso.dart';
import '../../admin/presentation/dashboard_ejecutivo_page.dart';
import 'ciclos_page.dart';

class DashboardCatalogoPage extends ConsumerWidget {
  const DashboardCatalogoPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final acceso = ref.watch(dashboardAccesoProvider).$2;
    if (!(acceso?.puedeVerDashboards ?? false)) {
      return const Scaffold(
        body: Center(child: Text('Sin acceso a dashboards.')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboards'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authRepositoryProvider)?.cerrarSesion(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Indicadores de gestión',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 20),
          Card(
            child: ListTile(
              leading: const Icon(Icons.dashboard_outlined),
              title: const Text('Dashboard ejecutivo'),
              subtitle: const Text('Producción, recepción y operación'),
              trailing: const Icon(Icons.chevron_right),
              onTap:
                  () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const DashboardEjecutivoPage(),
                    ),
                  ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.timeline),
              title: const Text('Tiempos de ciclo por proceso'),
              subtitle: const Text(
                'Cumplimiento, tiempos históricos y capacidad diaria y semanal',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap:
                  () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const CiclosPage()),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
