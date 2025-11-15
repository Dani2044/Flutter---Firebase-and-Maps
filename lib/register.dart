import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'auth_service.dart';
import 'onboarding.dart';

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
    if (isFilled) {
      return ElevatedButton(
        onPressed: callback,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.black87,
          minimumSize: const Size(double.infinity, 50),
        ),
        child: Text(label),
      );
    } else {
      return ElevatedButton(
        onPressed: callback,
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
        ),
        child: Text(label),
      );
    }
  }
}

class BottomStepperWidget extends StatelessWidget {
  const BottomStepperWidget({
    super.key,
    this.itemCount,
  });

  final int? itemCount;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: AppData.onboardingCurrentIndexNotifier,
      builder: (context, currentIndex, child) {
        String label;
        if (itemCount == null) {
          label = 'Last step';
        } else {
          label = 'Step ${currentIndex + 1} of $itemCount';
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white54,
            ),
          ),
        );
      },
    );
  }
}

class AppData {
  static ValueNotifier<int> onboardingCurrentIndexNotifier =
      ValueNotifier<int>(0);
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController controllerEmail = TextEditingController();
  final TextEditingController controllerPassword = TextEditingController();
  final formKey = GlobalKey<FormState>();

  String errorMessage = '';

  @override
  void dispose() {
    controllerEmail.dispose();
    controllerPassword.dispose();
    super.dispose();
  }

  Future<void> register() async {
    try {
      final auth = context.read<AuthService>();
      await auth.createAccount(
        email: controllerEmail.text.trim(),
        password: controllerPassword.text.trim(),
      );

      if (!mounted) return;
      Navigator.pop(context);

    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomBarButtons(
      appBar: AppBar(
        leading: ValueListenableBuilder(
          valueListenable: AppData.onboardingCurrentIndexNotifier,
          builder: (context, currentIndex, child) {
            return IconButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) {
                      return OnboardingPages(initialPage: currentIndex);
                    },
                  ),
                );
              },
              icon: const Icon(
                Icons.arrow_back_ios,
                color: Colors.white,
              ),
            );
          },
        ),
        title: const Text("Flutter Pro"),
        bottom: const PreferredSize(
          preferredSize: Size(double.infinity, double.minPositive),
          child: BottomStepperWidget(),
        ),
      ),

      /// =========================
      /// ======== BODY ===========
      /// =========================
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            children: [
              const SizedBox(height: 60.0),
              const Text(
                'Register',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20.0),
              const Text(
                '🔑',
                style: TextStyle(
                  fontSize: 40,
                ),
              ),
              const SizedBox(height: 50),

              Form(
                key: formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: controllerEmail,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                      ),
                      validator: (String? value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please, enter something';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),

                    TextFormField(
                      controller: controllerPassword,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                      ),
                      obscureText: true,
                      validator: (String? value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please, enter something';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),

                    if (errorMessage.isNotEmpty)
                      Text(
                        errorMessage,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.redAccent,
                        ),
                      ),
                  ],
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
          callback: () {
            if (formKey.currentState!.validate()) {
              register();
            }
          },
        ),
      ],
    );
  }
}