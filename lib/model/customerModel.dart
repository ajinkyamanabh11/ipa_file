class CustomerModel {
  final String customerId;
  final String customerName;
  final String customerEmail;

  CustomerModel({
    required this.customerId,
    required this.customerName,
    required this.customerEmail,
  });

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'customerName': customerName,
      'customerEmail': customerEmail,
    };
  }

  factory CustomerModel.fromMap(Map<String, dynamic> map) {
    return CustomerModel(
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      customerEmail: map['customerEmail'] ?? '',
    );
  }

  @override
  String toString() {
    return 'CustomerModel(customerId: $customerId, customerName: $customerName, customerEmail: $customerEmail)';
  }
}