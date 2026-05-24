import 'dart:convert';

import 'package:dgs_app/yardimcilar/latex_temizleyici.dart';

int? _intDegeri(Object? deger) {
  if (deger is int) return deger;
  if (deger is num) return deger.toInt();
  return int.tryParse(deger?.toString() ?? '');
}

bool _boolDegeri(Object? deger) {
  if (deger is bool) return deger;
  if (deger is num) return deger == 1;
  final metin = deger?.toString().toLowerCase();
  return metin == 'true' || metin == '1' || metin == 'evet';
}

class Konu {
  final int? id;
  final String ad;
  final String metin;
  final String? resimUrl;
  final int ilerlemeYuzdesi;

  Konu({
    this.id,
    required this.ad,
    this.metin = '',
    this.resimUrl,
    this.ilerlemeYuzdesi = 0,
  });

  factory Konu.haritadanOlustur(Map<String, dynamic> json) {
    return Konu(
      id: json['id'] ?? json['konu_id'],
      ad: json['konu_adi'] ?? json['name'] ?? '',
      metin: json['konu_metin'] ?? json['description'] ?? '',
      resimUrl: json['konu_resmi'],
      ilerlemeYuzdesi: json['progress_percent'] ?? 0,
    );
  }

  Map<String, dynamic> haritayaDonustur() => {
    'id': id,
    'konu_adi': ad,
    'konu_metin': metin,
    'konu_resmi': resimUrl,
    'progress_percent': ilerlemeYuzdesi,
  };
}

class Soru {
  final int? id;
  final int konuId;
  final String soruMetni;
  final String? soruResmi;
  final String soruKoku;
  final String secenekA;
  final String secenekB;
  final String secenekC;
  final String secenekD;
  final String secenekE;
  final String dogruSecenek;
  final String cozum;
  final String zorluk;
  final bool yapayZekaUretimiMi;
  final String durum;
  final String? olusturulmaTarihi;
  final String? guncellenmeTarihi;

  Soru({
    this.id,
    required this.konuId,
    required this.soruMetni,
    this.soruResmi,
    this.soruKoku = '',
    required this.secenekA,
    required this.secenekB,
    required this.secenekC,
    required this.secenekD,
    this.secenekE = '',
    required this.dogruSecenek,
    required this.cozum,
    this.zorluk = 'Orta',
    this.yapayZekaUretimiMi = false,
    this.durum = 'yayinda',
    this.olusturulmaTarihi,
    this.guncellenmeTarihi,
  });

  factory Soru.haritadanOlustur(Map<String, dynamic> json) {
    String temizMetin(Object? deger) {
      if (deger is List || deger is Map) {
        return latexMetniniOnar(jsonEncode(deger));
      }
      return latexMetniniOnar(deger?.toString() ?? '');
    }

    return Soru(
      id: _intDegeri(json['soru_id'] ?? json['question_id'] ?? json['id']),
      konuId: _intDegeri(json['konu_id'] ?? json['topic_id']) ?? 1,
      soruMetni: temizMetin(
        json['sorumetni'] ?? json['question_text'] ?? json['text'],
      ),
      soruResmi: temizMetin(json['soruresmi']),
      soruKoku: temizMetin(json['sorukoku'] ?? json['question_root']),
      secenekA: temizMetin(json['secenek_a'] ?? json['option_a'] ?? json['a']),
      secenekB: temizMetin(json['secenek_b'] ?? json['option_b'] ?? json['b']),
      secenekC: temizMetin(json['secenek_c'] ?? json['option_c'] ?? json['c']),
      secenekD: temizMetin(json['secenek_d'] ?? json['option_d'] ?? json['d']),
      secenekE: temizMetin(json['secenek_e'] ?? json['option_e'] ?? json['e']),
      dogruSecenek:
          (json['dogrucevap'] ??
                  json['correct_option'] ??
                  json['correct_answer'] ??
                  json['answer'] ??
                  '')
              .toString()
              .toUpperCase(),
      cozum: temizMetin(
        json['cozum'] ?? json['solution'] ?? json['explanation'],
      ),
      zorluk: (json['difficulty'] ?? json['zorluk'] ?? 'Orta').toString(),
      yapayZekaUretimiMi: _boolDegeri(json['is_ai_generated']),
      durum: json['durum'] ?? 'yayinda',
      olusturulmaTarihi: json['olusturulma_tarihi']?.toString(),
      guncellenmeTarihi: json['guncellenme_tarihi']?.toString(),
    );
  }

  Map<String, dynamic> haritayaDonustur() => {
    'soru_id': id,
    'sorumetni': soruMetni,
    'soruresmi': soruResmi,
    'sorukoku': soruKoku.isEmpty ? soruMetni : soruKoku,
    'secenek_a': secenekA,
    'secenek_b': secenekB,
    'secenek_c': secenekC,
    'secenek_d': secenekD,
    'secenek_e': secenekE.isEmpty ? '-' : secenekE,
    'dogrucevap': dogruSecenek.toUpperCase(),
    'cozum': cozum,
    'konu_id': konuId,
    'difficulty': zorluk,
    'is_ai_generated': yapayZekaUretimiMi ? 1 : 0,
    'durum': durum,
    'olusturulma_tarihi': olusturulmaTarihi,
    'guncellenme_tarihi': guncellenmeTarihi,
  };

  String get gorunenMetin {
    if (soruKoku.isEmpty || soruKoku == soruMetni) {
      return soruMetni;
    }
    return '$soruMetni\n\n$soruKoku';
  }
}

class Istatistik {
  final int? id;
  final int kullaniciId;
  final int dogruSayisi;
  final int yanlisSayisi;
  final int bosSayisi;
  final String zamanDamgasi;
  final String kategori;

  Istatistik({
    this.id,
    required this.kullaniciId,
    this.dogruSayisi = 0,
    this.yanlisSayisi = 0,
    this.bosSayisi = 0,
    required this.zamanDamgasi,
    required this.kategori,
  });

  factory Istatistik.haritadanOlustur(Map<String, dynamic> json) => Istatistik(
    id: json['id'],
    kullaniciId: json['user_id'] ?? json['kullanici_id'],
    dogruSayisi: json['correct_count'] ?? json['dogru_sayisi'] ?? 0,
    yanlisSayisi: json['wrong_count'] ?? json['yanlis_sayisi'] ?? 0,
    bosSayisi: json['empty_count'] ?? json['bos_sayisi'] ?? 0,
    zamanDamgasi: json['timestamp'] ?? json['olusturulma_tarihi'] ?? '',
    kategori: json['category'] ?? json['deneme_adi'] ?? '',
  );

  Map<String, dynamic> haritayaDonustur() => {
    'id': id,
    'kullanici_id': kullaniciId,
    'dogru_sayisi': dogruSayisi,
    'yanlis_sayisi': yanlisSayisi,
    'bos_sayisi': bosSayisi,
    'olusturulma_tarihi': zamanDamgasi,
    'deneme_adi': kategori,
  };
}

class KullaniciSoruCozumu {
  final int? cozumId;
  final int? uzakCozumId;
  final int kullaniciId;
  final int soruId;
  final String? verilenCevap;
  final String dogruCevap;
  final String sonuc;
  final int? cozumSuresiSaniye;
  final String cozulmeTarihi;
  final bool senkronizeEdildiMi;

  KullaniciSoruCozumu({
    this.cozumId,
    this.uzakCozumId,
    required this.kullaniciId,
    required this.soruId,
    this.verilenCevap,
    required this.dogruCevap,
    required this.sonuc,
    this.cozumSuresiSaniye,
    required this.cozulmeTarihi,
    this.senkronizeEdildiMi = false,
  });

  factory KullaniciSoruCozumu.haritadanOlustur(Map<String, dynamic> json) {
    return KullaniciSoruCozumu(
      cozumId: json['cozum_id'],
      uzakCozumId: json['uzak_cozum_id'],
      kullaniciId: json['kullanici_id'],
      soruId: json['soru_id'],
      verilenCevap: json['verilen_cevap'],
      dogruCevap: json['dogru_cevap'],
      sonuc: json['sonuc'],
      cozumSuresiSaniye: json['cozum_suresi_saniye'],
      cozulmeTarihi: json['cozulme_tarihi'] ?? '',
      senkronizeEdildiMi: (json['senkronize_edildi_mi'] ?? 0) == 1,
    );
  }

  Map<String, dynamic> haritayaDonustur() => {
    'cozum_id': cozumId,
    'uzak_cozum_id': uzakCozumId,
    'kullanici_id': kullaniciId,
    'soru_id': soruId,
    'verilen_cevap': verilenCevap,
    'dogru_cevap': dogruCevap,
    'sonuc': sonuc,
    'cozum_suresi_saniye': cozumSuresiSaniye,
    'cozulme_tarihi': cozulmeTarihi,
    'senkronize_edildi_mi': senkronizeEdildiMi ? 1 : 0,
  };
}
