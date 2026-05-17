enum PaymentProvider { paystack, flutterwave, stripe }

enum PaymentStatus { pending, completed, failed }

class Payment {
  final String id;
  final String eventId;
  final String userId;
  final PaymentProvider provider;
  final String providerRef;
  final int amount;
  final String currency;
  final PaymentStatus status;
  final DateTime createdAt;

  Payment({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.provider,
    required this.providerRef,
    required this.amount,
    required this.currency,
    required this.status,
    required this.createdAt,
  });

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
    id: json['id'],
    eventId: json['event_id'],
    userId: json['user_id'],
    provider: PaymentProvider.values.byName(json['provider']),
    providerRef: json['provider_ref'],
    amount: json['amount'],
    currency: json['currency'],
    status: PaymentStatus.values.byName(json['status']),
    createdAt: DateTime.parse(json['created_at']),
  );
}
