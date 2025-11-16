import 'package:flutter/material.dart';

import 'login.dart';
import 'register.dart';

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
      body: SafeArea(child: body),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 24.0,
          horizontal: 16.0,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
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

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBottomBarButtons(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Image.asset(
                  "assets/images/welcome.png",
                  width: MediaQuery.of(context).size.width * 0.6,
                ),
              )
            ],
          ),
        ),
      ),

      buttons: [
        ButtonWidget(
          label: "Register",
          isFilled: true,
          callback: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const RegisterPage(),
              ),
            );
          },
        ),
        const SizedBox(height: 10.0),
        ButtonWidget(
          label: "Log in",
          callback: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const LoginPage(),
              ),
            );
          },
        ),
      ],
    );
  }
}