import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'auth_service.dart';

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
      resizeToAvoidBottomInset: true,
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

class ResetPasswordModel extends ChangeNotifier {
  String errorMessage = '';

  void setError(String message) {
    errorMessage = message;
    notifyListeners();
  }

  void clearError() {
    errorMessage = '';
    notifyListeners();
  }
}

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({
    super.key,
    required this.email,
  });

  final String email;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final TextEditingController controllerEmail = TextEditingController();
  final formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    controllerEmail.text = widget.email;
  }

  @override
  void dispose() {
    controllerEmail.dispose();
    super.dispose();
  }

  void showSnackBar(BuildContext ctx) {
    ScaffoldMessenger.of(ctx).clearMaterialBanners();
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        backgroundColor: Theme.of(ctx).colorScheme.primary,
        content: const Text(
          'Please check your email',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white,
          ),
        ),
        showCloseIcon: true,
      ),
    );
  }

  Future<void> reset(BuildContext ctx) async {
    final auth = ctx.read<AuthService>();
    final model = ctx.read<ResetPasswordModel>();

    try {
      await auth.resetPassword(email: controllerEmail.text.trim());

      if (!ctx.mounted) return;
      model.clearError();
      showSnackBar(ctx);
    } on Exception catch (e) {
      if (!ctx.mounted) return;
      model.setError(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ResetPasswordModel(),
      child: Builder(
        builder: (innerCtx) {
          return AppBottomBarButtons(
            appBar: AppBar(
              leading: IconButton(
                onPressed: () {
                  Navigator.pop(innerCtx);
                },
                icon: const Icon(
                  Icons.arrow_back_ios,
                  color: Colors.white,
                ),
              ),
            ),
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(30.0),
                child: Column(
                  children: [
                    const SizedBox(height: 60.0),
                    const Text(
                      'Reset password',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20.0),

                    Image.asset(
                      "assets/images/reset.png",
                      width: 90,
                      height: 90,
                    ),

                    const SizedBox(height: 50),

                    Form(
                      key: formKey,
                      child: Consumer<ResetPasswordModel>(
                        builder: (ctx, model, _) {
                          return Column(
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
                              if (model.errorMessage.isNotEmpty)
                                Text(
                                  model.errorMessage,
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

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            buttons: [
              ButtonWidget(
                isFilled: true,
                label: 'Reset password',
                callback: () async {
                  if (formKey.currentState!.validate()) {
                    await reset(innerCtx);
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }
}