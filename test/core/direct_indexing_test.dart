import 'package:flutter_test/flutter_test.dart';
import 'package:samridhi/core/direct_indexing.dart';

void main() {
  final u = syntheticUniverse();
  test('universe is deterministic and shaped as asked', () {
    expect(u.stocks, 40);
    expect(u.months, 60);
    expect(syntheticUniverse().monthly[3][5], u.monthly[3][5]);
  });

  test('a threshold nothing can reach harvests nothing and tracks exactly', () {
    final r = simulateDirectIndexing(u, harvestThreshold: 0.99);
    expect(r.harvests, 0);
    expect(r.harvestedLosses, 0);
    expect(r.trackingDifference, closeTo(0, 1e-9));
    expect(r.portfolioValues.last, closeTo(r.indexValues.last, 1e-6));
  });

  test('harvesting realises positive losses and costs some tracking', () {
    final r = simulateDirectIndexing(u);
    expect(r.harvests, greaterThan(0));
    expect(r.harvestedLosses, greaterThan(0));
    expect(r.taxOffsetValue, closeTo(r.harvestedLosses * 0.20, 1e-9));
    expect(r.trackingDifference, greaterThan(0));
    expect(r.portfolioValues.length, r.indexValues.length);
  });
}
