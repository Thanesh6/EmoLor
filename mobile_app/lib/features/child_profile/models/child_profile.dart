import 'package:flutter/foundation.dart';

/// Model representing a child profile.
/// In the real schema, children are rows in the `profiles` table
/// linked to caregivers via the `family_links` junction table.
@immutable
class ChildProfile {
  final String profileId;
  final String userId;
  final String name;
  final DateTime? dateOfBirth;
  final String? avatarUrl;
  final String? phoneNumber;
  final String role;
  final String? parentPinHash;

  const ChildProfile({
    required this.profileId,
    required this.userId,
    required this.name,
    this.dateOfBirth,
    this.avatarUrl,
    this.phoneNumber,
    this.role = 'child',
    this.parentPinHash,
  });

  /// Derive age from date_of_birth
  int? get age {
    if (dateOfBirth == null) return null;
    final now = DateTime.now();
    int years = now.year - dateOfBirth!.year;
    if (now.month < dateOfBirth!.month ||
        (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
      years--;
    }
    return years;
  }

  /// Factory from a profiles-table JSON row
  factory ChildProfile.fromJson(Map<String, dynamic> json) {
    return ChildProfile(
      profileId: json['profile_id'] as String,
      userId: json['user_id'] as String,
      name: (json['full_name'] as String?) ?? 'Child',
      dateOfBirth: json['date_of_birth'] != null
          ? DateTime.parse(json['date_of_birth'])
          : null,
      avatarUrl: json['avatar_url'] as String?,
      phoneNumber: json['phone_number'] as String?,
      role: (json['role'] as String?) ?? 'child',
      parentPinHash: json['parent_pin_hash'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'profile_id': profileId,
      'user_id': userId,
      'full_name': name,
      'date_of_birth': dateOfBirth?.toIso8601String(),
      'avatar_url': avatarUrl,
      'phone_number': phoneNumber,
      'role': role,
      'parent_pin_hash': parentPinHash,
    };
  }

  ChildProfile copyWith({
    String? profileId,
    String? userId,
    String? name,
    DateTime? dateOfBirth,
    String? avatarUrl,
    String? phoneNumber,
    String? role,
    String? parentPinHash,
  }) {
    return ChildProfile(
      profileId: profileId ?? this.profileId,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role ?? this.role,
      parentPinHash: parentPinHash ?? this.parentPinHash,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChildProfile && other.profileId == profileId;
  }

  @override
  int get hashCode => profileId.hashCode;
}
