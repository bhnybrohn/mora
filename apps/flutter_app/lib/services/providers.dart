import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/event.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'events_service.dart';
import 'guests_service.dart';
import 'locations_service.dart';
import 'me_service.dart';
import 'photos_service.dart';
import 'sponsors_service.dart';

/// Bumped whenever the user is hard signed-out (refresh failed, no recovery
/// possible). The app's root listens to this and routes back to /welcome.
final sessionExpiredProvider = StateProvider<int>((ref) => 0);

/// Single shared Dio-backed API client. Auth header set here is reused by
/// every other service since they all hold a reference to this same client.
/// The 401 interceptor is wired by [authServiceProvider] below — kept out of
/// here so we don't form a circular reference (auth needs apiClient; the
/// interceptor needs auth — putting both edges through providers confuses
/// Dart's type inference).
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final authServiceProvider = Provider<AuthService>((ref) {
  final client = ref.watch(apiClientProvider);
  final service = AuthService(client);

  // Hook the 401 refresh interceptor now that both pieces exist. Done inside
  // this provider (instead of inside apiClientProvider) so apiClientProvider
  // doesn't itself depend on authServiceProvider — that's the cycle that
  // breaks `Provider<ApiClient>` inference.
  client.onUnauthorized = (err) async {
    final ok = await service.refresh();
    if (!ok) {
      // Bump the counter so the app root routes back to /welcome.
      ref.read(sessionExpiredProvider.notifier).state++;
    }
    return ok;
  };

  return service;
});

final eventsServiceProvider = Provider<EventsService>((ref) {
  return EventsService(ref.watch(apiClientProvider));
});

final photosServiceProvider = Provider<PhotosService>((ref) {
  return PhotosService(ref.watch(apiClientProvider));
});

final meServiceProvider = Provider<MeService>((ref) {
  return MeService(ref.watch(apiClientProvider));
});

final sponsorsServiceProvider = Provider<SponsorsService>((ref) {
  return SponsorsService(ref.watch(apiClientProvider));
});

final guestsServiceProvider = Provider<GuestsService>((ref) {
  return GuestsService(ref.watch(apiClientProvider));
});

final locationsServiceProvider = Provider<LocationsService>((ref) {
  return LocationsService();
});

final guestsForEventProvider =
    FutureProvider.family.autoDispose<List<GuestSummary>, String>((ref, eventId) {
  return ref.watch(guestsServiceProvider).listForEvent(eventId);
});

/// Sponsors for a specific event. Invalidate after create/update/delete to
/// refresh. autoDispose so navigating away cleans up.
final sponsorsForEventProvider =
    FutureProvider.family.autoDispose<List<Sponsor>, String>((ref, eventId) {
  return ref.watch(sponsorsServiceProvider).listForEvent(eventId);
});

/// Whether a JWT was found in secure storage at app boot.
/// Drives the initial route: signed in → /films, otherwise → /welcome.
final sessionRestoredProvider = FutureProvider<bool>((ref) async {
  await ref.read(authServiceProvider).restoreSession();
  return ref.read(authServiceProvider).hasSession();
});

/// Async list of the signed-in host's films. Invalidate after a successful
/// create/archive to refresh.
final myFilmsProvider = FutureProvider.autoDispose<List<Event>>((ref) async {
  return ref.watch(eventsServiceProvider).listMine();
});

/// In-progress film-creation draft. The FilmType screen sets a type, the
/// FilmDetails screen sets the rest, the "Create film" button reads this and
/// POSTs. Lives across screens via Riverpod rather than route extras so we
/// don't lose state on a back-and-forth.
class FilmDraft {
  final EventType? type;
  final String name;
  final String location;
  final String reveal; // 'during' | 'after' | 'delay'
  final int frames;
  /// Wall-clock start of the event, including the hour the doors open.
  /// We derive `ends_at` as +10h and `reveal_at` from `reveal` at submit.
  final DateTime startsAt;

  const FilmDraft({
    this.type,
    this.name = '',
    this.location = 'Lagos',
    this.reveal = 'after',
    this.frames = 24,
    required this.startsAt,
  });

  FilmDraft copyWith({
    EventType? type,
    String? name,
    String? location,
    String? reveal,
    int? frames,
    DateTime? startsAt,
  }) =>
      FilmDraft(
        type: type ?? this.type,
        name: name ?? this.name,
        location: location ?? this.location,
        reveal: reveal ?? this.reveal,
        frames: frames ?? this.frames,
        startsAt: startsAt ?? this.startsAt,
      );
}

class FilmDraftController extends StateNotifier<FilmDraft> {
  FilmDraftController() : super(FilmDraft(startsAt: _nextSaturdayAt3pm()));

  void setType(EventType t) => state = state.copyWith(type: t);
  void setName(String n) => state = state.copyWith(name: n);
  void setLocation(String loc) => state = state.copyWith(location: loc);
  void setReveal(String r) => state = state.copyWith(reveal: r);
  void setFrames(int n) => state = state.copyWith(frames: n);
  void setStartsAt(DateTime d) => state = state.copyWith(startsAt: d);
  void reset() => state = FilmDraft(startsAt: _nextSaturdayAt3pm());
}

DateTime _nextSaturdayAt3pm() {
  // Default to the next Saturday at 3pm — the modal owambe slot. Most events
  // anchor around that window; the user can shift it via the date+time picker.
  final now = DateTime.now();
  final daysUntilSat = (DateTime.saturday - now.weekday + 7) % 7;
  return DateTime(now.year, now.month, now.day + (daysUntilSat == 0 ? 7 : daysUntilSat), 15);
}

final filmDraftProvider =
    StateNotifierProvider<FilmDraftController, FilmDraft>((_) => FilmDraftController());
