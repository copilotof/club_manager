// lib/data/models/hall_model.dart
class HallModel {
  final int? id;
  final String name;
  final String? address;
  final String? phone;

  HallModel({this.id, required this.name, this.address, this.phone});

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'address': address, 'phone': phone};
  }

  factory HallModel.fromMap(Map<String, dynamic> map) {
    return HallModel(
      id: map['id'],
      name: map['name'],
      address: map['address'],
      phone: map['phone'],
    );
  }
}
