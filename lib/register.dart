import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:app/login.dart';
import 'config.dart';

class RegisterPage extends StatelessWidget {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  Future<void> registerUser(BuildContext context) async {
    final String url = '$baseUrl/users';
    final String username = usernameController.text;
    final String password = passwordController.text;

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'username': username, 'password': password}),
    );

    if (response.statusCode == 201) {
      print('Registration successful');
      // Navigate to the login page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginPage()),
      );
    } else {
      print('Failed to register: ${response.statusCode}');
      // Handle registration failure
    }
  }

  void navigateToLogin(BuildContext context) {
    Navigator.pop(context); // Use pop instead of pushReplacement
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Register'),
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
                  borderSide: BorderSide(
                      color: Colors
                          .deepOrange), // Change border color when not focused
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  borderSide: BorderSide(
                      color: Colors
                          .deepOrange), // Change border color when focused
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
                  borderSide: BorderSide(
                      color: Colors
                          .deepOrange), // Change border color when not focused
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  borderSide: BorderSide(
                      color: Colors
                          .deepOrange), // Change border color when focused
                ),
              ),
              obscureText: true,
            ),
            SizedBox(height: 24.0),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  registerUser(context);
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
                  'Register',
                  style: TextStyle(fontSize: 18.0),
                ),
              ),
            ),
            SizedBox(height: 16.0),
            TextButton(
              onPressed: () {
                navigateToLogin(context);
              },
              child: Text(
                'Already have an account? Login',
                style: TextStyle(
                  color: Colors.deepOrange,
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
