String latexMetniniOnar(String metin) {
  var sonuc = metin
      .replaceAll('\u0008ullet', r'\bullet')
      .replaceAll('\u0008eta', r'\beta')
      .replaceAll('\u0008ig', r'\big')
      .replaceAll('\u0008ar', r'\bar')
      .replaceAll('\u0008egin', r'\begin')
      .replaceAll('\u0009ext', r'\text')
      .replaceAll('\u0009imes', r'\times')
      .replaceAll('\u0009heta', r'\theta')
      .replaceAll('\u0009an', r'\tan')
      .replaceAll('\u000crac', r'\frac')
      .replaceAll('\u000crloor', r'\floor')
      .replaceAll('\u000doot', r'\root')
      .replaceAll('\u000dight', r'\right');

  sonuc = sonuc
      .replaceAll(RegExp(r'(?<!\\)\bcdot\b'), r'\cdot')
      .replaceAll(RegExp(r'(?<!\\)\btext\s*\('), r'\text(')
      .replaceAll(RegExp(r'(?<!\\)\bfrac\s*\{'), r'\frac{')
      .replaceAll(RegExp(r'(?<!\\)\bsqrt\s*\{'), r'\sqrt{')
      .replaceAll(RegExp(r'(?<!\\)\bsqrt\s*\('), r'\sqrt(');

  sonuc = sonuc.replaceAll(
    RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F]'),
    '',
  );
  return sonuc;
}
