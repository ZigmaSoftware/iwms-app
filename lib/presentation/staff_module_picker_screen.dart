import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iwms_citizen_app/data/models/permission_bundle.dart';
import 'package:iwms_citizen_app/logic/auth/auth_bloc.dart';
import 'package:iwms_citizen_app/logic/auth/auth_event.dart';

class StaffModulePickerScreen extends StatelessWidget {
  final String userName;
  final List<AppSurfaceAccess> surfaces;

  const StaffModulePickerScreen({
    super.key,
    required this.userName,
    required this.surfaces,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose module'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: () {
              context.read<AuthBloc>().add(AuthLogoutRequested());
              context.go('/citizen/login');
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Signed in as $userName',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Available workspaces',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.black54,
                    ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: surfaces.isEmpty
                    ? const Center(
                        child: Text(
                            'No app modules are assigned to this account.'),
                      )
                    : ListView.separated(
                        itemCount: surfaces.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final surface = surfaces[index];
                          return _SurfaceCard(surface: surface);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  final AppSurfaceAccess surface;

  const _SurfaceCard({required this.surface});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(_iconForSurface(surface.key)),
        ),
        title: Text(surface.label),
        subtitle: Text(surface.route),
        trailing: surface.isDefault
            ? const Chip(label: Text('Default'))
            : const Icon(Icons.chevron_right),
        onTap: surface.route.isEmpty ? null : () => context.go(surface.route),
      ),
    );
  }

  IconData _iconForSurface(String key) {
    switch (key.toLowerCase()) {
      case 'admin':
        return Icons.dashboard_customize_outlined;
      case 'operator':
        return Icons.qr_code_scanner_outlined;
      case 'driver':
        return Icons.local_shipping_outlined;
      case 'supervisor':
        return Icons.shield_outlined;
      default:
        return Icons.person_outline;
    }
  }
}
