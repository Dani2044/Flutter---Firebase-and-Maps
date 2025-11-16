import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'auth_service.dart';
import 'reset_password.dart';

class LoginFormModel extends ChangeNotifier {
  String emailError = '';
  String passwordError = '';
  String backendError = '';

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

  bool validateForm({
    required String email,
    required String password,
  }) {
    String newEmailError = '';
    String newPasswordError = '';

    if (email.isEmpty) {
      newEmailError = 'Email is empty';
    } else if (!_validEmailAddress(email)) {
      newEmailError = 'Not a valid email address';
    }

    if (password.isEmpty) {
      newPasswordError = 'Password is empty';
    } else if (password.length < 6) {
      newPasswordError = 'Password is too short';
    }

    emailError = newEmailError;
    passwordError = newPasswordError;

    notifyListeners();
    return emailError.isEmpty && passwordError.isEmpty;
  }
}

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

  @override
  void dispose() {
    controllerEmail.dispose();
    controllerPassword.dispose();
    super.dispose();
  }

  Future<void> _signIn(BuildContext ctx) async {
    final model = ctx.read<LoginFormModel>();
    final auth = ctx.read<AuthService>();

    final email = controllerEmail.text.trim();
    final password = controllerPassword.text.trim();

    model.clearBackendError();

    final isValid = model.validateForm(email: email, password: password);
    if (!isValid) return;

    try {
      await auth.signIn(email: email, password: password);

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
      create: (_) => LoginFormModel(),
      child: Builder(
        builder: (innerContext) {
          return AppBottomBarButtons(
            appBar: AppBar(
              leading: IconButton(
                onPressed: () => Navigator.pop(innerContext),
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              ),
            ),
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(30.0),
                child: Consumer<LoginFormModel>(
                  builder: (context, model, _) {
                    return Column(
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
                        Image.asset(
                          "assets/images/login.png",
                          width: 90,
                          height: 90,
                        ),

                        const SizedBox(height: 40),

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

                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              Navigator.push(
                                innerContext,
                                MaterialPageRoute(
                                  builder: (ctx) => ResetPasswordPage(
                                    email: controllerEmail.text,
                                  ),
                                ),
                              );
                            },
                            child: const Text('Reset password'),
                          ),
                        ),

                        if (model.backendError.isNotEmpty)
                          Text(
                            model.backendError,
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),

            buttons: [
              Consumer<LoginFormModel>(
                builder: (ctx, model, _) {
                  return ButtonWidget(
                    isFilled: true,
                    label: 'Log in',
                    callback: () => _signIn(ctx),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}