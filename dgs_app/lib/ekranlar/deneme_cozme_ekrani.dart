import 'dart:async';
import 'package:dgs_app/bilesenler/latex_metin.dart';
import 'package:flutter/material.dart';
import 'package:dgs_app/tema/uygulama_temasi.dart';
import 'package:dgs_app/veritabani/veritabani_yardimcisi.dart';
import 'package:dgs_app/modeller/modeller.dart';

class DenemeCozmeEkrani extends StatefulWidget {
  final String zorluk;
  final int denemeNo;

  const DenemeCozmeEkrani({
    super.key,
    required this.zorluk,
    required this.denemeNo,
  });

  @override
  State<DenemeCozmeEkrani> createState() => _DenemeCozmeEkraniDurumu();
}

class _DenemeCozmeEkraniDurumu extends State<DenemeCozmeEkrani> {
  final VeritabaniYardimcisi _veritabaniYardimcisi = VeritabaniYardimcisi();
  final GlobalKey<_CizimAlaniDurumu> _cizimAlaniAnahtari =
      GlobalKey<_CizimAlaniDurumu>();
  final List<_Cizgi> _cizgiler = [];
  List<Soru> _sorular = [];
  int _gecerliIndeks = 0;
  final Map<int, String> _cevaplar = {};
  final Set<int> _favoriler = {};
  bool _denemeBitirildi = false;
  bool _cizimPaneliAcik = false;
  bool _silgiAktif = false;
  bool _favoriYukleniyor = true;

  late Timer _timer;
  int _kalanSaniye = _denemeSuresiSaniye;

  static const int _denemeSoruSayisi = 50;
  static const int _denemeSuresiSaniye = 135 * 60;
  static const List<_DenemeKonuDagilimi> _konuDagilimi = [
    _DenemeKonuDagilimi('İşlem Yeteneği ve Sayı Kümeleri', 1),
    _DenemeKonuDagilimi('Tek ve Çift Sayılar ve İşaret İncelemesi', 1),
    _DenemeKonuDagilimi('Ardışık Sayılar', 1),
    _DenemeKonuDagilimi('Faktöriyel', 1),
    _DenemeKonuDagilimi('Basamak Kavramı', 3),
    _DenemeKonuDagilimi('Bölme ve Bölünebilme', 1),
    _DenemeKonuDagilimi('Asal Sayılar ve Asal Çarpanlara Ayırma', 1),
    _DenemeKonuDagilimi('EBOB ve EKOK', 1),
    _DenemeKonuDagilimi('Rasyonel Sayılar', 1),
    _DenemeKonuDagilimi('Birinci Dereceden Denklemler', 2),
    _DenemeKonuDagilimi('Birinci Dereceden Eşitsizlikler', 2),
    _DenemeKonuDagilimi('Mutlak Değer', 1),
    _DenemeKonuDagilimi('Üslü Sayılar', 2),
    _DenemeKonuDagilimi('Köklü Sayılar', 1),
    _DenemeKonuDagilimi('Çarpanlara Ayırma', 1),
    _DenemeKonuDagilimi('Oran ve Orantı', 1),
    _DenemeKonuDagilimi('Sayı ve Kesir Problemleri', 6),
    _DenemeKonuDagilimi('Yaş Problemleri', 1),
    _DenemeKonuDagilimi('Yüzde, Kâr, Zarar ve Karışım Problemleri', 2),
    _DenemeKonuDagilimi('İşçi ve Havuz Problemleri', 1),
    _DenemeKonuDagilimi('Hareket Problemleri', 1),
    _DenemeKonuDagilimi('Tablo ve Grafik Problemleri', 2),
    _DenemeKonuDagilimi('Kümeler', 1),
    _DenemeKonuDagilimi('Fonksiyonlar', 1),
    _DenemeKonuDagilimi('İşlem ve Periyodik Tekrar Eden Durumlar', 2),
    _DenemeKonuDagilimi('Permütasyon', 1),
    _DenemeKonuDagilimi('Kombinasyon', 1),
    _DenemeKonuDagilimi('Olasılık', 1),
    _DenemeKonuDagilimi('Sayısal Mantık', 9),
  ];

  @override
  void initState() {
    super.initState();
    _sorulariYukle();
    _startTimer();
  }

  Future<void> _sorulariYukle() async {
    final yedekSorular = await _dagilimaGoreSorulariGetir();
    final favoriIdleri = <int>{};
    for (final soru in yedekSorular) {
      final soruId = soru.id;
      if (soruId == null) continue;
      if (await _veritabaniYardimcisi.soruFavorideMi(soruId)) {
        favoriIdleri.add(soruId);
      }
    }
    if (!mounted) return;
    setState(() {
      _sorular = yedekSorular;
      _favoriler
        ..clear()
        ..addAll(favoriIdleri);
      _favoriYukleniyor = false;
    });
  }

  Future<List<Soru>> _dagilimaGoreSorulariGetir() async {
    final secilenSorular = <Soru>[];
    final secilenSoruIdleri = <int>{};

    for (final dagilim in _konuDagilimi) {
      final konu = await _veritabaniYardimcisi.konuyuAdinaGoreGetir(
        dagilim.konuAdi,
      );
      final konuId = konu?.id;
      if (konuId == null) continue;

      final zorlukSorulari = await _veritabaniYardimcisi.sorulariGetir(
        konuId: konuId,
        zorluk: widget.zorluk,
        limit: dagilim.soruSayisi * widget.denemeNo,
        sadeceCozulmemis: true,
      );
      _benzersizSorulariEkle(
        secilenSorular,
        secilenSoruIdleri,
        _denemeSorulariniSec(zorlukSorulari, dagilim.soruSayisi),
        dagilim.soruSayisi,
      );

      final eksikSayi =
          dagilim.soruSayisi - _konuSoruSayisi(secilenSorular, konuId);
      if (eksikSayi <= 0) continue;

      final konuYedekleri = await _veritabaniYardimcisi.sorulariGetir(
        konuId: konuId,
        limit: dagilim.soruSayisi * widget.denemeNo,
        sadeceCozulmemis: true,
      );
      _benzersizSorulariEkle(
        secilenSorular,
        secilenSoruIdleri,
        _denemeSorulariniSec(konuYedekleri, dagilim.soruSayisi),
        eksikSayi,
      );
    }

    if (secilenSorular.length < _denemeSoruSayisi) {
      final genelYedekler = await _veritabaniYardimcisi.sorulariGetir(
        zorluk: widget.zorluk,
        limit: _denemeSoruSayisi * widget.denemeNo,
        sadeceCozulmemis: true,
      );
      _benzersizSorulariEkle(
        secilenSorular,
        secilenSoruIdleri,
        _denemeSorulariniSec(genelYedekler, _denemeSoruSayisi),
        _denemeSoruSayisi - secilenSorular.length,
      );
    }

    if (secilenSorular.length < _denemeSoruSayisi) {
      final genelYedekler = await _veritabaniYardimcisi.sorulariGetir(
        limit: _denemeSoruSayisi * widget.denemeNo,
        sadeceCozulmemis: true,
      );
      _benzersizSorulariEkle(
        secilenSorular,
        secilenSoruIdleri,
        _denemeSorulariniSec(genelYedekler, _denemeSoruSayisi),
        _denemeSoruSayisi - secilenSorular.length,
      );
    }

    return secilenSorular.take(_denemeSoruSayisi).toList();
  }

  List<Soru> _denemeSorulariniSec(List<Soru> sorular, int adet) {
    final offset = (widget.denemeNo - 1) * adet;
    final secilenler = sorular.skip(offset).take(adet).toList();
    if (secilenler.length >= adet) return secilenler;

    final eksik = adet - secilenler.length;
    return [...secilenler, ...sorular.take(eksik)];
  }

  void _benzersizSorulariEkle(
    List<Soru> hedef,
    Set<int> secilenSoruIdleri,
    List<Soru> kaynak,
    int adet,
  ) {
    var eklenen = 0;
    for (final soru in kaynak) {
      final soruId = soru.id;
      if (soruId != null && secilenSoruIdleri.contains(soruId)) continue;
      hedef.add(soru);
      if (soruId != null) secilenSoruIdleri.add(soruId);
      eklenen++;
      if (eklenen >= adet) break;
    }
  }

  int _konuSoruSayisi(List<Soru> sorular, int konuId) {
    return sorular.where((soru) => soru.konuId == konuId).length;
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

  Future<void> _favoriDegistir() async {
    if (_sorular.isEmpty) return;
    final soruId = _sorular[_gecerliIndeks].id;
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
    if (_sorular.isEmpty) return;
    final soruId = _sorular[_gecerliIndeks].id;
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
          if (dialogContext.mounted) Navigator.of(dialogContext).pop();
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
                        ? Icons.check_circle_outline
                        : Icons.error_outline,
                    color: renk,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      mesaj,
                      style: TextStyle(
                        color: renk,
                        fontWeight: FontWeight.w800,
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

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_kalanSaniye > 0) {
          _kalanSaniye--;
        } else {
          _timer.cancel();
          _denemeyiBitir();
        }
      });
    });
  }

  String _sureyiBicimlendir(int seconds) {
    int dakika = seconds ~/ 60;
    int kalanSaniye = seconds % 60;
    return '${dakika.toString().padLeft(2, '0')}:${kalanSaniye.toString().padLeft(2, '0')}';
  }

  Future<void> _denemeyiBitir({bool sonucDialoguGoster = true}) async {
    if (_denemeBitirildi) return;
    _denemeBitirildi = true;
    _timer.cancel();
    int dogru = 0;
    int yanlis = 0;
    int bos = 0;
    final kullanici = await _veritabaniYardimcisi.aktifKullaniciyiGetir();
    final kullaniciId = kullanici?['id'] as int?;
    final cozumSuresi = _denemeSuresiSaniye - _kalanSaniye;
    final verilenCevaplar = <int, String?>{};
    final dogruCevaplar = <int, String>{};
    final sonuclar = <int, String>{};

    for (int i = 0; i < _sorular.length; i++) {
      final soru = _sorular[i];
      final verilenCevap = _cevaplar[i];
      late final String sonuc;

      if (!_cevaplar.containsKey(i)) {
        bos++;
        sonuc = 'bos';
      } else if (verilenCevap == soru.dogruSecenek) {
        dogru++;
        sonuc = 'dogru';
      } else {
        yanlis++;
        sonuc = 'yanlis';
      }

      final soruId = soru.id;
      if (soruId != null) {
        verilenCevaplar[soruId] = verilenCevap;
        dogruCevaplar[soruId] = soru.dogruSecenek;
        sonuclar[soruId] = sonuc;
      }
    }
    if (kullaniciId != null &&
        _sorular.isNotEmpty &&
        _sorular.first.id != null) {
      final denemeAdi = '${widget.zorluk} ${widget.denemeNo}';
      await _veritabaniYardimcisi.denemeSonucuKaydet(
        kullaniciId: kullaniciId,
        soruId: _sorular.first.id!,
        denemeAdi: denemeAdi,
        toplamSoruSayisi: _sorular.length,
        dogruSayisi: dogru,
        yanlisSayisi: yanlis,
        bosSayisi: bos,
        cozumSuresiSaniye: cozumSuresi,
      );
      await _veritabaniYardimcisi.denemeSorulariniKaydet(
        kullaniciId: kullaniciId,
        denemeAdi: denemeAdi,
        soruIdleri: _sorular.map((soru) => soru.id).whereType<int>(),
        verilenCevaplar: verilenCevaplar,
        dogruCevaplar: dogruCevaplar,
        sonuclar: sonuclar,
      );
    }

    if (!mounted) return;

    if (!sonucDialoguGoster) {
      Navigator.pop(context);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Sınav Bitti'),
        content: Text('Doğru: $dogru\nYanlış: $yanlis\nBoş: $bos'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Back to exams
            },
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  Future<void> _denemedenCikmayiSor() async {
    final cikmakIstiyorMu = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Denemeden Çık'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Denemeden çıkmak istiyor musunuz?'),
              const SizedBox(height: 18),
              OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hayır'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Evet'),
              ),
            ],
          ),
        );
      },
    );
    if (cikmakIstiyorMu != true || !mounted) return;

    final kayitSecimi = await showDialog<_DenemeCikisSecimi>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Sonuçlar'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Çıkmadan önce deneme sonucunu kaydetmek ister misiniz?',
              ),
              const SizedBox(height: 18),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Vazgeç'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () =>
                    Navigator.pop(context, _DenemeCikisSecimi.kaydetme),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Kaydetme ve Çık'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () =>
                    Navigator.pop(context, _DenemeCikisSecimi.kaydet),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Kaydet ve Çık'),
              ),
            ],
          ),
        );
      },
    );
    if (!mounted || kayitSecimi == null) return;

    if (kayitSecimi == _DenemeCikisSecimi.kaydet) {
      await _denemeyiBitir(sonucDialoguGoster: false);
      return;
    }

    _denemeBitirildi = true;
    _timer.cancel();
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_sorular.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final soru = _sorular[_gecerliIndeks];
    final soruId = soru.id;
    final favorideMi = soruId != null && _favoriler.contains(soruId);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || _denemeBitirildi) return;
        if (_cizimPaneliAcik) {
          _cizimPaneliniAcKapat();
          return;
        }
        _denemedenCikmayiSor();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: _denemedenCikmayiSor,
            icon: const Icon(Icons.arrow_back),
          ),
          title: Text('${widget.zorluk} Deneme ${widget.denemeNo}'),
          actions: [
            IconButton(
              tooltip: favorideMi ? 'Favorilerden çıkar' : 'Favorilere ekle',
              onPressed: _favoriYukleniyor ? null : _favoriDegistir,
              icon: Icon(
                favorideMi
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: const Color(0xFFE11D48),
              ),
            ),
            IconButton(
              tooltip: 'Hatalı soru bildir',
              onPressed: _geribildirimPopupGoster,
              icon: const Icon(
                Icons.report_problem_outlined,
                color: Color(0xFFF59E0B),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Text(
                  _sureyiBicimlendir(_kalanSaniye),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.red,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                LinearProgressIndicator(
                  value: (_gecerliIndeks + 1) / _sorular.length,
                  backgroundColor: UygulamaTemasi.acikMavi,
                  color: UygulamaTemasi.ortaMavi,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Soru ${_gecerliIndeks + 1}/${_sorular.length}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 16),
                        LatexMetin(
                          soru.gorunenMetin,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 32),
                        _secenekOlustur('A', soru.secenekA),
                        _secenekOlustur('B', soru.secenekB),
                        _secenekOlustur('C', soru.secenekC),
                        _secenekOlustur('D', soru.secenekD),
                        if (soru.secenekE.isNotEmpty && soru.secenekE != '-')
                          _secenekOlustur('E', soru.secenekE),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_gecerliIndeks > 0)
                        OutlinedButton(
                          onPressed: () => _soruDegistir(_gecerliIndeks - 1),
                          child: const Text('Geri'),
                        )
                      else
                        const SizedBox(),
                      ElevatedButton(
                        onPressed: () {
                          if (_gecerliIndeks < _sorular.length - 1) {
                            _soruDegistir(_gecerliIndeks + 1);
                          } else {
                            _denemeyiBitir();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(120, 50),
                        ),
                        child: Text(
                          _gecerliIndeks < _sorular.length - 1
                              ? 'Sonraki'
                              : 'Bitir',
                        ),
                      ),
                    ],
                  ),
                ),
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
      ),
    );
  }

  Widget _secenekOlustur(String key, String text) {
    bool seciliMi = _cevaplar[_gecerliIndeks] == key;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        onTap: () => setState(() => _cevaplar[_gecerliIndeks] = key),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: seciliMi ? const Color(0x1A2196F3) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: seciliMi ? UygulamaTemasi.ortaMavi : Colors.grey[300]!,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: seciliMi
                    ? UygulamaTemasi.ortaMavi
                    : Colors.grey[200],
                child: Text(
                  key,
                  style: TextStyle(
                    color: seciliMi ? Colors.white : Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: LatexMetin(
                  text,
                  style: TextStyle(
                    fontWeight: seciliMi ? FontWeight.bold : FontWeight.normal,
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

class _DenemeKonuDagilimi {
  final String konuAdi;
  final int soruSayisi;

  const _DenemeKonuDagilimi(this.konuAdi, this.soruSayisi);
}

enum _DenemeCikisSecimi { kaydet, kaydetme }
