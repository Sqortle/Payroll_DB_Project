# Bordro Yönetim Sistemi — Savunma Soru Bankası (Oracle PL/SQL)

Bu doküman, Oracle veritabanı üzerine kurulu çok kiracılı (multi-tenant / SaaS) bir **Bordro Yönetim Sistemi** dönem projesinin savunmasına hazırlık için derlenmiştir. Sorular kategorilere göre gruplanmış, her birinin ardından savunmada kullanılabilecek kısa ve doğru model cevap verilmiştir. En sonda, hocanın yüklenebileceği **bilinçli kabul edilmesi gereken zayıf noktalar** ayrı bir bölümde toplanmıştır.

> **Asansör Özeti (savunmanın ilk cümleleri):**
> "Projemiz, birden fazla şirketin (tenant) aynı veritabanını paylaştığı bir SaaS Bordro Yönetim Sistemidir. 15 ilişkisel tablodan oluşur; tanım (lookup) ve hareket (transaction) tabloları ayrıştırılmış, büyük ölçüde 3NF'e uygun normalize edilmiştir. Tüm iş mantığı 6 PL/SQL paketinde (ekleme, güncelleme, silme, raporlama, bakım) modüler olarak toplanmıştır. Çok kiracılı izolasyon için her tabloda `fk_company_id` taşınır; tanım tablosuna personel girilince hareket tablosuna otomatik kayıt açan trigger'lar, audit log mekanizması, sequence kullanımı, dinamik filtrelemeli raporlama ve ROWID tabanlı mükerrer kayıt temizliği sistemin öne çıkan yetenekleridir. Bordro tutarları yasal bir snapshot olarak bilinçli denormalize edilerek saklanır."

---

## 1. Temel Kavramlar

**1. DBMS ile RDBMS arasındaki fark nedir ve sistem neden RDBMS (Oracle) üzerine kurulu?**
DBMS veriyi saklayıp yöneten genel bir yazılımdır; RDBMS ise veriyi birbiriyle ilişkili tablolar halinde tutan, ilişkileri PK/FK ile kuran bir DBMS türüdür. Projedeki 15 tablo birbirine FK ile bağlı (örn. `Employees.fk_company_id -> Companies.company_id`). İlişkisel bütünlük ve normalizasyon RDBMS olmadan sağlanamayacağı için Oracle kullanıldı.

**2. SQL ile PL/SQL arasındaki fark nedir, projede hangisi nerede kullanıldı?**
SQL bildirimsel (declarative) sorgu dilidir; tekil komutlar çalıştırır. PL/SQL ise Oracle'ın prosedürel uzantısıdır (değişken, IF, döngü, exception, prosedür/fonksiyon). Tablo ve kısıt oluşturmada saf SQL (DDL), iş mantığında PL/SQL paketleri (pkg_payroll_entry, pkg_payroll_delete vb.) kullanıldı. `SQL%ROWCOUNT`, `RAISE_APPLICATION_ERROR` ve trigger'lardaki `IF INSERTING/DELETING` mantığı PL/SQL örnekleridir.

**3. DDL, DML, DCL ve TCL komut gruplarını projeden örneklerle açıklayın.**
- **DDL** (yapı): `CREATE TABLE`, `ALTER TABLE ... ADD CONSTRAINT`, `CREATE INDEX`, `CREATE SEQUENCE`.
- **DML** (veri): paketlerdeki `INSERT`, `UPDATE`, `DELETE`.
- **DCL** (yetki): `GRANT`/`REVOKE` (doğrudan kullanılmadı; rol bazlı erişim `Users.role` ile uygulama katmanında planlandı).
- **TCL** (işlem): pkg_payroll_maintenance içindeki `COMMIT` ve `ROLLBACK`.

**4. Transaction nedir, ACID ilkeleri nelerdir?**
Transaction, ya tamamı uygulanan ya da hiç uygulanmayan mantıksal bir iş birimidir. ACID: **Atomicity** (ya hep ya hiç), **Consistency** (kısıtlar korunur), **Isolation** (eşzamanlı işlemler birbirini bozmaz), **Durability** (COMMIT sonrası kalıcı). `remove_all_duplicates` 15 tabloyu sırayla temizler; hepsi başarılıysa tek COMMIT, hata olursa ROLLBACK ile yarım iş geri alınır — bu Atomicity garantisidir.

**5. Primary Key ile Unique Key arasındaki fark nedir, projede her ikisine örnek var mı?**
PK satırı tekil tanımlar, tablo başına bir tanedir ve NULL kabul etmez (örn. `pk_employees`). UNIQUE de tekilliği garantiler ama tablo başına birden çok olabilir ve (tek sütunluysa) NULL'a izin verir. Projede composite UNIQUE'ler var: `uq_emp_national_id (fk_company_id, national_id)` ve `uq_payroll_period (fk_employee_id, period_month, period_year)`. Özetle PK kimlik için, UNIQUE iş kuralı (business key) tekilliği içindir.

**6. Oracle'da boolean olmadığı için is_active'i neden NUMBER(1) yaptınız? NUMBER(p,s) nedir?**
Oracle SQL'inde tablo sütunu için yerleşik BOOLEAN yoktur (BOOLEAN sadece PL/SQL içinde). 0/1 mantığını NUMBER(1) ile temsil ettik; sayısal karşılaştırmaya (`is_active = 1`) en uygun, en küçük tiptir (CHAR(1) tip dönüşümü gerektirirdi). NUMBER(p,s)'de **p** toplam basamak (precision), **s** ondalık basamak (scale). Örn. NUMBER(15,2) maaş tutarları, NUMBER(5,4) `salary_multiplier` için 1.1000 gibi oranlar.

**7. VARCHAR2 ile CHAR farkı nedir? national_id neden CHAR(11) değil VARCHAR2(11)?**
CHAR sabit uzunluktur, kısa değerleri boşlukla doldurur (pad) ve bu karşılaştırmada sorun çıkarabilir. VARCHAR2 değişken uzunluktur, sadece girilen karakteri saklar. national_id mantıken sabit 11 hane olsa da VARCHAR2 seçtik ki pad kaynaklı beklenmedik boşluk karşılaştırma hataları olmasın; Oracle'da metinler için pratikte hep VARCHAR2 tercih edilir. (Not: 11 hane ve rakam zorunluluğu tip değil bir CHECK kısıtıyla garanti edilmeliydi — bkz. Zayıf Noktalar.)

**8. NULL'ın davranışı nedir, neden 'NULL = NULL' true dönmez?**
NULL "bilinmeyen / değer yok" demektir; sıfır ya da boş string değildir. Bu yüzden NULL ile yapılan her karşılaştırma (NULL = NULL dahil) TRUE değil **UNKNOWN** döner; kontrol `IS NULL` / `IS NOT NULL` ile yapılır. Projede `Tax_Slabs.fk_company_id` global vergi dilimi için NULL bırakılır; `Payroll_Logs.fk_user_id` trigger DB seviyesinde uygulama kullanıcısını bilmediği için NULL yazılır.

**9. Cursor nedir? Implicit ve explicit cursor farkı, SYS_REFCURSOR neden kullanıldı?**
Cursor, bir sorgunun sonuç kümesine işaret eden bellek alanıdır. **Implicit cursor** tek satır/DML sorgularında Oracle'ın otomatik açtığıdır; `SQL%ROWCOUNT` onun bir özniteliğidir. **Explicit cursor** programcının DECLARE/OPEN/FETCH/CLOSE ettiği, çok satırı satır satır gezen imleçtir. **SYS_REFCURSOR** bir cursor'a işaretçidir (weakly typed); raporlarda dinamik sorgu sonucunu çağırana döndürmek için kullanıldı, çünkü sonuç yapısı çalışma anında belli olur.

---

## 2. Şema & ER Tasarımı

**10. Sistemdeki 15 tabloyu kavramsal olarak hangi gruplara ayırırsın?**
Üç grup: (1) **Tanım/master tabloları** (statik referans): Companies, Departments, Job_Titles, Allowance_Types, Deduction_Types, Tax_Slabs, Statutory_Parameters, Users. (2) **Ana varlık ve 1:1 uzantısı**: Employees ve Employee_Contracts. (3) **Hareket (transaction) tabloları** (sürekli kayıt eklenir): Attendance_Records, Employee_Allowances, Employee_Deductions, Payroll_Summary, Payroll_Logs. Lookup tabloları nadiren değişir/silinmez; hareket tabloları aylık büyür ve raporlamanın kaynağıdır.

**11. Surrogate key mi natural key mi kullandın? national_id (TCKN) varken neden employee_id PK?**
Tüm tablolarda surrogate (vekil) NUMBER key kullandım. TCKN doğal aday anahtar olsa da PK yapmadım çünkü: (1) TCKN değişebilir/düzeltilebilir, PK değişmemelidir; (2) VARCHAR2(11) FK olarak her çocuk tabloya taşınması yer kaplar ve JOIN'i yavaşlatır, NUMBER surrogate daha hızlı indekslenir; (3) TCKN hassas veridir, FK olarak yayılması gizlilik riskidir. Yine de `uq_emp_national_id (fk_company_id, national_id)` bileşik UNIQUE ile iş kuralını koruyorum.

**12. fk_company_id'yi neredeyse her tabloya koymuşsun; bu denormalizasyon değil mi?**
Evet, bilinçli ve kontrollü bir denormalizasyondur, SaaS multi-tenancy için yapıldı. Faydaları: (1) **Tenant izolasyonu** — her sorguya doğrudan `WHERE fk_company_id = :x` eklenebilir, ileride VPD/RLS politikası tek sütuna bağlanabilir; (2) **Performans** — şirket bazlı raporlarda Employees üzerinden JOIN yapmadan filtrelenebilir. Maliyeti, `fk_employee_id` ile `fk_company_id` arasındaki tutarlılığın bileşik FK olmadan garanti edilmemesidir; bunu uygulama/trigger katmanında tutarlı atadığımı varsayıyorum.

**13. Employee_Allowances ve Employee_Deductions neden ayrı varlık? ER'deki rolü nedir?**
Bunlar M:N ilişkiyi çözen **junction (bağlantı) tablolarıdır**. Bir çalışan çok ek ödeme/kesinti türü alabilir, bir tür de çok çalışanda kullanılabilir. İlişkisel modelde M:N doğrudan kurulamaz, iki adet 1:N'e bölünür. Employee_Allowances `fk_employee_id` ve `fk_allowance_type_id` ile köprüyü kurar; ayrıca `amount`, `payment_date` gibi ilişkiye ait nitelikler (association attributes) taşıdığı için aynı zamanda bir hareket tablosudur.

**14. Tax_Slabs/Statutory_Parameters'ta fk_company_id NULL olabiliyor ama Employees'ta NOT NULL. Neden?**
Bilinçli tasarım. Vergi dilimleri ve yasal parametreler (SGK oranı gibi) çoğunlukla ülke genelinde **global**dir. `fk_company_id = NULL` "tüm tenant'lar için geçerli global parametre", dolu olması "şirkete özel override" anlamına gelir. Departments/Employees doğası gereği her zaman bir şirkete ait olduğundan orada NOT NULL'dur. Risk: global/tenant ayrımının uygulamada COALESCE/öncelik mantığıyla doğru yorumlanması gerekir.

**15. Companies satırı silinmek istense ne olur?**
Companies tüm tabloların köküdür; doğrudan silmek bağlı child kayıtlar yüzünden FK ihlali (ORA-02292) verir, çünkü FK'larda `ON DELETE CASCADE` tanımlamadım. Bu istenen davranıştır: tenant verisini kazara topluca silmeyi önler. Bilinçli silme gerekirse hiyerarşik silme (en alt child'dan köke) ya da soft-delete (`is_active`) tercih edilmeli. CASCADE kullanmama nedeni, bordro/log gibi yasal kayıtların kontrolsüz topluca silinmesinin muhasebe açısından kabul edilemez olmasıdır.

**16. uq_payroll_period'a neden fk_company_id'yi dahil etmedin? (bkz. Zayıf Noktalar — tuzak)**
`fk_employee_id` zaten `Employees(employee_id)` PK'sine bağlı ve `employee_id` **global olarak (tüm tenant'larda) tekildir**. Bir employee_id tek bir şirkete ait olduğu için (employee_id, ay, yıl) tekilliği dolaylı olarak şirketi de sabitler; fk_company_id eklemek gereksiz olurdu. Bu, tasarımın gizli bir varsayıma (global employee_id) dayandığını kabul ederek savunulmalı.

**17. Employees -> Employee_Contracts ilişkisi gerçekten 1:1 zorlanıyor mu? (bkz. Zayıf Noktalar — tuzak)**
Şema seviyesinde 1:1 ZORLANMIYOR; `fk_employee_id` üzerinde UNIQUE yok, dolayısıyla DB fiilen 1:N'e izin verir. Detaylı dürüst savunma Zayıf Noktalar bölümündedir.

**18. Payroll_Logs.fk_payroll_id'ye neden FOREIGN KEY koymadın?**
Kasıtlı bir audit kararı. Audit/log tabloları kaynak tabloya FK ile bağlanmamalıdır. FK koysaydım bir bordro DELETE edildiğinde o bordronun eski INSERT/UPDATE logları FK'yi ihlal eder (ORA-02292) ve silme bloklanırdı; ayrıca trigger'ın yazdığı DELETE log kaydı da yazılamazdı (parent siliniyor). Audit felsefesi: log kalıcı ve değişmez (immutable) bir tarihçedir, kaynak silinse bile log durmalıdır. Bu, denetim izinin doğruluğu uğruna katı referans bütünlüğünden bilinçli bir tavizdir. (`fk_company_id` ve `fk_user_id`'ye FK koyduk çünkü onlar silinmeyen referans tablolardır.)

---

## 3. Normalizasyon (1NF / 2NF / 3NF / BCNF)

**19. Normalizasyon nedir, neden uygulanır, hangi problemleri çözer?**
Normalizasyon, veriyi tekrar (redundancy) ve anomalilerden arındırmak için tabloları fonksiyonel bağımlılıklara göre parçalama sürecidir. Amacı veri tekrarını azaltmak ve bütünlüğü korumaktır. Çözdüğü problemler: ekleme, güncelleme ve silme anomalileri. Örneğin departman adını her çalışan satırında tutsaydık, ad değişince yüzlerce satırı güncellemek gerekir; biz bunu Departments tablosuna ayırdık.

**20. 1NF, 2NF, 3NF kurallarını tanımlayın ve projeden örnek verin.**
- **1NF**: Her hücre atomik, tekrarlayan sütun grubu yok. Payroll_Summary'de Ocak_Maasi/Subat_Maasi yerine `period_month`/`period_year` ile her ay ayrı satır.
- **2NF**: 1NF + anahtar-dışı alan PK'nin yalnız bir parçasına bağlı olamaz (kısmi bağımlılık yok).
- **3NF**: 2NF + geçişli bağımlılık yok; anahtar-dışı alan başka anahtar-dışı alana bağlı olamaz. `department_name`'i Employees'a koymayıp Departments'a aldık.

**21. department_name'i Employees'a koysaydın hangi anomaliler çıkardı?**
`employee_id -> fk_department_id -> department_name` geçişli bağımlılığı olur, 3NF ihlali. Üç anomali: (1) **Güncelleme**: departman adı değişince tüm çalışan satırlarını tek tek güncellemek gerekir, biri atlanırsa tutarsızlık. (2) **Ekleme**: çalışanı olmayan yeni departmanı ekleyemezdik. (3) **Silme**: bir departmandaki son çalışanı silersek departman bilgisi kaybolurdu. Bu yüzden ayrı Departments tablosu + `fk_department_id`.

**22. Tasarım BCNF'i sağlıyor mu? 3NF–BCNF farkı nedir?**
BCNF daha katıdır: her fonksiyonel bağımlılığın sol tarafı (determinant) bir aday anahtar (superkey) olmalı. 3NF prime attribute'lara biraz tolerans tanır, BCNF tanımaz. Tablolarımızın çoğunda tek determinant var (surrogate PK + tek bileşik UNIQUE), anahtar-dışı alanlar sadece bu anahtara bağlı. Tek determinantlı tablolar kullandığım için 3NF ve BCNF burada çakışıyor; örtüşen ikinci bir bileşik aday anahtar + aralarında bağımlılık modellemediğim için BCNF korunuyor.

**23. Tax_Slabs'taki fonksiyonel bağımlılıkları nasıl tanımlarsın, tablo 3NF mi?**
PK `slab_id -> {fk_company_id, min_income, max_income, tax_rate}`. İş mantığı açısından (fk_company_id, min_income) de pratikte aday anahtar gibidir ve tax_rate'i belirler. Anahtar-dışı bir alanın başka anahtar-dışı alana bağlı olduğu geçişli bağımlılık yoktur (tax_rate doğrudan dilime bağlı, max_income'a değil). Dolayısıyla 3NF'tir. Not: aralıkların çakışmaması normalizasyonla değil CHECK/uygulama mantığıyla sağlanan ayrı bir kuraldır.

**24. Attendance_Records'ta attendance_id (PK) ile UNIQUE (fk_employee_id, record_month, record_year) ilişkisi nedir, worked_days hangi anahtara bağlı, 2NF sorunu var mı?**
`attendance_id` surrogate PK'dir; (fk_employee_id, record_month, record_year) doğal **aday/alternate anahtardır**. `worked_days`, `overtime_hours` bir personelin belirli ay/yıldaki çalışmasını ifade eder, yani bu **üçlünün tamamına** bağlıdır. Bileşik aday anahtara göre kontrol edildiğinde kısmi bağımlılık YOKTUR, tablo 2NF'tir. Worked_days sadece personele bağlı olsaydı kısmi bağımlılık olurdu; puantaj aya özgü olduğu için tam bağımlılık var.

**25. Employee_Allowances junction tablosunda is_taxable'ı neden Allowance_Types'ta tuttun?**
`is_taxable` ödeme TÜRÜNE bağlıdır, tekil kayda değil. Köprüye koysaydık `emp_allowance_id -> fk_allowance_type_id -> is_taxable` geçişli bağımlılığı (3NF ihlali) olurdu: tür her kullanıldığında is_taxable tekrarlanır, türün vergi durumu değişince tüm geçmiş kayıtlar güncellenir (güncelleme anomalisi). Bu yüzden tür bilgisini Allowance_Types'a ayırıp `fk_allowance_type_id` ile bağladık.

**26. Denormalizasyon ne zaman tercih edilir, projede var mı?**
Çok sayıda JOIN'in performansı düşürdüğü, sık okunan ama az değişen veride veya tarihsel snapshot gerektiren durumlarda bilinçli tercih edilir; karşılığında redundancy ve güncelleme sorumluluğu kabul edilir. En net örnek **Payroll_Summary'deki gross/net/total_tax**. Bunlar sözleşme, puantaj, ek ödeme, kesinti ve o ayki oranlardan JOIN'lerle yeniden hesaplanabilirdi; ama (1) bordro yasal bir snapshot olduğu için oranlar değişse bile o ayın tutarı sabit kalmalı, (2) raporlamada ağır hesap tekrarını önlemek için sakladık. Kontrollü bir denormalizasyondur.

> Madde 9'daki "tek sütunlu PK olduğu için 2NF kesin", "saf 3NF'yiz", türetilmiş gross/net saklama ve Companies'teki tax_number→tax_office gibi normalizasyon iddialarının dürüst sürümleri **Zayıf Noktalar** bölümündedir.

---

## 4. Kısıtlar & İndeksler

**27. Oracle PRIMARY KEY tanımlayınca arka planda ne oluşturur? FK için de aynı mı?**
PK (ve UNIQUE) kısıtı oluşturulduğunda Oracle onu zorlamak için otomatik **benzersiz B-Tree indeksi** yaratır; bu yüzden PK'ler için ayrıca indeks açmadık. Ancak **FOREIGN KEY için Oracle otomatik indeks AÇMAZ**; FK sadece referans bütünlüğünü zorlar. Bu yüzden sık kullanılan FK sütunlarına (örn. `idx_emp_dept`) indeksleri elle açtık.

**28. İndekssiz FK sadece SELECT'i mi etkiler, başka risk var mı?**
İki sorun: (1) JOIN/WHERE'de yavaşlık (full table scan). (2) Daha kritik **kilitlenme**: parent tabloda UPDATE/DELETE yapılırken FK indeksi yoksa Oracle child tabloyu tablo seviyesinde kilitleyebilir (share lock), concurrency düşer ve deadlock (ORA-00060) riski artar. (Birçok FK'de indeks olmaması bu açıdan bir eksiklik — bkz. Zayıf Noktalar.)

**29. national_id'yi neden tek başına UNIQUE değil de (fk_company_id, national_id) bileşik UNIQUE yaptın?**
SaaS multi-tenant sistem; aynı DB'de çok şirket var. TCKN global benzersiz olsa da her şirket kendi personel havuzunu yönetir. Tek başına UNIQUE olsaydı bir TCKN tüm sistemde bir kez girilebilir, bu da tenant'ları birbirine bağlardı. Bileşik UNIQUE ile kural "aynı şirket içinde aynı TCKN iki kez olamaz" olur; izolasyon korunur. Aynı mantıkla `uq_emp_code` de `(fk_company_id, employee_code)`.

**30. İndeks her zaman hızlandırır mı? Ne zaman performansı DÜŞÜRÜR?**
İndeks SELECT'i hızlandırırken yazma işlemlerini (INSERT/UPDATE/DELETE) yavaşlatır, çünkü her satır yazımında ilgili indeksler de güncellenir (N indeks varsa INSERT N+1 yapı günceller). Ayrıca disk tüketir ve optimizer'ın yanlış indeks seçme ihtimalini artırır. Bordro gibi periyodik toplu INSERT yapılan sistemde gereksiz indeks ciddi yavaşlatır; bu yüzden indeksleri yalnız sık SELECT/JOIN edilen sütunlara açtık.

**31. B-Tree indeksi düşük seçicilikli sütunda (is_active 0/1) iyi midir?**
Hayır. B-Tree **yüksek seçicilikli** (çok farklı değerli, örn. ID) sütunlarda verimlidir. is_active gibi düşük cardinality sütunda tablonun yarısı zaten 1 olabilir ve optimizer büyük olasılıkla full table scan tercih eder. Bu tür sütunlar için Oracle'da bitmap indeks uygundur (ama bitmap, sık DML'de kilitleme sorunlu olduğundan OLTP'de önerilmez). Bu yüzden is_active'e indeks açmadık — doğru tercih.

**32. PRIMARY KEY ile UNIQUE farkı nedir? Neden payroll_id PK, (fk_employee_id, period_month, period_year) UNIQUE?**
PK hem benzersizliği zorlar hem NULL'a izin VERMEZ ve tablo başına bir tanedir; UNIQUE benzersizliği zorlar ama (Oracle'da) NULL'a izin verir ve birden çok olabilir. payroll_id surrogate PK seçtik: tek sütunlu, sayısal, değişmez anahtar FK/JOIN için verimlidir. Doğal anahtarı (üçlü) UNIQUE yaptık; PK yapsaydık Payroll_Logs'tan üç sütunlu bileşik FK gerekirdi — hantal. **Surrogate PK + natural UNIQUE** yaygın ve doğru bir desendir.

> CHECK kısıtı eksikliği, indekslenmemiş FK'ler, nullable UNIQUE/NULL etkileşimi, redundant indeksler (idx_att_emp vb.) ve nullable FK + indeks konuları **Zayıf Noktalar** bölümündedir.

---

## 5. PL/SQL Paketler & Prosedürler

**33. Package SPECIFICATION ile BODY farkı nedir? (pkg_payroll_entry üzerinden)**
Specification paketin dışa açık arayüzüdür; sadece prosedür/fonksiyon imzalarını (add_company, add_employee) bildirir. Body bu imzaların gerçek implementasyonunu (INSERT'ler, iş mantığı) barındırır. Bu ayrım sayesinde çağıran yalnızca spec'e bağımlıdır; body değişse bile spec aynı kaldığı sürece bağımlı objeler invalid olmaz, yeniden derleme gerekmez. Arayüz–implementasyon ayrımı encapsulation sağlar.

**34. Neden standalone prosedür yerine 5 PACKAGE kullandın?**
Modülerlik ve encapsulation: ekleme (entry), güncelleme (update), silme (delete), raporlama (reports), bakım (maintenance) işlemlerini mantıksal gruplara ayırdım. Avantajları: (1) İlişkili prosedürler tek isim alanında, okunabilirlik artar; (2) Body değişse bile spec sabit kaldığı için bağımlılık kırılmaz, paket bir kez derlenip bellekte (SGA) tutulur; (3) Private değişken/yardımcı prosedür gizlenebilir; (4) İlk çağrıda tüm paket belleğe yüklenir, sonraki çağrılar hızlanır.

**35. PROCEDURE ile FUNCTION farkı nedir? Neden raporlama FUNCTION, ekleme PROCEDURE?**
Procedure bir işlem yapar, RETURN ile değer döndürmez (gerekirse OUT parametre). Function mutlaka bir değer döndürür (RETURN) ve genelde SELECT içinde de kullanılabilir. Raporlama fonksiyonları çağırana bir SYS_REFCURSOR döndürmesi gerektiği için FUNCTION; ekleme işlemleri yalnızca INSERT yapıp veri durumunu değiştirdiği, dönecek değeri olmadığı için PROCEDURE yapıldı.

**36. IN / OUT / IN OUT parametre modları nedir, neden hep IN kullandın?**
IN değeri içeri alır, içeride salt-okunurdur (varsayılan mod). OUT çağırana değer döndürür, girişte değeri yok sayılır. IN OUT hem alır hem döndürür. Ekleme/güncelleme/silme prosedürlerinin görevi sadece DML olduğu ve dönecek değer olmadığı için hepsini IN yaptım. Eklenen kaydın ID'sini döndürmek isteseydim `p_new_id OUT` eklerdim; raporlamada dönüşü OUT yerine FUNCTION RETURN ile çözdüm.

**37. SQL%ROWCOUNT neyi sayar, niçin kullandın?**
En son çalışan implicit SQL cümlesinin (INSERT/UPDATE/DELETE) etkilediği satır sayısını döndüren bir implicit cursor özniteliğidir. Multi-tenancy güvenliği için kullandım: `update_employee_job`'da hem employee_id hem fk_company_id eşleşmezse hiçbir satır güncellenmez, ROWCOUNT 0 olur ve `RAISE_APPLICATION_ERROR` ile "personel bulunamadı veya bu şirkete ait değil" hatası fırlatırım. Böylece bir şirketin başka şirketin kaydına dokunması sessizce başarılı görünmez.

**38. delete_employee'de silme sırasını neden böyle belirledin (önce child, en sonda Employees)?**
FK kısıtları nedeniyle child kayıtlar parent'tan önce silinmelidir. Employees parent'tır; Attendance_Records, Employee_Contracts, Employee_Allowances, Payroll_Summary ona `fk_employee_id` ile referans verir. Önce Employees'i silmeye çalışsam ORA-02292 (child record found) alırım. Bu yüzden en dipteki child'lardan (Payroll_Logs -> Payroll_Summary -> Allowance/Deduction/Attendance -> Contracts) başlayıp en sonda parent Employees siliyorum. Payroll_Logs, Payroll_Summary'nin de child'ı olduğu için ondan önce silinir.

**39. RAISE_APPLICATION_ERROR'da neden -20001..-20010 aralığı, rastgele -50000 olur muydu?**
Oracle kullanıcı tanımlı hatalar için **-20000 ile -20999** arasını ayırmıştır; RAISE_APPLICATION_ERROR sadece bu aralığı kabul eder, -50000 hata verirdi. Her prosedüre benzersiz bir kod verdim (örn. update_employee_job -20001, contract -20002, attendance -20003, delete_employee -20004) ki çağıran EXCEPTION bloğunda SQLCODE'a bakıp hatanın kaynağını ayırt edip farklı işlem yapabilsin. Sıralı/dokümante numara hata kataloğu oluşturmayı kolaylaştırır.

**40. Spec'te bildirilmeyip sadece BODY'ye yazılan prosedür ne olur?**
PRIVATE (özel) olur; yalnızca aynı paket içinden çağrılabilir, dışarıdan erişilemez. Faydası encapsulation: iç yardımcı mantığı (validasyon/hesaplama) dışa açmadan saklarım, arayüz temiz kalır ve iç implementasyon serbestçe değişebilir. Projede tüm prosedürleri public yaptım ama örneğin ortak "şirket var mı" kontrolünü private prosedüre çıkarıp tüm public prosedürlerden çağırabilirdim — bu kod tekrarını azaltırdı.

**41. Raporlama fonksiyonları neden SYS_REFCURSOR döndürüyor, collection değil?**
SYS_REFCURSOR yapısı önceden tanımlanmamış (weakly typed) bir imleç tipidir; dinamik SQL ile değişen kolon setlerini döndürmek için idealdir. Tüm satırları belleğe toplamadan çağırana bir işaretçi verir, çağıran FETCH ile satır satır okur — büyük sonuç kümelerinde bellek açısından verimli. Ayrıca Java/.NET gibi uygulama katmanına raporu açmak için standart arayüzdür. Collection döndürseydim tüm veriyi PGA'da materialize etmem gerekirdi.

> COMMIT'in paketlerde olmaması, entry'de exception eksikliği, ROWCOUNT'un sadece son DELETE'i ölçmesi ve string concat'lı dinamik SQL gibi konular **Zayıf Noktalar** bölümündedir.

---

## 6. Trigger & Sequence

**42. Trigger nedir, projede neden kullandın? (Madde 7'yi nasıl karşılar)**
Trigger, bir tabloda DML olayında Oracle'ın otomatik çalıştırdığı, isimli bir PL/SQL bloğudur; uygulamadan ayrı, DB seviyesinde iş kuralını garanti eder. İki trigger var: `trg_after_emp_insert` bir personel (Employees) eklenince o personel için sıfır değerli puantaj (Attendance_Records) açar; `trg_payroll_audit` Payroll_Summary üzerindeki her DML'i Payroll_Logs'a yazar. Bu, "tanım tablosuna giriş yapılınca hareket tablosuna otomatik veri" gereğini (Madde 7) tam karşılar.

**43. trg_after_emp_insert neden BEFORE değil AFTER INSERT?**
AFTER seçtim çünkü Attendance_Records'a eklediğim kaydın `fk_employee_id`'si Employees'e FK ile bağlı. Satır Employees'e fiziksel yazılıp PK'sı kesinleşmeden ona referans veren kayıt eklemek mantıken risklidir. AFTER ROW seviyesinde `:NEW.employee_id` garanti hazırdır. BEFORE'ı asıl `:NEW` kolonlarını değiştirmek/doğrulamak istediğimde kullanırdım; bir yan etki üretiyorsam doğru semantik AFTER'dır.

**44. FOR EACH ROW yazmasaydın ne olurdu? ROW-level vs STATEMENT-level?**
FOR EACH ROW trigger'ı etkilenen HER satır için bir kez çalıştırır ve `:NEW`/`:OLD`'a erişim verir. Yazmazsam STATEMENT-level olur: ifade kaç satır etkilerse etkilesin trigger bir kez çalışır ve :NEW/:OLD'a erişemem. Her iki trigger'ım satır bazlı veri taşıdığı için (her personele bir puantaj, her bordro satırına bir log) ROW-level zorunludur. Tek INSERT ile 10 personel eklersem 10 ayrı puantaj gerekir; STATEMENT-level bunu yapamaz.

**45. :NEW ve :OLD ne zaman dolu olur? Audit trigger'da neden DELETE'te :OLD, INSERT/UPDATE'te :NEW?**
`:NEW` satırın işlemden sonraki, `:OLD` önceki halidir. INSERT'te :OLD boştur, sadece :NEW dolu; DELETE'te :NEW boştur, sadece :OLD dolu; UPDATE'te ikisi de dolu. Bu yüzden INSERT/UPDATE dalında payroll_id'yi `:NEW`'den, DELETE dalında satır silindiği için `:OLD`'dan alıyorum. DELETE'te :NEW kullansaydım NULL gelir ve hangi bordronun silindiğini kaybederdim.

**46. INSERTING / UPDATING / DELETING belirteçleri nedir, tek trigger'da üç olayı yönetmenin avantaj/dezavantajı?**
Birden çok olaya bağlı trigger içinde o an hangi olayın tetiklendiğini söyleyen Boolean belirteçlerdir. Audit trigger'da `IF INSERTING / ELSIF UPDATING / ELSIF DELETING` ile action_type'ı ve hangi bind değişkenini kullanacağımı belirliyorum. **Avantaj**: tek noktada audit mantığı, kod tekrarı yok, bakım kolay. **Dezavantaj**: blok büyür ve her DML'de dallar değerlendirilir; çok farklı davranışlar olsaydı ayrı trigger'lar okunabilirliği artırabilirdi.

**47. MUTATING TABLE hatası nedir, bu trigger'larda risk var mı?**
Mutating table (ORA-04091): bir ROW-level trigger'ın, tetiklendiği DML'in o an değiştirmekte olduğu tabloyu okumaya/yazmaya çalışmasıdır; Oracle tutarlılık için izin vermez. Benim trigger'larımda risk YOK çünkü ikisi de farklı tabloya yazar: `trg_after_emp_insert` Employees'te tetiklenir ama Attendance_Records'a yazar; `trg_payroll_audit` Payroll_Summary'de tetiklenir ama Payroll_Logs'a yazar. Mutating hatası, Employees trigger'ı içinde tekrar Employees'i SELECT etseydim oluşurdu.

**48. Sequence nedir, NEXTVAL/CURRVAL farkı nedir?**
Sequence, eşzamanlı ortamda bile çakışmayan benzersiz sayılar üreten bir DB nesnesidir. `NEXTVAL` bir sonraki değeri üretip ilerletir; `CURRVAL` aynı oturumda en son NEXTVAL ile üretilen değeri tekrar döndürür (oturumda önce NEXTVAL çağrılmadan kullanılamaz). Trigger'ların ürettiği `attendance_id` ve `log_id` sistemce otomatik üretildiği için `seq_attendance_id` ve `seq_payroll_log_id` ile NEXTVAL kullanmak gerekli ve doğrudur. (Tüm tablolarda neden sequence değil — bkz. Zayıf Noktalar.)

**49. Sequence'leri neden START WITH 10000 / 1000 ile başlattın?**
Teknik zorunluluk değil, okunabilirlik/ayırt edilebilirlik tercihi. Yüksek ve farklı başlangıçlar (attendance 10000, log 1000) ID'ye bakar bakmaz hangi tabloya ait olduğunu sezdirir ve manuel girdiğim küçük test ID'leriyle (1,2,3) karışmasını önler. INCREMENT BY 1 ile artıyor; istenirse NOCACHE/CACHE, MAXVALUE eklenebilirdi, varsayılan CACHE 20 ile gidiyorum.

**50. trg_after_emp_insert içindeki INSERT, uq_attendance_period'u ihlal ederse ne olur? Employees insert'ini etkiler mi?**
Trigger içindeki INSERT, Attendance_Records'taki UNIQUE'i (fk_employee_id, record_month, record_year) ihlal ederse ORA-00001 fırlar. Trigger ile onu tetikleyen DML aynı transaction içinde olduğundan, yakalanmayan exception tüm ifadeyi geri alır; yani asıl Employees INSERT'i de rollback olur. Şu an trigger'da EXCEPTION bloğu yok, hata yukarı propagate olur. Bu çoğu durumda istenen atomikliktir; istesem trigger'da DUP_VAL_ON_INDEX'i yakalayıp puantajı atlayabilirdim.

**51. Payroll_Logs'ta fk_payroll_id'ye neden FK yok, bordro DELETE edilince trg_payroll_audit ne yazar?**
Bilinçli olarak FK koymadım (constraints dosyasında not düştüm). Audit log kalıcı bir kanıt tablosudur; kaynak bordro silinse bile INSERT/UPDATE/DELETE geçmişi durmalı. FK olsaydı bir bordro silinirken trigger DELETE logunu yazmaya çalışır ama o payroll_id artık silinmek üzere olduğundan ve eski loglar da ona referans verdiğinden FK ihlali (ORA-02292) oluşurdu. Yani audit = kalıcı/immutable, kaynak = mutable; ikisini FK ile bağlamak audit amacını bozar.

> SYSDATE'ten dönem alınması, fk_user_id'nin NULL geçilmesi ve trigger/manuel-ID tutarsızlığı **Zayıf Noktalar** bölümündedir.

---

## 7. Dinamik SQL, Raporlama & Güvenlik

**52. SYS_REFCURSOR nedir, raporlar neden tablo/koleksiyon yerine bunu döndürüyor?**
SYS_REFCURSOR, sorgu sonuç kümesine işaret eden, önceden RETURN tipiyle bağlanmamış (weakly typed) bir cursor tipidir. Çalışma zamanında hangi sorgunun çalışacağı belli olmadığı (filtreye göre SELECT değişiyor) için kullanılır. Fonksiyon sonucu açık bir imleç olarak çağırana döner, çağıran FETCH ile satırları gezer, veriyi tamamen belleğe almayız.

**53. EXECUTE IMMEDIATE ile OPEN FOR farkı nedir, neden OPEN FOR?**
EXECUTE IMMEDIATE tek seferlik DDL/DML veya tek satır/skaler işlemler içindir; sonucu INTO ile değişkene alır. OPEN FOR bir SELECT'i cursor'a bağlayıp çok satırlı sonucu çağırana açmak içindir. Raporlar çok satır döndürüp imleci dışarıya RETURN ettiği için `OPEN ... FOR v_sql` doğru seçimdir; EXECUTE IMMEDIATE ile bir REF CURSOR'ı çağırana döndüremezdim.

**54. Madde 8'deki dinamik WHERE kriterini nasıl sağladın, filtre NULL gelince ne olur?**
Temel sorguyu sabit gövde olarak kuruyorum (şirket kısıtı ve `is_active=1` her zaman var). Opsiyonel parametreleri IF ile kontrol ediyorum: `p_department_id IS NOT NULL` ise v_sql'e `AND e.fk_department_id = ...` ekliyorum; aynısı job_title için. Parametre NULL gelince o AND koşulu hiç eklenmez, filtre uygulanmaz. Yani opsiyonel filtreyi WHERE'e koşul ekleyip eklememe yoluyla sağlıyorum.

**55. v_sql'i neden VARCHAR2(4000) tanımladın, çok filtre eklenseydi ne olurdu?**
VARCHAR2(4000) makul ama sabit bir üst sınır. Bu raporlarda sorgu kısa olduğu için yeterli, ancak çok filtre/uzun IN listesi eklenirse 4000 aşılıp ORA-06502 (buffer too small) alınır. Önlem: PL/SQL içinde VARCHAR2 değişkeni 32767'ye (32KB) kadar genişler; ayrıca dinamik parçaları bind variable'a çıkarmak metni kısaltır. En sağlamı sınırı bilinçli seçmek ve filtre sayısını kontrol altında tutmaktır.

**56. NUMBER parametrede injection zorsa bind variable'ın başka faydası ne?**
İki ana fayda: (1) **Performans/ölçeklenebilirlik** — değerleri metne gömünce her farklı şirket/dönem için SQL metni değişir, Oracle her seferinde hard parse yapar ve shared pool'u (library cache) farklı cursor'larla şişirir; bind ile SQL metni sabit kalır, tek paylaşılan cursor soft parse ile tekrar kullanılır. (2) **Geleceğe dönük güvenlik** — bugün NUMBER olsa bile yarın VARCHAR2 filtre eklenirse bind kullanan kod hala güvenli kalır, concatenation o gün açığa döner. Bind, doğru varsayılan yaklaşımdır.

**57. get_monthly_payroll'u bind variable ile güvenli nasıl yazardın?**
Değerleri `||` ile gömmek yerine SQL'e placeholder koyup `OPEN FOR ... USING` ile bind ederim. Örnek: `v_sql := 'SELECT ... WHERE p.fk_company_id = :cid AND p.period_month = :m AND p.period_year = :y'`; opsiyonel için `AND p.fk_employee_id = :eid` eklerim. Sonra `OPEN v_cursor FOR v_sql USING p_company_id, p_period_month, p_period_year[, p_employee_id]`. Kritik kural: bind sayısı ve sırası placeholder sırasıyla birebir eşleşmeli. Böylece girdi veri olarak yorumlanır, asla SQL kodu çalışmaz; ayrıca soft parse ile performans kazanılır.

> String concat'lı dinamik SQL (SQL injection), sabit `'HASHED_PWD'` parolası, multi-tenant company_id doğrulamasının yapılmaması ve Tax_Slabs'ın hiç okunmaması (ölü tablo) gibi kritik konular **Zayıf Noktalar** bölümündedir.

---

## 8. Mükerrer Kayıt Temizliği & ROWID

**58. ROWID nedir, dedup'ta neden PK yerine ROWID ile ayırt ediyorsun?**
ROWID bir satırın diskteki fiziksel adresidir (data object number + datafile + block + row number) ve erişimin en hızlı yoludur. Dedup'ta ROWID kullanırım çünkü business key'i (örn. fk_company_id + username) aynı olan iki satırı ayıracak başka garantili kolon yok; PK manuel atandığı için iki kopya farklı PK'lere sahip olabilir. ROWID her satır için kesin benzersiz olduğundan `MIN(rowid)` ile gruptaki ilk fiziksel kopyayı tutup gerisini silebiliyorum.

**59. ROWID ile ROWNUM farkı nedir, dedup'ı ROWNUM ile yapabilir miydin?**
ROWID satırın kalıcı fiziksel adresidir, satır var oldukça (taşınmadıkça) sabittir ve satırı tek başına tanımlar. ROWNUM ise sorgu çalışırken sonuç kümesine atanan geçici sıralı sözde-kolondur (1,2,3...); aynı satır farklı sorgularda farklı ROWNUM alabilir, hatta WHERE aşamasında ORDER BY'dan önce atanır. Bu yüzden "gruptaki ilkini tut" mantığını güvenilir kuramazdım; bunu sağlayan tek şey ROWID'dir. ROWNUM dedup'ta değil sayfalama/limitlemede işe yarar.

**60. DELETE ... WHERE rowid NOT IN (SELECT MIN(rowid) ... GROUP BY business_key) ne yapıyor?**
İç sorgu kayıtları business key'e (örn. Users'ta fk_company_id + username) göre gruplar, her grup için en küçük ROWID'yi (`MIN(rowid)`) seçer; yani her benzersiz iş anahtarı için "tutulacak temsilci"yi belirler. Dış DELETE bu listede OLMAYAN (NOT IN) satırları siler. Sonuçta her business key için bir satır kalır. MIN(rowid) keyfi ama deterministik bir seçimdir.

**61. UNIQUE constraint'ler varken bu temizlik paketine neden gerek var?**
Normal çalışmada UNIQUE ikinci kopyanın INSERT'ini zaten engeller. Bu paket, constraint'in geçici devre dışı olduğu senaryolar içindir: büyük yüklemelerde (ETL/migration) performans için constraint DISABLE edilir, veri yüklenir, ENABLE edilmek istenir; kaynak veride mükerrer varsa ENABLE adımı patlar. O aşamada bu prosedürle önce kopyalar temizlenip constraint tekrar geçerli kılınır. Ayrıca eski/legacy verinin aktarıldığı veya constraint'in hiç tanımlanmadığı dönemden kalma kirli kayıtların tek seferlik temizliği içindir.

**62. Companies dedup'unda neden WHERE tax_number IS NOT NULL?**
tax_number NULL olabilir. NULL'ı gerçek değer gibi gruplamak istemiyorum: vergi numarası girilmemiş iki ayrı şirket aynı "NULL grubu"nda toplanıp mükerrer sanılabilir ve biri yanlışlıkla silinebilir. Bu yüzden hem DELETE'in WHERE'inde hem iç sorguda `tax_number IS NOT NULL` diyorum. Ek güvence: NOT IN listesinde NULL olsaydı üç değerli mantık nedeniyle hiç satır silinmeyebilirdi; IS NOT NULL bu tuzağı da bertaraf eder.

**63. Prosedür sonunda tek COMMIT, hatada tek ROLLBACK. 15 silmeden 8'incisi patlarsa önceki 7 tablo ne olur?**
Tüm 15 DELETE tek transaction içinde, arada COMMIT yok. Bu "ya hep ya hiç" (atomik) davranış sağlar: 8. silme patlarsa EXCEPTION'daki ROLLBACK önceki 7'yi de geri alır, hiçbir tablo değişmez. İstenen özelliktir; yarım kalmış tutarsız temizlik bırakmaz. Alternatifi her tablodan sonra COMMIT olurdu ki hata anında kısmi temizlik bırakırdı. Akademik proje boyutunda atomik yaklaşım daha güvenli.

> Yalnızca 3 tabloda destekleyici UNIQUE olması, WHEN OTHERS'ın hata lokalizasyonunu kaybetmesi, Payroll_Logs'ta timestamp tabanlı yanlış dedup ve dedup sırasında re-parenting yapılmaması **Zayıf Noktalar** bölümündedir.

---

## ⚠️ Dikkat: Kodundaki Zayıf Noktalar (Hoca Buraya Yüklenebilir)

> Bu sorular, kodda gerçek bir zayıflık veya gizli varsayım içerir. Hepsinde **savunma stratejisi aynıdır: zayıflığı dürüstçe kabul et, NEDEN'ini doğru gerekçelendir ve doğru çözümü göster.** "Sorun yok / her şey güvenli" gibi aşırı genelleme yapma.

### Z1. Employees → Employee_Contracts ilişkisi şemada 1:1 zorlanıyor mu?
**Zayıflık:** Employee_Contracts'ta `fk_employee_id` üzerinde UNIQUE yok (yalnızca `fk_cont_emp` FK'si var). Dolayısıyla aynı çalışana birden fazla sözleşme girilebilir; ilişki fiilen 1:N'dir. Maintenance paketinin mükerrer sözleşme temizlemesi de bunu doğruluyor. Ayrıca `update_contract_salary`'deki `UPDATE ... WHERE is_active=1` birden çok aktif satırı sessizce günceller (ROWCOUNT 2 döner ama başarı sayılır).
**Dürüst savunma:** "1:1 yalnızca iş kuralı/niyet seviyesinde; şema bunu zorlamıyor, bu bir eksiklik. Gerçek 1:1 için ya `fk_employee_id`'ye UNIQUE koymalı ya da aktif sözleşmeler için fonksiyon-bazlı/koşullu unique indeks kullanmalıydım: `CREATE UNIQUE INDEX uq_active_contract ON Employee_Contracts (CASE WHEN is_active=1 THEN fk_employee_id END)`." "FK var, yeter" demek bu açığı kapatmaz.

### Z2. uq_payroll_period'a fk_company_id dahil edilmemiş — multi-tenant hata mı?
**Zayıflık (aslında açık DEĞİL ama gizli varsayıma dayanır):** UNIQUE `(fk_employee_id, period_month, period_year)` şeklinde, fk_company_id yok.
**Dürüst savunma:** "Açık yok, çünkü `employee_id` global surrogate'tir; bir employee_id tek bir şirkete ait olduğundan tekillik korunur. Ancak bu, tasarımın gizli bir varsayıma (global tekil employee_id) dayandığını kabul etmek demektir. employee_id şirket bazında resetlense fk_company_id'yi UNIQUE'e eklemek şart olurdu." Sadece "gerek yok / unuttum" demek yetersizdir; NEDEN güvenli olduğunu gerekçelendir.

### Z3. Madde 9: "Tek sütunlu PK olduğu için 2NF kesin" argümanı
**Zayıflık:** Normalizasyon birincil anahtara göre değil TÜM aday anahtarlara göre kontrol edilir. Tek sütunlu surrogate PK kısmi bağımlılığı "gizler", kanıtlamaz.
**Dürüst savunma:** "Surrogate key normalizasyon seviyesini yükseltmez; sadece kısmi bağımlılık ihtimalini maskeler. Doğru ispat doğal/aday anahtarlara göre yapılır. Benim Payroll_Summary ve Attendance_Records'ta doğal aday anahtar bileşiktir (`uq_payroll_period`, `uq_attendance_period`); gross_salary/worked_days bu üçlünün tamamına bağlı olduğu için 2NF yine sağlanıyor — ama gerekçem 'tek sütunlu PK' değil 'bileşik aday anahtara göre kontrol' olmalı."

### Z4. Payroll_Summary'de türetilmiş gross/net/total_tax saklamak 3NF ihlali mi?
**Zayıflık:** gross/net/total_tax sözleşme, puantaj, ek ödeme, kesinti ve vergi dilimlerinden hesaplanabilen türetilmiş değerlerdir; saklamak katı 3NF açısından bir denormalizasyondur. Doküman "saf 3NF'yiz" derken bunu tartışmıyor. Ayrıca `net = gross - tax - kesinti` ilişkisini zorlayan CHECK yok; biri total_tax'ı UPDATE edip net'i güncellemezse tutarsızlık oluşur ve hiçbir kısıt yakalamaz.
**Dürüst savunma:** "Bu bilinçli bir denormalizasyon. Bordro yasal bir **snapshot** olduğu için oranlar sonradan değişse bile o ayın değeri donmalı; bu yüzden hesaplama anındaki durumu sakladım. Saf akademik 3NF açısından denormalizasyondur; 'temporal snapshot + audit + hesaplama maliyeti' gerekçesiyle bilinçli tercih ettim. 'Tamamen 3NF'yiz' yerine 'kontrollü denormalizasyon yaptık' demek daha güçlü ve dürüst. İdeal olarak bir `CHECK (net_salary = gross_salary - total_tax - ...)` veya tek giriş noktası ile korumalıydım."

### Z5. Companies'te gizli geçişli bağımlılık: tax_number → tax_office
**Zayıflık:** Türkiye'de bir vergi numarası tek bir vergi dairesini belirler; `tax_number -> tax_office` bir FD ise ve tax_number aday anahtar değilse (PK company_id), bu teorik bir 3NF zayıflığıdır. Doküman bunu tartışmıyor.
**Dürüst savunma:** "FD'nin varlığını kabul ediyorum. Pratikte her şirkette tek bir tax_number/tax_office olduğu için redundancy doğmuyor; bu yüzden Companies içinde tuttuk. Saf teoride normalize etmek için `Tax_Offices` referans tablosu açıp tax_number'ı ona bağlamak gerekirdi. Maliyet/fayda gerekçesiyle ayırmadık — bu küçük ve bilinçli bir kabuldür. 'Hiçbir tabloda geçişli bağımlılık yok' iddiasını mutlak doğru gibi savunmamak gerekir."

### Z6. FK sütunlarında indeks eksikliği
**Zayıflık:** Yalnızca 4 FK indeksi var (idx_emp_dept, idx_emp_job, idx_att_emp, idx_payroll_emp). Tüm `fk_company_id`'ler, `Employee_Contracts.fk_employee_id`, Allowance/Deduction'ların fk'leri, `Payroll_Logs.fk_user_id` indekssizdir. Oracle FK'ye otomatik indeks açmaz.
**Dürüst savunma:** "Performans-kritik gördüğüm FK'leri indeksledim; geri kalanını veri hacmi/erişim deseni düşük varsayımıyla indekslemedim. Ancak özellikle **sık silinen parent'lar** için bu indekslenmeliydi; aksi halde parent UPDATE/DELETE'inde child tablo seviye kilidi (share lock) ve deadlock riski doğar. 'Tüm FK'leri indeksledim' demek yanlış olur."

### Z7. Nullable national_id / employee_code + bileşik UNIQUE
**Zayıflık:** `national_id VARCHAR2(11)` ve `employee_code VARCHAR2(30)` NOT NULL DEĞİL. Oracle'da bileşik UNIQUE indekste sütunlardan en az biri NULL ise o satır benzersizlik kontrolüne girmez. Yani iki personel de `national_id=NULL` ile girilebilir; `uq_emp_national_id` mükerreri engellemez.
**Dürüst savunma:** "Bu bir tasarım eksiği. İş kuralı 'her personelin TCKN'si olmalı' ise `national_id NOT NULL` yapılmalıydı; ek olarak `CHECK (LENGTH(national_id)=11 AND REGEXP_LIKE(national_id,'^[0-9]+$'))` ile format da zorlanmalıydı. 'Kısıt her durumda mükerrerliği engelliyor' demek yanlış olur."

### Z8. Redundant indeksler (idx_att_emp, idx_payroll_emp)
**Zayıflık:** `uq_attendance_period` leading sütunu `fk_employee_id`; `idx_att_emp` da yalnızca `fk_employee_id`. B-Tree leftmost-prefix kuralı gereği UNIQUE indeksin sol-öneki zaten `WHERE fk_employee_id = X` sorgularını karşılar. Aynı durum `uq_payroll_period` ile `idx_payroll_emp` arasında da var.
**Dürüst savunma:** "Garantici davrandım ama bu indeksler büyük olasılıkla gereksiz tekrar; UNIQUE indeksinin leading sütunu zaten fk_employee_id sorgularını karşılıyor. Bu fazlalık INSERT maliyetini ve disk alanını boşuna artırıyor; kaldırılabilir."

### Z9. Hiç CHECK kısıtı yok (domain bütünlüğü)
**Zayıflık:** 01_create_tables.sql ve 02_constraints_indexes.sql'de TEK BİR CHECK yok. `record_month` 13/99 olabilir, `is_active` 5 olabilir, `worked_days`/`overtime_hours`/`tax_rate`/`salary_multiplier` negatif olabilir, `marital_status`/`payment_status`/`role` serbest metin.
**Dürüst savunma:** "Domain bütünlüğünü DB seviyesinde zorlamadım; doğrulamayı PL/SQL paketlerine bıraktım, bu bir eksiklik çünkü bütünlüğün ilk savunma hattı DB kısıtı olmalı. İdeali: `CHECK (record_month BETWEEN 1 AND 12)`, `CHECK (is_active IN (0,1))`, `CHECK (worked_days BETWEEN 0 AND 31)`, `CHECK (tax_rate >= 0)`, `marital_status` için CHECK IN (...) veya referans tablo. Bunu iyileştirme olarak ekleyebilirim. 'Her şey kısıtlarla korunuyor' demek yanlış olur."

### Z10. delete_employee'de SQL%ROWCOUNT yalnızca son DELETE'i ölçer
**Zayıflık:** Prosedürde 6 ardışık DELETE var ama `IF SQL%ROWCOUNT = 0` yalnızca en sonki Employees DELETE'ini ölçer.
**Dürüst savunma:** "Bilinçli olarak Employees DELETE'ini en sona koydum; asıl varlık kontrolü odur, personel yoksa veya company_id yanlışsa 0 döner ve hata fırlatırım — bu doğru çalışıyor. Ama tasarımın zayıflığı: ara silmelerin başarısını ayrı doğrulamıyor ve DELETE sırasına bağımlı/kırılgan. İdeali, en başta `SELECT COUNT(*) INTO v_count` ile varlık kontrolü yapmaktı; o zaman niyet kodda net görünürdü. 'Her DELETE'i sayıyorum / tüm silmeleri kapsıyor' demek yanlış olur."

### Z11. entry/update/delete paketlerinde COMMIT yok, maintenance'ta var
**Zayıflık:** Transaction kontrolü tutarsız: entry/update/delete COMMIT içermez, maintenance içerir.
**Dürüst savunma:** "Bu bilinçli 'caller controls transaction' desenidir: add_employee + add_contract + add_payroll'u tek atomik iş olarak çağırıp sonunda bir kez COMMIT etmek isterim; her prosedür kendi COMMIT'ini yapsaydı atomikliği kaybederdim. `remove_all_duplicates` bağımsız bir bakım işi olduğu için kendi atomik birimini yönetir. Dürüst eksik: çağıran COMMIT/ROLLBACK yapmazsa kayıt asılı kalır; idealde transaction sınırını net bir wrapper/iş prosedürüyle belgelemeliydim. 'Unuttum' değil, bilinçli ama tutarsız."

### Z12. entry paketinde hiç EXCEPTION bloğu yok
**Zayıflık:** Aynı şirkette aynı TCKN ile ikinci personel eklenince ham `DUP_VAL_ON_INDEX` (ORA-00001) doğrudan çağırana yansır; update/delete'teki RAISE_APPLICATION_ERROR yaklaşımıyla tutarsız.
**Dürüst savunma:** "Hata kaybolmuyor, çağırana ulaşıyor; sessizce yutulmuyor — bu kadarı kabul edilebilir. Ama daha iyisi `DUP_VAL_ON_INDEX`'i yakalayıp `RAISE_APPLICATION_ERROR(-20007, 'Bu TCKN ile zaten personel kayıtlı')` gibi anlamlı bir mesaja çevirmekti. Update/delete tarafında özel hata mesajları ürettim ama entry'de tutarlı uygulamadım; geliştirilebilir bir noktadır."

### Z13. pkg_payroll_reports — string concat ile dinamik SQL (SQL Injection)
**Zayıflık:** `get_employee_report` ve `get_monthly_payroll`, WHERE'i `... || p_company_id || ...` ile kuruyor, hiç bind variable yok. Klasik SQL injection deseni ve gereksiz hard parse.
**Dürüst savunma:** "Kalıp olarak güvensiz. Parametreler NUMBER olduğu için şu an injection vektörü dar (sayı olmayan değer ORA-06502 verir), ama bu tek başına savunma değil: yarın bir VARCHAR2 filtre (isim/departman adı) eklersem kapı açılır. Doğrusu `OPEN cursor FOR v_sql USING ...` ile bind variable kullanmaktı; hem injection'ı keser hem soft parse ile shared pool'u korur. 'NUMBER olduğu için kesinlikle güvenli' demek savunulamaz."

### Z14. add_user'da sabit 'HASHED_PWD' parolası
**Zayıflık:** `password_hash` alanına her kullanıcı için sabit `'HASHED_PWD'` literali yazılıyor; hiçbir hash hesaplanmıyor, parola parametre olarak bile alınmıyor.
**Dürüst savunma:** "Bu bilinçli bir akademik kısayol, prodüksiyona uygun değil. Tüm kullanıcılar aynı 'parolaya' sahip olur, kimlik doğrulama anlamsızlaşır. Doğrusu parolayı parametre alıp yazmadan önce tuzlanmış (salt) güçlü bir algoritmayla hash'lemekti — Oracle bunu `STANDARD_HASH(p_password,'SHA256')` veya `DBMS_CRYPTO.HASH` ile destekliyor; idealde bcrypt/PBKDF2/Argon2. Düz parolayı asla saklamam/loglamam. 'Bu zaten güvenli bir hash' demek yanlış, çünkü değer sabit ve hiç hesaplanmıyor."

### Z15. Multi-tenant raporlarda company_id doğrulanmıyor
**Zayıflık:** Raporlar WHERE'e `fk_company_id = p_company_id` kısıtını her zaman ekliyor (iyi), ama `p_company_id`'nin çağıran kullanıcıya gerçekten ait olduğunu fonksiyon hiç doğrulamıyor; yetkilendirme tamamen çağırana güveniyor.
**Dürüst savunma:** "SQL içinde tenant kısıtı garanti, asla atlanamaz; bu sağlam. Ama fonksiyon gelen company_id'nin doğruluğunu denetlemiyor — yanlış/başkasının company_id'sini geçiren biri o şirketin verisini görür. Gerçek sistemde bunu oturumdan `SYS_CONTEXT` ile alıp **VPD (Virtual Private Database)/RLS** ile zorlardım. 'Tamamen güvenli, kimse başka şirketin verisini göremez' demek yanlış olur."

### Z16. Trigger dönemi SYSDATE'ten alıyor, :NEW.hire_date'ten değil
**Zayıflık:** `trg_after_emp_insert` puantaj dönemini kaydın girildiği andaki SYSDATE'ten (EXTRACT MONTH/YEAR) alıyor. 1 Ocak'ta işe başlayan personel Haziran'da girilirse puantaj Haziran açılır. Ayrıca `uq_attendance_period` nedeniyle aynı personel aynı dönemde tekrar işlenirse ORA-00001 patlar.
**Dürüst savunma:** "Doğru kaynak `:NEW.hire_date` olmalıydı (`EXTRACT(MONTH FROM :NEW.hire_date)`). SYSDATE kullanımı 'sisteme bu ay eklenen personelin bu ayki boş puantajını aç' varsayımına dayanan bilinçli bir sadeleştirme; gerçek zamanlı girişte çalışır ama toplu/geriye dönük (backfill) girişte yanlış dönem üretir ve UNIQUE çakışması riski taşır. Bu kusuru kabul ediyorum."

### Z17. trg_payroll_audit'te fk_user_id NULL geçiliyor (kim yaptı kaybı)
**Zayıflık:** Audit'in en kritik bilgisi "kim yaptı" kayıt edilmiyor; `fk_user_id` NULL geçiliyor ve `fk_log_user` FK'si NULL'a izin verdiği için hata da vermez, sessizce eksik kalır.
**Dürüst savunma:** "Trigger DB seviyesinde çalıştığı için uygulamanın oturum açmış kullanıcısını doğrudan bilmez. Bu tasarımın gerçek zayıflığıdır. Doğrusu: uygulama her oturumda `DBMS_SESSION.SET_CONTEXT` ile application context'e kullanıcıyı yazar, trigger `SYS_CONTEXT` ile okur; ya da DB kullanıcısı için `SYS_CONTEXT('USERENV','SESSION_USER')` kullanılır. Mevcut tasarımda 'kim yaptı' eksik kalıyor — bilinçli ama zayıf bir nokta."

### Z18. Manuel ID atama vs sequence tutarsızlığı (eşzamanlılık)
**Zayıflık:** Sequence yalnızca trigger'larda; ana tablolarda (Companies, Employees, Payroll_Summary) ID'ler uygulama parametresi olarak manuel veriliyor (`add_company(1,...)`). İki oturum aynı anda aynı id'yi verirse ikincisi PK ihlali (ORA-00001) alır.
**Dürüst savunma:** "Manuel ID akademik/öğretici bir tercih; akış kontrolünü göstermek için yaptım. PK çakışmayı engeller (ikinci insert hata alır) ama bu bir çözüm değil — ID üretim sorumluluğunu hatalı biçimde uygulamaya yıkar ve eşzamanlılıkta kırılgandır, ölçeklenmez. Üretimde doğrusu `GENERATED ALWAYS AS IDENTITY` veya `seq_xxx.NEXTVAL` olurdu; sequence değerleri oturumlar arası benzersiz ve kilitsizdir, race condition'ı baştan ortadan kaldırır. Trigger'larda sequence kullanmak ise zorunlu ve doğru. 'PK var, çakışmaz' demek riski örtbas eder."

### Z19. remove_all_duplicates'te WHEN OTHERS hata lokalizasyonunu kaybediyor
**Zayıflık:** Tek `WHEN OTHERS THEN ROLLBACK; RAISE_APPLICATION_ERROR(-20010, '...' || SQLERRM);` bloğu 15 DELETE'i sarıyor. 11. DELETE patlarsa hangi tabloda/adımda olduğu ve orijinal çağrı yığını kaybolur; sadece SQLERRM metni kalır, satır numarası yok. WHEN OTHERS ayrıca NO_DATA_FOUND gibi alakasız hataları da aynı kovaya atar.
**Dürüst savunma:** "ROLLBACK + yeniden RAISE_APPLICATION_ERROR ile 'sessiz yutma'yı kısmen önledim, hata kaybolmuyor. Ama hata lokalizasyonu yok. Daha iyisi: hangi adımda olduğumu tutan bir `v_step` değişkeni mesaja eklemek, `DBMS_UTILITY.FORMAT_ERROR_BACKTRACE` ile yığını korumak ya da çıplak `RAISE;` ile orijinal istisnayı yeniden fırlatmaktı. 'Hata yönetimi yaptım' demek tek başına yeterli savunma değil; yanlış hata yönetimi debug'ı zorlaştırır."

### Z20. Dedup'ta yalnızca 3 tabloda destekleyici UNIQUE var
**Zayıflık:** Paket 15 tablonun tamamı için dedup yapıyor ama UNIQUE yalnızca Employees (uq_emp_national_id, uq_emp_code), Attendance_Records (uq_attendance_period) ve Payroll_Summary (uq_payroll_period)'de var. `Users(fk_company_id, username)`, `Companies(tax_number)`, `Departments(fk_company_id, department_name)` için DB seviyesinde mükerrer engeli YOK.
**Dürüst savunma:** "Bu bir eksiklik. En azından username, tax_number ve department_name için de UNIQUE constraint eklenmeliydi. Dedup paketi tek başına **engelleme** değil **sonradan temizleme** yapar — yani mükerrer kayıt zaten girilmiş olur. İdeali: UNIQUE'lerle önlemek, dedup paketini sadece güvenlik ağı olarak tutmak."

### Z21. Payroll_Logs dedup'unda TIMESTAMP tabanlı yanlış grupla
**Zayıflık:** `action_timestamp` TIMESTAMP (sub-second). Yorumda "aynı saniye içinde aynı log" deniyor ama TIMESTAMP mikrosaniye hassasiyetli olduğundan aynı işlemde üretilen iki log farklı timestamp alıp farklı gruplara düşer; GROUP BY gerçek mükerrerleri kaçırır. Ayrıca audit log'da dedup mantıken tartışmalıdır (append-only/kalıcı olmalı).
**Dürüst savunma:** "Yorum hatalı: TIMESTAMP saniye-altı olduğu için 'aynı saniye' grubu doğru çalışmaz. Gerçekten istenseydi timestamp'i `TRUNC`/saniyeye yuvarlayarak gruplamak gerekirdi. Daha doğrusu, audit log'u dedup dışında bırakmaktı; loglar zaten append-only ve immutable olmalı, mükerrer yazmıyoruz."

### Z22. Dedup parent tablodan silerken re-parenting yapmıyor
**Zayıflık:** Dedup, parent tablolardan (Employees, Companies) mükerrer satır silebiliyor ama child kayıtların re-parenting'ini (korunan satıra taşıma) yapmıyor. Silinecek mükerrer parent'a bağlı child varsa ORA-02292 FK ihlali alınır ve tüm işlem rollback olur — temizlik hiç yapılamaz.
**Dürüst savunma:** "Prosedür FK ihlalinde **güvenli** (atomik rollback) ama **eksik**. Normal işleyişte mükerrerler 'fazlalık kopyalar' olduğu için genelde child bağlanmamış olur; ama teorik risk var. Gerçek migration senaryosunda child referansları korunan satıra taşıyan ek bir re-parenting mantığı gerekirdi. Bunu dürüst bir sınırlama olarak kabul ediyorum."

### Z23. get_employee_report'ta INNER JOIN + is_active=1 yan etkisi
**Zayıflık:** Rapor Employee_Contracts'a `INNER JOIN ... AND c.is_active=1` ile bağlanıyor; aktif sözleşmesi olmayan personel rapora HİÇ gelmez. Ayrıca bir personelin birden çok aktif sözleşmesi olursa (Z1 nedeniyle mümkün) satır çoğalır.
**Dürüst savunma:** "INNER JOIN burada bir filtre etkisi de yaratıyor, bunun farkındayım. 'Çalışan + maaş çarpanı' dökümü istediğimiz için sözleşmesizleri dışarıda tutmak kasıtlıdır. Ama amaç 'tüm personeli, varsa sözleşmesiyle' listelemek olsaydı `LEFT JOIN` kullanmalıydık (sözleşmesiz personelin salary_multiplier'ı NULL döner). Çoklu aktif sözleşmede satır çoğalması Z1'deki UNIQUE eksikliğinin bir yansımasıdır."

### Z24. Tax_Slabs ve Statutory_Parameters hiç okunmuyor ("ölü tablolar") — EN KRİTİK
**Zayıflık:** "Kodu değiştirmeden vergiyi güncelleyebilmek için dinamik tuttuk" denildi, ama hiçbir paket/prosedür Tax_Slabs ya da Statutory_Parameters'tan okuyup hesaplama yapmıyor. `add_payroll` gross/net/total_tax'i hazır parametre olarak alıp olduğu gibi insert ediyor; asıl bordro hesabı sistemde hiç yok, dışarıda yapılıp giriliyor.
**Dürüst savunma:** "Dürüstçe: bordro hesap motoru yazılmadı, bu iki tablo şu an 'ölü' (kullanılmayan) veri yapıları. Şema bunu DESTEKLİYOR ama uygulamasını yazmadım, bu yüzden 'dinamik vergi' argümanı pratikte kanıtlanamıyor. İdeali, `calculate_payroll` gibi bir prosedür yazıp baz maaş × sözleşme çarpanından brütü, sonra Tax_Slabs'tan ilgili dilimi bulup vergiyi, kesintileri düşüp neti hesaplamaktı. Bunu eksiklik olarak kabul ediyorum ve eklenebilir bir geliştirme olarak sunuyorum." Bu, hocanın en çok yükleneceği noktadır; savunmadan önce mümkünse bu fonksiyonu eklemek en güçlü hamledir.

---

**Savunma altın kuralı:** Bir zayıflık sorulduğunda önce **kabul et**, sonra **neden böyle yaptığını / hangi bilinçli tercihi yaptığını açıkla**, en sonda **doğru çözümü göster**. Savunmaya değil dürüstlüğe ve farkındalığa yaslan — "biliyorum, şu sebeple böyle yaptım, üretimde şöyle yapardım" cümlesi her zaman "sorun yok" demekten daha güçlüdür.