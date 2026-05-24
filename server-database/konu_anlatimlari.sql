-- Konu metinleri uygulama icine gomulecegi icin veritabaninda tutulmaz.
-- Bu dosya konu adlarini korur ve konu_metin alanini NULL olarak ayarlar.

ALTER TABLE konu ALTER COLUMN konu_metin DROP NOT NULL;

INSERT INTO konu (id, konu_adi, konu_metin, konu_resmi) VALUES
(1, 'Temel Kavramlar', NULL, NULL),
(2, 'Sayı Basamakları', NULL, NULL),
(3, 'Bölme ve Bölünebilme', NULL, NULL),
(4, 'EBOB ve EKOK', NULL, NULL),
(5, 'Rasyonel Sayılar', NULL, NULL),
(6, 'Basit Eşitsizlikler', NULL, NULL),
(7, 'Mutlak Değer', NULL, NULL),
(8, 'Üslü Sayılar', NULL, NULL),
(9, 'Köklü Sayılar', NULL, NULL),
(10, 'Çarpanlara Ayırma', NULL, NULL),
(11, 'Oran ve Orantı', NULL, NULL),
(12, 'Denklem Çözme', NULL, NULL),
(13, 'Problemler', NULL, NULL),
(14, 'Kümeler', NULL, NULL),
(15, 'Fonksiyonlar', NULL, NULL),
(16, 'Permutasyon', NULL, NULL),
(17, 'Kombinasyon', NULL, NULL),
(18, 'Olasılık', NULL, NULL),
(19, 'Sayısal Mantık', NULL, NULL),
(20, 'Tablo ve Grafik Yorumlama', NULL, NULL),
(21, 'Sayı Problemleri', NULL, NULL),
(22, 'Kesir Problemleri', NULL, NULL),
(23, 'Yüzde Problemleri', NULL, NULL),
(24, 'Kar-Zarar Problemleri', NULL, NULL),
(25, 'Faiz Problemleri', NULL, NULL),
(26, 'Yaş Problemleri', NULL, NULL),
(27, 'Hareket Problemleri', NULL, NULL),
(28, 'İşçi-Havuz Problemleri', NULL, NULL)
ON CONFLICT (id) DO UPDATE SET
    konu_adi = EXCLUDED.konu_adi,
    konu_metin = NULL;

SELECT setval(pg_get_serial_sequence('konu', 'id'), COALESCE((SELECT MAX(id) FROM konu), 1), true);
