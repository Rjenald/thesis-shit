import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/splash_screen.dart';
import 'services/class_notifications_service.dart';
import 'services/enrollment_service.dart';
import 'services/profile_picture_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize persisted services before the widget tree is built so that
  // data is available on the very first frame.
  await Future.wait([
    ClassNotificationsService().initialize(),
    EnrollmentService().initialize(),
    ProfilePictureService().initialize(),
  ]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ClassNotificationsService()),
        ChangeNotifierProvider(create: (_) => EnrollmentService()),
        ChangeNotifierProvider(create: (_) => ProfilePictureService()),
      ],
      child: MaterialApp(
        title: 'Karaoke App',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: Colors.black,
          fontFamily: 'Roboto',
          // Replace Material 3's zoom-from-center "pop-up" transition with a
          // native right-to-left slide on both Android and iOS.
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: CupertinoPageTransitionsBuilder(),
              TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            },
          ),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
