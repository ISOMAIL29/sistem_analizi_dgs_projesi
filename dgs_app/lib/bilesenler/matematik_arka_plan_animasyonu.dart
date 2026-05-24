import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

class MatematikArkaPlanAnimasyonu extends StatefulWidget {
  const MatematikArkaPlanAnimasyonu({
    super.key,
    this.calismaSuresi = const Duration(seconds: 8),
  });

  final Duration calismaSuresi;

  @override
  State<MatematikArkaPlanAnimasyonu> createState() =>
      _MatematikArkaPlanAnimasyonuDurumu();
}

class _MatematikArkaPlanAnimasyonuDurumu
    extends State<MatematikArkaPlanAnimasyonu>
    with SingleTickerProviderStateMixin {
  late final AnimationController _kontrolcu;
  Timer? _durdurmaZamanlayicisi;

  static const List<_UcanFormul> _formuller = [
    _UcanFormul('∫', 0.08, 0.13, 30, 0.00, 0xFF2563EB),
    _UcanFormul('∑', 0.78, 0.10, 27, 0.16, 0xFF1E3A8A),
    _UcanFormul('∂', 0.18, 0.78, 24, 0.33, 0xFF138BED),
    _UcanFormul('∞', 0.84, 0.72, 30, 0.48, 0xFF2563EB),
    _UcanFormul('π', 0.58, 0.18, 22, 0.62, 0xFF1E3A8A),
    _UcanFormul('α', 0.09, 0.50, 20, 0.74, 0xFF138BED),
    _UcanFormul('Δ', 0.86, 0.40, 24, 0.25, 0xFF2563EB),
    _UcanFormul('Ω', 0.66, 0.82, 23, 0.88, 0xFF1E3A8A),
    _UcanFormul('∈', 0.33, 0.22, 18, 0.41, 0xFF138BED),
    _UcanFormul('∀', 0.42, 0.87, 19, 0.57, 0xFF2563EB),
    _UcanFormul('∃', 0.91, 0.58, 19, 0.70, 0xFF1E3A8A),
    _UcanFormul('{...}', 0.21, 0.36, 17, 0.09, 0xFF138BED),
    _UcanFormul('sin(x)', 0.69, 0.31, 17, 0.53, 0xFF2563EB),
    _UcanFormul('x²', 0.31, 0.66, 18, 0.82, 0xFF1E3A8A),
    _UcanFormul('E=mc²', 0.59, 0.61, 16, 0.21, 0xFF138BED),
  ];

  @override
  void initState() {
    super.initState();
    _kontrolcu = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();

    _durdurmaZamanlayicisi = Timer(widget.calismaSuresi, _kontrolcu.stop);
  }

  @override
  void dispose() {
    _durdurmaZamanlayicisi?.cancel();
    _kontrolcu.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: SizedBox.expand(
          child: CustomPaint(
            painter: _UcanFormulBoyacisi(
              animasyon: _kontrolcu,
              formuller: _formuller,
            ),
          ),
        ),
      ),
    );
  }
}

class _UcanFormul {
  final String metin;
  final double xOrani;
  final double yOrani;
  final double punto;
  final double faz;
  final int renk;

  const _UcanFormul(
    this.metin,
    this.xOrani,
    this.yOrani,
    this.punto,
    this.faz,
    this.renk,
  );
}

class _UcanFormulBoyacisi extends CustomPainter {
  final Animation<double> animasyon;
  final List<_UcanFormul> formuller;

  _UcanFormulBoyacisi({required this.animasyon, required this.formuller})
    : super(repaint: animasyon);

  @override
  void paint(Canvas canvas, Size size) {
    final zaman = animasyon.value;

    for (final formul in formuller) {
      final dalga = math.sin((zaman + formul.faz) * math.pi * 2);
      final ikinciDalga = math.cos((zaman * 0.75 + formul.faz) * math.pi * 2);
      final x = size.width * formul.xOrani + ikinciDalga * 14;
      final y = size.height * formul.yOrani + dalga * 22;
      final olcek = 1 + dalga * 0.09;
      final saydamlik = 0.08 + (ikinciDalga + 1) * 0.035;
      final textPainter = TextPainter(
        text: TextSpan(
          text: formul.metin,
          style: TextStyle(
            color: Color(formul.renk).withValues(alpha: saydamlik),
            fontSize: formul.punto,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(dalga * 0.08);
      canvas.scale(olcek);
      textPainter.paint(canvas, Offset.zero);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _UcanFormulBoyacisi oldDelegate) {
    return oldDelegate.animasyon != animasyon ||
        oldDelegate.formuller != formuller;
  }
}
