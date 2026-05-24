-- Ana veritabaninin tablo yapisini burada kuruyoruz.
-- Tablolarin sirasi baglantilar bozulmasin diye onemlidir.

-- Konu listesini ve konuya ait temel bilgileri tutar.
CREATE TABLE IF NOT EXISTS konu (
    id SERIAL PRIMARY KEY,
    konu_adi VARCHAR(255) NOT NULL,
    konu_metin TEXT,
    konu_resmi VARCHAR(500)
);

-- Uygulamaya kayit olan kullanicilarin bilgilerini tutar.
CREATE TABLE IF NOT EXISTS kullanici (
    kullanici_id SERIAL PRIMARY KEY,
    ad VARCHAR(120) NOT NULL,
    eposta VARCHAR(255) UNIQUE NOT NULL,
    sifre_ozeti VARCHAR(255) NOT NULL,
    hesap_turu VARCHAR(20) NOT NULL DEFAULT 'ucretsiz',
    rol VARCHAR(20) NOT NULL DEFAULT 'kullanici' CHECK (rol IN ('kullanici', 'admin')),
    kayit_tarihi TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    cozulen_toplam_soru INTEGER DEFAULT 0,
    dogru_sayisi INTEGER DEFAULT 0,
    yanlis_sayisi INTEGER DEFAULT 0,
    bos_sayisi INTEGER DEFAULT 0
);

-- Eski kullanici tablo adlari varsa API'nin bekledigi yeni adlara tasir.
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'kullanici' AND column_name = 'id'
    ) AND NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'kullanici' AND column_name = 'kullanici_id'
    ) THEN
        ALTER TABLE kullanici RENAME COLUMN id TO kullanici_id;
    END IF;

    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'kullanici' AND column_name = 'ad_soyad'
    ) AND NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'kullanici' AND column_name = 'ad'
    ) THEN
        ALTER TABLE kullanici RENAME COLUMN ad_soyad TO ad;
    END IF;

    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'kullanici' AND column_name = 'email'
    ) AND NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'kullanici' AND column_name = 'eposta'
    ) THEN
        ALTER TABLE kullanici RENAME COLUMN email TO eposta;
    END IF;

    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'kullanici' AND column_name = 'sifre_hash'
    ) AND NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'kullanici' AND column_name = 'sifre_ozeti'
    ) THEN
        ALTER TABLE kullanici RENAME COLUMN sifre_hash TO sifre_ozeti;
    END IF;
END
$$;

-- Yapay zeka tarafindan uretilen ve mobil uygulamaya gonderilecek sorulari tutar.
CREATE TABLE IF NOT EXISTS soru (
    soru_id SERIAL PRIMARY KEY,
    sorumetni TEXT NOT NULL,
    soruresmi VARCHAR(500) NULL,
    sorukoku TEXT NOT NULL,
    secenek_a TEXT NOT NULL,
    secenek_b TEXT NOT NULL,
    secenek_c TEXT NOT NULL,
    secenek_d TEXT NOT NULL,
    secenek_e TEXT NOT NULL,
    dogrucevap CHAR(1) NOT NULL CHECK (dogrucevap IN ('A', 'B', 'C', 'D', 'E')),
    cozum JSONB NOT NULL DEFAULT '[]'::jsonb,
    konu_id INTEGER NOT NULL REFERENCES konu(id) ON DELETE CASCADE,
    difficulty VARCHAR(20) NOT NULL DEFAULT 'Orta' CHECK (difficulty IN ('Kolay', 'Orta', 'Zor')),
    durum VARCHAR(20) NOT NULL DEFAULT 'yayinda' CHECK (durum IN ('taslak', 'yayinda', 'pasif', 'hatali')),
    olusturulma_tarihi TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    guncellenme_tarihi TIMESTAMP NULL
);

-- Admin panelinden degistirilen canli ayarlari tutar.
CREATE TABLE IF NOT EXISTS ayar (
    ayar_id SERIAL PRIMARY KEY,
    anahtar VARCHAR(120) NOT NULL UNIQUE,
    deger VARCHAR(255) NOT NULL,
    guncellenme_tarihi TIMESTAMP NULL
);

-- Adminin yaptigi onemli islemleri sonradan kontrol etmek icin kaydeder.
CREATE TABLE IF NOT EXISTS admin_islem_kaydi (
    islem_id SERIAL PRIMARY KEY,
    kullanici_id INTEGER NOT NULL,
    islem VARCHAR(120) NOT NULL,
    detay JSONB NOT NULL DEFAULT '{}'::jsonb,
    islem_tarihi TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Kullanicinin cozdugu deneme ve soru gecmisini tutar.
CREATE TABLE IF NOT EXISTS deneme (
    id SERIAL PRIMARY KEY,
    kullanici_id INTEGER NOT NULL REFERENCES kullanici(kullanici_id) ON DELETE CASCADE,
    soru_id INTEGER NOT NULL REFERENCES soru(soru_id) ON DELETE CASCADE,
    deneme_adi VARCHAR(255) NOT NULL,
    toplam_soru_sayisi INTEGER NOT NULL,
    dogru_sayisi INTEGER DEFAULT 0,
    yanlis_sayisi INTEGER DEFAULT 0,
    bos_sayisi INTEGER DEFAULT 0,
    cozum_suresi_saniye INTEGER,
    olusturulma_tarihi TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Kullanicinin tek tek cozdugu sorularin gecmisini tutar.
CREATE TABLE IF NOT EXISTS kullanici_soru_cozumu (
    cozum_id SERIAL PRIMARY KEY,
    kullanici_id INTEGER NOT NULL REFERENCES kullanici(kullanici_id) ON DELETE CASCADE,
    soru_id INTEGER NOT NULL REFERENCES soru(soru_id) ON DELETE CASCADE,
    verilen_cevap CHAR(1) NULL CHECK (verilen_cevap IS NULL OR verilen_cevap IN ('A', 'B', 'C', 'D', 'E')),
    dogru_cevap CHAR(1) NOT NULL CHECK (dogru_cevap IN ('A', 'B', 'C', 'D', 'E')),
    sonuc VARCHAR(20) NOT NULL CHECK (sonuc IN ('dogru', 'yanlis', 'bos')),
    cozum_suresi_saniye INTEGER NULL,
    cozulme_tarihi TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Soru listelerini konuya gore daha hizli getirmek icin kullanilir.
CREATE INDEX IF NOT EXISTS idx_soru_konu_id ON soru (konu_id);

-- Bir kullanicinin deneme kayitlarini daha hizli bulmak icin kullanilir.
CREATE INDEX IF NOT EXISTS idx_deneme_kullanici_id ON deneme (kullanici_id);

-- Bir kullanicinin soru cozme gecmisini daha hizli bulmak icin kullanilir.
CREATE INDEX IF NOT EXISTS idx_kullanici_soru_cozumu_kullanici_id ON kullanici_soru_cozumu (kullanici_id);

-- Bir sorunun hangi cozumlerde kullanildigini daha hizli bulmak icin kullanilir.
CREATE INDEX IF NOT EXISTS idx_kullanici_soru_cozumu_soru_id ON kullanici_soru_cozumu (soru_id);

-- Admin ayarlarini anahtar adina gore hizli bulmak icin kullanilir.
CREATE INDEX IF NOT EXISTS idx_ayar_anahtar ON ayar (anahtar);

-- Admin islem gecmisini kullaniciya gore hizli sorgulamak icin kullanilir.
CREATE INDEX IF NOT EXISTS idx_admin_islem_kaydi_kullanici_id ON admin_islem_kaydi (kullanici_id);

-- Daha once kurulmus kullanici tablosunda yeni alanlar yoksa ekler.
ALTER TABLE kullanici
ADD COLUMN IF NOT EXISTS rol VARCHAR(20) NOT NULL DEFAULT 'kullanici',
ADD COLUMN IF NOT EXISTS hesap_turu VARCHAR(20) NOT NULL DEFAULT 'ucretsiz',
ADD COLUMN IF NOT EXISTS cozulen_toplam_soru INTEGER NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS dogru_sayisi INTEGER NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS yanlis_sayisi INTEGER NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS bos_sayisi INTEGER NOT NULL DEFAULT 0;

-- Daha once kurulmus soru tablosunda yayin ve tarih alanlari yoksa ekler.
ALTER TABLE soru
ADD COLUMN IF NOT EXISTS durum VARCHAR(20) NOT NULL DEFAULT 'yayinda',
ADD COLUMN IF NOT EXISTS difficulty VARCHAR(20) NOT NULL DEFAULT 'Orta',
ADD COLUMN IF NOT EXISTS olusturulma_tarihi TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
ADD COLUMN IF NOT EXISTS guncellenme_tarihi TIMESTAMP NULL;

-- Sadece yayindaki veya pasif sorulari daha hizli ayirmak icin kullanilir.
CREATE INDEX IF NOT EXISTS idx_soru_durum ON soru (durum);

-- Kullanici rolu bos veya hatali kaldiysa normal kullanici yapar.
UPDATE kullanici
SET rol = 'kullanici'
WHERE rol IS NULL OR rol NOT IN ('kullanici', 'admin');

-- Soru durumu bos veya hatali kaldiysa yayinda kabul eder.
UPDATE soru
SET durum = 'yayinda'
WHERE durum IS NULL OR durum NOT IN ('taslak', 'yayinda', 'pasif', 'hatali');

-- Soru zorlugu bos veya hatali kaldiysa orta kabul eder.
UPDATE soru
SET difficulty = 'Orta'
WHERE difficulty IS NULL OR difficulty NOT IN ('Kolay', 'Orta', 'Zor');

-- Kullanici rolune sadece izin verilen degerlerin yazilmasini saglar.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'kullanici_rol_kontrol'
    ) THEN
        ALTER TABLE kullanici
        ADD CONSTRAINT kullanici_rol_kontrol
        CHECK (rol IN ('kullanici', 'admin'));
    END IF;
END
$$;

-- Soru zorluguna sadece izin verilen degerlerin yazilmasini saglar.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'soru_difficulty_kontrol'
    ) THEN
        ALTER TABLE soru
        ADD CONSTRAINT soru_difficulty_kontrol
        CHECK (difficulty IN ('Kolay', 'Orta', 'Zor'));
    END IF;
END
$$;

-- Cozum gecmisinde verilen cevaba sadece sik harfi veya bos deger yazilmasini saglar.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'kullanici_soru_cozumu_verilen_cevap_kontrol'
    ) THEN
        ALTER TABLE kullanici_soru_cozumu
        ADD CONSTRAINT kullanici_soru_cozumu_verilen_cevap_kontrol
        CHECK (verilen_cevap IS NULL OR verilen_cevap IN ('A', 'B', 'C', 'D', 'E'));
    END IF;
END
$$;

-- Cozum sonucuna sadece dogru, yanlis veya bos yazilmasini saglar.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'kullanici_soru_cozumu_sonuc_kontrol'
    ) THEN
        ALTER TABLE kullanici_soru_cozumu
        ADD CONSTRAINT kullanici_soru_cozumu_sonuc_kontrol
        CHECK (sonuc IN ('dogru', 'yanlis', 'bos'));
    END IF;
END
$$;

-- Soru durumuna sadece izin verilen degerlerin yazilmasini saglar.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'soru_durum_kontrol'
    ) THEN
        ALTER TABLE soru
        ADD CONSTRAINT soru_durum_kontrol
        CHECK (durum IN ('taslak', 'yayinda', 'pasif', 'hatali'));
    END IF;
END
$$;
