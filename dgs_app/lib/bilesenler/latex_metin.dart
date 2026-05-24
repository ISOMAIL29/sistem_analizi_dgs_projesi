import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import 'package:dgs_app/yardimcilar/latex_temizleyici.dart';

class LatexMetin extends StatelessWidget {
  const LatexMetin(
    this.metin, {
    super.key,
    this.style,
    this.spacing = 2,
    this.runSpacing = 4,
  });

  final String metin;
  final TextStyle? style;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = DefaultTextStyle.of(context).style.merge(style);
    final mathStyle = effectiveStyle.copyWith(
      fontSize: (effectiveStyle.fontSize ?? 14) * 1.12,
    );
    final parcalar = _latexParcalariniAyir(latexMetniniOnar(metin));

    return RichText(
      text: TextSpan(
        style: effectiveStyle,
        children: [
          for (final parca in parcalar)
            if (parca.latexMi)
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: spacing / 2),
                  child: Math.tex(
                    parca.metin,
                    mathStyle: MathStyle.display,
                    textStyle: mathStyle,
                    onErrorFallback: (error) =>
                        Text('\$${parca.metin}\$', style: effectiveStyle),
                  ),
                ),
              )
            else
              TextSpan(text: parca.metin),
        ],
      ),
    );
  }

  List<_LatexParcasi> _latexParcalariniAyir(String kaynak) {
    final parcalar = <_LatexParcasi>[];
    final buffer = StringBuffer();
    var latexMi = false;

    void flush() {
      if (buffer.isEmpty) return;
      final metin = buffer.toString();
      if (latexMi) {
        parcalar.add(_LatexParcasi(metin, true));
      } else {
        parcalar.addAll(_duzMetinParcalariniAyir(metin));
      }
      buffer.clear();
    }

    for (var i = 0; i < kaynak.length; i++) {
      final karakter = kaynak[i];
      final oncekiEscapeMi = i > 0 && kaynak.codeUnitAt(i - 1) == 0x5C;

      if (karakter == r'$' && !oncekiEscapeMi) {
        flush();
        latexMi = !latexMi;
      } else {
        buffer.write(karakter);
      }
    }

    flush();

    return parcalar.isEmpty ? [_LatexParcasi(kaynak, false)] : parcalar;
  }

  List<_LatexParcasi> _duzMetinParcalariniAyir(String kaynak) {
    final parcalar = <_LatexParcasi>[];
    final tokenlar = RegExp(
      r'\s+|\S+',
    ).allMatches(kaynak).map((match) => match.group(0) ?? '').toList();
    final matematikMi = List<bool>.filled(tokenlar.length, false);

    for (var i = 0; i < tokenlar.length; i++) {
      final token = tokenlar[i];
      if (token.trim().isEmpty) continue;
      matematikMi[i] = _tokenMatematikMi(token);
    }

    for (var i = 0; i < tokenlar.length; i++) {
      final token = tokenlar[i];
      final temiz = token.trim();
      if (temiz.isEmpty || matematikMi[i]) continue;

      final onceki = _oncekiDoluTokenIndeksi(tokenlar, i);
      final sonraki = _sonrakiDoluTokenIndeksi(tokenlar, i);
      final operatorYaninda =
          (onceki != null && _tokenOperatorMu(tokenlar[onceki])) ||
          (sonraki != null && _tokenOperatorMu(tokenlar[sonraki]));

      if (operatorYaninda && _tokenMatematikTerimiMi(token)) {
        matematikMi[i] = true;
      }
    }

    final mathBuffer = StringBuffer();
    final textBuffer = StringBuffer();

    void flushMath() {
      if (mathBuffer.isEmpty) return;
      parcalar.add(_LatexParcasi(mathBuffer.toString().trim(), true));
      mathBuffer.clear();
    }

    void flushText() {
      if (textBuffer.isEmpty) return;
      parcalar.add(_LatexParcasi(textBuffer.toString(), false));
      textBuffer.clear();
    }

    for (var i = 0; i < tokenlar.length; i++) {
      final token = tokenlar[i];
      if (token.trim().isEmpty) {
        final sonraki = _sonrakiDoluTokenIndeksi(tokenlar, i);
        if (mathBuffer.isNotEmpty && sonraki != null && matematikMi[sonraki]) {
          mathBuffer.write(token);
        } else {
          flushMath();
          textBuffer.write(token);
        }
        continue;
      }

      if (matematikMi[i]) {
        flushText();
        mathBuffer.write(token);
      } else {
        flushMath();
        textBuffer.write(token);
      }
    }

    flushMath();
    flushText();
    return parcalar;
  }

  bool _tokenMatematikMi(String token) {
    final temiz = _tokenTemizle(token);
    if (temiz.isEmpty) return false;
    if (RegExp(r'^[A-E]\)$').hasMatch(temiz)) return false;
    if (temiz.startsWith(r'\')) return true;
    if (RegExp(r'[+\-*/=<>^_{}()[\]|]').hasMatch(temiz)) return true;
    if (RegExp(r'\d+[A-Za-z]+|[A-Za-z]+\d+').hasMatch(temiz)) return true;
    return false;
  }

  bool _tokenMatematikTerimiMi(String token) {
    final temiz = _tokenTemizle(token);
    if (temiz.isEmpty) return false;
    if (RegExp(r'^[A-E]\)$').hasMatch(temiz)) return false;
    return RegExp(
      r'^[A-Za-zÇĞİÖŞÜçğıöşü]$|^-?\d+(?:[,.]\d+)?$',
    ).hasMatch(temiz);
  }

  bool _tokenOperatorMu(String token) {
    final temiz = _tokenTemizle(token);
    return temiz.startsWith(r'\') ||
        RegExp(r'^[+\-*/=<>^_{}()[\]|]+$').hasMatch(temiz) ||
        RegExp(r'[+\-*/=<>^_{}()[\]|]').hasMatch(temiz);
  }

  String _tokenTemizle(String token) {
    return token.trim().replaceAll(RegExp(r'^[,.;:!?]+|[,.;:!?]+$'), '');
  }

  int? _oncekiDoluTokenIndeksi(List<String> tokenlar, int indeks) {
    for (var i = indeks - 1; i >= 0; i--) {
      if (tokenlar[i].trim().isNotEmpty) return i;
    }
    return null;
  }

  int? _sonrakiDoluTokenIndeksi(List<String> tokenlar, int indeks) {
    for (var i = indeks + 1; i < tokenlar.length; i++) {
      if (tokenlar[i].trim().isNotEmpty) return i;
    }
    return null;
  }
}

class _LatexParcasi {
  const _LatexParcasi(this.metin, this.latexMi);

  final String metin;
  final bool latexMi;
}
