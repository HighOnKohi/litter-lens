import 'package:flutter/material.dart';

class AppColors {
  static const bgColor = Color(0xFFEEFFF7);
  static const primaryGreen = Color(0xFF0B8A4D);
  static const adminGold = Color(0xFFF5BD02);
  static const collectorPink = Color(0xFFC90274);
  static const residentPink = Color(0xFFE73895);
}

class BigGreenButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  const BigGreenButton({
    required this.text,
    required this.onPressed,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryGreen, // fill color
        foregroundColor: AppColors.bgColor, // text color
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12), // rounded edges
        ),
        textStyle: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
        padding: const EdgeInsets.symmetric(horizontal: 125, vertical: 20),
      ),
      onPressed: onPressed,
      child: Text(text),
    );
  }
}

class MediumGreenButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  const MediumGreenButton({
    required this.text,
    required this.onPressed,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryGreen, // fill color
        foregroundColor: AppColors.bgColor, // text color
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12), // rounded edges
        ),
        textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
      ),
      onPressed: onPressed,
      child: Text(text),
    );
  }
}

class InputField extends StatelessWidget {
  final TextEditingController inputController;
  final String label;
  final bool obscuring;
  const InputField({
    super.key,
    required this.inputController,
    required this.label,
    required this.obscuring,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: inputController,
      obscureText: obscuring,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.black),
        hintStyle: const TextStyle(color: Colors.grey),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(
            color: AppColors.primaryGreen,
            width: 2.0,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Colors.green, width: 2.0),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

class InteractionTextButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;
  final IconData icon;

  const InteractionTextButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () {
        onPressed;
      },
      icon: Icon(icon, color: AppColors.primaryGreen),
      label: Text(label),
      style: TextButton.styleFrom(textStyle: const TextStyle(fontSize: 15)),
    );
  }
}

class MediumTextButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  const MediumTextButton({
    super.key,
    required this.text,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        textStyle: const TextStyle(fontSize: 20),
        foregroundColor: AppColors.primaryGreen, // text color
      ),
      onPressed: () {
        onPressed;
      },
      child: Text(text),
    );
  }
}

class ActionButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  const ActionButton({super.key, required this.onPressed, required this.icon});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: onPressed,
      splashColor: AppColors.primaryGreen,
      backgroundColor: AppColors.bgColor,
      child: Icon(icon, color: AppColors.primaryGreen),
    );
  }
}

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    scaffoldBackgroundColor: Colors.white,

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.primaryGreen),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryGreen,
        side: const BorderSide(color: AppColors.primaryGreen, width: 2.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),

    //  AppBar  theme
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primaryGreen,
      titleTextStyle: TextStyle(
        color: AppColors.bgColor,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      iconTheme: IconThemeData(color: AppColors.bgColor),
      elevation: 2,
    ),

    // BottomNavigationBar  theme
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.bgColor,
      selectedItemColor: AppColors.primaryGreen,
      unselectedItemColor: Colors.grey,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
    ),
  );
}
