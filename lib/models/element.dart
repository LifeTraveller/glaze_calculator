/// 化学元素
class Element {
  final String symbol; // 元素符号
  final double atomicMass; // 原子质量 (g/mol)
  final String nameCn; // 中文名称

  const Element(this.symbol, this.atomicMass, this.nameCn);

  @override
  String toString() => '$symbol ($atomicMass g/mol)';

  // 常用元素定义
  static const Element k = Element('K', 39.10, '钾');
  static const Element na = Element('Na', 22.99, '钠');
  static const Element ca = Element('Ca', 40.08, '钙');
  static const Element mg = Element('Mg', 24.31, '镁');
  static const Element ba = Element('Ba', 137.33, '钡');
  static const Element sr = Element('Sr', 87.62, '锶');
  static const Element li = Element('Li', 6.94, '锂');
  static const Element zn = Element('Zn', 65.38, '锌');
  static const Element pb = Element('Pb', 207.2, '铅');
  static const Element al = Element('Al', 26.98, '铝');
  static const Element b = Element('B', 10.81, '硼');
  static const Element p = Element('P', 30.97, '磷');
  static const Element si = Element('Si', 28.09, '硅');
  static const Element ti = Element('Ti', 47.87, '钛');
  static const Element sn = Element('Sn', 118.71, '锡');
  static const Element zr = Element('Zr', 91.22, '锆');
  static const Element fe = Element('Fe', 55.85, '铁');
  static const Element cu = Element('Cu', 63.55, '铜');
  static const Element co = Element('Co', 58.93, '钴');
  static const Element cr = Element('Cr', 52.00, '铬');
  static const Element mn = Element('Mn', 54.94, '锰');
  static const Element ni = Element('Ni', 58.69, '镍');
  static const Element o = Element('O', 16.00, '氧');
  static const Element h = Element('H', 1.008, '氢');
  static const Element c = Element('C', 12.01, '碳');
}
