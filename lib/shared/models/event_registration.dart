import 'package:cloud_firestore/cloud_firestore.dart';

/// Event registration model for tracking user registrations
class EventRegistration {
  final String id;
  final String eventId;
  final String eventName;
  final String userId;
  final String userName;
  final String userEmail;
  final String userPhone;
  final int numberOfAttendees;
  final String notes;
  final RegistrationStatus status;
  final DateTime registeredAt;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final bool checkedIn;
  final DateTime? checkInTime;
  final Map<String, dynamic>? metadata;

  const EventRegistration({
    required this.id,
    required this.eventId,
    required this.eventName,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.userPhone,
    required this.numberOfAttendees,
    this.notes = '',
    this.status = RegistrationStatus.confirmed,
    required this.registeredAt,
    required this.createdAt,
    this.updatedAt,
    this.cancelledAt,
    this.cancellationReason,
    this.checkedIn = false,
    this.checkInTime,
    this.metadata,
  });

  factory EventRegistration.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return EventRegistration.fromJson({...data, 'id': doc.id});
  }

  factory EventRegistration.fromJson(Map<String, dynamic> json) {
    return EventRegistration(
      id: json['id'] as String,
      eventId: json['eventId'] as String,
      eventName: json['eventName'] as String,
      userId: json['userId'] as String,
      userName: json['userName'] as String,
      userEmail: json['userEmail'] as String,
      userPhone: json['userPhone'] as String,
      numberOfAttendees: json['numberOfAttendees'] as int? ?? 1,
      notes: json['notes'] as String? ?? '',
      status: RegistrationStatus.values.firstWhere(
        (e) => e.name == (json['status'] as String? ?? 'confirmed'),
        orElse: () => RegistrationStatus.confirmed,
      ),
      registeredAt: (json['registeredAt'] as Timestamp).toDate(),
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      updatedAt: json['updatedAt'] != null
          ? (json['updatedAt'] as Timestamp).toDate()
          : null,
      cancelledAt: json['cancelledAt'] != null
          ? (json['cancelledAt'] as Timestamp).toDate()
          : null,
      cancellationReason: json['cancellationReason'] as String?,
      checkedIn: json['checkedIn'] as bool? ?? false,
      checkInTime: json['checkInTime'] != null
          ? (json['checkInTime'] as Timestamp).toDate()
          : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'eventId': eventId,
      'eventName': eventName,
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'userPhone': userPhone,
      'numberOfAttendees': numberOfAttendees,
      'notes': notes,
      'status': status.name,
      'registeredAt': Timestamp.fromDate(registeredAt),
      'createdAt': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      if (cancelledAt != null) 'cancelledAt': Timestamp.fromDate(cancelledAt!),
      if (cancellationReason != null) 'cancellationReason': cancellationReason,
      'checkedIn': checkedIn,
      if (checkInTime != null) 'checkInTime': Timestamp.fromDate(checkInTime!),
      if (metadata != null) 'metadata': metadata,
    };
  }

  EventRegistration copyWith({
    String? id,
    String? eventId,
    String? eventName,
    String? userId,
    String? userName,
    String? userEmail,
    String? userPhone,
    int? numberOfAttendees,
    String? notes,
    RegistrationStatus? status,
    DateTime? registeredAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? cancelledAt,
    String? cancellationReason,
    bool? checkedIn,
    DateTime? checkInTime,
    Map<String, dynamic>? metadata,
  }) {
    return EventRegistration(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      eventName: eventName ?? this.eventName,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      userPhone: userPhone ?? this.userPhone,
      numberOfAttendees: numberOfAttendees ?? this.numberOfAttendees,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      registeredAt: registeredAt ?? this.registeredAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      checkedIn: checkedIn ?? this.checkedIn,
      checkInTime: checkInTime ?? this.checkInTime,
      metadata: metadata ?? this.metadata,
    );
  }

  bool get isActive => status == RegistrationStatus.confirmed;
  bool get isCancelled => status == RegistrationStatus.cancelled;
  bool get isWaitlisted => status == RegistrationStatus.waitlisted;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EventRegistration &&
        other.id == id &&
        other.eventId == eventId &&
        other.userId == userId;
  }

  @override
  int get hashCode => Object.hash(id, eventId, userId);
}

enum RegistrationStatus {
  confirmed,
  waitlisted,
  cancelled,
  checkedIn,
}
