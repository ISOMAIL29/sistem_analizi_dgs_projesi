import 'package:flutter/material.dart';
import 'package:dgs_app/tema/uygulama_temasi.dart';
import 'package:dgs_app/ekranlar/deneme_cozme_ekrani.dart';

class DenemeSecimEkrani extends StatelessWidget {
  final String zorluk;

  const DenemeSecimEkrani({super.key, required this.zorluk});

  static const Color _bg = Color(0xFFF4F8FF);
  static const Color _text = Color(0xFF1E3A8A);
  static const Color _muted = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: true,
        title: Text(_zorlukBasligi(zorluk)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(
            '$zorluk seviyesinde 3 farklı denemeden birini seç.',
            style: const TextStyle(color: _muted),
          ),
          const SizedBox(height: 16),
          ...List.generate(3, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _DenemeSecimKarti(
                denemeNo: index + 1,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DenemeCozmeEkrani(
                        zorluk: zorluk,
                        denemeNo: index + 1,
                      ),
                    ),
                  );
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  String _zorlukBasligi(String value) {
    if (value == 'Kolay') return 'Kolay Denemeler';
    if (value == 'Orta') return 'Orta Denemeler';
    return 'Zor Denemeler';
  }
}

class _DenemeSecimKarti extends StatelessWidget {
  final int denemeNo;
  final VoidCallback onTap;

  const _DenemeSecimKarti({required this.denemeNo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFDDE7FF)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: UygulamaTemasi.acikMavi,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '$denemeNo',
                  style: const TextStyle(
                    color: DenemeSecimEkrani._text,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Deneme $denemeNo',
                      style: const TextStyle(
                        color: DenemeSecimEkrani._text,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _BilgiRozeti(
                          icon: Icons.help_outline_rounded,
                          text: '50 soru',
                        ),
                        _BilgiRozeti(
                          icon: Icons.timer_outlined,
                          text: '2 saat 15 dk',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: DenemeSecimEkrani._text,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BilgiRozeti extends StatelessWidget {
  final IconData icon;
  final String text;

  const _BilgiRozeti({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: UygulamaTemasi.koyuMavi),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: DenemeSecimEkrani._text,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
