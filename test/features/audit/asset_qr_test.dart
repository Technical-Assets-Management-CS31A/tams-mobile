import 'package:flutter_test/flutter_test.dart';
import 'package:tams_mobile/features/audit/domain/asset_qr.dart';
import 'package:tams_mobile/features/audit/domain/entities/audit_scan.dart';

import '../../helpers/audit_fixtures.dart';

void main() {
  group('parseAssetQr', () {
    test('reads the asset id from a TAMS label', () {
      expect(parseAssetQr('tams:asset:$assetA'), assetA);
    });

    test('accepts a bare UUID', () {
      expect(parseAssetQr(assetA), assetA);
    });

    test('ignores case and surrounding spaces', () {
      expect(parseAssetQr('  TAMS:ASSET:${assetA.toUpperCase()}\n'), assetA);
    });

    for (final raw in [
      '',
      'hello',
      'tams:asset:',
      'tams:asset:not-a-uuid',
      'tams:room:$assetA',
      'https://example.com/$assetA',
      '${assetA}0',
    ]) {
      test('"$raw" is not an asset', () {
        expect(parseAssetQr(raw), isNull);
      });
    }
  });

  group('scanKeyOf', () {
    test('is the asset id for a label or a bare UUID', () {
      expect(scanKeyOf('tams:asset:$assetA'), scanKeyOf(assetA));
    });

    test('is the trimmed text otherwise', () {
      expect(scanKeyOf(' WIFI:S:lab; '), 'WIFI:S:lab;');
    });
  });

  group('localResultOf', () {
    final roster = labRoster();

    test('an asset on the roster is matched', () {
      expect(localResultOf('tams:asset:$assetA', roster), ScanResult.matched);
    });

    test('a valid asset not on the roster is pending', () {
      expect(localResultOf(strayAsset, roster), ScanResult.pending);
    });

    test('anything else is unknown', () {
      expect(localResultOf('PRJ-07', roster), ScanResult.unknown);
    });
  });
}
