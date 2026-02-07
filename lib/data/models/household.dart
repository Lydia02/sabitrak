import 'package:cloud_firestore/cloud_firestore.dart';

class Household {
  final String id;
  final String name;
  final List<String> members;
  final String inviteCode;
  final DateTime createdAt;
  final String createdBy;

  Household({
    required this.id,
    required this.name,
    required this.members,
    required this.inviteCode,
    required this.createdAt,
    required this.createdBy,
  });

  factory Household.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Household(
      id: doc.id,
      name: data['name'] ?? '',
      members: List<String>.from(data['members'] ?? []),
      inviteCode: data['inviteCode'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      createdBy: data['createdBy'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'members': members,
      'inviteCode': inviteCode,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
    };
  }
}
