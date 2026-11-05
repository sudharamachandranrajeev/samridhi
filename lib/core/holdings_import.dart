import 'dart:convert';

import 'asset_class.dart';

/// Read-only import of holdings from a file the user chooses (for example an
/// export from Artha). Samridhi only reads the file; nothing is ever written
/// back to the source.
///
/// JSON (`format` must be `samridhi-holdings-v1`):
/// `{"format":"samridhi-holdings-v1","accounts":[{"name":"ISA",
/// "wrapper":"isa","holdings":[{"name":"Global equity fund",
/// "assetClass":"equity","value":12000}]}]}`
///
/// CSV with header `account,wrapper,holding,assetClass,value`.
const holdingsFormat = 'samridhi-holdings-v1';
const maxImportBytes = 2 * 1024 * 1024;
const _wrappers = {'isa', 'pension', 'taxable', 'cash'};

class ImportedHolding {
  const ImportedHolding(this.name, this.assetClass, this.value);
  final String name;
  final AssetClass assetClass;
  final double value;
}

class ImportedAccount {
  ImportedAccount(this.name, this.wrapper);
  final String name;
  final String wrapper;
  final List<ImportedHolding> holdings = [];

  /// Stable id: importing the same file twice updates instead of duplicating.
  String get id => 'imp:${_slug(name)}';
  double get total => holdings.fold(0.0, (a, h) => a + h.value);
}

class ImportResult {
  ImportResult(this.accounts, this.problems);
  final List<ImportedAccount> accounts;

  /// Rows skipped, with the reason. Never contains the file's raw values.
  final List<String> problems;
  int get holdingCount => accounts.fold(0, (a, x) => a + x.holdings.length);
}

String _slug(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-|-$'), '');

String holdingId(ImportedAccount a, ImportedHolding h) =>
    '${a.id}:${_slug(h.name)}';

AssetClass? _class(String s) {
  final k = s.trim().toLowerCase();
  for (final c in AssetClass.values) {
    if (c.name == k) return c;
  }
  return switch (k) {
    'equities' || 'stock' || 'stocks' => AssetClass.equity,
    'bond' || 'fixed income' => AssetClass.bonds,
    'reit' || 'reits' || 'real estate' => AssetClass.property,
    'commodity' || 'commodities' => AssetClass.gold,
    _ => null,
  };
}

/// Parses [bytes] as JSON or CSV (decided by the first non-space character).
/// Throws [FormatException] if the file is not usable at all; bad rows are
/// skipped and reported in [ImportResult.problems].
ImportResult parseHoldings(List<int> bytes) {
  if (bytes.length > maxImportBytes) {
    throw const FormatException('File is too large to be a holdings export.');
  }
  final text = utf8.decode(bytes).trim();
  if (text.isEmpty) throw const FormatException('The file is empty.');
  return text.startsWith('{') ? _fromJson(text) : _fromCsv(text);
}

class _Builder {
  final byName = <String, ImportedAccount>{};
  final problems = <String>[];

  void add(
    String where,
    String account,
    String wrapper,
    String holding,
    String cls,
    Object? value,
  ) {
    final c = _class(cls);
    final v = value is num
        ? value.toDouble()
        : double.tryParse('$value'.trim());
    final w = wrapper.trim().toLowerCase();
    if (account.trim().isEmpty || holding.trim().isEmpty) {
      problems.add('$where: missing account or holding name');
    } else if (c == null) {
      problems.add('$where: unknown asset class');
    } else if (v == null || !v.isFinite || v < 0 || v > 1e12) {
      problems.add('$where: value is not a sensible amount');
    } else if (w.isNotEmpty && !_wrappers.contains(w)) {
      problems.add('$where: unknown wrapper');
    } else {
      byName
          .putIfAbsent(
            account.trim(),
            () => ImportedAccount(account.trim(), w.isEmpty ? 'taxable' : w),
          )
          .holdings
          .add(ImportedHolding(holding.trim(), c, v));
    }
  }

  ImportResult done() {
    if (byName.isEmpty) {
      throw FormatException(
        problems.isEmpty
            ? 'No holdings found.'
            : 'No valid holdings. First problem: ${problems.first}',
      );
    }
    return ImportResult(byName.values.toList(), problems);
  }
}

ImportResult _fromJson(String text) {
  final Object? root;
  try {
    root = jsonDecode(text);
  } on FormatException {
    throw const FormatException('Not valid JSON.');
  }
  if (root is! Map || root['format'] != holdingsFormat) {
    throw const FormatException('Not a $holdingsFormat file.');
  }
  final b = _Builder();
  final accounts = root['accounts'];
  if (accounts is! List) throw const FormatException('No "accounts" list.');
  for (var i = 0; i < accounts.length; i++) {
    final a = accounts[i];
    if (a is! Map || a['holdings'] is! List) {
      b.problems.add('account ${i + 1}: malformed');
      continue;
    }
    final hs = a['holdings'] as List;
    for (var j = 0; j < hs.length; j++) {
      final h = hs[j];
      if (h is! Map) {
        b.problems.add('account ${i + 1}, holding ${j + 1}: malformed');
        continue;
      }
      b.add(
        'account ${i + 1}, holding ${j + 1}',
        '${a['name'] ?? ''}',
        '${a['wrapper'] ?? ''}',
        '${h['name'] ?? ''}',
        '${h['assetClass'] ?? ''}',
        h['value'],
      );
    }
  }
  return b.done();
}

List<String> _csvLine(String line) {
  final out = <String>[];
  final cur = StringBuffer();
  var quoted = false;
  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (quoted) {
      if (ch == '"' && i + 1 < line.length && line[i + 1] == '"') {
        cur.write('"');
        i++;
      } else if (ch == '"') {
        quoted = false;
      } else {
        cur.write(ch);
      }
    } else if (ch == '"') {
      quoted = true;
    } else if (ch == ',') {
      out.add(cur.toString());
      cur.clear();
    } else {
      cur.write(ch);
    }
  }
  return out..add(cur.toString());
}

ImportResult _fromCsv(String text) {
  final lines = const LineSplitter().convert(text);
  final head = _csvLine(lines.first)
      .map((s) => s.trim().toLowerCase())
      .toList();
  const need = ['account', 'wrapper', 'holding', 'assetclass', 'value'];
  final idx = [for (final n in need) head.indexOf(n)];
  if (idx.contains(-1)) {
    throw const FormatException(
      'CSV header must be: account,wrapper,holding,assetClass,value',
    );
  }
  final b = _Builder();
  for (var i = 1; i < lines.length; i++) {
    if (lines[i].trim().isEmpty) continue;
    final f = _csvLine(lines[i]);
    String at(int k) => idx[k] < f.length ? f[idx[k]] : '';
    b.add('row ${i + 1}', at(0), at(1), at(2), at(3), at(4));
  }
  return b.done();
}
