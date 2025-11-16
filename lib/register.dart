import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'auth_service.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
// For Storage
// import 'package:firebase_storage/firebase_storage.dart';
// import 'dart:io';

class AppBottomBarButtons extends StatelessWidget {
  const AppBottomBarButtons({
    super.key,
    required this.buttons,
    required this.body,
    this.appBar,
  });

  final List<Widget> buttons;
  final Widget body;
  final PreferredSizeWidget? appBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      body: body,
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 24.0,
          horizontal: 16.0,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: buttons,
        ),
      ),
    );
  }
}

class ButtonWidget extends StatelessWidget {
  const ButtonWidget({
    super.key,
    this.isFilled = false,
    required this.label,
    required this.callback,
  });

  final bool isFilled;
  final String label;
  final Function()? callback;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: callback,
      style: ElevatedButton.styleFrom(
        backgroundColor:
            isFilled ? Theme.of(context).colorScheme.primary : Colors.transparent,
        foregroundColor: isFilled ? Colors.black87 : Colors.white,
        minimumSize: const Size(double.infinity, 50),
      ),
      child: Text(label),
    );
  }
}

class BottomStepperWidget extends StatelessWidget {
  const BottomStepperWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(height: 8);
  }
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // Controladores
  final TextEditingController controllerFirstName = TextEditingController();
  final TextEditingController controllerLastName = TextEditingController();
  final TextEditingController controllerEmail = TextEditingController();
  final TextEditingController controllerPassword = TextEditingController();
  final TextEditingController controllerIdNumber = TextEditingController();

  // Estado de validación
  String firstNameError = '';
  String lastNameError = '';
  String emailError = '';
  String passwordError = '';
  String idError = '';
  String locationError = '';
  String backendError = '';

  // Ubicación
  double? latitude;
  double? longitude;

  // Profile image (cuando tengas picker / storage)
  // String? localImagePath;
  // String? uploadedImageUrl;

  @override
  void dispose() {
    controllerFirstName.dispose();
    controllerLastName.dispose();
    controllerEmail.dispose();
    controllerPassword.dispose();
    controllerIdNumber.dispose();
    super.dispose();
  }

  bool validEmailAddress(String email) {
    final regex = RegExp(r"^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+$");
    return regex.hasMatch(email);
  }

  bool validateForm() {
    final firstName = controllerFirstName.text.trim();
    final lastName = controllerLastName.text.trim();
    final email = controllerEmail.text.trim();
    final password = controllerPassword.text.trim();
    final idNumber = controllerIdNumber.text.trim();

    bool isValid = true;

    setState(() {
      firstNameError = '';
      lastNameError = '';
      emailError = '';
      passwordError = '';
      idError = '';
      locationError = '';
      backendError = '';
    });

    if (firstName.isEmpty) {
      firstNameError = 'First name is empty';
      isValid = false;
    }

    if (lastName.isEmpty) {
      lastNameError = 'Last name is empty';
      isValid = false;
    }

    if (email.isEmpty) {
      emailError = 'Email is empty';
      isValid = false;
    } else if (!validEmailAddress(email)) {
      emailError = 'Not a valid email address';
      isValid = false;
    }

    if (password.isEmpty) {
      passwordError = 'Password is empty';
      isValid = false;
    } else if (password.length < 6) {
      passwordError = 'Password is too short (min 6 characters)';
      isValid = false;
    }

    if (idNumber.isEmpty) {
      idError = 'ID number is empty';
      isValid = false;
    } else if (int.tryParse(idNumber) == null) {
      idError = 'ID must be numeric';
      isValid = false;
    }

    if (latitude == null || longitude == null) {
      locationError = 'Location is required. Please get your location.';
      isValid = false;
    }

    setState(() {});

    return isValid;
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          locationError = 'Location services are disabled.';
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            locationError = 'Location permissions are denied.';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          locationError =
              'Location permissions are permanently denied. Enable them in settings.';
        });
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        ),
      );


      setState(() {
        latitude = pos.latitude;
        longitude = pos.longitude;
        locationError = '';
      });
    } catch (e) {
      setState(() {
        locationError = 'Error getting location: $e';
      });
    }
  }

  Future<void> register() async {
    if (!validateForm()) return;

    try {
      final auth = context.read<AuthService>();

      final cred = await auth.createAccount(
        email: controllerEmail.text.trim(),
        password: controllerPassword.text.trim(),
      );

      final user = cred.user;
      if (user == null) {
        setState(() {
          backendError = 'User could not be created.';
        });
        return;
      }

      // Space for Firebase Storage
      // if (localImagePath != null) {
      //   final storageRef = FirebaseStorage.instance
      //       .ref()
      //       .child('profile_images')
      //       .child('${user.uid}.jpg');
      //
      //   final file = File(localImagePath!);
      //   await storageRef.putFile(file);
      //   uploadedImageUrl = await storageRef.getDownloadURL();
      // }

      final dbRef = FirebaseDatabase.instance.refFromURL(
        'https://taller-3-4fca0-default-rtdb.firebaseio.com/users/${user.uid}',
      );

      await dbRef.set({
        'firstName': controllerFirstName.text.trim(),
        'lastName': controllerLastName.text.trim(),
        'email': controllerEmail.text.trim(),
        'idNumber': controllerIdNumber.text.trim(),
        'latitude': latitude,
        'longitude': longitude,
        // 'imageUrl': uploadedImageUrl, // cuando implementes Storage
        'createdAt': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;
      Navigator.pop(context);
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        backendError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomBarButtons(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Colors.white,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size(double.infinity, 24),
          child: BottomStepperWidget(),
        ),
      ),

      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            children: [
              const SizedBox(height: 40.0),
              const Text(
                'Register',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20.0),

              Image.asset(
                "assets/images/register.png",
                width: 90,
                height: 90,
              ),

              const SizedBox(height: 40),

              TextField(
                controller: controllerFirstName,
                decoration: InputDecoration(
                  labelText: 'First name',
                  errorText: firstNameError.isEmpty ? null : firstNameError,
                ),
              ),
              const SizedBox(height: 10),

              TextField(
                controller: controllerLastName,
                decoration: InputDecoration(
                  labelText: 'Last name',
                  errorText: lastNameError.isEmpty ? null : lastNameError,
                ),
              ),
              const SizedBox(height: 10),

              TextField(
                controller: controllerEmail,
                decoration: InputDecoration(
                  labelText: 'Email',
                  errorText: emailError.isEmpty ? null : emailError,
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 10),

              TextField(
                controller: controllerPassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  errorText: passwordError.isEmpty ? null : passwordError,
                ),
                obscureText: true,
              ),
              const SizedBox(height: 10),

              TextField(
                controller: controllerIdNumber,
                decoration: InputDecoration(
                  labelText: 'ID number',
                  errorText: idError.isEmpty ? null : idError,
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: Text(
                      latitude != null && longitude != null
                          ? 'Lat: ${latitude!.toStringAsFixed(5)}\nLng: ${longitude!.toStringAsFixed(5)}'
                          : 'Location not obtained yet',
                    ),
                  ),
                  IconButton(
                    onPressed: _getCurrentLocation,
                    icon: const Icon(Icons.my_location),
                  ),
                ],
              ),
              if (locationError.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    locationError,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.redAccent,
                    ),
                  ),
                ),

              const SizedBox(height: 10),

              // Here is how the profile image should word when someone fixes the billing account
              // OutlinedButton.icon(
              //   onPressed: () async {
              //     // Aquí podrías usar image_picker para seleccionar la imagen:
              //     // final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
              //     // if (picked != null) {
              //     //   setState(() {
              //     //     localImagePath = picked.path;
              //     //   });
              //     // }
              //   },
              //   icon: const Icon(Icons.image),
              //   label: Text(localImagePath == null
              //       ? 'Select profile image'
              //       : 'Image selected'),
              // ),

              const SizedBox(height: 10),

              if (backendError.isNotEmpty)
                Text(
                  backendError,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.redAccent,
                  ),
                ),
            ],
          ),
        ),
      ),

      buttons: [
        ButtonWidget(
          isFilled: true,
          label: 'Register',
          callback: register,
        ),
      ],
    );
  }
}