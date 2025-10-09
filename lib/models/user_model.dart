class User {
  final String username;
  final String name;
  final String location;
  final String photoUrl;
  final String token;

  User({
    required this.username,
    required this.name,
    required this.location,
    required this.photoUrl,
    required this.token,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      username: json['username'] ?? '',
      name: json['name'] ?? '',
      location: json['location'] ?? '',
      photoUrl: json['photoUrl'] ?? '',
      token: json['token'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'name': name,
      'location': location,
      'photoUrl': photoUrl,
      'token': token,
    };
  }
} 