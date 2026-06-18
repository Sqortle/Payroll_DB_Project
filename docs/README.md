# Bordro Yönetim Sistemi — Veritabanı Projesi

<<<<<<< HEAD
**Ders:** Veritabanı Yönetim Sistemleri
**Teknoloji:** Oracle Database, PL/SQL
**Mimari:** SaaS Multi-tenancy (her tabloda `fk_company_id`)
**Tablo Sayısı:** 15 (gereksinim: en az 12)
=======
**Ders:** BİL312 - Veritabanı Yönetim Sistemleri
**Teknoloji:** Oracle Database, PL/SQL
**Mimari:** SaaS Multi-tenancy 
**Tablo Sayısı:** 15 
>>>>>>> 1ac1f6fa2ddb87246eab88aacb62a72b765ac739

## Proje Özeti

Bordro hesaplaması, personel yönetimi ve şirketler arası veri izolasyonu sağlayan bir SaaS bordro veritabanıdır. 15 tablo, 5 PL/SQL paketi, 2 trigger ve dinamik raporlama içerir. Veritabanı 3. Normal Form (3NF) standartlarındadır.

## Repo Yapısı

```
.
├── DB Project.md                  Ana dokuman (tum kodlar + acıklamalar)
├── README.md                      Bu dosya
├── docs/
│   └── payroll_chen_erd.drawio    ER diyagram (Chen notasyonu, draw.io)
├── sql/                           Calisma sirasina gore .sql dosyalari
│   ├── 01_create_tables.sql       Madde 2: 15 tablo
│   ├── 02_constraints_indexes.sql Madde 3: PK / FK / UNIQUE / Index
│   ├── 03_sequences_triggers.sql  Madde 7: Sequence + 2 Trigger
│   ├── packages/
│   │   ├── pkg_payroll_entry.sql       Madde 4: Veri girisi
│   │   ├── pkg_payroll_update.sql      Madde 5: Veri guncelleme
│   │   ├── pkg_payroll_delete.sql      Madde 6: Veri silme (hiyerarsik)
│   │   ├── pkg_payroll_reports.sql     Madde 8: Dinamik raporlar
│   │   └── pkg_payroll_maintenance.sql Madde 10: Mukerrer kayit silme
│   └── tests/
│       ├── 01_data_seeding.sql    Veri girisi (4 sirket + 30 calisan/sirket)
│       ├── 02_trigger_test.sql    Trigger dogrulama (4 senaryo)
│       ├── 03_update_test.sql     Guncelleme testi
│       ├── 04_delete_test.sql     Silme testi
│       ├── 05_report_test.sql     Rapor testi
│       └── 06_maintenance_test.sql Mukerrer kayit testi
└── presentation/
    ├── slides_outline.md          Sunum icerik taslagi
    └── report_outline.md          Rapor icerik taslagi
```

## Çalıştırma Sırası (SQL\*Plus / SQL Developer)

```
1. sql/01_create_tables.sql
2. sql/02_constraints_indexes.sql
3. sql/03_sequences_triggers.sql
4. sql/packages/pkg_payroll_entry.sql
5. sql/packages/pkg_payroll_update.sql
6. sql/packages/pkg_payroll_delete.sql
7. sql/packages/pkg_payroll_reports.sql
8. sql/packages/pkg_payroll_maintenance.sql
9. sql/tests/01_data_seeding.sql       (4 şirket + 120 çalışan oluşur)
10. sql/tests/02_trigger_test.sql      (trigger'ları doğrular)
11. sql/tests/03_update_test.sql       (terfi + zam testi)
12. sql/tests/05_report_test.sql       (IMSA çalışan raporu)
13. sql/tests/06_maintenance_test.sql  (mükerrer kayıt temizliği)
14. sql/tests/04_delete_test.sql       (en son: hiyerarşik silme)
```

> **Not:** `04_delete_test.sql` personel sildiği için en sona bırakılmıştır. Aksi halde update/report test'leri çalışmaz.

## Madde-Madde Karşılığı

| # | Gereksinim | Dosya |
|---|-----------|-------|
| 1 | E-R diyagramı | `docs/payroll_chen_erd.drawio` |
| 2 | Tablo oluşturma | `sql/01_create_tables.sql` |
| 3 | İndeksler | `sql/02_constraints_indexes.sql` |
| 4 | Veri girişi paketi | `sql/packages/pkg_payroll_entry.sql` |
| 5 | Veri güncelleme paketi | `sql/packages/pkg_payroll_update.sql` |
| 6 | Veri silme paketi | `sql/packages/pkg_payroll_delete.sql` |
| 7 | Trigger'lar | `sql/03_sequences_triggers.sql` |
| 8 | Dinamik raporlar | `sql/packages/pkg_payroll_reports.sql` |
| 9 | 3NF ispatı | `DB Project.md` (Madde 9) |
| 10 | Mükerrer kayıt silme | `sql/packages/pkg_payroll_maintenance.sql` |

## Tasarım Tercihleri

- **SaaS Multi-tenancy:** Her tabloda `fk_company_id` ile mantıksal izolasyon.
- **Manuel ID atama:** Akademik tercih; production sistemde sequence kullanılır.
- **Dinamik vergi/yasal parametreler:** `Tax_Slabs` ve `Statutory_Parameters` tablo bazlı, kod değişmeden güncellenebilir.
- **Hiyerarşik silme:** `ON DELETE CASCADE` yerine `pkg_payroll_delete` içinde manuel kontrol.
- **3NF:** Hiçbir tabloda geçişli bağımlılık yok.
