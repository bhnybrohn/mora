enum EventType { wedding, owambe, naming, funeral, birthday, other }

enum EventPrivacy { public, private }

enum EventStatus { active, revealed, archived }

enum EventTier { free, standard, premium }

class Event {
  final String id;
  final String ownerUserId;
  final String name;
  final String location;
  final EventType eventType;
  final EventPrivacy privacy;
  final DateTime startsAt;
  final DateTime endsAt;
  final DateTime revealAt;
  final EventTier tier;
  final EventStatus status;
  final int guestCount;
  final int photoCount;
  final DateTime createdAt;

  Event({
    required this.id,
    required this.ownerUserId,
    required this.name,
    this.location = '',
    required this.eventType,
    required this.privacy,
    required this.startsAt,
    required this.endsAt,
    required this.revealAt,
    required this.tier,
    required this.status,
    required this.guestCount,
    required this.photoCount,
    required this.createdAt,
  });

  factory Event.fromJson(Map<String, dynamic> json) => Event(
        id: json['id'] as String,
        ownerUserId: json['owner_user_id'] as String,
        name: json['name'] as String,
        location: (json['location'] as String?) ?? '',
        eventType: EventType.values.byName(json['event_type'] as String),
        privacy: EventPrivacy.values.byName(json['privacy'] as String),
        startsAt: DateTime.parse(json['starts_at'] as String),
        endsAt: DateTime.parse(json['ends_at'] as String),
        revealAt: DateTime.parse(json['reveal_at'] as String),
        tier: EventTier.values.byName(json['tier'] as String),
        status: EventStatus.values.byName(json['status'] as String),
        guestCount: (json['guest_count'] as int?) ?? 0,
        photoCount: (json['photo_count'] as int?) ?? 0,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'location': location,
        'event_type': eventType.name,
        'privacy': privacy.name,
        'starts_at': startsAt.toIso8601String(),
        'ends_at': endsAt.toIso8601String(),
        'reveal_at': revealAt.toIso8601String(),
        'tier': tier.name,
      };
}
