-- PostgreSQL schema for DGS question bank
-- Table creation order matters to satisfy foreign keys.

CREATE TABLE IF NOT EXISTS konu (
    id SERIAL PRIMARY KEY,
    konu_adi VARCHAR(255) NOT NULL,
    konu_metin TEXT NOT NULL,
    konu_resmi VARCHAR(500)
);

CREATE TABLE IF NOT EXISTS kullanici (
    id SERIAL PRIMARY KEY,
    ad_soyad VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    sifre_hash VARCHAR(255) NOT NULL,
    kayit_tarihi TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    cozulen_toplam_soru INTEGER DEFAULT 0,
    dogru_sayisi INTEGER DEFAULT 0,
    yanlis_sayisi INTEGER DEFAULT 0,
    bos_sayisi INTEGER DEFAULT 0
);

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
    konu_id INTEGER NOT NULL REFERENCES konu(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS deneme (
    id SERIAL PRIMARY KEY,
    kullanici_id INTEGER NOT NULL REFERENCES kullanici(id) ON DELETE CASCADE,
    soru_id INTEGER NOT NULL REFERENCES soru(soru_id) ON DELETE CASCADE,
    deneme_adi VARCHAR(255) NOT NULL,
    toplam_soru_sayisi INTEGER NOT NULL,
    dogru_sayisi INTEGER DEFAULT 0,
    yanlis_sayisi INTEGER DEFAULT 0,
    bos_sayisi INTEGER DEFAULT 0,
    cozum_suresi_saniye INTEGER,
    olusturulma_tarihi TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_soru_konu_id ON soru (konu_id);
CREATE INDEX IF NOT EXISTS idx_deneme_kullanici_id ON deneme (kullanici_id);
