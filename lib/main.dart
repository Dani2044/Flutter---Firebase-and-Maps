import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'package:provider/provider.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:math' as math;

import 'auth_service.dart';
import 'welcome.dart';
import 'tracking.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(
    ChangeNotifierProvider(
      create: (context) => AuthService(),
      child: const MyApp(),
    ),
  );
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // manejar el background message por si es necesario
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    // Configuracion del Firebase Messaging: manejar permisos, guardar el token, etc.
    final messaging = FirebaseMessaging.instance;
    messaging.requestPermission();

    // guardar el token cuando este disponible (osea si el usuario ingresa)
    messaging.getToken().then((token) async {
      if (authService.currentUser != null) {
        await authService.updateFcmToken(token);
      }
    }).catchError((e) {
      // ignorar errores de token
    });

    // manejo de notificacion cuando la app no estaba abierta
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null && message.data['trackedUid'] != null) {
        final trackedUid = message.data['trackedUid'];
        if (authService.currentUser != null) {
          navigatorKey.currentState?.push(MaterialPageRoute(
            builder: (_) => TrackingPage(trackedUid: trackedUid),
          ));
        } else {
          navigatorKey.currentState?.push(MaterialPageRoute(
            builder: (_) => const WelcomePage(),
          ));
        }
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final data = message.data;
      final trackedUid = data['trackedUid'];
      if (trackedUid != null) {
        if (authService.currentUser != null) {
          navigatorKey.currentState?.push(MaterialPageRoute(
            builder: (_) => TrackingPage(trackedUid: trackedUid),
          ));
        } else {
          navigatorKey.currentState?.push(MaterialPageRoute(
            builder: (_) => const WelcomePage(),
          ));
        }
      }
    });

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: StreamBuilder(
        stream: authService.authStateChanges,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return const HomePage();
          }
          return const WelcomePage();
        },
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool? isAvailable;
  LatLng? userPosition;
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  List<Map<String, dynamic>> availableUsers = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    // Asegurarse de que el token este guardado para el usuario ingresado
    FirebaseMessaging.instance.getToken().then((token) {
      final auth = context.read<AuthService>();
      if (auth.currentUser != null && token != null) {
        auth.updateFcmToken(token);
      }
    }).catchError((_) {});
  }

  /// Calcula la distancia en metros entre dos coordenadas
  double _calculateDistance(LatLng start, LatLng end) {
    const earthRadius = 6371000; 
    final dLat = (end.latitude - start.latitude) * math.pi / 180;
    final dLng = (end.longitude - start.longitude) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(start.latitude * math.pi / 180) *
            math.cos(end.latitude * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  Future<void> _loadUserData() async {
    final user = context.read<AuthService>().currentUser;
    if (user == null) return;

    final ref = FirebaseDatabase.instance.ref('users/${user.uid}');
    final snapshot = await ref.get();

    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      isAvailable = (data['available'] ?? false) as bool;
      final lat = (data['latitude'] ?? 0.0).toDouble();
      final lng = (data['longitude'] ?? 0.0).toDouble();
      userPosition = LatLng(lat, lng);
    } else {
      isAvailable = false;
      userPosition = const LatLng(27.34, -122.03);
      await ref.set({
        'available': false,
        'latitude': userPosition!.latitude,
        'longitude': userPosition!.longitude,
      });
    }

    // cargar usuarios disponibles
    _loadAvailableUsers();

    if (mounted) {
      _updateMarker();
      setState(() {});
      if (_mapController != null && userPosition != null) {
        _mapController!.animateCamera(CameraUpdate.newLatLng(userPosition!));
      }
    }
  }

  Future<void> _loadAvailableUsers() async {
    try {
      final ref = FirebaseDatabase.instance.ref('users');
        final currentUser = context.read<AuthService>().currentUser;
      final snapshot = await ref.get();

      if (snapshot.exists) {
        final usersData = snapshot.value as Map<dynamic, dynamic>;
        availableUsers.clear();

        usersData.forEach((uid, userData) {
                    // excluir al usuario actual
                    if (uid == currentUser?.uid) return;

          if (userData is Map<dynamic, dynamic>) {
            final available = userData['available'] ?? false;
            if (available == true) {
              final distance = userPosition != null
                  ? _calculateDistance(
                      userPosition!,
                      LatLng(
                        (userData['latitude'] ?? 0.0).toDouble(),
                        (userData['longitude'] ?? 0.0).toDouble(),
                      ),
                    )
                  : 0.0;

              availableUsers.add({
                'uid': uid,
                'firstName': userData['firstName'] ?? 'Usuario',
                'lastName': userData['lastName'] ?? '',
                'email': userData['email'] ?? '',
                'latitude': (userData['latitude'] ?? 0.0).toDouble(),
                'longitude': (userData['longitude'] ?? 0.0).toDouble(),
                'distance': distance,
              });
            }
          }
        });

        // Ordenar por distancia
        availableUsers.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));

        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      print('Error cargando usuarios disponibles: $e');
      if (mounted) {
        setState(() {
          availableUsers = [];
        });
      }
    }
  }

  void _updateMarker() {
    if (userPosition == null) return;
    _markers.clear();
    _markers.add(
      Marker(
        markerId: const MarkerId('user_location'),
        position: userPosition!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'Tu ubicación'),
      ),
    );
  }

  void _showUserOnMap(Map<String, dynamic> user) {
    final userPosition = LatLng(user['latitude'] as double, user['longitude'] as double);
    final distance = user['distance'] as double;

    // Agregar marcador del user q escoja
    _markers.add(
      Marker(
        markerId: MarkerId(user['uid'] as String),
        position: userPosition,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: '${user['firstName']} ${user['lastName']}',
          snippet: 'Distancia: ${(distance / 1000).toStringAsFixed(2)} km',
        ),
      ),
    );

    // esto es para  q se centre el mapa en el user q se seleccione
    _mapController?.animateCamera(CameraUpdate.newLatLng(userPosition));

    setState(() {});
  }

  Future<void> _toggleAvailability() async {
    final user = context.read<AuthService>().currentUser;
    if (user == null) return;

    final newValue = !(isAvailable ?? false);
    final ref = FirebaseDatabase.instance.ref('users/${user.uid}/available');
    await ref.set(newValue);

    if (mounted) {
      setState(() => isAvailable = newValue);
    }
  }

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(27.34, -122.03),
    zoom: 14.4,
  );

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    final user = authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Inicio', style: TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            if (user != null)
              Text(
                user.email ?? '',
                style: TextStyle(
                  fontSize: 18,
                  color: isAvailable == true ? Colors.green : Colors.grey,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              isAvailable == true ? Icons.toggle_on : Icons.toggle_off,
              color: isAvailable == true ? Colors.green : Colors.grey,
              size: 38,
            ),
            onPressed: isAvailable == null ? null : _toggleAvailability,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent, size: 32),
            onPressed: () async => await authService.signOut(),
          ),
        ],
      ),
      body: GoogleMap(
        initialCameraPosition: userPosition != null
            ? CameraPosition(target: userPosition!, zoom: 14.4)
            : _initialPosition,
        markers: _markers,
        onMapCreated: (controller) {
          _mapController = controller;
          if (userPosition != null) {
            controller.animateCamera(CameraUpdate.newLatLng(userPosition!));
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAvailableUsersList(context);
        },
        tooltip: 'Ver usuarios disponibles',
        child: const Icon(Icons.people),
      ),
    );
  }

  void _showAvailableUsersList(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Usuarios Disponibles (${availableUsers.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: availableUsers.isEmpty
                    ? const Center(
                        child: Text('No hay usuarios disponibles'),
                      )
                    : ListView.builder(
                        itemCount: availableUsers.length,
                        itemBuilder: (context, index) {
                          final user = availableUsers[index];
                          final distance = user['distance'] as double;
                          final distanceKm = distance / 1000;

                          final String firstNameStr = (user['firstName'] ?? '') as String;
                          final String lastNameStr = (user['lastName'] ?? '') as String;
                          final String initials = (() {
                            String s = '';
                            if (firstNameStr.isNotEmpty) s += firstNameStr[0].toUpperCase();
                            if (lastNameStr.isNotEmpty) s += lastNameStr[0].toUpperCase();
                            return s.isEmpty ? 'U' : s;
                          })();

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                child: Text(initials),
                              ),
                              title: Text(
                                '${user['firstName']} ${user['lastName']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(user['email'] as String),
                                  Text(
                                    'Distancia: ${distanceKm.toStringAsFixed(2)} km',
                                    style: const TextStyle(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: ElevatedButton.icon(
                                onPressed: () {
                                  _showUserOnMap(user);
                                  Navigator.pop(context);
                                },
                                icon: const Icon(Icons.location_on),
                                label: const Text('Ver'),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
