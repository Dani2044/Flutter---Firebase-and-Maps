import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'firebase_options.dart';
import 'package:provider/provider.dart';
import 'package:firebase_database/firebase_database.dart';

import 'auth_service.dart';
import 'welcome.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    ChangeNotifierProvider(
      create: (context) => AuthService(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);

    return MaterialApp(
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

  @override
  void initState() {
    super.initState();
    _loadUserData();
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

    if (mounted) {
      _updateMarker();
      setState(() {});
      if (_mapController != null && userPosition != null) {
        _mapController!.animateCamera(CameraUpdate.newLatLng(userPosition!));
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
    );
  }
}
