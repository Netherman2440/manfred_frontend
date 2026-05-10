import '../domain/user_me.dart';

class UserMeResponseDto {
  const UserMeResponseDto({required this.id, required this.name});

  factory UserMeResponseDto.fromJson(Map<String, dynamic> json) {
    return UserMeResponseDto(
      id: json['id'] as String,
      name: json['name'] as String,
    );
  }

  final String id;
  final String name;

  UserMe toDomain() => UserMe(id: id, name: name);
}
