// Copyright 2022 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart'; // Import the generated options file
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';
import 'home_page.dart';
import 'user_manager.dart';
import 'change_password.dart';
import 'theme_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize your application state
  final appState = ApplicationState();
  await appState.init();

  runApp(ChangeNotifierProvider(
    create: (context) => appState,
    builder: ((context, child) => App()),
  ));
}

void navigateToChangePassword(BuildContext context) {
  // Navigation logic to the Change Password screen
  Navigator.pushNamed(context, '/change-password');
}

// App with live dark mode switching via ThemeController
class App extends StatelessWidget {
  App({super.key});

  @override
  Widget build(BuildContext context) {
    UserManager.instance.fetchAndStoreUserMappings();

    return AnimatedBuilder(
      animation: ThemeController.instance, // listens for setDark() changes
      builder: (context, _) {
        return MaterialApp.router(
          title: 'מועדון הכרמל',
          // Light theme (default)
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
            textTheme: GoogleFonts.robotoTextTheme(
              Theme.of(context).textTheme,
            ),
            visualDensity: VisualDensity.adaptivePlatformDensity,
          ),
          // Dark theme
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Brightness.dark,
            ),
            textTheme: GoogleFonts.robotoTextTheme(
              ThemeData(brightness: Brightness.dark).textTheme,
            ),
            visualDensity: VisualDensity.adaptivePlatformDensity,
          ),
          // Theme mode controlled globally (default = light).
          // Call ThemeController.instance.setDark(true/false) from your drawer toggle.
          themeMode: ThemeController.instance.mode,
          routerConfig: _router,
        );
      },
    );
  }
}

// Add GoRouter configuration outside the App class
final _router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomePage(),
      routes: [
        GoRoute(
          path: 'sign-in',
          builder: (context, state) {
            return SignInScreen(
              providers: [
                EmailAuthProvider(), // Include additional providers as needed
              ],
              actions: [
                ForgotPasswordAction(((context, email) {
                  final uri = Uri(
                    path: '/sign-in/forgot-password',
                    queryParameters: <String, String?>{
                      'email': email,
                    },
                  );
                  context.push(uri.toString());
                })),
                AuthStateChangeAction(((context, state) async {
                  final user = switch (state) {
                    SignedIn s => s.user,
                    UserCreated s => s.credential.user,
                    _ => null
                  };
                  if (user == null) return;

                  if (state is UserCreated) {
                    user.updateDisplayName(user.email!.split('@')[0]);
                  }

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    context.go('/'); // replaces stack cleanly
                  });
                })),
              ],
              footerBuilder: (context, _) {
                return const SizedBox
                    .shrink(); // This hides the registration footer
              },
              showAuthActionSwitch:
                  false, // Hide switch between sign-in and register
            );
          },
          routes: [
            GoRoute(
              path: 'forgot-password',
              builder: (context, state) {
                final arguments = state.uri.queryParameters;
                return ForgotPasswordScreen(
                  email: arguments['email'],
                  headerMaxExtent: 200,
                );
              },
            ),
          ],
        ),
        GoRoute(
          path: 'profile',
          builder: (context, state) {
            return ProfileScreen(
              providers: const [],
              actions: [
                SignedOutAction((context) {
                  context.pushReplacement('/');
                }),
              ],
            );
          },
        ),
        GoRoute(
          path: 'change-password',
          builder: (context, state) => const ChangePasswordScreen(),
        ),
      ],
    ),
  ],
);
// end of GoRouter configuration
