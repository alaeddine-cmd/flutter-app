import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/register.dart';
import 'config.dart';
import 'file.dart';

class LoginPage extends StatelessWidget {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  Future<void> loginUser(BuildContext context) async {
    final String url = '$baseUrl/login';
    final String username = usernameController.text;
    final String password = passwordController.text;

    final Map<String, String> requestBody = {
      'username': username,
      'password': password,
    };

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );

    if (response.statusCode == 200) {
      print('Login successful');

      final responseData = jsonDecode(response.body);
      final userId =
          responseData['userIdVolo']; // Extract the user ID from the response
      final usernameVolo = responseData[
          'usernameVolo']; // Extract the username from the response

      if (userId != null) {
        // Store the user ID and username in local storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userId', userId);
        await prefs.setString('usernameVolo', usernameVolo);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PostListScreen(),
          ),
        );
      } else {
        print('Failed to extract user ID from the response');
        // Handle the case where the user ID is null
      }
    } else {
      // Handle the case of a failed login request
      print('Failed to login: ${response.statusCode}');
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Login Failed'),
            content: Text('Invalid username or password'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text('OK'),
              ),
            ],
          );
        },
      );
    }
  }

  void navigateToRegister(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RegisterPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Login'),
        backgroundColor: Colors.deepOrange,
      ),
      backgroundColor: Colors.grey[200],
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: usernameController,
              decoration: InputDecoration(
                labelText: 'Username',
                labelStyle: TextStyle(
                    color: Colors
                        .deepOrange), // Change label (hint) color to deep orange
                fillColor: Colors.white,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  borderSide: BorderSide(color: Colors.deepOrange),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  borderSide: BorderSide(color: Colors.deepOrange),
                ),
              ),
            ),
            SizedBox(height: 16.0),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(
                labelText: 'Password',
                labelStyle: TextStyle(
                    color: Colors
                        .deepOrange), // Change label (hint) color to deep orange
                fillColor: Colors.white,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  borderSide: BorderSide(color: Colors.deepOrange),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  borderSide: BorderSide(color: Colors.deepOrange),
                ),
              ),
              obscureText: true,
            ),
            SizedBox(height: 24.0),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  loginUser(context);
                },
                style: ElevatedButton.styleFrom(
                  primary: Colors.deepOrange,
                  onPrimary: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: 48.0,
                    vertical: 16.0,
                  ),
                ),
                child: Text(
                  'Login',
                  style: TextStyle(fontSize: 18.0),
                ),
              ),
            ),
            SizedBox(height: 16.0),
            GestureDetector(
              onTap: () {
                navigateToRegister(context);
              },
              child: Text(
                'Don\'t have an account? Register here',
                style: TextStyle(
                  color: Colors.deepOrange,
                  decoration: TextDecoration.underline,
                  fontSize: 16.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
