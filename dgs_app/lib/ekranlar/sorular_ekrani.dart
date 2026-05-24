import 'dart:convert';

import 'package:dgs_app/bilesenler/latex_metin.dart';
import 'package:dgs_app/modeller/modeller.dart';
import 'package:dgs_app/veri/konu_verileri.dart';
import 'package:dgs_app/veritabani/veritabani_yardimcisi.dart';
import 'package:flutter/material.dart';

class SorularEkrani extends StatefulWidget {
  const SorularEkrani({super.key});

  @override
  State<SorularEkrani> createState() => _SorularEkraniDurumu();
}

class _SorularEkraniDurumu extends State<SorularEkrani> {
  static const Color _bg = Color(0xFFF4F7FB);
  static const Color _primary = Color(0xFF1D4ED8);
  static const Color _mint = Color(0xFFDDEBFF);

  static final List<_SoruKonusu> _konular = List.generate(
    kKonular.length,
    (index) => _SoruKonusu(id: index + 1, ad: kKonular[index]),
  );

  bool _listeAciliyor = false;

  Future<void> _ozelListeyiAc({
    required String baslik,
    required Future<List<Soru>> Function() sorulariGetir,
    required String bosMesaj,
    bool yanlisTekrarModu = false,
  }) async {
    if (_listeAciliyor) return;
    setState(() => _listeAciliyor = true);
    final sorular = await sorulariGetir();

    if (!mounted) return;
    setState(() => _listeAciliyor = false);

    if (sorular.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(bosMesaj)));
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _SoruCozumEkrani(
          baslik: baslik,
          sorular: sorular,
          yanlisTekrarModu: yanlisTekrarModu,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: true,
        title: const Text('Soru Bankası'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              itemCount: _konular.length,
              itemBuilder: (context, index) {
                final konu = _konular[index];
                return _SoruKonusuKutucugu(konu: konu);
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _listeAciliyor
                          ? null
                          : () => _ozelListeyiAc(
                              baslik: 'Yanlışlarını Tekrar Et',
                              sorulariGetir: () => VeritabaniYardimcisi()
                                  .yanlisSorulariGetir(limit: 20),
                              bosMesaj: 'Tekrar edilecek yanlış soru yok.',
                              yanlisTekrarModu: true,
                            ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Yanlışlarını Tekrar Et'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: _listeAciliyor
                        ? null
                        : () => _ozelListeyiAc(
                            baslik: 'Favoriler',
                            sorulariGetir:
                                VeritabaniYardimcisi().favoriSorulariGetir,
                            bosMesaj: 'Favorilere eklenmiş soru yok.',
                          ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(56, 52),
                      foregroundColor: const Color(0xFFE11D48),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Icon(Icons.favorite_border_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SoruKonusuKutucugu extends StatelessWidget {
  final _SoruKonusu konu;

  const _SoruKonusuKutucugu({required this.konu});

  static const Color _primary = _SorularEkraniDurumu._primary;
  static const Color _mint = _SorularEkraniDurumu._mint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => _KonuSorulariEkrani(konu: konu)),
          );
        },
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFDFE8F3)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _mint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.quiz_outlined, color: _primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  konu.ad,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                    fontSize: 15,
                  ),
                ),
              ),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Color(0xFF475569),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KonuSorulariEkrani extends StatelessWidget {
  final _SoruKonusu konu;

  const _KonuSorulariEkrani({required this.konu});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Soru>>(
      future: VeritabaniYardimcisi().sorulariGetir(
        konuId: konu.id,
        sadeceCozulmemis: true,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(title: Text(konu.ad)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final sorular = snapshot.data ?? [];
        if (sorular.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: Text(konu.ad)),
            body: const Center(
              child: Text(
                'Bu konu için çözülmemiş soru bulunamadı.',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            ),
          );
        }

        return _SoruCozumEkrani(baslik: konu.ad, sorular: sorular);
      },
    );
  }
}

class _SoruCozumEkrani extends StatefulWidget {
  final String baslik;
  final List<Soru> sorular;
  final bool yanlisTekrarModu;

  const _SoruCozumEkrani({
    required this.baslik,
    required this.sorular,
    this.yanlisTekrarModu = false,
  });

  @override
  State<_SoruCozumEkrani> createState() => _SoruCozumEkraniDurumu();
}

class _SoruCozumEkraniDurumu extends State<_SoruCozumEkrani> {
  final VeritabaniYardimcisi _veritabaniYardimcisi = VeritabaniYardimcisi();
  final GlobalKey<_CizimAlaniDurumu> _cizimAlaniAnahtari =
      GlobalKey<_CizimAlaniDurumu>();
  final List<_Cizgi> _cizgiler = [];
  final Map<int, String> _cevaplar = {};
  final Set<int> _favoriler = {};
  late final List<Soru> _sorular;

  int _gecerliIndeks = 0;
  bool _favoriYukleniyor = true;
  bool _cizimPaneliAcik = false;
  bool _silgiAktif = false;

  Soru get _soru => _sorular[_gecerliIndeks];

  @override
  void initState() {
    super.initState();
    _sorular = List<Soru>.of(widget.sorular)..shuffle();
    _favorileriYukle();
    if (!widget.yanlisTekrarModu) {
      _cozumleriYukle();
    }
  }

  Future<void> _favorileriYukle() async {
    final favoriIdleri = <int>{};
    for (final soru in _sorular) {
      final soruId = soru.id;
      if (soruId == null) continue;
      if (await _veritabaniYardimcisi.soruFavorideMi(soruId)) {
        favoriIdleri.add(soruId);
      }
    }

    if (!mounted) return;
    setState(() {
      _favoriler
        ..clear()
        ..addAll(favoriIdleri);
      _favoriYukleniyor = false;
    });
  }

  Future<void> _cozumleriYukle() async {
    final cozumler = await _veritabaniYardimcisi.soruCozumleriniGetir(
      _sorular.map((soru) => soru.id).whereType<int>(),
    );

    if (!mounted) return;
    setState(() {
      _cevaplar.clear();
      for (final entry in _sorular.asMap().entries) {
        final soruId = entry.value.id;
        if (soruId == null) continue;
        final verilenCevap = cozumler[soruId]?.verilenCevap;
        if (verilenCevap == null || verilenCevap.isEmpty) continue;
        _cevaplar[entry.key] = verilenCevap;
      }
    });
  }

  Future<void> _favoriDegistir() async {
    final soruId = _soru.id;
    if (soruId == null) return;

    final favorideMi = !_favoriler.contains(soruId);
    setState(() {
      if (favorideMi) {
        _favoriler.add(soruId);
      } else {
        _favoriler.remove(soruId);
      }
    });
    await _veritabaniYardimcisi.soruFavoriDurumunuAyarla(soruId, favorideMi);
  }

  Future<void> _geribildirimPopupGoster() async {
    final soruId = _soru.id;
    if (soruId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu soru için bildirim oluşturulamadı.')),
      );
      return;
    }

    var dogruCevapYok = false;
    var birdenCokDogruCevap = false;
    var soruMetniYanlis = false;
    var yazimHatasi = false;
    var ipucuYanlis = false;

    final gonderildi = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final secimVar =
                dogruCevapYok ||
                birdenCokDogruCevap ||
                soruMetniYanlis ||
                yazimHatasi ||
                ipucuYanlis;

            return AlertDialog(
              title: const Text('Hatalı Soru Bildir'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CheckboxListTile(
                    value: dogruCevapYok,
                    onChanged: (value) =>
                        setDialogState(() => dogruCevapYok = value ?? false),
                    title: const Text('Doğru cevap yok'),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  CheckboxListTile(
                    value: birdenCokDogruCevap,
                    onChanged: (value) => setDialogState(
                      () => birdenCokDogruCevap = value ?? false,
                    ),
                    title: const Text('Birden çok doğru cevap'),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  CheckboxListTile(
                    value: soruMetniYanlis,
                    onChanged: (value) =>
                        setDialogState(() => soruMetniYanlis = value ?? false),
                    title: const Text('Soru metni yanlış'),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  CheckboxListTile(
                    value: yazimHatasi,
                    onChanged: (value) =>
                        setDialogState(() => yazimHatasi = value ?? false),
                    title: const Text('Yazım hatası'),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  CheckboxListTile(
                    value: ipucuYanlis,
                    onChanged: (value) =>
                        setDialogState(() => ipucuYanlis = value ?? false),
                    title: const Text('İpucu yanlış'),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: secimVar
                          ? () async {
                              final kaydedildi = await _veritabaniYardimcisi
                                  .soruGeribildirimiKaydet(
                                    soruId: soruId,
                                    dogruCevapYok: dogruCevapYok,
                                    birdenCokDogruCevap: birdenCokDogruCevap,
                                    soruMetniYanlis: soruMetniYanlis,
                                    yazimHatasi: yazimHatasi,
                                    ipucuYanlis: ipucuYanlis,
                                  );
                              if (context.mounted) {
                                Navigator.pop(context, kaydedildi);
                              }
                            }
                          : null,
                      child: const Text('Gönder'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                      ),
                      child: const Text('Vazgeç'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (!mounted || gonderildi == null) return;
    await _merkezMesajiGoster(
      gonderildi ? 'Geri bildirim gönderildi.' : 'Geri bildirim gönderilemedi.',
      basariliMi: gonderildi,
    );
  }

  Future<void> _merkezMesajiGoster(
    String mesaj, {
    required bool basariliMi,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.08),
      builder: (dialogContext) {
        Future<void>.delayed(const Duration(milliseconds: 500), () {
          if (dialogContext.mounted) {
            Navigator.of(dialogContext).pop();
          }
        });

        final renk = basariliMi
            ? const Color(0xFF16A34A)
            : const Color(0xFFDC2626);

        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: renk.withValues(alpha: 0.35)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    basariliMi
                        ? Icons.check_circle_outline_rounded
                        : Icons.error_outline_rounded,
                    color: renk,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      mesaj,
                      style: TextStyle(
                        color: renk,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _secenekSec(String secenek) async {
    if (_cevaplar.containsKey(_gecerliIndeks)) return;

    setState(() {
      _cevaplar[_gecerliIndeks] = secenek;
      _cizimPaneliAcik = false;
      _cizgiler.clear();
    });

    final soruId = _soru.id;
    final kullanici = await _veritabaniYardimcisi.aktifKullaniciyiGetir();
    final kullaniciId = kullanici?['id'] as int?;
    if (soruId == null || kullaniciId == null) return;

    await _veritabaniYardimcisi.soruCozumuKaydet(
      KullaniciSoruCozumu(
        kullaniciId: kullaniciId,
        soruId: soruId,
        verilenCevap: secenek,
        dogruCevap: _soru.dogruSecenek,
        sonuc: secenek == _soru.dogruSecenek ? 'dogru' : 'yanlis',
        cozulmeTarihi: DateTime.now().toIso8601String(),
      ),
    );
  }

  Future<void> _yanlisimiAnladim() async {
    final soruId = _soru.id;
    if (soruId == null) return;

    await _veritabaniYardimcisi.yanlisTekrarAnlasildiIsaretle(soruId);
    if (!mounted) return;

    if (_sorular.length == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yanlış tekrar listesi tamamlandı.')),
      );
      Navigator.pop(context);
      return;
    }

    final yeniCevaplar = <int, String>{};
    for (final entry in _cevaplar.entries) {
      if (entry.key == _gecerliIndeks) continue;
      final yeniIndeks = entry.key > _gecerliIndeks ? entry.key - 1 : entry.key;
      yeniCevaplar[yeniIndeks] = entry.value;
    }

    setState(() {
      _sorular.removeAt(_gecerliIndeks);
      _cevaplar
        ..clear()
        ..addAll(yeniCevaplar);
      if (_gecerliIndeks >= _sorular.length) {
        _gecerliIndeks = _sorular.length - 1;
      }
      _cizimPaneliAcik = false;
      _silgiAktif = false;
      _cizgiler.clear();
    });
  }

  void _soruDegistir(int yeniIndeks) {
    if (yeniIndeks < 0 || yeniIndeks >= _sorular.length) return;
    setState(() {
      _gecerliIndeks = yeniIndeks;
      _cizimPaneliAcik = false;
      _silgiAktif = false;
      _cizgiler.clear();
    });
  }

  void _cizimPaneliniAcKapat() {
    setState(() {
      _cizimPaneliAcik = !_cizimPaneliAcik;
      if (_cizimPaneliAcik) {
        _silgiAktif = false;
      }
    });
  }

  Future<void> _ipucuPopupGoster() async {
    await showDialog<void>(
      context: context,
      builder: (context) => _IpucuPopup(cozum: _soru.cozum),
    );
  }

  @override
  Widget build(BuildContext context) {
    final soru = _soru;
    final soruId = soru.id;
    final seciliCevap = _cevaplar[_gecerliIndeks];
    final cevapGosterilsin = seciliCevap != null;
    final favorideMi = soruId != null && _favoriler.contains(soruId);

    return PopScope(
      canPop: !_cizimPaneliAcik,
      onPopInvokedWithResult: (didPop, result) {
        // Panel acikken kenar hareketleri ve sistem geri tusu yok sayilir.
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F7FB),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF4F7FB),
          elevation: 0,
          title: Text(widget.baslik),
        ),
        body: Stack(
          children: [
            ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              children: [
                _SoruBasligi(
                  indeks: _gecerliIndeks,
                  toplam: _sorular.length,
                  favorideMi: favorideMi,
                  favoriYukleniyor: _favoriYukleniyor,
                  onFavori: _favoriDegistir,
                  onGeribildirim: _geribildirimPopupGoster,
                ),
                const SizedBox(height: 10),
                _SoruMetniKart(soru: soru),
                const SizedBox(height: 14),
                _SecenekSatiri(
                  etiket: 'A',
                  metin: soru.secenekA,
                  seciliMi: seciliCevap == 'A',
                  dogruMu: soru.dogruSecenek == 'A',
                  cevapGosterilsin: cevapGosterilsin,
                  onTap: () => _secenekSec('A'),
                ),
                _SecenekSatiri(
                  etiket: 'B',
                  metin: soru.secenekB,
                  seciliMi: seciliCevap == 'B',
                  dogruMu: soru.dogruSecenek == 'B',
                  cevapGosterilsin: cevapGosterilsin,
                  onTap: () => _secenekSec('B'),
                ),
                _SecenekSatiri(
                  etiket: 'C',
                  metin: soru.secenekC,
                  seciliMi: seciliCevap == 'C',
                  dogruMu: soru.dogruSecenek == 'C',
                  cevapGosterilsin: cevapGosterilsin,
                  onTap: () => _secenekSec('C'),
                ),
                _SecenekSatiri(
                  etiket: 'D',
                  metin: soru.secenekD,
                  seciliMi: seciliCevap == 'D',
                  dogruMu: soru.dogruSecenek == 'D',
                  cevapGosterilsin: cevapGosterilsin,
                  onTap: () => _secenekSec('D'),
                ),
                if (soru.secenekE.isNotEmpty && soru.secenekE != '-')
                  _SecenekSatiri(
                    etiket: 'E',
                    metin: soru.secenekE,
                    seciliMi: seciliCevap == 'E',
                    dogruMu: soru.dogruSecenek == 'E',
                    cevapGosterilsin: cevapGosterilsin,
                    onTap: () => _secenekSec('E'),
                  ),
                if (cevapGosterilsin) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Doğru cevap: ${soru.dogruSecenek}',
                    style: const TextStyle(
                      color: Color(0xFF16A34A),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
            Positioned(
              right: 0,
              bottom: MediaQuery.sizeOf(context).height * 0.25 - 29,
              child: _cizimPaneliAcik
                  ? const SizedBox.shrink()
                  : _CizimCekmeceDugmesi(
                      acikMi: false,
                      onTap: _cizimPaneliniAcKapat,
                    ),
            ),
          ],
        ),
        bottomSheet: _CizimAltYariPaneli(
          acikMi: _cizimPaneliAcik,
          cizimAnahtari: _cizimAlaniAnahtari,
          cizgiler: _cizgiler,
          silgiAktif: _silgiAktif,
          onSilgiDegisti: (aktif) => setState(() => _silgiAktif = aktif),
          onKapat: _cizimPaneliniAcKapat,
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.yanlisTekrarModu) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _yanlisimiAnladim,
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: const Text('Yanlışımı Anladım'),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _gecerliIndeks == 0
                            ? null
                            : () => _soruDegistir(_gecerliIndeks - 1),
                        icon: const Icon(Icons.chevron_left_rounded),
                        label: const Text('Önceki'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 112,
                      child: ElevatedButton.icon(
                        onPressed: _ipucuPopupGoster,
                        icon: const Icon(
                          Icons.lightbulb_outline_rounded,
                          size: 18,
                        ),
                        label: const Text('İpucu'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _gecerliIndeks == _sorular.length - 1
                            ? null
                            : () => _soruDegistir(_gecerliIndeks + 1),
                        icon: const Icon(Icons.chevron_right_rounded),
                        label: const Text('Sonraki'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SoruBasligi extends StatelessWidget {
  final int indeks;
  final int toplam;
  final bool favorideMi;
  final bool favoriYukleniyor;
  final VoidCallback onFavori;
  final VoidCallback onGeribildirim;

  const _SoruBasligi({
    required this.indeks,
    required this.toplam,
    required this.favorideMi,
    required this.favoriYukleniyor,
    required this.onFavori,
    required this.onGeribildirim,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Soru ${indeks + 1}/$toplam',
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        IconButton.filledTonal(
          tooltip: favorideMi ? 'Favorilerden çıkar' : 'Favorilere ekle',
          onPressed: favoriYukleniyor ? null : onFavori,
          icon: Icon(
            favorideMi ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: const Color(0xFFE11D48),
          ),
        ),
        const SizedBox(width: 6),
        IconButton.filledTonal(
          tooltip: 'Hatalı soru bildir',
          onPressed: onGeribildirim,
          icon: const Icon(
            Icons.report_problem_outlined,
            color: Color(0xFFF59E0B),
          ),
        ),
      ],
    );
  }
}

class _SoruMetniKart extends StatelessWidget {
  final Soru soru;

  const _SoruMetniKart({required this.soru});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: LatexMetin(
        soru.gorunenMetin,
        style: const TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 16,
          fontWeight: FontWeight.w600,
          height: 1.35,
        ),
      ),
    );
  }
}

class _IpucuPopup extends StatefulWidget {
  final String cozum;

  const _IpucuPopup({required this.cozum});

  @override
  State<_IpucuPopup> createState() => _IpucuPopupDurumu();
}

class _IpucuPopupDurumu extends State<_IpucuPopup> {
  late final List<String> _adimlar = _ipucuAdimlariniAyikla(widget.cozum);
  int _adimIndeksi = 0;

  @override
  Widget build(BuildContext context) {
    final adim = _adimlar[_adimIndeksi];

    final ekran = MediaQuery.sizeOf(context);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: SizedBox(
        width: ekran.width - 80,
        height: ekran.height * 0.56,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 14),
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'İpucu',
                      style: TextStyle(fontSize: 22, color: Color(0xFF0F172A)),
                    ),
                  ),
                  Text(
                    '${_adimIndeksi + 1}/${_adimlar.length}',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Expanded(
                child: SingleChildScrollView(
                  child: SizedBox(
                    width: double.infinity,
                    child: LatexMetin(
                      adim,
                      style: const TextStyle(
                        color: Color(0xFF713F12),
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton.filledTonal(
                    tooltip: 'Önceki adım',
                    onPressed: _adimIndeksi == 0
                        ? null
                        : () => setState(() => _adimIndeksi--),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Tamam'),
                  ),
                  const Spacer(),
                  IconButton.filledTonal(
                    tooltip: 'Sonraki adım',
                    onPressed: _adimIndeksi == _adimlar.length - 1
                        ? null
                        : () => setState(() => _adimIndeksi++),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _ipucuAdimlariniAyikla(String cozum) {
    final temiz = cozum.trim();
    if (temiz.isEmpty || temiz == '[]') {
      return const ['Bu soru için kayıtlı çözüm bulunmuyor.'];
    }

    try {
      final decoded = json.decode(temiz);
      if (decoded is List) {
        final adimlar = decoded
            .map((adim) {
              if (adim is Map) {
                return (adim['adim'] ?? adim['metin'] ?? adim['text'] ?? '')
                    .toString()
                    .trim();
              }
              return adim.toString().trim();
            })
            .where((adim) => adim.isNotEmpty)
            .toList();
        if (adimlar.isNotEmpty) return adimlar;
      }
    } catch (_) {}

    final adimMetni = temiz
        .replaceFirst(RegExp(r'^\s*\[\s*\{\s*adim\s*:\s*'), '')
        .replaceFirst(RegExp(r'\s*\}\s*\]\s*$'), '')
        .trim();

    final numaraliAdimlar = _adimBasliklarinaGoreBol(adimMetni);
    if (numaraliAdimlar.length > 1) return numaraliAdimlar;

    final satirAdimlari = adimMetni
        .split(RegExp(r'\n\s*\n+|\n(?=\s*(?:\d+[\).]|[-*]))'))
        .map(
          (adim) =>
              adim.replaceFirst(RegExp(r'^\s*(?:\d+[\).]|[-*])\s*'), '').trim(),
        )
        .where((adim) => adim.isNotEmpty)
        .toList();
    if (satirAdimlari.length > 1) return satirAdimlari;

    return [adimMetni];
  }

  List<String> _adimBasliklarinaGoreBol(String metin) {
    final baslikRegex = RegExp(
      r'Ad[ıi]m\s*\d+\s*:',
      caseSensitive: false,
      unicode: true,
    );
    final eslesmeler = baslikRegex.allMatches(metin).toList();
    if (eslesmeler.length <= 1) return const [];

    final adimlar = <String>[];
    for (var i = 0; i < eslesmeler.length; i++) {
      final baslangic = eslesmeler[i].start;
      final bitis = i + 1 < eslesmeler.length
          ? eslesmeler[i + 1].start
          : metin.length;
      final adim = metin.substring(baslangic, bitis).trim();
      if (adim.isNotEmpty) adimlar.add(adim);
    }
    return adimlar;
  }
}

class _CizimCekmeceDugmesi extends StatelessWidget {
  final bool acikMi;
  final VoidCallback onTap;

  const _CizimCekmeceDugmesi({required this.acikMi, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1D4ED8),
      borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
        child: SizedBox(
          width: 44,
          height: 58,
          child: Icon(
            acikMi ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
            color: Colors.white,
            size: 30,
          ),
        ),
      ),
    );
  }
}

class _CizimAltYariPaneli extends StatelessWidget {
  final bool acikMi;
  final GlobalKey<_CizimAlaniDurumu> cizimAnahtari;
  final List<_Cizgi> cizgiler;
  final bool silgiAktif;
  final ValueChanged<bool> onSilgiDegisti;
  final VoidCallback onKapat;

  const _CizimAltYariPaneli({
    required this.acikMi,
    required this.cizimAnahtari,
    required this.cizgiler,
    required this.silgiAktif,
    required this.onSilgiDegisti,
    required this.onKapat,
  });

  @override
  Widget build(BuildContext context) {
    if (!acikMi) return const SizedBox.shrink();

    final yukseklik = MediaQuery.sizeOf(context).height * 0.5;

    return SizedBox(
      height: yukseklik,
      width: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(
            child: _CizimPaneli(
              cizimAnahtari: cizimAnahtari,
              cizgiler: cizgiler,
              silgiAktif: silgiAktif,
              onSilgiDegisti: onSilgiDegisti,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: _CizimCekmeceDugmesi(acikMi: true, onTap: onKapat),
          ),
        ],
      ),
    );
  }
}

class _CizimPaneli extends StatelessWidget {
  final GlobalKey<_CizimAlaniDurumu> cizimAnahtari;
  final List<_Cizgi> cizgiler;
  final bool silgiAktif;
  final ValueChanged<bool> onSilgiDegisti;

  const _CizimPaneli({
    required this.cizimAnahtari,
    required this.cizgiler,
    required this.silgiAktif,
    required this.onSilgiDegisti,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 10,
      child: Column(
        children: [
          Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                IconButton.filledTonal(
                  tooltip: 'Kalem',
                  onPressed: () => onSilgiDegisti(false),
                  icon: Icon(
                    Icons.edit_rounded,
                    color: silgiAktif ? null : const Color(0xFF1D4ED8),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Silgi',
                  onPressed: () => onSilgiDegisti(true),
                  icon: Icon(
                    Icons.cleaning_services_rounded,
                    color: silgiAktif ? const Color(0xFF1D4ED8) : null,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _CizimAlani(
              key: cizimAnahtari,
              cizgiler: cizgiler,
              silgiAktif: silgiAktif,
            ),
          ),
        ],
      ),
    );
  }
}

class _CizimAlani extends StatefulWidget {
  final List<_Cizgi> cizgiler;
  final bool silgiAktif;

  const _CizimAlani({
    super.key,
    required this.cizgiler,
    required this.silgiAktif,
  });

  @override
  State<_CizimAlani> createState() => _CizimAlaniDurumu();
}

class _CizimAlaniDurumu extends State<_CizimAlani> {
  void _cizgiBaslat(DragStartDetails details) {
    final kutu = context.findRenderObject() as RenderBox;
    final nokta = kutu.globalToLocal(details.globalPosition);
    setState(() {
      widget.cizgiler.add(
        _Cizgi(
          noktalar: [nokta],
          renk: widget.silgiAktif ? Colors.white : const Color(0xFF111827),
          kalinlik: widget.silgiAktif ? 28 : 3.2,
        ),
      );
    });
  }

  void _cizgiSurukle(DragUpdateDetails details) {
    if (widget.cizgiler.isEmpty) return;
    final kutu = context.findRenderObject() as RenderBox;
    final nokta = kutu.globalToLocal(details.globalPosition);
    setState(() => widget.cizgiler.last.noktalar.add(nokta));
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: ColoredBox(
        color: Colors.white,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: _cizgiBaslat,
          onPanUpdate: _cizgiSurukle,
          child: CustomPaint(
            foregroundPainter: _CizimBoyacisi(widget.cizgiler),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _Cizgi {
  final List<Offset> noktalar;
  final Color renk;
  final double kalinlik;

  _Cizgi({required this.noktalar, required this.renk, required this.kalinlik});
}

class _CizimBoyacisi extends CustomPainter {
  final List<_Cizgi> cizgiler;

  const _CizimBoyacisi(this.cizgiler);

  @override
  void paint(Canvas canvas, Size size) {
    for (final cizgi in cizgiler) {
      if (cizgi.noktalar.isEmpty) continue;
      final paint = Paint()
        ..color = cizgi.renk
        ..strokeWidth = cizgi.kalinlik
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (cizgi.noktalar.length == 1) {
        canvas.drawCircle(cizgi.noktalar.first, cizgi.kalinlik / 2, paint);
        continue;
      }

      final path = Path()
        ..moveTo(cizgi.noktalar.first.dx, cizgi.noktalar.first.dy);
      for (final nokta in cizgi.noktalar.skip(1)) {
        path.lineTo(nokta.dx, nokta.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_CizimBoyacisi oldDelegate) => true;
}

class _SecenekSatiri extends StatelessWidget {
  final String etiket;
  final String metin;
  final bool seciliMi;
  final bool dogruMu;
  final bool cevapGosterilsin;
  final VoidCallback onTap;

  const _SecenekSatiri({
    required this.etiket,
    required this.metin,
    required this.seciliMi,
    required this.dogruMu,
    required this.cevapGosterilsin,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dogruGoster = cevapGosterilsin && dogruMu;
    final yanlisGoster = cevapGosterilsin && seciliMi && !dogruMu;
    final borderColor = dogruGoster
        ? const Color(0xFF22C55E)
        : yanlisGoster
        ? const Color(0xFFEF4444)
        : seciliMi
        ? const Color(0xFF1D4ED8)
        : const Color(0xFFE2E8F0);
    final backgroundColor = dogruGoster
        ? const Color(0xFFEAFBF0)
        : yanlisGoster
        ? const Color(0xFFFEF2F2)
        : seciliMi
        ? const Color(0xFFEFF6FF)
        : Colors.white;
    final etiketArkaPlan = dogruGoster
        ? const Color(0xFF22C55E)
        : yanlisGoster
        ? const Color(0xFFEF4444)
        : const Color(0xFFEFF6FF);
    final etiketRengi = dogruGoster || yanlisGoster
        ? Colors.white
        : const Color(0xFF1D4ED8);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: seciliMi ? 1.6 : 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: etiketArkaPlan,
                child: Text(
                  etiket,
                  style: TextStyle(
                    color: etiketRengi,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: LatexMetin(
                  metin,
                  style: const TextStyle(
                    color: Color(0xFF334155),
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SoruKonusu {
  final int id;
  final String ad;

  const _SoruKonusu({required this.id, required this.ad});
}
