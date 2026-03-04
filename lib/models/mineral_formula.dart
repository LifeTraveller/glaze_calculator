import 'chemical_formula.dart';

/// 矿物式（由化学式组成的复杂矿物）
class MineralFormula {
  final String name;
  final Map<ChemicalFormula, double> composition; // 化学式组成（摩尔比）
  final Map<ChemicalFormula, double>? _firedComposition; // 烧成后的氧化物组成（可选）

  const MineralFormula(this.name, this.composition, [this._firedComposition]);

  /// 获取烧成后的氧化物组成
  /// 如果未指定，返回原始组成（适用于纯氧化物矿物）
  Map<ChemicalFormula, double> get firedComposition => _firedComposition ?? composition;

  /// 计算摩尔质量（根据化学式组成自动计算）
  double get molarMass {
    double mass = 0.0;
    for (var entry in composition.entries) {
      mass += entry.key.molarMass * entry.value;
    }
    return mass;
  }

  /// 生成矿物式字符串（如 K₂O·Al₂O₃·6SiO₂）
  String get formulaString {
    final parts = <String>[];
    for (var entry in composition.entries) {
      final ratio = entry.value;
      if (ratio == 1.0) {
        parts.add(entry.key.name);
      } else if (ratio == ratio.toInt()) {
        // 整数摩尔比
        parts.add('${ratio.toInt()}${entry.key.name}');
      } else {
        // 小数摩尔比（保留1位小数）
        parts.add('${ratio.toStringAsFixed(1)}${entry.key.name}');
      }
    }
    return parts.join('·');
  }

  /// 计算质量百分比
  Map<String, double> calculateMassPercentages() {
    // 计算总质量
    double totalMass = 0.0;
    final masses = <String, double>{};

    for (var entry in composition.entries) {
      final mass = entry.value * entry.key.molarMass;
      masses[entry.key.name] = mass;
      totalMass += mass;
    }

    // 计算百分比
    final percentages = <String, double>{};
    for (var entry in masses.entries) {
      percentages[entry.key] = (entry.value / totalMass) * 100;
    }

    return percentages;
  }

  @override
  String toString() => '$name: $formulaString (${molarMass.toStringAsFixed(2)} g/mol)';

  // === 常见矿物化学式 ===

  // 钾长石: K₂O·Al₂O₃·6SiO₂
  static final MineralFormula potashFeldspar = MineralFormula(
    '钾长石',
    {ChemicalFormula.k2o: 1.0, ChemicalFormula.al2o3: 1.0, ChemicalFormula.sio2: 6.0},
  );

  // 钠长石: Na₂O·Al₂O₃·6SiO₂
  static final MineralFormula sodaFeldspar = MineralFormula(
    '钠长石',
    {ChemicalFormula.na2o: 1.0, ChemicalFormula.al2o3: 1.0, ChemicalFormula.sio2: 6.0},
  );

  // 高岭土（理论组成）: Al₂O₃·2SiO₂·2H₂O → 烧成后: Al₂O₃·2SiO₂
  static final MineralFormula kaolin = MineralFormula(
    '高岭土',
    {ChemicalFormula.al2o3: 1.0, ChemicalFormula.sio2: 2.0, ChemicalFormula.h2o: 2.0},
    {ChemicalFormula.al2o3: 1.0, ChemicalFormula.sio2: 2.0},  // 结合水蒸发
  );

  // 滑石: 3MgO·4SiO₂·H₂O → 烧成后: 3MgO·4SiO₂
  static final MineralFormula talc = MineralFormula(
    '滑石',
    {ChemicalFormula.mgo: 3.0, ChemicalFormula.sio2: 4.0, ChemicalFormula.h2o: 1.0},
    {ChemicalFormula.mgo: 3.0, ChemicalFormula.sio2: 4.0},  // 结合水蒸发
  );

  // 锂辉石: Li₂O·Al₂O₃·4SiO₂
  static final MineralFormula spodumene = MineralFormula(
    '锂辉石',
    {ChemicalFormula.li2o: 1.0, ChemicalFormula.al2o3: 1.0, ChemicalFormula.sio2: 4.0},
  );

  // 锆英石: ZrO₂·SiO₂
  static final MineralFormula zircon = MineralFormula(
    '锆英石',
    {ChemicalFormula.zro2: 1.0, ChemicalFormula.sio2: 1.0},
  );

  // 硼砂十水合物: Na₂O·2B₂O₃·10H₂O → 烧成后: Na₂O·2B₂O₃
  static final MineralFormula borax = MineralFormula(
    '硼砂',
    {ChemicalFormula.na2o: 1.0, ChemicalFormula.b2o3: 2.0, ChemicalFormula.h2o: 10.0},
    {ChemicalFormula.na2o: 1.0, ChemicalFormula.b2o3: 2.0},  // 结合水蒸发
  );

  // 白云石: CaCO₃·MgCO₃ → 烧成后: CaO·MgO
  static final MineralFormula dolomite = MineralFormula(
    '白云石',
    {ChemicalFormula.caco3: 1.0, ChemicalFormula.mgco3: 1.0},
    {ChemicalFormula.cao: 1.0, ChemicalFormula.mgo: 1.0},  // 碳酸盐分解
  );

  // 石灰石: CaCO₃ → 烧成后: CaO
  static final MineralFormula limestone = MineralFormula(
    '石灰石',
    {ChemicalFormula.caco3: 1.0},
    {ChemicalFormula.cao: 1.0},  // 碳酸盐分解
  );

  // 方解石: CaCO₃ → 烧成后: CaO（与石灰石化学成分相同，但晶体结构不同）
  static final MineralFormula calcite = MineralFormula(
    '方解石',
    {ChemicalFormula.caco3: 1.0},
    {ChemicalFormula.cao: 1.0},  // 碳酸盐分解
  );

  // 硅石/石英: SiO₂
  static final MineralFormula quartz = MineralFormula(
    '石英',
    {ChemicalFormula.sio2: 1.0},
  );

  // 氧化铝: Al₂O₃
  static final MineralFormula alumina = MineralFormula(
    '氧化铝',
    {ChemicalFormula.al2o3: 1.0},
  );

  // 碳酸钡: BaCO₃ → 烧成后: BaO
  static final MineralFormula witherite = MineralFormula(
    '碳酸钡',
    {ChemicalFormula.baco3: 1.0},
    {ChemicalFormula.bao: 1.0},  // 碳酸盐分解
  );

  // 碳酸锂: Li₂CO₃ → 烧成后: Li₂O
  static final MineralFormula lithiumCarbonate = MineralFormula(
    '碳酸锂',
    {ChemicalFormula.li2co3: 1.0},
    {ChemicalFormula.li2o: 1.0},  // 碳酸盐分解
  );

  // 碳酸镁: MgCO₃ → 烧成后: MgO
  static final MineralFormula magnesite = MineralFormula(
    '碳酸镁',
    {ChemicalFormula.mgco3: 1.0},
    {ChemicalFormula.mgo: 1.0},  // 碳酸盐分解
  );

  // 氧化锌: ZnO
  static final MineralFormula zincOxide = MineralFormula(
    '氧化锌',
    {ChemicalFormula.zno: 1.0},
  );

  // 氧化钛: TiO₂
  static final MineralFormula titaniumDioxide = MineralFormula(
    '氧化钛',
    {ChemicalFormula.tio2: 1.0},
  );

  // 氧化锡: SnO₂
  static final MineralFormula tinOxide = MineralFormula(
    '氧化锡',
    {ChemicalFormula.sno2: 1.0},
  );

  // 氧化锆: ZrO₂
  static final MineralFormula zirconiumDioxide = MineralFormula(
    '氧化锆',
    {ChemicalFormula.zro2: 1.0},
  );

  // 氧化铁: Fe₂O₃
  static final MineralFormula ironOxide = MineralFormula(
    '氧化铁',
    {ChemicalFormula.fe2o3: 1.0},
  );

  // 氧化铜: CuO
  static final MineralFormula copperOxide = MineralFormula(
    '氧化铜',
    {ChemicalFormula.cuo: 1.0},
  );

  // 氧化钴: CoO
  static final MineralFormula cobaltOxide = MineralFormula(
    '氧化钴',
    {ChemicalFormula.coo: 1.0},
  );

  // 氧化铬: Cr₂O₃
  static final MineralFormula chromiumOxide = MineralFormula(
    '氧化铬',
    {ChemicalFormula.cr2o3: 1.0},
  );

  // 氧化锰: MnO₂
  static final MineralFormula manganeseOxide = MineralFormula(
    '氧化锰',
    {ChemicalFormula.mno2: 1.0},
  );

  // 氧化镍: NiO
  static final MineralFormula nickelOxide = MineralFormula(
    '氧化镍',
    {ChemicalFormula.nio: 1.0},
  );

  // 硼酸: H₃BO₃ → 烧成后: 0.5B₂O₃ (2H₃BO₃ → B₂O₃ + 3H₂O)
  static final MineralFormula boricAcid = MineralFormula(
    '硼酸',
    {ChemicalFormula.h3bo3: 1.0},
    {ChemicalFormula.b2o3: 0.5},  // 脱水分解
  );

  // 钙长石（斜长石系列）: CaO·Al₂O₃·2SiO₂
  static final MineralFormula anorthite = MineralFormula(
    '钙长石',
    {ChemicalFormula.cao: 1.0, ChemicalFormula.al2o3: 1.0, ChemicalFormula.sio2: 2.0},
  );

  // 霞石: Na₂O·Al₂O₃·2SiO₂
  static final MineralFormula nepheline = MineralFormula(
    '霞石',
    {ChemicalFormula.na2o: 1.0, ChemicalFormula.al2o3: 1.0, ChemicalFormula.sio2: 2.0},
  );

  // 叶蜡石: Al₂O₃·4SiO₂·H₂O → 烧成后: Al₂O₃·4SiO₂
  static final MineralFormula pyrophyllite = MineralFormula(
    '叶蜡石',
    {ChemicalFormula.al2o3: 1.0, ChemicalFormula.sio2: 4.0, ChemicalFormula.h2o: 1.0},
    {ChemicalFormula.al2o3: 1.0, ChemicalFormula.sio2: 4.0},  // 结合水蒸发
  );

  // 透辉石: CaO·MgO·2SiO₂
  static final MineralFormula diopside = MineralFormula(
    '透辉石',
    {ChemicalFormula.cao: 1.0, ChemicalFormula.mgo: 1.0, ChemicalFormula.sio2: 2.0},
  );

  // 硅灰石: CaO·SiO₂
  static final MineralFormula wollastonite = MineralFormula(
    '硅灰石',
    {ChemicalFormula.cao: 1.0, ChemicalFormula.sio2: 1.0},
  );

  // 所有矿物列表
  static final List<MineralFormula> all = [
    // 长石类
    potashFeldspar,
    sodaFeldspar,
    anorthite,
    nepheline,
    // 粘土类
    kaolin,
    pyrophyllite,
    // 滑石类
    talc,
    // 锂矿
    spodumene,
    lithiumCarbonate,
    // 锆矿
    zircon,
    zirconiumDioxide,
    // 硼矿
    borax,
    boricAcid,
    // 碳酸盐类
    limestone,
    calcite,
    dolomite,
    witherite,
    magnesite,
    // 硅酸盐矿物
    quartz,
    wollastonite,
    diopside,
    // 氧化铝
    alumina,
    // 着色氧化物
    ironOxide,
    copperOxide,
    cobaltOxide,
    chromiumOxide,
    manganeseOxide,
    nickelOxide,
    // 其他氧化物
    zincOxide,
    titaniumDioxide,
    tinOxide,
  ];

  /// 根据名称查找矿物
  static MineralFormula? fromName(String name) {
    try {
      return all.firstWhere((m) => m.name == name);
    } catch (e) {
      return null;
    }
  }
}
