import 'dart:math' as math;

/// Result of a mean-variance optimisation.
class MvoResult {
  const MvoResult(this.weights, this.expectedReturn, this.volatility);
  final List<double> weights;
  final double expectedReturn;
  final double volatility;
}

/// Builds a covariance matrix from volatilities and a correlation matrix.
List<List<double>> covarianceFrom(List<double> vols, List<List<double>> corr) {
  final n = vols.length;
  return List.generate(
    n,
    (i) => List.generate(n, (j) => corr[i][j] * vols[i] * vols[j]),
  );
}

double portfolioReturn(List<double> w, List<double> mu) {
  var r = 0.0;
  for (var i = 0; i < w.length; i++) {
    r += w[i] * mu[i];
  }
  return r;
}

double portfolioVariance(List<double> w, List<List<double>> cov) {
  var v = 0.0;
  for (var i = 0; i < w.length; i++) {
    for (var j = 0; j < w.length; j++) {
      v += w[i] * w[j] * cov[i][j];
    }
  }
  return v;
}

/// Projects [v] onto {w : sum(w)=1, lo<=w<=hi} (Euclidean), by bisection on
/// the shift tau in w_i = clamp(v_i - tau, lo_i, hi_i).
List<double> projectBoxSimplex(
  List<double> v,
  List<double> lo,
  List<double> hi,
) {
  final n = v.length;
  double sumAt(double tau) {
    var s = 0.0;
    for (var i = 0; i < n; i++) {
      s += (v[i] - tau).clamp(lo[i], hi[i]);
    }
    return s;
  }

  var a = -10.0, b = 10.0;
  // sumAt is non-increasing in tau: widen until the root is bracketed.
  while (sumAt(a) < 1 && a > -1e6) {
    a *= 2;
  }
  while (sumAt(b) > 1 && b < 1e6) {
    b *= 2;
  }
  for (var k = 0; k < 100; k++) {
    final m = (a + b) / 2;
    if (sumAt(m) > 1) {
      a = m;
    } else {
      b = m;
    }
  }
  final tau = (a + b) / 2;
  return [for (var i = 0; i < n; i++) (v[i] - tau).clamp(lo[i], hi[i])];
}

/// Long-only, box-constrained mean-variance optimiser:
///   maximise  w'mu - (lambda/2) w'Σw   s.t. sum(w)=1, lo<=w<=hi.
///
/// Convex; solved by projected gradient with a 1/L step. Larger
/// [riskAversion] (lambda) gives a safer portfolio.
MvoResult optimise({
  required List<double> mu,
  required List<List<double>> cov,
  required double riskAversion,
  List<double>? lower,
  List<double>? upper,
  int maxIter = 20000,
  double tol = 1e-12,
}) {
  final n = mu.length;
  final lo = lower ?? List.filled(n, 0.0);
  final hi = upper ?? List.filled(n, 1.0);
  if (lo.fold<double>(0, (a, b) => a + b) > 1 + 1e-9 ||
      hi.fold<double>(0, (a, b) => a + b) < 1 - 1e-9) {
    throw ArgumentError('Infeasible weight bounds');
  }
  // Gradient Lipschitz constant <= lambda * trace(cov) for PSD cov.
  var trace = 0.0;
  for (var i = 0; i < n; i++) {
    trace += cov[i][i];
  }
  final step = 1 / (riskAversion * trace + 1e-12);
  var w = projectBoxSimplex(List.filled(n, 1 / n), lo, hi);
  for (var it = 0; it < maxIter; it++) {
    final next = projectBoxSimplex(
      [
        for (var i = 0; i < n; i++)
          w[i] +
              step *
                  (mu[i] -
                      riskAversion *
                          [for (var j = 0; j < n; j++) cov[i][j] * w[j]]
                              .fold<double>(0, (a, b) => a + b)),
      ],
      lo,
      hi,
    );
    var diff = 0.0;
    for (var i = 0; i < n; i++) {
      diff += (next[i] - w[i]).abs();
    }
    w = next;
    if (diff < tol) break;
  }
  return MvoResult(
    w,
    portfolioReturn(w, mu),
    math.sqrt(portfolioVariance(w, cov)),
  );
}

/// Points along the efficient frontier, from very safe (lambda 50) to
/// aggressive (lambda 0.5).
List<MvoResult> efficientFrontier({
  required List<double> mu,
  required List<List<double>> cov,
  List<double>? lower,
  List<double>? upper,
  int points = 12,
}) {
  return [
    for (var k = 0; k < points; k++)
      optimise(
        mu: mu,
        cov: cov,
        riskAversion: 50 * math.pow(0.5 / 50, k / (points - 1)).toDouble(),
        lower: lower,
        upper: upper,
        maxIter: 5000,
      ),
  ];
}
