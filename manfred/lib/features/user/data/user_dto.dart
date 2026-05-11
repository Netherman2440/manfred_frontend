import '../domain/user_me.dart';

class UserMeResponseDto {
  const UserMeResponseDto({required this.id, required this.name});

  factory UserMeResponseDto.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    if (id is! String || name is! String) {
      throw const FormatException(
        'Invalid /users/me payload: "id" and "name" must be strings',
      );
    }
    return UserMeResponseDto(id: id, name: name);
  }

  final String id;
  final String name;

  UserMe toDomain() => UserMe(id: id, name: name);
}
