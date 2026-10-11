import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:math_log/core/theme/app_theme.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({Key? key}) : super(key: key);

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  bool _isLoading = false;
  String _statusText = '';

  int _parseInt(dynamic value, {int defaultValue = 1}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is num) return value.toInt();
    final str = value.toString().trim();
    return int.tryParse(str) ?? defaultValue;
  }

  Future<void> _importCSV() async {
    setState(() {
      _isLoading = true;
      _statusText = 'ファイルを選択中...';
    });

    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        setState(() {
          _isLoading = false;
          _statusText = '';
        });
        return;
      }

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        throw StateError('ファイルの読み込みに失敗しました（データがありません）。');
      }

      setState(() {
        _statusText = 'CSVデータを解析中...';
      });

      final csvString = utf8.decode(bytes);
      final List<List<dynamic>> rows = const CsvToListConverter().convert(csvString);

      if (rows.length <= 1) {
        throw StateError('CSVファイルにデータ行が含まれていません。');
      }

      setState(() {
        _statusText = 'Firestoreへインポート中...';
      });

      WriteBatch batch = FirebaseFirestore.instance.batch();
      int counter = 0;
      int totalImported = 0;

      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.length < 10) continue; // 10カラム未満の行をスキップ

        final String questionId = row[0].toString().trim();
        if (questionId.isEmpty) continue;

        final String chapterSection = row[1].toString().trim();
        final String questionNumberAndLabel = row[2].toString().trim();
        final String source = row[3].toString().trim();
        final String unitId = row[4].toString().trim();
        final int knowledgeLv = _parseInt(row[5]);
        final int strategyLv = _parseInt(row[6]);
        final int calculationLv = _parseInt(row[7]);
        final int readingLv = _parseInt(row[8]);
        final int difficultyTag = _parseInt(row[9]);

        final data = {
          'Question_ID': questionId,
          '章・セクション': chapterSection,
          '問題番号・表記': questionNumberAndLabel,
          '収録元': source,
          'Unit_ID': unitId,
          '知識Lv': knowledgeLv,
          '方針Lv': strategyLv,
          '計算Lv': calculationLv,
          '読解Lv': readingLv,
          '難易度タグ': difficultyTag,
        };

        final docRef = FirebaseFirestore.instance.collection('questions').doc(questionId);
        batch.set(docRef, data);
        counter++;
        totalImported++;

        if (counter >= 500) {
          setState(() {
            _statusText = '$totalImported 件を書き込み中...';
          });
          await batch.commit();
          batch = FirebaseFirestore.instance.batch();
          counter = 0;
        }
      }

      if (counter > 0) {
        await batch.commit();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.greenAccent),
                const SizedBox(width: 12),
                Text('$totalImported件の問題を追加しました！'),
              ],
            ),
            backgroundColor: AppTheme.surfaceColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: Color(0xFF334155)),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error importing CSV: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.redAccent),
                const SizedBox(width: 12),
                Expanded(child: Text('インポートエラー: $e')),
              ],
            ),
            backgroundColor: AppTheme.surfaceColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: Color(0xFF334155)),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusText = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('管理者メニュー'),
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Card(
                color: AppTheme.surfaceColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: const BorderSide(color: Color(0xFF334155), width: 1.5),
                ),
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.cloud_upload_rounded,
                          color: AppTheme.primaryColor,
                          size: 48,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        '問題CSVデータの一括取り込み',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '1行目をヘッダーとする10カラム形式のCSVを選択し、Firestoreの questions コレクションへ書き込みます。',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                      if (_isLoading) ...[
                        const SizedBox(height: 32),
                        const CircularProgressIndicator(color: AppTheme.primaryColor),
                        const SizedBox(height: 16),
                        Text(
                          _statusText,
                          style: const TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Opacity(
                opacity: _isLoading ? 0.6 : 1.0,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: _isLoading ? null : AppTheme.primaryGradient,
                    color: _isLoading ? const Color(0xFF1E293B) : null,
                    boxShadow: _isLoading
                        ? null
                        : [
                            BoxShadow(
                              color: AppTheme.primaryColor.withOpacity(0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _importCSV,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'CSVファイルを選択してインポート',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
