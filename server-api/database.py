import os
from datetime import datetime
from sqlalchemy import create_engine, Column, DateTime, ForeignKey, Integer, String, Text, CHAR, text
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import sessionmaker, declarative_base
from dotenv import load_dotenv

load_dotenv()

# Veritabanı bağlantı adresini ortam değişkeninden al.
VERITABANI_ADRESI = os.environ.get("DATABASE_URL", "postgresql://user:password@localhost/dgs_db")

# SQLAlchemy ana veritabanına bu motor üzerinden bağlanır.
veritabani_motoru = create_engine(
    VERITABANI_ADRESI,
    pool_pre_ping=True,
    pool_recycle=1800,
)

# Her API isteği için kısa ömürlü veritabanı oturumu buradan açılır.
OturumYerel = sessionmaker(autocommit=False, autoflush=False, bind=veritabani_motoru)

# Veritabanı tablolarının Python sınıfları için ortak temel sınıftır.
TemelModel = declarative_base()

# Ana veritabanındaki soru tablosunu temsil eder.
class Soru(TemelModel):
    __tablename__ = "soru"
    
    soru_id = Column(Integer, primary_key=True, index=True)
    sorumetni = Column(Text, nullable=False)
    soruresmi = Column(String(500), nullable=True)
    sorukoku = Column(Text, nullable=False)
    secenek_a = Column(Text, nullable=False)
    secenek_b = Column(Text, nullable=False)
    secenek_c = Column(Text, nullable=False)
    secenek_d = Column(Text, nullable=False)
    secenek_e = Column(Text, nullable=False)
    dogrucevap = Column(CHAR(1), nullable=False)
    cozum = Column(JSONB, nullable=False, default=list)
    konu_id = Column(Integer, nullable=False)
    difficulty = Column(String(20), nullable=False, default="Orta")
    durum = Column(String(20), nullable=False, default="yayinda")
    olusturulma_tarihi = Column(DateTime, nullable=False, default=datetime.utcnow)
    guncellenme_tarihi = Column(DateTime, nullable=True)

# Uygulamaya kayıt olan kullanıcıları bu tabloda tutuyoruz.
class Kullanici(TemelModel):
    __tablename__ = "kullanici"

    kullanici_id = Column(Integer, primary_key=True, index=True)
    ad = Column(String(120), nullable=False)
    eposta = Column(String(255), nullable=False, unique=True, index=True)
    sifre_ozeti = Column(String(255), nullable=False)
    hesap_turu = Column(String(20), nullable=False, default="ucretsiz")
    rol = Column(String(20), nullable=False, default="kullanici")
    kayit_tarihi = Column(DateTime, nullable=False, default=datetime.utcnow)
    cozulen_toplam_soru = Column(Integer, nullable=False, default=0)
    dogru_sayisi = Column(Integer, nullable=False, default=0)
    yanlis_sayisi = Column(Integer, nullable=False, default=0)
    bos_sayisi = Column(Integer, nullable=False, default=0)

# Kullanicinin tek tek soru cozme gecmisini bu tabloda tutuyoruz.
class KullaniciSoruCozumu(TemelModel):
    __tablename__ = "kullanici_soru_cozumu"

    cozum_id = Column(Integer, primary_key=True, index=True)
    kullanici_id = Column(Integer, ForeignKey("kullanici.kullanici_id", ondelete="CASCADE"), nullable=False, index=True)
    soru_id = Column(Integer, ForeignKey("soru.soru_id", ondelete="CASCADE"), nullable=False, index=True)
    verilen_cevap = Column(CHAR(1), nullable=True)
    dogru_cevap = Column(CHAR(1), nullable=False)
    sonuc = Column(String(20), nullable=False)
    cozum_suresi_saniye = Column(Integer, nullable=True)
    cozulme_tarihi = Column(DateTime, nullable=False, default=datetime.utcnow)

# Admin panelinden degistirilen genel ayarlar bu tabloda tutulur.
class Ayar(TemelModel):
    __tablename__ = "ayar"

    ayar_id = Column(Integer, primary_key=True, index=True)
    anahtar = Column(String(120), nullable=False, unique=True, index=True)
    deger = Column(String(255), nullable=False)
    guncellenme_tarihi = Column(DateTime, nullable=True)

# Admin panelinde yapilan onemli islemleri sonradan gorebilmek icin kaydeder.
class AdminIslemKaydi(TemelModel):
    __tablename__ = "admin_islem_kaydi"

    islem_id = Column(Integer, primary_key=True, index=True)
    kullanici_id = Column(Integer, nullable=False)
    islem = Column(String(120), nullable=False)
    detay = Column(JSONB, nullable=False, default=dict)
    islem_tarihi = Column(DateTime, nullable=False, default=datetime.utcnow)

# Eksik tabloları uygulama başlarken oluşturmak için kullanılır.
def tablolari_olustur():
    TemelModel.metadata.create_all(bind=veritabani_motoru)

# Mevcut soru tablosunda sonradan eklenen alanlar yoksa bunlari tamamlar.
def soru_tablosu_eksik_alanlari_tamamla():
    with veritabani_motoru.begin() as baglanti:
        baglanti.execute(text("ALTER TABLE soru ADD COLUMN IF NOT EXISTS durum VARCHAR(20) NOT NULL DEFAULT 'yayinda'"))
        baglanti.execute(text("ALTER TABLE soru ADD COLUMN IF NOT EXISTS difficulty VARCHAR(20) NOT NULL DEFAULT 'Orta'"))
        baglanti.execute(text("ALTER TABLE soru ADD COLUMN IF NOT EXISTS olusturulma_tarihi TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP"))
        baglanti.execute(text("ALTER TABLE soru ADD COLUMN IF NOT EXISTS guncellenme_tarihi TIMESTAMP NULL"))
        baglanti.execute(text("UPDATE soru SET durum = 'yayinda' WHERE durum IS NULL OR durum NOT IN ('taslak', 'yayinda', 'pasif', 'hatali')"))
        baglanti.execute(text("UPDATE soru SET difficulty = 'Orta' WHERE difficulty IS NULL OR difficulty NOT IN ('Kolay', 'Orta', 'Zor')"))
        baglanti.execute(text("""
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
        """))
        baglanti.execute(text("""
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
        """))

# Kullanici tablosuna admin kontrolu icin gereken rol alanini ekler.
def kullanici_tablosu_eksik_alanlari_tamamla():
    with veritabani_motoru.begin() as baglanti:
        baglanti.execute(text("ALTER TABLE kullanici ADD COLUMN IF NOT EXISTS rol VARCHAR(20) NOT NULL DEFAULT 'kullanici'"))
        baglanti.execute(text("ALTER TABLE kullanici ADD COLUMN IF NOT EXISTS cozulen_toplam_soru INTEGER NOT NULL DEFAULT 0"))
        baglanti.execute(text("ALTER TABLE kullanici ADD COLUMN IF NOT EXISTS dogru_sayisi INTEGER NOT NULL DEFAULT 0"))
        baglanti.execute(text("ALTER TABLE kullanici ADD COLUMN IF NOT EXISTS yanlis_sayisi INTEGER NOT NULL DEFAULT 0"))
        baglanti.execute(text("ALTER TABLE kullanici ADD COLUMN IF NOT EXISTS bos_sayisi INTEGER NOT NULL DEFAULT 0"))
        baglanti.execute(text("UPDATE kullanici SET rol = 'kullanici' WHERE rol IS NULL OR rol NOT IN ('kullanici', 'admin')"))
        baglanti.execute(text("""
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
        """))

# Tek tek soru cozumu tablosunda gereken kontroller ve indeksler yoksa tamamlar.
def kullanici_soru_cozumu_tablosu_eksik_alanlari_tamamla():
    with veritabani_motoru.begin() as baglanti:
        baglanti.execute(text("""
            CREATE TABLE IF NOT EXISTS kullanici_soru_cozumu (
                cozum_id SERIAL PRIMARY KEY,
                kullanici_id INTEGER NOT NULL REFERENCES kullanici(kullanici_id) ON DELETE CASCADE,
                soru_id INTEGER NOT NULL REFERENCES soru(soru_id) ON DELETE CASCADE,
                verilen_cevap CHAR(1) NULL,
                dogru_cevap CHAR(1) NOT NULL,
                sonuc VARCHAR(20) NOT NULL,
                cozum_suresi_saniye INTEGER NULL,
                cozulme_tarihi TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
            )
        """))
        baglanti.execute(text("CREATE INDEX IF NOT EXISTS idx_kullanici_soru_cozumu_kullanici_id ON kullanici_soru_cozumu (kullanici_id)"))
        baglanti.execute(text("CREATE INDEX IF NOT EXISTS idx_kullanici_soru_cozumu_soru_id ON kullanici_soru_cozumu (soru_id)"))
        baglanti.execute(text("""
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
        """))
        baglanti.execute(text("""
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
        """))

# API isteği bitince veritabanı oturumunu otomatik kapatır.
def veritabani_oturumu_al():
    veritabani = OturumYerel()
    try:
        yield veritabani
    finally:
        veritabani.close()
