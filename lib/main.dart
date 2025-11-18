import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
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

  @override
  void initState() {
    super.initState();
    _loadAvailability();
  }

  Future<void> _loadAvailability() async {
    final user = context.read<AuthService>().currentUser;
    if (user == null) return;

    final ref = FirebaseDatabase.instance.ref('users/${user.uid}/available');
    final snapshot = await ref.get();

    if (snapshot.exists) {
      isAvailable = snapshot.value as bool;
    } else {
      isAvailable = false;
      await ref.set(false);
    }
    if (mounted) setState(() {});
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

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    final user = authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text('Inicio', style: TextStyle(fontWeight: FontWeight.bold)),
            Spacer(),
            if (user != null) ...[
              Text(
                user.email ?? '',
                style: TextStyle(
                  fontSize: 18,
                  color: isAvailable == true ? Colors.green : Colors.grey
                )
              ),
            ],
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
            icon: Icon(Icons.logout, color: Colors.redAccent, size: 32),
            onPressed: () async => await authService.signOut(),
          ),
        ],
      ),
      body: Center(
        child: Text(
          isAvailable == null
              ? 'Cargando estado...'
              : 'Estado: ${isAvailable! ? "Disponible ✅" : "No disponible ❌"}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
