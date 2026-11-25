import 'entities/audit_scan.dart';
import 'entities/roster.dart';

const assetQrPrefix = 'tams:asset:';

final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

String? parseAssetQr(String raw) {
  var value = raw.trim();
  if (value.toLowerCase().startsWith(assetQrPrefix)) {
    value = value.substring(assetQrPrefix.length).trim();
  }
  return _uuid.hasMatch(value) ? value.toLowerCase() : null;
}

String scanKeyOf(String raw) => parseAssetQr(raw) ?? raw.trim();

ScanResult localResultOf(String raw, Roster roster) {
  final assetId = parseAssetQr(raw);
  if (assetId == null) return ScanResult.unknown;
  return roster.item(assetId) == null ? ScanResult.pending : ScanResult.matched;
}
