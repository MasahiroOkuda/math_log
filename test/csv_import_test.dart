import 'package:flutter_test/flutter_test.dart';
import 'package:csv/csv.dart';

int parseIntHelper(dynamic value, {int defaultValue = 1}) {
  if (value == null) return defaultValue;
  if (value is int) return value;
  if (value is num) return value.toInt();
  final str = value.toString().trim();
  return int.tryParse(str) ?? defaultValue;
}

void main() {
  group('CSV Parsing and Safe Type Casting Tests', () {
    test('Safe int parser test', () {
      // Test direct integers
      expect(parseIntHelper(3), equals(3));
      
      // Test double conversion
      expect(parseIntHelper(2.8), equals(2));
      
      // Test string integer conversion
      expect(parseIntHelper('4'), equals(4));
      expect(parseIntHelper('  2  '), equals(2));
      
      // Test invalid strings (should fallback to default)
      expect(parseIntHelper('abc'), equals(1));
      expect(parseIntHelper(''), equals(1));
      expect(parseIntHelper(null), equals(1));
      
      // Test custom default value
      expect(parseIntHelper('invalid', defaultValue: 3), equals(3));
    });

    test('CSV list structure and header skipping test', () {
      const csvData = '''Question_ID,章・セクション,問題番号・表記,収録元,Unit_ID,知識Lv,方針Lv,計算Lv,読解Lv,難易度タグ
A-001_1,第01章 数と式,001(1)-(2),全レベル問題集,U-01,1,2,2,1,1
A-002_1,第01章 数と式,002(1),全レベル問題集,U-01,2,abc,3.5,4,5''';

      final List<List<dynamic>> rows = const CsvToListConverter().convert(csvData);
      
      // Should have 3 rows (1 header + 2 data rows)
      expect(rows.length, equals(3));
      
      // First row is header
      expect(rows[0][0], equals('Question_ID'));
      expect(rows[0][9], equals('難易度タグ'));

      // Check second row (index 1)
      final row1 = rows[1];
      expect(row1[0].toString().trim(), equals('A-001_1'));
      expect(row1[1].toString().trim(), equals('第01章 数と式'));
      expect(parseIntHelper(row1[5]), equals(1));
      expect(parseIntHelper(row1[6]), equals(2));
      expect(parseIntHelper(row1[7]), equals(2));
      expect(parseIntHelper(row1[8]), equals(1));
      expect(parseIntHelper(row1[9]), equals(1));

      // Check third row (index 2) with string/double/invalid values
      final row2 = rows[2];
      expect(row2[0].toString().trim(), equals('A-002_1'));
      expect(parseIntHelper(row2[5]), equals(2)); // int
      expect(parseIntHelper(row2[6]), equals(1)); // 'abc' invalid -> 1
      expect(parseIntHelper(row2[7]), equals(3)); // 3.5 double -> 3 (toInt)
      expect(parseIntHelper(row2[8]), equals(4)); // int
      expect(parseIntHelper(row2[9]), equals(5)); // int
    });
  });
}
