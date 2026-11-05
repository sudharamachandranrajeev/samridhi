import 'dart:math' as math;

/// Forecasting STUB using classical methods only (no ML, no LLM).
///
/// Simple exponential smoothing (SES) with the smoothing constant chosen by
/// minimising one-step squared error. The prediction band comes from the
/// in-sample residual spread and widens with the horizon. Every surface that
/// shows a [Forecast] must show its [confidence], its [TrackRecord] and the
/// model disclosure — it is a model, not a guarantee.
class Forecast {
  const Forecast({
    required this.mean,
    required this.lower,
    required this.upper,
    required this.confidence,
    required this.alpha,
    required this.track,
  });
  final List<double> mean;
  final List<double> lower;
  final List<double> upper;

  /// Nominal coverage of the band, e.g. 0.8.
  final double confidence;
  final double alpha;
  final TrackRecord track;
}

/// Rolling-origin back-test of the forecaster on its own history.
class TrackRecord {
  const TrackRecord({
    required this.trials,
    required this.hits,
    required this.maeModel,
    required this.maeNaive,
  });
  final int trials;

  /// Times the realised value fell inside the predicted band.
  final int hits;
  final double maeModel;

  /// Mean absolute error of the "same as last value" naive forecast.
  final double maeNaive;

  double get hitRate => trials == 0 ? 0 : hits / trials;
}

final _z = {0.8: 1.2816, 0.9: 1.6449, 0.95: 1.96};

/// Normal quantile for the supported confidence levels (0.8, 0.9, 0.95).
double zFor(double confidence) {
  final z = _z[confidence];
  if (z == null) {
    throw ArgumentError('confidence must be one of ${_z.keys.toList()}');
  }
  return z;
}

double _sesLevel(List<double> y, double alpha) {
  var l = y.first;
  for (var i = 1; i < y.length; i++) {
    l = alpha * y[i] + (1 - alpha) * l;
  }
  return l;
}

({double alpha, double sigma}) _fitSes(List<double> y) {
  var bestA = 0.5;
  var bestSse = double.infinity;
  for (var k = 1; k <= 20; k++) {
    final a = k * 0.05;
    var l = y.first;
    var sse = 0.0;
    for (var i = 1; i < y.length; i++) {
      final e = y[i] - l;
      sse += e * e;
      l = a * y[i] + (1 - a) * l;
    }
    if (sse < bestSse) {
      bestSse = sse;
      bestA = a;
    }
  }
  return (alpha: bestA, sigma: math.sqrt(bestSse / (y.length - 1)));
}

/// Moving-average level over the last [window] points (baseline method).
double movingAverage(List<double> y, int window) {
  final w = math.min(window, y.length);
  return y.sublist(y.length - w).reduce((a, b) => a + b) / w;
}

/// Forecasts [horizon] steps ahead. Needs at least [minHistory] points.
Forecast forecastSes(
  List<double> series, {
  int horizon = 1,
  double confidence = 0.8,
  int minHistory = 8,
}) {
  if (series.length < minHistory) {
    throw ArgumentError('need at least $minHistory observations');
  }
  final z = zFor(confidence);
  final fit = _fitSes(series);
  final level = _sesLevel(series, fit.alpha);
  final mean = <double>[], lo = <double>[], hi = <double>[];
  for (var h = 1; h <= horizon; h++) {
    final sd = fit.sigma * math.sqrt(1 + (h - 1) * fit.alpha * fit.alpha);
    mean.add(level);
    lo.add(level - z * sd);
    hi.add(level + z * sd);
  }
  // Rolling-origin track record: refit on a growing prefix, score one step.
  var trials = 0, hits = 0;
  var errModel = 0.0, errNaive = 0.0;
  for (var t = minHistory; t < series.length; t++) {
    final prefix = series.sublist(0, t);
    final f = _fitSes(prefix);
    final l = _sesLevel(prefix, f.alpha);
    final actual = series[t];
    trials++;
    if ((actual - l).abs() <= z * f.sigma) hits++;
    errModel += (actual - l).abs();
    errNaive += (actual - prefix.last).abs();
  }
  return Forecast(
    mean: mean,
    lower: lo,
    upper: hi,
    confidence: confidence,
    alpha: fit.alpha,
    track: TrackRecord(
      trials: trials,
      hits: hits,
      maeModel: trials == 0 ? 0 : errModel / trials,
      maeNaive: trials == 0 ? 0 : errNaive / trials,
    ),
  );
}
