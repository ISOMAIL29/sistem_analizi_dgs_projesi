import json
import os
import time

import requests

API_ADRESI = "http://127.0.0.1:8000/api/soru-uret"
URETIM_PLANI_ADRESI = "http://127.0.0.1:8000/api/bot/uretim-plani"
ISTEM_DOSYASI = os.path.join(os.path.dirname(__file__), "prompts.json")
URETIMLER_ARASI_BEKLEME_SANIYE = 60
BEKLEME_MODU_KONTROL_SANIYE = 15
ZORLUK_DONGUSU = ("Kolay", "Orta", "Zor")


def uretim_planini_getir():
    try:
        yanit = requests.get(URETIM_PLANI_ADRESI, timeout=10)
        if yanit.status_code == 200:
            return yanit.json()
    except requests.RequestException:
        pass
    return None


def istem_verilerini_getir():
    if not os.path.exists(ISTEM_DOSYASI):
        raise FileNotFoundError("prompts.json dosyasi bulunamadi.")

    with open(ISTEM_DOSYASI, "r", encoding="utf-8") as dosya:
        return json.load(dosya)


def siradaki_konuyu_sec(plan):
    etkin_hedef = plan["etkin_hedef_soru_sayisi"]
    eksik_konular = [
        konu for konu in plan["konular"] if konu["soru_sayisi"] < etkin_hedef
    ]
    if not eksik_konular:
        return None
    return min(eksik_konular, key=lambda konu: (konu["soru_sayisi"], konu["konu_id"]))


def bot_baslat():
    istem_verileri = istem_verilerini_getir()
    print("Bot dengeli uretim planiyla baslatildi.")

    while True:
        plan = uretim_planini_getir()
        if plan is None:
            print("Uretim plani alinamadi. Baglanti tekrar denenecek.")
            time.sleep(BEKLEME_MODU_KONTROL_SANIYE)
            continue

        if not plan["bot_aktif"]:
            print("Bot admin tarafindan durduruldu.")
            return

        if not plan["api_aktif"]:
            print("Ana API kapali. Bot bekliyor.")
            time.sleep(BEKLEME_MODU_KONTROL_SANIYE)
            continue

        siradaki_konu = siradaki_konuyu_sec(plan)
        if siradaki_konu is None:
            print("Tum konular hedef soru sayisina ulasti. Bot tamamlandi.")
            return

        konu_anahtari = str(siradaki_konu["konu_id"])
        konu_verisi = istem_verileri.get(konu_anahtari)
        if konu_verisi is None or not konu_verisi.get("promptlar"):
            print(f"Konu {konu_anahtari} icin istem bulunamadi. Bot durduruldu.")
            return

        # Konudaki mevcut sayi ilerleme imlecidir; yeniden baslatilsa da ayni
        # seviyeden sonraki isteme gecilir.
        istemler = konu_verisi["promptlar"]
        istem_indeksi = siradaki_konu["soru_sayisi"] % len(istemler)
        zorluk_seviyesi = ZORLUK_DONGUSU[
            siradaki_konu["soru_sayisi"] % len(ZORLUK_DONGUSU)
        ]
        istek_verisi = {
            "konu_id": siradaki_konu["konu_id"],
            "konu_adi": siradaki_konu["konu_adi"],
            "zorluk_seviyesi": zorluk_seviyesi,
            "ek_talimatlar": istemler[istem_indeksi],
        }
        print(
            f"{siradaki_konu['konu_adi']}: "
            f"{siradaki_konu['soru_sayisi']}/{plan['etkin_hedef_soru_sayisi']} "
            f"icin {zorluk_seviyesi} yeni soru isteniyor."
        )

        try:
            yanit = requests.post(API_ADRESI, json=istek_verisi, timeout=180)
        except requests.RequestException as hata:
            print(f"Iletisim hatasi, kaldigi yerden tekrar denenecek: {hata}")
            time.sleep(BEKLEME_MODU_KONTROL_SANIYE)
            continue

        if yanit.status_code == 200:
            time.sleep(URETIMLER_ARASI_BEKLEME_SANIYE)
            continue

        if yanit.status_code == 429:
            bekleme = int(
                yanit.headers.get("Retry-After", BEKLEME_MODU_KONTROL_SANIYE)
            )
            print("Yapay zeka bekleme modunda. Uretim durdu; ayni noktadan tekrar denenecek.")
            time.sleep(max(bekleme, BEKLEME_MODU_KONTROL_SANIYE))
            continue

        if yanit.status_code in {403, 503}:
            print("Uretim su anda kapali. Ayarlar tekrar kontrol edilecek.")
            time.sleep(BEKLEME_MODU_KONTROL_SANIYE)
            continue

        print(
            f"Soru uretilemedi ({yanit.status_code}). "
            f"Sunucu yaniti: {yanit.text[:1000]}"
        )
        print("Kaldigi yerden tekrar denenecek.")
        time.sleep(BEKLEME_MODU_KONTROL_SANIYE)


if __name__ == "__main__":
    bot_baslat()
