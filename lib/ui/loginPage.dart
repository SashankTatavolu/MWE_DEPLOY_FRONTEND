// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:multiwordexpressionworkbench/services/secureStorageService.dart';
import 'package:http/http.dart' as https;
import 'package:multiwordexpressionworkbench/ui/projectDisplayPage.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  Future<bool> _validLogin(String email, String password) async {
    var url =
        Uri.https('www.cfilt.iitb.ac.in', 'annotation_tool_apis/user/login');
    var body = {"email": email, "password": password};
    String bodyJson = jsonEncode(body);

    final response = await https.post(
      url,
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: bodyJson,
    );

    if (response.statusCode == 200) {
      // Parse response
      String jsonString = response.body;
      Map<String, dynamic> jsonResponse = jsonDecode(jsonString);
      // Assuming the response contains accessToken, organisation, role
      String accessToken = jsonResponse['access_token'];
      String organization = jsonResponse['organisation'];
      String role = jsonResponse['role'];

      // Store data in SecureStorage
      await SecureStorage().writeSecureData('jwtToken', accessToken);
      await SecureStorage().writeSecureData('role', role);
      await SecureStorage().writeSecureData('organization', organization);

      return true; // Login successful
    } else {
      return false; // Login failed
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Image.asset(
          "images/logo.png",
        ),
        toolbarHeight: 100,
        leadingWidth: 300,
        backgroundColor: Colors.grey[300],
        title: const Align(
            alignment: Alignment.center,
            child: Text('Multiword Expression Workbench')),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
              ),
            ),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                bool success = await _validLogin(
                    emailController.text, passwordController.text);
                if (success) {
                  // Navigate to the projects page
                  Get.to(const ProjectsPage());
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("Incorrect Email or Password")),
                  );
                }
              },
              child: const Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
}
