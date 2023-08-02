import 'package:flutter/material.dart';
import 'package:app/login.dart';
import 'package:app/register.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/file.dart'; // Import the file.dart
import 'package:app/home.dart'; // Import the file.dart

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Clear shared preferences
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Volo',
      initialRoute: '/login',
      routes: {
        '/login': (context) => LoginPage(),
        '/home': (context) => HomeScreen(),
        '/register': (context) => RegisterPage(),
        '/postList': (context) =>
            PostListScreen(), // Add the PostListScreen route
      },
    );
  }
}
