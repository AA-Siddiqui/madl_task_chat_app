import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'auth/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/chat_screen.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AuthService>(
      create: (_) => AuthService(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    return StreamBuilder(
      stream: auth.authStateChanges,
      builder: (_, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          return snapshot.hasData ? ChatScreen() : LoginScreen();
        }
        return Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}
