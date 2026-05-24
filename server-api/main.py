import os
import json
import asyncio
import base64
import hashlib
import hmac
import re
import secrets
import subprocess
import sys
import traceback
from datetime import datetime
from typing import Any, Literal, Optional, Union
from fastapi import FastAPI, Header, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, ConfigDict, Field, field_validator
from google import genai
from google.genai import types
from sqlalchemy import func, select
from sqlalchemy.orm import aliased
from sqlalchemy.orm import Session
from database import AdminIslemKaydi, Ayar, Kullanici, KullaniciSoruCozumu, Soru, kullanici_soru_cozumu_tablosu_eksik_alanlari_tamamla, kullanici_tablosu_eksik_alanlari_tamamla, soru_tablosu_eksik_alanlari_tamamla, tablolari_olustur, veritabani_oturumu_al
from latex_temizleyici import latex_deger_onar, latex_metin_onar

# Yapay zekadan ve mobil API'den dönen verilerin şeklini burada tarif ediyoruz.
HesapTuru = Literal["ucretsiz", "ucretli"]
SoruDurumu = Literal["taslak", "yayinda", "pasif", "hatali"]
KullaniciRolu = Literal["kullanici", "admin"]
CozumSonucu = Literal["dogru", "yanlis", "bos"]
ZorlukSeviyesi = Literal["Kolay", "Orta", "Zor"]

class Secenekler(BaseModel):
    A: str = Field(description="A şıkkı")
    B: str = Field(description="B şıkkı")
    C: str = Field(description="C şıkkı")
    D: str = Field(description="D şıkkı")
    E: str = Field(description="E şıkkı")

class SoruUretimYaniti(BaseModel):
    baglam_metni: Optional[str] = Field(default="", description="Sorunun çözümü için öğrenciye verilen ön bilgi (yoksa boş).")
    soru_koku: str = Field(description="Öğrenciden tam olarak neyin istendiğini belirten asıl soru cümlesi.")
    secenekler: Secenekler
    dogru_cevap: Literal["A", "B", "C", "D", "E"] = Field(description="Yalnızca doğru olan şıkkın harf değeri.")
    cozum_adimlari: list[str] = Field(description="Cevabı doğrudan söylemeyen, sıralı ipucu adımları.")

    @field_validator("cozum_adimlari", mode="before")
    @classmethod
    def cozum_adimlari_liste_olmali(cls, deger: Any) -> list[str]:
        if isinstance(deger, list):
            return [str(adim) for adim in deger]
        return cozum_adimlarini_ayikla(str(deger or ""))

class SoruIstegi(BaseModel):
    model_config = ConfigDict(extra="forbid")

    konu_id: int
    konu_adi: str
    zorluk_seviyesi: ZorlukSeviyesi
    ek_talimatlar: Optional[str] = ""

class KullaniciKayitIstegi(BaseModel):
    model_config = ConfigDict(extra="forbid")

    ad: str = Field(min_length=2, max_length=120)
    eposta: str = Field(min_length=5, max_length=255)
    sifre: str = Field(min_length=6, max_length=128)

    @field_validator("eposta")
    @classmethod
    def eposta_gecerli_olmali(cls, deger: str) -> str:
        return eposta_degerini_dogrula(deger)

class KullaniciGirisIstegi(BaseModel):
    model_config = ConfigDict(extra="forbid")

    eposta: str = Field(min_length=5, max_length=255)
    sifre: str = Field(min_length=1, max_length=128)

    @field_validator("eposta")
    @classmethod
    def eposta_gecerli_olmali(cls, deger: str) -> str:
        return eposta_degerini_dogrula(deger)

class KullaniciYaniti(BaseModel):
    model_config = ConfigDict(extra="forbid")

    kullanici_id: int
    ad: str
    eposta: str
    hesap_turu: HesapTuru
    rol: KullaniciRolu

class KimlikIslemYaniti(BaseModel):
    model_config = ConfigDict(extra="forbid")

    basarili: bool
    mesaj: str
    kullanici: Optional[KullaniciYaniti] = None
    token: Optional[str] = None

class MobilSoruYaniti(BaseModel):
    model_config = ConfigDict(extra="forbid")

    soru_id: int
    konu_id: int
    sorumetni: str
    soruresmi: Optional[str] = None
    sorukoku: str
    secenek_a: str
    secenek_b: str
    secenek_c: str
    secenek_d: str
    secenek_e: str
    dogrucevap: Literal["A", "B", "C", "D", "E"]
    cozum: list[dict[str, Any]] = Field(default_factory=list)
    difficulty: ZorlukSeviyesi = "Orta"
    durum: SoruDurumu
    olusturulma_tarihi: datetime
    guncellenme_tarihi: Optional[datetime] = None

class MobilSoruListesiYaniti(BaseModel):
    model_config = ConfigDict(extra="forbid")

    son_soru_id: int
    devam_var: bool
    hesap_turu: HesapTuru
    konu_basina_soru_siniri: Optional[int] = None
    sorular: list[MobilSoruYaniti]

class MobilSoruCozumuIstegi(BaseModel):
    model_config = ConfigDict(extra="forbid")

    soru_id: int
    verilen_cevap: Optional[Literal["A", "B", "C", "D", "E"]] = None
    cozum_suresi_saniye: Optional[int] = Field(default=None, ge=0)

    @field_validator("verilen_cevap", mode="before")
    @classmethod
    def bos_cevabi_duzenle(cls, deger: Any) -> Optional[str]:
        if deger is None:
            return None
        if isinstance(deger, str) and deger.strip() == "":
            return None
        if isinstance(deger, str):
            return deger.strip().upper()
        return deger

class MobilSoruCozumuYaniti(BaseModel):
    model_config = ConfigDict(extra="forbid")

    cozum_id: int
    soru_id: int
    verilen_cevap: Optional[Literal["A", "B", "C", "D", "E"]] = None
    dogru_cevap: Literal["A", "B", "C", "D", "E"]
    sonuc: CozumSonucu
    cozum_suresi_saniye: Optional[int] = None
    cozulme_tarihi: datetime

class SenkronizasyonAyarlariYaniti(BaseModel):
    model_config = ConfigDict(extra="forbid")

    kayitlar_aktif: bool
    api_aktif: bool
    soru_uretimi_aktif: bool
    mobil_senkronizasyon_aktif: bool
    bot_aktif: bool
    bot_calismakta: bool
    bot_hedef_soru_sayisi: int
    tum_hesaplar_konu_basina_soru_siniri: Optional[int] = None
    ucretli_hesaplar_konu_basina_soru_siniri: Optional[int] = None
    varsayilan_paket_limiti: int
    en_yuksek_paket_limiti: int
    veritabani_senkronizasyon_versiyonu: int = 0
    veritabani_senkronizasyon_tarihi: Optional[datetime] = None

class AdminAyarlariGuncellemeIstegi(BaseModel):
    model_config = ConfigDict(extra="forbid")

    kayitlar_aktif: Optional[bool] = None
    api_aktif: Optional[bool] = None
    soru_uretimi_aktif: Optional[bool] = None
    mobil_senkronizasyon_aktif: Optional[bool] = None
    bot_aktif: Optional[bool] = None
    bot_hedef_soru_sayisi: Optional[int] = Field(default=None, ge=1, le=1000)
    tum_hesaplar_konu_basina_soru_siniri: Optional[int] = Field(default=None, ge=0)
    ucretli_hesaplar_konu_basina_soru_siniri: Optional[int] = Field(default=None, ge=0)
    varsayilan_paket_limiti: Optional[int] = Field(default=None, ge=1)
    en_yuksek_paket_limiti: Optional[int] = Field(default=None, ge=1)

class SonSorulariPasiflestirIstegi(BaseModel):
    model_config = ConfigDict(extra="forbid")

    adet: int = Field(ge=1, le=1000)

class AdminIslemYaniti(BaseModel):
    model_config = ConfigDict(extra="forbid")

    basarili: bool
    mesaj: str
    etkilenen_kayit_sayisi: int = 0

class AdminIslemKaydiYaniti(BaseModel):
    model_config = ConfigDict(extra="forbid")

    islem_id: int
    kullanici_id: int
    islem: str
    detay: dict[str, Any]
    islem_tarihi: datetime

class AdminSoruOnarimYaniti(BaseModel):
    model_config = ConfigDict(extra="forbid")

    basarili: bool
    mesaj: str
    taranan_kayit_sayisi: int
    etkilenen_kayit_sayisi: int

class BotKonuDurumu(BaseModel):
    model_config = ConfigDict(extra="forbid")

    konu_id: int
    konu_adi: str
    soru_sayisi: int

class BotUretimPlaniYaniti(BaseModel):
    model_config = ConfigDict(extra="forbid")

    bot_aktif: bool
    api_aktif: bool
    hedef_soru_sayisi: int
    etkin_hedef_soru_sayisi: int
    tamamlandi: bool
    konular: list[BotKonuDurumu]

# API uygulamasını burada başlatıyoruz.
uygulama = FastAPI(title="DGS/TYT Soru Üreticisi API")

# APK tarafında CORS sorun olmaz; web panel veya tarayıcı tabanlı istemci bağlanırsa
# sunucunun preflight isteklerini kabul etmesi gerekir.
izinli_kaynaklar = [
    kaynak.strip()
    for kaynak in os.environ.get("CORS_ORIGINS", "*").split(",")
    if kaynak.strip()
]
uygulama.add_middleware(
    CORSMiddleware,
    allow_origins=izinli_kaynaklar or ["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Sunucuda "main:app" komutu kullanılıyorsa bozulmaması için bu kısa adı koruyoruz.
app = uygulama

# Gemini'ye soru ürettirmek için istemciyi burada hazırlıyoruz.
VERTEX_AI_PROJECT_ID = "dgsai-496304"
VERTEX_AI_KONUMU = "global"
GEMINI_MODEL_ADI = "gemini-2.5-flash"
GEMINI_ISTEKLER_ARASI_BEKLEME_SANIYE = 60
GEMINI_RATE_LIMIT_BEKLEME_SANIYE = 15
gemini_istemcisi: Optional[genai.Client] = None

def gemini_istemcisini_al() -> genai.Client:
    global gemini_istemcisi
    if gemini_istemcisi is not None:
        return gemini_istemcisi

    gemini_istemcisi = genai.Client(
        vertexai=True,
        project=VERTEX_AI_PROJECT_ID,
        location=VERTEX_AI_KONUMU,
    )
    return gemini_istemcisi

def gemini_rate_limit_hatasi_mi(hata: Exception) -> bool:
    durum_kodu = getattr(hata, "status_code", None) or getattr(hata, "code", None)
    hata_metni = str(hata).lower()
    return durum_kodu == 429 or "429" in hata_metni or "resource_exhausted" in hata_metni

async def gemini_icerik_uret(istem_metni: str, sicaklik: float):
    return await asyncio.to_thread(
        gemini_istemcisini_al().models.generate_content,
        model=GEMINI_MODEL_ADI,
        contents=istem_metni,
        config=types.GenerateContentConfig(
            system_instruction=sistem_talimatları,
            response_mime_type="application/json",
            response_schema=SoruUretimYaniti,
            temperature=sicaklik,
        ),
    )

# Uygulama açılırken eksik veritabanı tablolarını oluşturuyoruz.
@uygulama.on_event("startup")
def uygulama_baslarken():
    tablolari_olustur()
    soru_tablosu_eksik_alanlari_tamamla()
    kullanici_tablosu_eksik_alanlari_tamamla()
    kullanici_soru_cozumu_tablosu_eksik_alanlari_tamamla()

# Sınır ayarı boş, 0, "sinirsiz" veya "sınırsız" ise sınırsız kabul edilir.
def sinir_ayarini_oku(ayar_adi: str) -> Optional[int]:
    deger = os.environ.get(ayar_adi)
    if deger is None:
        return None

    temiz_deger = deger.strip().lower()
    if temiz_deger in {"", "0", "none", "null", "sinirsiz", "sınırsız", "unlimited"}:
        return None

    sinir = int(temiz_deger)
    if sinir < 1:
        return None
    return sinir

# Tüm hesaplar için konu başına gönderilecek soru sınırıdır; None sınırsız demektir.
TUM_HESAPLAR_KONU_BASINA_SORU_SINIRI = sinir_ayarini_oku("TUM_HESAPLAR_KONU_BASINA_SORU_SINIRI")

# Ücretli hesaplar için ayrı sınırdır; None ise tüm hesap sınırı kullanılır.
UCRETLI_HESAPLAR_KONU_BASINA_SORU_SINIRI = sinir_ayarini_oku("UCRETLI_HESAPLAR_KONU_BASINA_SORU_SINIRI")

# Mobil uygulama tek seferde varsayılan olarak bu kadar soru ister.
MOBIL_VARSAYILAN_PAKET_LIMITI = int(os.environ.get("MOBIL_VARSAYILAN_PAKET_LIMITI", "500"))

# Mobil uygulama yanlışlıkla çok büyük istek atarsa bu üst sınır uygulanır.
MOBIL_EN_YUKSEK_PAKET_LIMITI = int(os.environ.get("MOBIL_EN_YUKSEK_PAKET_LIMITI", "1000"))

# Token'ı imzalamak için kullanılan gizli anahtar buradan alınır.
OTURUM_GIZLI_ANAHTARI = os.environ.get("OTURUM_GIZLI_ANAHTARI", "gelistirme-icin-gecici-anahtar")

# Panel ayarlarinda kullanilan anahtar adlarini tek yerde topluyoruz.
AYAR_SORU_URETIMI_AKTIF = "soru_uretimi_aktif"
AYAR_MOBIL_SENKRONIZASYON_AKTIF = "mobil_senkronizasyon_aktif"
AYAR_KAYITLAR_AKTIF = "kayitlar_aktif"
AYAR_API_AKTIF = "api_aktif"
AYAR_BOT_AKTIF = "bot_aktif"
AYAR_BOT_HEDEF_SORU_SAYISI = "bot_hedef_soru_sayisi"
AYAR_TUM_HESAPLAR_KONU_BASINA_SORU_SINIRI = "tum_hesaplar_konu_basina_soru_siniri"
AYAR_UCRETLI_HESAPLAR_KONU_BASINA_SORU_SINIRI = "ucretli_hesaplar_konu_basina_soru_siniri"
AYAR_MOBIL_VARSAYILAN_PAKET_LIMITI = "mobil_varsayilan_paket_limiti"
AYAR_MOBIL_EN_YUKSEK_PAKET_LIMITI = "mobil_en_yuksek_paket_limiti"
AYAR_VERITABANI_SENKRONIZASYON_VERSIYONU = "veritabani_senkronizasyon_versiyonu"
AYAR_VERITABANI_SENKRONIZASYON_TARIHI = "veritabani_senkronizasyon_tarihi"
bot_sureci: Optional[subprocess.Popen] = None

# Yapay zekaya nasıl soru yazacağını anlatan ana talimat budur.
sistem_talimatları = r"""Sen profesyonel bir DGS/TYT matematik test sorusu hazırlama uzmanısın. Üreteceğin her soru özgün, sınav diline uygun, ölçme değeri yüksek ve aşağıdaki JSON formatına kesinlikle uyumlu olmalıdır. ÖSYM tarzını taklit et ama çıkmış soruları, telifli soru metinlerini veya birebir kalıpları kopyalama.
JSON alanları tam olarak şu isimlerle üretilmelidir: "baglam_metni", "soru_koku", "secenekler", "dogru_cevap", "cozum_adimlari". "secenekler" nesnesinde tam olarak "A", "B", "C", "D", "E" anahtarları bulunmalıdır.
* baglam_metni (Bağlam/Öncül): Sorunun çözümü için öğrenciye verilen ön bilgi, hikaye, uzun paragraf, tablo verisi veya matematiksel denklemlerin bulunduğu kısımdır. Eğer soru doğrudan soruluyorsa (ön bilgi yoksa) bu alan boş string olmalıdır. Mümkün olduğunca metin ağırlıklı (kare/üçgen gibi görsel gerektirmeyen) matematik soruları üret.
* soru_koku (Soru Kökü): Öğrenciden tam olarak neyin istendiğini belirten, genellikle koyu renkle yazılan asıl soru cümlesidir.
* secenekler (Şıklar): A, B, C, D ve E olmak üzere tam olarak 5 adet seçenekten oluşmalıdır. Yalnızca bir seçenek doğru olmalı; diğerleri işlem hatası, kavram yanılgısı, eksik koşul veya yanlış yorum gibi gerçekçi çeldiricilerden oluşmalıdır.
* dogru_cevap: Yalnızca doğru olan şıkkın harf değerini içermelidir (A, B, C, D veya E).
* cozum_adimlari: Bir string değil, 4 ile 8 arasında kısa string içeren bir JSON dizisi olmalıdır. Her dizi elemanı uygulamada ayrı ipucu adımı olarak gösterilir. İlk adım yalnızca kullanılacak kavramı/başlangıç fikrini versin; sonraki adımlar tek bir işlem veya tek bir çıkarım ilerletsin. Hiçbir adım tek başına tüm çözümü bitirmemelidir. Son adımda bile "Cevap D şıkkıdır", "doğru cevap A" gibi doğrudan şık söyleyen cümleler yazma; bunun yerine bulunan sonucu seçeneklerle karşılaştırmayı ima eden kısa bir ifade kullan. Her adım 1-2 cümle olsun; uzun çözümü tek paragrafa sıkıştırma.
Matematik yazım standardı: Normal Türkçe metni LaTeX içine alma; yalnızca matematiksel ifadeleri LaTeX ile yaz. Kısa matematik ifadelerini $...$ içinde, uzun veya ayrı satırda gösterilmesi gereken denklem, kesir, köklü ifade, denklem sistemi, parçalı fonksiyon ve benzeri ifadeleri $$...$$ içinde kullan. Üs, kök, kesir, mutlak değer, fonksiyon, ters fonksiyon, kombinasyon, olasılık oranı, eşitsizlik ve denklem ifadelerinde mutlaka LaTeX kullan. Örnekler: $x^2$, $\sqrt{2x-5}$, $\frac{3}{5}$, $|x-3| \le 5$, $f^{-1}(4)$, $\binom{8}{3}$.
Ek talimatlarda Unicode matematik gösterimi veya bilgisayar tarzı gösterim geçse bile nihai JSON çıktısındaki tüm matematiksel ifadeleri bu LaTeX standardına dönüştür. Örneğin x², √x, ⅗, a⁄b, f⁻¹(x) veya C(8,3) gibi yazımları nihai çıktıda sırasıyla $x^2$, $\sqrt{x}$, $\frac{3}{5}$, $\frac{a}{b}$, $f^{-1}(x)$ ve $\binom{8}{3}$ biçiminde yaz.
Öncüllü sorularda öncülleri baglam_metni alanında I, II, III biçiminde açıkça ver; öncüllerin içindeki matematiksel ifadeleri de aynı LaTeX standardıyla yaz. secenekler alanında matematik varsa seçenek metninde de $...$ veya gerektiğinde $$...$$ kullan.
Kalite kuralları: Soru tek kazanımı net ölçmeli, gereksiz uzunluk içermemeli, cevap seçenekleri aynı tür ve benzer inandırıcılıkta olmalı, belirsiz ifade veya birden fazla doğru cevap üretmemelidir. İşlem yükü zorluk seviyesiyle uyumlu olmalı; görsel zorunluluğu varsa bunu metin veya tabloyla ifade etmelidir.
"""

# Veritabanindan gelen ayar degerini metin olarak okuyoruz.
def ayar_degerini_al(veritabani: Session, anahtar: str) -> Optional[str]:
    ayar = veritabani.query(Ayar).filter(Ayar.anahtar == anahtar).first()
    return ayar.deger if ayar is not None else None

# Acik/kapali ayarlarini bool degere ceviriyoruz.
def bool_ayarini_al(veritabani: Session, anahtar: str, varsayilan: bool) -> bool:
    deger = ayar_degerini_al(veritabani, anahtar)
    if deger is None:
        return varsayilan
    return deger.strip().lower() in {"1", "true", "evet", "aktif", "acik", "açık"}

# Sayi ayarlarini veritabanindan okuyoruz.
def int_ayarini_al(veritabani: Session, anahtar: str, varsayilan: int) -> int:
    deger = ayar_degerini_al(veritabani, anahtar)
    if deger is None:
        return varsayilan
    return int(deger)

# Konu basina soru sinirinda 0 ve sinirsiz degerleri sinirsiz kabul ediyoruz.
def sinir_ayarini_veritabanindan_al(veritabani: Session, anahtar: str, varsayilan: Optional[int]) -> Optional[int]:
    deger = ayar_degerini_al(veritabani, anahtar)
    if deger is None:
        return varsayilan

    temiz_deger = deger.strip().lower()
    if temiz_deger in {"", "0", "none", "null", "sinirsiz", "sınırsız", "unlimited"}:
        return None
    return int(temiz_deger)

# API'nin o an kullanacagi canli ayarlari tek cevapta topluyoruz.
def sistem_ayarlarini_al(veritabani: Session) -> SenkronizasyonAyarlariYaniti:
    global bot_sureci
    bot_calismakta = bot_sureci is not None and bot_sureci.poll() is None
    senkronizasyon_tarihi = ayar_degerini_al(veritabani, AYAR_VERITABANI_SENKRONIZASYON_TARIHI)
    return SenkronizasyonAyarlariYaniti(
        kayitlar_aktif=bool_ayarini_al(veritabani, AYAR_KAYITLAR_AKTIF, True),
        api_aktif=bool_ayarini_al(veritabani, AYAR_API_AKTIF, True),
        soru_uretimi_aktif=bool_ayarini_al(veritabani, AYAR_SORU_URETIMI_AKTIF, True),
        mobil_senkronizasyon_aktif=bool_ayarini_al(veritabani, AYAR_MOBIL_SENKRONIZASYON_AKTIF, True),
        bot_aktif=bool_ayarini_al(veritabani, AYAR_BOT_AKTIF, False),
        bot_calismakta=bot_calismakta,
        bot_hedef_soru_sayisi=int_ayarini_al(veritabani, AYAR_BOT_HEDEF_SORU_SAYISI, 50),
        tum_hesaplar_konu_basina_soru_siniri=sinir_ayarini_veritabanindan_al(veritabani, AYAR_TUM_HESAPLAR_KONU_BASINA_SORU_SINIRI, TUM_HESAPLAR_KONU_BASINA_SORU_SINIRI),
        ucretli_hesaplar_konu_basina_soru_siniri=sinir_ayarini_veritabanindan_al(veritabani, AYAR_UCRETLI_HESAPLAR_KONU_BASINA_SORU_SINIRI, UCRETLI_HESAPLAR_KONU_BASINA_SORU_SINIRI),
        varsayilan_paket_limiti=int_ayarini_al(veritabani, AYAR_MOBIL_VARSAYILAN_PAKET_LIMITI, MOBIL_VARSAYILAN_PAKET_LIMITI),
        en_yuksek_paket_limiti=int_ayarini_al(veritabani, AYAR_MOBIL_EN_YUKSEK_PAKET_LIMITI, MOBIL_EN_YUKSEK_PAKET_LIMITI),
        veritabani_senkronizasyon_versiyonu=int_ayarini_al(veritabani, AYAR_VERITABANI_SENKRONIZASYON_VERSIYONU, 0),
        veritabani_senkronizasyon_tarihi=datetime.fromisoformat(senkronizasyon_tarihi) if senkronizasyon_tarihi else None,
    )

def ana_apiyi_dogrula(veritabani: Session):
    if not sistem_ayarlarini_al(veritabani).api_aktif:
        raise HTTPException(status_code=503, detail="Ana API su anda admin tarafindan durduruldu.")

def bot_uretim_planini_al(veritabani: Session) -> BotUretimPlaniYaniti:
    dosya_yolu = os.path.join(os.path.dirname(__file__), "prompts.json")
    with open(dosya_yolu, "r", encoding="utf-8") as dosya:
        istem_verileri = json.load(dosya)

    soru_sayilari = dict(
        veritabani.query(Soru.konu_id, func.count(Soru.soru_id))
        .filter(Soru.durum == "yayinda")
        .group_by(Soru.konu_id)
        .all()
    )
    konular = [
        BotKonuDurumu(
            konu_id=int(konu_id),
            konu_adi=konu_verisi["konu_adi"],
            soru_sayisi=int(soru_sayilari.get(int(konu_id), 0)),
        )
        for konu_id, konu_verisi in istem_verileri.items()
    ]
    ayarlar = sistem_ayarlarini_al(veritabani)
    en_yuksek_mevcut_sayi = max(
        (konu.soru_sayisi for konu in konular),
        default=0,
    )
    etkin_hedef = max(ayarlar.bot_hedef_soru_sayisi, en_yuksek_mevcut_sayi)

    return BotUretimPlaniYaniti(
        bot_aktif=ayarlar.bot_aktif,
        api_aktif=ayarlar.api_aktif,
        hedef_soru_sayisi=ayarlar.bot_hedef_soru_sayisi,
        etkin_hedef_soru_sayisi=etkin_hedef,
        tamamlandi=all(
            konu.soru_sayisi >= etkin_hedef
            for konu in konular
        ),
        konular=sorted(konular, key=lambda konu: konu.konu_id),
    )

# Admin panelinden gelen ayari veritabanina yazar veya mevcut kaydi gunceller.
def ayar_degerini_kaydet(veritabani: Session, anahtar: str, deger: str):
    ayar = veritabani.query(Ayar).filter(Ayar.anahtar == anahtar).first()
    if ayar is None:
        veritabani.add(Ayar(anahtar=anahtar, deger=deger, guncellenme_tarihi=datetime.utcnow()))
        return

    ayar.deger = deger
    ayar.guncellenme_tarihi = datetime.utcnow()

# Admin islemlerini veritabaninda kayit altina aliyoruz.
def admin_islemini_kaydet(veritabani: Session, kullanici: Kullanici, islem: str, detay: dict[str, Any]):
    veritabani.add(AdminIslemKaydi(
        kullanici_id=kullanici.kullanici_id,
        islem=islem,
        detay=detay,
    ))

# E-posta adresini karşılaştırma için küçük harfe çeviriyoruz.
def epostayi_duzenle(eposta: str) -> str:
    return eposta.strip().lower()

# E-posta alanı temel biçime uymuyorsa isteği reddediyoruz.
def eposta_degerini_dogrula(eposta: str) -> str:
    duzenlenmis_eposta = epostayi_duzenle(eposta)
    if not re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", duzenlenmis_eposta):
        raise ValueError("Geçerli bir e-posta adresi girilmelidir.")
    return duzenlenmis_eposta

# Şifreyi veritabanına düz yazmak yerine tuzlu özet haline getiriyoruz.
def sifre_ozeti_olustur(sifre: str) -> str:
    tuz = secrets.token_bytes(16)
    ozet = hashlib.pbkdf2_hmac("sha256", sifre.encode("utf-8"), tuz, 100_000)
    tuz_metni = base64.b64encode(tuz).decode("ascii")
    ozet_metni = base64.b64encode(ozet).decode("ascii")
    return f"pbkdf2_sha256$100000${tuz_metni}${ozet_metni}"

# Girişte yazılan şifre ile veritabanındaki özet aynı mı diye kontrol ediyoruz.
def sifre_dogru_mu(sifre: str, kayitli_ozet: str) -> bool:
    try:
        algoritma, tekrar_sayisi_metni, tuz_metni, beklenen_ozet_metni = kayitli_ozet.split("$", 3)
        if algoritma != "pbkdf2_sha256":
            return False

        tekrar_sayisi = int(tekrar_sayisi_metni)
        tuz = base64.b64decode(tuz_metni.encode("ascii"))
        beklenen_ozet = base64.b64decode(beklenen_ozet_metni.encode("ascii"))
        hesaplanan_ozet = hashlib.pbkdf2_hmac("sha256", sifre.encode("utf-8"), tuz, tekrar_sayisi)
        return hmac.compare_digest(hesaplanan_ozet, beklenen_ozet)
    except Exception:
        return False

# Token içindeki JSON'u güvenli taşımak için base64url biçimine çeviriyoruz.
def base64url_kodla(veri: bytes) -> str:
    return base64.urlsafe_b64encode(veri).rstrip(b"=").decode("ascii")

# Token'dan gelen base64url metni tekrar byte veriye çeviriyoruz.
def base64url_coz(metin: str) -> bytes:
    eksik_dolgu = "=" * (-len(metin) % 4)
    return base64.urlsafe_b64decode((metin + eksik_dolgu).encode("ascii"))

# Kullanıcı bilgilerini imzalı token haline getiriyoruz.
def token_olustur(kullanici: Kullanici) -> str:
    baslik = {"alg": "HS256", "typ": "JWT"}
    govde = {
        "kullanici_id": kullanici.kullanici_id,
        "eposta": kullanici.eposta,
        "hesap_turu": kullanici.hesap_turu,
        "rol": kullanici.rol,
    }
    baslik_metni = base64url_kodla(json.dumps(baslik, separators=(",", ":")).encode("utf-8"))
    govde_metni = base64url_kodla(json.dumps(govde, separators=(",", ":")).encode("utf-8"))
    imzalanacak_metin = f"{baslik_metni}.{govde_metni}".encode("ascii")
    imza = hmac.new(OTURUM_GIZLI_ANAHTARI.encode("utf-8"), imzalanacak_metin, hashlib.sha256).digest()
    return f"{baslik_metni}.{govde_metni}.{base64url_kodla(imza)}"

# Mobil uygulamadan gelen token'ın imzası doğru mu diye kontrol ediyoruz.
def token_coz(token: str) -> dict[str, Any]:
    try:
        baslik_metni, govde_metni, imza_metni = token.split(".", 2)
        imzalanacak_metin = f"{baslik_metni}.{govde_metni}".encode("ascii")
        beklenen_imza = hmac.new(OTURUM_GIZLI_ANAHTARI.encode("utf-8"), imzalanacak_metin, hashlib.sha256).digest()
        gelen_imza = base64url_coz(imza_metni)
        if not hmac.compare_digest(gelen_imza, beklenen_imza):
            raise ValueError("Token imzası geçersiz.")
        return json.loads(base64url_coz(govde_metni).decode("utf-8"))
    except Exception as hata:
        raise HTTPException(status_code=401, detail="Token geçersiz.") from hata

# Authorization başlığından kullanıcıyı buluyoruz.
def aktif_kullaniciyi_al(authorization: Optional[str] = Header(default=None), veritabani: Session = Depends(veritabani_oturumu_al)) -> Kullanici:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Token gerekli.")

    token = authorization.removeprefix("Bearer ").strip()
    token_verisi = token_coz(token)
    kullanici_id = token_verisi.get("kullanici_id")
    kullanici = veritabani.query(Kullanici).filter(Kullanici.kullanici_id == kullanici_id).first()
    if kullanici is None:
        raise HTTPException(status_code=401, detail="Kullanıcı bulunamadı.")
    return kullanici

# Kullanıcı veritabanı kaydını API cevabına çeviriyoruz.
# Kullanici admin degilse admin API adreslerine izin vermiyoruz.
def aktif_admini_al(kullanici: Kullanici = Depends(aktif_kullaniciyi_al)) -> Kullanici:
    if kullanici.rol != "admin":
        raise HTTPException(status_code=403, detail="Bu islem icin admin yetkisi gerekli.")
    return kullanici

def kullanici_yanitina_donustur(kullanici: Kullanici) -> KullaniciYaniti:
    return KullaniciYaniti(
        kullanici_id=kullanici.kullanici_id,
        ad=kullanici.ad,
        eposta=kullanici.eposta,
        hesap_turu=kullanici.hesap_turu,
        rol=kullanici.rol,
    )

# Ana veritabanındaki soru kaydını mobil uygulamanın anlayacağı cevaba çeviriyoruz.
def mobil_soru_yanitina_donustur(soru: Soru) -> MobilSoruYaniti:
    return MobilSoruYaniti(
        soru_id=soru.soru_id,
        konu_id=soru.konu_id,
        sorumetni=latex_metin_onar(soru.sorumetni or ""),
        soruresmi=soru.soruresmi,
        sorukoku=latex_metin_onar(soru.sorukoku),
        secenek_a=latex_metin_onar(soru.secenek_a),
        secenek_b=latex_metin_onar(soru.secenek_b),
        secenek_c=latex_metin_onar(soru.secenek_c),
        secenek_d=latex_metin_onar(soru.secenek_d),
        secenek_e=latex_metin_onar(soru.secenek_e),
        dogrucevap=soru.dogrucevap,
        cozum=latex_deger_onar(soru.cozum or []),
        difficulty=soru.difficulty or "Orta",
        durum=soru.durum,
        olusturulma_tarihi=soru.olusturulma_tarihi,
        guncellenme_tarihi=soru.guncellenme_tarihi,
    )

def cozum_adimlarini_hazirla(cozum_adimlari: Union[list[str], str], dogru_cevap: str) -> list[dict[str, str]]:
    ham_adimlar = cozum_adimlarini_ayikla(cozum_adimlari)
    adimlar: list[str] = []

    for adim in ham_adimlar:
        temiz_adim = latex_metin_onar(str(adim)).strip()
        if not temiz_adim:
            continue
        temiz_adim = re.sub(r"^\s*(?:ad[ıi]m\s*)?\d+[\).:-]\s*", "", temiz_adim, flags=re.IGNORECASE)
        temiz_adim = re.sub(r"^\s*[-*•]\s*", "", temiz_adim)
        temiz_adim = cevap_ifsa_cumlesini_temizle(temiz_adim, dogru_cevap)
        if temiz_adim and not kisa_cevap_ifsa_adimi_mi(temiz_adim, dogru_cevap):
            adimlar.extend(uzun_adimi_bol(temiz_adim))

    adimlar = [adim for adim in adimlar if adim and not kisa_cevap_ifsa_adimi_mi(adim, dogru_cevap)]
    if not adimlar:
        adimlar = ["Verilen bilgileri ve istenen ifadeyi ayrı ayrı belirle."]

    return [{"adim": adim} for adim in adimlar[:8]]

def cozum_adimlarini_ayikla(cozum_adimlari: Union[list[str], str]) -> list[str]:
    if isinstance(cozum_adimlari, list):
        return [str(adim).strip() for adim in cozum_adimlari if str(adim).strip()]

    metin = str(cozum_adimlari).strip()
    if not metin:
        return []

    try:
        decoded = json.loads(metin)
        if isinstance(decoded, list):
            return [str(adim).strip() for adim in decoded if str(adim).strip()]
    except Exception:
        pass

    basliklar = list(re.finditer(r"(?:^|\n)\s*(?:ad[ıi]m\s*)?\d+[\).:-]\s*", metin, flags=re.IGNORECASE))
    if len(basliklar) > 1:
        adimlar = []
        for indeks, eslesme in enumerate(basliklar):
            baslangic = eslesme.end()
            bitis = basliklar[indeks + 1].start() if indeks + 1 < len(basliklar) else len(metin)
            adimlar.append(metin[baslangic:bitis].strip())
        return adimlar

    satirlar = [
        re.sub(r"^\s*(?:[-*•]|\d+[\).:-])\s*", "", satir).strip()
        for satir in re.split(r"\n+", metin)
    ]
    satirlar = [satir for satir in satirlar if satir]
    if len(satirlar) > 1:
        return satirlar

    return cumlelere_bol(metin)

def uzun_adimi_bol(adim: str) -> list[str]:
    if len(adim) <= 260:
        return [adim]

    cumleler = cumlelere_bol(adim)
    if len(cumleler) <= 1:
        return [adim]

    parcalar: list[str] = []
    buffer = ""
    for cumle in cumleler:
        aday = f"{buffer} {cumle}".strip()
        if buffer and len(aday) > 220:
            parcalar.append(buffer)
            buffer = cumle
        else:
            buffer = aday
    if buffer:
        parcalar.append(buffer)
    return parcalar

def cumlelere_bol(metin: str) -> list[str]:
    return [
        cumle.strip()
        for cumle in re.split(r"(?<=[.!?])\s+(?=[A-ZÇĞİÖŞÜ0-9])", metin)
        if cumle.strip()
    ]

def cevap_ifsa_cumlesini_temizle(metin: str, dogru_cevap: str) -> str:
    harf = re.escape(dogru_cevap.upper())
    kaliplar = [
        rf"\s*(?:Bu nedenle|Dolayısıyla|Sonuç olarak)?\s*(?:doğru\s+)?cevap\s+{harf}\s*ş[ıi]kk[ıi]d[ıi]r\.?\s*$",
        rf"\s*(?:Bu nedenle|Dolayısıyla|Sonuç olarak)?\s*{harf}\s*ş[ıi]kk[ıi]\s*(?:doğrudur|olur)\.?\s*$",
    ]
    sonuc = metin
    for kalip in kaliplar:
        sonuc = re.sub(kalip, "", sonuc, flags=re.IGNORECASE)
    return sonuc.strip()

def kisa_cevap_ifsa_adimi_mi(metin: str, dogru_cevap: str) -> bool:
    if len(metin) > 140:
        return False
    harf = re.escape(dogru_cevap.upper())
    return bool(re.search(rf"\b(?:cevap|doğru cevap|ş[ıi]k)\b.*\b{harf}\b|\b{harf}\b\s*ş[ıi]kk[ıi]", metin, flags=re.IGNORECASE))

# Hesap türüne göre ana veritabanından konu başına kaç soru gönderileceğini buluyoruz.
def konu_basina_soru_sinirini_bul(hesap_turu: HesapTuru, ayarlar: SenkronizasyonAyarlariYaniti) -> Optional[int]:
    if hesap_turu == "ucretli" and ayarlar.ucretli_hesaplar_konu_basina_soru_siniri is not None:
        return ayarlar.ucretli_hesaplar_konu_basina_soru_siniri
    return ayarlar.tum_hesaplar_konu_basina_soru_siniri

# Sınır varsa her konunun ilk belirlenen sayıdaki sorusunu alır, sınır yoksa bütün sorulara izin verir.
def mobil_soru_sorgusunu_hazirla(veritabani: Session, son_soru_id: int, konu_basina_soru_siniri: Optional[int]):
    if konu_basina_soru_siniri is None:
        return (
            veritabani.query(Soru)
            .filter(Soru.soru_id > son_soru_id)
            .filter(Soru.durum == "yayinda")
            .order_by(Soru.soru_id.asc())
        )

    konudaki_sira = func.row_number().over(
        partition_by=Soru.konu_id,
        order_by=Soru.soru_id.asc(),
    ).label("konudaki_sira")
    sirali_sorular = select(Soru, konudaki_sira).where(Soru.durum == "yayinda").subquery()
    sirali_soru = aliased(Soru, sirali_sorular)

    return (
        veritabani.query(sirali_soru)
        .filter(sirali_soru.soru_id > son_soru_id)
        .filter(sirali_sorular.c.konudaki_sira <= konu_basina_soru_siniri)
        .order_by(sirali_soru.soru_id.asc())
    )

# Mobil veya yönetim tarafının çağıracağı API adresleri burada başlar.
@uygulama.post("/api/kullanici/kayit", response_model=KimlikIslemYaniti)
async def kullanici_kayit(istek: KullaniciKayitIstegi, veritabani: Session = Depends(veritabani_oturumu_al)):
    ayarlar = sistem_ayarlarini_al(veritabani)
    if not ayarlar.api_aktif:
        raise HTTPException(status_code=503, detail="Ana API su anda admin tarafindan durduruldu.")
    if not ayarlar.kayitlar_aktif:
        raise HTTPException(status_code=403, detail="Yeni kullanici kayitlari gecici olarak donduruldu.")

    eposta = epostayi_duzenle(istek.eposta)
    mevcut_kullanici = veritabani.query(Kullanici).filter(Kullanici.eposta == eposta).first()
    if mevcut_kullanici is not None:
        raise HTTPException(status_code=409, detail="Bu e-posta adresiyle kayıtlı kullanıcı var.")

    yeni_kullanici = Kullanici(
        ad=istek.ad.strip(),
        eposta=eposta,
        sifre_ozeti=sifre_ozeti_olustur(istek.sifre),
        hesap_turu="ucretsiz",
        rol="kullanici",
    )

    try:
        veritabani.add(yeni_kullanici)
        veritabani.commit()
        veritabani.refresh(yeni_kullanici)
    except Exception as hata:
        veritabani.rollback()
        raise HTTPException(status_code=500, detail=str(hata))

    return KimlikIslemYaniti(
        basarili=True,
        mesaj="Kayıt başarılı.",
        kullanici=kullanici_yanitina_donustur(yeni_kullanici),
        token=token_olustur(yeni_kullanici),
    )

@uygulama.post("/api/kullanici/giris", response_model=KimlikIslemYaniti)
async def kullanici_giris(istek: KullaniciGirisIstegi, veritabani: Session = Depends(veritabani_oturumu_al)):
    eposta = epostayi_duzenle(istek.eposta)
    kullanici = veritabani.query(Kullanici).filter(Kullanici.eposta == eposta).first()

    if kullanici is None or not sifre_dogru_mu(istek.sifre, kullanici.sifre_ozeti):
        return KimlikIslemYaniti(
            basarili=False,
            mesaj="E-posta veya şifre hatalı.",
            kullanici=None,
        )

    return KimlikIslemYaniti(
        basarili=True,
        mesaj="Giriş başarılı.",
        kullanici=kullanici_yanitina_donustur(kullanici),
        token=token_olustur(kullanici),
    )

@uygulama.get("/api/kullanici/ben", response_model=KullaniciYaniti)
async def aktif_kullanici_bilgisi(kullanici: Kullanici = Depends(aktif_kullaniciyi_al)):
    return kullanici_yanitina_donustur(kullanici)

@uygulama.post("/api/kullanici/cikis", response_model=KimlikIslemYaniti)
async def kullanici_cikis(kullanici: Kullanici = Depends(aktif_kullaniciyi_al)):
    return KimlikIslemYaniti(
        basarili=True,
        mesaj="Çıkış başarılı. Mobil uygulama kayıtlı token'ı silmelidir.",
        kullanici=kullanici_yanitina_donustur(kullanici),
        token=None,
    )

# Admin paneli mevcut canli ayarlari bu adresten okur.
@uygulama.get("/api/admin/ayarlar", response_model=SenkronizasyonAyarlariYaniti)
async def admin_ayarlarini_getir(
    admin: Kullanici = Depends(aktif_admini_al),
    veritabani: Session = Depends(veritabani_oturumu_al),
):
    return sistem_ayarlarini_al(veritabani)

@uygulama.get("/api/bot/uretim-plani", response_model=BotUretimPlaniYaniti)
async def bot_uretim_planini_getir(veritabani: Session = Depends(veritabani_oturumu_al)):
    return bot_uretim_planini_al(veritabani)

# Admin paneli acik/kapali ve limit ayarlarini bu adresten degistirir.
@uygulama.put("/api/admin/ayarlar", response_model=SenkronizasyonAyarlariYaniti)
async def admin_ayarlarini_guncelle(
    istek: AdminAyarlariGuncellemeIstegi,
    admin: Kullanici = Depends(aktif_admini_al),
    veritabani: Session = Depends(veritabani_oturumu_al),
):
    global bot_sureci
    gelen_ayarlar = istek.model_dump(exclude_unset=True)
    mevcut_ayarlar = sistem_ayarlarini_al(veritabani)
    varsayilan_paket_limiti = gelen_ayarlar.get("varsayilan_paket_limiti", mevcut_ayarlar.varsayilan_paket_limiti)
    en_yuksek_paket_limiti = gelen_ayarlar.get("en_yuksek_paket_limiti", mevcut_ayarlar.en_yuksek_paket_limiti)

    if varsayilan_paket_limiti > en_yuksek_paket_limiti:
        raise HTTPException(status_code=400, detail="Varsayilan paket limiti en yuksek paket limitinden buyuk olamaz.")

    anahtarlar = {
        "kayitlar_aktif": AYAR_KAYITLAR_AKTIF,
        "api_aktif": AYAR_API_AKTIF,
        "soru_uretimi_aktif": AYAR_SORU_URETIMI_AKTIF,
        "mobil_senkronizasyon_aktif": AYAR_MOBIL_SENKRONIZASYON_AKTIF,
        "bot_aktif": AYAR_BOT_AKTIF,
        "bot_hedef_soru_sayisi": AYAR_BOT_HEDEF_SORU_SAYISI,
        "tum_hesaplar_konu_basina_soru_siniri": AYAR_TUM_HESAPLAR_KONU_BASINA_SORU_SINIRI,
        "ucretli_hesaplar_konu_basina_soru_siniri": AYAR_UCRETLI_HESAPLAR_KONU_BASINA_SORU_SINIRI,
        "varsayilan_paket_limiti": AYAR_MOBIL_VARSAYILAN_PAKET_LIMITI,
        "en_yuksek_paket_limiti": AYAR_MOBIL_EN_YUKSEK_PAKET_LIMITI,
    }

    try:
        for alan_adi, deger in gelen_ayarlar.items():
            if deger is None:
                continue
            kayit_degeri = str(deger).lower() if isinstance(deger, bool) else str(deger)
            ayar_degerini_kaydet(veritabani, anahtarlar[alan_adi], kayit_degeri)

        if gelen_ayarlar.get("api_aktif") is False:
            ayar_degerini_kaydet(veritabani, AYAR_BOT_AKTIF, "false")
            if bot_sureci is not None and bot_sureci.poll() is None:
                bot_sureci.terminate()
                bot_sureci = None

        admin_islemini_kaydet(veritabani, admin, "ayar_guncelleme", gelen_ayarlar)
        veritabani.commit()
    except Exception as hata:
        veritabani.rollback()
        raise HTTPException(status_code=500, detail=str(hata))

    return sistem_ayarlarini_al(veritabani)

@uygulama.post("/api/admin/senkronizasyon/tetikle", response_model=SenkronizasyonAyarlariYaniti)
async def admin_veritabani_senkronizasyonunu_tetikle(
    admin: Kullanici = Depends(aktif_admini_al),
    veritabani: Session = Depends(veritabani_oturumu_al),
):
    """
    Mobil cihazlara güvenli tam eşitleme sinyali üretir.
    Bu işlem cihaz verisini silmez; istemciler uygun anda önce bekleyen çözümleri
    sunucuya gönderip sonra güncel sunucu tablolarını çeker.
    """
    mevcut_versiyon = int_ayarini_al(veritabani, AYAR_VERITABANI_SENKRONIZASYON_VERSIYONU, 0)
    yeni_versiyon = mevcut_versiyon + 1
    simdi = datetime.utcnow()

    try:
        ayar_degerini_kaydet(veritabani, AYAR_VERITABANI_SENKRONIZASYON_VERSIYONU, str(yeni_versiyon))
        ayar_degerini_kaydet(veritabani, AYAR_VERITABANI_SENKRONIZASYON_TARIHI, simdi.isoformat())
        admin_islemini_kaydet(veritabani, admin, "veritabani_senkronizasyon_tetikleme", {
            "versiyon": yeni_versiyon,
            "tarih": simdi.isoformat(),
        })
        veritabani.commit()
    except Exception as hata:
        veritabani.rollback()
        raise HTTPException(status_code=500, detail=str(hata))

    return sistem_ayarlarini_al(veritabani)

@uygulama.post("/api/admin/bot/baslat", response_model=SenkronizasyonAyarlariYaniti)
async def admin_botu_baslat(
    admin: Kullanici = Depends(aktif_admini_al),
    veritabani: Session = Depends(veritabani_oturumu_al),
):
    global bot_sureci
    if not sistem_ayarlarini_al(veritabani).api_aktif:
        raise HTTPException(status_code=409, detail="Botu baslatmadan once ana API etkinlestirilmelidir.")

    ayar_degerini_kaydet(veritabani, AYAR_BOT_AKTIF, "true")
    admin_islemini_kaydet(veritabani, admin, "bot_baslatma", {})
    veritabani.commit()

    if bot_sureci is None or bot_sureci.poll() is not None:
        bot_yolu = os.path.join(os.path.dirname(__file__), "bot.py")
        bot_sureci = subprocess.Popen([sys.executable, bot_yolu], cwd=os.path.dirname(__file__))

    return sistem_ayarlarini_al(veritabani)

@uygulama.post("/api/admin/bot/durdur", response_model=SenkronizasyonAyarlariYaniti)
async def admin_botu_durdur(
    admin: Kullanici = Depends(aktif_admini_al),
    veritabani: Session = Depends(veritabani_oturumu_al),
):
    global bot_sureci
    if bot_sureci is not None and bot_sureci.poll() is None:
        bot_sureci.terminate()
        bot_sureci = None

    ayar_degerini_kaydet(veritabani, AYAR_BOT_AKTIF, "false")
    admin_islemini_kaydet(veritabani, admin, "bot_durdurma", {})
    veritabani.commit()
    return sistem_ayarlarini_al(veritabani)

# Admin paneli son uretilen yayindaki sorulari silmeden pasif hale getirir.
@uygulama.post("/api/admin/sorular/son-n-pasiflestir", response_model=AdminIslemYaniti)
async def son_sorulari_pasiflestir(
    istek: SonSorulariPasiflestirIstegi,
    admin: Kullanici = Depends(aktif_admini_al),
    veritabani: Session = Depends(veritabani_oturumu_al),
):
    sorular = (
        veritabani.query(Soru)
        .filter(Soru.durum == "yayinda")
        .order_by(Soru.soru_id.desc())
        .limit(istek.adet)
        .all()
    )

    try:
        simdi = datetime.utcnow()
        for soru in sorular:
            soru.durum = "pasif"
            soru.guncellenme_tarihi = simdi

        admin_islemini_kaydet(veritabani, admin, "son_sorulari_pasiflestirme", {
            "istenen_adet": istek.adet,
            "etkilenen_kayit_sayisi": len(sorular),
            "soru_id_listesi": [soru.soru_id for soru in sorular],
        })
        veritabani.commit()
    except Exception as hata:
        veritabani.rollback()
        raise HTTPException(status_code=500, detail=str(hata))

    return AdminIslemYaniti(
        basarili=True,
        mesaj=f"Son {len(sorular)} soru pasif hale getirildi.",
        etkilenen_kayit_sayisi=len(sorular),
    )

@uygulama.post("/api/admin/sorular/latex-onar", response_model=AdminSoruOnarimYaniti)
async def soru_latex_metinlerini_onar(
    admin: Kullanici = Depends(aktif_admini_al),
    veritabani: Session = Depends(veritabani_oturumu_al),
):
    sorular = veritabani.query(Soru).all()
    etkilenen = 0

    for soru in sorular:
        degisti = False
        alanlar = [
            "sorumetni",
            "sorukoku",
            "secenek_a",
            "secenek_b",
            "secenek_c",
            "secenek_d",
            "secenek_e",
        ]

        for alan in alanlar:
            eski_deger = getattr(soru, alan)
            yeni_deger = latex_metin_onar(eski_deger)
            if yeni_deger != eski_deger:
                setattr(soru, alan, yeni_deger)
                degisti = True

        yeni_cozum = latex_deger_onar(soru.cozum or [])
        if yeni_cozum != (soru.cozum or []):
            soru.cozum = yeni_cozum
            degisti = True

        if degisti:
            soru.guncellenme_tarihi = datetime.utcnow()
            etkilenen += 1

    veritabani.commit()
    admin_islemini_kaydet(veritabani, admin, "soru_latex_metin_onarimi", {
        "taranan_kayit_sayisi": len(sorular),
        "etkilenen_kayit_sayisi": etkilenen,
    })

    return AdminSoruOnarimYaniti(
        basarili=True,
        mesaj=f"{etkilenen} soru kaydindaki LaTeX metinleri onarildi.",
        taranan_kayit_sayisi=len(sorular),
        etkilenen_kayit_sayisi=etkilenen,
    )

# Admin paneli daha once yapilan admin islemlerini bu adresten listeler.
@uygulama.get("/api/admin/islem-kayitlari", response_model=list[AdminIslemKaydiYaniti])
async def admin_islem_kayitlarini_listele(
    limit: int = 100,
    admin: Kullanici = Depends(aktif_admini_al),
    veritabani: Session = Depends(veritabani_oturumu_al),
):
    guvenli_limit = min(max(limit, 1), 500)
    kayitlar = (
        veritabani.query(AdminIslemKaydi)
        .order_by(AdminIslemKaydi.islem_id.desc())
        .limit(guvenli_limit)
        .all()
    )

    return [
        AdminIslemKaydiYaniti(
            islem_id=kayit.islem_id,
            kullanici_id=kayit.kullanici_id,
            islem=kayit.islem,
            detay=kayit.detay or {},
            islem_tarihi=kayit.islem_tarihi,
        )
        for kayit in kayitlar
    ]

@uygulama.post("/api/soru-uret", response_model=SoruUretimYaniti)
async def soru_uret_ucnoktasi(istek: SoruIstegi, veritabani: Session = Depends(veritabani_oturumu_al)):
    ana_apiyi_dogrula(veritabani)
    ayarlar = sistem_ayarlarini_al(veritabani)
    if not ayarlar.soru_uretimi_aktif:
        raise HTTPException(status_code=403, detail="Soru uretimi su anda admin tarafindan kapatildi.")

    try:
        # Konu ve zorluk bilgisine göre yapay zekaya gönderilecek metni hazırlıyoruz.
        istem_metni = f"Bana {istek.konu_adi} konusuyla ilgili, zorluk seviyesi '{istek.zorluk_seviyesi}' olan TYT/DGS tarzında 5 seçenekli özgün bir matematik test sorusu hazırla."
        if istek.ek_talimatlar:
            istem_metni += f" Ek talimat: {istek.ek_talimatlar}"

        # Hazırlanan metni Gemini'ye gönderip JSON formatında soru istiyoruz.
        gemini_yaniti = await gemini_icerik_uret(istem_metni, sicaklik=0.7)

        # Gelen cevabı önce JSON'a çeviriyor, sonra beklenen alanlara uyuyor mu diye kontrol ediyoruz.
        json_verisi = json.loads(gemini_yaniti.text)
        soru_verisi = SoruUretimYaniti(**json_verisi)
        
        # Doğrulanan soruyu ana veritabanındaki soru tablosuna kaydediyoruz.
        yeni_soru = Soru(
            sorumetni=latex_metin_onar(soru_verisi.baglam_metni or ""),
            soruresmi=None,
            sorukoku=latex_metin_onar(soru_verisi.soru_koku),
            secenek_a=latex_metin_onar(soru_verisi.secenekler.A),
            secenek_b=latex_metin_onar(soru_verisi.secenekler.B),
            secenek_c=latex_metin_onar(soru_verisi.secenekler.C),
            secenek_d=latex_metin_onar(soru_verisi.secenekler.D),
            secenek_e=latex_metin_onar(soru_verisi.secenekler.E),
            dogrucevap=soru_verisi.dogru_cevap,
            cozum=latex_deger_onar(cozum_adimlarini_hazirla(soru_verisi.cozum_adimlari, soru_verisi.dogru_cevap)),
            konu_id=istek.konu_id,
            difficulty=istek.zorluk_seviyesi,
            durum="yayinda",
        )
        veritabani.add(yeni_soru)
        veritabani.commit()
        veritabani.refresh(yeni_soru)

        return soru_verisi

    except Exception as hata:
        # Kayıt sırasında bir hata olursa yarım kalan işlemi geri alıyoruz.
        veritabani.rollback()
        if gemini_rate_limit_hatasi_mi(hata):
            raise HTTPException(
                status_code=429,
                detail=f"Yapay zeka bekleme modunda. {GEMINI_RATE_LIMIT_BEKLEME_SANIYE} saniye sonra tekrar deneyin.",
                headers={"Retry-After": str(GEMINI_RATE_LIMIT_BEKLEME_SANIYE)},
            )
        print("Soru uretim hatasi:")
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(hata))

# API'nin çalışıp çalışmadığını hızlıca kontrol etmek için basit cevap döner.
@uygulama.get("/")
def ana_sayfa():
    return {"message": "DGS Soru Üreticisi API Çalışıyor."}

# Mobil uygulama senkronizasyon ayarlarını bu adresten okuyabilir.
@uygulama.get("/api/senkronizasyon/ayarlar", response_model=SenkronizasyonAyarlariYaniti)
async def senkronizasyon_ayarlarini_getir(veritabani: Session = Depends(veritabani_oturumu_al)):
    return sistem_ayarlarini_al(veritabani)

# Mobil uygulama yeni soruları bu adresten parça parça çeker.
@uygulama.get("/api/mobil/sorular", response_model=MobilSoruListesiYaniti)
async def mobil_sorulari_listele(
    son_soru_id: int = 0,
    limit: Optional[int] = None,
    hesap_turu: HesapTuru = "ucretsiz",
    veritabani: Session = Depends(veritabani_oturumu_al),
):
    # Hesap türüne göre konu başına soru sınırını buluyoruz.
    ana_apiyi_dogrula(veritabani)
    ayarlar = sistem_ayarlarini_al(veritabani)
    if not ayarlar.mobil_senkronizasyon_aktif:
        raise HTTPException(status_code=403, detail="Mobil senkronizasyon su anda admin tarafindan kapatildi.")

    konu_basina_soru_siniri = konu_basina_soru_sinirini_bul(hesap_turu, ayarlar)

    # Çok büyük istekleri engellemek için limit değerini güvenli aralıkta tutuyoruz.
    istenen_limit = ayarlar.varsayilan_paket_limiti if limit is None else limit
    guvenli_limit = min(max(istenen_limit, 1), ayarlar.en_yuksek_paket_limiti)

    # Mobilde kayıtlı son sorudan büyük ID'ye sahip soruları sıralı şekilde alıyoruz.
    kayitlar = mobil_soru_sorgusunu_hazirla(veritabani, son_soru_id, konu_basina_soru_siniri).limit(guvenli_limit + 1).all()

    # Bir kayıt fazla çekerek devam sayfası var mı anlıyoruz.
    devam_var = len(kayitlar) > guvenli_limit
    secilen_kayitlar = kayitlar[:guvenli_limit]
    sorular = [mobil_soru_yanitina_donustur(soru) for soru in secilen_kayitlar]
    yeni_son_soru_id = sorular[-1].soru_id if sorular else son_soru_id

    return MobilSoruListesiYaniti(
        son_soru_id=yeni_son_soru_id,
        devam_var=devam_var,
        hesap_turu=hesap_turu,
        konu_basina_soru_siniri=konu_basina_soru_siniri,
        sorular=sorular,
    )

# Aynı senkronizasyon işlemi için daha açık isimli ikinci adresi de sağlıyoruz.
@uygulama.get("/api/mobil/senkronizasyon", response_model=MobilSoruListesiYaniti)
async def mobil_senkronizasyon(
    son_soru_id: int = 0,
    limit: Optional[int] = None,
    hesap_turu: HesapTuru = "ucretsiz",
    veritabani: Session = Depends(veritabani_oturumu_al),
):
    return await mobil_sorulari_listele(
        son_soru_id=son_soru_id,
        limit=limit,
        hesap_turu=hesap_turu,
        veritabani=veritabani,
    )

# Mobil uygulama tek bir soruyu ID ile tekrar almak isterse bu adresi kullanır.
# Mobil uygulama kullanicinin tek tek soru cozumunu bu adrese kaydeder.
@uygulama.post("/api/mobil/soru-cozumu", response_model=MobilSoruCozumuYaniti)
async def mobil_soru_cozumu_kaydet(
    istek: MobilSoruCozumuIstegi,
    kullanici: Kullanici = Depends(aktif_kullaniciyi_al),
    veritabani: Session = Depends(veritabani_oturumu_al),
):
    ana_apiyi_dogrula(veritabani)
    soru = veritabani.query(Soru).filter(Soru.soru_id == istek.soru_id).first()
    if soru is None:
        raise HTTPException(status_code=404, detail="Soru bulunamadi.")

    if istek.verilen_cevap is None:
        sonuc: CozumSonucu = "bos"
    elif istek.verilen_cevap == soru.dogrucevap:
        sonuc = "dogru"
    else:
        sonuc = "yanlis"

    cozum_kaydi = KullaniciSoruCozumu(
        kullanici_id=kullanici.kullanici_id,
        soru_id=soru.soru_id,
        verilen_cevap=istek.verilen_cevap,
        dogru_cevap=soru.dogrucevap,
        sonuc=sonuc,
        cozum_suresi_saniye=istek.cozum_suresi_saniye,
    )

    try:
        veritabani.add(cozum_kaydi)
        kullanici.cozulen_toplam_soru = (kullanici.cozulen_toplam_soru or 0) + 1
        if sonuc == "dogru":
            kullanici.dogru_sayisi = (kullanici.dogru_sayisi or 0) + 1
        elif sonuc == "yanlis":
            kullanici.yanlis_sayisi = (kullanici.yanlis_sayisi or 0) + 1
        else:
            kullanici.bos_sayisi = (kullanici.bos_sayisi or 0) + 1

        veritabani.commit()
        veritabani.refresh(cozum_kaydi)
    except Exception as hata:
        veritabani.rollback()
        raise HTTPException(status_code=500, detail=str(hata))

    return MobilSoruCozumuYaniti(
        cozum_id=cozum_kaydi.cozum_id,
        soru_id=cozum_kaydi.soru_id,
        verilen_cevap=cozum_kaydi.verilen_cevap,
        dogru_cevap=cozum_kaydi.dogru_cevap,
        sonuc=cozum_kaydi.sonuc,
        cozum_suresi_saniye=cozum_kaydi.cozum_suresi_saniye,
        cozulme_tarihi=cozum_kaydi.cozulme_tarihi,
    )

@uygulama.get("/api/mobil/sorular/{soru_id}", response_model=MobilSoruYaniti)
async def mobil_soru_detayi(soru_id: int, veritabani: Session = Depends(veritabani_oturumu_al)):
    ana_apiyi_dogrula(veritabani)
    # İstenen ID'ye sahip soruyu ana veritabanında arıyoruz.
    soru = veritabani.query(Soru).filter(Soru.soru_id == soru_id).filter(Soru.durum == "yayinda").first()
    if soru is None:
        raise HTTPException(status_code=404, detail="Soru bulunamadı.")
    return mobil_soru_yanitina_donustur(soru)

# Bir konunun prompt listesindeki bütün soruları sırayla üretir.
@uygulama.post("/api/toplu-soru-uret/{konu_id}")
async def toplu_soru_uret_ucnoktasi(konu_id: int, zorluk_seviyesi: ZorlukSeviyesi = "Orta", veritabani: Session = Depends(veritabani_oturumu_al)):
    ana_apiyi_dogrula(veritabani)
    ayarlar = sistem_ayarlarini_al(veritabani)
    if not ayarlar.soru_uretimi_aktif:
        raise HTTPException(status_code=403, detail="Soru uretimi su anda admin tarafindan kapatildi.")

    try:
        # Toplu üretimde kullanılacak konu ve istem şablonlarını dosyadan okuyoruz.
        dosya_yolu = os.path.join(os.path.dirname(__file__), 'prompts.json')
        if not os.path.exists(dosya_yolu):
            raise HTTPException(status_code=404, detail="prompts.json dosyası bulunamadı.")
            
        with open(dosya_yolu, 'r', encoding='utf-8') as dosya:
            istem_verileri = json.load(dosya)
            
        konu_anahtari = str(konu_id)
        if konu_anahtari not in istem_verileri:
            raise HTTPException(status_code=404, detail=f"{konu_id} ID'li konu için istem şablonu bulunamadı.")
            
        konu_adi = istem_verileri[konu_anahtari]['konu_adi']
        istem_listesi = istem_verileri[konu_anahtari]['promptlar']
        
        uretilen_sorular = []
        hatalar = []
        
        # API limitini zorlamamak için soruları sırayla ve kısa beklemeyle üretiyoruz.
        for sira, istem_sablonu in enumerate(istem_listesi):
            if sira > 0:
                await asyncio.sleep(GEMINI_ISTEKLER_ARASI_BEKLEME_SANIYE)
                
            istem_tam_metni = f"Bana {konu_adi} konusuyla ilgili, zorluk seviyesi '{zorluk_seviyesi}' olan TYT/DGS tarzında 5 seçenekli özgün bir matematik test sorusu hazırla. Ek talimat: {istem_sablonu}"
            
            try:
                # Her istem şablonu için Gemini'den ayrı bir soru istiyoruz.
                gemini_yaniti = await gemini_icerik_uret(istem_tam_metni, sicaklik=0.8)
                
                # Gelen soruyu kontrol edip ana veritabanına yazıyoruz.
                json_verisi = json.loads(gemini_yaniti.text)
                soru_verisi = SoruUretimYaniti(**json_verisi)
                
                yeni_soru = Soru(
                    sorumetni=latex_metin_onar(soru_verisi.baglam_metni or ""),
                    soruresmi=None, 
                    sorukoku=latex_metin_onar(soru_verisi.soru_koku),
                    secenek_a=latex_metin_onar(soru_verisi.secenekler.A),
                    secenek_b=latex_metin_onar(soru_verisi.secenekler.B),
                    secenek_c=latex_metin_onar(soru_verisi.secenekler.C),
                    secenek_d=latex_metin_onar(soru_verisi.secenekler.D),
                    secenek_e=latex_metin_onar(soru_verisi.secenekler.E),
                    dogrucevap=soru_verisi.dogru_cevap,
                    cozum=latex_deger_onar(cozum_adimlarini_hazirla(soru_verisi.cozum_adimlari, soru_verisi.dogru_cevap)),
                    konu_id=konu_id,
                    difficulty=zorluk_seviyesi,
                    durum="yayinda",
                )
                veritabani.add(yeni_soru)
                veritabani.commit()
                veritabani.refresh(yeni_soru)
                
                uretilen_sorular.append(soru_verisi.soru_koku)
                
            except Exception as hata:
                # Bu soru üretilemezse diğer istemlere devam etmek için hatayı listeye ekliyoruz.
                veritabani.rollback()
                hatalar.append(f"İstem {sira+1} üretilirken hata: {str(hata)}")

        return {
            "mesaj": f"{konu_adi} konusu için toplu üretim tamamlandı.",
            "basarili_uretim_sayisi": len(uretilen_sorular),
            "hatalar": hatalar,
            "uretilen_soru_kokleri": uretilen_sorular
        }

    except HTTPException:
        raise
    except Exception as hata:
        raise HTTPException(status_code=500, detail=str(hata))
