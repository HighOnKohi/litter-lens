import 'package:flutter/material.dart';
import 'package:litter_lens/theme.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  void _login() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            child: Image.asset(
              'assets/images/shapes.png',
              width: 200,
              height: 200,
              fit: BoxFit.contain,
            ),
          ),

          // main content
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 25),
                  child: Column(
                    children: [
                      const Text(
                        "LOGIN",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      Image.asset(
                        'assets/images/litter_lens_logo.png',
                        width: 150,
                        height: 150,
                        fit: BoxFit.contain,
                      ),
                    ],
                  ),
                ),
                InputField(
                  inputController: _usernameController,
                  obscuring: false,
                  label: "Username",
                ),
                const SizedBox(height: 16),
                InputField(
                  inputController: _passwordController,
                  obscuring: true,
                  label: "Password",
                ),
                const SizedBox(height: 24),
                BigGreenButton(onPressed: _login, text: "Login"),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
