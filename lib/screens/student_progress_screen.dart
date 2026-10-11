import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:math_log/core/theme/app_theme.dart';
import 'package:math_log/domain/entities/unit_achievement.dart';
import 'package:math_log/services/database_service.dart';
import 'package:math_log/services/question_service.dart';
import 'package:math_log/services/workbook_filter_service.dart';
import 'package:math_log/screens/unit_detail_screen.dart';
import 'package:math_log/screens/review_workbook_screen.dart';

class StudentProgressScreen extends StatefulWidget {
  final String studentId;
  final String studentEmail;

  const StudentProgressScreen({
    Key? key,
    required this.studentId,
    required this.studentEmail,
  }) : super(key: key);

  @override
  State<StudentProgressScreen> createState() => _StudentProgressScreenState();
}

class _StudentProgressScreenState extends State<StudentProgressScreen> {
  List<UnitAchievement> _units = [];
  Future<List<UnitAchievement>>? _initFuture;
  bool _initialized = false;
  String _selectedUnitId = 'U-01';

  // Book Selection variables
  List<String> _sources = [];
  String? _selectedSource;

  @override
  void initState() {
    super.initState();
    WorkbookFilterService().activeWorkbooksNotifier.addListener(_onActiveWorkbooksChanged);
  }

  @override
  void dispose() {
    WorkbookFilterService().activeWorkbooksNotifier.removeListener(_onActiveWorkbooksChanged);
    super.dispose();
  }

  void _onActiveWorkbooksChanged() {
    _loadQuestionsAndSources();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initFuture = _loadUnits();
      _initFilterAndLoadQuestions();
      _initialized = true;
    }
  }

  Future<void> _initFilterAndLoadQuestions() async {
    await WorkbookFilterService().init();
    _loadQuestionsAndSources();
  }

  Future<void> _loadQuestionsAndSources() async {
    await QuestionService().loadQuestions(forceReload: true);
    final questions = QuestionService().questions;
    final Set<String> uniqueSourcesSet = {};
    final List<String> sources = [];
    final active = WorkbookFilterService().activeWorkbooksNotifier.value;
    for (var q in questions) {
      if (uniqueSourcesSet.add(q.source) && active.contains(q.source)) {
        sources.add(q.source);
      }
    }
    if (mounted) {
      setState(() {
        _sources = sources;
        if (sources.isEmpty) {
          _selectedSource = null;
        } else if (_selectedSource == null || !sources.contains(_selectedSource)) {
          _selectedSource = sources.first;
        }
      });
    }
  }

  Future<List<UnitAchievement>> _loadUnits() async {
    try {
      final jsonString = await DefaultAssetBundle.of(context).loadString('assets/units.json');
      final List<dynamic> jsonMap = json.decode(jsonString);
      final loadedUnits = jsonMap.map((item) {
        final id = item['id'] as String;
        return UnitAchievement(
          id: id,
          name: item['name'] as String,
          category: UnitClassification.getSubject(id),
          stars: 1,
          progress: 0.0,
        );
      }).toList();

      setState(() {
        _units = loadedUnits;
      });
      return loadedUnits;
    } catch (e) {
      debugPrint('Error loading units: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: DatabaseService().getRatingsStream(uid: widget.studentId),
      builder: (context, ratingsSnapshot) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: DatabaseService().getLogsStream(uid: widget.studentId),
          builder: (context, logsSnapshot) {
            if (ratingsSnapshot.connectionState == ConnectionState.waiting ||
                logsSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryColor),
                ),
              );
            }

            // Parse Ratings
            Map<String, dynamic> ratings = {};
            if (ratingsSnapshot.hasData && ratingsSnapshot.data!.exists) {
              final data = ratingsSnapshot.data!.data();
              ratings = data?['ratings'] as Map<String, dynamic>? ?? {};
            }

            // Parse Logged Questions
            final loggedQuestionIds = logsSnapshot.hasData
                ? logsSnapshot.data!.docs.map((doc) => doc.data()['questionId'] as String).toSet()
                : <String>{};

            return DefaultTabController(
              length: 4,
              child: Scaffold(
                appBar: AppBar(
                  title: Text(
                    widget.studentEmail,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: AppTheme.backgroundColor,
                  elevation: 0,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.history_rounded, color: Colors.white70),
                      tooltip: '生徒の学習履歴',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ReviewWorkbookScreen(studentId: widget.studentId),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                body: SafeArea(
                  child: FutureBuilder<List<UnitAchievement>>(
                    future: _initFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting && _units.isEmpty) {
                        return const Center(
                          child: CircularProgressIndicator(color: AppTheme.primaryColor),
                        );
                      }
                      if (snapshot.hasError) {
                        return const Center(
                          child: Text(
                            '単元データの読み込みに失敗しました',
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        );
                      }

                      return NestedScrollView(
                        key: const PageStorageKey('student_progress_scroll_key'),
                        headerSliverBuilder: (context, innerBoxIsScrolled) {
                          return [
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // 1. Book Progress Tracker (進行中の問題集)
                                    _buildBookProgressCard(loggedQuestionIds),
                                    const SizedBox(height: 16),

                                    // 2. Abilities Radar Chart (Selected Unit ELO representation)
                                    _buildRadarChartContainer(ratings),
                                    const SizedBox(height: 20),

                                    // 3. Title
                                    const Row(
                                      children: [
                                        Text(
                                          '単元別平均レート分析',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                ),
                              ),
                            ),
                            SliverPersistentHeader(
                              pinned: true,
                              delegate: _SliverAppBarDelegate(
                                TabBar(
                                  tabs: const [
                                    Tab(text: '数学Ⅰ'),
                                    Tab(text: '数学A'),
                                    Tab(text: '数学Ⅱ'),
                                    Tab(text: '数学B'),
                                  ],
                                  labelColor: AppTheme.primaryColor,
                                  unselectedLabelColor: Colors.white60,
                                  indicatorColor: AppTheme.primaryColor,
                                  indicatorSize: TabBarIndicatorSize.tab,
                                  indicator: const UnderlineTabIndicator(
                                    borderSide: BorderSide(color: AppTheme.primaryColor, width: 3),
                                    insets: EdgeInsets.symmetric(horizontal: 16),
                                  ),
                                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
                                ),
                              ),
                            ),
                          ];
                        },
                        body: TabBarView(
                          children: [
                            _buildUnitListViewForSubject('数学Ⅰ', ratings),
                            _buildUnitListViewForSubject('数学A', ratings),
                            _buildUnitListViewForSubject('数学Ⅱ', ratings),
                            _buildUnitListViewForSubject('数学B', ratings),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUnitListViewForSubject(String subject, Map<String, dynamic> ratings) {
    final filtered = _units.where((unit) => unit.category == subject).toList();
    if (filtered.isEmpty) {
      return const Center(
        child: Text(
          '単元がありません',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }
    return ListView.builder(
      key: PageStorageKey('student_subject_list_${subject}'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final unit = filtered[index];
        final unitRating = ratings[unit.id] as Map<String, dynamic>? ?? {
          'knowledge': 500,
          'strategy': 500,
          'calculation': 500,
          'reading': 500,
        };
        final int knowledge = (unitRating['knowledge'] as num?)?.toInt() ?? 500;
        final int strategy = (unitRating['strategy'] as num?)?.toInt() ?? 500;
        final int calculation = (unitRating['calculation'] as num?)?.toInt() ?? 500;
        final int reading = (unitRating['reading'] as num?)?.toInt() ?? 500;
        final int avgRate = ((knowledge + strategy + calculation + reading) / 4).round();

        return _buildUnitCard(context, unit, avgRate);
      },
    );
  }

  Widget _buildUnitCard(BuildContext context, UnitAchievement unit, int avgRate) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UnitDetailScreen(
                  unit: unit,
                  allUnits: _units,
                  selectedSource: _selectedSource ?? '',
                  studentId: widget.studentId,
                  isReadOnly: true,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.folder_open_rounded,
                    color: AppTheme.primaryColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${unit.id}: ${unit.name}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '平均レート: $avgRate',
                        style: TextStyle(
                          color: avgRate >= 1500
                              ? Colors.greenAccent
                              : avgRate >= 1300
                                  ? Colors.amberAccent
                                  : Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white38,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBookProgressCard(Set<String> loggedQuestionIds) {
    if (_sources.isEmpty) {
      return Card(
        color: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF334155), width: 1),
        ),
        child: const Padding(
          padding: EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '進行中の問題集',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              Text(
                '表示可能な問題集が設定されていません。',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    final questions = QuestionService().questions;
    final bookQuestions = questions.where((q) => q.source == _selectedSource).toList();
    final completed = bookQuestions.where((q) => loggedQuestionIds.contains(q.id)).length;
    final total = bookQuestions.length;
    final double percent = total == 0 ? 0.0 : completed / total;
    final String percentText = (percent * 100).toStringAsFixed(0);

    return Card(
      color: AppTheme.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF334155), width: 1),
      ),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '進行中の問題集',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedSource,
                  dropdownColor: AppTheme.surfaceColor,
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                  isExpanded: true,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  items: _sources.map((src) {
                    return DropdownMenuItem<String>(
                      value: src,
                      child: Text(
                        src,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedSource = newValue;
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '達成度: $completed / $total 問完了 ($percentText%)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF0F172A),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: percent.clamp(0.0, 1.0),
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: AppTheme.progressGradient,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRadarChartContainer(Map<String, dynamic> ratings) {
    final unitRating = ratings[_selectedUnitId] as Map<String, dynamic>? ?? {
      'knowledge': 500,
      'strategy': 500,
      'calculation': 500,
      'reading': 500,
    };

    final int knowledge = (unitRating['knowledge'] as num?)?.toInt() ?? 500;
    final int strategy = (unitRating['strategy'] as num?)?.toInt() ?? 500;
    final int calculation = (unitRating['calculation'] as num?)?.toInt() ?? 500;
    final int reading = (unitRating['reading'] as num?)?.toInt() ?? 500;

    return _buildRadarChartCard(knowledge, strategy, calculation, reading);
  }

  Widget _buildRadarChartCard(int knowledge, int strategy, int calculation, int reading) {
    return Card(
      color: AppTheme.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF334155), width: 1),
      ),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '単元別能力分析',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_units.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedUnitId,
                              dropdownColor: AppTheme.surfaceColor,
                              icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                              isExpanded: true,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              items: _units.map((unit) {
                                return DropdownMenuItem<String>(
                                  value: unit.id,
                                  child: Text(
                                    '${unit.id}: ${unit.name}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    _selectedUnitId = newValue;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: RadarChart(
                RadarChartData(
                  dataSets: [
                    RadarDataSet(
                      dataEntries: const [
                        RadarEntry(value: 1000),
                        RadarEntry(value: 1000),
                        RadarEntry(value: 1000),
                        RadarEntry(value: 1000),
                      ],
                      borderColor: Colors.transparent,
                      fillColor: Colors.transparent,
                      entryRadius: 0,
                    ),
                    RadarDataSet(
                      dataEntries: const [
                        RadarEntry(value: 1800),
                        RadarEntry(value: 1800),
                        RadarEntry(value: 1800),
                        RadarEntry(value: 1800),
                      ],
                      borderColor: Colors.transparent,
                      fillColor: Colors.transparent,
                      entryRadius: 0,
                    ),
                    RadarDataSet(
                      dataEntries: [
                        RadarEntry(value: knowledge.toDouble()),
                        RadarEntry(value: strategy.toDouble()),
                        RadarEntry(value: calculation.toDouble()),
                        RadarEntry(value: reading.toDouble()),
                      ],
                      borderColor: AppTheme.primaryColor,
                      fillColor: AppTheme.primaryColor.withOpacity(0.2),
                      entryRadius: 4,
                      borderWidth: 2,
                    ),
                  ],
                  getTitle: (index, angle) {
                    switch (index) {
                      case 0:
                        return const RadarChartTitle(text: '知識');
                      case 1:
                        return const RadarChartTitle(text: '方針');
                      case 2:
                        return const RadarChartTitle(text: '計算');
                      case 3:
                        return const RadarChartTitle(text: '読解');
                      default:
                        return const RadarChartTitle(text: '');
                    }
                  },
                  titleTextStyle: const TextStyle(
                     color: Colors.white70,
                     fontSize: 12,
                     fontWeight: FontWeight.bold,
                  ),
                  tickCount: 4,
                  ticksTextStyle: const TextStyle(color: Colors.white30, fontSize: 8),
                  gridBorderData: const BorderSide(color: Color(0xFF334155), width: 1),
                  tickBorderData: const BorderSide(color: Color(0xFF1E293B), width: 1),
                  radarBorderData: const BorderSide(color: Color(0xFF475569), width: 1.5),
                  radarShape: RadarShape.polygon,
                  isMinValueAtCenter: false,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Column(
              children: [
                _buildRatingListItem('知識', knowledge, AppTheme.knowledgeColor),
                const SizedBox(height: 8),
                _buildRatingListItem('方針', strategy, AppTheme.strategyColor),
                const SizedBox(height: 8),
                _buildRatingListItem('計算', calculation, AppTheme.calculationColor),
                const SizedBox(height: 8),
                _buildRatingListItem('読解', reading, AppTheme.readingColor),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingListItem(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Text(
            '${label}レート: $value',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
