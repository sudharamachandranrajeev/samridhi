/// Asset classes the planner allocates across.
///
/// Capital-market assumptions below are **generic, synthetic, long-run
/// illustrative figures** (not market data, not a forecast). They exist so the
/// optimiser has deterministic inputs; the forecasting layer may tilt them.
/// Every surface that shows them must carry [modelDisclosure].
enum AssetClass {
  equity('Equities', 0.070, 0.16),
  bonds('Bonds', 0.035, 0.06),
  property('Property / REITs', 0.060, 0.14),
  gold('Gold / commodities', 0.030, 0.15),
  cash('Cash', 0.020, 0.005);

  const AssetClass(this.label, this.expectedReturn, this.volatility);

  final String label;

  /// Annual expected (arithmetic) return, illustrative.
  final double expectedReturn;

  /// Annual standard deviation, illustrative.
  final double volatility;
}

/// Illustrative correlation matrix, indexed by [AssetClass.index].
const List<List<double>> defaultCorrelations = [
  //  eq    bond  prop  gold  cash
  [1.00, 0.10, 0.70, 0.05, 0.00], // equity
  [0.10, 1.00, 0.25, 0.20, 0.10], // bonds
  [0.70, 0.25, 1.00, 0.10, 0.00], // property
  [0.05, 0.20, 0.10, 1.00, 0.00], // gold
  [0.00, 0.10, 0.00, 0.00, 1.00], // cash
];

const String modelDisclosure =
    'This is a model using illustrative assumptions, not financial advice or '
    'a guarantee. Past and simulated results do not predict future returns.';
