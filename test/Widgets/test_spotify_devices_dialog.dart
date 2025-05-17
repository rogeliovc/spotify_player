import 'package:flutter/material.dart';

class TestSpotifyDevice {
  final String id;
  final String name;
  final String type;
  final bool isActive;

  TestSpotifyDevice({
    required this.id,
    required this.name,
    required this.type,
    required this.isActive,
  });
}

class TestSpotifyDevicesDialog extends StatelessWidget {
  final List<TestSpotifyDevice> devices;
  final void Function(TestSpotifyDevice)? onTap; // onTap es opcional

  const TestSpotifyDevicesDialog({
    super.key,
    required this.devices,
    this.onTap, // Permite onTap como un parámetro opcional
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Dispositivos de Spotify'),
      content: devices.isEmpty
          ? const Text('No hay dispositivos disponibles.')
          : SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: devices.length,
          itemBuilder: (context, index) {
            final d = devices[index];
            return ListTile(
              leading: Icon(
                d.isActive ? Icons.play_circle_fill : Icons.devices,
                color: d.isActive ? Colors.green : Colors.grey,
              ),
              title: Text(d.name),
              subtitle: Text(d.type),
              trailing: d.isActive
                  ? const Text(
                'Activo',
                style: TextStyle(color: Colors.green),
              )
                  : null,
              onTap: onTap != null ? () => onTap!(d) : null, // Verifica si onTap no es nulo
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}
