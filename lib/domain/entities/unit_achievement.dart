class UnitAchievement {
  final String id;
  final String name;
  final String category; // e.g. "中学1年", "数学I", "数学A"
  final int stars;       // 0 to 3
  final double progress; // 0.0 to 1.0

  const UnitAchievement({
    required this.id,
    required this.name,
    required this.category,
    required this.stars,
    required this.progress,
  });

  factory UnitAchievement.fromJson(Map<String, dynamic> json) {
    return UnitAchievement(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String? ?? '',
      stars: json['stars'] as int? ?? 1,
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

enum MathUnit {
  u01('U-01', '展開・因数分解と実数', '数学Ⅰ'),
  u02('U-02', '1次不等式と絶対値', '数学Ⅰ'),
  u03('U-03', '恒等式と等式・不等式の証明', '数学Ⅱ'),
  u04('U-04', '複素数と2次方程式', '数学Ⅱ'),
  u05('U-05', '剰余の定理と高次方程式', '数学Ⅱ'),
  u06('U-06', '等差数列と等比数列', '数学B'),
  u07('U-07', 'いろいろな数列とΣ計算', '数学B'),
  u08('U-08', '階差数列と群数列', '数学B'),
  u09('U-09', '漸化式', '数学B'),
  u10('U-10', '数学的帰納法', '数学B'),
  u11('U-11', '2次関数のグラフと最大・最小（基本）', '数学Ⅰ'),
  u12('U-12', '2次関数の最大・最小（場合分け）', '数学Ⅰ'),
  u13('U-13', '2次方程式・不等式と解の配置', '数学Ⅰ'),
  u14('U-14', '指数関数', '数学Ⅱ'),
  u15('U-15', '対数関数', '数学Ⅱ'),
  u16('U-16', '三角関数①：弧度法とグラフ', '数学Ⅱ'),
  u17('U-17', '三角関数②：加法定理と諸公式', '数学Ⅱ'),
  u18('U-18', '三角関数③：合成と方程式・不等式', '数学Ⅱ'),
  u19('U-19', '微分法①：微分係数・導関数・接線', '数学Ⅱ'),
  u20('U-20', '微分法②：関数の増減・最大最小', '数学Ⅱ'),
  u21('U-21', '積分法①：不定積分・定積分の計算', '数学Ⅱ'),
  u22('U-22', '積分法②：定積分と面積', '数学Ⅱ'),
  u23('U-23', '三角比の基本と正弦・余弦定理', '数学Ⅰ'),
  u24('U-24', '図形の計量（面積・空間図形への応用）', '数学Ⅰ'),
  u25('U-25', '三角形と円の性質（平面図形）', '数学A'),
  u26('U-26', '点と直線', '数学Ⅱ'),
  u27('U-27', '円と直線の方程式', '数学Ⅱ'),
  u28('U-28', '軌跡と方程式', '数学Ⅱ'),
  u29('U-29', '不等式の表す領域', '数学Ⅱ'),
  u30('U-30', '平面ベクトルの演算と内積', '数学B'),
  u31('U-31', '平面ベクトルの図形への応用', '数学B'),
  u32('U-32', '空間ベクトルの演算と内積', '数学B'),
  u33('U-33', '空間ベクトルの図形への応用', '数学B'),
  u34('U-34', '複素数平面と極形式', '数学B'),
  u35('U-35', 'ド・モアブルの定理と図形への応用', '数学B'),
  u36('U-36', '2次曲線と極座標', '数学B'),
  u37('U-37', '集合と命題・必要十分条件', '数学Ⅰ'),
  u38('U-38', '順列・円順列・重複順列', '数学A'),
  u39('U-39', '組合せと組分け', '数学A'),
  u40('U-40', '確率の基本と独立な試行', '数学A'),
  u41('U-41', '反復試行と条件付き確率', '数学A'),
  u42('U-42', 'データの分析①：代表値・分散・標準偏差', '数学Ⅰ'),
  u43('U-43', 'データの分析②：相関・散布図・仮説検定', '数学Ⅰ'),
  u44('U-44', '確率分布と期待値', '数学B'),
  u45('U-45', '正規分布と二項分布', '数学B'),
  u46('U-46', '統計的な推測（母平均・母比率の推定）', '数学B'),
  u47('U-47', '整数の性質①：約数・倍数とユークリッドの互除法', '数学A'),
  u48('U-48', '整数の性質②：不定方程式と記数法', '数学A');

  final String id;
  final String name;
  final String category;

  const MathUnit(this.id, this.name, this.category);

  static MathUnit? fromId(String id) {
    for (var u in MathUnit.values) {
      if (u.id == id) return u;
    }
    return null;
  }

  static MathUnit? fromName(String name) {
    for (var u in MathUnit.values) {
      if (u.name == name) return u;
    }
    return null;
  }
}

class UnitClassification {
  static String getSubject(String unitId) {
    final unit = MathUnit.fromId(unitId);
    return unit?.category ?? '数学Ⅰ';
  }
}
