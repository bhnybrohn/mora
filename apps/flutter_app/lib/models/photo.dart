class Photo {
  final String id;
  final String eventId;
  final String? guestId;
  final String storageKey;
  final String previewKey;
  final int width;
  final int height;
  final DateTime takenAt;
  final String status;

  Photo({
    required this.id,
    required this.eventId,
    this.guestId,
    required this.storageKey,
    required this.previewKey,
    required this.width,
    required this.height,
    required this.takenAt,
    required this.status,
  });

  factory Photo.fromJson(Map<String, dynamic> json) => Photo(
    id: json['id'],
    eventId: json['event_id'],
    guestId: json['guest_id'],
    storageKey: json['storage_key'],
    previewKey: json['preview_key'],
    width: json['width'],
    height: json['height'],
    takenAt: DateTime.parse(json['taken_at']),
    status: json['status'],
  );
}
