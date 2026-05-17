import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'config/theme.dart';
import 'screens/album/album_screen.dart';
import 'screens/album/photo_viewer_screen.dart';
import 'screens/auth/otp_verify_screen.dart';
import 'screens/auth/phone_auth_screen.dart';
import 'screens/diaspora/diaspora_screen.dart';
import 'screens/diaspora/diaspora_share_screen.dart';
import 'screens/host/edit_film_screen.dart';
import 'screens/host/guests_screen.dart';
import 'screens/guest/camera_screen.dart';
import 'screens/guest/guest_splash_screen.dart';
import 'screens/host/event_detail_screen.dart';
import 'screens/host/film_details_screen.dart';
import 'screens/host/film_type_screen.dart';
import 'screens/host/films_list_screen.dart';
import 'screens/host/qr_share_screen.dart';
import 'screens/host/welcome_screen.dart';
import 'screens/reveal/develop_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/sponsors/sponsor_form_screen.dart';
import 'screens/sponsors/sponsors_manage_screen.dart';
import 'screens/sponsors/sponsors_screen.dart';
import 'services/sponsors_service.dart' show Sponsor;
import 'services/providers.dart';
import 'widgets/ui_atoms.dart';

GoRouter _buildRouter({required bool signedIn}) {
  return GoRouter(
    initialLocation: signedIn ? '/films' : '/welcome',
    routes: [
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: '/auth/phone', builder: (_, _) => const PhoneAuthScreen()),
      GoRoute(
        path: '/auth/otp',
        builder: (_, state) {
          final phone = state.extra is String ? state.extra as String : '';
          return OtpVerifyScreen(phone: phone);
        },
      ),
      GoRoute(path: '/films', builder: (_, _) => const FilmsListScreen()),
      GoRoute(path: '/film-type', builder: (_, _) => const FilmTypeScreen()),
      GoRoute(path: '/film-details', builder: (_, _) => const FilmDetailsScreen()),
      GoRoute(
        path: '/qr-share',
        builder: (_, state) {
          final id = state.extra is String ? state.extra as String : '';
          return QRShareScreen(eventId: id);
        },
      ),
      GoRoute(
        path: '/events/:id/detail',
        builder: (_, state) => EventDetailScreen(eventId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/guest-splash', builder: (_, _) => const GuestSplashScreen()),
      GoRoute(
        path: '/camera',
        builder: (_, state) {
          final entry = state.extra is CameraEntry ? state.extra as CameraEntry : null;
          if (entry == null) {
            // Defensive: deep link without an entry payload — bounce home.
            return const _Bounce();
          }
          return CameraScreen(entry: entry);
        },
      ),
      GoRoute(path: '/develop', builder: (_, _) => const DevelopScreen()),
      GoRoute(
        path: '/album',
        builder: (_, state) {
          final id = state.extra is String ? state.extra as String : '';
          return AlbumScreen(eventId: id);
        },
      ),
      GoRoute(
        path: '/photo-viewer',
        builder: (_, state) {
          final args = state.extra as PhotoViewerArgs?;
          if (args == null) return const _Bounce();
          return PhotoViewerScreen(args: args);
        },
      ),
      GoRoute(path: '/sponsors', builder: (_, _) => const SponsorsScreen()),
      GoRoute(
        path: '/films/:id/sponsors',
        builder: (_, state) => SponsorsManageScreen(eventId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/films/:id/sponsors/new',
        builder: (_, state) => SponsorFormScreen(
          eventId: state.pathParameters['id']!,
          existing: state.extra is Sponsor ? state.extra as Sponsor : null,
        ),
      ),
      GoRoute(
        path: '/films/:id/guests',
        builder: (_, state) => GuestsScreen(eventId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/films/:id/edit',
        builder: (_, state) => EditFilmScreen(eventId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/films/:id/diaspora',
        builder: (_, state) => DiasporaShareScreen(eventId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/diaspora', builder: (_, _) => const DiasporaScreen()),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
    ],
  );
}

class MoraApp extends ConsumerStatefulWidget {
  const MoraApp({super.key});

  @override
  ConsumerState<MoraApp> createState() => _MoraAppState();
}

class _MoraAppState extends ConsumerState<MoraApp> {
  GoRouter? _router;

  @override
  Widget build(BuildContext context) {
    // Route to /welcome whenever the session-expired counter bumps. Listening
    // here means it works wherever the user is in the app at the time.
    ref.listen<int>(sessionExpiredProvider, (prev, next) {
      if (next > (prev ?? 0)) {
        _router?.go('/welcome');
      }
    });

    final session = ref.watch(sessionRestoredProvider);
    return session.when(
      loading: () => const _Splash(),
      error: (_, _) => MaterialApp(
        title: 'Mora',
        theme: moraTheme(),
        debugShowCheckedModeBanner: false,
        home: const _Splash(),
      ),
      data: (signedIn) {
        // Build the router once per session decision so go() calls in the
        // listener above hit a real instance.
        _router ??= _buildRouter(signedIn: signedIn);
        return MaterialApp.router(
          title: 'Mora',
          theme: moraTheme(),
          routerConfig: _router!,
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MoraColors.bgBase,
      body: const Center(child: MoraMark(size: 36, color: MoraColors.textPrimary)),
    );
  }
}

/// Fallback widget for /camera deep-linked without an entry payload. Pushes
/// the user back to /films on first frame so they don't end up stuck.
class _Bounce extends StatefulWidget {
  const _Bounce();

  @override
  State<_Bounce> createState() => _BounceState();
}

class _BounceState extends State<_Bounce> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go('/films');
    });
  }

  @override
  Widget build(BuildContext context) => const _Splash();
}
