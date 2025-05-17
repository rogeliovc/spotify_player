import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'test_spotify_devices_dialog.dart'; // Asegúrate de que la ruta sea correcta

void main() {
  testWidgets('Muestra dispositivos realistas y responde al tap', (WidgetTester tester) async {
    final devices = [
      TestSpotifyDevice(id: '1', name: 'Altavoz Living Room', type: 'Speaker', isActive: true),
      TestSpotifyDevice(id: '2', name: 'Smartphone de Juan', type: 'Phone', isActive: false),
      TestSpotifyDevice(id: '3', name: 'Laptop de Maria', type: 'Laptop', isActive: true),
      TestSpotifyDevice(id: '4', name: 'TV Smart', type: 'TV', isActive: false),
    ];

    TestSpotifyDevice? seleccionado;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => TestSpotifyDevicesDialog(
                        devices: devices,
                        onTap: (d) {
                          seleccionado = d;
                          Navigator.of(context).pop();
                        },
                      ),
                    );
                  },
                  child: const Text('Abrir diálogo'),
                ),
              ),
            );
          },
        ),
      ),
    );

    // Taps to open the dialog
    await tester.tap(find.text('Abrir diálogo'));
    await tester.pumpAndSettle();

    // Assert that all devices appear in the dialog
    expect(find.text('Altavoz Living Room'), findsOneWidget);
    expect(find.text('Smartphone de Juan'), findsOneWidget);
    expect(find.text('Laptop de Maria'), findsOneWidget);
    expect(find.text('TV Smart'), findsOneWidget);

    // Check if the "Activo" text appears for active devices
    expect(find.text('Activo'), findsNWidgets(2));

    // Tap on a device (Smartphone de Juan)
    await tester.tap(find.text('Smartphone de Juan'));
    await tester.pumpAndSettle();

    // Assert that the device tapped is the one selected
    expect(seleccionado?.name, 'Smartphone de Juan');
  });

  testWidgets('Muestra mensaje si no hay dispositivos disponibles', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => const TestSpotifyDevicesDialog(
                        devices: [],  // Lista vacía de dispositivos
                        onTap: null,  // Pasamos onTap como null aquí
                      ),
                    );
                  },
                  child: const Text('Abrir diálogo'),
                ),
              ),
            );
          },
        ),
      ),
    );

    // Tap para abrir el diálogo
    await tester.tap(find.text('Abrir diálogo'));
    await tester.pumpAndSettle();

    // Verificamos que el mensaje de no hay dispositivos disponibles se muestra
    expect(find.text('No hay dispositivos disponibles.'), findsOneWidget);
  });
}
