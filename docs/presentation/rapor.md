# BORDRO YÖNETİM SİSTEMİ VERİTABANI

**Oracle PL/SQL ile SaaS Mimaride Çok Şirketli Bordro Hizmet Platformu**

---

## Giriş

Bu proje; tek bir şirketin kendi bordrosunu yönettiği klasik bir bordro yazılımı değil, **birden fazla müşteri şirkete aynı anda bordro hizmeti veren bir SaaS (Software as a Service) platformunun veritabanı sistemidir.** Yani projemizin asıl müşterisi çalışan değil, "bordro hesaplamalarını dış kaynak olarak bize emanet eden şirketlerdir".

Bu yapıda, sistemi kullanan her şirket "tenant" (kiracı) olarak adlandırılır. Tüm şirketler tek bir veritabanını paylaşır; ancak her şirketin verisi yalnızca kendisine aittir, başka bir şirket asla bu veriye erişemez. Bu izolasyonu sağlayabilmek için projemizdeki **15 tablonun neredeyse tamamında `fk_company_id` sütunu** bulunmaktadır. Hem her INSERT işlemi bu kolona değer yazar, hem de her SELECT/UPDATE/DELETE işlemi bu kolon ile filtrelenir. Bu mimariye veritabanı literatüründe **Multi-Tenant SaaS Architecture (Shared Database, Shared Schema modeli)** denilmektedir.

**Kullanılan Teknolojiler:**

- **Veritabanı Motoru:** Oracle Database
- **Programlama Dili:** PL/SQL (paket, prosedür, fonksiyon, trigger, dinamik SQL)
- **Modelleme Aracı:** draw.io (Chen Notasyonu ile E-R diyagramı)
- **Versiyon Kontrol:** Git

**Sistemin Genel Özeti:**

| Bileşen | Sayı |
|---------|------|
| Tablo | 15 |
| Birincil Anahtar (PK) | 15 |
| Yabancı Anahtar (FK) | 24 |
| Bileşik UNIQUE Kısıt | 4 |
| Performans İndeksi | 4 |
| PL/SQL Paketi | 5 |
| Trigger | 2 |
| Sequence | 2 |

**Test Verisi:** Sistemimizin test ortamında dört adet müşteri şirket (IMSA, MISA, SIMA, AIMS) tanımlıdır. Her şirkette bir CEO, üç departman, altı unvan ve otuz çalışan bulunur. Toplam 4 şirket × 31 personel = **124 personel** seed verisi ile gerçek bir SaaS senaryosunu simüle etmektedir.

**Tablo Kategorileri:**

- **Tanım Tabloları (8):** `Companies`, `Users`, `Departments`, `Job_Titles`, `Tax_Slabs`, `Statutory_Parameters`, `Allowance_Types`, `Deduction_Types`
- **Ana Entity (1):** `Employees`
- **Hareket Tabloları (4 — Weak Entity):** `Employee_Contracts`, `Attendance_Records`, `Employee_Allowances`, `Employee_Deductions`
- **Sonuç ve Audit (2):** `Payroll_Summary`, `Payroll_Logs`

---

## 1. E-R Diyagramı

Projenin E-R diyagramı **Chen notasyonu** ile çizilmiştir. Chen notasyonu seçilmiştir; çünkü hem entity'leri (dikdörtgen), hem ilişkileri (eşkenar dörtgen), hem de attribute'ları (elips) ayrı şekillerde gösterdiği için akademik bir raporda ilişkilerin görselleştirilmesi açısından **Crow's Foot notasyonundan çok daha açıklayıcıdır.**

**Diyagram İstatistikleri:**

- **Entity Sayısı:** 15 (11 strong entity + 4 weak entity)
- **İlişki Sayısı:** 20
- **Attribute Sayısı:** 93
- **Çizim Aracı:** draw.io (`docs/ER_diagram/payroll_chen_erd.drawio`)

**Kullanılan Notasyon Kuralları:**

| Şekil | Anlam |
|-------|-------|
| Tek çizgili dikdörtgen | Strong Entity (bağımsız var olabilen) |
| Çift çizgili dikdörtgen | Weak Entity (sahibi olmadan var olamayan) |
| Eşkenar dörtgen | Relationship (ilişki) |
| Çift çizgili eşkenar dörtgen | Identifying Relationship (weak entity için) |
| Elips | Attribute |
| Altı çizili elips | Primary Key |
| Kesik çizgili elips | Foreign Key |
| Çift çizgili elips | Multivalued Attribute |
| 1, N, M | Kardinaliteler |

**Önemli İlişkiler ve Kardinaliteleri:**

- `Companies` (1) ─ owns ─ (N) `Users` / `Departments` / `Job_Titles` / `Employees` / ... → SaaS izolasyonu için merkezdeki tablo
- `Employees` (1) ─ has ─ (1) `Employee_Contracts` → 1:1 (her aktif personel bir aktif sözleşmeye sahiptir)
- `Employees` (1) ─ has ─ (N) `Attendance_Records` → 1:N (her personel için her ay bir puantaj)
- `Employees` (M) ─ receives ─ (N) `Allowance_Types` → M:N junction = `Employee_Allowances`
- `Employees` (M) ─ subjected_to ─ (N) `Deduction_Types` → M:N junction = `Employee_Deductions`
- `Employees` (1) ─ generates ─ (N) `Payroll_Summary` → 1:N (her personel her ay için bir bordro)
- `Payroll_Summary` (1) ─ logged_to ─ (N) `Payroll_Logs` → 1:N (audit log için)
- `Departments` (1) ─ employs ─ (N) `Employees`
- `Job_Titles` (1) ─ classifies ─ (N) `Employees`

**Diyagram Görseli:** `docs/ER_diagram/payroll_chen_erd.drawio.png`

---

## 2. Tablo Oluşturma Kodları

Sistem 15 tablodan oluşur. Aşağıda her tablonun amacı kısa açıklaması ve tüm `CREATE TABLE` kodları yer almaktadır.

**Veri Tipi Tercihleri:**

- `NUMBER(15,2)` → tüm para alanları (15 hane, 2 ondalık)
- `NUMBER(1)` → boolean yerine (Oracle'da yerleşik BOOLEAN tipi DML'de kullanılamaz; 1 = true, 0 = false)
- `TIMESTAMP DEFAULT CURRENT_TIMESTAMP` → log zamanı için (otomatik kayıt)
- `VARCHAR2` → tüm metin alanları (`CHAR` yerine; depolama açısından daha verimlidir)

```sql
-- 1. Companies — SaaS müşteri şirketleri
CREATE TABLE Companies (
    company_id NUMBER,
    company_name VARCHAR2(150) NOT NULL,
    tax_office VARCHAR2(100),
    tax_number VARCHAR2(20),
    contact_person VARCHAR2(100),
    contact_phone VARCHAR2(20),
    contact_email VARCHAR2(100),
    address VARCHAR2(500)
);

-- 2. Users — Sisteme giriş yapan kullanıcılar
CREATE TABLE Users (
    user_id NUMBER,
    fk_company_id NUMBER NOT NULL,
    username VARCHAR2(50) NOT NULL,
    password_hash VARCHAR2(255) NOT NULL,
    email VARCHAR2(100),
    role VARCHAR2(30)
);

-- 3. Departments — Şirket içi departman tanımları
CREATE TABLE Departments (
    department_id NUMBER,
    fk_company_id NUMBER NOT NULL,
    department_name VARCHAR2(100) NOT NULL
);

-- 4. Job_Titles — Şirket içi unvanlar ve baz maaşlar
CREATE TABLE Job_Titles (
    job_title_id NUMBER,
    fk_company_id NUMBER NOT NULL,
    title_name VARCHAR2(100) NOT NULL,
    min_base_salary NUMBER(15, 2)
);

-- 5. Employees — Çalışan ana tablosu
CREATE TABLE Employees (
    employee_id NUMBER,
    fk_company_id NUMBER NOT NULL,
    fk_department_id NUMBER NOT NULL,
    fk_job_title_id NUMBER NOT NULL,
    employee_code VARCHAR2(30),
    national_id VARCHAR2(11),
    first_name VARCHAR2(50) NOT NULL,
    last_name VARCHAR2(50) NOT NULL,
    birth_date DATE,
    marital_status VARCHAR2(20),
    children_count NUMBER(2) DEFAULT 0,
    hire_date DATE NOT NULL
);

-- 6. Employee_Contracts — Maaş sözleşmeleri (weak entity, 1:1 Employees)
CREATE TABLE Employee_Contracts (
    contract_id NUMBER,
    fk_employee_id NUMBER NOT NULL,
    fk_company_id NUMBER NOT NULL,
    salary_multiplier NUMBER(5, 4) DEFAULT 1.0,        -- Örn: 1.10 = %10 zam
    additional_fixed_salary NUMBER(15, 2) DEFAULT 0,
    contract_start_date DATE NOT NULL,
    contract_end_date DATE,
    is_active NUMBER(1) DEFAULT 1                       -- 1=Aktif, 0=Pasif
);

-- 7. Tax_Slabs — Vergi dilimleri (fk_company_id NULL ise global dilim)
CREATE TABLE Tax_Slabs (
    slab_id NUMBER,
    fk_company_id NUMBER,
    min_income NUMBER(15, 2) NOT NULL,
    max_income NUMBER(15, 2),
    tax_rate NUMBER(5, 2) NOT NULL
);

-- 8. Statutory_Parameters — SGK ve yasal oranlar
CREATE TABLE Statutory_Parameters (
    param_id NUMBER,
    fk_company_id NUMBER,
    param_name VARCHAR2(100) NOT NULL,
    rate NUMBER(5, 4) NOT NULL,
    effective_date DATE NOT NULL
);

-- 9. Allowance_Types — Ek ödeme türleri (Yemek, Bonus, Yakacak, vb.)
CREATE TABLE Allowance_Types (
    allowance_type_id NUMBER,
    fk_company_id NUMBER NOT NULL,
    allowance_name VARCHAR2(100) NOT NULL,
    is_taxable NUMBER(1) DEFAULT 1
);

-- 10. Deduction_Types — Kesinti türleri (İcra, Sendika aidatı, vb.)
CREATE TABLE Deduction_Types (
    deduction_type_id NUMBER,
    fk_company_id NUMBER NOT NULL,
    deduction_name VARCHAR2(100) NOT NULL
);

-- 11. Attendance_Records — Aylık puantaj (weak entity)
CREATE TABLE Attendance_Records (
    attendance_id NUMBER,
    fk_employee_id NUMBER NOT NULL,
    fk_company_id NUMBER NOT NULL,
    record_month NUMBER(2) NOT NULL,
    record_year NUMBER(4) NOT NULL,
    worked_days NUMBER(4, 1) DEFAULT 0,
    overtime_hours NUMBER(5, 1) DEFAULT 0
);

-- 12. Employee_Allowances — Personele aylık ek ödemeler (junction, weak)
CREATE TABLE Employee_Allowances (
    emp_allowance_id NUMBER,
    fk_employee_id NUMBER NOT NULL,
    fk_company_id NUMBER NOT NULL,
    fk_allowance_type_id NUMBER NOT NULL,
    amount NUMBER(15, 2) NOT NULL,
    payment_date DATE NOT NULL
);

-- 13. Employee_Deductions — Personele aylık kesintiler (junction, weak)
CREATE TABLE Employee_Deductions (
    emp_deduction_id NUMBER,
    fk_employee_id NUMBER NOT NULL,
    fk_company_id NUMBER NOT NULL,
    fk_deduction_type_id NUMBER NOT NULL,
    amount NUMBER(15, 2) NOT NULL,
    deduction_date DATE NOT NULL
);

-- 14. Payroll_Summary — Aylık bordro özeti (sonuç tablosu)
CREATE TABLE Payroll_Summary (
    payroll_id NUMBER,
    fk_employee_id NUMBER NOT NULL,
    fk_company_id NUMBER NOT NULL,
    period_month NUMBER(2) NOT NULL,
    period_year NUMBER(4) NOT NULL,
    gross_salary NUMBER(15, 2) NOT NULL,
    net_salary NUMBER(15, 2) NOT NULL,
    total_tax NUMBER(15, 2) NOT NULL,
    payment_status VARCHAR2(30),
    payment_date DATE
);

-- 15. Payroll_Logs — Audit log tablosu (trigger ile otomatik dolar)
CREATE TABLE Payroll_Logs (
    log_id NUMBER,
    fk_payroll_id NUMBER NOT NULL,
    fk_company_id NUMBER NOT NULL,
    fk_user_id NUMBER,
    action_type VARCHAR2(50) NOT NULL,
    action_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

---

## 3. İndeksler ve Anahtar Kısıtları

Tablolar oluşturulduktan sonra, hem **veri bütünlüğünü** garanti altına almak hem de **sorgu performansını** artırmak için üç katmanlı bir indeks/kısıt yapısı kurulmuştur:

1. **Primary Key (15 adet)** — her tablonun benzersiz kayıt tanımlayıcısı
2. **Foreign Key (24 adet)** — tablolar arası referans bütünlüğü
3. **Bileşik UNIQUE (4 adet)** — iş mantığı kuralları için tekillik garantisi
4. **Performans İndeksi (4 adet)** — sık yapılan JOIN ve filter işlemleri için

### 3.1. Birincil Anahtarlar

```sql
ALTER TABLE Companies            ADD CONSTRAINT pk_companies        PRIMARY KEY (company_id);
ALTER TABLE Users                ADD CONSTRAINT pk_users            PRIMARY KEY (user_id);
ALTER TABLE Departments          ADD CONSTRAINT pk_departments      PRIMARY KEY (department_id);
ALTER TABLE Job_Titles           ADD CONSTRAINT pk_job_titles       PRIMARY KEY (job_title_id);
ALTER TABLE Employees            ADD CONSTRAINT pk_employees        PRIMARY KEY (employee_id);
ALTER TABLE Employee_Contracts   ADD CONSTRAINT pk_contracts        PRIMARY KEY (contract_id);
ALTER TABLE Tax_Slabs            ADD CONSTRAINT pk_tax_slabs        PRIMARY KEY (slab_id);
ALTER TABLE Statutory_Parameters ADD CONSTRAINT pk_stat_params      PRIMARY KEY (param_id);
ALTER TABLE Allowance_Types      ADD CONSTRAINT pk_allowance_types  PRIMARY KEY (allowance_type_id);
ALTER TABLE Deduction_Types      ADD CONSTRAINT pk_deduction_types  PRIMARY KEY (deduction_type_id);
ALTER TABLE Attendance_Records   ADD CONSTRAINT pk_attendance       PRIMARY KEY (attendance_id);
ALTER TABLE Employee_Allowances  ADD CONSTRAINT pk_emp_allowances   PRIMARY KEY (emp_allowance_id);
ALTER TABLE Employee_Deductions  ADD CONSTRAINT pk_emp_deductions   PRIMARY KEY (emp_deduction_id);
ALTER TABLE Payroll_Summary      ADD CONSTRAINT pk_payroll_summary  PRIMARY KEY (payroll_id);
ALTER TABLE Payroll_Logs         ADD CONSTRAINT pk_payroll_logs     PRIMARY KEY (log_id);
```

### 3.2. Yabancı Anahtarlar

```sql
-- Tenant ilişkileri (Companies'e bağlanan tüm tablolar)
ALTER TABLE Users                ADD CONSTRAINT fk_user_company       FOREIGN KEY (fk_company_id) REFERENCES Companies(company_id);
ALTER TABLE Departments          ADD CONSTRAINT fk_dept_company       FOREIGN KEY (fk_company_id) REFERENCES Companies(company_id);
ALTER TABLE Job_Titles           ADD CONSTRAINT fk_job_company        FOREIGN KEY (fk_company_id) REFERENCES Companies(company_id);
ALTER TABLE Tax_Slabs            ADD CONSTRAINT fk_tax_company        FOREIGN KEY (fk_company_id) REFERENCES Companies(company_id);
ALTER TABLE Statutory_Parameters ADD CONSTRAINT fk_stat_company       FOREIGN KEY (fk_company_id) REFERENCES Companies(company_id);
ALTER TABLE Allowance_Types      ADD CONSTRAINT fk_alw_type_company   FOREIGN KEY (fk_company_id) REFERENCES Companies(company_id);
ALTER TABLE Deduction_Types      ADD CONSTRAINT fk_ded_type_company   FOREIGN KEY (fk_company_id) REFERENCES Companies(company_id);

-- Employees ilişkileri
ALTER TABLE Employees            ADD CONSTRAINT fk_emp_company        FOREIGN KEY (fk_company_id)     REFERENCES Companies(company_id);
ALTER TABLE Employees            ADD CONSTRAINT fk_emp_dept           FOREIGN KEY (fk_department_id)  REFERENCES Departments(department_id);
ALTER TABLE Employees            ADD CONSTRAINT fk_emp_job            FOREIGN KEY (fk_job_title_id)   REFERENCES Job_Titles(job_title_id);

-- Sözleşmeler
ALTER TABLE Employee_Contracts   ADD CONSTRAINT fk_cont_emp           FOREIGN KEY (fk_employee_id) REFERENCES Employees(employee_id);
ALTER TABLE Employee_Contracts   ADD CONSTRAINT fk_cont_company       FOREIGN KEY (fk_company_id)  REFERENCES Companies(company_id);

-- Puantaj
ALTER TABLE Attendance_Records   ADD CONSTRAINT fk_att_emp            FOREIGN KEY (fk_employee_id) REFERENCES Employees(employee_id);
ALTER TABLE Attendance_Records   ADD CONSTRAINT fk_att_company        FOREIGN KEY (fk_company_id)  REFERENCES Companies(company_id);

-- Ek ödemeler
ALTER TABLE Employee_Allowances  ADD CONSTRAINT fk_ea_emp             FOREIGN KEY (fk_employee_id)         REFERENCES Employees(employee_id);
ALTER TABLE Employee_Allowances  ADD CONSTRAINT fk_ea_company         FOREIGN KEY (fk_company_id)          REFERENCES Companies(company_id);
ALTER TABLE Employee_Allowances  ADD CONSTRAINT fk_ea_type            FOREIGN KEY (fk_allowance_type_id)   REFERENCES Allowance_Types(allowance_type_id);

-- Kesintiler
ALTER TABLE Employee_Deductions  ADD CONSTRAINT fk_ed_emp             FOREIGN KEY (fk_employee_id)         REFERENCES Employees(employee_id);
ALTER TABLE Employee_Deductions  ADD CONSTRAINT fk_ed_company         FOREIGN KEY (fk_company_id)          REFERENCES Companies(company_id);
ALTER TABLE Employee_Deductions  ADD CONSTRAINT fk_ed_type            FOREIGN KEY (fk_deduction_type_id)   REFERENCES Deduction_Types(deduction_type_id);

-- Bordro
ALTER TABLE Payroll_Summary      ADD CONSTRAINT fk_pay_emp            FOREIGN KEY (fk_employee_id) REFERENCES Employees(employee_id);
ALTER TABLE Payroll_Summary      ADD CONSTRAINT fk_pay_company        FOREIGN KEY (fk_company_id)  REFERENCES Companies(company_id);

-- Audit Log
ALTER TABLE Payroll_Logs         ADD CONSTRAINT fk_log_company        FOREIGN KEY (fk_company_id) REFERENCES Companies(company_id);
ALTER TABLE Payroll_Logs         ADD CONSTRAINT fk_log_user           FOREIGN KEY (fk_user_id)    REFERENCES Users(user_id);
```

> **Önemli Tasarım Notu:** `Payroll_Logs.fk_payroll_id` için bir foreign key **bilinçli olarak eklenmemiştir.** Çünkü audit log tablosu kaynak tabloya FK ile bağlanırsa, bordro silindiğinde mevcut INSERT/UPDATE logları yüzünden FK ihlali (ORA-02292) olur ve trigger DELETE log'unu yazamaz. Audit log tablosu kalıcı olmalı; kaynak tablo (Payroll_Summary) ise silinebilir/değişebilir olmalıdır.

### 3.3. Bileşik UNIQUE Kısıtları (İş Mantığı Tekilliği)

```sql
-- Aynı şirkette aynı TCKN ile iki personel açılamaz
ALTER TABLE Employees ADD CONSTRAINT uq_emp_national_id
    UNIQUE (fk_company_id, national_id);

-- Aynı şirkette aynı personel kodu iki kez kullanılamaz
ALTER TABLE Employees ADD CONSTRAINT uq_emp_code
    UNIQUE (fk_company_id, employee_code);

-- Bir personelin aynı ay/yıl için sadece bir puantajı olabilir
ALTER TABLE Attendance_Records ADD CONSTRAINT uq_attendance_period
    UNIQUE (fk_employee_id, record_month, record_year);

-- Bir personelin aynı ay/yıl için sadece bir bordrosu olabilir
ALTER TABLE Payroll_Summary ADD CONSTRAINT uq_payroll_period
    UNIQUE (fk_employee_id, period_month, period_year);
```

### 3.4. Performans İndeksleri

```sql
-- JOIN ve WHERE'de sık kullanılan FK kolonları için
CREATE INDEX idx_emp_dept       ON Employees(fk_department_id);
CREATE INDEX idx_emp_job        ON Employees(fk_job_title_id);
CREATE INDEX idx_att_emp        ON Attendance_Records(fk_employee_id);
CREATE INDEX idx_payroll_emp    ON Payroll_Summary(fk_employee_id);
```

---

## 4. Veri Girişi Paketi

Veri girişi, **direct INSERT** yerine **`pkg_payroll_entry` adlı bir PL/SQL paketi** üzerinden yapılır. Bu yaklaşımın faydaları:

- **Encapsulation:** Tablonun iç yapısı değişse bile uygulama kodu değişmez
- **Validation:** Tek noktadan iş kuralı kontrolü
- **Auditability:** Tüm INSERT'ler aynı katmandan geçtiği için izlenebilir
- **Tenant güvenliği:** `fk_company_id` parametresi her çağrıda zorunlu

Paket toplam **7 prosedür** içerir.

```sql
CREATE OR REPLACE PACKAGE pkg_payroll_entry AS
    PROCEDURE add_company   (p_company_id NUMBER, p_name VARCHAR2, p_email VARCHAR2);
    PROCEDURE add_department(p_dept_id NUMBER, p_company_id NUMBER, p_name VARCHAR2);
    PROCEDURE add_job_title (p_job_id NUMBER, p_company_id NUMBER, p_title VARCHAR2, p_base_salary NUMBER);
    PROCEDURE add_user      (p_user_id NUMBER, p_company_id NUMBER, p_username VARCHAR2,
                             p_email VARCHAR2, p_role VARCHAR2);
    PROCEDURE add_employee  (p_emp_id NUMBER, p_company_id NUMBER, p_dept_id NUMBER, p_job_id NUMBER,
                             p_national_id VARCHAR2, p_first_name VARCHAR2, p_last_name VARCHAR2);
    PROCEDURE add_contract  (p_contract_id NUMBER, p_emp_id NUMBER, p_company_id NUMBER, p_multiplier NUMBER);
    PROCEDURE add_payroll   (p_payroll_id NUMBER, p_employee_id NUMBER, p_company_id NUMBER,
                             p_period_month NUMBER, p_period_year NUMBER,
                             p_gross_salary NUMBER, p_net_salary NUMBER, p_total_tax NUMBER,
                             p_payment_status VARCHAR2);
END pkg_payroll_entry;
/

CREATE OR REPLACE PACKAGE BODY pkg_payroll_entry AS

    PROCEDURE add_company(p_company_id NUMBER, p_name VARCHAR2, p_email VARCHAR2) IS
    BEGIN
        INSERT INTO Companies (company_id, company_name, contact_email)
        VALUES (p_company_id, p_name, p_email);
    END add_company;

    PROCEDURE add_department(p_dept_id NUMBER, p_company_id NUMBER, p_name VARCHAR2) IS
    BEGIN
        INSERT INTO Departments (department_id, fk_company_id, department_name)
        VALUES (p_dept_id, p_company_id, p_name);
    END add_department;

    PROCEDURE add_job_title(p_job_id NUMBER, p_company_id NUMBER,
                            p_title VARCHAR2, p_base_salary NUMBER) IS
    BEGIN
        INSERT INTO Job_Titles (job_title_id, fk_company_id, title_name, min_base_salary)
        VALUES (p_job_id, p_company_id, p_title, p_base_salary);
    END add_job_title;

    PROCEDURE add_user(p_user_id NUMBER, p_company_id NUMBER, p_username VARCHAR2,
                       p_email VARCHAR2, p_role VARCHAR2) IS
    BEGIN
        INSERT INTO Users (user_id, fk_company_id, username, password_hash, email, role)
        VALUES (p_user_id, p_company_id, p_username, 'HASHED_PWD', p_email, p_role);
    END add_user;

    PROCEDURE add_employee(p_emp_id NUMBER, p_company_id NUMBER, p_dept_id NUMBER,
                           p_job_id NUMBER, p_national_id VARCHAR2,
                           p_first_name VARCHAR2, p_last_name VARCHAR2) IS
    BEGIN
        INSERT INTO Employees (employee_id, fk_company_id, fk_department_id, fk_job_title_id,
                               employee_code, national_id, first_name, last_name, hire_date)
        VALUES (p_emp_id, p_company_id, p_dept_id, p_job_id,
                'EMP'||p_emp_id, p_national_id, p_first_name, p_last_name, SYSDATE);
    END add_employee;

    PROCEDURE add_contract(p_contract_id NUMBER, p_emp_id NUMBER,
                           p_company_id NUMBER, p_multiplier NUMBER) IS
    BEGIN
        INSERT INTO Employee_Contracts (contract_id, fk_employee_id, fk_company_id,
                                        salary_multiplier, contract_start_date)
        VALUES (p_contract_id, p_emp_id, p_company_id, p_multiplier, SYSDATE);
    END add_contract;

    PROCEDURE add_payroll(
        p_payroll_id NUMBER, p_employee_id NUMBER, p_company_id NUMBER,
        p_period_month NUMBER, p_period_year NUMBER,
        p_gross_salary NUMBER, p_net_salary NUMBER, p_total_tax NUMBER,
        p_payment_status VARCHAR2
    ) IS
    BEGIN
        INSERT INTO Payroll_Summary (
            payroll_id, fk_employee_id, fk_company_id,
            period_month, period_year,
            gross_salary, net_salary, total_tax,
            payment_status, payment_date
        ) VALUES (
            p_payroll_id, p_employee_id, p_company_id,
            p_period_month, p_period_year,
            p_gross_salary, p_net_salary, p_total_tax,
            p_payment_status, SYSDATE
        );
    END add_payroll;

END pkg_payroll_entry;
/
```

**Örnek Çağrı (4 müşteri şirketten birinin kurulumu):**

```sql
BEGIN
    pkg_payroll_entry.add_company   (1, 'IMSA', 'mirzasincap@gmail.com');
    pkg_payroll_entry.add_department(1, 1, 'Executive Board');
    pkg_payroll_entry.add_job_title (1, 1, 'CEO', 500000);
    pkg_payroll_entry.add_user      (1, 1, 'isasmirza', 'mirzasincap@gmail.com', 'Admin');
    pkg_payroll_entry.add_employee  (1, 1, 1, 1, '23120205033', 'Isa Mirza', 'Sincap');
    pkg_payroll_entry.add_contract  (1, 1, 1, 1.0);
    COMMIT;
END;
/
```

---

## 5. Veri Güncelleme Paketi

Güncelleme işlemleri için `pkg_payroll_update` paketi tasarlanmıştır. Üç tipik bordro senaryosunu kapsar:

1. **Personel terfisi / departman değişikliği**
2. **Maaş zammı (sözleşme güncellemesi)**
3. **Hatalı puantajın düzeltilmesi**

**Tüm güncelleme prosedürlerinde iki güvenlik katmanı vardır:**

- `fk_company_id` ile **tenant izolasyonu** (bir müşteri şirket diğerinin verisini güncelleyemez)
- `SQL%ROWCOUNT = 0` kontrolü ile **sessiz başarısızlık önleme** (kayıt yoksa açıkça hata fırlatılır)

```sql
CREATE OR REPLACE PACKAGE pkg_payroll_update AS

    PROCEDURE update_employee_job(
        p_employee_id NUMBER, p_company_id NUMBER,
        p_new_dept_id NUMBER, p_new_job_id NUMBER
    );

    PROCEDURE update_contract_salary(
        p_employee_id NUMBER, p_company_id NUMBER,
        p_new_multiplier NUMBER, p_new_fixed_salary NUMBER
    );

    PROCEDURE update_attendance(
        p_attendance_id NUMBER, p_employee_id NUMBER, p_company_id NUMBER,
        p_new_worked_days NUMBER, p_new_overtime_hours NUMBER
    );

END pkg_payroll_update;
/

CREATE OR REPLACE PACKAGE BODY pkg_payroll_update AS

    -- 1. Personel terfi / departman değişikliği
    PROCEDURE update_employee_job(
        p_employee_id NUMBER, p_company_id NUMBER,
        p_new_dept_id NUMBER, p_new_job_id NUMBER
    ) IS
    BEGIN
        UPDATE Employees
        SET fk_department_id = p_new_dept_id,
            fk_job_title_id  = p_new_job_id
        WHERE employee_id    = p_employee_id
          AND fk_company_id  = p_company_id;   -- Tenant güvenlik kontrolü

        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20001,
                'Personel bulunamadi veya bu sirkete ait degil.');
        END IF;
    END update_employee_job;

    -- 2. Maaş sözleşmesi güncelleme (yalnızca aktif sözleşme)
    PROCEDURE update_contract_salary(
        p_employee_id NUMBER, p_company_id NUMBER,
        p_new_multiplier NUMBER, p_new_fixed_salary NUMBER
    ) IS
    BEGIN
        UPDATE Employee_Contracts
        SET salary_multiplier        = p_new_multiplier,
            additional_fixed_salary  = p_new_fixed_salary
        WHERE fk_employee_id = p_employee_id
          AND fk_company_id  = p_company_id
          AND is_active      = 1;

        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20002,
                'Aktif sozlesme bulunamadi veya yetkisiz islem.');
        END IF;
    END update_contract_salary;

    -- 3. Puantaj düzeltme
    PROCEDURE update_attendance(
        p_attendance_id NUMBER, p_employee_id NUMBER, p_company_id NUMBER,
        p_new_worked_days NUMBER, p_new_overtime_hours NUMBER
    ) IS
    BEGIN
        UPDATE Attendance_Records
        SET worked_days     = p_new_worked_days,
            overtime_hours  = p_new_overtime_hours
        WHERE attendance_id  = p_attendance_id
          AND fk_employee_id = p_employee_id
          AND fk_company_id  = p_company_id;

        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20003,
                'Puantaj kaydi bulunamadi veya sirket eslesmiyor.');
        END IF;
    END update_attendance;

END pkg_payroll_update;
/
```

**Örnek Çağrı (IMSA'da bir personeli HR Specialist'ten HR Manager'a terfi ettirme):**

```sql
BEGIN
    pkg_payroll_update.update_employee_job(
        p_employee_id => 305,
        p_company_id  => 1,
        p_new_dept_id => 101,
        p_new_job_id  => 202
    );
    COMMIT;
END;
/
```

---

## 6. Veri Silme Paketi

Silme işlemleri **`pkg_payroll_delete`** paketi üzerinden yapılır. **`ON DELETE CASCADE` bilinçli olarak kullanılmamıştır;** çünkü cascade davranışı veritabanı seviyesinde otomatik olur ve audit log için tehlikelidir. Bunun yerine **PL/SQL içinde manuel hiyerarşik silme** uygulanmıştır.

**Hiyerarşik Silme Sırası (FK ihlali yaşamamak için):**

1. `Payroll_Logs` (en alttaki bağımlı kayıtlar)
2. `Payroll_Summary`
3. `Employee_Allowances` + `Employee_Deductions` + `Attendance_Records`
4. `Employee_Contracts`
5. `Employees` (en sondaki ana entity)

```sql
CREATE OR REPLACE PACKAGE pkg_payroll_delete AS
    PROCEDURE delete_employee (p_employee_id NUMBER, p_company_id NUMBER);
    PROCEDURE delete_allowance(p_emp_allowance_id NUMBER, p_company_id NUMBER);
    PROCEDURE delete_payroll  (p_payroll_id NUMBER, p_company_id NUMBER);
END pkg_payroll_delete;
/

CREATE OR REPLACE PACKAGE BODY pkg_payroll_delete AS

    -- 1. Hiyerarşik personel silme (5 katman)
    PROCEDURE delete_employee(p_employee_id NUMBER, p_company_id NUMBER) IS
    BEGIN
        -- Adım 1: Logları ve bordro özetini sil
        DELETE FROM Payroll_Logs
        WHERE fk_payroll_id IN (
            SELECT payroll_id FROM Payroll_Summary
            WHERE fk_employee_id = p_employee_id AND fk_company_id = p_company_id
        );
        DELETE FROM Payroll_Summary
        WHERE fk_employee_id = p_employee_id AND fk_company_id = p_company_id;

        -- Adım 2: Ek ödeme, kesinti ve puantajları sil
        DELETE FROM Employee_Allowances
        WHERE fk_employee_id = p_employee_id AND fk_company_id = p_company_id;

        DELETE FROM Employee_Deductions
        WHERE fk_employee_id = p_employee_id AND fk_company_id = p_company_id;

        DELETE FROM Attendance_Records
        WHERE fk_employee_id = p_employee_id AND fk_company_id = p_company_id;

        -- Adım 3: Sözleşmeyi sil
        DELETE FROM Employee_Contracts
        WHERE fk_employee_id = p_employee_id AND fk_company_id = p_company_id;

        -- Adım 4: Personeli ana tablodan sil
        DELETE FROM Employees
        WHERE employee_id = p_employee_id AND fk_company_id = p_company_id;

        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20004,
                'Silinecek personel bulunamadi veya yetkisiz sirket islemi.');
        END IF;
    END delete_employee;

    -- 2. Ek ödeme silme (yanlışlıkla verilmiş bonus iptali)
    PROCEDURE delete_allowance(p_emp_allowance_id NUMBER, p_company_id NUMBER) IS
    BEGIN
        DELETE FROM Employee_Allowances
        WHERE emp_allowance_id = p_emp_allowance_id
          AND fk_company_id    = p_company_id;

        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20005, 'Ek odeme kaydi bulunamadi.');
        END IF;
    END delete_allowance;

    -- 3. Bordro silme (önce log, sonra bordro)
    PROCEDURE delete_payroll(p_payroll_id NUMBER, p_company_id NUMBER) IS
    BEGIN
        DELETE FROM Payroll_Logs
        WHERE fk_payroll_id = p_payroll_id AND fk_company_id = p_company_id;

        DELETE FROM Payroll_Summary
        WHERE payroll_id    = p_payroll_id AND fk_company_id = p_company_id;

        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20006, 'Bordro kaydi bulunamadi.');
        END IF;
    END delete_payroll;

END pkg_payroll_delete;
/
```

**Örnek Çağrı (SIMA'dan istifa eden bir personeli silme):**

```sql
BEGIN
    pkg_payroll_delete.delete_employee(p_employee_id => 365, p_company_id => 3);
    COMMIT;
END;
/
```

---

## 7. Trigger ile Tanım–Hareket Tablosu Otomasyonu

Trigger'lar; kullanıcı bir **tanım tablosuna** veri girdiğinde, ilgili **hareket tablosuna** otomatik kayıt atılmasını sağlar. Bu sayede uygulamanın "elle puantaj kaydı oluşturma" veya "elle audit log yazma" gibi tekrarlayan işlemleri unutulmaz.

Sistemde **2 trigger** ve onları besleyen **2 sequence** vardır.

### 7.1. Sequence Tanımlamaları

```sql
CREATE SEQUENCE seq_attendance_id   START WITH 10000  INCREMENT BY 1;
CREATE SEQUENCE seq_payroll_log_id  START WITH 1000   INCREMENT BY 1;
```

### 7.2. Trigger 1 — Personel Eklenince Puantaj Otomatik Açılır

`Employees` tablosuna yeni bir personel girildiğinde, bu personel için o ayın puantaj kaydı **sıfır değerlerle otomatik** oluşturulur. Böylece insan kaynakları "yeni personeli puantaj listesine eklemeyi unutmuş" hatasına düşemez.

```sql
CREATE OR REPLACE TRIGGER trg_after_emp_insert
AFTER INSERT ON Employees
FOR EACH ROW
DECLARE
    v_current_month NUMBER;
    v_current_year  NUMBER;
BEGIN
    v_current_month := EXTRACT(MONTH FROM SYSDATE);
    v_current_year  := EXTRACT(YEAR  FROM SYSDATE);

    INSERT INTO Attendance_Records (
        attendance_id, fk_employee_id, fk_company_id,
        record_month, record_year, worked_days, overtime_hours
    ) VALUES (
        seq_attendance_id.NEXTVAL,
        :NEW.employee_id,
        :NEW.fk_company_id,
        v_current_month,
        v_current_year,
        0, 0
    );
END;
/
```

### 7.3. Trigger 2 — Bordro Üzerindeki Tüm DML İşlemlerini Audit Loglar

`Payroll_Summary` tablosuna yapılan **her INSERT, UPDATE ve DELETE** işlemi otomatik olarak `Payroll_Logs` tablosuna kaydedilir. Hangi bordro, ne zaman, hangi türde değiştirilmiş — hepsi izlenebilir.

```sql
CREATE OR REPLACE TRIGGER trg_payroll_audit
AFTER INSERT OR UPDATE OR DELETE ON Payroll_Summary
FOR EACH ROW
DECLARE
    v_action_type        VARCHAR2(50);
    v_target_payroll_id  NUMBER;
    v_target_company_id  NUMBER;
BEGIN
    IF INSERTING THEN
        v_action_type       := 'INSERT - YENI BORDRO HESAPLANDI';
        v_target_payroll_id := :NEW.payroll_id;
        v_target_company_id := :NEW.fk_company_id;
    ELSIF UPDATING THEN
        v_action_type       := 'UPDATE - BORDRO RAKAMLARI DEGISTIRILDI';
        v_target_payroll_id := :NEW.payroll_id;
        v_target_company_id := :NEW.fk_company_id;
    ELSIF DELETING THEN
        v_action_type       := 'DELETE - BORDRO IPTAL EDILDI';
        v_target_payroll_id := :OLD.payroll_id;
        v_target_company_id := :OLD.fk_company_id;
    END IF;

    INSERT INTO Payroll_Logs (
        log_id, fk_payroll_id, fk_company_id, fk_user_id,
        action_type, action_timestamp
    ) VALUES (
        seq_payroll_log_id.NEXTVAL,
        v_target_payroll_id,
        v_target_company_id,
        NULL,
        v_action_type,
        CURRENT_TIMESTAMP
    );
END;
/
```

### 7.4. Test Senaryosu ve Çıktısı

```
=== TRIGGER TEST BLOGU BASLADI ===

TEST 1: Yeni personel ekleniyor (ID=9999)...
--> Trigger sonucu: 1 adet puantaj kaydi otomatik olusturuldu.

TEST 2: Test personeli icin bordro ekleniyor (payroll_id=9999)...
--> Trigger sonucu: 1 adet INSERT logu olusturuldu.

TEST 3: Bordro guncelleniyor...
--> Trigger sonucu: Toplam 2 adet log var.

TEST 4: Bordro siliniyor...
--> Trigger sonucu: Toplam 3 adet log var.

=== OLUSTURULAN LOGLARIN DETAYI ===
Log ID: 1000 | Islem: INSERT - YENI BORDRO HESAPLANDI
Log ID: 1001 | Islem: UPDATE - BORDRO RAKAMLARI DEGISTIRILDI
Log ID: 1002 | Islem: DELETE - BORDRO IPTAL EDILDI

=== TEST TAMAMLANDI ===
```

---

## 8. Dinamik SQL ile Raporlama

Raporlama için `pkg_payroll_reports` paketi tasarlanmıştır. Burada kritik özellik şudur: **WHERE cümlesindeki kısıtlar sabit değil, parametrelere göre çalışma zamanında dinamik olarak inşa edilir.** Bu sayede aynı fonksiyon hem "tüm departmanlar", hem "sadece Engineering departmanı", hem de "sadece Senior Software Engineer'lar" için farklı sonuç döndürebilir.

**Kullanılan Yapılar:**

- `SYS_REFCURSOR` → fonksiyon birden fazla satır döndürebilsin diye
- `EXECUTE IMMEDIATE` benzeri yapı: `OPEN v_cursor FOR v_sql;`
- Opsiyonel parametreler için `IF p_xxx IS NOT NULL THEN v_sql := v_sql || ' AND ...'` deseni

```sql
CREATE OR REPLACE PACKAGE pkg_payroll_reports AS

    FUNCTION get_employee_report(
        p_company_id    NUMBER,
        p_department_id NUMBER DEFAULT NULL,
        p_job_title_id  NUMBER DEFAULT NULL
    ) RETURN SYS_REFCURSOR;

    FUNCTION get_monthly_payroll(
        p_company_id   NUMBER,
        p_period_month NUMBER,
        p_period_year  NUMBER,
        p_employee_id  NUMBER DEFAULT NULL
    ) RETURN SYS_REFCURSOR;

END pkg_payroll_reports;
/

CREATE OR REPLACE PACKAGE BODY pkg_payroll_reports AS

    -- 1. Çalışan Raporu (Departman ve Unvan filtresi opsiyonel)
    FUNCTION get_employee_report(
        p_company_id    NUMBER,
        p_department_id NUMBER DEFAULT NULL,
        p_job_title_id  NUMBER DEFAULT NULL
    ) RETURN SYS_REFCURSOR
    IS
        v_sql    VARCHAR2(4000);
        v_cursor SYS_REFCURSOR;
    BEGIN
        -- Sabit (zorunlu) kısım: müşteri şirket izolasyonu
        v_sql := 'SELECT e.employee_code, e.national_id, e.first_name, e.last_name, ' ||
                 'd.department_name, j.title_name, c.salary_multiplier ' ||
                 'FROM Employees e ' ||
                 'JOIN Departments d        ON e.fk_department_id = d.department_id ' ||
                 'JOIN Job_Titles j         ON e.fk_job_title_id  = j.job_title_id ' ||
                 'JOIN Employee_Contracts c ON e.employee_id      = c.fk_employee_id ' ||
                 'WHERE e.fk_company_id = ' || p_company_id || ' AND c.is_active = 1';

        -- Dinamik kısıt 1: Departman filtresi
        IF p_department_id IS NOT NULL THEN
            v_sql := v_sql || ' AND e.fk_department_id = ' || p_department_id;
        END IF;

        -- Dinamik kısıt 2: Unvan filtresi
        IF p_job_title_id IS NOT NULL THEN
            v_sql := v_sql || ' AND e.fk_job_title_id = ' || p_job_title_id;
        END IF;

        v_sql := v_sql || ' ORDER BY e.first_name, e.last_name';

        OPEN v_cursor FOR v_sql;
        RETURN v_cursor;
    END get_employee_report;

    -- 2. Aylık Bordro Raporu (tek personel veya tüm şirket için)
    FUNCTION get_monthly_payroll(
        p_company_id   NUMBER,
        p_period_month NUMBER,
        p_period_year  NUMBER,
        p_employee_id  NUMBER DEFAULT NULL
    ) RETURN SYS_REFCURSOR
    IS
        v_sql    VARCHAR2(4000);
        v_cursor SYS_REFCURSOR;
    BEGIN
        v_sql := 'SELECT p.payroll_id, e.first_name || '' '' || e.last_name AS full_name, ' ||
                 'p.gross_salary, p.total_tax, p.net_salary, p.payment_status ' ||
                 'FROM Payroll_Summary p ' ||
                 'JOIN Employees e ON p.fk_employee_id = e.employee_id ' ||
                 'WHERE p.fk_company_id = ' || p_company_id ||
                 ' AND p.period_month = ' || p_period_month ||
                 ' AND p.period_year = '  || p_period_year;

        -- Dinamik kısıt: Tek personel için döküm
        IF p_employee_id IS NOT NULL THEN
            v_sql := v_sql || ' AND p.fk_employee_id = ' || p_employee_id;
        END IF;

        OPEN v_cursor FOR v_sql;
        RETURN v_cursor;
    END get_monthly_payroll;

END pkg_payroll_reports;
/
```

**Örnek Çağrı 1 — IMSA'nın Tüm Çalışanları:**

```sql
DECLARE
    v_cur SYS_REFCURSOR;
    v_emp_code VARCHAR2(30); v_tc VARCHAR2(11);
    v_fname VARCHAR2(50);    v_lname VARCHAR2(50);
    v_dept VARCHAR2(100);    v_title VARCHAR2(100);
    v_mult NUMBER;
BEGIN
    v_cur := pkg_payroll_reports.get_employee_report(p_company_id => 1);
    LOOP
        FETCH v_cur INTO v_emp_code, v_tc, v_fname, v_lname, v_dept, v_title, v_mult;
        EXIT WHEN v_cur%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE(v_emp_code || ' - ' || v_fname || ' ' || v_lname ||
                             ' | ' || v_dept || ' | ' || v_title);
    END LOOP;
    CLOSE v_cur;
END;
/
```

**Örnek Çağrı 2 — Sadece IMSA'nın Engineering Departmanındaki Senior Engineer'lar:**

```sql
v_cur := pkg_payroll_reports.get_employee_report(
    p_company_id    => 1,
    p_department_id => 100,   -- Engineering
    p_job_title_id  => 200    -- Senior Software Engineer
);
```

**Örnek Çağrı 3 — MISA'nın Mayıs 2026 Bordrosu:**

```sql
v_cur := pkg_payroll_reports.get_monthly_payroll(
    p_company_id   => 2,
    p_period_month => 5,
    p_period_year  => 2026
);
```

---

## 9. Üçüncü Normal Form (3NF) Doğrulaması

Tasarımımızın 3NF olduğunu kanıtlamak için her bir normal form sırayla incelenir.

### 9.1. 1. Normal Form (1NF)

**Kural:** Tüm sütun değerleri atomik olmalıdır (tekrar eden grup, liste veya iç içe yapı bulunmamalıdır).

**Doğrulama:** Tüm tablolarda her sütun atomik bir değer tutar:

- Çalışanın adı `first_name`, soyadı `last_name` olarak ayrı tutulur (`full_name` gibi birleşik bir alan yoktur)
- Çalışanın aldığı tüm ek ödemeler aynı satırda virgülle değil, **`Employee_Allowances`** tablosunda ayrı satırlar olarak tutulur
- Çocuk sayısı `children_count` olarak tek atomik sayıdır

**Sonuç:** ✅ Tüm tablolar **1NF**'dedir.

### 9.2. 2. Normal Form (2NF)

**Kural:** Tablo 1NF olmalı, ek olarak hiçbir non-key attribute kısmen primary key'e bağımlı olmamalıdır.

**Doğrulama:** Tüm 15 tablomuzda **tek sütunlu surrogate primary key** (`company_id`, `employee_id`, `payroll_id` vb.) kullanılmıştır. Tek sütunlu PK'da "kısmi bağımlılık" matematiksel olarak imkânsızdır.

> Not: Bileşik UNIQUE kısıtlar (örn. `(fk_employee_id, period_month, period_year)`) iş mantığı tekilliği için vardır; bunlar PRIMARY KEY değildir, dolayısıyla 2NF analizi tek sütunlu PK üzerinden yapılır.

**Sonuç:** ✅ Tüm tablolar **2NF**'dedir.

### 9.3. 3. Normal Form (3NF)

**Kural:** Tablo 2NF olmalı, ek olarak hiçbir non-key attribute başka bir non-key attribute'a transitif olarak bağımlı olmamalıdır. (Yani: PK → A → B zinciri olmamalıdır.)

**Doğrulama (15 tablo için tek tek):**

| # | Tablo | 3NF Doğrulaması |
|---|-------|-----------------|
| 1 | `Companies` | Tüm sütunlar (`company_name`, `tax_office` vb.) doğrudan `company_id`'ye bağlı. ✅ |
| 2 | `Users` | `username`, `email`, `role` doğrudan `user_id`'ye bağlı. ✅ |
| 3 | `Departments` | `department_name` doğrudan `department_id`'ye bağlı. ✅ |
| 4 | `Job_Titles` | `title_name` ve `min_base_salary` doğrudan `job_title_id`'ye bağlı. ✅ |
| 5 | `Employees` | Departman adı **Departments**'ta, unvan adı **Job_Titles**'ta tutulur. Employees yalnızca `fk_department_id` ve `fk_job_title_id` referansları tutar. Transitif bağımlılık yok. ✅ |
| 6 | `Employee_Contracts` | Maaş çarpanı doğrudan `contract_id`'ye bağlı. ✅ |
| 7 | `Tax_Slabs` | Vergi oranı doğrudan `slab_id`'ye bağlı. ✅ |
| 8 | `Statutory_Parameters` | Yasal oran doğrudan `param_id`'ye bağlı. ✅ |
| 9 | `Allowance_Types` | Ek ödeme adı doğrudan `allowance_type_id`'ye bağlı. ✅ |
| 10 | `Deduction_Types` | Kesinti adı doğrudan `deduction_type_id`'ye bağlı. ✅ |
| 11 | `Attendance_Records` | Çalışılan gün ve mesai saati doğrudan `attendance_id`'ye bağlı. ✅ |
| 12 | `Employee_Allowances` | Tutar doğrudan `emp_allowance_id`'ye bağlı; ek ödeme adı `Allowance_Types`'ta. ✅ |
| 13 | `Employee_Deductions` | Tutar doğrudan `emp_deduction_id`'ye bağlı; kesinti adı `Deduction_Types`'ta. ✅ |
| 14 | `Payroll_Summary` | Brüt, net, vergi tutarları doğrudan `payroll_id`'ye bağlı. ✅ |
| 15 | `Payroll_Logs` | İşlem türü ve zaman doğrudan `log_id`'ye bağlı. ✅ |

### 9.4. Anomaly'lerin Önlenmesi

Tasarımın 3NF'de olması, üç temel anomaly'i (anormalliği) önler:

- **Update Anomaly:** "Engineering" departmanının adı değişirse tek satır (`Departments` tablosunda) güncellenir, tüm çalışanların satırı güncellenmez.
- **Insert Anomaly:** Yeni bir unvan tanımlamak için en az bir personel girmek gerekmez; `Job_Titles` tablosuna doğrudan eklenir.
- **Delete Anomaly:** Bir departmandaki son personel silindiğinde departman tanımı kaybolmaz; `Departments` tablosunda durmaya devam eder.

**Genel Sonuç:** ✅ **Tüm 15 tablo 3. Normal Form'dadır.**

---

## 10. Mükerrer Kayıt Temizliği

Veritabanında daha önce tanımlanmış bileşik UNIQUE kısıtları sayesinde, normal koşullarda mükerrer kayıt oluşması mümkün değildir. **Ancak şu senaryolarda mükerrer kayıt oluşabilir:**

- Toplu veri aktarımı (ETL / migration) sırasında kısıtlar geçici olarak devre dışı bırakılırsa
- Yedek (dump) dosyasından eski veri tekrar yüklenirse
- UNIQUE kısıt kapsamına girmeyen "iş mantığı tekrarları" yaşanırsa (örneğin aynı şirkete aynı vergi numarası ile iki Companies kaydı)

Bu senaryolar için **`pkg_payroll_maintenance.remove_all_duplicates`** prosedürü tasarlanmıştır. Prosedür, **15 tablonun tamamı için** her tablonun kendi "business key" tanımına göre temizlik yapar.

**Kullanılan Yöntem (ROWID + MIN):**

```sql
DELETE FROM <tablo>
WHERE rowid NOT IN (
    SELECT MIN(rowid) FROM <tablo>
    GROUP BY <business_key_kolonlari>
);
```

Bu yöntem her grupta yalnızca **en eski (en küçük rowid)** kaydı korur, geri kalanları siler.

```sql
CREATE OR REPLACE PACKAGE pkg_payroll_maintenance AS
    PROCEDURE remove_all_duplicates;
END pkg_payroll_maintenance;
/

CREATE OR REPLACE PACKAGE BODY pkg_payroll_maintenance AS

    PROCEDURE remove_all_duplicates IS
    BEGIN
        -- 1. Companies — aynı vergi numarasına sahip kopyalar
        DELETE FROM Companies
        WHERE tax_number IS NOT NULL
          AND rowid NOT IN (
            SELECT MIN(rowid) FROM Companies
            WHERE tax_number IS NOT NULL
            GROUP BY tax_number
        );

        -- 2. Users — aynı şirketteki aynı kullanıcı adları
        DELETE FROM Users
        WHERE rowid NOT IN (
            SELECT MIN(rowid) FROM Users GROUP BY fk_company_id, username
        );

        -- 3. Departments — aynı şirketteki aynı isimli departmanlar
        DELETE FROM Departments
        WHERE rowid NOT IN (
            SELECT MIN(rowid) FROM Departments GROUP BY fk_company_id, department_name
        );

        -- 4. Job_Titles — aynı şirketteki aynı isimli unvanlar
        DELETE FROM Job_Titles
        WHERE rowid NOT IN (
            SELECT MIN(rowid) FROM Job_Titles GROUP BY fk_company_id, title_name
        );

        -- 5. Employees — aynı şirkette aynı TCKN'ye sahip personeller
        DELETE FROM Employees
        WHERE rowid NOT IN (
            SELECT MIN(rowid) FROM Employees GROUP BY fk_company_id, national_id
        );

        -- 6. Employee_Contracts — aynı tarihte başlayan mükerrer sözleşmeler
        DELETE FROM Employee_Contracts
        WHERE rowid NOT IN (
            SELECT MIN(rowid) FROM Employee_Contracts
            GROUP BY fk_employee_id, contract_start_date
        );

        -- 7. Tax_Slabs — aynı şirketin aynı dilim sınırları
        DELETE FROM Tax_Slabs
        WHERE rowid NOT IN (
            SELECT MIN(rowid) FROM Tax_Slabs
            GROUP BY fk_company_id, min_income, max_income
        );

        -- 8. Statutory_Parameters — aynı yasal parametre / aynı tarih
        DELETE FROM Statutory_Parameters
        WHERE rowid NOT IN (
            SELECT MIN(rowid) FROM Statutory_Parameters
            GROUP BY fk_company_id, param_name, effective_date
        );

        -- 9. Allowance_Types — aynı şirketteki aynı isimli ek ödeme türleri
        DELETE FROM Allowance_Types
        WHERE rowid NOT IN (
            SELECT MIN(rowid) FROM Allowance_Types
            GROUP BY fk_company_id, allowance_name
        );

        -- 10. Deduction_Types — aynı şirketteki aynı isimli kesinti türleri
        DELETE FROM Deduction_Types
        WHERE rowid NOT IN (
            SELECT MIN(rowid) FROM Deduction_Types
            GROUP BY fk_company_id, deduction_name
        );

        -- 11. Attendance_Records — aynı personelin aynı ay/yıl puantajı
        DELETE FROM Attendance_Records
        WHERE rowid NOT IN (
            SELECT MIN(rowid) FROM Attendance_Records
            GROUP BY fk_employee_id, record_month, record_year
        );

        -- 12. Employee_Allowances — aynı gün aynı türde mükerrer ödeme
        DELETE FROM Employee_Allowances
        WHERE rowid NOT IN (
            SELECT MIN(rowid) FROM Employee_Allowances
            GROUP BY fk_employee_id, fk_allowance_type_id, payment_date
        );

        -- 13. Employee_Deductions — aynı gün aynı türde mükerrer kesinti
        DELETE FROM Employee_Deductions
        WHERE rowid NOT IN (
            SELECT MIN(rowid) FROM Employee_Deductions
            GROUP BY fk_employee_id, fk_deduction_type_id, deduction_date
        );

        -- 14. Payroll_Summary — aynı personelin aynı dönem için iki bordrosu
        DELETE FROM Payroll_Summary
        WHERE rowid NOT IN (
            SELECT MIN(rowid) FROM Payroll_Summary
            GROUP BY fk_employee_id, period_month, period_year
        );

        -- 15. Payroll_Logs — aynı saniye aynı işlem birebir kopyaları
        DELETE FROM Payroll_Logs
        WHERE rowid NOT IN (
            SELECT MIN(rowid) FROM Payroll_Logs
            GROUP BY fk_payroll_id, fk_user_id, action_type, action_timestamp
        );

        COMMIT;

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20010,
                'Mukerrer kayit temizligi sirasinda bir hata olustu: ' || SQLERRM);
    END remove_all_duplicates;

END pkg_payroll_maintenance;
/
```

**Tasarımın Sağladığı Garanti:**

- **Atomiklik:** Tüm 15 silme işlemi tek bir transaction'dadır. Herhangi bir adımda hata olursa `ROLLBACK` ile başlangıç durumuna dönülür.
- **İzole edilmiş hata yönetimi:** `EXCEPTION WHEN OTHERS` ile beklenmeyen hatalar yakalanır ve anlamlı bir hata mesajıyla yukarıya iletilir.
- **Hangi kaydı tutalım?** `MIN(rowid)` → en eski kayıt korunur, sonradan eklenmiş kopyalar silinir.

**Örnek Çağrı:**

```sql
BEGIN
    pkg_payroll_maintenance.remove_all_duplicates;
END;
/
```

---

## Sonuç

Bu projede; **birden fazla müşteri şirkete bordro hizmeti veren bir SaaS platformunun** veritabanı ihtiyaçları, Oracle PL/SQL teknolojisi ile sıfırdan tasarlanıp uygulanmıştır. Tasarım sürecinde hem **akademik veri tabanı normalizasyon prensiplerine** (3NF) hem de **gerçek dünyaya uygun mimari kararlara** (multi-tenant izolasyon, audit log, hiyerarşik silme) sadık kalınmıştır.

**Sayısal Özet:**

| Bileşen | Sayı |
|---------|------|
| Tablo | 15 |
| Birincil Anahtar (PK) | 15 |
| Yabancı Anahtar (FK) | 24 |
| Bileşik UNIQUE | 4 |
| Performans İndeksi | 4 |
| PL/SQL Paketi | 5 |
| Toplam Prosedür / Fonksiyon | 16 |
| Trigger | 2 |
| Sequence | 2 |
| E-R Diyagramı Entity / İlişki / Attribute | 15 / 20 / 93 |

**Karşılanan Gereksinimler (10 Madde):**

| # | Gereksinim | Karşılayan Bileşen |
|---|-----------|--------------------|
| 1 | E-R Diyagramı (≥12 tablo) | 15 entity / Chen notasyonu |
| 2 | Tablo oluşturma kodları | `01_create_tables.sql` |
| 3 | İndeksler (PK / FK / UNIQUE / Composite) | `02_constraints_indexes.sql` |
| 4 | Veri girişi (PL/SQL paket) | `pkg_payroll_entry` |
| 5 | Veri güncelleme (PL/SQL paket) | `pkg_payroll_update` |
| 6 | Veri silme (PL/SQL paket) | `pkg_payroll_delete` |
| 7 | Tetikleyici otomasyonu | `trg_after_emp_insert`, `trg_payroll_audit` |
| 8 | Dinamik raporlama | `pkg_payroll_reports` |
| 9 | 3NF kanıtı | Bölüm 9'da 15 tablo için doğrulama |
| 10 | Mükerrer kayıt silme | `pkg_payroll_maintenance.remove_all_duplicates` |

**SaaS Mimarisinin Kazanımları:**

- **Tek veritabanı, sınırsız müşteri şirket:** Her yeni müşteri için ayrı kurulum gerektirmez; sadece `Companies` tablosuna bir kayıt atılır.
- **Veri izolasyonu:** Hiçbir müşteri şirket başka birinin verisini ne görür ne de güncelleyebilir. `fk_company_id` ile filtrelenir.
- **Maliyet ve bakım kolaylığı:** Tek veritabanı yedeği, tek versiyon güncellemesi, tek lisans.
- **Esnek tanım yapısı:** Vergi dilimleri (`Tax_Slabs.fk_company_id NULL`) gibi alanlar hem global hem de şirkete özel tanımlanabilir.

**Veri Tutarlılığı Garantileri:**

- Foreign Key kısıtları → referans bütünlüğü
- Bileşik UNIQUE kısıtları → iş mantığı tekilliği (TCKN, dönem bazlı bordro vb.)
- Trigger'lar → unutulmayacak otomatik kayıtlar (puantaj, audit log)
- 3NF tasarımı → güncelleme/ekleme/silme anomaly'lerinin önlenmesi
- Hiyerarşik silme prosedürü → FK ihlali olmadan veri temizliği

**Olası Geliştirme Önerileri:**

- Manuel ID atama yerine `seq_*.NEXTVAL` ile sequence tabanlı otomatik ID üretimi
- Demo amaçlı `'HASHED_PWD'` yerine bcrypt / Argon2 ile gerçek şifre hashing
- Audit log içinde `SYS_CONTEXT('USERENV', 'SESSION_USER')` ile gerçek oturum kullanıcı kimliği
- Dinamik SQL'de string concatenation yerine `bind variable` (`USING` klozu) kullanımı
- Materialized view ile aylık / yıllık raporların önbelleklenmesi

Sonuç olarak proje; gerek tablo sayısı (15 ≥ 12), gerek ilişki çeşitliliği (1:1, 1:N, M:N), gerekse PL/SQL kullanım derinliği (paket, prosedür, fonksiyon, trigger, dinamik SQL, dedupe) ile **ödevin 10 maddesinin tamamını eksiksiz ve gerçek bir SaaS bordro platformuna uygun şekilde karşılamaktadır.**
