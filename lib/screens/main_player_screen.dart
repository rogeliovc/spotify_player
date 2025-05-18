import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import 'task_manager.dart';
import '../models/spotify_track.dart';
import '../models/song_model.dart';
import '../models/spotify_device.dart';
import 'package:http/http.dart' as http;
import 'settings_screen.dart';
import 'dart:convert';
import '../services/auth_service.dart';
import 'mini_player.dart';
import '../utils/spotify_search.dart';
import '../widgets/spotify_search_field.dart';
import 'package:table_calendar/table_calendar.dart';

class MainPlayerScreen extends StatefulWidget {
  final int? initialTab;
  final String? initialSongId;
  final Map<String, dynamic>? songData;

  const MainPlayerScreen({Key? key, this.initialTab, this.initialSongId, this.songData}) : super(key: key);

  @override
  State<MainPlayerScreen> createState() => _MainPlayerScreenState();
}

class _MainPlayerScreenState extends State<MainPlayerScreen>
    with WidgetsBindingObserver {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  int _selectedTab = 1; // 0: Player, 1: Home, 2: Tasks
  int _lastTab = 1;
  final bool _calendarLoading = false;
  Key _playlistRefreshKey = UniqueKey(); // <-- NUEVO

  // NUEVO: función para refrescar playlists
  void refreshPlaylists() {
    setState(() {
      _playlistRefreshKey = UniqueKey();
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Cambia el tab si se provee initialTab
    if (widget.initialTab != null) {
      _selectedTab = widget.initialTab!;
    }
    // Reproduce la canción si se provee initialSongId
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    if (widget.songData != null) {
      // Construir Song y reproducir
      final song = Song(
        id: widget.songData!['id'] ?? '',
        title: widget.songData!['title'] ?? '',
        artist: widget.songData!['artist'] ?? '',
        album: widget.songData!['album'] ?? '',
        albumArtUrl: widget.songData!['albumArtUrl'] ?? '',
        durationMs: widget.songData!['durationMs'] ?? 180000,
      );
      playerProvider.playSong(song);
    } else if (widget.initialSongId != null) {
      PlayerProvider.playSongByIdStatic(playerProvider, widget.initialSongId!);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _lastTab = _selectedTab;
  }

  @override
  void didUpdateWidget(covariant MainPlayerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _lastTab = _selectedTab;
  }

  Future<List<SpotifyDevice>> getSpotifyDevices(BuildContext context) async {
    final auth = AuthService();
    final token = await auth.getAccessToken();
    if (token == null) throw 'No se encontró el token de sesión de Spotify.';
    final url = Uri.parse('https://api.spotify.com/v1/me/player/devices');
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode != 200) {
      throw 'Error al obtener dispositivos: ${response.statusCode}';
    }
    final data = json.decode(response.body);
    final items = data['devices'] as List<dynamic>;
    return items.map((item) => SpotifyDevice.fromJson(item)).toList();
  }

  void showDevicesDialog(BuildContext context) async {
    try {
      final devices = await getSpotifyDevices(context);
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
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
                            ? const Text('Activo',
                                style: TextStyle(color: Colors.green))
                            : null,
                        onTap: () async {
                          Navigator.of(context).pop();
                          final auth = AuthService();
                          final token = await auth.getAccessToken();
                          if (token == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('No hay sesión activa de Spotify.')),
                            );
                            return;
                          }
                          final response = await http.put(
                            Uri.parse(
                                'https://api.spotify.com/v1/me/player/transfer'),
                            headers: {
                              'Authorization': 'Bearer $token',
                              'Content-Type': 'application/json',
                            },
                            body: json.encode({
                              'device_ids': [d.id],
                              'play': true, // Reproduce automáticamente
                            }),
                          );
                          if (response.statusCode == 204) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('Transferido a: ${d.name}')),
                            );
                          } else {
                            String errorMsg =
                                'No se pudo transferir (${response.statusCode})';
                            try {
                              final Map<String, dynamic> errorBody =
                                  json.decode(response.body);
                              if (errorBody.containsKey('error')) {
                                errorMsg += ': ' +
                                    (errorBody['error']['message'] ?? '');
                              }
                            } catch (_) {}
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(errorMsg)),
                            );
                          }
                        },
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
        ),
      );
    } catch (e) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Error'),
          content: Text(e.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    }
  }

  void _handleTabChange(int newTab) async {
    if (_selectedTab == 2 && newTab == 1) {
      // Al cambiar de "Tareas" a "Home", borra completadas
      final taskProvider = Provider.of<TaskProvider>(context, listen: false);
      await taskProvider.removeCompletedTasks();
    }
    setState(() {
      _selectedTab = newTab;
    });
  }

  // NUEVO: Crear playlist en Spotify con logs
  Future<void> _createPlaylist(BuildContext context) async {
    final auth = AuthService();
    final token = await auth.getAccessToken();
    debugPrint('[Sincronía] Token obtenido: ${token != null ? "OK" : "NULL"}');
    if (token == null) {
      debugPrint('[Sincronía] No hay sesión activa de Spotify.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay sesión activa de Spotify.')),
      );
      return;
    }

    // Obtener el user_id
    final userResp = await http.get(
      Uri.parse('https://api.spotify.com/v1/me'),
      headers: {'Authorization': 'Bearer $token'},
    );
    debugPrint(
        '[Sincronía] Respuesta usuario: ${userResp.statusCode} ${userResp.body}');
    if (userResp.statusCode != 200) {
      debugPrint('[Sincronía] No se pudo obtener tu usuario de Spotify.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No se pudo obtener tu usuario de Spotify.')),
      );
      return;
    }
    final userId = (json.decode(userResp.body))['id'];
    debugPrint('[Sincronía] userId: $userId');

    // Mostrar diálogo para nombre y descripción
    String playlistName = '';
    String playlistDesc = '';
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Crear nueva playlist'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  onChanged: (v) => playlistName = v,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Escribe un nombre';
                    }
                    if (v.length > 100) {
                      return 'Máximo 100 caracteres';
                    }
                    if (!RegExp(r'^[a-zA-Z0-9\s\-_.,!?]+$').hasMatch(v)) {
                      return 'Solo letras, números y - _ . , ! ?';
                    }
                    return null;
                  }),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Descripción'),
                onChanged: (v) => playlistDesc = v,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(context).pop(true);
              }
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    debugPrint(
        '[Sincronía] Dialog result: $result, nombre: $playlistName, desc: $playlistDesc');
    if (result != true) return;

    // Llamar a la API de Spotify para crear la playlist
    final resp = await http.post(
      Uri.parse('https://api.spotify.com/v1/users/$userId/playlists'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'name': playlistName,
        'description': playlistDesc,
        'public': false,
      }),
    );
    debugPrint(
        '[Sincronía] Respuesta creación playlist: ${resp.statusCode} ${resp.body}');
    if (resp.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Playlist creada exitosamente!')),
      );
      setState(() {}); // Refresca la pantalla para mostrar la nueva playlist
    } else {
      String msg = 'No se pudo crear la playlist.';
      try {
        final err = json.decode(resp.body);
        if (err['error']?['message'] != null) {
          msg += ' ${err['error']['message']}';
        }
      } catch (e) {
        debugPrint('[Sincronía] Error parseando respuesta: $e');
      }
      debugPrint('[Sincronía] $msg');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    }
  }

  Future<void> addTracksToPlaylist(
      String playlistId, List<String> trackUris) async {
    final auth = AuthService();
    final token = await auth.getAccessToken();
    if (token == null) {
      debugPrint('[Sincronía] No hay sesión activa de Spotify.');
      return;
    }

    final url =
        Uri.parse('https://api.spotify.com/v1/playlists/$playlistId/tracks');
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({'uris': trackUris}),
    );

    debugPrint(
        '[Sincronía] Respuesta agregar tracks: ${response.statusCode} ${response.body}');
    if (response.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Canciones agregadas a la playlist')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al agregar canciones: ${response.body}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Provee el context global al PlayerProvider para navegación segura
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    playerProvider.setContext(context);
    return Scaffold(
      backgroundColor: const Color(0xFF0E1928),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Sincronía',
            style: TextStyle(
                fontFamily: 'Serif',
                fontSize: 28,
                color: Colors.white,
                letterSpacing: 1)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.settings, color: Colors.white70),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_add, color: Color(0xFFe0c36a)),
            tooltip: 'Crear playlist',
            onPressed: () => _createPlaylist(context),
          ),
          IconButton(
            icon: const Icon(Icons.devices, color: Colors.white70),
            tooltip: 'Mostrar dispositivos',
            onPressed: () => showDevicesDialog(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Contenido principal con tabs
          SafeArea(
            child: Column(
              children: [
                Center(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF182B45),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.music_note,
                              color: _selectedTab == 0
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.6)),
                          onPressed: () => _handleTabChange(0),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: _selectedTab == 1
                                ? Colors.white
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 4),
                          child: IconButton(
                            icon: Icon(Icons.home,
                                color: _selectedTab == 1
                                    ? const Color(0xFF182B45)
                                    : Colors.white.withOpacity(0.6)),
                            onPressed: () => _handleTabChange(1),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.calendar_today,
                              color: _selectedTab == 2
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.6)),
                          onPressed: () => _handleTabChange(2),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 450),
                    switchInCurve: Curves.easeInOut,
                    switchOutCurve: Curves.easeInOut,
                    layoutBuilder: (currentChild, previousChildren) {
                      return Stack(
                        children: <Widget>[
                          ...previousChildren,
                          if (currentChild != null) currentChild,
                        ],
                      );
                    },
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                      final slide = Tween<Offset>(
                        begin: const Offset(1.0, 0.0),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeInOutCubicEmphasized,
                        ),
                      );
                      return SlideTransition(
                        position: slide,
                        child: FadeTransition(
                          opacity: animation,
                          child: child,
                        ),
                      );
                    },
                    child: Builder(
                      key: ValueKey(_selectedTab),
                      builder: (context) {
                        if (_selectedTab == 1) {
                          return _buildCalendarAnimated();
                        } else if (_selectedTab == 2) {
                          return _buildTaskManagerAnimated();
                        } else {
                          return _buildPlayerContentAnimated();
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          // MiniPlayer siempre visible, pegado al fondo
          Align(
            alignment: Alignment.bottomCenter,
            child: MiniPlayer(onRequestPlaylistRefresh: refreshPlaylists),
          ),
        ],
      ),
    );
  }

  // Animación para el calendario
  Widget _buildCalendarAnimated() {
    return FutureBuilder<void>(
      future: Future.delayed(const Duration(milliseconds: 300)),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          // Shimmer en vez de spinner
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const ShimmerLoader(height: 32, width: 180),
                const SizedBox(height: 24),
                ShimmerLoader(
                    height: 220,
                    width: double.infinity,
                    borderRadius: BorderRadius.circular(18)),
                const SizedBox(height: 24),
                const Row(
                  children: [
                    ShimmerLoader(height: 24, width: 120),
                    SizedBox(width: 12),
                    ShimmerLoader(height: 24, width: 80),
                  ],
                ),
                const SizedBox(height: 24),
                ShimmerLoader(
                    height: 110,
                    width: double.infinity,
                    borderRadius: BorderRadius.circular(18)),
              ],
            ),
          );
        }
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: _buildCalendarOnly(),
        );
      },
    );
  }

  // Animación para el TaskManager
  Widget _buildTaskManagerAnimated() {
    return FutureBuilder<void>(
      future: Future.delayed(const Duration(milliseconds: 300)),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          // Shimmer en vez de spinner
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                4,
                (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: ShimmerLoader(
                      height: 70,
                      width: double.infinity,
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          );
        }
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: _buildTaskManager(),
        );
      },
    );
  }

  // Animación para el contenido del reproductor
  Widget _buildPlayerContentAnimated() {
    return FutureBuilder<void>(
      future: Future.delayed(const Duration(milliseconds: 300)),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          // Shimmer en vez de spinner
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const ShimmerLoader(height: 32, width: 180),
                const SizedBox(height: 24),
                Row(
                  children: [
                    ShimmerLoader(
                        height: 140,
                        width: 140,
                        borderRadius: BorderRadius.circular(16)),
                    const SizedBox(width: 16),
                    ShimmerLoader(
                        height: 140,
                        width: 140,
                        borderRadius: BorderRadius.circular(16)),
                  ],
                ),
                const SizedBox(height: 24),
                const ShimmerLoader(height: 32, width: 180),
              ],
            ),
          );
        }
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: _buildPlayerContent(),
        );
      },
    );
  }

  Widget _buildCalendarOnly() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.07),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Consumer<TaskProvider>(
                builder: (context, taskProvider, _) {
                  // Crear un mapa de eventos: fecha -> lista de tareas pendientes
                  final Map<DateTime, List<dynamic>> taskEvents = {};
                  for (final task in taskProvider.tasks) {
                    if (!task.completed) {
                      final day = DateTime(task.dueDate.year,
                          task.dueDate.month, task.dueDate.day);
                      taskEvents.putIfAbsent(day, () => []).add(task);
                    }
                  }
                  return TableCalendar(
                    rowHeight: 54,
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) =>
                        _selectedDay != null && isSameDay(_selectedDay, day),
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                    },
                    eventLoader: (day) {
                      final key = DateTime(day.year, day.month, day.day);
                      return taskEvents[key] ?? [];
                    },
                    calendarStyle: CalendarStyle(
                      defaultTextStyle: const TextStyle(color: Colors.black87),
                      weekendTextStyle: const TextStyle(color: Colors.blueGrey),
                      outsideTextStyle: const TextStyle(color: Colors.black26),
                      todayDecoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        shape: BoxShape.circle,
                      ),
                      todayTextStyle: const TextStyle(
                          color: Colors.blue, fontWeight: FontWeight.bold),
                      selectedDecoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      selectedTextStyle: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                      disabledTextStyle: const TextStyle(color: Colors.grey),
                      markerDecoration: const BoxDecoration(
                        color: Colors.blueAccent,
                        shape: BoxShape.circle,
                      ),
                      markersMaxCount: 1,
                      markersAlignment: Alignment.bottomCenter,
                      markersOffset: const PositionedOffset(bottom: 4),
                    ),
                    calendarBuilders: CalendarBuilders(
                      markerBuilder: (context, day, events) {
                        if (events.isNotEmpty) {
                          return Positioned(
                            bottom: 4,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: Colors.blueAccent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          );
                        }
                        return null;
                      },
                    ),
                    headerStyle: const HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                      titleTextStyle: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                      leftChevronIcon:
                          Icon(Icons.chevron_left, color: Colors.black87),
                      rightChevronIcon:
                          Icon(Icons.chevron_right, color: Colors.black87),
                    ),
                    daysOfWeekStyle: const DaysOfWeekStyle(
                      weekdayStyle: TextStyle(
                          color: Colors.black54, fontWeight: FontWeight.w600),
                      weekendStyle: TextStyle(
                          color: Colors.blueGrey, fontWeight: FontWeight.w600),
                    ),
                  );
                },
              ),
            ),
          ),
          // Slider de tareas pendientes
          Consumer<TaskProvider>(
            builder: (context, taskProvider, _) {
              // Filtrar solo tareas pendientes y ordenarlas por fecha
              final pendingTasks = taskProvider.tasks
                  .where((t) => !t.completed)
                  .toList()
                ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
              if (pendingTasks.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No hay tareas pendientes',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                );
              }
              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 130),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  itemCount: pendingTasks.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final task = pendingTasks[index];
                    return Container(
                      width: 180,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF182B45),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.16),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.blue.withOpacity(0.25),
                          width: 1.2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Expanded(
                            child: Text(
                              task.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Expanded(
                            child: Text(
                              'Hasta: ${task.dueDate.day}/${task.dueDate.month}/${task.dueDate.year}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Expanded(
                            flex: 2,
                            child: Text(
                              task.description,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          // Carrusel de escuchados recientemente
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Escuchados recientemente',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 110),
            child: _buildHorizontalTrackList(_getRecentlyPlayedFuture()),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        title,
        style: const TextStyle(
            fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }

  Widget _buildHorizontalTrackList(Future<List<SpotifyTrack>> futureTracks) {
    return FutureBuilder<List<SpotifyTrack>>(
      future: futureTracks,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 180,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return SizedBox(
            height: 180,
            child: Center(
              child: Text('Error: \n${snapshot.error}',
                  style: TextStyle(color: Colors.red[200])),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox(
              height: 180,
              child: Center(
                  child: Text('Sin canciones',
                      style: TextStyle(color: Colors.white70))));
        }
        final tracks = snapshot.data!;
        return Container(
          height: 180,
          decoration: BoxDecoration(
            color: const Color(0xFF182B45),
            borderRadius: BorderRadius.circular(20),
          ),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: tracks.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final track = tracks[index];
              return _buildTrackCard(track);
            },
          ),
        );
      },
    );
  }

  Widget _buildTrackCard(SpotifyTrack track) {
    return GestureDetector(
      onTap: () async {
        final player = Provider.of<PlayerProvider>(context, listen: false);
        await player.playSongFromList([
          Song(
            id: track.uri.split(':').last,
            title: track.title,
            artist: track.artist,
            album: '',
            albumArtUrl: track.albumArtUrl,
            durationMs: _parseDuration(track.duration),
          )
        ], 0);
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF182B45), // Agregado
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                track.albumArtUrl,
                width: 140,
                height: 140,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 140,
                  height: 140,
                  color: Colors.grey[900],
                  child: const Icon(Icons.music_note,
                      color: Colors.white38, size: 48),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15),
                    ),
                    Text(
                      track.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Text(
                        track.duration,
                        style: const TextStyle(
                            color: Color(0xFFe0c36a), fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _parseDuration(String durationString) {
    // Convierte "mm:ss" a milisegundos
    final parts = durationString.split(':');
    if (parts.length != 2) return 0;
    final minutes = int.tryParse(parts[0]) ?? 0;
    final seconds = int.tryParse(parts[1]) ?? 0;
    return (minutes * 60 + seconds) * 1000;
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  // Favoritas: Top tracks
  Future<List<SpotifyTrack>> _getFavoriteTracksFuture() async =>
      _fetchTopTracks();
  // Reproducidas recientemente
  Future<List<SpotifyTrack>> _getRecentlyPlayedFuture() async =>
      _fetchRecentlyPlayed();
  // Nuevos lanzamientos
  Future<List<SpotifyTrack>> _getNewReleasesFuture() async =>
      _fetchNewReleases();

  Future<List<SpotifyTrack>> _fetchTopTracks() async {
    final auth = AuthService();
    final token = await auth.getAccessToken();
    if (token == null) throw 'No se encontró el token de sesión de Spotify.';
    final url = Uri.parse('https://api.spotify.com/v1/me/top/tracks?limit=20');
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode != 200) {
      throw 'Error al obtener top tracks: \\n${response.body}';
    }
    final data = json.decode(response.body);
    final items = data['items'] as List<dynamic>;
    return items.map(_spotifyTrackFromItem).toList();
  }

  Future<List<SpotifyTrack>> _fetchRecentlyPlayed() async {
    final auth = AuthService();
    final token = await auth.getAccessToken();
    if (token == null) throw 'No se encontró el token de sesión de Spotify.';
    final url = Uri.parse(
        'https://api.spotify.com/v1/me/player/recently-played?limit=20');
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode != 200) {
      throw 'Error al obtener reproducidas recientemente: \\n${response.body}';
    }
    final data = json.decode(response.body);
    final items = data['items'] as List<dynamic>;
    return items.map((item) => _spotifyTrackFromItem(item['track'])).toList();
  }

  Future<List<SpotifyTrack>> _fetchNewReleases() async {
    final auth = AuthService();
    final token = await auth.getAccessToken();
    if (token == null) throw 'No se encontró el token de sesión de Spotify.';
    final url =
        Uri.parse('https://api.spotify.com/v1/browse/new-releases?limit=20');
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode != 200) {
      throw 'Error al obtener nuevos lanzamientos: \\n${response.body}';
    }
    final data = json.decode(response.body);
    final items = (data['albums']['items'] as List<dynamic>);
    // Tomamos la primera canción de cada álbum
    List<SpotifyTrack> tracks = [];
    for (final album in items) {
      if (album['id'] == null) continue;
      final albumId = album['id'];
      final albumUrl = Uri.parse('https://api.spotify.com/v1/albums/$albumId');
      final albumResp = await http.get(albumUrl, headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      });
      if (albumResp.statusCode == 200) {
        final albumData = json.decode(albumResp.body);
        final tracksList = albumData['tracks']['items'] as List<dynamic>;
        if (tracksList.isNotEmpty) {
          final firstTrack = tracksList[0];
          tracks.add(_spotifyTrackFromItem({
            ...firstTrack,
            'album': album, // Usamos la portada del álbum
          }));
        }
      }
    }
    return tracks;
  }

  SpotifyTrack _spotifyTrackFromItem(dynamic item) {
    final durationMs = item['duration_ms'] as int? ?? 0;
    final duration = _formatDuration(Duration(milliseconds: durationMs));
    return SpotifyTrack(
      title: item['name'] ?? '',
      artist: (item['artists'] as List).isNotEmpty
          ? item['artists'][0]['name']
          : '',
      duration: duration,
      albumArtUrl:
          item['album'] != null && (item['album']['images'] as List).isNotEmpty
              ? item['album']['images'][0]['url']
              : '',
      uri: item['uri'] ?? '',
    );
  }

  Widget _buildTaskManager() {
    // Usar solo el widget TaskManagerScreen centralizado
    return const TaskManagerScreen();
  }

  String _dueDateText(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Hoy';
    } else if (date.isBefore(now)) {
      return 'Ayer';
    } else if (date.difference(now).inDays == 1) {
      return 'Mañana';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Widget _priorityChip(String priority) {
    Color color;
    switch (priority) {
      case 'Volumen al 100':
        color = Colors.red;
        break;
      case 'Coro pegajoso':
        color = Colors.yellow[800]!;
        break;
      case 'Beat suave':
        color = Colors.green[700]!;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        border: Border.all(color: color, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(priority,
          style: TextStyle(
              color: color, fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }

  Widget _labelChip(String label) {
    Color color;
    switch (label) {
      case 'Investigación':
        color = Colors.black;
        break;
      case 'Estudio':
        color = Colors.white;
        break;
      case 'Ejercicio':
        color = Colors.white;
        break;
      case 'Viaje':
        color = Colors.white;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        border: Border.all(color: color, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
              color: color == Colors.white ? Colors.black : color,
              fontWeight: FontWeight.bold,
              fontSize: 13)),
    );
  }

  // Playlists del usuario
  Future<List<SpotifyTrack>> _getUserPlaylistsFuture() async =>
      _fetchUserPlaylists();

  Future<List<SpotifyTrack>> _fetchUserPlaylists() async {
    final auth = AuthService();
    final token = await auth.getAccessToken();
    if (token == null) throw 'No se encontró el token de sesión de Spotify.';
    final url = Uri.parse('https://api.spotify.com/v1/me/playlists?limit=20');
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode != 200) {
      throw 'Error al obtener playlists: \n${response.body}';
    }
    final data = json.decode(response.body);
    final items = data['items'] as List<dynamic>;
    return items.map((item) {
      final images = item['images'] as List<dynamic>? ?? [];
      return SpotifyTrack(
        title: item['name'] ?? '',
        artist: item['owner']?['display_name'] ?? '',
        duration: '',
        albumArtUrl: images.isNotEmpty ? images[0]['url'] ?? '' : '',
        uri: item['uri'] ?? '',
      );
    }).toList();
  }

  Widget _buildPlaylistCard(SpotifyTrack playlist) {
    return GestureDetector(
      onTap: () async {
        final auth = AuthService();
        final token = await auth.getAccessToken();
        if (token == null) {
          throw 'No se encontró el token de sesión de Spotify.';
        }

        // Obtener las canciones de la playlist
        final playlistId = playlist.uri.split(':').last;
        final url = Uri.parse(
            'https://api.spotify.com/v1/playlists/$playlistId/tracks');
        final response = await http.get(
          url,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );
        if (response.statusCode != 200) {
          throw 'Error al obtener canciones de la playlist: \n${response.body}';
        }

        final data = json.decode(response.body);
        final items = data['items'] as List<dynamic>;
        final songs = items.map((item) {
          final track = item['track'] as Map<String, dynamic>? ?? {};
          final artists = track['artists'] as List<dynamic>? ?? [];
          final album = track['album'] as Map<String, dynamic>? ?? {};
          final images = album['images'] as List<dynamic>? ?? [];

          return Song(
            id: track['id'] ?? '',
            title: track['name'] ?? '',
            artist: artists.isNotEmpty ? artists[0]['name'] ?? '' : '',
            album: album['name'] ?? '',
            albumArtUrl: images.isNotEmpty ? images[0]['url'] ?? '' : '',
            durationMs: track['duration_ms'] ?? 0,
          );
        }).toList();

        final player = Provider.of<PlayerProvider>(context, listen: false);
        await player.playSongFromList(songs, 0);
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                playlist.albumArtUrl,
                width: 140,
                height: 140,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 140,
                  height: 140,
                  color: Colors.grey[900],
                  child: const Icon(Icons.playlist_play,
                      color: Colors.white38, size: 48),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      playlist.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15),
                    ),
                    Text(
                      playlist.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFe0c36a).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const IconButton(
                          icon: Icon(Icons.play_circle_filled,
                              color: Color(0xFFe0c36a), size: 24),
                          onPressed:
                              null, // El onTap del GestureDetector maneja la reproducción
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerContent() {
    return _SpotifyGlobalSearchPlayerContent(
      buildSectionTitle: _buildSectionTitle,
      buildHorizontalTrackList: _buildHorizontalTrackList,
      buildTrackCard: _buildTrackCard,
      getFavoriteTracksFuture: _getFavoriteTracksFuture,
      getRecentlyPlayedFuture: _getRecentlyPlayedFuture,
      getNewReleasesFuture: _getNewReleasesFuture,
      getUserPlaylistsFuture: _getUserPlaylistsFuture,
      buildPlaylistCard: _buildPlaylistCard,
      playlistRefreshKey: _playlistRefreshKey, // <-- PASA LA KEY
      onRequestPlaylistRefresh: refreshPlaylists, // <-- PASA CALLBACK
    );
  }
}

class _SpotifyGlobalSearchPlayerContent extends StatefulWidget {
  final Widget Function(String) buildSectionTitle;
  final Widget Function(Future<List<SpotifyTrack>>) buildHorizontalTrackList;
  final Widget Function(SpotifyTrack) buildTrackCard;
  final Future<List<SpotifyTrack>> Function() getFavoriteTracksFuture;
  final Future<List<SpotifyTrack>> Function() getRecentlyPlayedFuture;
  final Future<List<SpotifyTrack>> Function() getNewReleasesFuture;
  final Future<List<SpotifyTrack>> Function() getUserPlaylistsFuture;
  final Widget Function(SpotifyTrack) buildPlaylistCard;
  final Key playlistRefreshKey;
  final VoidCallback onRequestPlaylistRefresh;

  const _SpotifyGlobalSearchPlayerContent({
    required this.buildSectionTitle,
    required this.buildHorizontalTrackList,
    required this.buildTrackCard,
    required this.getFavoriteTracksFuture,
    required this.getRecentlyPlayedFuture,
    required this.getNewReleasesFuture,
    required this.getUserPlaylistsFuture,
    required this.buildPlaylistCard,
    required this.playlistRefreshKey,
    required this.onRequestPlaylistRefresh,
    Key? key,
  }) : super(key: key);

  @override
  State<_SpotifyGlobalSearchPlayerContent> createState() =>
      _SpotifyGlobalSearchPlayerContentState();
}

class _SpotifyGlobalSearchPlayerContentState
    extends State<_SpotifyGlobalSearchPlayerContent> {
  final TextEditingController _searchController = TextEditingController();
  List<Song> _searchResults = [];
  bool _isSearching = false;
  String _lastQuery = '';

  void _onSearchChanged(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _lastQuery = '';
      });
      return;
    }
    setState(() {
      _isSearching = true;
    });
    try {
      final results = await SpotifySearchService.searchTracks(query);
      setState(() {
        _searchResults = results;
        _isSearching = false;
        _lastQuery = query;
      });
    } catch (_) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _lastQuery = query;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: SpotifySearchField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              hintText: 'Buscar en Spotify...',
              showClear: _searchController.text.isNotEmpty,
              onClear: () {
                _searchController.clear();
                _onSearchChanged('');
              },
            ),
          ),
        ),
        if (_searchController.text.isNotEmpty) ...[
          _isSearching
              ? const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              : _searchResults.isEmpty && _lastQuery.isNotEmpty
                  ? const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                            child: Text('No se encontraron canciones.',
                                style: TextStyle(color: Colors.white70))),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, idx) {
                          final song = _searchResults[idx];
                          return ListTile(
                            leading: song.albumArtUrl.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.network(song.albumArtUrl,
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.cover),
                                  )
                                : const Icon(Icons.music_note,
                                    color: Colors.white70),
                            title: Text(song.title,
                                style: const TextStyle(color: Colors.white)),
                            subtitle: Text(song.artist,
                                style: const TextStyle(color: Colors.white70)),
                            onTap: () async {
                              final player = Provider.of<PlayerProvider>(
                                  context,
                                  listen: false);
                              await player.playSongFromList([song], 0);
                            },
                          );
                        },
                        childCount: _searchResults.length,
                      ),
                    )
        ] else ...[
          SliverToBoxAdapter(child: widget.buildSectionTitle('Tus favoritas')),
          SliverToBoxAdapter(
              child: widget
                  .buildHorizontalTrackList(widget.getFavoriteTracksFuture())),
          SliverToBoxAdapter(
              child: widget.buildSectionTitle('Reproducidas recientemente')),
          SliverToBoxAdapter(
              child: widget
                  .buildHorizontalTrackList(widget.getRecentlyPlayedFuture())),
          SliverToBoxAdapter(
              child: widget.buildSectionTitle('Nuevos lanzamientos')),
          SliverToBoxAdapter(
              child: widget
                  .buildHorizontalTrackList(widget.getNewReleasesFuture())),
          SliverToBoxAdapter(child: widget.buildSectionTitle('Tus playlists')),
          SliverToBoxAdapter(
            child: FutureBuilder<List<SpotifyTrack>>(
              key: widget.playlistRefreshKey,
              future: widget.getUserPlaylistsFuture(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 180,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return SizedBox(
                    height: 180,
                    child: Center(
                      child: Text('Error: \n${snapshot.error}',
                          style: TextStyle(color: Colors.red[200])),
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const SizedBox(
                    height: 180,
                    child: Center(
                        child: Text('Sin playlists',
                            style: TextStyle(color: Colors.white70))),
                  );
                }
                final playlists = snapshot.data!;
                return SizedBox(
                  height: 180,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: playlists.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 16),
                    itemBuilder: (context, index) {
                      final playlist = playlists[index];
                      return widget.buildPlaylistCard(playlist);
                    },
                  ),
                );
              },
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ],
    );
  }
}

// --- SHIMMER LOADER WIDGET ---
class ShimmerLoader extends StatelessWidget {
  final double height;
  final double width;
  final BorderRadius borderRadius;
  const ShimmerLoader({
    this.height = 24,
    this.width = double.infinity,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1.0),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Container(
            height: height,
            width: width,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.13 + 0.13 * value),
              borderRadius: borderRadius,
            ),
          ),
        );
      },
      onEnd: () {},
    );
  }
}
