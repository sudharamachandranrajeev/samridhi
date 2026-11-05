import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:samridhi/core/asset_class.dart';
import 'package:samridhi/core/holdings_import.dart';

List<int> b(String s) => utf8.encode(s);

void main() {
  test('CSV: groups by account, maps aliases, skips bad rows', () {
    final r = parseHoldings(
      b(
        'account,wrapper,holding,assetClass,value\n'
        'My ISA,isa,"Global, equity",stocks,12000\n'
        'My ISA,isa,Gilts,bond,3000.5\n'
        'Bank,cash,Savings,cash,500\n'
        'Bank,cash,Weird,crypto,10\n'
        'Bank,cash,Neg,cash,-5\n',
      ),
    );
    expect(r.accounts.map((a) => a.name), ['My ISA', 'Bank']);
    expect(r.accounts.first.holdings.first.name, 'Global, equity');
    expect(r.accounts.first.holdings.first.assetClass, AssetClass.equity);
    expect(r.accounts.first.total, closeTo(15000.5, 1e-9));
    expect(r.problems, hasLength(2));
    expect(r.problems.join(), isNot(contains('crypto')));
  });

  test('JSON format parses and ids are stable', () {
    final json = jsonEncode({
      'format': holdingsFormat,
      'accounts': [
        {
          'name': 'Pension',
          'wrapper': 'pension',
          'holdings': [
            {'name': 'Index fund', 'assetClass': 'equity', 'value': 100},
          ],
        },
      ],
    });
    final a = parseHoldings(b(json)).accounts.single;
    final a2 = parseHoldings(b(json)).accounts.single;
    expect(a.id, a2.id);
    expect(a.id, 'imp:pension');
    expect(holdingId(a, a.holdings.single), 'imp:pension:index-fund');
  });

  test('unusable files are rejected with a message', () {
    for (final bad in [
      '',
      '{"format":"other","accounts":[]}',
      '{not json',
      'a,b\n1,2',
      'account,wrapper,holding,assetClass,value\nX,isa,Y,nope,1',
    ]) {
      expect(() => parseHoldings(b(bad)), throwsFormatException, reason: bad);
    }
    expect(
      () => parseHoldings(List.filled(maxImportBytes + 1, 65)),
      throwsFormatException,
    );
  });
}
