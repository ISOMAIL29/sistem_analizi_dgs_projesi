import 'dart:convert';

import 'package:dgs_app/modeller/modeller.dart';
import 'package:dgs_app/veritabani/veritabani_yardimcisi.dart';
import 'package:http/http.dart' as http;

class ApiServisi {
  static const String temelUrl = String.fromEnvironment(
    'API_TEMEL_URL',
    defaultValue: 'http://45.136.6.48:8000',
  );

  final VeritabaniYardimcisi _veritabaniYardimcisi = VeritabaniYardimcisi();

  Future<bool> kayitOl({
    required String ad,
    required String eposta,
    required String sifre,
  }) async {
    try {
      final yanit = await http
          .post(
            _uri('/api/kullanici/kayit'),
            headers: _jsonHeader,
            body: json.encode({'ad': ad, 'eposta': eposta, 'sifre': sifre}),
          )
          .timeout(const Duration(seconds: 15));

      if (yanit.statusCode < 200 || yanit.statusCode >= 300) return false;

      final veri = _jsonMap(yanit.body);
      await _oturumVeKullaniciKaydet(veri, varsayilanAd: ad, eposta: eposta);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> girisYap({required String eposta, required String sifre}) async {
    try {
      final yanit = await http
          .post(
            _uri('/api/kullanici/giris'),
            headers: _jsonHeader,
            body: json.encode({'eposta': eposta, 'sifre': sifre}),
          )
          .timeout(const Duration(seconds: 15));

      if (yanit.statusCode < 200 || yanit.statusCode >= 300) return false;

      final veri = _jsonMap(yanit.body);
      final token = veri['token']?.toString();
      if (veri['basarili'] != true ||
          token == null ||
          token.isEmpty ||
          veri['kullanici'] is! Map) {
        return false;
      }

      await _oturumVeKullaniciKaydet(
        veri,
        varsayilanAd: eposta,
        eposta: eposta,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, Object?>?> kullaniciBilgisiGetir() async {
    try {
      final yanit = await http
          .get(_uri('/api/kullanici/ben'), headers: await _authHeader())
          .timeout(const Duration(seconds: 10));

      if (yanit.statusCode != 200) return null;
      final veri = _jsonMap(yanit.body);
      await _oturumVeKullaniciKaydet(veri, varsayilanAd: '', eposta: '');
      return veri;
    } catch (_) {
      return null;
    }
  }

  Future<bool> oturumuDogrula() async {
    final oturum = await _veritabaniYardimcisi.oturumuGetir();
    final token = oturum?['token']?.toString();
    if (token == null || token.isEmpty) return false;

    final kullanici = await kullaniciBilgisiGetir();
    if (kullanici != null) return true;

    await _veritabaniYardimcisi.oturumSil();
    return false;
  }

  Future<Map<String, dynamic>?> adminAyarlariGetir() async {
    try {
      final yanit = await http
          .get(_uri('/api/admin/ayarlar'), headers: await _authHeader())
          .timeout(const Duration(seconds: 10));
      if (yanit.statusCode != 200) return null;
      return _jsonMap(yanit.body);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> adminAyarlariGuncelle(
    Map<String, Object?> ayarlar,
  ) async {
    try {
      final yanit = await http
          .put(
            _uri('/api/admin/ayarlar'),
            headers: await _authHeader(),
            body: json.encode(ayarlar),
          )
          .timeout(const Duration(seconds: 10));
      if (yanit.statusCode != 200) return null;
      return _jsonMap(yanit.body);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> botUretimPlaniGetir() async {
    try {
      final yanit = await http
          .get(_uri('/api/bot/uretim-plani'), headers: await _authHeader())
          .timeout(const Duration(seconds: 10));
      if (yanit.statusCode != 200) return null;
      return _jsonMap(yanit.body);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> botKontrolEt({required bool baslat}) async {
    try {
      final eylem = baslat ? 'baslat' : 'durdur';
      final yanit = await http
          .post(_uri('/api/admin/bot/$eylem'), headers: await _authHeader())
          .timeout(const Duration(seconds: 10));
      if (yanit.statusCode != 200) return null;
      return _jsonMap(yanit.body);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> adminSenkronizasyonTetikle() async {
    try {
      final yanit = await http
          .post(
            _uri('/api/admin/senkronizasyon/tetikle'),
            headers: await _authHeader(),
          )
          .timeout(const Duration(seconds: 10));
      if (yanit.statusCode != 200) return null;
      return _jsonMap(yanit.body);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> adminSoruLatexOnar() async {
    try {
      final yanit = await http
          .post(
            _uri('/api/admin/sorular/latex-onar'),
            headers: await _authHeader(),
          )
          .timeout(const Duration(seconds: 60));
      if (yanit.statusCode != 200) return null;
      return _jsonMap(yanit.body);
    } catch (_) {
      return null;
    }
  }

  Future<void> tamEsitle() async {
    await bekleyenCozumleriGonder();
    await sunucudanEsitle();
    await kullaniciBilgisiGetir();
  }

  Future<int> sunucudanEsitle({int limit = 500}) async {
    final sorular = await sorulariCek(limit: limit);
    if (sorular.isNotEmpty) {
      await _veritabaniYardimcisi.sorulariKaydet(sorular);
    }

    return sorular.length;
  }

  Future<List<Soru>> sorulariCek({int limit = 500}) async {
    try {
      final sonSoruId = await _veritabaniYardimcisi.sonSoruIdGetir();
      final oturum = await _veritabaniYardimcisi.oturumuGetir();
      final hesapTuru = oturum?['hesap_turu']?.toString() ?? 'ucretsiz';

      final yanit = await http
          .get(
            _uri('/api/mobil/sorular', {
              'son_soru_id': sonSoruId.toString(),
              'limit': limit.toString(),
              'hesap_turu': hesapTuru,
            }),
          )
          .timeout(const Duration(seconds: 30));
      if (yanit.statusCode != 200) return [];

      final veri = json.decode(yanit.body);
      final satirlar = _listeyiAyikla(veri, const [
        'sorular',
        'questions',
        'data',
        'results',
      ]);
      final sorular = satirlar
          .map(
            (satir) => Soru.haritadanOlustur(Map<String, dynamic>.from(satir)),
          )
          .toList();

      final yeniSonSoruId = _sonSoruIdAyikla(veri, sorular, sonSoruId);
      if (yeniSonSoruId > sonSoruId) {
        await _veritabaniYardimcisi.sonSoruIdKaydet(yeniSonSoruId);
      }

      return sorular;
    } catch (_) {
      return [];
    }
  }

  Future<Soru?> soruDetayiCek(int soruId) async {
    try {
      final yanit = await http
          .get(_uri('/api/mobil/sorular/$soruId'))
          .timeout(const Duration(seconds: 10));

      if (yanit.statusCode != 200) return null;
      final veri = _jsonMap(yanit.body);
      return Soru.haritadanOlustur(veri);
    } catch (_) {
      return null;
    }
  }

  Future<bool> soruCozumuGonder(KullaniciSoruCozumu cozum) async {
    try {
      final yanit = await http
          .post(
            _uri('/api/mobil/soru-cozumu'),
            headers: await _authHeader(),
            body: json.encode({
              'soru_id': cozum.soruId,
              'verilen_cevap': cozum.verilenCevap,
              'cozum_suresi_saniye': cozum.cozumSuresiSaniye,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (yanit.statusCode < 200 || yanit.statusCode >= 300) return false;
      final veri = _jsonMap(yanit.body);
      await _veritabaniYardimcisi.cozumSenkronizeIsaretle(
        cozum.cozumId ?? 0,
        _intDegeri(veri['cozum_id'] ?? veri['id']),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<int> bekleyenCozumleriGonder() async {
    final cozumler = await _veritabaniYardimcisi
        .senkronBekleyenCozumleriGetir();
    var gonderilen = 0;
    for (final cozum in cozumler) {
      if (await soruCozumuGonder(cozum)) {
        gonderilen++;
      }
    }
    return gonderilen;
  }

  Future<Soru?> yapayZekaSorusuUret(int konuId) async {
    try {
      final yanit = await http
          .get(_uri('/generate-question', {'topic_id': konuId.toString()}))
          .timeout(const Duration(seconds: 10));

      if (yanit.statusCode == 200) {
        final veri = _jsonMap(yanit.body);
        final soru = Soru.haritadanOlustur({...veri, 'is_ai_generated': 1});
        await _veritabaniYardimcisi.sorulariKaydet([soru]);
        return soru;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<void> _oturumVeKullaniciKaydet(
    Map<String, dynamic> veri, {
    required String varsayilanAd,
    required String eposta,
  }) async {
    final mevcutOturum = await _veritabaniYardimcisi.oturumuGetir();
    final kullanici = _jsonMap(veri['kullanici'] ?? veri['user'] ?? veri);
    final token =
        (veri['token'] ?? veri['access_token'])?.toString() ??
        mevcutOturum?['token']?.toString();
    final email = (kullanici['eposta'] ?? kullanici['email'] ?? eposta)
        .toString();
    final ad = (kullanici['ad'] ?? kullanici['ad_soyad'] ?? varsayilanAd)
        .toString();
    final rol = (kullanici['rol'] ?? 'kullanici').toString();
    final hesapTuru = (kullanici['hesap_turu'] ?? 'ucretsiz').toString();
    final uzakKullaniciId = _intDegeri(
      kullanici['id'] ?? kullanici['kullanici_id'] ?? kullanici['user_id'],
    );

    if (email.isNotEmpty) {
      await _veritabaniYardimcisi.kullaniciApiKaydet(
        uzakKullaniciId: uzakKullaniciId,
        ad: ad.isEmpty ? email : ad,
        email: email,
        hesapTuru: hesapTuru,
        rol: rol,
      );
    }

    if (token != null && token.isNotEmpty) {
      await _veritabaniYardimcisi.oturumKaydet(
        token: token,
        uzakKullaniciId: uzakKullaniciId,
        email: email.isEmpty ? (mevcutOturum?['email']?.toString()) : email,
        rol: rol,
        hesapTuru: hesapTuru,
      );
    }
  }

  Future<Map<String, String>> _authHeader() async {
    final oturum = await _veritabaniYardimcisi.oturumuGetir();
    final token = oturum?['token']?.toString();
    return {
      ..._jsonHeader,
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = temelUrl.endsWith('/')
        ? temelUrl.substring(0, temelUrl.length - 1)
        : temelUrl;
    return Uri.parse('$base$path').replace(queryParameters: query);
  }

  Map<String, String> get _jsonHeader => const {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  Map<String, dynamic> _jsonMap(Object? veri) {
    if (veri is Map<String, dynamic>) return veri;
    if (veri is Map) return Map<String, dynamic>.from(veri);
    if (veri is String && veri.isNotEmpty) {
      final decoded = json.decode(veri);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    }
    return {};
  }

  List<dynamic> _listeyiAyikla(Object? veri, List<String> anahtarlar) {
    if (veri is List) return veri;
    if (veri is Map) {
      for (final anahtar in anahtarlar) {
        final deger = veri[anahtar];
        if (deger is List) return deger;
      }
    }
    return const [];
  }

  int _sonSoruIdAyikla(Object? veri, List<Soru> sorular, int mevcutSonSoruId) {
    if (veri is Map) {
      final apiSonSoruId = _intDegeri(veri['son_soru_id']);
      if (apiSonSoruId != null) return apiSonSoruId;
    }

    var sonSoruId = mevcutSonSoruId;
    for (final soru in sorular) {
      final id = soru.id ?? 0;
      if (id > sonSoruId) sonSoruId = id;
    }
    return sonSoruId;
  }

  int? _intDegeri(Object? deger) {
    if (deger is int) return deger;
    if (deger is num) return deger.toInt();
    return int.tryParse(deger?.toString() ?? '');
  }
}
