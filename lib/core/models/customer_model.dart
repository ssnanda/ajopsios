/// GET /ops/customers row shape (format_ops_customer_row in
/// class-ajcore-rest-api.php). The web detail view has 8+ panels (payments,
/// Stripe charges, local ledger, profile/1583 docs, files...) — this mobile
/// client deliberately covers the pragmatic subset: identity, portal status
/// + quick actions, active subscriptions, recent service requests. Full
/// billing/document management stays a web-only task.
class Customer {
  final String stripeCustomerId;
  final String customerNumber;
  final String email;
  final String name;
  final String phone;
  final String description;
  final String address;
  final String
  portalStatus; // active | disabled | archived | without_portal_login
  final bool enabledPortal;
  final List<String>
  serviceTypes; // active subscription / local-contract service names

  const Customer({
    required this.stripeCustomerId,
    required this.customerNumber,
    required this.email,
    required this.name,
    required this.phone,
    required this.description,
    required this.address,
    required this.portalStatus,
    required this.enabledPortal,
    this.serviceTypes = const [],
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      stripeCustomerId: json['stripe_customer_id'] as String? ?? '',
      customerNumber: json['customer_number']?.toString() ?? '',
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      description: json['description'] as String? ?? '',
      address: _formatAddress(json['address']),
      portalStatus: json['portal_status'] as String? ?? '',
      enabledPortal:
          json['enabled_portal'] == true ||
          json['enabled_portal'].toString() == '1',
      serviceTypes:
          (json['service_types'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  /// AJCore returns address as a structured object ({line1, line2, city, state,
  /// postal_code, country}), not a flat string — this was previously parsed as
  /// `json['address'] as String?`, which throws a TypeError on every row (a Map
  /// isn't a String) and silently crashed the whole customer list into an error
  /// state. Also defensively handles a plain string, in case a row somewhere
  /// stores it that way instead.
  static String _formatAddress(dynamic value) {
    if (value is String) return value;
    if (value is Map) {
      final parts = [
        value['line1'],
        value['line2'],
        value['city'],
        value['state'],
        value['postal_code'],
      ].map((e) => (e ?? '').toString().trim()).where((e) => e.isNotEmpty);
      return parts.join(', ');
    }
    return '';
  }

  String get displayName =>
      name.isNotEmpty ? name : (email.isNotEmpty ? email : stripeCustomerId);

  // Keyed by stripeCustomerId for Riverpod .family caching.
  @override
  bool operator ==(Object other) =>
      other is Customer && other.stripeCustomerId == stripeCustomerId;

  @override
  int get hashCode => stripeCustomerId.hashCode;
}

/// A trimmed view of GET /ops/customers/{id}'s aggregate response — only the
/// fields the mobile detail screen actually shows.
class CustomerDetail {
  final Customer customer;
  final String businessName;
  final String individualName;
  final List<CustomerSubscription> subscriptions;
  final List<CustomerServiceRequestSummary> serviceRequests;

  const CustomerDetail({
    required this.customer,
    required this.businessName,
    required this.individualName,
    required this.subscriptions,
    required this.serviceRequests,
  });

  factory CustomerDetail.fromJson(Map<String, dynamic> json) {
    final customerJson = json['customer'] as Map<String, dynamic>? ?? {};
    return CustomerDetail(
      customer: Customer.fromJson(customerJson),
      businessName: customerJson['business_name'] as String? ?? '',
      individualName: customerJson['individual_name'] as String? ?? '',
      subscriptions: (json['subscriptions'] as List<dynamic>? ?? [])
          .map((e) => CustomerSubscription.fromJson(e as Map<String, dynamic>))
          .toList(),
      serviceRequests: (json['service_requests'] as List<dynamic>? ?? [])
          .map(
            (e) => CustomerServiceRequestSummary.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}

class CustomerSubscription {
  final String id;
  final String status;
  final String priceLabel;

  const CustomerSubscription({
    required this.id,
    required this.status,
    required this.priceLabel,
  });

  factory CustomerSubscription.fromJson(Map<String, dynamic> json) =>
      CustomerSubscription(
        id: json['id']?.toString() ?? '',
        status: json['status'] as String? ?? '',
        priceLabel:
            (json['price_label'] ?? json['product_name'] ?? json['nickname'])
                ?.toString() ??
            'Subscription',
      );
}

class CustomerServiceRequestSummary {
  final int id;
  final String requestNumber;
  final String serviceName;
  final String status;
  final String serviceStatus;

  const CustomerServiceRequestSummary({
    required this.id,
    required this.requestNumber,
    required this.serviceName,
    required this.status,
    required this.serviceStatus,
  });

  factory CustomerServiceRequestSummary.fromJson(Map<String, dynamic> json) =>
      CustomerServiceRequestSummary(
        id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
        requestNumber: json['service_request_number'] as String? ?? '',
        serviceName: json['service_name'] as String? ?? '',
        status: json['status'] as String? ?? '',
        serviceStatus: json['service_status'] as String? ?? '',
      );
}
