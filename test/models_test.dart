import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_calculator/models/element.dart' as elem;
import 'package:glaze_calculator/models/chemical_formula.dart';
import 'package:glaze_calculator/models/mineral_formula.dart';

void main() {
  group('elem.Element 测试', () {
    test('元素摩尔质量正确', () {
      expect(elem.Element.ca.atomicMass, 40.08);
      expect(elem.Element.c.atomicMass, 12.01);
      expect(elem.Element.o.atomicMass, 16.00);
    });
  });

  group('ChemicalFormula 测试', () {
    test('CaCO₃ 摩尔质量计算正确', () {
      // CaCO₃ = 40.08 + 12.01 + 3*16.00 = 100.09
      expect(ChemicalFormula.caco3.molarMass, closeTo(100.09, 0.01));
    });

    test('H₂O 摩尔质量计算正确', () {
      // H₂O = 2*1.008 + 16.00 = 18.016
      expect(ChemicalFormula.h2o.molarMass, closeTo(18.016, 0.01));
    });

    test('SiO₂ 摩尔质量计算正确', () {
      // SiO₂ = 28.09 + 2*16.00 = 60.09
      expect(ChemicalFormula.sio2.molarMass, closeTo(60.09, 0.01));
    });
  });

  group('MineralFormula 测试', () {
    test('石灰石(CaCO₃)摩尔质量计算正确', () {
      final limestone = MineralFormula(
        '石灰石',
        {ChemicalFormula.caco3: 1.0},
      );
      // CaCO₃ = 100.09
      expect(limestone.molarMass, closeTo(100.09, 0.01));
    });

    test('高岭土(Al₂O₃·2SiO₂·2H₂O)摩尔质量计算正确', () {
      // Al₂O₃ = 2*26.98 + 3*16.00 = 101.96
      // SiO₂ = 28.09 + 2*16.00 = 60.09
      // H₂O = 2*1.008 + 16.00 = 18.016
      // 总计 = 101.96 + 2*60.09 + 2*18.016 = 258.172
      expect(MineralFormula.kaolin.molarMass, closeTo(258.17, 0.1));
    });

    test('钾长石(K₂O·Al₂O₃·6SiO₂)摩尔质量计算正确', () {
      // K₂O = 2*39.10 + 16.00 = 94.20
      // Al₂O₃ = 2*26.98 + 3*16.00 = 101.96
      // SiO₂ = 28.09 + 2*16.00 = 60.09
      // 总计 = 94.20 + 101.96 + 6*60.09 = 556.70
      expect(MineralFormula.potashFeldspar.molarMass, closeTo(556.70, 0.5));
    });

    test('白云石(CaCO₃·MgCO₃)摩尔质量计算正确', () {
      // CaCO₃ = 100.09
      // MgCO₃ = 24.31 + 12.01 + 3*16.00 = 84.32
      // 总计 = 100.09 + 84.32 = 184.41
      expect(MineralFormula.dolomite.molarMass, closeTo(184.41, 0.1));
    });

    test('硼砂(Na₂O·2B₂O₃·10H₂O)摩尔质量和质量百分比', () {
      final massPercentages = MineralFormula.borax.calculateMassPercentages();

      // 验证所有百分比加起来为 100%
      final total = massPercentages.values.reduce((a, b) => a + b);
      expect(total, closeTo(100.0, 0.1));

      // 打印实际值用于调试
      print('硼砂摩尔质量: ${MineralFormula.borax.molarMass.toStringAsFixed(2)} g/mol');
      print('硼砂组成百分比:');
      massPercentages.forEach((name, percent) {
        print('  $name: ${percent.toStringAsFixed(2)}%');
      });
    });
  });

  group('化学式字符串生成测试', () {
    test('钾长石化学式字符串正确', () {
      expect(MineralFormula.potashFeldspar.formulaString, 'K₂O·Al₂O₃·6SiO₂');
    });

    test('白云石化学式字符串正确', () {
      expect(MineralFormula.dolomite.formulaString, 'CaCO₃·MgCO₃');
    });
  });
}
