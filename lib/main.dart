import 'package:field_work_2/Professors/professorsLandingPage.dart';
import 'package:field_work_2/Students/studentsLandingPage.dart';
import 'package:field_work_2/login/login.dart';
import 'package:field_work_2/login/signup.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://iiddrittxgeqephfulqk.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlpZGRyaXR0eGdlcWVwaGZ1bHFrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI5OTExNDgsImV4cCI6MjA4ODU2NzE0OH0.0eyvo-RdBHkhhPkpaGgDTrIpuZ-VFniMRfXAsiS_YLQ',
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      initialRoute: '/',
      routes: {
        '/signup': (context) => const Signup(),
        '/Login': (context) => const Login(),
        '/professors-landing': (context) => const Professorslandingpage(),
        '/students-landing': (context) => const Studentslandingpage(),
      },
      theme: ThemeData(
        appBarTheme: AppBarTheme(
          foregroundColor: Colors.white,
          backgroundColor: Colors.black,
          elevation: 0,
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.black,
          surface: Colors.grey[50], // The main background color
        ),
      ),
      home: const Login(),
    );
  }
}
