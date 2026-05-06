// Copyright 2022 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // Import the generated options file
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:firebase_ui_localizations/firebase_ui_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';
import 'home_page.dart';
import 'server_time.dart';
import 'user_manager.dart';
import 'change_password.dart';
import 'theme_controller.dart';
import 'tv_screen.dart';
import 'tv_message_editor.dart';
import 'booking_tokens.dart';
import 'widgets/bouncing_ball_loader.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Heebo .ttf files are bundled as Flutter assets under google_fonts/ — never
  // reach for the network. With runtime fetching off, a missing weight throws
  // loudly instead of silently falling back, which is what we want.
  GoogleFonts.config.allowRuntimeFetching = false;

  // Show the bouncing-ball splash immediately. Block the splash only on what
  // the first real frame strictly needs (Firebase platform init + auth
  // listener). Everything else loads in the background while the ball bounces
  // / after the home page mounts — UserManager self-heals on first lookup,
  // and ServerTime falls back to device time until the network anchor lands.
  final splashStart = DateTime.now();
  runApp(const _BootSplash());

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  unawaited(ServerTime.init().timeout(
    const Duration(seconds: 4),
    onTimeout: () {},
  ));
  unawaited(UserManager.instance.fetchAndStoreUserMappings());

  final appState = ApplicationState();
  await appState.init();

  // Hold the splash for a minimum time so the bouncing ball is actually seen.
  // If bootstrap took longer than this, no extra wait.
  const minSplash = Duration(seconds: 3);
  final elapsed = DateTime.now().difference(splashStart);
  if (elapsed < minSplash) {
    await Future.delayed(minSplash - elapsed);
  }

  runApp(ChangeNotifierProvider(
    create: (context) => appState,
    builder: ((context, child) => App()),
  ));
}

class _BootSplash extends StatelessWidget {
  const _BootSplash();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ThemeController.instance.mode,
      locale: const Locale('he'),
      supportedLocales: const [Locale('he'), Locale('en')],
      home: Builder(
        builder: (ctx) {
          final tokens = BookingTokens.of(ctx);
          return Scaffold(
            backgroundColor: tokens.bg,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'מועדון הכרמל',
                    style: TextStyle(
                      color: tokens.clay,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const BouncingBallLoader(size: 36, showBaseline: true),
                  const SizedBox(height: 8),
                  Text(
                    'טוען…',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      color: tokens.ink2,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

void navigateToChangePassword(BuildContext context) {
  // Navigation logic to the Change Password screen
  Navigator.pushNamed(context, '/change-password');
}

ThemeData buildLightTheme() {
  const tokens = BookingTokens.light;
  final base = ThemeData(
    brightness: Brightness.light,
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: tokens.clay,
      brightness: Brightness.light,
      primary: tokens.clay,
      surface: tokens.surface,
    ),
    scaffoldBackgroundColor: tokens.bg,
    visualDensity: VisualDensity.adaptivePlatformDensity,
    extensions: const [tokens],
  );

  final text = GoogleFonts.heeboTextTheme(base.textTheme).apply(
    bodyColor: tokens.ink,
    displayColor: tokens.ink,
  );

  return base.copyWith(textTheme: text);
}

ThemeData buildDarkTheme() {
  const tokens = BookingTokens.dark;
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: tokens.clay,
      brightness: Brightness.dark,
      primary: tokens.clay,
      surface: tokens.surface,
    ),
    scaffoldBackgroundColor: tokens.bg,
    visualDensity: VisualDensity.adaptivePlatformDensity,
    extensions: const [tokens],
  );

  final text = GoogleFonts.heeboTextTheme(base.textTheme).apply(
    bodyColor: tokens.ink,
    displayColor: tokens.ink,
  );

  return base.copyWith(textTheme: text);
}

// Re-anchors [ServerTime] when the app returns to the foreground (handles
// long-backgrounded tabs / suspended apps where the monotonic Stopwatch may
// have frozen) and on a slow periodic timer to correct hardware-clock drift
// over multi-day kiosk sessions.
class _ServerTimeKeeper extends StatefulWidget {
  final Widget child;
  const _ServerTimeKeeper({required this.child});

  @override
  State<_ServerTimeKeeper> createState() => _ServerTimeKeeperState();
}

class _ServerTimeKeeperState extends State<_ServerTimeKeeper>
    with WidgetsBindingObserver {
  Timer? _periodic;
  StreamSubscription<User?>? _authSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _periodic = Timer.periodic(
      const Duration(hours: 1),
      (_) => ServerTime.refresh(),
    );
    // When a user signs in, re-anchor via Firestore (replacing any anchor
    // the unauthenticated JSON/HEAD fallback set during cold boot).
    _authSub = FirebaseAuth.instance.userChanges().listen((user) {
      if (user != null) ServerTime.refresh();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _periodic?.cancel();
    _authSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ServerTime.refresh();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// App with live dark mode switching via ThemeController
class App extends StatelessWidget {
  App({super.key});

  @override
  Widget build(BuildContext context) {
    return _ServerTimeKeeper(
      child: AnimatedBuilder(
      animation: ThemeController.instance, // listens for setDark() changes
      builder: (context, _) {
        return MaterialApp.router(
          title: 'מועדון הכרמל',
          theme: buildLightTheme(), // <-- use helper
          darkTheme: buildDarkTheme(), // <-- use helper
          themeMode: ThemeController.instance.mode,
          routerConfig: _router,
          locale: const Locale('he'),
          supportedLocales: const [Locale('he'), Locale('en')],
          localizationsDelegates: [
            FirebaseUILocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],

          // Optional: disable theme animation completely (prevents any lerp)
          // themeAnimationDuration: Duration.zero,
          // themeAnimationCurve: Curves.linear,
        );
      },
    ),
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
        GoRoute(
          path: 'tv',
          builder: (context, state) => const TvScreen(),
        ),
        GoRoute(
          path: 'tv-message',
          builder: (context, state) => const TvMessageEditor(),
        ),
      ],
    ),
  ],
);
// end of GoRouter configuration
