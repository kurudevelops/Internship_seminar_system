import 'package:flutter/material.dart';
import 'features/auth/presentation/role_gate_screen.dart';

void main() {
  runApp(const InternshipSeminarApp());
}

class InternshipSeminarApp extends StatelessWidget {
  const InternshipSeminarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Internship Seminar System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E3A8A),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade300),
          ),
        ),
      ),
      home: const RoleGateScreen(),
    );
  }
}