class PrinterModel {
  final String id;
  final String name;
  final String ipAddress;
  final int port;
  final List<String> assignedAreas; // e.g., ['Cashier', 'Kitchen', 'Bar']
  final bool isDefault; // Agar true bo'lsa, tanlanmagan joylar uchun ishlatiladi

  PrinterModel({
    required this.id,
    required this.name,
    required this.ipAddress,
    this.port = 9100,
    required this.assignedAreas,
    this.isDefault = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'ipAddress': ipAddress,
    'port': port,
    'assignedAreas': assignedAreas,
    'isDefault': isDefault,
  };

  factory PrinterModel.fromJson(Map<String, dynamic> json) => PrinterModel(
    id: json['id'],
    name: json['name'],
    ipAddress: json['ipAddress'],
    port: json['port'] ?? 9100,
    assignedAreas: List<String>.from(json['assignedAreas'] ?? []),
    isDefault: json['isDefault'] ?? false,
  );
}
