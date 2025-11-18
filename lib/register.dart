import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'auth_service.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
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
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
        child: Column(mainAxisSize: MainAxisSize.min, children: buttons),
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
        backgroundColor: isFilled
            ? Theme.of(context).colorScheme.primary
            : Colors.transparent,
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

class RegisterFormModel extends ChangeNotifier {
  String firstNameError = '';
  String lastNameError = '';
  String emailError = '';
  String passwordError = '';
  String idError = '';
  String locationError = '';
  String backendError = '';

  double? latitude;
  double? longitude;

  // String? localImagePath;
  // String? uploadedImageUrl;

  bool _validEmailAddress(String email) {
    final regex = RegExp(r"^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+$");
    return regex.hasMatch(email);
  }

  void clearBackendError() {
    backendError = '';
    notifyListeners();
  }

  void setBackendError(String message) {
    backendError = message;
    notifyListeners();
  }

  void setLocation({required double lat, required double lng}) {
    latitude = lat;
    longitude = lng;
    locationError = '';
    notifyListeners();
  }

  void setLocationError(String message) {
    locationError = message;
    notifyListeners();
  }

  void _resetErrors() {
    firstNameError = '';
    lastNameError = '';
    emailError = '';
    passwordError = '';
    idError = '';
    locationError = '';
  }

  bool validateForm({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String idNumber,
  }) {
    _resetErrors();

    bool isValid = true;

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
    } else if (!_validEmailAddress(email)) {
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

    notifyListeners();
    return isValid;
  }
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController controllerFirstName = TextEditingController();
  final TextEditingController controllerLastName = TextEditingController();
  final TextEditingController controllerEmail = TextEditingController();
  final TextEditingController controllerPassword = TextEditingController();
  final TextEditingController controllerIdNumber = TextEditingController();

  @override
  void dispose() {
    controllerFirstName.dispose();
    controllerLastName.dispose();
    controllerEmail.dispose();
    controllerPassword.dispose();
    controllerIdNumber.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation(BuildContext ctx) async {
    final model = ctx.read<RegisterFormModel>();

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        model.setLocationError('Location services are disabled.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          model.setLocationError('Location permissions are denied.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        model.setLocationError(
          'Location permissions are permanently denied. Enable them in settings.',
        );
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        ),
      );

      model.setLocation(lat: pos.latitude, lng: pos.longitude);
    } catch (e) {
      model.setLocationError('Error getting location: $e');
    }
  }

  Future<void> _register(BuildContext ctx) async {
    final model = ctx.read<RegisterFormModel>();
    final auth = ctx.read<AuthService>();

    final firstName = controllerFirstName.text.trim();
    final lastName = controllerLastName.text.trim();
    final email = controllerEmail.text.trim();
    final password = controllerPassword.text.trim();
    final idNumber = controllerIdNumber.text.trim();

    model.clearBackendError();

    final isValid = model.validateForm(
      firstName: firstName,
      lastName: lastName,
      email: email,
      password: password,
      idNumber: idNumber,
    );

    if (!isValid) return;

    try {
      final cred = await auth.createAccount(email: email, password: password);

      final user = cred.user;
      if (user == null) {
        model.setBackendError('User could not be created.');
        return;
      }

      // if (model.localImagePath != null) {
      //   final storageRef = FirebaseStorage.instance
      //       .ref()
      //       .child('profile_images')
      //       .child('${user.uid}.jpg');
      //
      //   final file = File(model.localImagePath!);
      //   await storageRef.putFile(file);
      //   model.uploadedImageUrl = await storageRef.getDownloadURL();
      // }

      final dbRef = FirebaseDatabase.instance.refFromURL(
        'https://taller-3-4fca0-default-rtdb.firebaseio.com/users/${user.uid}',
      );

      await dbRef.set({
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'idNumber': idNumber,
        'latitude': model.latitude,
        'longitude': model.longitude,
        // 'imageUrl': model.uploadedImageUrl,
        'createdAt': DateTime.now().toIso8601String(),
        'available': false,
      });

      if (!ctx.mounted) return;
      Navigator.pop(ctx);
    } on Exception catch (e) {
      if (!ctx.mounted) return;
      model.setBackendError(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RegisterFormModel(),
      child: Builder(
        builder: (innerCtx) {
          return AppBottomBarButtons(
            appBar: AppBar(
              leading: IconButton(
                onPressed: () => Navigator.pop(innerCtx),
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              ),
              bottom: const PreferredSize(
                preferredSize: Size(double.infinity, 24),
                child: BottomStepperWidget(),
              ),
            ),

            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(30.0),
                child: Consumer<RegisterFormModel>(
                  builder: (ctx, model, _) {
                    return Column(
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
                            errorText: model.firstNameError.isEmpty
                                ? null
                                : model.firstNameError,
                          ),
                        ),
                        const SizedBox(height: 10),

                        TextField(
                          controller: controllerLastName,
                          decoration: InputDecoration(
                            labelText: 'Last name',
                            errorText: model.lastNameError.isEmpty
                                ? null
                                : model.lastNameError,
                          ),
                        ),
                        const SizedBox(height: 10),

                        TextField(
                          controller: controllerEmail,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            errorText: model.emailError.isEmpty
                                ? null
                                : model.emailError,
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 10),

                        TextField(
                          controller: controllerPassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            errorText: model.passwordError.isEmpty
                                ? null
                                : model.passwordError,
                          ),
                          obscureText: true,
                        ),
                        const SizedBox(height: 10),

                        TextField(
                          controller: controllerIdNumber,
                          decoration: InputDecoration(
                            labelText: 'ID number',
                            errorText: model.idError.isEmpty
                                ? null
                                : model.idError,
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 20),

                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                model.latitude != null &&
                                        model.longitude != null
                                    ? 'Lat: ${model.latitude!.toStringAsFixed(5)}\nLng: ${model.longitude!.toStringAsFixed(5)}'
                                    : 'Location not obtained yet',
                              ),
                            ),
                            IconButton(
                              onPressed: () => _getCurrentLocation(innerCtx),
                              icon: const Icon(Icons.my_location),
                            ),
                          ],
                        ),
                        if (model.locationError.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              model.locationError,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.redAccent,
                              ),
                            ),
                          ),

                        const SizedBox(height: 10),

                        // OutlinedButton.icon(
                        //   onPressed: () async {
                        //     // final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
                        //     // if (picked != null) {
                        //     //   model.setLocalImagePath(picked.path);
                        //     // }
                        //   },
                        //   icon: const Icon(Icons.image),
                        //   label: Text(
                        //     model.localImagePath == null
                        //         ? 'Select profile image'
                        //         : 'Image selected',
                        //   ),
                        // ),
                        const SizedBox(height: 10),

                        if (model.backendError.isNotEmpty)
                          Text(
                            model.backendError,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.redAccent,
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),

            buttons: [
              ButtonWidget(
                isFilled: true,
                label: 'Register',
                callback: () => _register(innerCtx),
              ),
            ],
          );
        },
      ),
    );
  }
}
