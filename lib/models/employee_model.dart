class EmployeeModel {
  final int id;
  final String employeeName;
  final String? employeePhone;
  final int employeeType; // 0: Kitchen, 1: Service, 3: Driver, 4: Manager

  const EmployeeModel({
    required this.id,
    required this.employeeName,
    this.employeePhone,
    required this.employeeType,
  });

  factory EmployeeModel.fromMap(Map<String, dynamic> map) {
    return EmployeeModel(
      id: (map['id'] as int?) ?? 0,
      employeeName: map['employee_name'] as String? ?? '',
      employeePhone: map['employee_phone'] as String?,
      employeeType: (map['employee_type'] as int?) ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id > 0) 'id': id,
      'employee_name': employeeName,
      'employee_phone': employeePhone,
      'employee_type': employeeType,
    };
  }

  String get typeName {
    switch (employeeType) {
      case 0:
        return 'Kitchen';
      case 1:
        return 'Service';
      case 3:
        return 'Driver';
      case 4:
        return 'Manager';
      default:
        return 'Staff';
    }
  }

  EmployeeModel copyWith({
    int? id,
    String? employeeName,
    String? employeePhone,
    int? employeeType,
  }) {
    return EmployeeModel(
      id: id ?? this.id,
      employeeName: employeeName ?? this.employeeName,
      employeePhone: employeePhone ?? this.employeePhone,
      employeeType: employeeType ?? this.employeeType,
    );
  }
}
