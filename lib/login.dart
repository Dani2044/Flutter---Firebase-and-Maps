import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'auth_service.dart';
import 'reset_password.dart';

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

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController controllerEmail = TextEditingController();
  final TextEditingController controllerPassword = TextEditingController();

  String emailError = '';
  String passwordError = '';
  String backendError = '';

  @override
  void dispose() {
    controllerEmail.dispose();
    controllerPassword.dispose();
    super.dispose();
  }

  bool validEmailAddress(String email) {
    final regex = RegExp(r"^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+$");
    return regex.hasMatch(email);
  }

  bool validateForm() {
    String email = controllerEmail.text.trim();
    String password = controllerPassword.text.trim();

    if (email.isEmpty) {
      setState(() {
        emailError = "Email is empty";
      });
      return false;
    } else {
      setState(() => emailError = '');
    }

    if (!validEmailAddress(email)) {
      setState(() {
        emailError = "Not a valid email address";
      });
      return false;
    } else {
      setState(() => emailError = '');
    }

    if (password.isEmpty) {
      setState(() {
        passwordError = "Password is empty";
      });
      return false;
    } else {
      setState(() => passwordError = '');
    }

    if (password.length < 6) {
      setState(() {
        passwordError = "Password is too short";
      });
      return false;
    } else {
      setState(() => passwordError = '');
    }

    return true;
  }

  Future<void> signIn() async {
    if (!validateForm()) return;

    try {
      final auth = context.read<AuthService>();
      await auth.signIn(
        email: controllerEmail.text.trim(),
        password: controllerPassword.text.trim(),
      );

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
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
        ),
      ),

      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            children: [
              const SizedBox(height: 60.0),
              const Text(
                'Log in',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20.0),
              Image.asset("assets/images/login.png", width: 90, height: 90),

              const SizedBox(height: 40),

              // EMAIL FIELD
              TextField(
                controller: controllerEmail,
                decoration: InputDecoration(
                  labelText: 'Email',
                  errorText: emailError.isEmpty ? null : emailError,
                ),
              ),

              const SizedBox(height: 10),

              // PASSWORD FIELD
              TextField(
                controller: controllerPassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  errorText: passwordError.isEmpty ? null : passwordError,
                ),
                obscureText: true,
              ),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ResetPasswordPage(email: controllerEmail.text),
                      ),
                    );
                  },
                  child: const Text('Reset password'),
                ),
              ),

              if (backendError.isNotEmpty)
                Text(
                  backendError,
                  style: const TextStyle(color: Colors.redAccent),
                ),
            ],
          ),
        ),
      ),

      buttons: [
        ButtonWidget(
          isFilled: true,
          label: 'Log in',
          callback: signIn,
        ),
      ],
    );
  }
}