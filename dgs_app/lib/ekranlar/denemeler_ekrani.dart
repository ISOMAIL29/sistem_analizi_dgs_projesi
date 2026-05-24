import 'package:flutter/material.dart';
import 'package:dgs_app/ekranlar/deneme_secim_ekrani.dart';

class DenemelerEkrani extends StatelessWidget {
  const DenemelerEkrani({super.key});

  static const Color _bg = Color(0xFFF4F8FF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: true,
        title: const Text('Deneme Merkezi'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Zorluk seviyene göre uygun denemeyi seç.',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 14),
            _denemeKartiOlustur(
              context,
              baslik: 'Kolay',
              renk: const Color(0xFFEAF2FF),
              textColor: const Color(0xFF1E3A8A),
              zorluk: 'Kolay',
              sure: '2 saat 15 dk',
              soruSayisi: '50 soru',
            ),
            const SizedBox(height: 16),
            _denemeKartiOlustur(
              context,
              baslik: 'Orta',
              renk: const Color(0xFFDDEBFF),
              textColor: const Color(0xFF1D4ED8),
              zorluk: 'Orta',
              sure: '2 saat 15 dk',
              soruSayisi: '50 soru',
            ),
            const SizedBox(height: 16),
            _denemeKartiOlustur(
              context,
              baslik: 'Zor',
              renk: const Color(0xFFCCDEFF),
              textColor: const Color(0xFF1E40AF),
              zorluk: 'Zor',
              sure: '2 saat 15 dk',
              soruSayisi: '50 soru',
            ),
          ],
        ),
      ),
    );
  }

  Widget _denemeKartiOlustur(
    BuildContext context, {
    required String baslik,
    required Color renk,
    required Color textColor,
    required String zorluk,
    required String sure,
    required String soruSayisi,
  }) {
    return Ink(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: renk,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            baslik,
            style: TextStyle(
              color: textColor,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$soruSayisi • $sure',
            style: TextStyle(
              color: textColor.withValues(alpha: 0.8),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DenemeSecimEkrani(zorluk: zorluk),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: textColor,
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Denemeyi Başlat'),
          ),
        ],
      ),
    );
  }
}
