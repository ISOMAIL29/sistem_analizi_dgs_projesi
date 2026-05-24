import 'dart:math' as math;

import 'package:dgs_app/modeller/modeller.dart';
import 'package:dgs_app/servisler/api_servisi.dart';
import 'package:dgs_app/veritabani/veritabani_yardimcisi.dart';
import 'package:dgs_app/yardimcilar/latex_temizleyici.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:tex/tex.dart';
import 'package:url_launcher/url_launcher.dart';

class HesapEkrani extends StatefulWidget {
  const HesapEkrani({super.key});

  @override
  State<HesapEkrani> createState() => _HesapEkraniDurumu();
}

class _HesapEkraniDurumu extends State<HesapEkrani> {
  final VeritabaniYardimcisi _veritabaniYardimcisi = VeritabaniYardimcisi();
  late Future<_HesapVerileri> _hesapVerileriGelecegi;
  int _gunlukGrafikHaftaKaydirma = 0;
  int _konuGrafikHaftaKaydirma = 0;
  int? _gunlukGrafikSeciliGun;
  int? _konuGrafikSeciliGun;
  int? _secilenKonuId;
  bool _genelIstatistiklerAcik = false;

  static const Color _bg = Color(0xFFF4F8FF);
  static const Color _primary = Color(0xFF2563EB);
  static const Color _text = Color(0xFF1E3A8A);

  @override
  void initState() {
    super.initState();
    _hesapVerileriGelecegi = _hesapVerileriniGetir();
  }

  Future<_HesapVerileri> _hesapVerileriniGetir() async {
    await ApiServisi().kullaniciBilgisiGetir();
    final kullanici = await _veritabaniYardimcisi.aktifKullaniciyiGetir();
    final istatistikler = await _veritabaniYardimcisi
        .aktifKullaniciIstatistikleriniGetir();
    final gunlukIstatistikler = await _veritabaniYardimcisi
        .aktifKullaniciGunlukIstatistikleriniGetir();
    final konuIstatistikleri = await _veritabaniYardimcisi
        .aktifKullaniciKonuIstatistikleriniGetir();
    final konuGunlukIstatistikleri = await _veritabaniYardimcisi
        .aktifKullaniciKonuGunlukIstatistikleriniGetir();
    final denemeIstatistikleri = await _veritabaniYardimcisi
        .aktifKullaniciDenemeIstatistikleriniGetir();
    return _HesapVerileri(
      kullanici: kullanici,
      istatistikler: istatistikler,
      gunlukIstatistikler: gunlukIstatistikler,
      konuIstatistikleri: konuIstatistikleri,
      konuGunlukIstatistikleri: konuGunlukIstatistikleri,
      denemeIstatistikleri: denemeIstatistikleri,
    );
  }

  void _yenile() {
    setState(() {
      _hesapVerileriGelecegi = _hesapVerileriniGetir();
    });
  }

  Future<void> _ayarlarEkraniniAc() async {
    final kullanici = await _veritabaniYardimcisi.aktifKullaniciyiGetir();
    if (!mounted) return;

    final yenile = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _HesapSecenekleriEkrani(kullanici: kullanici),
      ),
    );
    if (yenile == true && mounted) _yenile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: true,
        title: const Text('Hesap'),
        actions: [
          IconButton(
            tooltip: 'Ayarlar',
            onPressed: _ayarlarEkraniniAc,
            icon: const Icon(Icons.settings_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: FutureBuilder<_HesapVerileri>(
        future: _hesapVerileriGelecegi,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final veriler = snapshot.data ?? _HesapVerileri.bos();
          final kullanici = veriler.kullanici;
          final istatistikler = veriler.istatistikler;
          final gunlukIstatistikler = veriler.gunlukIstatistikler;
          final konuIstatistikleri = veriler.konuIstatistikleri;
          final konuGunlukIstatistikleri = veriler.konuGunlukIstatistikleri;
          final denemeIstatistikleri = veriler.denemeIstatistikleri;
          final username = (kullanici?['ad_soyad'] as String?) ?? '-';
          final hesapTuru = (kullanici?['hesap_turu'] as String?) ?? 'ucretsiz';

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              children: [
                _profilKartiOlustur(username: username, hesapTuru: hesapTuru),
                const SizedBox(height: 14),
                _gunlukGrafikKartiOlustur(gunlukIstatistikler),
                const SizedBox(height: 14),
                _konuCozumGrafikKartiOlustur(
                  konuIstatistikleri,
                  konuGunlukIstatistikleri,
                ),
                const SizedBox(height: 14),
                _denemeGrafikKartiOlustur(denemeIstatistikleri),
                const SizedBox(height: 14),
                _genelIstatistikKartiOlustur(istatistikler),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _profilKartiOlustur({
    required String username,
    required String hesapTuru,
  }) {
    final plusMi = hesapTuru.toLowerCase() == 'plus';
    final badgeMetni = plusMi ? 'PLUS' : 'ÜCRETSİZ';
    final badgeRengi = plusMi
        ? const Color(0xFFF59E0B)
        : const Color(0xFF2563EB);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDDE7FF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 32,
            backgroundColor: Color(0xFFEAF2FF),
            child: Icon(Icons.person, size: 34, color: _primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _text,
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: badgeRengi,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badgeMetni,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _gunlukGrafikKartiOlustur(
    List<Map<String, Object?>> gunlukIstatistikler,
  ) {
    final noktalar = _grafikNoktalariHazirla(
      gunlukIstatistikler,
      haftaKaydirma: _gunlukGrafikHaftaKaydirma,
    );
    final maxY = _grafikUstSiniri(noktalar.maxY);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _kartDekorasyonu(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Genel Durum',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: _text,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: const [
              _GrafikAciklamasi('Toplam', Color(0xFF2563EB)),
              _GrafikAciklamasi('Doğru', Color(0xFF16A34A)),
              _GrafikAciklamasi('Yanlış', Color(0xFFDC2626)),
              _GrafikAciklamasi('Boş', Color(0xFFF59E0B)),
            ],
          ),
          const SizedBox(height: 18),
          GestureDetector(
            onHorizontalDragEnd: (details) {
              final hiz = details.primaryVelocity ?? 0;
              if (hiz < -120 && _gunlukGrafikHaftaKaydirma > 0) {
                setState(() {
                  _gunlukGrafikHaftaKaydirma--;
                  _gunlukGrafikSeciliGun = null;
                });
              } else if (hiz > 120) {
                setState(() {
                  _gunlukGrafikHaftaKaydirma++;
                  _gunlukGrafikSeciliGun = null;
                });
              }
            },
            child: _cozumCizgiGrafigi(
              noktalar,
              maxY,
              seciliGun: _gunlukGrafikSeciliGun,
              onSeciliGunDegisti: (gun) {
                setState(() => _gunlukGrafikSeciliGun = gun);
              },
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Önceki haftalar kaydırın.',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _genelIstatistikKartiOlustur(Map<String, int> istatistikler) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: _kartDekorasyonu(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _genelIstatistiklerAcik = !_genelIstatistiklerAcik;
              });
            },
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Genel İstatistikler',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: _text,
                      ),
                    ),
                  ),
                  Icon(
                    _genelIstatistiklerAcik
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: _text,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Column(
              children: [
                const SizedBox(height: 10),
                _istatistikSatiriOlustur(
                  'Toplam Soru',
                  '${istatistikler['toplam'] ?? 0}',
                ),
                const Divider(),
                _istatistikSatiriOlustur(
                  'Başarı Oranı',
                  _dogrulukMetni(istatistikler),
                ),
                const Divider(),
                _istatistikSatiriOlustur(
                  'Doğru',
                  '${istatistikler['dogru'] ?? 0}',
                ),
                const Divider(),
                _istatistikSatiriOlustur(
                  'Yanlış',
                  '${istatistikler['yanlis'] ?? 0}',
                ),
                const Divider(),
                _istatistikSatiriOlustur('Boş', '${istatistikler['bos'] ?? 0}'),
                const SizedBox(height: 8),
              ],
            ),
            crossFadeState: _genelIstatistiklerAcik
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
          ),
        ],
      ),
    );
  }

  Widget _konuCozumGrafikKartiOlustur(
    List<Map<String, Object?>> konuIstatistikleri,
    List<Map<String, Object?>> konuGunlukIstatistikleri,
  ) {
    if (konuIstatistikleri.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: _kartDekorasyonu(),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Konu Durum',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: _text,
              ),
            ),
            SizedBox(height: 14),
            Text(
              'Henüz konu bazlı çözüm kaydı yok.',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    final istenenKonuId =
        _secilenKonuId ?? _intDegeri(konuIstatistikleri.first['konu_id']);
    final seciliKonu = konuIstatistikleri.firstWhere(
      (konu) => _intDegeri(konu['konu_id']) == istenenKonuId,
      orElse: () => konuIstatistikleri.first,
    );
    final seciliKonuId = _intDegeri(seciliKonu['konu_id']);
    final filtreliGunler = konuGunlukIstatistikleri
        .where((satir) => _intDegeri(satir['konu_id']) == seciliKonuId)
        .toList();
    final noktalar = _grafikNoktalariHazirla(
      filtreliGunler,
      haftaKaydirma: _konuGrafikHaftaKaydirma,
    );
    final maxY = _grafikUstSiniri(noktalar.maxY);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _kartDekorasyonu(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Konu Durum',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: _text,
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<int>(
            initialValue: seciliKonuId,
            isExpanded: true,
            items: konuIstatistikleri.map((konu) {
              final konuId = _intDegeri(konu['konu_id']);
              final toplam = _intDegeri(konu['toplam']);
              return DropdownMenuItem<int>(
                value: konuId,
                child: Text(
                  '${konu['konu_adi'] ?? '-'} ($toplam)',
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (konuId) {
              setState(() {
                _secilenKonuId = konuId;
                _konuGrafikHaftaKaydirma = 0;
                _konuGrafikSeciliGun = null;
              });
            },
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: const [
              _GrafikAciklamasi('Toplam', Color(0xFF2563EB)),
              _GrafikAciklamasi('Doğru', Color(0xFF16A34A)),
              _GrafikAciklamasi('Yanlış', Color(0xFFDC2626)),
              _GrafikAciklamasi('Boş', Color(0xFFF59E0B)),
            ],
          ),
          const SizedBox(height: 18),
          GestureDetector(
            onHorizontalDragEnd: (details) {
              final hiz = details.primaryVelocity ?? 0;
              if (hiz < -120 && _konuGrafikHaftaKaydirma > 0) {
                setState(() {
                  _konuGrafikHaftaKaydirma--;
                  _konuGrafikSeciliGun = null;
                });
              } else if (hiz > 120) {
                setState(() {
                  _konuGrafikHaftaKaydirma++;
                  _konuGrafikSeciliGun = null;
                });
              }
            },
            child: _cozumCizgiGrafigi(
              noktalar,
              maxY,
              seciliGun: _konuGrafikSeciliGun,
              onSeciliGunDegisti: (gun) {
                setState(() => _konuGrafikSeciliGun = gun);
              },
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Önceki haftalar için kaydırın.',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _denemeGrafikKartiOlustur(
    List<Map<String, Object?>> denemeIstatistikleri,
  ) {
    if (denemeIstatistikleri.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: _kartDekorasyonu(),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Deneme İstatistikleri',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: _text,
              ),
            ),
            SizedBox(height: 14),
            Text(
              'Henüz tamamlanmış deneme sınavı yok.',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    final noktalar = _denemeGrafikNoktalariHazirla(denemeIstatistikleri);
    final maxY = _grafikUstSiniri(noktalar.maxY);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _kartDekorasyonu(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Deneme İstatistikleri',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: _text,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: const [
              _GrafikAciklamasi('Doğru', Color(0xFF16A34A)),
              _GrafikAciklamasi('Yanlış', Color(0xFFDC2626)),
              _GrafikAciklamasi('Boş', Color(0xFFF59E0B)),
            ],
          ),
          const SizedBox(height: 18),
          _denemeSutunGrafigi(noktalar, maxY),
        ],
      ),
    );
  }

  Widget _istatistikSatiriOlustur(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF64748B))),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, color: _text),
          ),
        ],
      ),
    );
  }

  String _dogrulukMetni(Map<String, int> istatistikler) {
    final toplam = istatistikler['toplam'] ?? 0;
    if (toplam == 0) return '%0';
    final dogru = istatistikler['dogru'] ?? 0;
    return '%${((dogru / toplam) * 100).round()}';
  }

  _GunlukGrafikNoktalari _grafikNoktalariHazirla(
    List<Map<String, Object?>> gunlukIstatistikler, {
    required int haftaKaydirma,
  }) {
    final bugun = DateTime.now();
    final bitis = DateTime(
      bugun.year,
      bugun.month,
      bugun.day,
    ).subtract(Duration(days: haftaKaydirma * 7));
    final baslangic = bitis.subtract(const Duration(days: 6));
    final gunHaritasi = {
      for (final satir in gunlukIstatistikler) satir['gun']?.toString(): satir,
    };
    final toplam = <FlSpot>[];
    final dogru = <FlSpot>[];
    final yanlis = <FlSpot>[];
    final bos = <FlSpot>[];
    final etiketler = <String>[];
    var maxY = 0.0;

    for (var i = 0; i < 7; i++) {
      final tarih = baslangic.add(Duration(days: i));
      final anahtar = tarih.toIso8601String().substring(0, 10);
      final satir = gunHaritasi[anahtar] ?? const <String, Object?>{};
      final x = i.toDouble();
      final toplamDeger = _intDegeri(satir['toplam']).toDouble();
      final dogruDeger = _intDegeri(satir['dogru']).toDouble();
      final yanlisDeger = _intDegeri(satir['yanlis']).toDouble();
      final bosDeger = _intDegeri(satir['bos']).toDouble();

      toplam.add(FlSpot(x, toplamDeger));
      dogru.add(FlSpot(x, dogruDeger));
      yanlis.add(FlSpot(x, yanlisDeger));
      bos.add(FlSpot(x, bosDeger));
      etiketler.add('${tarih.day}/${tarih.month}');
      maxY = [
        maxY,
        toplamDeger,
        dogruDeger,
        yanlisDeger,
        bosDeger,
      ].reduce((a, b) => a > b ? a : b);
    }

    return _GunlukGrafikNoktalari(
      toplam: toplam,
      dogru: dogru,
      yanlis: yanlis,
      bos: bos,
      etiketler: etiketler,
      maxY: maxY,
      baslik:
          '${baslangic.day}/${baslangic.month} - ${bitis.day}/${bitis.month}',
    );
  }

  _GunlukGrafikNoktalari _denemeGrafikNoktalariHazirla(
    List<Map<String, Object?>> denemeIstatistikleri,
  ) {
    final toplam = <FlSpot>[];
    final dogru = <FlSpot>[];
    final yanlis = <FlSpot>[];
    final bos = <FlSpot>[];
    final etiketler = <String>[];
    var maxY = 0.0;

    for (var i = 0; i < denemeIstatistikleri.length; i++) {
      final satir = denemeIstatistikleri[i];
      final x = i.toDouble();
      final toplamDeger = _intDegeri(satir['toplam_soru_sayisi']).toDouble();
      final dogruDeger = _intDegeri(satir['dogru_sayisi']).toDouble();
      final yanlisDeger = _intDegeri(satir['yanlis_sayisi']).toDouble();
      final bosDeger = _intDegeri(satir['bos_sayisi']).toDouble();

      toplam.add(FlSpot(x, toplamDeger));
      dogru.add(FlSpot(x, dogruDeger));
      yanlis.add(FlSpot(x, yanlisDeger));
      bos.add(FlSpot(x, bosDeger));
      etiketler.add(satir['deneme_adi']?.toString() ?? 'Deneme ${i + 1}');
      maxY = [
        maxY,
        toplamDeger,
        dogruDeger,
        yanlisDeger,
        bosDeger,
      ].reduce((a, b) => a > b ? a : b);
    }

    return _GunlukGrafikNoktalari(
      toplam: toplam,
      dogru: dogru,
      yanlis: yanlis,
      bos: bos,
      etiketler: etiketler,
      maxY: maxY,
      baslik: 'Deneme Sonuçları',
    );
  }

  Widget _denemeSutunGrafigi(_GunlukGrafikNoktalari noktalar, double maxY) {
    final itemWidth = 86.0;
    final chartWidth = math.max(
      MediaQuery.of(context).size.width - 72,
      itemWidth * noktalar.etiketler.length,
    );
    final barGroups = [
      for (var i = 0; i < noktalar.etiketler.length; i++)
        BarChartGroupData(
          x: i,
          barsSpace: 5,
          barRods: [
            BarChartRodData(
              toY: noktalar.dogru[i].y,
              color: const Color(0xFF16A34A),
              width: 12,
              borderRadius: BorderRadius.circular(3),
            ),
            BarChartRodData(
              toY: noktalar.yanlis[i].y,
              color: const Color(0xFFDC2626),
              width: 12,
              borderRadius: BorderRadius.circular(3),
            ),
            BarChartRodData(
              toY: noktalar.bos[i].y,
              color: const Color(0xFFF59E0B),
              width: 12,
              borderRadius: BorderRadius.circular(3),
            ),
          ],
        ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: chartWidth,
        height: 286,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxY,
            barGroups: barGroups,
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: _grafikAraligi(maxY),
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: const Color(0xFFE2E8F0), strokeWidth: 1),
            ),
            borderData: FlBorderData(
              show: true,
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 52,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= noktalar.etiketler.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: SizedBox(
                        width: 58,
                        child: Text(
                          noktalar.etiketler[index],
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 10,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final label = switch (rodIndex) {
                    0 => 'Doğru',
                    1 => 'Yanlış',
                    _ => 'Boş',
                  };
                  return BarTooltipItem(
                    '$label: ${rod.toY.toInt()}',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _cozumCizgiGrafigi(
    _GunlukGrafikNoktalari noktalar,
    double maxY, {
    required int? seciliGun,
    required ValueChanged<int?> onSeciliGunDegisti,
  }) {
    final cizgiler = [
      _cizgiVerisi(noktalar.toplam, const Color(0xFF2563EB), 3),
      _cizgiVerisi(noktalar.dogru, const Color(0xFF16A34A), 2.6),
      _cizgiVerisi(noktalar.yanlis, const Color(0xFFDC2626), 2.6),
      _cizgiVerisi(noktalar.bos, const Color(0xFFF59E0B), 2.6),
    ];
    final tooltipGosterilecekNoktalar =
        seciliGun == null ||
            seciliGun < 0 ||
            seciliGun >= noktalar.etiketler.length
        ? const <ShowingTooltipIndicators>[]
        : [
            ShowingTooltipIndicators([
              for (var i = 0; i < cizgiler.length; i++)
                if (seciliGun < cizgiler[i].spots.length)
                  LineBarSpot(cizgiler[i], i, cizgiler[i].spots[seciliGun]),
            ]),
          ];

    return SizedBox(
      height: 260,
      child: Stack(
        children: [
          LineChart(
            LineChartData(
              minX: -0.18,
              maxX: 6.55,
              minY: 0,
              maxY: maxY,
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: _grafikAraligi(maxY),
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: const Color(0xFFE2E8F0), strokeWidth: 1),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      final yuvarlanmisDeger = value.roundToDouble();
                      if ((value - yuvarlanmisDeger).abs() > 0.01) {
                        return const SizedBox.shrink();
                      }

                      final index = yuvarlanmisDeger.toInt();
                      if (index < 0 || index >= noktalar.etiketler.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          noktalar.etiketler[index],
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 10,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineBarsData: cizgiler,
              showingTooltipIndicators: tooltipGosterilecekNoktalar,
              lineTouchData: LineTouchData(
                handleBuiltInTouches: false,
                touchSpotThreshold: 18,
                touchCallback: (event, response) {
                  if (event is! FlTapUpEvent) return;
                  final spots = response?.lineBarSpots;
                  if (spots == null || spots.isEmpty) {
                    onSeciliGunDegisti(null);
                    return;
                  }

                  final spot = spots.first;
                  final gun = spot.x.round();
                  if (gun < 0 || gun >= noktalar.etiketler.length) return;
                  onSeciliGunDegisti(seciliGun == gun ? null : gun);
                },
                touchTooltipData: LineTouchTooltipData(
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipItems: (spots) {
                    return spots.map((spot) {
                      final label = switch (spot.barIndex) {
                        0 => 'Toplam',
                        1 => 'Doğru',
                        2 => 'Yanlış',
                        _ => 'Boş',
                      };
                      return LineTooltipItem(
                        '$label: ${spot.y.toInt()}',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
            ),
          ),
          Positioned(
            left: 7,
            top: 3,
            bottom: 33,
            child: IgnorePointer(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final etiket in _grafikYEtiketleri(maxY))
                    Text(
                      etiket,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  LineChartBarData _cizgiVerisi(
    List<FlSpot> spots,
    Color renk,
    double kalinlik,
  ) {
    return LineChartBarData(
      spots: spots,
      isCurved: false,
      color: renk,
      barWidth: kalinlik,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
    );
  }

  BoxDecoration _kartDekorasyonu() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFDDE7FF)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  static double _grafikAraligi(double maxY) {
    if (maxY <= 0) return 1;
    final hedefAralik = maxY / 4;
    final kuvvet = math.pow(10, (math.log(hedefAralik) / math.ln10).floor());
    final normal = hedefAralik / kuvvet;
    final katsayi = normal <= 1
        ? 1
        : normal <= 2
        ? 2
        : normal <= 5
        ? 5
        : 10;
    return (katsayi * kuvvet).toDouble();
  }

  static double _grafikUstSiniri(double enYuksekDeger) {
    if (enYuksekDeger <= 0) return 5;
    final hedef = enYuksekDeger * 1.12;
    final aralik = _grafikAraligi(hedef);
    return math.max(5, (hedef / aralik).ceil() * aralik);
  }

  static List<String> _grafikYEtiketleri(double maxY) {
    final interval = _grafikAraligi(maxY);
    final degerler = <double>{0, maxY};
    for (var value = interval; value < maxY; value += interval) {
      degerler.add(value);
    }
    final siraliDegerler = degerler.toList()..sort();
    return siraliDegerler.reversed.map((deger) {
      return deger.toInt().toString();
    }).toList();
  }

  int _intDegeri(Object? deger) {
    if (deger is int) return deger;
    if (deger is num) return deger.toInt();
    return int.tryParse(deger?.toString() ?? '') ?? 0;
  }
}

class _HesapSecenekleriEkrani extends StatefulWidget {
  final Map<String, Object?>? kullanici;

  const _HesapSecenekleriEkrani({required this.kullanici});

  @override
  State<_HesapSecenekleriEkrani> createState() =>
      _HesapSecenekleriEkraniDurumu();
}

class _HesapSecenekleriEkraniDurumu extends State<_HesapSecenekleriEkrani> {
  bool _hesapAyarlariAcik = false;
  bool _soruAktarAcik = false;
  bool _sorularDisariAktariliyor = false;
  int _disariAktarSoruSayisi = 10;
  final Map<String, _PdfLatexSvg> _pdfLatexCache = {};

  static const Color _bg = Color(0xFFF4F8FF);
  static const Color _text = Color(0xFF1E3A8A);
  static const Color _danger = Color(0xFFDC2626);

  Future<void> _yardimMailiniAc(BuildContext context) async {
    final uri = Uri(scheme: 'mailto', path: 'support@isomail.dev');

    try {
      final acildi = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (acildi) return;
    } catch (_) {
      // Mail uygulamasi bulunamazsa kullaniciya temiz bir mesaj gosteriyoruz.
    }

    if (!context.mounted) return;
    await _hesapMesajiGoster(context, 'Mail uygulaması açılamadı.');
  }

  Future<void> _cikisYap(BuildContext context) async {
    await VeritabaniYardimcisi().oturumSil();
    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  Future<void> _hesapAyarlariniAc(BuildContext context) async {
    final aktifKullanici = widget.kullanici;
    if (aktifKullanici == null) return;

    final guncellendi = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => HesapAyarlariEkrani(kullanici: aktifKullanici),
      ),
    );
    if (!context.mounted) return;
    if (guncellendi == true) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _sorulariDisariAktar(int konuBasinaSoruSayisi) async {
    setState(() => _sorularDisariAktariliyor = true);

    late final _SoruPdfCikti pdfCikti;
    try {
      pdfCikti = await _soruPdfOlustur(
        konuBasinaSoruSayisi: konuBasinaSoruSayisi,
      );
    } catch (error) {
      debugPrint('Soru PDF oluşturma hatası: $error');
      if (!mounted) return;
      await _hesapMesajiGoster(
        context,
        'Soru PDF oluşturulamadı: ${error.runtimeType}',
      );
      if (mounted) setState(() => _sorularDisariAktariliyor = false);
      return;
    }

    try {
      await Printing.sharePdf(
        bytes: pdfCikti.bytes,
        filename: 'dgs_soru_aktarimi.pdf',
      );
      await VeritabaniYardimcisi().disariAktarilanSorulariIsaretle(
        pdfCikti.soruIdleri,
      );
    } catch (error) {
      debugPrint('Soru PDF paylaşım hatası: $error');
      if (!mounted) return;
      await _hesapMesajiGoster(
        context,
        'PDF hazırlandı ancak paylaşım ekranı açılamadı.',
      );
    } finally {
      if (mounted) setState(() => _sorularDisariAktariliyor = false);
    }
  }

  Future<_SoruPdfCikti> _soruPdfOlustur({
    required int konuBasinaSoruSayisi,
  }) async {
    final veritabaniYardimcisi = VeritabaniYardimcisi();
    final kullanici =
        widget.kullanici ?? await veritabaniYardimcisi.aktifKullaniciyiGetir();
    final kullaniciAdi = kullanici?['ad_soyad']?.toString() ?? '-';
    final olusturulmaTarihi = DateFormat(
      'dd.MM.yyyy HH:mm',
    ).format(DateTime.now());
    final logoBytes = await rootBundle.load('logo.png');
    final logo = pw.MemoryImage(logoBytes.buffer.asUint8List());
    final fontlar = await _soruPdfFontlariniYukle();
    final konular = await veritabaniYardimcisi.konulariGetir();
    final paketler = <_SoruPdfPaketi>[];
    final aktarilanSoruIdleri = <int>[];

    for (final konu in konular) {
      final konuId = konu.id;
      if (konuId == null) continue;
      final sorular = await veritabaniYardimcisi
          .disariAktarilmamisSorulariGetir(
            konuId: konuId,
            limit: konuBasinaSoruSayisi,
          );
      if (sorular.isEmpty) continue;
      paketler.add(_SoruPdfPaketi(konu: konu, sorular: sorular));
      aktarilanSoruIdleri.addAll(
        sorular.map((soru) => soru.id).whereType<int>(),
      );
    }

    if (paketler.isEmpty) {
      throw StateError('Dışarı aktarılacak soru bulunamadı.');
    }

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: fontlar.base, bold: fontlar.bold),
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(42),
        build: (context) => _soruPdfNumaraliSayfa(
          context,
          _soruPdfKapagi(
            logo: logo,
            kullaniciAdi: kullaniciAdi,
            olusturulmaTarihi: olusturulmaTarihi,
          ),
        ),
      ),
    );

    var soruNo = 1;
    for (final paket in paketler) {
      final konuOgeleri = <_SoruPdfOgesi>[];
      for (var i = 0; i < paket.sorular.length; i++) {
        konuOgeleri.add(
          _SoruPdfOgesi(
            konuAdi: paket.konu.ad,
            konuIciSira: i + 1,
            genelSira: soruNo++,
            soru: paket.sorular[i],
          ),
        );
      }

      for (var i = 0; i < konuOgeleri.length; i += 4) {
        final sayfaSorulari = konuOgeleri.skip(i).take(4).toList();
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.fromLTRB(28, 26, 28, 24),
            build: (context) =>
                _soruPdfNumaraliSayfa(context, _soruPdfSayfasi(sayfaSorulari)),
          ),
        );
      }
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 30, 32, 28),
        build: (context) =>
            _soruPdfNumaraliSayfa(context, _soruPdfCevapAnahtari(paketler)),
      ),
    );

    return _SoruPdfCikti(
      bytes: await pdf.save(),
      soruIdleri: aktarilanSoruIdleri,
    );
  }

  Future<({pw.Font base, pw.Font bold})> _soruPdfFontlariniYukle() async {
    try {
      final regular = await rootBundle.load('assets/fonts/arial.ttf');
      final bold = await rootBundle.load('assets/fonts/arialbd.ttf');
      return (base: pw.Font.ttf(regular), bold: pw.Font.ttf(bold));
    } catch (error) {
      debugPrint('Soru PDF yerel font yükleme hatası: $error');
    }

    try {
      return (
        base: await PdfGoogleFonts.openSansRegular(),
        bold: await PdfGoogleFonts.openSansBold(),
      );
    } catch (error) {
      debugPrint('Soru PDF Google font yükleme hatası: $error');
      return (base: pw.Font.helvetica(), bold: pw.Font.helveticaBold());
    }
  }

  pw.Widget _soruPdfKapagi({
    required pw.ImageProvider logo,
    required String kullaniciAdi,
    required String olusturulmaTarihi,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Expanded(
          child: pw.Center(
            child: pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Container(
                  width: 118,
                  height: 118,
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(24),
                    border: pw.Border.all(
                      color: const PdfColor.fromInt(0xFFDDE7FF),
                    ),
                  ),
                  child: pw.Image(logo, fit: pw.BoxFit.contain),
                ),
                pw.SizedBox(height: 28),
                pw.Text(
                  'DGS MATEMATİK',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    color: const PdfColor.fromInt(0xFF1E3A8A),
                    fontSize: 30,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Soru Aktarımı',
                  style: const pw.TextStyle(
                    color: PdfColor.fromInt(0xFF2563EB),
                    fontSize: 18,
                  ),
                ),
                pw.SizedBox(height: 22),
                pw.Text(
                  kullaniciAdi,
                  style: const pw.TextStyle(
                    color: PdfColor.fromInt(0xFF334155),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
        pw.Text(
          'Oluşturulduğu tarih: $olusturulmaTarihi',
          style: const pw.TextStyle(
            color: PdfColor.fromInt(0xFF64748B),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  pw.Widget _soruPdfNumaraliSayfa(pw.Context context, pw.Widget child) {
    return pw.Stack(
      children: [
        pw.Positioned.fill(child: child),
        pw.Positioned(
          right: 0,
          bottom: 0,
          child: pw.Text(
            '${context.pageNumber}',
            style: const pw.TextStyle(
              color: PdfColor.fromInt(0xFF94A3B8),
              fontSize: 9,
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _soruPdfSayfasi(List<_SoruPdfOgesi> sorular) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'DGS Matematik Soru Aktarımı',
          style: pw.TextStyle(
            color: const PdfColor.fromInt(0xFF1E3A8A),
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 10),
        for (var satir = 0; satir < 2; satir++) ...[
          pw.Expanded(
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                for (var sutun = 0; sutun < 2; sutun++) ...[
                  pw.Expanded(
                    child: _soruPdfHucresi(
                      satir * 2 + sutun < sorular.length
                          ? sorular[satir * 2 + sutun]
                          : null,
                    ),
                  ),
                  if (sutun == 0) pw.SizedBox(width: 10),
                ],
              ],
            ),
          ),
          if (satir < 1) pw.SizedBox(height: 10),
        ],
      ],
    );
  }

  pw.Widget _soruPdfHucresi(_SoruPdfOgesi? oge) {
    if (oge == null) return pw.SizedBox();

    final soru = oge.soru;
    final secenekler = [
      ('A', soru.secenekA),
      ('B', soru.secenekB),
      ('C', soru.secenekC),
      ('D', soru.secenekD),
      if (soru.secenekE.trim().isNotEmpty && soru.secenekE.trim() != '-')
        ('E', soru.secenekE),
    ];

    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: const PdfColor.fromInt(0xFFDDE7FF)),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.FittedBox(
        fit: pw.BoxFit.scaleDown,
        alignment: pw.Alignment.topLeft,
        child: pw.SizedBox(
          width: 240,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Text(
                '${oge.genelSira}. ${oge.konuAdi} | Soru ${oge.konuIciSira}',
                style: pw.TextStyle(
                  color: const PdfColor.fromInt(0xFF2563EB),
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 5),
              _pdfLatexliMetin(
                soru.gorunenMetin,
                style: const pw.TextStyle(
                  color: PdfColor.fromInt(0xFF0F172A),
                  fontSize: 10,
                  lineSpacing: 2,
                ),
              ),
              pw.SizedBox(height: 7),
              for (final secenek in secenekler)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 3),
                  child: _pdfLatexliMetin(
                    '${secenek.$1}) ${secenek.$2}',
                    style: const pw.TextStyle(
                      color: PdfColor.fromInt(0xFF334155),
                      fontSize: 9.5,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  pw.Widget _soruPdfCevapAnahtari(List<_SoruPdfPaketi> paketler) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Cevap Anahtarı',
          style: pw.TextStyle(
            color: const PdfColor.fromInt(0xFF1E3A8A),
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Expanded(
          child: pw.FittedBox(
            fit: pw.BoxFit.scaleDown,
            alignment: pw.Alignment.topLeft,
            child: pw.SizedBox(
              width: 515,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  for (final paket in paketler)
                    pw.Container(
                      width: double.infinity,
                      margin: const pw.EdgeInsets.only(bottom: 5),
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 5,
                      ),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(
                          color: const PdfColor.fromInt(0xFFDDE7FF),
                        ),
                        borderRadius: pw.BorderRadius.circular(7),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        mainAxisSize: pw.MainAxisSize.min,
                        children: [
                          pw.Text(
                            paket.konu.ad,
                            style: pw.TextStyle(
                              color: const PdfColor.fromInt(0xFF2563EB),
                              fontSize: 7.5,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 3),
                          pw.Wrap(
                            spacing: 8,
                            runSpacing: 2,
                            children: [
                              for (var i = 0; i < paket.sorular.length; i++)
                                pw.Text(
                                  'Soru ${i + 1}: ${paket.sorular[i].dogruSecenek}',
                                  style: const pw.TextStyle(
                                    color: PdfColor.fromInt(0xFF334155),
                                    fontSize: 7,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _pdfMetniTemizle(String metin) {
    return _pdfLatexMetniniDuzlestir(latexMetniniOnar(metin))
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  pw.Widget _pdfLatexliMetin(String metin, {required pw.TextStyle style}) {
    final satirlar = latexMetniniOnar(metin)
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .split(RegExp(r'\r?\n'));

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        for (var i = 0; i < satirlar.length; i++) ...[
          _pdfLatexliSatir(satirlar[i], style: style),
          if (i < satirlar.length - 1) pw.SizedBox(height: 3),
        ],
      ],
    );
  }

  pw.Widget _pdfLatexliSatir(String metin, {required pw.TextStyle style}) {
    final parcalar = _pdfMetinParcalariniAyir(metin);
    return pw.Wrap(
      spacing: 1.5,
      runSpacing: 2,
      crossAxisAlignment: pw.WrapCrossAlignment.center,
      children: [
        for (final parca in parcalar)
          if (parca.latexMi)
            _pdfLatexParcasi(parca.metin, style: style)
          else
            pw.Text(_pdfMetniTemizle(parca.metin), style: style),
      ],
    );
  }

  pw.Widget _pdfLatexParcasi(String kaynak, {required pw.TextStyle style}) {
    final svg = _pdfLatexSvgOlustur(kaynak);
    if (svg == null) {
      return pw.Text(_pdfLatexMetniniDuzlestir(kaynak), style: style);
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 0.5),
      child: pw.SvgImage(svg: svg.svg, width: svg.width, height: svg.height),
    );
  }

  _PdfLatexSvg? _pdfLatexSvgOlustur(String kaynak) {
    final texKaynak = _pdfLatexKaynaginiHazirla(kaynak);
    if (texKaynak.trim().isEmpty) return null;

    final cached = _pdfLatexCache[texKaynak];
    if (cached != null) return cached;

    final tex = TeX()
      ..scalingFactor = 1.0
      ..setColor(15, 23, 42);
    final svg = tex.tex2svg(texKaynak, displayStyle: false);
    if (!tex.success()) {
      debugPrint('TeX render hatası: ${tex.error} | $texKaynak');
      return null;
    }

    final sonuc = _PdfLatexSvg(
      svg: svg,
      width: math.max(5, tex.width.toDouble() * 0.42),
      height: math.max(5, tex.height.toDouble() * 0.42),
    );
    _pdfLatexCache[texKaynak] = sonuc;
    return sonuc;
  }

  String _pdfLatexKaynaginiHazirla(String kaynak) {
    var sonuc = kaynak
        .trim()
        .replaceAll(RegExp(r'^\$+|\$+$'), '')
        .replaceAll(RegExp(r'^\\\(|\\\)$'), '')
        .replaceAll(RegExp(r'^\\\[|\\\]$'), '');

    sonuc = sonuc.replaceAll('*', r'\cdot ');
    sonuc = sonuc.replaceAllMapped(
      RegExp(r'sqrt\s*\(([^()]+)\)'),
      (match) => '\\sqrt{${match.group(1)}}',
    );
    sonuc = sonuc.replaceAllMapped(
      RegExp(r'√\s*\(([^()]+)\)'),
      (match) => '\\sqrt{${match.group(1)}}',
    );
    sonuc = sonuc.replaceAllMapped(
      RegExp(r'√\s*([A-Za-z0-9]+)'),
      (match) => '\\sqrt{${match.group(1)}}',
    );
    sonuc = sonuc
        .replaceAll(r'\dfrac', r'\frac')
        .replaceAll(r'\tfrac', r'\frac')
        .replaceAll(r'\div', '/')
        .replaceAll(r'\leq', r'\le')
        .replaceAll(r'\geq', r'\ge')
        .replaceAll(r'\text{', r'\mathrm{')
        .replaceAllMapped(
          RegExp(r'\\text\s*\(([^()]*)\)'),
          (match) => '\\mathrm{${match.group(1)}}',
        );
    return sonuc;
  }

  List<_PdfMetinParcasi> _pdfMetinParcalariniAyir(String kaynak) {
    final parcalar = <_PdfMetinParcasi>[];
    final buffer = StringBuffer();
    var latexMi = false;

    void flush() {
      if (buffer.isEmpty) return;
      final metin = buffer.toString();
      if (latexMi) {
        parcalar.add(_PdfMetinParcasi(metin, true));
      } else {
        parcalar.addAll(_pdfDuzMetinParcalariniAyir(metin));
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

    return parcalar.isEmpty ? [_PdfMetinParcasi(kaynak, false)] : parcalar;
  }

  List<_PdfMetinParcasi> _pdfDuzMetinParcalariniAyir(String kaynak) {
    final parcalar = <_PdfMetinParcasi>[];
    final tokenlar = RegExp(r'\s+|\S+').allMatches(kaynak).map((m) {
      return m.group(0) ?? '';
    }).toList();
    final matematikMi = List<bool>.filled(tokenlar.length, false);

    for (var i = 0; i < tokenlar.length; i++) {
      final token = tokenlar[i];
      if (token.trim().isEmpty) continue;
      matematikMi[i] = _pdfTokenMatematikMi(token);
    }

    for (var i = 0; i < tokenlar.length; i++) {
      final token = tokenlar[i];
      if (token.trim().isEmpty || matematikMi[i]) continue;

      final onceki = _pdfOncekiDoluTokenIndeksi(tokenlar, i);
      final sonraki = _pdfSonrakiDoluTokenIndeksi(tokenlar, i);
      final operatorYaninda =
          (onceki != null && _pdfTokenOperatorMu(tokenlar[onceki])) ||
          (sonraki != null && _pdfTokenOperatorMu(tokenlar[sonraki]));

      if (operatorYaninda && _pdfTokenMatematikTerimiMi(token)) {
        matematikMi[i] = true;
      }
    }

    final mathBuffer = StringBuffer();
    final textBuffer = StringBuffer();

    void flushMath() {
      if (mathBuffer.isEmpty) return;
      parcalar.add(_PdfMetinParcasi(mathBuffer.toString().trim(), true));
      mathBuffer.clear();
    }

    void flushText() {
      if (textBuffer.isEmpty) return;
      parcalar.add(_PdfMetinParcasi(textBuffer.toString(), false));
      textBuffer.clear();
    }

    for (var i = 0; i < tokenlar.length; i++) {
      final token = tokenlar[i];
      if (token.trim().isEmpty) {
        final sonraki = _pdfSonrakiDoluTokenIndeksi(tokenlar, i);
        if (mathBuffer.isNotEmpty && sonraki != null && matematikMi[sonraki]) {
          mathBuffer.write(' ');
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

  bool _pdfTokenMatematikMi(String token) {
    final temiz = _pdfTokenTemizle(token);
    if (temiz.isEmpty) return false;
    if (RegExp(r'^[A-E]\)$').hasMatch(temiz)) return false;
    if (temiz.startsWith(r'\')) return true;
    if (RegExp(r'[\^_=<>+\-*/(){}√]').hasMatch(temiz)) return true;
    if (RegExp(r'\d+[A-Za-z]+|[A-Za-z]+\d+').hasMatch(temiz)) return true;
    return false;
  }

  bool _pdfTokenMatematikTerimiMi(String token) {
    final temiz = _pdfTokenTemizle(token);
    if (temiz.isEmpty) return false;
    if (RegExp(r'^[A-E]\)$').hasMatch(temiz)) return false;
    return RegExp(
      r'^[A-Za-zÇĞİÖŞÜçğıöşü]$|^-?\d+(?:[,.]\d+)?$',
    ).hasMatch(temiz);
  }

  bool _pdfTokenOperatorMu(String token) {
    final temiz = _pdfTokenTemizle(token);
    return temiz.startsWith(r'\') ||
        RegExp(r'^[\^_=<>+\-*/(){}[\]|√]+$').hasMatch(temiz) ||
        RegExp(r'[\^_=<>+\-*/(){}[\]|√]').hasMatch(temiz);
  }

  String _pdfTokenTemizle(String token) {
    return token.trim().replaceAll(RegExp(r'^[,.;:!?]+|[,.;:!?]+$'), '');
  }

  int? _pdfOncekiDoluTokenIndeksi(List<String> tokenlar, int indeks) {
    for (var i = indeks - 1; i >= 0; i--) {
      if (tokenlar[i].trim().isNotEmpty) return i;
    }
    return null;
  }

  int? _pdfSonrakiDoluTokenIndeksi(List<String> tokenlar, int indeks) {
    for (var i = indeks + 1; i < tokenlar.length; i++) {
      if (tokenlar[i].trim().isNotEmpty) return i;
    }
    return null;
  }

  String _pdfLatexMetniniDuzlestir(String metin) {
    var sonuc = metin
        .replaceAll(RegExp(r'\$+'), ' ')
        .replaceAll(RegExp(r'\\\(|\\\)|\\\[|\\\]'), ' ')
        .replaceAll(RegExp(r'\\begin\{[^}]+\}|\\end\{[^}]+\}'), ' ')
        .replaceAll(RegExp(r'\\left|\\right'), ' ')
        .replaceAll(RegExp(r'\\displaystyle|\\textstyle'), ' ');

    for (var i = 0; i < 4; i++) {
      sonuc = sonuc.replaceAllMapped(
        RegExp(r'\\(?:dfrac|tfrac|frac)\s*\{([^{}]+)\}\s*\{([^{}]+)\}'),
        (match) =>
            '(${_pdfLatexMetniniDuzlestir(match.group(1) ?? '')})/'
            '(${_pdfLatexMetniniDuzlestir(match.group(2) ?? '')})',
      );
      sonuc = sonuc.replaceAllMapped(
        RegExp(r'\\sqrt\s*\{([^{}]+)\}'),
        (match) => 'sqrt(${_pdfLatexMetniniDuzlestir(match.group(1) ?? '')})',
      );
      sonuc = sonuc.replaceAllMapped(
        RegExp(r'\^\s*\{([^{}]+)\}'),
        (match) => '^${_pdfLatexMetniniDuzlestir(match.group(1) ?? '')}',
      );
      sonuc = sonuc.replaceAllMapped(
        RegExp(r'_\s*\{([^{}]+)\}'),
        (match) => '_${_pdfLatexMetniniDuzlestir(match.group(1) ?? '')}',
      );
      sonuc = sonuc.replaceAllMapped(
        RegExp(r'\\text\s*\{([^{}]+)\}'),
        (match) => match.group(1) ?? '',
      );
    }

    return sonuc
        .replaceAll('&', ' ')
        .replaceAll('\\\\', ' ')
        .replaceAll('\\times', '*')
        .replaceAll('\\cdot', '*')
        .replaceAll('\\div', '/')
        .replaceAll('\\leq', '<=')
        .replaceAll('\\geq', '>=')
        .replaceAll('\\neq', '!=')
        .replaceAll('\\pm', '+/-')
        .replaceAll('\\mp', '-/+')
        .replaceAll('\\pi', 'pi')
        .replaceAll('\\alpha', 'alpha')
        .replaceAll('\\beta', 'beta')
        .replaceAll('\\Delta', 'Delta')
        .replaceAll('\\Omega', 'Omega')
        .replaceAll(RegExp(r'\\[a-zA-Z]+'), '')
        .replaceAll('{', '(')
        .replaceAll('}', ')');
  }

  @override
  Widget build(BuildContext context) {
    final adminMi = widget.kullanici?['rol'] == 'admin';

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: true,
        title: const Text('Ayarlar'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            _AyarSatiri(
              icon: Icons.manage_accounts_outlined,
              title: 'Hesap Ayarları',
              trailing: Icon(
                _hesapAyarlariAcik
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: _text,
              ),
              onTap: widget.kullanici == null
                  ? null
                  : () {
                      setState(() {
                        _hesapAyarlariAcik = !_hesapAyarlariAcik;
                      });
                    },
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: _AyarAltKarti(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Kullanıcı adını, şifreyi ve hesap silme işlemini buradan yönetebilirsin.',
                        style: TextStyle(color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _hesapAyarlariniAc(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Hesap Bilgilerini Düzenle'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              crossFadeState: _hesapAyarlariAcik
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 180),
            ),
            const SizedBox(height: 10),
            _AyarSatiri(
              icon: Icons.upload_file_outlined,
              title: _sorularDisariAktariliyor
                  ? 'Dışarı Soru Aktar hazırlanıyor...'
                  : 'Dışarı Soru Aktar',
              trailing: _sorularDisariAktariliyor
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _soruAktarAcik
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: _text,
                    ),
              onTap: _sorularDisariAktariliyor
                  ? null
                  : () {
                      setState(() {
                        _soruAktarAcik = !_soruAktarAcik;
                      });
                    },
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: _AyarAltKarti(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Konu başına kaç soru aktarılacağını seç. Daha önce dışarı aktarılan sorular tekrar PDF’ye eklenmez.',
                        style: TextStyle(color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final sayi in const [5, 10, 20])
                            ChoiceChip(
                              label: Text('$sayi soru'),
                              selected: _disariAktarSoruSayisi == sayi,
                              onSelected: _sorularDisariAktariliyor
                                  ? null
                                  : (_) {
                                      setState(() {
                                        _disariAktarSoruSayisi = sayi;
                                      });
                                    },
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _sorularDisariAktariliyor
                              ? null
                              : () => _sorulariDisariAktar(
                                  _disariAktarSoruSayisi,
                                ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: _sorularDisariAktariliyor
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.picture_as_pdf_outlined),
                          label: Text(
                            _sorularDisariAktariliyor
                                ? 'PDF hazırlanıyor...'
                                : 'PDF Olarak Dışarı Aktar',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              crossFadeState: _soruAktarAcik
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 180),
            ),
            const SizedBox(height: 10),
            _AyarSatiri(
              icon: Icons.analytics_outlined,
              title: 'Veri ve İstatistik',
              onTap: () async {
                final yenile = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        _VeriIstatistikEkrani(kullanici: widget.kullanici),
                  ),
                );
                if (!context.mounted) return;
                if (yenile == true) Navigator.pop(context, true);
              },
            ),
            if (adminMi) ...[
              const SizedBox(height: 10),
              _AyarSatiri(
                icon: Icons.admin_panel_settings_outlined,
                title: 'Admin Ayarları',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminAyarlariEkrani(),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            _AyarSatiri(
              icon: Icons.history,
              title: 'Geçmiş Denemeler',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const _GecmisDenemelerEkrani(),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _AyarSatiri(
              icon: Icons.help_outline,
              title: 'Yardım ve Destek',
              onTap: () => _yardimMailiniAc(context),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _cikisYap(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _danger,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.logout),
                label: const Text('Çıkış Yap'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SoruPdfPaketi {
  final Konu konu;
  final List<Soru> sorular;

  const _SoruPdfPaketi({required this.konu, required this.sorular});
}

class _SoruPdfCikti {
  final Uint8List bytes;
  final List<int> soruIdleri;

  const _SoruPdfCikti({required this.bytes, required this.soruIdleri});
}

class _SoruPdfOgesi {
  final String konuAdi;
  final int konuIciSira;
  final int genelSira;
  final Soru soru;

  const _SoruPdfOgesi({
    required this.konuAdi,
    required this.konuIciSira,
    required this.genelSira,
    required this.soru,
  });
}

class _PdfLatexSvg {
  final String svg;
  final double width;
  final double height;

  const _PdfLatexSvg({
    required this.svg,
    required this.width,
    required this.height,
  });
}

class _PdfMetinParcasi {
  final String metin;
  final bool latexMi;

  const _PdfMetinParcasi(this.metin, this.latexMi);
}

class _AyarSatiri extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _AyarSatiri({
    required this.icon,
    required this.title,
    this.onTap,
    this.trailing,
  });

  static const Color _primary = Color(0xFF2563EB);
  static const Color _text = Color(0xFF1E3A8A);

  @override
  Widget build(BuildContext context) {
    final aktifMi = onTap != null;

    return Opacity(
      opacity: aktifMi ? 1 : 0.55,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFDDE7FF)),
            ),
            child: Row(
              children: [
                Icon(icon, color: _primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: _text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                trailing ??
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: Color(0xFF64748B),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AyarAltKarti extends StatelessWidget {
  final Widget child;

  const _AyarAltKarti({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDE7FF)),
      ),
      child: child,
    );
  }
}

class _GecmisDenemelerEkrani extends StatelessWidget {
  const _GecmisDenemelerEkrani();

  static const Color _bg = Color(0xFFF4F8FF);
  static const Color _text = Color(0xFF1E3A8A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: true,
        title: const Text('Geçmiş Denemeler'),
      ),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: VeritabaniYardimcisi()
            .aktifKullaniciDenemeIstatistikleriniGetir(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final denemeler = snapshot.data ?? const <Map<String, Object?>>[];
          if (denemeler.isEmpty) {
            return const Center(
              child: Text(
                'Henüz tamamlanmış deneme sınavı yok.',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            itemCount: denemeler.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final deneme = denemeler[index];
              final toplam = _intDegeriStatik(deneme['toplam_soru_sayisi']);
              final dogru = _intDegeriStatik(deneme['dogru_sayisi']);
              final yanlis = _intDegeriStatik(deneme['yanlis_sayisi']);
              final bos = _intDegeriStatik(deneme['bos_sayisi']);
              final tarih = _kisaTarihStatik(
                deneme['olusturulma_tarihi']?.toString(),
              );

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFDDE7FF)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            deneme['deneme_adi']?.toString() ?? '-',
                            style: const TextStyle(
                              color: _text,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          tarih,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _DenemeOzetRozeti('Toplam', '$toplam'),
                        _DenemeOzetRozeti('Doğru', '$dogru'),
                        _DenemeOzetRozeti('Yanlış', '$yanlis'),
                        _DenemeOzetRozeti('Boş', '$bos'),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _DenemeOzetRozeti extends StatelessWidget {
  final String label;
  final String value;

  const _DenemeOzetRozeti(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: Color(0xFF1E3A8A),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

int _intDegeriStatik(Object? deger) {
  if (deger is int) return deger;
  if (deger is num) return deger.toInt();
  return int.tryParse(deger?.toString() ?? '') ?? 0;
}

String _kisaTarihStatik(String? isoTarih) {
  if (isoTarih == null || isoTarih.length < 10) return '-';
  final tarih = DateTime.tryParse(isoTarih);
  if (tarih == null) return isoTarih;
  return DateFormat('dd.MM.yyyy').format(tarih);
}

class _VeriIstatistikEkrani extends StatefulWidget {
  final Map<String, Object?>? kullanici;

  const _VeriIstatistikEkrani({required this.kullanici});

  @override
  State<_VeriIstatistikEkrani> createState() => _VeriIstatistikEkraniDurumu();
}

class _VeriIstatistikEkraniDurumu extends State<_VeriIstatistikEkrani> {
  final _veritabaniYardimcisi = VeritabaniYardimcisi();
  bool _pdfHazirlaniyor = false;
  bool _ilerlemeSiliniyor = false;
  String? _hazirlananRapor;

  static const Color _bg = Color(0xFFF4F8FF);
  static const Color _primary = Color(0xFF2563EB);
  static const Color _danger = Color(0xFFDC2626);

  Future<void> _ilerlemeDurumunuSil() async {
    final sifre = await _ilerlemeSilmeOnayiniGoster();
    if (sifre == null || !mounted) return;
    if (sifre.isEmpty) {
      await _hesapMesajiGoster(context, 'Åžifre alanÄ± zorunludur.');
      return;
    }

    final sifreDogruMu = await _sifreyiDogrula(sifre);
    if (!mounted) return;
    if (!sifreDogruMu) {
      await _hesapMesajiGoster(context, 'Åžifre hatalÄ±. Ä°lerleme silinmedi.');
      return;
    }

    setState(() => _ilerlemeSiliniyor = true);
    try {
      await _veritabaniYardimcisi.aktifKullaniciIstatistikleriniSifirla();
    } catch (error) {
      debugPrint('Ä°lerleme durumu silme hatasÄ±: $error');
      if (!mounted) return;
      setState(() => _ilerlemeSiliniyor = false);
      await _hesapMesajiGoster(
        context,
        'Ä°lerleme durumu silinemedi: ${error.runtimeType}',
      );
      return;
    }

    if (!mounted) return;
    setState(() => _ilerlemeSiliniyor = false);
    await _hesapMesajiGoster(context, 'Ä°lerleme durumu silindi.');
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<String?> _ilerlemeSilmeOnayiniGoster() async {
    final sifreKontrolcusu = TextEditingController();
    try {
      return showDialog<String>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Ä°lerleme Durumunu Sil'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Ã‡Ã¶zÃ¼len soru kayÄ±tlarÄ±, deneme kayÄ±tlarÄ±, istatistikler ve grafik verileri silinecek. Hesap bilgilerin korunacak.',
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: sifreKontrolcusu,
                  autofocus: true,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Åžifre',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  onSubmitted: (_) =>
                      Navigator.pop(context, sifreKontrolcusu.text),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 46),
                    ),
                    child: const Text('VazgeÃ§'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () =>
                        Navigator.pop(context, sifreKontrolcusu.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _danger,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 46),
                    ),
                    child: const Text('Sil'),
                  ),
                ),
              ],
            ),
          );
        },
      );
    } finally {
      sifreKontrolcusu.dispose();
    }
  }

  Future<bool> _sifreyiDogrula(String sifre) async {
    final yerelSifreDogruMu = await _veritabaniYardimcisi
        .aktifKullaniciSifresiDogruMu(sifre);
    if (yerelSifreDogruMu) return true;

    final kullanici =
        widget.kullanici ?? await _veritabaniYardimcisi.aktifKullaniciyiGetir();
    final email = kullanici?['email']?.toString() ?? '';
    if (email.isEmpty) return false;
    return ApiServisi().girisYap(eposta: email, sifre: sifre);
  }

  // ignore: unused_element
  Future<void> _eskiIlerlemeDurumunuSil() async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('İlerleme Durumunu Sil'),
          content: const Text(
            'Çözülen soru kayıtları, deneme kayıtları, istatistikler ve grafik verileri silinecek. Hesap bilgilerin korunacak. Devam etmek istiyor musun?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Vazgeç'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _danger,
                foregroundColor: Colors.white,
              ),
              child: const Text('Sil'),
            ),
          ],
        );
      },
    );
    if (onay != true || !mounted) return;

    setState(() => _ilerlemeSiliniyor = true);
    try {
      await _veritabaniYardimcisi.aktifKullaniciIstatistikleriniSifirla();
    } catch (error) {
      debugPrint('İlerleme durumu silme hatası: $error');
      if (!mounted) return;
      setState(() => _ilerlemeSiliniyor = false);
      await _hesapMesajiGoster(
        context,
        'İlerleme durumu silinemedi: ${error.runtimeType}',
      );
      return;
    }

    if (!mounted) return;
    setState(() => _ilerlemeSiliniyor = false);
    await _hesapMesajiGoster(context, 'İlerleme durumu silindi.');
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _pdfDisariAktar({required bool son30Gun}) async {
    final raporAdi = son30Gun ? '30 Günlük Rapor' : 'Tüm Zamanlar Raporu';
    setState(() {
      _pdfHazirlaniyor = true;
      _hazirlananRapor = raporAdi;
    });
    late final Uint8List pdfBytes;
    try {
      pdfBytes = await _istatistikPdfOlustur(son30Gun: son30Gun);
    } catch (error) {
      debugPrint('PDF oluşturma hatası: $error');
      if (!mounted) return;
      await _hesapMesajiGoster(
        context,
        'PDF oluşturulamadı: ${error.runtimeType}',
      );
      if (mounted) setState(() => _pdfHazirlaniyor = false);
      return;
    }

    try {
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: son30Gun
            ? 'dgs_30_gunluk_istatistik_raporu.pdf'
            : 'dgs_tum_zamanlar_istatistik_raporu.pdf',
      );
    } catch (error) {
      debugPrint('PDF paylaşım hatası: $error');
      if (!mounted) return;
      await _hesapMesajiGoster(
        context,
        'PDF hazırlandı ancak paylaşım ekranı açılamadı.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _pdfHazirlaniyor = false;
          _hazirlananRapor = null;
        });
      }
    }
  }

  Future<Uint8List> _istatistikPdfOlustur({required bool son30Gun}) async {
    final kullanici =
        widget.kullanici ?? await _veritabaniYardimcisi.aktifKullaniciyiGetir();
    final username = kullanici?['ad_soyad']?.toString() ?? '-';
    final gunSayisi = son30Gun ? 30 : 3650;
    final raporBasligi = son30Gun ? 'Son 30 Gün Raporu' : 'Tüm Zamanlar Raporu';
    final istatistikler = await _veritabaniYardimcisi
        .aktifKullaniciIstatistikleriniGetir();
    final gunlukIstatistikler = await _veritabaniYardimcisi
        .aktifKullaniciGunlukIstatistikleriniGetir(gunSayisi: gunSayisi);
    final konuIstatistikleri = await _veritabaniYardimcisi
        .aktifKullaniciKonuIstatistikleriniGetir();
    final konuGunlukIstatistikleri = await _veritabaniYardimcisi
        .aktifKullaniciKonuGunlukIstatistikleriniGetir(gunSayisi: gunSayisi);
    final denemeIstatistikleri = await _veritabaniYardimcisi
        .aktifKullaniciDenemeIstatistikleriniGetir(
          gunSayisi: son30Gun ? 30 : null,
        );
    final genelGrafikVerileri = son30Gun
        ? _gunlukVerileriTamamla(gunlukIstatistikler, 30)
        : gunlukIstatistikler;
    final logoBytes = await rootBundle.load('logo.png');
    final logo = pw.MemoryImage(logoBytes.buffer.asUint8List());
    final fontlar = await _pdfFontlariniYukle();
    final olusturulmaTarihi = DateFormat(
      'dd.MM.yyyy HH:mm',
    ).format(DateTime.now());

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: fontlar.base, bold: fontlar.bold),
    );
    final pageFormat = son30Gun ? PdfPageFormat.a4 : PdfPageFormat.a4.landscape;

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.zero,
        build: (context) => _pdfDesenliSayfa(
          pw.Stack(
            children: [
              pw.Positioned(
                top: 92,
                left: 0,
                right: 0,
                child: pw.Column(
                  children: [
                    pw.Container(
                      width: 96,
                      height: 96,
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        borderRadius: pw.BorderRadius.circular(22),
                        border: pw.Border.all(
                          color: PdfColor.fromInt(0x4CC4C6CF),
                        ),
                      ),
                      child: pw.Image(logo, fit: pw.BoxFit.contain),
                    ),
                    pw.SizedBox(height: 18),
                    pw.Text(
                      'DGS MATEMATİK',
                      style: pw.TextStyle(
                        color: PdfColor.fromInt(0xFF002045),
                        fontSize: 28,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'SORU BANKASI',
                      style: pw.TextStyle(
                        color: PdfColor.fromInt(0xFF002045),
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              pw.Center(
                child: pw.Column(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.Text(
                      raporBasligi,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        color: PdfColor.fromInt(0xFF2563EB),
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 14),
                    pw.Text(
                      username,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        color: PdfColor.fromInt(0xFF1E3A8A),
                        fontSize: 30,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              pw.Positioned(
                bottom: 46,
                left: 0,
                right: 0,
                child: pw.Text(
                  'Oluşturulma tarihi: $olusturulmaTarihi',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(
                    color: PdfColor.fromInt(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(34),
        build: (context) => [
          _pdfBaslik('Konu Bazlı Çizgi Grafikler'),
          pw.SizedBox(height: 8),
          _pdfLejant([
            _PdfLejant('Doğru', PdfColor.fromInt(0xFF16A34A)),
            _PdfLejant('Yanlış', PdfColor.fromInt(0xFFDC2626)),
            _PdfLejant('Boş', PdfColor.fromInt(0xFFF59E0B)),
          ]),
          pw.SizedBox(height: 16),
          ..._pdfKonuCizgiGrafikleri(
            konuIstatistikleri,
            konuGunlukIstatistikleri,
            pageFormat: pageFormat,
            son30Gun: son30Gun,
          ),
        ],
      ),
    );

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.zero,
        build: (context) => _pdfDesenliSayfa(
          pw.Padding(
            padding: const pw.EdgeInsets.all(34),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _pdfBaslik(
                  son30Gun
                      ? 'Son 30 Günde Yapılan Deneme Sınavları'
                      : 'Tüm Deneme Sınavları',
                ),
                pw.SizedBox(height: 8),
                _pdfLejant([
                  _PdfLejant('Doğru', PdfColor.fromInt(0xFF16A34A)),
                  _PdfLejant('Yanlış', PdfColor.fromInt(0xFFDC2626)),
                  _PdfLejant('Boş', PdfColor.fromInt(0xFFF59E0B)),
                ]),
                pw.SizedBox(height: 18),
                _pdfDenemeCizgiGrafigi(
                  denemeIstatistikleri,
                  pageFormat: pageFormat,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.zero,
        build: (context) => _pdfDesenliSayfa(
          pw.Padding(
            padding: const pw.EdgeInsets.all(34),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _pdfBaslik('Genel Çizgi Grafik'),
                pw.SizedBox(height: 8),
                _pdfOzetSatiri(istatistikler),
                pw.SizedBox(height: 18),
                _pdfCizgiGrafigi(genelGrafikVerileri, pageFormat: pageFormat),
                pw.SizedBox(height: 10),
                _pdfLejant([
                  _PdfLejant('Doğru', PdfColor.fromInt(0xFF16A34A)),
                  _PdfLejant('Yanlış', PdfColor.fromInt(0xFFDC2626)),
                  _PdfLejant('Boş', PdfColor.fromInt(0xFFF59E0B)),
                ]),
              ],
            ),
          ),
        ),
      ),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(34),
        build: (context) => [
          _pdfBaslik('Konu Sayısal Tablosu'),
          pw.SizedBox(height: 16),
          _pdfKonuTablosu(konuIstatistikleri),
        ],
      ),
    );

    return pdf.save();
  }

  Future<({pw.Font base, pw.Font bold})> _pdfFontlariniYukle() async {
    try {
      final regular = await rootBundle.load('assets/fonts/arial.ttf');
      final bold = await rootBundle.load('assets/fonts/arialbd.ttf');
      return (base: pw.Font.ttf(regular), bold: pw.Font.ttf(bold));
    } catch (error) {
      debugPrint('PDF yerel font yükleme hatası: $error');
    }

    try {
      return (
        base: await PdfGoogleFonts.openSansRegular(),
        bold: await PdfGoogleFonts.openSansBold(),
      );
    } catch (error) {
      debugPrint('PDF Google font yükleme hatası: $error');
      return (base: pw.Font.helvetica(), bold: pw.Font.helveticaBold());
    }
  }

  pw.Widget _pdfDesenliSayfa(pw.Widget child) {
    return pw.Stack(
      children: [
        pw.Positioned.fill(child: _pdfArkaPlan()),
        pw.Positioned.fill(child: child),
      ],
    );
  }

  pw.Widget _pdfArkaPlan() {
    return pw.CustomPaint(
      size: const PdfPoint(841.89, 595.28),
      painter: (canvas, size) {
        canvas
          ..setStrokeColor(PdfColor.fromInt(0x07E2E8F0))
          ..setLineWidth(1);
        for (var x = 0.0; x <= size.x; x += 40) {
          canvas.drawLine(x, 0, x, size.y);
        }
        for (var y = 0.0; y <= size.y; y += 40) {
          canvas.drawLine(0, y, size.x, y);
        }
        canvas.strokePath();

        canvas
          ..setStrokeColor(PdfColor.fromInt(0x0D138BED))
          ..setLineWidth(2)
          ..drawRect(-28, 72, 130, 130)
          ..strokePath();
        canvas
          ..setStrokeColor(PdfColor.fromInt(0x08002045))
          ..setLineWidth(24)
          ..drawEllipse(size.x - 175, size.y - 175, 220, 220)
          ..strokePath();
        canvas
          ..setStrokeColor(PdfColor.fromInt(0x0A2563EB))
          ..setLineWidth(14)
          ..drawEllipse(size.x - 86, 38, 118, 118)
          ..strokePath();
        canvas
          ..setStrokeColor(PdfColor.fromInt(0x0A138BED))
          ..setLineWidth(1.5)
          ..drawRect(size.x * 0.58, size.y - 95, 76, 76)
          ..strokePath();
      },
    );
  }

  pw.Widget _pdfBaslik(String metin) {
    return pw.Text(
      metin,
      style: pw.TextStyle(
        color: PdfColor.fromInt(0xFF1E3A8A),
        fontSize: 20,
        fontWeight: pw.FontWeight.bold,
      ),
    );
  }

  pw.Widget _pdfOzetSatiri(Map<String, int> istatistikler) {
    final toplam = istatistikler['toplam'] ?? 0;
    final dogru = istatistikler['dogru'] ?? 0;
    final yanlis = istatistikler['yanlis'] ?? 0;
    final bos = istatistikler['bos'] ?? 0;
    return pw.Row(
      children: [
        _pdfOzetKutusu(
          'Toplam',
          toplam.toString(),
          PdfColor.fromInt(0xFF2563EB),
        ),
        pw.SizedBox(width: 10),
        _pdfOzetKutusu('Doğru', dogru.toString(), PdfColor.fromInt(0xFF16A34A)),
        pw.SizedBox(width: 10),
        _pdfOzetKutusu(
          'Yanlış',
          yanlis.toString(),
          PdfColor.fromInt(0xFFDC2626),
        ),
        pw.SizedBox(width: 10),
        _pdfOzetKutusu('Boş', bos.toString(), PdfColor.fromInt(0xFFF59E0B)),
      ],
    );
  }

  pw.Widget _pdfOzetKutusu(String baslik, String deger, PdfColor renk) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          borderRadius: pw.BorderRadius.circular(12),
          border: pw.Border.all(color: PdfColor.fromInt(0xFFDDE7FF)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(baslik, style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 4),
            pw.Text(
              deger,
              style: pw.TextStyle(
                color: renk,
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _pdfCizgiGrafigi(
    List<Map<String, Object?>> gunlukVeriler, {
    required PdfPageFormat pageFormat,
  }) {
    final veriler = gunlukVeriler.toList();
    final maxY = _pdfGrafikUstSiniri(
      1,
      veriler.fold<int>(0, (max, satir) {
        return [
          max,
          _intDegeri(satir['dogru']),
          _intDegeri(satir['yanlis']),
          _intDegeri(satir['bos']),
        ].reduce(math.max);
      }),
    );
    final chartHeight = pageFormat.width < pageFormat.height ? 250.0 : 300.0;

    return pw.Container(
      height: chartHeight,
      padding: const pw.EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(14),
        border: pw.Border.all(color: PdfColor.fromInt(0xFFDDE7FF)),
      ),
      child: pw.Column(
        children: [
          pw.Expanded(
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                _pdfSayisalEksen(maxY),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: pw.CustomPaint(
                    size: const PdfPoint(720, 230),
                    painter: (canvas, size) {
                      _pdfGridCiz(canvas, size);
                      if (veriler.isEmpty) return;
                      _pdfSeriCiz(
                        canvas,
                        size,
                        veriler,
                        'dogru',
                        maxY,
                        PdfColor.fromInt(0xFF16A34A),
                      );
                      _pdfSeriCiz(
                        canvas,
                        size,
                        veriler,
                        'yanlis',
                        maxY,
                        PdfColor.fromInt(0xFFDC2626),
                      );
                      _pdfSeriCiz(
                        canvas,
                        size,
                        veriler,
                        'bos',
                        maxY,
                        PdfColor.fromInt(0xFFF59E0B),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 4),
          _pdfTarihAraligi(veriler),
        ],
      ),
    );
  }

  pw.Widget _pdfDenemeCizgiGrafigi(
    List<Map<String, Object?>> denemeVerileri, {
    required PdfPageFormat pageFormat,
  }) {
    if (denemeVerileri.isEmpty) {
      return pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          borderRadius: pw.BorderRadius.circular(14),
          border: pw.Border.all(color: PdfColor.fromInt(0xFFDDE7FF)),
        ),
        child: pw.Text('Deneme sınavı kaydı bulunamadı.'),
      );
    }

    final veriler = denemeVerileri.map((satir) {
      return <String, Object?>{
        'etiket': satir['deneme_adi']?.toString() ?? '-',
        'dogru': _intDegeri(satir['dogru_sayisi']),
        'yanlis': _intDegeri(satir['yanlis_sayisi']),
        'bos': _intDegeri(satir['bos_sayisi']),
      };
    }).toList();
    final maxY = _pdfGrafikUstSiniri(
      1,
      veriler.fold<int>(0, (max, satir) {
        return [
          max,
          _intDegeri(satir['dogru']),
          _intDegeri(satir['yanlis']),
          _intDegeri(satir['bos']),
        ].reduce(math.max);
      }),
    );
    final chartHeight = pageFormat.width < pageFormat.height ? 250.0 : 300.0;

    return pw.Container(
      height: chartHeight,
      padding: const pw.EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(14),
        border: pw.Border.all(color: PdfColor.fromInt(0xFFDDE7FF)),
      ),
      child: pw.Column(
        children: [
          pw.Expanded(
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                _pdfSayisalEksen(maxY),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: pw.CustomPaint(
                    size: const PdfPoint(720, 230),
                    painter: (canvas, size) {
                      _pdfGridCiz(canvas, size);
                      _pdfSeriCiz(
                        canvas,
                        size,
                        veriler,
                        'dogru',
                        maxY,
                        PdfColor.fromInt(0xFF16A34A),
                      );
                      _pdfSeriCiz(
                        canvas,
                        size,
                        veriler,
                        'yanlis',
                        maxY,
                        PdfColor.fromInt(0xFFDC2626),
                      );
                      _pdfSeriCiz(
                        canvas,
                        size,
                        veriler,
                        'bos',
                        maxY,
                        PdfColor.fromInt(0xFFF59E0B),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 4),
          _pdfDenemeEtiketleri(veriler),
        ],
      ),
    );
  }

  List<pw.Widget> _pdfKonuCizgiGrafikleri(
    List<Map<String, Object?>> konuVerileri,
    List<Map<String, Object?>> konuGunlukVerileri, {
    required PdfPageFormat pageFormat,
    required bool son30Gun,
  }) {
    final widgets = <pw.Widget>[];
    for (final konu in konuVerileri) {
      final konuId = _intDegeri(konu['konu_id']);
      final gunler = konuGunlukVerileri
          .where((satir) => _intDegeri(satir['konu_id']) == konuId)
          .toList();
      final grafikVerileri = son30Gun
          ? _gunlukVerileriTamamla(gunler, 30)
          : gunler;

      widgets.add(
        pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 18),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                '${konu['konu_adi'] ?? '-'}',
                style: pw.TextStyle(
                  color: PdfColor.fromInt(0xFF1E3A8A),
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              pw.SizedBox(height: 6),
              _pdfCizgiGrafigi(grafikVerileri, pageFormat: pageFormat),
            ],
          ),
        ),
      );
    }
    if (widgets.isEmpty) {
      widgets.add(pw.Text('Konu bazlı çözüm kaydı bulunamadı.'));
    }
    return widgets;
  }

  pw.Widget _pdfKonuTablosu(List<Map<String, Object?>> konuVerileri) {
    final rows = konuVerileri.map((satir) {
      return [
        satir['konu_adi']?.toString() ?? '-',
        _intDegeri(satir['toplam']).toString(),
        _intDegeri(satir['dogru']).toString(),
        _intDegeri(satir['yanlis']).toString(),
        _intDegeri(satir['bos']).toString(),
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: const ['Konu', 'Toplam', 'Doğru', 'Yanlış', 'Boş'],
      data: rows,
      headerStyle: pw.TextStyle(
        color: PdfColors.white,
        fontWeight: pw.FontWeight.bold,
      ),
      headerDecoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFF2563EB)),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignment: pw.Alignment.centerLeft,
      cellAlignments: const {
        1: pw.Alignment.center,
        2: pw.Alignment.center,
        3: pw.Alignment.center,
        4: pw.Alignment.center,
      },
      oddRowDecoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFFF8FAFC)),
      border: pw.TableBorder.all(color: PdfColor.fromInt(0xFFE2E8F0)),
    );
  }

  pw.Widget _pdfLejant(List<_PdfLejant> items) {
    return pw.Row(
      children: [
        for (final item in items) ...[
          pw.Container(width: 10, height: 10, color: item.renk),
          pw.SizedBox(width: 5),
          pw.Text(item.label, style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(width: 14),
        ],
      ],
    );
  }

  pw.Widget _pdfSayisalEksen(int maxY) {
    return pw.SizedBox(
      width: 28,
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text('$maxY', style: const pw.TextStyle(fontSize: 8)),
          pw.Text(
            '${(maxY / 2).round()}',
            style: const pw.TextStyle(fontSize: 8),
          ),
          pw.Text('0', style: const pw.TextStyle(fontSize: 8)),
        ],
      ),
    );
  }

  int _pdfGrafikUstSiniri(int minimum, int enYuksekDeger) {
    final hedef = math.max(minimum, (enYuksekDeger * 1.12).ceil());
    if (hedef <= 5) return 5;

    final hedefAralik = hedef / 4;
    final kuvvet = math.pow(10, (math.log(hedefAralik) / math.ln10).floor());
    final normal = hedefAralik / kuvvet;
    final katsayi = normal <= 1
        ? 1
        : normal <= 2
        ? 2
        : normal <= 5
        ? 5
        : 10;
    final aralik = (katsayi * kuvvet).toInt();
    return ((hedef / aralik).ceil() * aralik).toInt();
  }

  pw.Widget _pdfTarihAraligi(List<Map<String, Object?>> veriler) {
    if (veriler.isEmpty) return pw.SizedBox.shrink();
    final ilk = _kisaTarih(veriler.first['gun']?.toString());
    final son = _kisaTarih(veriler.last['gun']?.toString());
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(ilk, style: const pw.TextStyle(fontSize: 8)),
        pw.Text(son, style: const pw.TextStyle(fontSize: 8)),
      ],
    );
  }

  pw.Widget _pdfDenemeEtiketleri(List<Map<String, Object?>> veriler) {
    if (veriler.isEmpty) return pw.SizedBox.shrink();
    final aralik = (veriler.length / 8).ceil().clamp(1, 999);
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < veriler.length; i++)
          if (i % aralik == 0 || i == veriler.length - 1)
            pw.Expanded(
              child: pw.Text(
                veriler[i]['etiket']?.toString() ?? '-',
                textAlign: pw.TextAlign.center,
                maxLines: 2,
                style: const pw.TextStyle(fontSize: 7),
              ),
            ),
      ],
    );
  }

  List<Map<String, Object?>> _gunlukVerileriTamamla(
    List<Map<String, Object?>> veriler,
    int gunSayisi,
  ) {
    final gunHaritasi = {
      for (final satir in veriler) satir['gun']?.toString(): satir,
    };
    final bugun = DateTime.now();
    final baslangic = DateTime(
      bugun.year,
      bugun.month,
      bugun.day,
    ).subtract(Duration(days: gunSayisi - 1));

    return [
      for (var i = 0; i < gunSayisi; i++)
        () {
          final tarih = baslangic.add(Duration(days: i));
          final anahtar = tarih.toIso8601String().substring(0, 10);
          final satir = gunHaritasi[anahtar];
          return <String, Object?>{
            'gun': anahtar,
            'toplam': _intDegeri(satir?['toplam']),
            'dogru': _intDegeri(satir?['dogru']),
            'yanlis': _intDegeri(satir?['yanlis']),
            'bos': _intDegeri(satir?['bos']),
          };
        }(),
    ];
  }

  String _kisaTarih(String? isoTarih) {
    if (isoTarih == null || isoTarih.length < 10) return '-';
    final tarih = DateTime.tryParse(isoTarih);
    if (tarih == null) return isoTarih;
    return '${tarih.day}.${tarih.month}.${tarih.year}';
  }

  void _pdfGridCiz(PdfGraphics canvas, PdfPoint size) {
    canvas
      ..setStrokeColor(PdfColor.fromInt(0xFFE2E8F0))
      ..setLineWidth(0.7);
    for (var i = 0; i <= 4; i++) {
      final y = 30 + (size.y - 50) * i / 4;
      canvas.drawLine(30, y, size.x - 20, y);
    }
    canvas.strokePath();
  }

  void _pdfSeriCiz(
    PdfGraphics canvas,
    PdfPoint size,
    List<Map<String, Object?>> veriler,
    String alan,
    int maxY,
    PdfColor renk,
  ) {
    final chartLeft = 30.0;
    final chartRight = size.x - 20;
    final chartBottom = 30.0;
    final chartTop = size.y - 20;
    final chartWidth = chartRight - chartLeft;
    final chartHeight = chartTop - chartBottom;

    canvas
      ..setStrokeColor(renk)
      ..setLineWidth(2);
    for (var i = 0; i < veriler.length; i++) {
      final x = veriler.length == 1
          ? chartLeft
          : chartLeft + chartWidth * i / (veriler.length - 1);
      final y = chartBottom + chartHeight * _intDegeri(veriler[i][alan]) / maxY;
      if (i == 0) {
        canvas.moveTo(x, y);
      } else {
        canvas.lineTo(x, y);
      }
    }
    canvas.strokePath();
  }

  int _intDegeri(Object? deger) {
    if (deger is int) return deger;
    if (deger is num) return deger.toInt();
    return int.tryParse(deger?.toString() ?? '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: true,
        title: const Text('Veri ve İstatistik'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFDDE7FF)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'İstatistik Raporu',
                    style: TextStyle(
                      color: Color(0xFF1E3A8A),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Son 30 gün raporu dikey A4, tüm zamanlar raporu yatay A4 olarak hazırlanır. Her raporda konu bazlı grafikler, deneme sınavı grafikleri, genel çizgi grafik ve sayısal tablo bulunur.',
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _pdfHazirlaniyor
                          ? null
                          : () => _pdfDisariAktar(son30Gun: true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: _pdfHazirlaniyor
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.picture_as_pdf_outlined),
                      label: Text(
                        _pdfHazirlaniyor
                            ? '${_hazirlananRapor ?? 'PDF'} hazırlanıyor...'
                            : 'Son 30 Günü PDF Olarak Dışarı Aktar',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _pdfHazirlaniyor
                          ? null
                          : () => _pdfDisariAktar(son30Gun: false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _primary,
                        side: const BorderSide(color: _primary),
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text(
                        'Tüm Zamanları PDF Olarak Dışarı Aktar',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFFFCDD2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'İlerleme Durumu',
                    style: TextStyle(
                      color: Color(0xFF991B1B),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Fresh start için çözdüğün soru kayıtlarını, deneme geçmişini ve bunlara bağlı istatistik/grafik verilerini siler. Hesap bilgilerin ve oturumun korunur.',
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (_pdfHazirlaniyor || _ilerlemeSiliniyor)
                          ? null
                          : _ilerlemeDurumunuSil,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _danger,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: _ilerlemeSiliniyor
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.restart_alt_rounded),
                      label: Text(
                        _ilerlemeSiliniyor
                            ? 'İlerleme durumu siliniyor...'
                            : 'İlerleme Durumunu Sil',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PdfLejant {
  final String label;
  final PdfColor renk;

  const _PdfLejant(this.label, this.renk);
}

class HesapAyarlariEkrani extends StatefulWidget {
  final Map<String, Object?> kullanici;

  const HesapAyarlariEkrani({super.key, required this.kullanici});

  @override
  State<HesapAyarlariEkrani> createState() => _HesapAyarlariEkraniDurumu();
}

class _HesapAyarlariEkraniDurumu extends State<HesapAyarlariEkrani> {
  final _veritabaniYardimcisi = VeritabaniYardimcisi();
  late final TextEditingController _usernameKontrolcusu;
  final _mevcutSifreKontrolcusu = TextEditingController();
  final _sifreKontrolcusu = TextEditingController();
  final _sifreTekrarKontrolcusu = TextEditingController();
  bool _sifreBolumuAcik = false;

  static const Color _bg = Color(0xFFF4F8FF);
  static const Color _primary = Color(0xFF2563EB);
  static const Color _danger = Color(0xFFDC2626);

  @override
  void initState() {
    super.initState();
    _usernameKontrolcusu = TextEditingController(
      text: (widget.kullanici['ad_soyad'] as String?) ?? '',
    );
  }

  Future<void> _kaydet() async {
    final username = _usernameKontrolcusu.text.trim();
    final mevcutSifre = _mevcutSifreKontrolcusu.text;
    final sifre = _sifreKontrolcusu.text;
    final sifreTekrar = _sifreTekrarKontrolcusu.text;

    if (username.isEmpty || username.length < 3) {
      await _hesapMesajiGoster(
        context,
        'Kullanıcı adı en az 3 karakter olmalıdır.',
      );
      return;
    }

    if (_sifreBolumuAcik || sifre.isNotEmpty || sifreTekrar.isNotEmpty) {
      if (mevcutSifre.isEmpty) {
        await _hesapMesajiGoster(context, 'Mevcut şifreyi girin.');
        return;
      }

      final mevcutSifreDogruMu = await _veritabaniYardimcisi
          .aktifKullaniciSifresiDogruMu(mevcutSifre);
      if (!mounted) return;
      var sifreDogrulandi = mevcutSifreDogruMu;
      if (!sifreDogrulandi) {
        final email = widget.kullanici['email']?.toString() ?? '';
        if (email.isNotEmpty) {
          sifreDogrulandi = await ApiServisi().girisYap(
            eposta: email,
            sifre: mevcutSifre,
          );
          if (!mounted) return;
        }
      }

      if (!sifreDogrulandi) {
        await _hesapMesajiGoster(context, 'Mevcut şifre hatalı.');
        return;
      }

      if (sifre != sifreTekrar) {
        await _hesapMesajiGoster(context, 'Şifreler eşleşmiyor.');
        return;
      }

      final sifreUyarisi = _sifreUyarisi(sifre);
      if (sifreUyarisi != null) {
        await _hesapMesajiGoster(context, sifreUyarisi);
        return;
      }
    }

    await _veritabaniYardimcisi.aktifKullaniciBilgileriniGuncelle(
      username: username,
      yeniSifre: sifre.isEmpty ? null : sifre,
    );
    if (!mounted) return;
    await _hesapMesajiGoster(context, 'Hesap ayarları güncellendi.');
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _hesabiSil() async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hesabı Sil'),
          content: const Text('Bu hesap ve oturum bilgileri silinsin mi?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Vazgeç'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sil', style: TextStyle(color: _danger)),
            ),
          ],
        );
      },
    );

    if (onay != true) return;
    if (!mounted) return;

    final sifre = await _sifreDogrulamaDialogunuGoster();
    if (sifre == null) return;
    if (sifre.isEmpty) {
      if (!mounted) return;
      await _hesapMesajiGoster(context, 'Şifre alanı zorunludur.');
      return;
    }

    final sifreDogruMu = await _sifreyiDogrula(sifre);
    if (!mounted) return;
    if (!sifreDogruMu) {
      await _hesapMesajiGoster(context, 'Şifre hatalı. Hesap silinmedi.');
      return;
    }

    await _veritabaniYardimcisi.aktifKullaniciHesabiniSil();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  Future<bool> _sifreyiDogrula(String sifre) async {
    final yerelSifreDogruMu = await _veritabaniYardimcisi
        .aktifKullaniciSifresiDogruMu(sifre);
    if (yerelSifreDogruMu) return true;

    final email = widget.kullanici['email']?.toString() ?? '';
    if (email.isEmpty) return false;
    return ApiServisi().girisYap(eposta: email, sifre: sifre);
  }

  Future<String?> _sifreDogrulamaDialogunuGoster() async {
    final sifreKontrolcusu = TextEditingController();
    try {
      return showDialog<String>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Şifre Doğrulama'),
            content: TextField(
              controller: sifreKontrolcusu,
              autofocus: true,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Şifre',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              onSubmitted: (_) => Navigator.pop(context, sifreKontrolcusu.text),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Vazgeç'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, sifreKontrolcusu.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _danger,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Hesabı Sil'),
              ),
            ],
          );
        },
      );
    } finally {
      sifreKontrolcusu.dispose();
    }
  }

  @override
  void dispose() {
    _usernameKontrolcusu.dispose();
    _mevcutSifreKontrolcusu.dispose();
    _sifreKontrolcusu.dispose();
    _sifreTekrarKontrolcusu.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: true,
        title: const Text('Hesap Ayarları'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 48,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ayarKartiOlustur(),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _hesabiSil,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _danger,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Hesabı Sil'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _ayarKartiOlustur() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDDE7FF)),
      ),
      child: Column(
        children: [
          TextField(
            controller: _usernameKontrolcusu,
            decoration: const InputDecoration(
              labelText: 'Kullanıcı Adı',
              prefixIcon: Icon(Icons.person_outline),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          _sifreBolumuOlustur(),
          /*
          TextField(
            controller: _sifreKontrolcusu,
            decoration: const InputDecoration(
              labelText: 'Yeni Şifre',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            obscureText: true,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _sifreTekrarKontrolcusu,
            decoration: const InputDecoration(
              labelText: 'Yeni Şifre Tekrar',
              prefixIcon: Icon(Icons.lock_reset_outlined),
            ),
            obscureText: true,
            onSubmitted: (_) => _kaydet(),
          ),
          */
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _kaydet,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.save_outlined),
            label: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  Widget _sifreBolumuOlustur() {
    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _sifreBolumuAcik = !_sifreBolumuAcik;
              if (!_sifreBolumuAcik) {
                _mevcutSifreKontrolcusu.clear();
                _sifreKontrolcusu.clear();
                _sifreTekrarKontrolcusu.clear();
              }
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.lock_reset_outlined, color: _primary),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Şifreyi Yenile',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                ),
                Icon(
                  _sifreBolumuAcik
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 180),
          crossFadeState: _sifreBolumuAcik
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Column(
            children: [
              const SizedBox(height: 12),
              TextField(
                controller: _mevcutSifreKontrolcusu,
                decoration: const InputDecoration(
                  labelText: 'Mevcut Şifre',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                obscureText: true,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _sifreKontrolcusu,
                decoration: const InputDecoration(
                  labelText: 'Yeni Şifre',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                obscureText: true,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _sifreTekrarKontrolcusu,
                decoration: const InputDecoration(
                  labelText: 'Yeni Şifre Tekrar',
                  prefixIcon: Icon(Icons.lock_reset_outlined),
                ),
                obscureText: true,
                onSubmitted: (_) => _kaydet(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HesapVerileri {
  final Map<String, Object?>? kullanici;
  final Map<String, int> istatistikler;
  final List<Map<String, Object?>> gunlukIstatistikler;
  final List<Map<String, Object?>> konuIstatistikleri;
  final List<Map<String, Object?>> konuGunlukIstatistikleri;
  final List<Map<String, Object?>> denemeIstatistikleri;

  const _HesapVerileri({
    required this.kullanici,
    required this.istatistikler,
    required this.gunlukIstatistikler,
    required this.konuIstatistikleri,
    required this.konuGunlukIstatistikleri,
    required this.denemeIstatistikleri,
  });

  factory _HesapVerileri.bos() {
    return const _HesapVerileri(
      kullanici: null,
      istatistikler: {
        'toplam': 0,
        'dogru': 0,
        'yanlis': 0,
        'bos': 0,
        'bitirilenKonu': 0,
        'toplamKonu': 0,
      },
      gunlukIstatistikler: [],
      konuIstatistikleri: [],
      konuGunlukIstatistikleri: [],
      denemeIstatistikleri: [],
    );
  }
}

class _GunlukGrafikNoktalari {
  const _GunlukGrafikNoktalari({
    required this.toplam,
    required this.dogru,
    required this.yanlis,
    required this.bos,
    required this.etiketler,
    required this.maxY,
    required this.baslik,
  });

  final List<FlSpot> toplam;
  final List<FlSpot> dogru;
  final List<FlSpot> yanlis;
  final List<FlSpot> bos;
  final List<String> etiketler;
  final double maxY;
  final String baslik;
}

class _GrafikAciklamasi extends StatelessWidget {
  const _GrafikAciklamasi(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class AdminAyarlariEkrani extends StatefulWidget {
  const AdminAyarlariEkrani({super.key});

  @override
  State<AdminAyarlariEkrani> createState() => _AdminAyarlariEkraniDurumu();
}

class _AdminAyarlariEkraniDurumu extends State<AdminAyarlariEkrani> {
  final _apiServisi = ApiServisi();
  final _hedefSayiKontrolcusu = TextEditingController(text: '50');
  bool _yukleniyor = true;
  bool _islemSuruyor = false;
  bool _kayitlarAktif = true;
  bool _apiAktif = true;
  bool _botCalismakta = false;
  int _senkronizasyonVersiyonu = 0;
  String? _senkronizasyonTarihi;
  int _etkinHedefSayi = 50;
  List<Map<String, dynamic>> _konuSayilari = const [];
  String? _sonucMesaji;

  static const Color _bg = Color(0xFFF4F8FF);
  static const Color _primary = Color(0xFF2563EB);
  static const Color _text = Color(0xFF1E3A8A);
  static const Color _success = Color(0xFF15803D);
  static const Color _inactive = Color(0xFFDC2626);

  @override
  void initState() {
    super.initState();
    _ayarlariYukle();
  }

  @override
  void dispose() {
    _hedefSayiKontrolcusu.dispose();
    super.dispose();
  }

  Future<void> _ayarlariYukle() async {
    final ayarlar = await _apiServisi.adminAyarlariGetir();
    final plan = await _apiServisi.botUretimPlaniGetir();
    if (!mounted) return;
    setState(() {
      _yukleniyor = false;
      if (ayarlar == null) {
        _sonucMesaji = 'Admin ayarları sunucudan alınamadı.';
        return;
      }
      _ayarDegerleriniUygula(ayarlar);
      if (plan != null) _planDegerleriniUygula(plan);
    });
  }

  void _ayarDegerleriniUygula(Map<String, dynamic> ayarlar) {
    _kayitlarAktif = ayarlar['kayitlar_aktif'] == true;
    _apiAktif = ayarlar['api_aktif'] == true;
    _botCalismakta = ayarlar['bot_calismakta'] == true;
    _senkronizasyonVersiyonu =
        (ayarlar['veritabani_senkronizasyon_versiyonu'] as num?)?.toInt() ?? 0;
    _senkronizasyonTarihi = ayarlar['veritabani_senkronizasyon_tarihi']
        ?.toString();
    _hedefSayiKontrolcusu.text = '${ayarlar['bot_hedef_soru_sayisi'] ?? 50}';
  }

  void _planDegerleriniUygula(Map<String, dynamic> plan) {
    _etkinHedefSayi = (plan['etkin_hedef_soru_sayisi'] as num?)?.toInt() ?? 50;
    final konular = plan['konular'];
    if (konular is List) {
      _konuSayilari = konular
          .whereType<Map>()
          .map((konu) => Map<String, dynamic>.from(konu))
          .toList();
    }
  }

  Future<void> _ayariGuncelle(
    Map<String, Object?> degisiklik,
    String basariMesaji,
  ) async {
    if (_islemSuruyor) return;
    setState(() {
      _islemSuruyor = true;
      _sonucMesaji = null;
    });

    final ayarlar = await _apiServisi.adminAyarlariGuncelle(degisiklik);
    if (!mounted) return;
    setState(() {
      _islemSuruyor = false;
      if (ayarlar == null) {
        _sonucMesaji = 'İşlem sunucuya iletilemedi.';
        return;
      }
      _ayarDegerleriniUygula(ayarlar);
      _sonucMesaji = basariMesaji;
    });
    await _planiYenile();
  }

  Future<void> _planiYenile() async {
    final plan = await _apiServisi.botUretimPlaniGetir();
    if (!mounted || plan == null) return;
    setState(() => _planDegerleriniUygula(plan));
  }

  Future<void> _botAyarlariniKaydet() async {
    final hedefSayi = int.tryParse(_hedefSayiKontrolcusu.text.trim());
    if (hedefSayi == null || hedefSayi < 1) {
      setState(() {
        _sonucMesaji = 'Konu başına hedef pozitif sayı olmalıdır.';
      });
      return;
    }
    await _ayariGuncelle({
      'bot_hedef_soru_sayisi': hedefSayi,
    }, 'Tüm konular için ortak üretim hedefi kaydedildi.');
  }

  Future<void> _botuDegistir() async {
    if (_islemSuruyor) return;
    setState(() => _islemSuruyor = true);
    final ayarlar = await _apiServisi.botKontrolEt(baslat: !_botCalismakta);
    if (!mounted) return;
    setState(() {
      _islemSuruyor = false;
      if (ayarlar == null) {
        _sonucMesaji = 'Bot kontrol komutu sunucuya iletilemedi.';
        return;
      }
      _ayarDegerleriniUygula(ayarlar);
      _sonucMesaji = _botCalismakta ? 'Bot başlatıldı.' : 'Bot durduruldu.';
    });
    await _planiYenile();
  }

  Future<void> _senkronizasyonuTetikle() async {
    if (_islemSuruyor) return;

    final onay = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Veritabanı Senkronizasyonu'),
          content: const Text(
            'Bu işlem cihazlara güvenli tam eşitleme isteği gönderir. Kullanıcıların yerel çözüm kayıtları silinmez; cihazlar uygun anda önce bekleyen çözümleri sunucuya gönderir, sonra güncel verileri çeker.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Vazgeç'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Senkronizasyon İste'),
            ),
          ],
        );
      },
    );
    if (onay != true) return;

    setState(() {
      _islemSuruyor = true;
      _sonucMesaji = null;
    });

    final ayarlar = await _apiServisi.adminSenkronizasyonTetikle();
    if (!mounted) return;
    setState(() {
      _islemSuruyor = false;
      if (ayarlar == null) {
        _sonucMesaji = 'Senkronizasyon isteği sunucuya iletilemedi.';
        return;
      }
      _ayarDegerleriniUygula(ayarlar);
      _sonucMesaji =
          'Senkronizasyon isteği oluşturuldu. Cihazlar sunucuya bağlandığında güvenli şekilde eşitlenecek.';
    });
  }

  Future<void> _soruLatexMetinleriniOnar() async {
    if (_islemSuruyor) return;

    final onay = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Soru Metinlerini Onar'),
          content: const Text(
            'Ana sunucudaki soru metinlerinde bozulmuş LaTeX kaçışlarını onarır. İşlem bitince cihazların güncel verileri yeniden çekmesi için senkronizasyon isteği de oluşturulur.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Vazgeç'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Onar'),
            ),
          ],
        );
      },
    );
    if (onay != true) return;

    setState(() {
      _islemSuruyor = true;
      _sonucMesaji = null;
    });

    final sonuc = await _apiServisi.adminSoruLatexOnar();
    if (!mounted) return;

    if (sonuc == null) {
      setState(() {
        _islemSuruyor = false;
        _sonucMesaji =
            'Soru metinleri onarılamadı. Sunucu güncel olmayabilir veya yetki doğrulanamadı.';
      });
      return;
    }

    final senkronizasyon = await _apiServisi.adminSenkronizasyonTetikle();
    if (!mounted) return;

    setState(() {
      _islemSuruyor = false;
      final etkilenen = (sonuc['etkilenen_kayit_sayisi'] as num?)?.toInt() ?? 0;
      final taranan = (sonuc['taranan_kayit_sayisi'] as num?)?.toInt() ?? 0;
      if (senkronizasyon != null) {
        _ayarDegerleriniUygula(senkronizasyon);
      }
      _sonucMesaji =
          '$taranan soru tarandı, $etkilenen soru onarıldı. ${senkronizasyon == null ? 'Senkronizasyon isteği oluşturulamadı.' : 'Senkronizasyon isteği oluşturuldu.'}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: true,
        title: const Text('Admin Ayarları'),
      ),
      body: SafeArea(
        child: _yukleniyor
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  _sistemDurumuKarti(),
                  const SizedBox(height: 14),
                  _anaKontrollerKarti(),
                  const SizedBox(height: 14),
                  _senkronizasyonKarti(),
                  const SizedBox(height: 14),
                  _soruBakimKarti(),
                  const SizedBox(height: 14),
                  _botAyarlariKarti(),
                  if (_islemSuruyor) ...[
                    const SizedBox(height: 16),
                    const Center(child: CircularProgressIndicator()),
                  ],
                  if (_sonucMesaji != null) ...[
                    const SizedBox(height: 16),
                    _sonucKarti(),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _sistemDurumuKarti() {
    return _kart(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Sistem Durumu',
                style: TextStyle(
                  color: _text,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              IconButton(
                onPressed: _islemSuruyor ? null : _ayarlariYukle,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Durumu Yenile',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _durumRozeti('API', _apiAktif),
              _durumRozeti('Bot', _botCalismakta),
              _durumRozeti('Kayıtlar', _kayitlarAktif),
            ],
          ),
        ],
      ),
    );
  }

  Widget _anaKontrollerKarti() {
    return _kart(
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Kayıtları Dondur',
              style: TextStyle(fontWeight: FontWeight.w700, color: _text),
            ),
            subtitle: const Text(
              'Yeni kullanıcı kayıtlarını geçici olarak reddeder. Kayıtlar açılınca yeni hesaplar sunucuya kaydedilebilir.',
            ),
            value: !_kayitlarAktif,
            onChanged: _islemSuruyor
                ? null
                : (dondur) => _ayariGuncelle(
                    {'kayitlar_aktif': !dondur},
                    dondur
                        ? 'Yeni kayıtlar donduruldu.'
                        : 'Yeni kayıtlar açıldı.',
                  ),
          ),
          const Divider(height: 22),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'API Kontrolü',
              style: TextStyle(fontWeight: FontWeight.w700, color: _text),
            ),
            subtitle: const Text(
              'Mobil veri ve üretim işlemlerini durdurur. Yeniden açıldığında cihazlar ilk bağlantıda bekleyen çözümleri gönderip güncel soruları alır.',
            ),
            value: _apiAktif,
            onChanged: _islemSuruyor
                ? null
                : (aktif) => _ayariGuncelle(
                    {'api_aktif': aktif},
                    aktif ? 'Ana API etkinleştirildi.' : 'Ana API durduruldu.',
                  ),
          ),
        ],
      ),
    );
  }

  Widget _senkronizasyonKarti() {
    return _kart(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Veritabanı Senkronizasyonu',
            style: TextStyle(
              color: _text,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Uygulamalardaki yerel veriler ile sunucu veritabanı arasında güvenli eşitleme isteği oluşturur. Cihazlar yeniden bağlandığında önce bekleyen çözümlerini gönderir, sonra güncel tabloları çeker.',
          ),
          const SizedBox(height: 10),
          Text(
            'Son istek: $_senkronizasyonVersiyonu${_senkronizasyonTarihi == null ? '' : ' • $_senkronizasyonTarihi'}',
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _islemSuruyor ? null : _senkronizasyonuTetikle,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
            icon: const Icon(Icons.sync_rounded),
            label: const Text('Sunucu ile Uygulamaları Eşitle'),
          ),
        ],
      ),
    );
  }

  Widget _soruBakimKarti() {
    return _kart(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Soru Bakımı',
            style: TextStyle(
              color: _text,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Ana sunucudaki bozulmuş LaTeX komutlarını onarır. Örneğin eksik kaçışlardan oluşan bullet, cdot, frac ve text hatalarını düzeltir.',
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _islemSuruyor ? null : _soruLatexMetinleriniOnar,
            style: OutlinedButton.styleFrom(
              foregroundColor: _primary,
              side: const BorderSide(color: _primary),
              minimumSize: const Size(double.infinity, 50),
            ),
            icon: const Icon(Icons.auto_fix_high_outlined),
            label: const Text('Soru LaTeX Metinlerini Onar'),
          ),
        ],
      ),
    );
  }

  Widget _botAyarlariKarti() {
    return _kart(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Bot Ayarları',
            style: TextStyle(
              color: _text,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Bot en az sorusu olan konudan başlayarak bütün konuları aynı hedefe taşır.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _hedefSayiKontrolcusu,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Her konu için hedef toplam',
              prefixIcon: Icon(Icons.format_list_numbered),
              suffixText: 'soru',
            ),
          ),
          if (_etkinHedefSayi !=
              int.tryParse(_hedefSayiKontrolcusu.text.trim())) ...[
            const SizedBox(height: 10),
            Text(
              'Bazı konularda daha fazla soru bulunduğu için eşitlik hedefi $_etkinHedefSayi olarak uygulanacak.',
              style: const TextStyle(color: Color(0xFF92400E)),
            ),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _islemSuruyor ? null : _botAyarlariniKaydet,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Üretim Hedefini Kaydet'),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _islemSuruyor ? null : _botuDegistir,
            style: ElevatedButton.styleFrom(
              backgroundColor: _botCalismakta ? _inactive : _primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
            icon: Icon(
              _botCalismakta
                  ? Icons.stop_circle_outlined
                  : Icons.play_circle_outline,
            ),
            label: Text(_botCalismakta ? 'Botu Durdur' : 'Botu Başlat'),
          ),
          const SizedBox(height: 18),
          const Text(
            'Konu Soru Sayıları',
            style: TextStyle(color: _text, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ..._konuSayilari.map(_konuSayisiSatiri),
        ],
      ),
    );
  }

  Widget _konuSayisiSatiri(Map<String, dynamic> konu) {
    final soruSayisi = (konu['soru_sayisi'] as num?)?.toInt() ?? 0;
    final tamamlandi = soruSayisi >= _etkinHedefSayi;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              konu['konu_adi']?.toString() ?? '-',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$soruSayisi / $_etkinHedefSayi',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: tamamlandi ? _success : _text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _durumRozeti(String label, bool aktif) {
    final renk = aktif ? _success : _inactive;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$label: ${aktif ? 'Çalışıyor' : 'Kapalı'}',
        style: TextStyle(color: renk, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _sonucKarti() {
    return _kart(
      child: Text(
        _sonucMesaji!,
        textAlign: TextAlign.center,
        style: const TextStyle(color: _text, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _kart({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDDE7FF)),
      ),
      child: child,
    );
  }
}

String? _sifreUyarisi(String sifre) {
  if (sifre.length < 8) {
    return 'Şifre en az 8 karakter olmalıdır.';
  }
  if (!RegExp(r'[A-Z]').hasMatch(sifre)) {
    return 'Şifre en az bir büyük harf içermelidir.';
  }
  if (!RegExp(r'[a-z]').hasMatch(sifre)) {
    return 'Şifre en az bir küçük harf içermelidir.';
  }
  if (!RegExp(r'\d').hasMatch(sifre)) {
    return 'Şifre en az bir rakam içermelidir.';
  }
  if (!RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=/\\[\];]').hasMatch(sifre)) {
    return 'Şifre en az bir özel karakter içermelidir.';
  }
  return null;
}

Future<void> _hesapMesajiGoster(BuildContext context, String message) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        content: Text(message, textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
            ),
            child: const Text('Tamam'),
          ),
        ],
      );
    },
  );
}
