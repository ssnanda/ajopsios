/// Formats a UTC "Y-m-d H:i:s" (or ISO) string from AJCore in AJCore's configured business
/// timezone — using the plain UTC-offset-in-seconds from siteStatusProvider rather than the
/// device's own local zone (Dart's DateTime.toLocal()), so every staff member sees the same
/// wall-clock time for the same event no matter where they're physically standing. See
/// ApiStatusModel's doc comment for why this is a raw offset rather than an IANA name: no bundled
/// tzdata is needed this way, at the cost of only being exactly right for "now" (acceptable — the
/// offset is refetched via /status, and only actually changes twice a year at DST transitions).
///
/// [offsetSeconds] and [abbr] come from ApiStatusModel (AJCore's /status) — never hardcode Eastern
/// or any other zone here; if AJCore's setting changes, this should follow without a code change.
String formatUtcWithOffset(String mysqlDateTime, int offsetSeconds, String abbr) {
  if (mysqlDateTime.isEmpty) return '—';
  final normalized =
      mysqlDateTime.contains('T') ? mysqlDateTime : mysqlDateTime.replaceFirst(' ', 'T');
  final utc = DateTime.tryParse(normalized.endsWith('Z') ? normalized : '${normalized}Z');
  if (utc == null) return mysqlDateTime;
  // .add() on a UTC DateTime stays UTC — deliberately NOT .toLocal(), which would apply the
  // device's own zone on top of this shift instead of AJCore's.
  final shifted = utc.add(Duration(seconds: offsetSeconds));
  final hour12 = shifted.hour % 12 == 0 ? 12 : shifted.hour % 12;
  final minute = shifted.minute.toString().padLeft(2, '0');
  final ampm = shifted.hour < 12 ? 'AM' : 'PM';
  final abbrSuffix = abbr.isNotEmpty ? ' $abbr' : '';
  return '${shifted.month}/${shifted.day}/${shifted.year}, $hour12:$minute $ampm$abbrSuffix';
}

/// Formats an AJCore "Y-m-d H:i:s" string that's already in the site's business timezone (written
/// via PHP's current_time('mysql') — leads, notes, etc.; NOT the UTC contract Visitor History
/// uses, see formatUtcWithOffset() above for that one). No shifting needed at all here — the wall-
/// clock numbers in the string are already correct, so this just reformats them directly rather
/// than parsing through DateTime (which would apply the device's own zone via .toLocal(), or
/// misread the string as UTC if 'Z' got appended — both wrong for a value that's neither).
String formatSiteLocalDatetime(String mysqlDateTime) {
  if (mysqlDateTime.isEmpty) return '—';
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2})').firstMatch(mysqlDateTime);
  if (match == null) return mysqlDateTime;
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final year = match.group(1)!;
  final hour = int.parse(match.group(4)!);
  final minute = match.group(5)!;
  final hour12 = hour % 12 == 0 ? 12 : hour % 12;
  final ampm = hour < 12 ? 'AM' : 'PM';
  return '$month/$day/$year, $hour12:$minute $ampm';
}
