import 'dart:convert';

class ClientModel {
  final String id;
  final String storeName;
  final String ownerName;
  final String phone;
  final String city;
  final String address;
  final String email;
  final String hardwareId;
  final DateTime createdAt;

  ClientModel({
    required this.id,
    required this.storeName,
    required this.ownerName,
    required this.phone,
    required this.city,
    this.address = '',
    this.email = '',
    required this.hardwareId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'storeName': storeName,
      'ownerName': ownerName,
      'phone': phone,
      'city': city,
      'address': address,
      'email': email,
      'hardwareId': hardwareId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ClientModel.fromMap(Map<String, dynamic> map) {
    return ClientModel(
      id: map['id'] ?? '',
      storeName: map['storeName'] ?? '',
      ownerName: map['ownerName'] ?? '',
      phone: map['phone'] ?? '',
      city: map['city'] ?? '',
      address: map['address'] ?? '',
      email: map['email'] ?? '',
      hardwareId: map['hardwareId'] ?? '',
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  String toJson() => json.encode(toMap());

  factory ClientModel.fromJson(String source) => ClientModel.fromMap(json.decode(source));
}
