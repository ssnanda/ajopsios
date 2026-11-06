/// Community > unit > owners directory (AJCore HOA extension, /ops/hoa/*).
String _s(dynamic v) => v?.toString() ?? '';
int _i(dynamic v) => v is num ? v.toInt() : int.tryParse(_s(v)) ?? 0;

class HoaCommunity {
  final String id;
  final String name;
  final int units;
  final int owners;
  final int vacant;
  final int violations;
  const HoaCommunity({required this.id, required this.name, required this.units, required this.owners, required this.vacant, required this.violations});

  factory HoaCommunity.fromJson(Map<String, dynamic> j) => HoaCommunity(
        id: _s(j['id']),
        name: _s(j['name']),
        units: _i(j['units']),
        owners: _i(j['owners']),
        vacant: _i(j['vacant']),
        violations: _i(j['violations']),
      );

  double get occupancy => units == 0 ? 0 : (units - vacant) / units;
}

class HoaOwner {
  final int id;
  final String name;
  final String email;
  final String phone;
  final String mailingAddress;
  final bool emailOk;
  final String startDate;
  final String endDate;
  final String notes;
  const HoaOwner({required this.id, required this.name, required this.email, required this.phone, required this.mailingAddress, required this.emailOk, required this.startDate, required this.endDate, required this.notes});

  factory HoaOwner.fromJson(Map<String, dynamic> j) => HoaOwner(
        id: _i(j['id']),
        name: _s(j['name']),
        email: _s(j['email']),
        phone: _s(j['phone']),
        mailingAddress: _s(j['mailing_address']),
        emailOk: j['email_ok'] != false,
        startDate: _s(j['start_date']),
        endDate: _s(j['end_date']),
        notes: _s(j['notes']),
      );

  bool get isCurrent => endDate.isEmpty;
}

class HoaUnitSummary {
  final int id;
  final String unit;
  final String address;
  final List<HoaOwner> owners;
  final int previousCount;
  final int violations;
  const HoaUnitSummary({required this.id, required this.unit, required this.address, required this.owners, required this.previousCount, required this.violations});

  factory HoaUnitSummary.fromJson(Map<String, dynamic> j) => HoaUnitSummary(
        id: _i(j['id']),
        unit: _s(j['unit']),
        address: _s(j['address']),
        owners: ((j['owners'] as List?) ?? const []).map((e) => HoaOwner.fromJson(e as Map<String, dynamic>)).toList(),
        previousCount: _i(j['previous_count']),
        violations: _i(j['violations']),
      );
}

class HoaViolation {
  final int requestId;
  final String number;
  final String title;
  final String status;
  final String statusLabel;
  final String createdAt;
  final String ownersAtTime;
  const HoaViolation({required this.requestId, required this.number, required this.title, required this.status, required this.statusLabel, required this.createdAt, required this.ownersAtTime});

  factory HoaViolation.fromJson(Map<String, dynamic> j) => HoaViolation(
        requestId: _i(j['request_id']),
        number: _s(j['number']),
        title: _s(j['title']),
        status: _s(j['status']),
        statusLabel: _s(j['status_label']),
        createdAt: _s(j['created_at']),
        ownersAtTime: _s(j['owners_at_time']),
      );
}

class HoaUnitDetail {
  final int id;
  final String unit;
  final String address;
  final String communityName;
  final List<HoaOwner> current;
  final List<HoaOwner> previous;
  final List<HoaViolation> violations;
  const HoaUnitDetail({required this.id, required this.unit, required this.address, required this.communityName, required this.current, required this.previous, required this.violations});

  factory HoaUnitDetail.fromJson(Map<String, dynamic> j) {
    final u = (j['unit'] as Map<String, dynamic>?) ?? const {};
    List<T> list<T>(String k, T Function(Map<String, dynamic>) f) => ((j[k] as List?) ?? const []).map((e) => f(e as Map<String, dynamic>)).toList();
    return HoaUnitDetail(
      id: _i(u['id']),
      unit: _s(u['unit']),
      address: _s(u['address']),
      communityName: _s(u['community_name']),
      current: list('current', HoaOwner.fromJson),
      previous: list('previous', HoaOwner.fromJson),
      violations: list('violations', HoaViolation.fromJson),
    );
  }

  /// Everyone who owned the unit, newest first.
  List<HoaOwner> get history => [...current, ...previous]..sort((a, b) => b.startDate.compareTo(a.startDate));
}
