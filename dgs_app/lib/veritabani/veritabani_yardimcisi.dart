import 'package:dgs_app/veri/konu_verileri.dart';
import 'package:dgs_app/modeller/modeller.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class VeritabaniYardimcisi {
  static final VeritabaniYardimcisi _instance =
      VeritabaniYardimcisi._internal();
  factory VeritabaniYardimcisi() => _instance;
  VeritabaniYardimcisi._internal();

  static Database? _veritabani;

  Future<Database> get veritabani async {
    if (_veritabani != null) return _veritabani!;
    _veritabani = await _veritabaniniBaslat();
    return _veritabani!;
  }

  Future<Database> _veritabaniniBaslat() async {
    final path = join(await getDatabasesPath(), 'dgs_database.db');
    return openDatabase(
      path,
      version: 6,
      onCreate: _olusturulunca,
      onUpgrade: _yukseltilince,
    );
  }

  Future<void> _olusturulunca(Database db, int version) async {
    await _tablolariOlustur(db);
    await _varsayilanVerileriEkle(db);
  }

  Future<void> _yukseltilince(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    await db.execute('DROP TABLE IF EXISTS stats');
    await db.execute('DROP TABLE IF EXISTS questions');
    await db.execute('DROP TABLE IF EXISTS topics');
    await db.execute('DROP TABLE IF EXISTS users');
    await db.execute('DROP TABLE IF EXISTS oturum');
    await db.execute('DROP TABLE IF EXISTS kullanici_soru_cozumu');
    await db.execute('DROP TABLE IF EXISTS soru_favori');
    await db.execute('DROP TABLE IF EXISTS geribildirim');
    await db.execute('DROP TABLE IF EXISTS yanlis_tekrar_anlasildi');
    await db.execute('DROP TABLE IF EXISTS disari_aktarilan_soru');
    await db.execute('DROP TABLE IF EXISTS deneme_soru');
    await db.execute('DROP TABLE IF EXISTS deneme');
    await db.execute('DROP TABLE IF EXISTS soru');
    await db.execute('DROP TABLE IF EXISTS kullanici');
    await db.execute('DROP TABLE IF EXISTS konu');
    await _tablolariOlustur(db);
    await _varsayilanVerileriEkle(db);
  }

  Future<void> _tablolariOlustur(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS konu (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        konu_adi TEXT NOT NULL UNIQUE,
        konu_metin TEXT NOT NULL,
        konu_resmi TEXT,
        progress_percent INTEGER DEFAULT 0,
        sort_order INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS kullanici (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uzak_kullanici_id INTEGER,
        ad_soyad TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        sifre_hash TEXT NOT NULL,
        token TEXT,
        hesap_turu TEXT NOT NULL DEFAULT 'ucretsiz',
        rol TEXT NOT NULL DEFAULT 'kullanici',
        kayit_tarihi TEXT DEFAULT CURRENT_TIMESTAMP,
        cozulen_toplam_soru INTEGER DEFAULT 0,
        dogru_sayisi INTEGER DEFAULT 0,
        yanlis_sayisi INTEGER DEFAULT 0,
        bos_sayisi INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS soru (
        soru_id INTEGER PRIMARY KEY AUTOINCREMENT,
        sorumetni TEXT NOT NULL,
        soruresmi TEXT,
        sorukoku TEXT NOT NULL,
        secenek_a TEXT NOT NULL,
        secenek_b TEXT NOT NULL,
        secenek_c TEXT NOT NULL,
        secenek_d TEXT NOT NULL,
        secenek_e TEXT NOT NULL,
        dogrucevap TEXT NOT NULL CHECK (dogrucevap IN ('A', 'B', 'C', 'D', 'E')),
        cozum TEXT NOT NULL DEFAULT '[]',
        konu_id INTEGER NOT NULL,
        durum TEXT NOT NULL DEFAULT 'yayinda',
        olusturulma_tarihi TEXT,
        guncellenme_tarihi TEXT,
        difficulty TEXT DEFAULT 'Orta',
        is_ai_generated INTEGER DEFAULT 0,
        FOREIGN KEY (konu_id) REFERENCES konu(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS kullanici_soru_cozumu (
        cozum_id INTEGER PRIMARY KEY AUTOINCREMENT,
        uzak_cozum_id INTEGER,
        kullanici_id INTEGER NOT NULL,
        soru_id INTEGER NOT NULL,
        verilen_cevap TEXT CHECK (verilen_cevap IS NULL OR verilen_cevap IN ('A', 'B', 'C', 'D', 'E')),
        dogru_cevap TEXT NOT NULL CHECK (dogru_cevap IN ('A', 'B', 'C', 'D', 'E')),
        sonuc TEXT NOT NULL CHECK (sonuc IN ('dogru', 'yanlis', 'bos')),
        cozum_suresi_saniye INTEGER,
        cozulme_tarihi TEXT DEFAULT CURRENT_TIMESTAMP,
        senkronize_edildi_mi INTEGER DEFAULT 0,
        FOREIGN KEY (kullanici_id) REFERENCES kullanici(id) ON DELETE CASCADE,
        FOREIGN KEY (soru_id) REFERENCES soru(soru_id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS soru_favori (
        kullanici_id INTEGER NOT NULL,
        soru_id INTEGER NOT NULL,
        favoriye_eklenme_tarihi TEXT DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (kullanici_id, soru_id),
        FOREIGN KEY (kullanici_id) REFERENCES kullanici(id) ON DELETE CASCADE,
        FOREIGN KEY (soru_id) REFERENCES soru(soru_id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS geribildirim (
        kullanici_id INTEGER NOT NULL,
        soru_id INTEGER NOT NULL,
        dogru_cevap_yok INTEGER NOT NULL DEFAULT 0,
        birden_cok_dogru_cevap INTEGER NOT NULL DEFAULT 0,
        soru_metni_yanlis INTEGER NOT NULL DEFAULT 0,
        yazim_hatasi INTEGER NOT NULL DEFAULT 0,
        ipucu_yanlis INTEGER NOT NULL DEFAULT 0,
        tarih_saat TEXT NOT NULL,
        PRIMARY KEY (kullanici_id, soru_id),
        FOREIGN KEY (kullanici_id) REFERENCES kullanici(id) ON DELETE CASCADE,
        FOREIGN KEY (soru_id) REFERENCES soru(soru_id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS oturum (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        token TEXT NOT NULL,
        uzak_kullanici_id INTEGER,
        email TEXT,
        rol TEXT NOT NULL DEFAULT 'kullanici',
        hesap_turu TEXT NOT NULL DEFAULT 'ucretsiz',
        guncellenme_tarihi TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS deneme (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        kullanici_id INTEGER,
        soru_id INTEGER NOT NULL,
        deneme_adi TEXT NOT NULL,
        toplam_soru_sayisi INTEGER NOT NULL,
        dogru_sayisi INTEGER DEFAULT 0,
        yanlis_sayisi INTEGER DEFAULT 0,
        bos_sayisi INTEGER DEFAULT 0,
        cozum_suresi_saniye INTEGER,
        olusturulma_tarihi TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (kullanici_id) REFERENCES kullanici(id) ON DELETE CASCADE,
        FOREIGN KEY (soru_id) REFERENCES soru(soru_id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS deneme_soru (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        kullanici_id INTEGER NOT NULL,
        soru_id INTEGER NOT NULL,
        deneme_adi TEXT NOT NULL,
        verilen_cevap TEXT,
        dogru_cevap TEXT,
        sonuc TEXT,
        olusturulma_tarihi TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (kullanici_id) REFERENCES kullanici(id) ON DELETE CASCADE,
        FOREIGN KEY (soru_id) REFERENCES soru(soru_id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS yanlis_tekrar_anlasildi (
        kullanici_id INTEGER NOT NULL,
        soru_id INTEGER NOT NULL,
        isaretlenme_tarihi TEXT DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (kullanici_id, soru_id),
        FOREIGN KEY (kullanici_id) REFERENCES kullanici(id) ON DELETE CASCADE,
        FOREIGN KEY (soru_id) REFERENCES soru(soru_id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS disari_aktarilan_soru (
        kullanici_id INTEGER NOT NULL,
        soru_id INTEGER NOT NULL,
        aktarilma_tarihi TEXT DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (kullanici_id, soru_id),
        FOREIGN KEY (kullanici_id) REFERENCES kullanici(id) ON DELETE CASCADE,
        FOREIGN KEY (soru_id) REFERENCES soru(soru_id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS senkron_durumu (
        anahtar TEXT PRIMARY KEY,
        deger TEXT NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_soru_konu_id ON soru (konu_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_soru_durum ON soru (durum)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_deneme_kullanici_id ON deneme (kullanici_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_deneme_soru_kullanici_id ON deneme_soru (kullanici_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_deneme_soru_soru_id ON deneme_soru (soru_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_yanlis_tekrar_anlasildi_soru_id ON yanlis_tekrar_anlasildi (soru_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_disari_aktarilan_soru_soru_id ON disari_aktarilan_soru (soru_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_kullanici_soru_cozumu_kullanici_id ON kullanici_soru_cozumu (kullanici_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_kullanici_soru_cozumu_soru_id ON kullanici_soru_cozumu (soru_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_kullanici_soru_cozumu_senkron ON kullanici_soru_cozumu (senkronize_edildi_mi)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_soru_favori_soru_id ON soru_favori (soru_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_geribildirim_soru_id ON geribildirim (soru_id)',
    );
  }

  Future<void> _varsayilanVerileriEkle(Database db) async {
    await db.insert('kullanici', {
      'ad_soyad': 'Test Kullanıcı',
      'email': 'test@test.com',
      'sifre_hash': 'testtest0',
      'hesap_turu': 'ucretsiz',
      'rol': 'kullanici',
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    for (var i = 0; i < kKonular.length; i++) {
      await db.insert('konu', {
        'konu_adi': kKonular[i],
        'konu_metin':
            '${kKonular[i]} konusu için temel bilgiler, örnekler ve pratik sorular.',
        'sort_order': i,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    final konuIdleri = await _konuIdHaritasi(db);
    final ornekSorular = [
      Soru(
        konuId: konuIdleri['Birinci Dereceden Denklemler'] ?? 1,
        soruMetni: '2x + 5 = 15',
        soruKoku: 'Yukarıdaki eşitliğe göre x kaçtır?',
        secenekA: '3',
        secenekB: '4',
        secenekC: '5',
        secenekD: '6',
        secenekE: '7',
        dogruSecenek: 'C',
        cozum: '2x = 10 olduğundan x = 5.',
      ),
      Soru(
        konuId: konuIdleri['Rasyonel Sayılar'] ?? 1,
        soruMetni: '1/2 + 1/3',
        soruKoku: 'İşleminin sonucu kaçtır?',
        secenekA: '2/5',
        secenekB: '5/6',
        secenekC: '1/5',
        secenekD: '1/6',
        secenekE: '1',
        dogruSecenek: 'B',
        cozum: 'Payda 6 yapılır: 3/6 + 2/6 = 5/6.',
      ),
      Soru(
        konuId: konuIdleri['Üslü Sayılar'] ?? 1,
        soruMetni: '2^3 x 2^2',
        soruKoku: 'İşleminin sonucu aşağıdakilerden hangisidir?',
        secenekA: '2^5',
        secenekB: '2^6',
        secenekC: '4^5',
        secenekD: '4^6',
        secenekE: '2^1',
        dogruSecenek: 'A',
        cozum: 'Tabanlar aynıysa üsler toplanır: 3 + 2 = 5.',
      ),
    ];

    for (final soru in ornekSorular) {
      await db.insert(
        'soru',
        soru.haritayaDonustur(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Future<Map<String, int>> _konuIdHaritasi(Database db) async {
    final rows = await db.query('konu', columns: ['id', 'konu_adi']);
    return {
      for (final row in rows) row['konu_adi'] as String: row['id'] as int,
    };
  }

  Future<int> kullaniciOlustur({
    required String ad,
    required String email,
    required String sifre,
  }) async {
    final db = await veritabani;
    return db.insert('kullanici', {
      'ad_soyad': ad,
      'email': email,
      'sifre_hash': sifre,
      'hesap_turu': 'ucretsiz',
      'rol': 'kullanici',
    }, conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future<void> kullaniciApiKaydet({
    int? uzakKullaniciId,
    required String ad,
    required String email,
    String hesapTuru = 'ucretsiz',
    String rol = 'kullanici',
    String sifreHash = '',
  }) async {
    final db = await veritabani;
    final mevcut = await db.query(
      'kullanici',
      columns: ['id'],
      where: 'email = ?',
      whereArgs: [email],
      limit: 1,
    );

    final values = {
      'uzak_kullanici_id': uzakKullaniciId,
      'ad_soyad': ad,
      'email': email,
      'sifre_hash': sifreHash,
      'hesap_turu': hesapTuru,
      'rol': rol,
    };

    if (mevcut.isEmpty) {
      await db.insert('kullanici', values);
    } else {
      await db.update(
        'kullanici',
        values,
        where: 'email = ?',
        whereArgs: [email],
      );
    }
  }

  // Hesap ekraninda admin butonunun acik olup olmayacagini buradan kontrol ediyoruz.
  Future<bool> aktifKullaniciAdminMi() async {
    final kullanici = await aktifKullaniciyiGetir();
    return kullanici?['rol'] == 'admin';
  }

  Future<bool> kullaniciDogrula(String email, String sifre) async {
    final db = await veritabani;
    final rows = await db.query(
      'kullanici',
      where: 'email = ? AND sifre_hash = ?',
      whereArgs: [email, sifre],
      limit: 1,
    );
    if (rows.isEmpty) return false;

    final kullanici = rows.first;
    await oturumKaydet(
      token: 'local-${kullanici['id']}',
      email: kullanici['email'] as String?,
      rol: (kullanici['rol'] as String?) ?? 'kullanici',
      hesapTuru: (kullanici['hesap_turu'] as String?) ?? 'ucretsiz',
    );
    return true;
  }

  Future<Map<String, Object?>?> aktifKullaniciyiGetir() async {
    final db = await veritabani;
    final oturum = await oturumuGetir();
    final email = oturum?['email'];
    if (email == null) return null;

    final rows = await db.query(
      'kullanici',
      where: 'email = ?',
      whereArgs: [email],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<Map<String, int>> aktifKullaniciIstatistikleriniGetir() async {
    final db = await veritabani;
    final kullanici = await aktifKullaniciyiGetir();
    if (kullanici == null) {
      return {
        'toplam': 0,
        'dogru': 0,
        'yanlis': 0,
        'bos': 0,
        'bitirilenKonu': 0,
        'toplamKonu': 0,
      };
    }

    final kullaniciId = kullanici['id'] as int;
    final sonucRows = await db.rawQuery(
      '''
      SELECT
        COUNT(*) AS toplam,
        SUM(CASE WHEN sonuc = 'dogru' THEN 1 ELSE 0 END) AS dogru,
        SUM(CASE WHEN sonuc = 'yanlis' THEN 1 ELSE 0 END) AS yanlis,
        SUM(CASE WHEN sonuc = 'bos' THEN 1 ELSE 0 END) AS bos
      FROM kullanici_soru_cozumu cozum
      INNER JOIN (
        SELECT soru_id, MAX(cozum_id) AS son_cozum_id
        FROM kullanici_soru_cozumu
        WHERE kullanici_id = ?
        GROUP BY soru_id
      ) son_cozumler ON son_cozumler.son_cozum_id = cozum.cozum_id
      ''',
      [kullaniciId],
    );
    final konuRows = await db.rawQuery(
      '''
      SELECT COUNT(DISTINCT soru.konu_id) AS bitirilen
      FROM kullanici_soru_cozumu
      INNER JOIN soru ON soru.soru_id = kullanici_soru_cozumu.soru_id
      WHERE kullanici_soru_cozumu.kullanici_id = ?
      ''',
      [kullaniciId],
    );
    final toplamKonuRows = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM konu',
    );
    final sonuc = sonucRows.first;

    return {
      'toplam': (sonuc['toplam'] as int?) ?? 0,
      'dogru': (sonuc['dogru'] as int?) ?? 0,
      'yanlis': (sonuc['yanlis'] as int?) ?? 0,
      'bos': (sonuc['bos'] as int?) ?? 0,
      'bitirilenKonu': (konuRows.first['bitirilen'] as int?) ?? 0,
      'toplamKonu': Sqflite.firstIntValue(toplamKonuRows) ?? 0,
    };
  }

  Future<List<Map<String, Object?>>> aktifKullaniciGunlukIstatistikleriniGetir({
    int gunSayisi = 365,
  }) async {
    final db = await veritabani;
    final kullanici = await aktifKullaniciyiGetir();
    if (kullanici == null) return [];

    final kullaniciId = kullanici['id'] as int;
    final baslangic = DateTime.now()
        .subtract(Duration(days: gunSayisi - 1))
        .toIso8601String()
        .substring(0, 10);
    return db.rawQuery(
      '''
      SELECT
        substr(cozulme_tarihi, 1, 10) AS gun,
        COUNT(*) AS toplam,
        SUM(CASE WHEN sonuc = 'dogru' THEN 1 ELSE 0 END) AS dogru,
        SUM(CASE WHEN sonuc = 'yanlis' THEN 1 ELSE 0 END) AS yanlis,
        SUM(CASE WHEN sonuc = 'bos' THEN 1 ELSE 0 END) AS bos
      FROM kullanici_soru_cozumu cozum
      INNER JOIN (
        SELECT soru_id, MAX(cozum_id) AS son_cozum_id
        FROM kullanici_soru_cozumu
        WHERE kullanici_id = ?
        GROUP BY soru_id
      ) son_cozumler ON son_cozumler.son_cozum_id = cozum.cozum_id
      WHERE substr(cozum.cozulme_tarihi, 1, 10) >= ?
      GROUP BY substr(cozum.cozulme_tarihi, 1, 10)
      ORDER BY gun ASC
      ''',
      [kullaniciId, baslangic],
    );
  }

  Future<List<Map<String, Object?>>>
  aktifKullaniciKonuGunlukIstatistikleriniGetir({int gunSayisi = 365}) async {
    final db = await veritabani;
    final kullanici = await aktifKullaniciyiGetir();
    if (kullanici == null) return [];

    final kullaniciId = kullanici['id'] as int;
    final baslangic = DateTime.now()
        .subtract(Duration(days: gunSayisi - 1))
        .toIso8601String()
        .substring(0, 10);
    return db.rawQuery(
      '''
      SELECT
        soru.konu_id AS konu_id,
        substr(cozum.cozulme_tarihi, 1, 10) AS gun,
        COUNT(*) AS toplam,
        SUM(CASE WHEN cozum.sonuc = 'dogru' THEN 1 ELSE 0 END) AS dogru,
        SUM(CASE WHEN cozum.sonuc = 'yanlis' THEN 1 ELSE 0 END) AS yanlis,
        SUM(CASE WHEN cozum.sonuc = 'bos' THEN 1 ELSE 0 END) AS bos
      FROM kullanici_soru_cozumu cozum
      INNER JOIN soru ON soru.soru_id = cozum.soru_id
      INNER JOIN (
        SELECT soru_id, MAX(cozum_id) AS son_cozum_id
        FROM kullanici_soru_cozumu
        WHERE kullanici_id = ?
        GROUP BY soru_id
      ) son_cozumler ON son_cozumler.son_cozum_id = cozum.cozum_id
      WHERE substr(cozum.cozulme_tarihi, 1, 10) >= ?
      GROUP BY soru.konu_id, substr(cozum.cozulme_tarihi, 1, 10)
      ORDER BY gun ASC
      ''',
      [kullaniciId, baslangic],
    );
  }

  Future<List<Map<String, Object?>>>
  aktifKullaniciKonuIstatistikleriniGetir() async {
    final db = await veritabani;
    final kullanici = await aktifKullaniciyiGetir();
    if (kullanici == null) return [];

    final kullaniciId = kullanici['id'] as int;
    return db.rawQuery(
      '''
      SELECT
        konu.id AS konu_id,
        konu.konu_adi AS konu_adi,
        COUNT(cozum.cozum_id) AS toplam,
        SUM(CASE WHEN cozum.sonuc = 'dogru' THEN 1 ELSE 0 END) AS dogru,
        SUM(CASE WHEN cozum.sonuc = 'yanlis' THEN 1 ELSE 0 END) AS yanlis,
        SUM(CASE WHEN cozum.sonuc = 'bos' THEN 1 ELSE 0 END) AS bos
      FROM kullanici_soru_cozumu cozum
      INNER JOIN soru ON soru.soru_id = cozum.soru_id
      INNER JOIN konu ON konu.id = soru.konu_id
      INNER JOIN (
        SELECT soru_id, MAX(cozum_id) AS son_cozum_id
        FROM kullanici_soru_cozumu
        WHERE kullanici_id = ?
        GROUP BY soru_id
      ) son_cozumler ON son_cozumler.son_cozum_id = cozum.cozum_id
      GROUP BY konu.id, konu.konu_adi
      ORDER BY toplam DESC, konu.konu_adi ASC
      ''',
      [kullaniciId],
    );
  }

  Future<void> denemeSonucuKaydet({
    required int kullaniciId,
    required int soruId,
    required String denemeAdi,
    required int toplamSoruSayisi,
    required int dogruSayisi,
    required int yanlisSayisi,
    required int bosSayisi,
    required int cozumSuresiSaniye,
  }) async {
    final db = await veritabani;
    await db.insert('deneme', {
      'kullanici_id': kullaniciId,
      'soru_id': soruId,
      'deneme_adi': denemeAdi,
      'toplam_soru_sayisi': toplamSoruSayisi,
      'dogru_sayisi': dogruSayisi,
      'yanlis_sayisi': yanlisSayisi,
      'bos_sayisi': bosSayisi,
      'cozum_suresi_saniye': cozumSuresiSaniye,
      'olusturulma_tarihi': DateTime.now().toIso8601String(),
    });
  }

  Future<void> denemeSorulariniKaydet({
    required int kullaniciId,
    required String denemeAdi,
    required Iterable<int> soruIdleri,
    Map<int, String?> verilenCevaplar = const <int, String?>{},
    Map<int, String> dogruCevaplar = const <int, String>{},
    Map<int, String> sonuclar = const <int, String>{},
  }) async {
    final db = await veritabani;
    await _denemeSoruTablosunuHazirla(db);
    final tarih = DateTime.now().toIso8601String();
    final batch = db.batch();

    for (final soruId in soruIdleri) {
      batch.insert('deneme_soru', {
        'kullanici_id': kullaniciId,
        'soru_id': soruId,
        'deneme_adi': denemeAdi,
        'verilen_cevap': verilenCevaplar[soruId],
        'dogru_cevap': dogruCevaplar[soruId],
        'sonuc': sonuclar[soruId],
        'olusturulma_tarihi': tarih,
      });
    }

    await batch.commit(noResult: true);
  }

  Future<List<Map<String, Object?>>> aktifKullaniciDenemeIstatistikleriniGetir({
    int? gunSayisi,
  }) async {
    final db = await veritabani;
    final kullanici = await aktifKullaniciyiGetir();
    if (kullanici == null) return [];

    final kullaniciId = kullanici['id'] as int;
    final where = <String>['kullanici_id = ?'];
    final args = <Object?>[kullaniciId];

    if (gunSayisi != null) {
      final baslangic = DateTime.now()
          .subtract(Duration(days: gunSayisi - 1))
          .toIso8601String()
          .substring(0, 10);
      where.add('substr(olusturulma_tarihi, 1, 10) >= ?');
      args.add(baslangic);
    }

    return db.query(
      'deneme',
      columns: [
        'id',
        'deneme_adi',
        'toplam_soru_sayisi',
        'dogru_sayisi',
        'yanlis_sayisi',
        'bos_sayisi',
        'cozum_suresi_saniye',
        'olusturulma_tarihi',
      ],
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'olusturulma_tarihi ASC, id ASC',
    );
  }

  Future<void> aktifKullaniciBilgileriniGuncelle({
    required String username,
    String? yeniSifre,
  }) async {
    final db = await veritabani;
    final kullanici = await aktifKullaniciyiGetir();
    if (kullanici == null) return;

    final values = <String, Object?>{'ad_soyad': username};
    if (yeniSifre != null && yeniSifre.isNotEmpty) {
      values['sifre_hash'] = yeniSifre;
    }

    await db.update(
      'kullanici',
      values,
      where: 'id = ?',
      whereArgs: [kullanici['id']],
    );
  }

  Future<bool> aktifKullaniciSifresiDogruMu(String sifre) async {
    final kullanici = await aktifKullaniciyiGetir();
    if (kullanici == null) return false;

    final kayitliSifre = kullanici['sifre_hash']?.toString() ?? '';
    return kayitliSifre.isNotEmpty && kayitliSifre == sifre;
  }

  Future<void> aktifKullaniciHesabiniSil() async {
    final db = await veritabani;
    final kullanici = await aktifKullaniciyiGetir();
    if (kullanici == null) return;

    await db.delete('kullanici', where: 'id = ?', whereArgs: [kullanici['id']]);
    await oturumSil();
  }

  Future<void> aktifKullaniciIstatistikleriniSifirla() async {
    final db = await veritabani;
    final kullanici = await aktifKullaniciyiGetir();
    if (kullanici == null) return;

    final kullaniciId = kullanici['id'] as int;
    await db.delete(
      'kullanici_soru_cozumu',
      where: 'kullanici_id = ?',
      whereArgs: [kullaniciId],
    );
    await db.delete(
      'deneme',
      where: 'kullanici_id = ?',
      whereArgs: [kullaniciId],
    );
    await _denemeSoruTablosunuHazirla(db);
    await db.delete(
      'deneme_soru',
      where: 'kullanici_id = ?',
      whereArgs: [kullaniciId],
    );
    await _yanlisTekrarAnlasildiTablosunuHazirla(db);
    await db.delete(
      'yanlis_tekrar_anlasildi',
      where: 'kullanici_id = ?',
      whereArgs: [kullaniciId],
    );
    await db.update(
      'kullanici',
      {
        'cozulen_toplam_soru': 0,
        'dogru_sayisi': 0,
        'yanlis_sayisi': 0,
        'bos_sayisi': 0,
      },
      where: 'id = ?',
      whereArgs: [kullaniciId],
    );
  }

  // API'den gelen token ve rol bilgisini telefonda saklar.
  Future<void> oturumKaydet({
    required String token,
    int? uzakKullaniciId,
    String? email,
    String rol = 'kullanici',
    String hesapTuru = 'ucretsiz',
  }) async {
    final db = await veritabani;
    await db.insert('oturum', {
      'id': 1,
      'token': token,
      'uzak_kullanici_id': uzakKullaniciId,
      'email': email,
      'rol': rol,
      'hesap_turu': hesapTuru,
      'guncellenme_tarihi': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // Cikis yapilinca kayitli tokeni telefondan siler.
  Future<void> oturumSil() async {
    final db = await veritabani;
    await db.delete('oturum');
  }

  // Uygulama acilirken kullanilacak kayitli token bilgisini getirir.
  Future<Map<String, Object?>?> oturumuGetir() async {
    final db = await veritabani;
    final rows = await db.query('oturum', where: 'id = ?', whereArgs: [1]);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  // Kullanici bir soruyu cozdüğunde yerel gecmise kaydeder.
  Future<int> soruCozumuKaydet(KullaniciSoruCozumu cozum) async {
    final db = await veritabani;
    final mevcutRows = await db.query(
      'kullanici_soru_cozumu',
      columns: ['cozum_id'],
      where: 'kullanici_id = ? AND soru_id = ?',
      whereArgs: [cozum.kullaniciId, cozum.soruId],
      orderBy: 'cozum_id DESC',
    );

    final values = cozum.haritayaDonustur()..remove('cozum_id');
    if (mevcutRows.isEmpty) {
      return db.insert('kullanici_soru_cozumu', values);
    }

    final cozumId = mevcutRows.first['cozum_id'] as int;
    await db.update(
      'kullanici_soru_cozumu',
      {...values, 'uzak_cozum_id': null, 'senkronize_edildi_mi': 0},
      where: 'cozum_id = ?',
      whereArgs: [cozumId],
    );
    if (mevcutRows.length > 1) {
      await db.delete(
        'kullanici_soru_cozumu',
        where: 'kullanici_id = ? AND soru_id = ? AND cozum_id <> ?',
        whereArgs: [cozum.kullaniciId, cozum.soruId, cozumId],
      );
    }
    return cozumId;
  }

  Future<Map<int, KullaniciSoruCozumu>> soruCozumleriniGetir(
    Iterable<int> soruIdleri,
  ) async {
    final db = await veritabani;
    final kullaniciId = await _aktifKullaniciIdGetir();
    final idler = soruIdleri.toSet().toList();
    if (kullaniciId == null || idler.isEmpty) return {};

    final placeholders = List.filled(idler.length, '?').join(', ');
    final rows = await db.rawQuery(
      '''
      SELECT cozum.*
      FROM kullanici_soru_cozumu cozum
      INNER JOIN (
        SELECT soru_id, MAX(cozum_id) AS son_cozum_id
        FROM kullanici_soru_cozumu
        WHERE kullanici_id = ? AND soru_id IN ($placeholders)
        GROUP BY soru_id
      ) son_cozumler ON son_cozumler.son_cozum_id = cozum.cozum_id
      ''',
      [kullaniciId, ...idler],
    );
    return {
      for (final row in rows)
        row['soru_id'] as int: KullaniciSoruCozumu.haritadanOlustur(row),
    };
  }

  // API'ye gonderilmemis cozumleri senkronizasyon icin listeler.
  Future<List<KullaniciSoruCozumu>> senkronBekleyenCozumleriGetir() async {
    final db = await veritabani;
    final rows = await db.rawQuery(
      '''
      SELECT cozum.*
      FROM kullanici_soru_cozumu cozum
      INNER JOIN (
        SELECT kullanici_id, soru_id, MAX(cozum_id) AS son_cozum_id
        FROM kullanici_soru_cozumu
        GROUP BY kullanici_id, soru_id
      ) son_cozumler ON son_cozumler.son_cozum_id = cozum.cozum_id
      WHERE cozum.senkronize_edildi_mi = ?
      ORDER BY cozum.cozum_id ASC
      ''',
      [0],
    );
    return rows.map(KullaniciSoruCozumu.haritadanOlustur).toList();
  }

  // API'ye gonderilen cozumleri tekrar gondermemek icin isaretler.
  Future<void> cozumSenkronizeIsaretle(int cozumId, int? uzakCozumId) async {
    final db = await veritabani;
    await db.update(
      'kullanici_soru_cozumu',
      {'senkronize_edildi_mi': 1, 'uzak_cozum_id': uzakCozumId},
      where: 'cozum_id = ?',
      whereArgs: [cozumId],
    );
  }

  Future<int> sonSoruIdGetir() async {
    final db = await veritabani;
    await _senkronDurumuTablosunuHazirla(db);
    final rows = await db.query(
      'senkron_durumu',
      columns: ['deger'],
      where: 'anahtar = ?',
      whereArgs: ['son_soru_id'],
      limit: 1,
    );
    if (rows.isEmpty) return 0;
    return int.tryParse(rows.first['deger']?.toString() ?? '') ?? 0;
  }

  Future<void> sonSoruIdKaydet(int sonSoruId) async {
    final db = await veritabani;
    await _senkronDurumuTablosunuHazirla(db);
    await db.insert('senkron_durumu', {
      'anahtar': 'son_soru_id',
      'deger': sonSoruId.toString(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _senkronDurumuTablosunuHazirla(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS senkron_durumu (
        anahtar TEXT PRIMARY KEY,
        deger TEXT NOT NULL
      )
    ''');
  }

  Future<void> _soruFavoriTablosunuHazirla(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS soru_favori (
        kullanici_id INTEGER NOT NULL,
        soru_id INTEGER NOT NULL,
        favoriye_eklenme_tarihi TEXT DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (kullanici_id, soru_id),
        FOREIGN KEY (kullanici_id) REFERENCES kullanici(id) ON DELETE CASCADE,
        FOREIGN KEY (soru_id) REFERENCES soru(soru_id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_soru_favori_soru_id ON soru_favori (soru_id)',
    );
  }

  Future<void> _geribildirimTablosunuHazirla(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS geribildirim (
        kullanici_id INTEGER NOT NULL,
        soru_id INTEGER NOT NULL,
        dogru_cevap_yok INTEGER NOT NULL DEFAULT 0,
        birden_cok_dogru_cevap INTEGER NOT NULL DEFAULT 0,
        soru_metni_yanlis INTEGER NOT NULL DEFAULT 0,
        yazim_hatasi INTEGER NOT NULL DEFAULT 0,
        ipucu_yanlis INTEGER NOT NULL DEFAULT 0,
        tarih_saat TEXT NOT NULL,
        PRIMARY KEY (kullanici_id, soru_id),
        FOREIGN KEY (kullanici_id) REFERENCES kullanici(id) ON DELETE CASCADE,
        FOREIGN KEY (soru_id) REFERENCES soru(soru_id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_geribildirim_soru_id ON geribildirim (soru_id)',
    );
  }

  Future<void> _denemeSoruTablosunuHazirla(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS deneme_soru (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        kullanici_id INTEGER NOT NULL,
        soru_id INTEGER NOT NULL,
        deneme_adi TEXT NOT NULL,
        verilen_cevap TEXT,
        dogru_cevap TEXT,
        sonuc TEXT,
        olusturulma_tarihi TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (kullanici_id) REFERENCES kullanici(id) ON DELETE CASCADE,
        FOREIGN KEY (soru_id) REFERENCES soru(soru_id) ON DELETE CASCADE
      )
    ''');
    await _sutunYoksaEkle(db, 'deneme_soru', 'verilen_cevap', 'TEXT');
    await _sutunYoksaEkle(db, 'deneme_soru', 'dogru_cevap', 'TEXT');
    await _sutunYoksaEkle(db, 'deneme_soru', 'sonuc', 'TEXT');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_deneme_soru_kullanici_id ON deneme_soru (kullanici_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_deneme_soru_soru_id ON deneme_soru (soru_id)',
    );
  }

  Future<void> _yanlisTekrarAnlasildiTablosunuHazirla(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS yanlis_tekrar_anlasildi (
        kullanici_id INTEGER NOT NULL,
        soru_id INTEGER NOT NULL,
        isaretlenme_tarihi TEXT DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (kullanici_id, soru_id),
        FOREIGN KEY (kullanici_id) REFERENCES kullanici(id) ON DELETE CASCADE,
        FOREIGN KEY (soru_id) REFERENCES soru(soru_id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_yanlis_tekrar_anlasildi_soru_id ON yanlis_tekrar_anlasildi (soru_id)',
    );
  }

  Future<void> _disariAktarilanSoruTablosunuHazirla(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS disari_aktarilan_soru (
        kullanici_id INTEGER NOT NULL,
        soru_id INTEGER NOT NULL,
        aktarilma_tarihi TEXT DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (kullanici_id, soru_id),
        FOREIGN KEY (kullanici_id) REFERENCES kullanici(id) ON DELETE CASCADE,
        FOREIGN KEY (soru_id) REFERENCES soru(soru_id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_disari_aktarilan_soru_soru_id ON disari_aktarilan_soru (soru_id)',
    );
  }

  Future<void> _sutunYoksaEkle(
    Database db,
    String tablo,
    String sutun,
    String tanim,
  ) async {
    final sutunlar = await db.rawQuery('PRAGMA table_info($tablo)');
    final varMi = sutunlar.any((satir) => satir['name'] == sutun);
    if (!varMi) {
      await db.execute('ALTER TABLE $tablo ADD COLUMN $sutun $tanim');
    }
  }

  Future<List<Konu>> konulariGetir() async {
    final db = await veritabani;
    final rows = await db.query('konu', orderBy: 'sort_order ASC, id ASC');
    return rows.map(Konu.haritadanOlustur).toList();
  }

  Future<Konu?> konuyuAdinaGoreGetir(String ad) async {
    final db = await veritabani;
    final rows = await db.query(
      'konu',
      where: 'konu_adi = ?',
      whereArgs: [ad],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Konu.haritadanOlustur(rows.first);
  }

  Future<List<Soru>> sorulariGetir({
    int? konuId,
    String? zorluk,
    int? limit,
    bool sadeceCozulmemis = false,
  }) async {
    final db = await veritabani;
    final where = <String>[];
    final args = <Object?>[];
    final kullanici = sadeceCozulmemis ? await aktifKullaniciyiGetir() : null;

    if (konuId != null) {
      where.add('konu_id = ?');
      args.add(konuId);
    }
    where.add('durum = ?');
    args.add('yayinda');

    if (zorluk != null && zorluk != 'Sana Özel') {
      where.add('difficulty = ?');
      args.add(zorluk);
    }
    if (sadeceCozulmemis && kullanici != null) {
      await _denemeSoruTablosunuHazirla(db);
      where.add('''
        NOT EXISTS (
          SELECT 1
          FROM kullanici_soru_cozumu cozum
          WHERE cozum.soru_id = soru.soru_id
            AND cozum.kullanici_id = ?
        )
      ''');
      args.add(kullanici['id'] as int);
      where.add('''
        NOT EXISTS (
          SELECT 1
          FROM deneme_soru deneme_soru
          WHERE deneme_soru.soru_id = soru.soru_id
            AND deneme_soru.kullanici_id = ?
        )
      ''');
      args.add(kullanici['id'] as int);
    }

    final rows = await db.query(
      'soru',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args,
      orderBy: 'soru_id ASC',
      limit: limit,
    );
    return rows.map(Soru.haritadanOlustur).toList();
  }

  Future<List<Soru>> disariAktarilmamisSorulariGetir({
    required int konuId,
    required int limit,
  }) async {
    final db = await veritabani;
    await _disariAktarilanSoruTablosunuHazirla(db);
    final kullaniciId = await _aktifKullaniciIdGetir();
    if (kullaniciId == null) return [];

    final rows = await db.rawQuery(
      '''
      SELECT soru.*
      FROM soru
      WHERE soru.konu_id = ?
        AND soru.durum = ?
        AND NOT EXISTS (
          SELECT 1
          FROM disari_aktarilan_soru aktarim
          WHERE aktarim.kullanici_id = ?
            AND aktarim.soru_id = soru.soru_id
        )
      ORDER BY soru.soru_id ASC
      LIMIT ?
      ''',
      [konuId, 'yayinda', kullaniciId, limit],
    );
    return rows.map(Soru.haritadanOlustur).toList();
  }

  Future<void> disariAktarilanSorulariIsaretle(Iterable<int> soruIdleri) async {
    final db = await veritabani;
    await _disariAktarilanSoruTablosunuHazirla(db);
    final kullaniciId = await _aktifKullaniciIdGetir();
    final idler = soruIdleri.toSet().toList();
    if (kullaniciId == null || idler.isEmpty) return;

    final tarih = DateTime.now().toIso8601String();
    final batch = db.batch();
    for (final soruId in idler) {
      batch.insert('disari_aktarilan_soru', {
        'kullanici_id': kullaniciId,
        'soru_id': soruId,
        'aktarilma_tarihi': tarih,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<int?> _aktifKullaniciIdGetir() async {
    final kullanici = await aktifKullaniciyiGetir();
    return kullanici?['id'] as int?;
  }

  Future<bool> soruFavorideMi(int soruId) async {
    final db = await veritabani;
    await _soruFavoriTablosunuHazirla(db);
    final kullaniciId = await _aktifKullaniciIdGetir();
    if (kullaniciId == null) return false;

    final rows = await db.query(
      'soru_favori',
      columns: ['soru_id'],
      where: 'kullanici_id = ? AND soru_id = ?',
      whereArgs: [kullaniciId, soruId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> soruFavoriDurumunuAyarla(int soruId, bool favorideMi) async {
    final db = await veritabani;
    await _soruFavoriTablosunuHazirla(db);
    final kullaniciId = await _aktifKullaniciIdGetir();
    if (kullaniciId == null) return;

    if (favorideMi) {
      await db.insert('soru_favori', {
        'kullanici_id': kullaniciId,
        'soru_id': soruId,
        'favoriye_eklenme_tarihi': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return;
    }

    await db.delete(
      'soru_favori',
      where: 'kullanici_id = ? AND soru_id = ?',
      whereArgs: [kullaniciId, soruId],
    );
  }

  Future<List<Soru>> favoriSorulariGetir() async {
    final db = await veritabani;
    await _soruFavoriTablosunuHazirla(db);
    final kullaniciId = await _aktifKullaniciIdGetir();
    if (kullaniciId == null) return [];

    final rows = await db.rawQuery(
      '''
      SELECT soru.*
      FROM soru
      INNER JOIN soru_favori ON soru_favori.soru_id = soru.soru_id
      WHERE soru_favori.kullanici_id = ? AND soru.durum = ?
      ORDER BY soru_favori.favoriye_eklenme_tarihi DESC
      ''',
      [kullaniciId, 'yayinda'],
    );
    return rows.map(Soru.haritadanOlustur).toList();
  }

  Future<List<Soru>> yanlisSorulariGetir({int limit = 20}) async {
    final db = await veritabani;
    await _denemeSoruTablosunuHazirla(db);
    await _yanlisTekrarAnlasildiTablosunuHazirla(db);
    final kullaniciId = await _aktifKullaniciIdGetir();
    if (kullaniciId == null) return [];

    final rows = await db.rawQuery(
      '''
      SELECT soru.*
      FROM soru
      INNER JOIN (
        SELECT soru_id, MAX(tarih) AS son_yanlis_tarihi
        FROM (
          SELECT cozum.soru_id, cozum.cozulme_tarihi AS tarih
          FROM kullanici_soru_cozumu cozum
          INNER JOIN (
            SELECT soru_id, MAX(cozum_id) AS son_cozum_id
            FROM kullanici_soru_cozumu
            WHERE kullanici_id = ?
            GROUP BY soru_id
          ) son_cozumler ON son_cozumler.son_cozum_id = cozum.cozum_id
          WHERE cozum.sonuc = ?

          UNION ALL

          SELECT deneme_soru.soru_id, deneme_soru.olusturulma_tarihi AS tarih
          FROM deneme_soru
          WHERE deneme_soru.kullanici_id = ?
            AND deneme_soru.sonuc = ?
        ) yanlis_kayitlar
        GROUP BY soru_id
      ) yanlislar ON yanlislar.soru_id = soru.soru_id
      WHERE soru.durum = ?
        AND NOT EXISTS (
          SELECT 1
          FROM yanlis_tekrar_anlasildi anlasildi
          WHERE anlasildi.kullanici_id = ?
            AND anlasildi.soru_id = soru.soru_id
        )
      ORDER BY yanlislar.son_yanlis_tarihi DESC
      LIMIT ?
      ''',
      [
        kullaniciId,
        'yanlis',
        kullaniciId,
        'yanlis',
        'yayinda',
        kullaniciId,
        limit,
      ],
    );
    return rows.map(Soru.haritadanOlustur).toList();
  }

  Future<void> yanlisTekrarAnlasildiIsaretle(int soruId) async {
    final db = await veritabani;
    await _yanlisTekrarAnlasildiTablosunuHazirla(db);
    final kullaniciId = await _aktifKullaniciIdGetir();
    if (kullaniciId == null) return;

    await db.insert('yanlis_tekrar_anlasildi', {
      'kullanici_id': kullaniciId,
      'soru_id': soruId,
      'isaretlenme_tarihi': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<bool> soruGeribildirimiKaydet({
    required int soruId,
    required bool dogruCevapYok,
    required bool birdenCokDogruCevap,
    required bool soruMetniYanlis,
    required bool yazimHatasi,
    required bool ipucuYanlis,
  }) async {
    final db = await veritabani;
    await _geribildirimTablosunuHazirla(db);
    final kullaniciId = await _aktifKullaniciIdGetir();
    if (kullaniciId == null) return false;

    await db.insert('geribildirim', {
      'kullanici_id': kullaniciId,
      'soru_id': soruId,
      'dogru_cevap_yok': dogruCevapYok ? 1 : 0,
      'birden_cok_dogru_cevap': birdenCokDogruCevap ? 1 : 0,
      'soru_metni_yanlis': soruMetniYanlis ? 1 : 0,
      'yazim_hatasi': yazimHatasi ? 1 : 0,
      'ipucu_yanlis': ipucuYanlis ? 1 : 0,
      'tarih_saat': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return true;
  }

  Future<int> konuSoruSayisiniGetir(int konuId) async {
    final db = await veritabani;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM soru WHERE konu_id = ? AND durum = ?',
      [konuId, 'yayinda'],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<void> konulariKaydet(List<Konu> konular) async {
    final db = await veritabani;
    final batch = db.batch();
    for (final konu in konular) {
      batch.insert(
        'konu',
        konu.haritayaDonustur(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> sorulariKaydet(List<Soru> sorular) async {
    final db = await veritabani;
    final batch = db.batch();
    for (final soru in sorular) {
      final map = soru.haritayaDonustur();
      batch.insert('soru', map, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }
}
