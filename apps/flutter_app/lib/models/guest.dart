enum JoinRequestStatus { pending, approved, rejected }

class Guest {
  final String id;
  final String eventId;
  final String displayName;
  final String? phone;
  final DateTime joinedAt;
  final DateTime? kickedAt;
  final int photoCount;

  Guest({
    required this.id,
    required this.eventId,
    required this.displayName,
    this.phone,
    required this.joinedAt,
    this.kickedAt,
    this.photoCount = 0,
  });

  factory Guest.fromJson(Map<String, dynamic> json) => Guest(
    id: json['id'],
    eventId: json['event_id'],
    displayName: json['display_name'],
    phone: json['phone'],
    joinedAt: DateTime.parse(json['joined_at']),
    kickedAt: json['kicked_at'] != null ? DateTime.parse(json['kicked_at']) : null,
    photoCount: json['photo_count'] ?? 0,
  );
}

class JoinRequest {
  final String id;
  final String eventId;
  final String displayName;
  final String? phone;
  final JoinRequestStatus status;
  final DateTime requestedAt;

  JoinRequest({
    required this.id,
    required this.eventId,
    required this.displayName,
    this.phone,
    required this.status,
    required this.requestedAt,
  });

  factory JoinRequest.fromJson(Map<String, dynamic> json) => JoinRequest(
    id: json['id'],
    eventId: json['event_id'],
    displayName: json['display_name'],
    phone: json['phone'],
    status: JoinRequestStatus.values.byName(json['status']),
    requestedAt: DateTime.parse(json['requested_at']),
  );
}
