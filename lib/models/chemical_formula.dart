import 'element.dart' as elem;

/// 化学式（由元素组成）
class ChemicalFormula {
  final String name;
  final Map<elem.Element, int> composition; // 元素组成

  const ChemicalFormula(this.name, this.composition);

  /// 判断是否为 RO 类氧化物
  bool get isRO => roOxides.contains(this);

  /// 计算摩尔质量（根据元素组成自动计算）
  double get molarMass {
    double mass = 0.0;
    for (var entry in composition.entries) {
      mass += entry.key.atomicMass * entry.value;
    }
    return mass;
  }

  @override
  String toString() => '$name (${molarMass.toStringAsFixed(2)} g/mol)';

  // === 碱性氧化物 (RO) ===
  static final ChemicalFormula k2o = ChemicalFormula('K₂O', const {elem.Element.k: 2, elem.Element.o: 1});
  static final ChemicalFormula na2o = ChemicalFormula('Na₂O', const {elem.Element.na: 2, elem.Element.o: 1});
  static final ChemicalFormula cao = ChemicalFormula('CaO', const {elem.Element.ca: 1, elem.Element.o: 1});
  static final ChemicalFormula mgo = ChemicalFormula('MgO', const {elem.Element.mg: 1, elem.Element.o: 1});
  static final ChemicalFormula bao = ChemicalFormula('BaO', const {elem.Element.ba: 1, elem.Element.o: 1});
  static final ChemicalFormula sro = ChemicalFormula('SrO', const {elem.Element.sr: 1, elem.Element.o: 1});
  static final ChemicalFormula li2o = ChemicalFormula('Li₂O', const {elem.Element.li: 2, elem.Element.o: 1});
  static final ChemicalFormula zno = ChemicalFormula('ZnO', const {elem.Element.zn: 1, elem.Element.o: 1});
  static final ChemicalFormula pbo = ChemicalFormula('PbO', const {elem.Element.pb: 1, elem.Element.o: 1});

  // === 中性氧化物 (R₂O₃) ===
  static final ChemicalFormula al2o3 = ChemicalFormula('Al₂O₃', const {elem.Element.al: 2, elem.Element.o: 3});
  static final ChemicalFormula b2o3 = ChemicalFormula('B₂O₃', const {elem.Element.b: 2, elem.Element.o: 3});
  static final ChemicalFormula p2o5 = ChemicalFormula('P₂O₅', const {elem.Element.p: 2, elem.Element.o: 5});

  // === 酸性氧化物 (RO₂) ===
  static final ChemicalFormula sio2 = ChemicalFormula('SiO₂', const {elem.Element.si: 1, elem.Element.o: 2});
  static final ChemicalFormula tio2 = ChemicalFormula('TiO₂', const {elem.Element.ti: 1, elem.Element.o: 2});
  static final ChemicalFormula sno2 = ChemicalFormula('SnO₂', const {elem.Element.sn: 1, elem.Element.o: 2});
  static final ChemicalFormula zro2 = ChemicalFormula('ZrO₂', const {elem.Element.zr: 1, elem.Element.o: 2});

  // === 着色氧化物 ===
  static final ChemicalFormula fe2o3 = ChemicalFormula('Fe₂O₃', const {elem.Element.fe: 2, elem.Element.o: 3});
  static final ChemicalFormula cuo = ChemicalFormula('CuO', const {elem.Element.cu: 1, elem.Element.o: 1});
  static final ChemicalFormula coo = ChemicalFormula('CoO', const {elem.Element.co: 1, elem.Element.o: 1});
  static final ChemicalFormula cr2o3 = ChemicalFormula('Cr₂O₃', const {elem.Element.cr: 2, elem.Element.o: 3});
  static final ChemicalFormula mno2 = ChemicalFormula('MnO₂', const {elem.Element.mn: 1, elem.Element.o: 2});
  static final ChemicalFormula nio = ChemicalFormula('NiO', const {elem.Element.ni: 1, elem.Element.o: 1});

  // === 碳酸盐 ===
  static final ChemicalFormula caco3 = ChemicalFormula('CaCO₃', const {elem.Element.ca: 1, elem.Element.c: 1, elem.Element.o: 3});
  static final ChemicalFormula mgco3 = ChemicalFormula('MgCO₃', const {elem.Element.mg: 1, elem.Element.c: 1, elem.Element.o: 3});
  static final ChemicalFormula baco3 = ChemicalFormula('BaCO₃', const {elem.Element.ba: 1, elem.Element.c: 1, elem.Element.o: 3});
  static final ChemicalFormula li2co3 = ChemicalFormula('Li₂CO₃', const {elem.Element.li: 2, elem.Element.c: 1, elem.Element.o: 3});

  // === 其他化合物 ===
  static final ChemicalFormula h2o = ChemicalFormula('H₂O', const {elem.Element.h: 2, elem.Element.o: 1});
  static final ChemicalFormula h3bo3 = ChemicalFormula('H₃BO₃', const {elem.Element.h: 3, elem.Element.b: 1, elem.Element.o: 3});

  // === 分类列表 ===

  /// RO 类氧化物（碱性氧化物）
  static final List<ChemicalFormula> roOxides = [
    k2o, na2o, cao, mgo, bao, sro, li2o, zno, pbo,
  ];

  /// R₂O₃ 类氧化物（中性氧化物）
  static final List<ChemicalFormula> r2o3Oxides = [
    al2o3, b2o3, p2o5,
  ];

  /// RO₂ 类氧化物（酸性氧化物）
  static final List<ChemicalFormula> ro2Oxides = [
    sio2, tio2, sno2, zro2,
  ];

  /// 发色金属氧化物（着色氧化物）
  static final List<ChemicalFormula> coloringOxides = [
    fe2o3, cuo, coo, cr2o3, mno2, nio,
  ];

  /// 其他化合物（碳酸盐、水等）
  static final List<ChemicalFormula> otherCompounds = [
    caco3, mgco3, baco3, li2co3,
    h2o, h3bo3,
  ];

  // 所有化学式列表（包含所有分类）
  static final List<ChemicalFormula> all = [
    ...roOxides,
    ...r2o3Oxides,
    ...ro2Oxides,
    ...coloringOxides,
    ...otherCompounds,
  ];

  /// 化学式分类映射（用于 UI 显示）
  static final Map<String, List<ChemicalFormula>> categoryMap = {
    '碱性氧化物 (RO)': roOxides,
    '中性氧化物 (R₂O₃)': r2o3Oxides,
    '酸性氧化物 (RO₂)': ro2Oxides,
    '着色氧化物': coloringOxides,
  };

  /// 根据名称查找化学式
  static ChemicalFormula? fromName(String name) {
    try {
      return all.firstWhere((f) => f.name == name);
    } catch (e) {
      return null;
    }
  }
}
