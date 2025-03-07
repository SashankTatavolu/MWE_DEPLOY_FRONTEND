// // ignore_for_file: avoid_unnecessary_containers

// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:multiwordexpressionworkbench/ui/loginPage.dart';

// void main() {
//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   // This widget is the root of your application.
//   @override
//   Widget build(BuildContext context) {
//     return GetMaterialApp(
//       debugShowCheckedModeBanner: false,
//       theme: ThemeData.light(),
//       home: Scaffold(
//         body: Container(
//           child: const LoginPage(),
//         ),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:multiwordexpressionworkbench/ui/loginPage.dart';
import 'package:multiwordexpressionworkbench/ui/projectDisplayPage.dart';
import 'package:multiwordexpressionworkbench/services/secureStorageService.dart';
import 'package:multiwordexpressionworkbench/ui/register_page.dart';

import 'ui/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Check login status
  bool isLoggedIn = await checkLoginStatus();

  runApp(MyApp(isLoggedIn: isLoggedIn));
}

Future<bool> checkLoginStatus() async {
  // Read the token from secure storage
  String token = await SecureStorage().readSecureData('jwtToken');
  return token != 'No data found!';
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;

  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(),
      initialRoute: isLoggedIn ? '/projects' : '/home',
      getPages: [
        GetPage(name: '/home', page: () => HomePage()),
        GetPage(name: '/login', page: () => LoginPage()),
        GetPage(name: '/projects', page: () => ProjectsPage()),
        GetPage(name: '/register', page: () => RegisterPage()),
      ],
    );
  }
}
