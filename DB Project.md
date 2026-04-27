
# 1. Projenizin bir E-R diyagramını çiziniz (en az 12 tablo bulunmalıdır). Microsoft Visio veya benzeri bir yazılım aracı kullanınız.
Bu projeyi sadece yerel bir takip aracı değil, ölçeklenebilir ve profesyonel bir SaaS (Software as a Service) platformu olarak kurguladık. En temel önceliğimiz, birden fazla şirketin verilerini aynı veritabanında güvenli bir şekilde barındırabilmekti. Bu amaçla uyguladığımız "Multi-tenancy" mimarisi sayesinde, her tabloda bulunan `fk_company_id`alanı üzerinden verileri mantıksal olarak izole ettik. Bu yapı, sisteme giriş yapan bir kullanıcının sadece kendi şirketine ait çalışanları, bordroları ve raporları görmesini sağlayarak en üst düzeyde veri gizliliği sunar. Yani veritabanı seviyesinde her şirket için görünmez bir duvar örerek, verilerin birbirine karışma riskini tamamen ortadan kaldırdık.

Tasarımda rasyonelliği sağlamak adına, bordro süreçlerinin dinamik ve değişken doğasına odaklandık. Maaş bilgisini statik bir veri olarak unvana gömmek yerine, `Employee_Contracts` tablosuyla kişiye özel hale getirdik; bu sayede "Ayın Elemanı" bonusları veya bireysel maaş pazarlıkları gibi gerçek hayat senaryolarını kolayca yönetebiliyoruz. Ayrıca, vergi dilimleri ve SGK oranları gibi yasal parametreleri kod içerisine hard-coded (sabit) yazmak yerine, `Tax_Slabs` ve `Statutory_Parameters` tablolarında dinamik olarak tuttuk. Bu sayede devlet bir vergi oranını değiştirdiğinde, yazılımın kodunu değiştirmeye gerek kalmadan sadece tabloyu güncelleyerek sistemi güncel tutabiliyoruz. Hem mühendislik standartlarına uygun `fk_` isimlendirme disiplini hem de 3. Normal Form (3NF) yapısıyla, veritabanını performanslı ve tutarlı bir hale getirdik.

|**Table Name**|**Columns (PK: Primary Key, FK: Foreign Key)**|
|---|---|
|**Companies**|`company_id` (PK), `company_name`, `tax_office`, `tax_number`, `contact_person`, `contact_phone`, `contact_email`, `address`|
|**Users**|`user_id` (PK), `fk_company_id` (FK), `username`, `password_hash`, `email`, `role`|
|**Departments**|`department_id` (PK), `fk_company_id` (FK), `department_name`|
|**Job_Titles**|`job_title_id` (PK), `fk_company_id` (FK), `title_name`, `min_base_salary`|
|**Employees**|`employee_id` (PK), `fk_company_id` (FK), `fk_department_id` (FK), `fk_job_title_id` (FK), `employee_code`, `national_id`, `first_name`, `last_name`, `birth_date`, `marital_status`, `children_count`, `hire_date`|
|**Employee_Contracts**|`contract_id` (PK), `fk_employee_id` (FK), `fk_company_id` (FK), `salary_multiplier`, `additional_fixed_salary`, `contract_start_date`, **`contract_end_date`**, `is_active`|
|**Tax_Slabs**|`slab_id` (PK), `fk_company_id` (FK), `min_income`, `max_income`, `tax_rate`|
|**Statutory_Parameters**|`param_id` (PK), `fk_company_id` (FK), `param_name`, `rate`, `effective_date`|
|**Allowance_Types**|`allowance_type_id` (PK), `fk_company_id` (FK), `allowance_name`, `is_taxable`|
|**Deduction_Types**|`deduction_type_id` (PK), `fk_company_id` (FK), `deduction_name`|
|**Attendance_Records**|`attendance_id` (PK), `fk_employee_id` (FK), `fk_company_id` (FK), `record_month`, `record_year`, `worked_days`, `overtime_hours`|
|**Employee_Allowances**|`emp_allowance_id` (PK), `fk_employee_id` (FK), `fk_company_id` (FK), `fk_allowance_type_id`(FK), `amount`, `payment_date`|
|**Employee_Deductions**|`emp_deduction_id` (PK), `fk_employee_id` (FK), `fk_company_id` (FK), `fk_deduction_type_id`(FK), `amount`, `deduction_date`|
|**Payroll_Summary**|`payroll_id` (PK), `fk_employee_id` (FK), `fk_company_id` (FK), `period_month`, `period_year`, `gross_salary`, `net_salary`, `total_tax`, `payment_status`, `payment_date`|
|**Payroll_Logs**|`log_id` (PK), `fk_payroll_id` (FK), `fk_company_id` (FK), `fk_user_id` (FK), `action_type`, `action_timestamp`|
### **Relationship Schema**

Okların yönü ve ilişki tipleri şu mantıkla kurgulanmalıdır:

- **Companies → All Entities:** `1:N` (SaaS yapısı gereği şirket tablosu; Departments, Users, Job_Titles, Employees, Contracts, Tax_Slabs, Allowances, Deductions, Attendance, Payroll ve Logs tablolarının tamamına `fk_company_id`üzerinden bağlanır).
    
- **Departments → Employees:** `1:N` (Bir departmanda birden fazla çalışan bulunur).
    
- **Job_Titles → Employees:** `1:N` (Aynı unvanda birçok çalışan olabilir).
    
- **Employees → Employee_Contracts:** `1:1` (Her çalışanın tek bir aktif sözleşmesi bulunur).
    
- **Employees → Attendance_Records:** `1:N` (Bir çalışan her ay için yeni bir puantaj kaydına sahip olur).
    
- **Employees → Employee_Allowances / Deductions:** `1:N` (Bir çalışana bir ayda birden fazla ek ödeme veya kesinti yapılabilir).
    
- **Allowance_Types → Employee_Allowances:** `1:N` (Bir ödeme türü -örneğin Bonus- birçok kayıtta kullanılabilir).
    
- **Deduction_Types → Employee_Deductions:** `1:N` (Bir kesinti türü birçok kayıtta kullanılabilir).
    
- **Employees → Payroll_Summary:** `1:N` (Bir çalışanın her ay için bir bordro özeti oluşur).
    
- **Payroll_Summary → Payroll_Logs:** `1:N` (Bir bordro işlemi üzerindeki her işlem -oluşturma, güncelleme- log tablosuna kaydedilir).
    
- **Users → Payroll_Logs:** `1:N` (Hangi işlemi hangi kullanıcının yaptığı takip edilir).

Selim'e Notlar:
```
## **1. Hareket Tabloları ve M:N İlişkiler Nerede?**

Aslında sistemin kalbinde hem **hareket (transaction)** tabloları var hem de **M:N (Çok'a Çok)** ilişkileri çözülmüş durumda. Sadece isimleri veya yapıları sana farklı gelmiş olabilir.

### **Hareket (Movement/Transaction) Tabloları**

Veritabanı mantığında "Hareket Tablosu", zaman içinde sürekli yeni kayıt eklenen, bir eylemi (maas ödemesi, mesai girişi vb.) temsil eden tablodur. Bizim tasarımımızda şu tablolar birer hareket tablosudur:

- **`Attendance_Records`**: Her ay personelin çalışma saati değişir; bu bir harekettir.
    
- **`Employee_Allowances` / `Deductions`**: Bir personele o ay özel bir bonus veya kesinti yapılması bir finansal harekettir.
    
- **`Payroll_Summary`**: Bu tablonun kendisi nihai "Bordro Hareketi" tablosudur.
    

### **M:N (Many-to-Many) İlişkiler**

İlişkisel veritabanlarında (Oracle gibi), M:N ilişkiler doğrudan kurulamaz. Bu ilişkiler her zaman bir **"Junction Table" (Bağlantı Tablosu)** ile iki adet `1:N` ilişkiye bölünür.

- **Senaryo:** Bir çalışanın birden fazla ek ödemesi (bonus, yemek, yol) olabilir. Bir ödeme türü de (örneğin "Yemek Yardımı") yüzlerce çalışana verilebilir.
    
- **Çözüm:** `Employees` ve `Allowance_Types` arasındaki M:N ilişkiyi, **`Employee_Allowances`** tablosuyla çözdük.
    
- Yani diyagramda gördüğün "bağlantı tabloları" aslında gizli birer M:N ilişkidir. Mühendislikte "temiz tasarım", bu ilişkileri bu şekilde ayrıştırmayı gerektirir.
    

---

## **2. 3NF (Üçüncü Normal Form) Nedir?**

Veritabanı tasarımının "altın kuralı" olan Normalizasyon, veri tekrarını önlemek ve veri bütünlüğünü korumak için kullanılır. **3NF**'yi basit bir mantıkla şöyle özetleyebiliriz:

> **"Her alan anahtara (Primary Key), anahtarın tamamına ve anahtardan başka hiçbir şeye bağlı olmamalıdır."**

### **3NF'nin 3 Temel Adımı:**

1. **1NF (Atomic Values):** Her hücrede tek bir veri olmalı (Örn: Bir hücreye iki telefon numarası yazılmaz).
    
2. **2NF (Partial Dependency):** Tüm sütunlar Primary Key'e bağlı olmalı. (Bizim tasarımımızda her tablo kendi PK'sine sahip olduğu için bunu sağladık).
    
3. **3NF (Transitive Dependency):** Anahtar olmayan bir sütun, anahtar olmayan başka bir sütuna bağlı **olmamalıdır.**
    

**Bizim Projeden Bir Örnekle 3NF:**

Eğer biz `Employees` tablosuna `Department_Name` yazsaydık, bu 3NF'ye aykırı olurdu. Çünkü `Department_Name`, çalışan ID'sine değil, `Department_ID`'ye bağlıdır.

- **Neden Kaçınıyoruz?** Yarın bir departmanın adı değiştiğinde, 10 bin personelin satırını tek tek güncellemek zorunda kalmamak (Update Anomaly) ve veri tutarsızlığını önlemek için bu bilgiyi ayrı bir `Departments` tablosuna alıyoruz.
    

---

### **Sonuç**

Şu anki şemamızda:

- SaaS yapısıyla şirketleri ayırdık.
    
- M:N ilişkileri bağlantı tablolarıyla (Junction Tables) modernize ettik.
    
- Veri tekrarını 3NF standartlarında minimize ettik.
    
```

# 2. Projenizin tablo oluşturma kodlarını veriniz.

```SQL
-- 1. Companies Tablosu
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

-- 2. Users Tablosu
CREATE TABLE Users (
    user_id NUMBER,
    fk_company_id NUMBER NOT NULL,
    username VARCHAR2(50) NOT NULL,
    password_hash VARCHAR2(255) NOT NULL,
    email VARCHAR2(100),
    role VARCHAR2(30)
);

-- 3. Departments Tablosu
CREATE TABLE Departments (
    department_id NUMBER,
    fk_company_id NUMBER NOT NULL,
    department_name VARCHAR2(100) NOT NULL
);

-- 4. Job_Titles Tablosu
CREATE TABLE Job_Titles (
    job_title_id NUMBER,
    fk_company_id NUMBER NOT NULL,
    title_name VARCHAR2(100) NOT NULL,
    min_base_salary NUMBER(15, 2)
);

-- 5. Employees Tablosu
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

-- 6. Employee_Contracts Tablosu
CREATE TABLE Employee_Contracts (
    contract_id NUMBER,
    fk_employee_id NUMBER NOT NULL,
    fk_company_id NUMBER NOT NULL,
    salary_multiplier NUMBER(5, 4) DEFAULT 1.0, -- Örn: 1.10 (%10 zam)
    additional_fixed_salary NUMBER(15, 2) DEFAULT 0,
    contract_start_date DATE NOT NULL,
    contract_end_date DATE,
    is_active NUMBER(1) DEFAULT 1 -- 1: Aktif, 0: Pasif (Oracle'da Boolean yerine Number(1) kullanılır)
);

-- 7. Tax_Slabs Tablosu
CREATE TABLE Tax_Slabs (
    slab_id NUMBER,
    fk_company_id NUMBER, -- Global vergi dilimi ise NULL bırakılabilir
    min_income NUMBER(15, 2) NOT NULL,
    max_income NUMBER(15, 2),
    tax_rate NUMBER(5, 2) NOT NULL
);

-- 8. Statutory_Parameters Tablosu
CREATE TABLE Statutory_Parameters (
    param_id NUMBER,
    fk_company_id NUMBER,
    param_name VARCHAR2(100) NOT NULL,
    rate NUMBER(5, 4) NOT NULL,
    effective_date DATE NOT NULL
);

-- 9. Allowance_Types Tablosu
CREATE TABLE Allowance_Types (
    allowance_type_id NUMBER,
    fk_company_id NUMBER NOT NULL,
    allowance_name VARCHAR2(100) NOT NULL,
    is_taxable NUMBER(1) DEFAULT 1
);

-- 10. Deduction_Types Tablosu
CREATE TABLE Deduction_Types (
    deduction_type_id NUMBER,
    fk_company_id NUMBER NOT NULL,
    deduction_name VARCHAR2(100) NOT NULL
);

-- 11. Attendance_Records Tablosu
CREATE TABLE Attendance_Records (
    attendance_id NUMBER,
    fk_employee_id NUMBER NOT NULL,
    fk_company_id NUMBER NOT NULL,
    record_month NUMBER(2) NOT NULL,
    record_year NUMBER(4) NOT NULL,
    worked_days NUMBER(4, 1) DEFAULT 0,
    overtime_hours NUMBER(5, 1) DEFAULT 0
);

-- 12. Employee_Allowances Tablosu
CREATE TABLE Employee_Allowances (
    emp_allowance_id NUMBER,
    fk_employee_id NUMBER NOT NULL,
    fk_company_id NUMBER NOT NULL,
    fk_allowance_type_id NUMBER NOT NULL,
    amount NUMBER(15, 2) NOT NULL,
    payment_date DATE NOT NULL
);

-- 13. Employee_Deductions Tablosu
CREATE TABLE Employee_Deductions (
    emp_deduction_id NUMBER,
    fk_employee_id NUMBER NOT NULL,
    fk_company_id NUMBER NOT NULL,
    fk_deduction_type_id NUMBER NOT NULL,
    amount NUMBER(15, 2) NOT NULL,
    deduction_date DATE NOT NULL
);

-- 14. Payroll_Summary Tablosu
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

-- 15. Payroll_Logs Tablosu
CREATE TABLE Payroll_Logs (
    log_id NUMBER,
    fk_payroll_id NUMBER NOT NULL,
    fk_company_id NUMBER NOT NULL,
    fk_user_id NUMBER,
    action_type VARCHAR2(50) NOT NULL,
    action_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

# 3. Projenizin indekslerini(birincil, yabancı veya bileşik anahtarlar) oluşturan kodları geliştiriniz.

```SQL
-- ==========================================
-- 1. PRIMARY KEY (BİRİNCİL ANAHTAR) TANIMLAMALARI
-- ==========================================

ALTER TABLE Companies ADD CONSTRAINT pk_companies PRIMARY KEY (company_id);
ALTER TABLE Users ADD CONSTRAINT pk_users PRIMARY KEY (user_id);
ALTER TABLE Departments ADD CONSTRAINT pk_departments PRIMARY KEY (department_id);
ALTER TABLE Job_Titles ADD CONSTRAINT pk_job_titles PRIMARY KEY (job_title_id);
ALTER TABLE Employees ADD CONSTRAINT pk_employees PRIMARY KEY (employee_id);
ALTER TABLE Employee_Contracts ADD CONSTRAINT pk_contracts PRIMARY KEY (contract_id);
ALTER TABLE Tax_Slabs ADD CONSTRAINT pk_tax_slabs PRIMARY KEY (slab_id);
ALTER TABLE Statutory_Parameters ADD CONSTRAINT pk_stat_params PRIMARY KEY (param_id);
ALTER TABLE Allowance_Types ADD CONSTRAINT pk_allowance_types PRIMARY KEY (allowance_type_id);
ALTER TABLE Deduction_Types ADD CONSTRAINT pk_deduction_types PRIMARY KEY (deduction_type_id);
ALTER TABLE Attendance_Records ADD CONSTRAINT pk_attendance PRIMARY KEY (attendance_id);
ALTER TABLE Employee_Allowances ADD CONSTRAINT pk_emp_allowances PRIMARY KEY (emp_allowance_id);
ALTER TABLE Employee_Deductions ADD CONSTRAINT pk_emp_deductions PRIMARY KEY (emp_deduction_id);
ALTER TABLE Payroll_Summary ADD CONSTRAINT pk_payroll_summary PRIMARY KEY (payroll_id);
ALTER TABLE Payroll_Logs ADD CONSTRAINT pk_payroll_logs PRIMARY KEY (log_id);


-- ==========================================
-- 2. FOREIGN KEY (YABANCI ANAHTAR) TANIMLAMALARI
-- ==========================================

-- Users
ALTER TABLE Users ADD CONSTRAINT fk_user_company FOREIGN KEY (fk_company_id) REFERENCES Companies(company_id);

-- Departments
ALTER TABLE Departments ADD CONSTRAINT fk_dept_company FOREIGN KEY (fk_company_id) REFERENCES Companies(company_id);

-- Job Titles
ALTER TABLE Job_Titles ADD CONSTRAINT fk_job_company FOREIGN KEY (fk_company_id) REFERENCES Companies(company_id);

-- Employees
ALTER TABLE Employees ADD CONSTRAINT fk_emp_company FOREIGN KEY (fk_company_id) REFERENCES Companies(company_id);
ALTER TABLE Employees ADD CONSTRAINT fk_emp_dept FOREIGN KEY (fk_department_id) REFERENCES Departments(department_id);
ALTER TABLE Employees ADD CONSTRAINT fk_emp_job FOREIGN KEY (fk_job_title_id) REFERENCES Job_Titles(job_title_id);

-- Employee Contracts
ALTER TABLE Employee_Contracts ADD CONSTRAINT fk_cont_emp FOREIGN KEY (fk_employee_id) REFERENCES Employees(employee_id);
ALTER TABLE Employee_Contracts ADD CONSTRAINT fk_cont_company FOREIGN KEY (fk_company_id) REFERENCES Companies(company_id);

-- Tax Slabs & Statutory Parameters (SaaS Yapısı)
ALTER TABLE Tax_Slabs ADD CONSTRAINT fk_tax_company FOREIGN KEY (fk_company_id) REFERENCES Companies(company_id);
ALTER TABLE Statutory_Parameters ADD CONSTRAINT fk_stat_company FOREIGN KEY (fk_company_id) REFERENCES Companies(company_id);

-- Allowances & Deductions Types
ALTER TABLE Allowance_Types ADD CONSTRAINT fk_alw_type_company FOREIGN KEY (fk_company_id) REFERENCES Companies(company_id);
ALTER TABLE Deduction_Types ADD CONSTRAINT fk_ded_type_company FOREIGN KEY (fk_company_id) REFERENCES Companies(company_id);

-- Attendance Records
ALTER TABLE Attendance_Records ADD CONSTRAINT fk_att_emp FOREIGN KEY (fk_employee_id) REFERENCES Employees(employee_id);
ALTER TABLE Attendance_Records ADD CONSTRAINT fk_att_company FOREIGN KEY (fk_company_id) REFERENCES Companies(company_id);

-- Employee Allowances
ALTER TABLE Employee_Allowances ADD CONSTRAINT fk_ea_emp FOREIGN KEY (fk_employee_id) REFERENCES Employees(employee_id);
ALTER TABLE Employee_Allowances ADD CONSTRAINT fk_ea_company FOREIGN KEY (fk_company_id) REFERENCES Companies(company_id);
ALTER TABLE Employee_Allowances ADD CONSTRAINT fk_ea_type FOREIGN KEY (fk_allowance_type_id) REFERENCES Allowance_Types(allowance_type_id);

-- Employee Deductions
ALTER TABLE Employee_Deductions ADD CONSTRAINT fk_ed_emp FOREIGN KEY (fk_employee_id) REFERENCES Employees(employee_id);
ALTER TABLE Employee_Deductions ADD CONSTRAINT fk_ed_company FOREIGN KEY (fk_company_id) REFERENCES Companies(company_id);
ALTER TABLE Employee_Deductions ADD CONSTRAINT fk_ed_type FOREIGN KEY (fk_deduction_type_id) REFERENCES Deduction_Types(deduction_type_id);

-- Payroll Summary
ALTER TABLE Payroll_Summary ADD CONSTRAINT fk_pay_emp FOREIGN KEY (fk_employee_id) REFERENCES Employees(employee_id);
ALTER TABLE Payroll_Summary ADD CONSTRAINT fk_pay_company FOREIGN KEY (fk_company_id) REFERENCES Companies(company_id);

-- Payroll Logs
ALTER TABLE Payroll_Logs ADD CONSTRAINT fk_log_payroll FOREIGN KEY (fk_payroll_id) REFERENCES Payroll_Summary(payroll_id);
ALTER TABLE Payroll_Logs ADD CONSTRAINT fk_log_company FOREIGN KEY (fk_company_id) REFERENCES Companies(company_id);
ALTER TABLE Payroll_Logs ADD CONSTRAINT fk_log_user FOREIGN KEY (fk_user_id) REFERENCES Users(user_id);


-- ==========================================
-- 3. PERFORMANS İÇİN COMPOSITE (BİLEŞİK) VE FK İNDEKS TANIMLAMALARI
-- ==========================================

-- Aynı şirkette aynı TCKN ile birden fazla personel açılamaması için (Bileşik Unique İndeks)
ALTER TABLE Employees ADD CONSTRAINT uq_emp_national_id UNIQUE (fk_company_id, national_id);
ALTER TABLE Employees ADD CONSTRAINT uq_emp_code UNIQUE (fk_company_id, employee_code);

-- Aynı personelin, aynı ay ve yıl için sadece bir tane puantaj kaydı olabilmesi için (Bileşik Unique İndeks)
ALTER TABLE Attendance_Records ADD CONSTRAINT uq_attendance_period UNIQUE (fk_employee_id, record_month, record_year);

-- Aynı personelin, aynı ay ve yıl için sadece bir bordrosu olabilmesi için
ALTER TABLE Payroll_Summary ADD CONSTRAINT uq_payroll_period UNIQUE (fk_employee_id, period_month, period_year);

-- Sorgulama performansını artırmak için sık kullanılan Foreign Key indeksleri
CREATE INDEX idx_emp_dept ON Employees(fk_department_id);
CREATE INDEX idx_emp_job ON Employees(fk_job_title_id);
CREATE INDEX idx_att_emp ON Attendance_Records(fk_employee_id);
CREATE INDEX idx_payroll_emp ON Payroll_Summary(fk_employee_id);
```
# 4. Projenizin veri girişini bir PL/SQL paketten çağrılabilen bir kod aracılığı(prosedür veya fonksiyon) ile gerçekleştiriniz.

## 4.1.  PL/SQL Paket Tanımı (Specification)

```PLSQL
CREATE OR REPLACE PACKAGE pkg_payroll_entry AS
    -- Şirket Ekleme
    PROCEDURE add_company(p_company_id NUMBER, p_name VARCHAR2, p_email VARCHAR2);
    
    -- Departman Ekleme
    PROCEDURE add_department(p_dept_id NUMBER, p_company_id NUMBER, p_name VARCHAR2);
    
    -- Unvan Ekleme
    PROCEDURE add_job_title(p_job_id NUMBER, p_company_id NUMBER, p_title VARCHAR2, p_base_salary NUMBER);
    
    -- Kullanıcı (Sisteme Giriş Yapacak Kişi) Ekleme
    PROCEDURE add_user(p_user_id NUMBER, p_company_id NUMBER, p_username VARCHAR2, p_email VARCHAR2, p_role VARCHAR2);
    
    -- Çalışan Ekleme
    PROCEDURE add_employee(p_emp_id NUMBER, p_company_id NUMBER, p_dept_id NUMBER, p_job_id NUMBER, p_national_id VARCHAR2, p_first_name VARCHAR2, p_last_name VARCHAR2);
    
    -- Çalışan Sözleşmesi Ekleme
    PROCEDURE add_contract(p_contract_id NUMBER, p_emp_id NUMBER, p_company_id NUMBER, p_multiplier NUMBER);
END pkg_payroll_entry;
/
```

## 4.2. PL/SQL Paket Gövdesi (Body)

```PLSQL
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

    PROCEDURE add_job_title(p_job_id NUMBER, p_company_id NUMBER, p_title VARCHAR2, p_base_salary NUMBER) IS
    BEGIN
        INSERT INTO Job_Titles (job_title_id, fk_company_id, title_name, min_base_salary) 
        VALUES (p_job_id, p_company_id, p_title, p_base_salary);
    END add_job_title;

    PROCEDURE add_user(p_user_id NUMBER, p_company_id NUMBER, p_username VARCHAR2, p_email VARCHAR2, p_role VARCHAR2) IS
    BEGIN
        -- Parola gerçek senaryoda hashlenir, burada basit geçiyoruz.
        INSERT INTO Users (user_id, fk_company_id, username, password_hash, email, role) 
        VALUES (p_user_id, p_company_id, p_username, 'HASHED_PWD', p_email, p_role);
    END add_user;

    PROCEDURE add_employee(p_emp_id NUMBER, p_company_id NUMBER, p_dept_id NUMBER, p_job_id NUMBER, p_national_id VARCHAR2, p_first_name VARCHAR2, p_last_name VARCHAR2) IS
    BEGIN
        INSERT INTO Employees (employee_id, fk_company_id, fk_department_id, fk_job_title_id, employee_code, national_id, first_name, last_name, hire_date) 
        VALUES (p_emp_id, p_company_id, p_dept_id, p_job_id, 'EMP'||p_emp_id, p_national_id, p_first_name, p_last_name, SYSDATE);
    END add_employee;

    PROCEDURE add_contract(p_contract_id NUMBER, p_emp_id NUMBER, p_company_id NUMBER, p_multiplier NUMBER) IS
    BEGIN
        INSERT INTO Employee_Contracts (contract_id, fk_employee_id, fk_company_id, salary_multiplier, contract_start_date) 
        VALUES (p_contract_id, p_emp_id, p_company_id, p_multiplier, SYSDATE);
    END add_contract;

END pkg_payroll_entry;
/
```

## 4.3. Veri Girişi İşlemi (Paketi Çağıran Ana Blok)

```PLSQL
DECLARE
    v_comp_id NUMBER;
    v_dept_id NUMBER := 100;
    v_job_id NUMBER := 200;
    v_emp_id NUMBER := 300;
    v_contract_id NUMBER := 400;
    v_user_id NUMBER := 500;
    
    -- Geçici değişkenler
    v_current_dept NUMBER;
    v_current_job NUMBER;
    v_tckn_base NUMBER := 10000000000;
BEGIN
    -- 4 ŞİRKET VE CEO'LARININ EKLENMESİ
    
    -- 1. İsa Mirza Sincap - IMSA
    pkg_payroll_entry.add_company(1, 'IMSA', 'mirzasincap@gmail.com');
    pkg_payroll_entry.add_department(1, 1, 'Executive Board');
    pkg_payroll_entry.add_job_title(1, 1, 'CEO', 500000);
    pkg_payroll_entry.add_user(1, 1, 'isasmirza', 'mirzasincap@gmail.com', 'Admin');
    pkg_payroll_entry.add_employee(1, 1, 1, 1, '23120205033', 'Isa Mirza', 'Sincap');
    pkg_payroll_entry.add_contract(1, 1, 1, 1.0);

    -- 2. Mirza Sakiroglu - MISA
    pkg_payroll_entry.add_company(2, 'MISA', 'mirzasakiroglu@gmail.com');
    pkg_payroll_entry.add_department(2, 2, 'Executive Board');
    pkg_payroll_entry.add_job_title(2, 2, 'CEO', 500000);
    pkg_payroll_entry.add_user(2, 2, 'mirzas', 'mirzasakiroglu@gmail.com', 'Admin');
    pkg_payroll_entry.add_employee(2, 2, 2, 2, '23120205028', 'Mirza', 'Sakiroglu');
    pkg_payroll_entry.add_contract(2, 2, 2, 1.0);

    -- 3. Selim Genc - SIMA
    pkg_payroll_entry.add_company(3, 'SIMA', 'selingnc44@gmail.com');
    pkg_payroll_entry.add_department(3, 3, 'Executive Board');
    pkg_payroll_entry.add_job_title(3, 3, 'CEO', 500000);
    pkg_payroll_entry.add_user(3, 3, 'selimg', 'selingnc44@gmail.com', 'Admin');
    pkg_payroll_entry.add_employee(3, 3, 3, 3, '23120205034', 'Selim', 'Genc');
    pkg_payroll_entry.add_contract(3, 3, 3, 1.0);

    -- 4. Ali Emre Aydin - AIMS
    pkg_payroll_entry.add_company(4, 'AIMS', 'aliemreaydin111@gmail.com');
    pkg_payroll_entry.add_department(4, 4, 'Executive Board');
    pkg_payroll_entry.add_job_title(4, 4, 'CEO', 500000);
    pkg_payroll_entry.add_user(4, 4, 'aliemrea', 'aliemreaydin111@gmail.com', 'Admin');
    pkg_payroll_entry.add_employee(4, 4, 4, 4, '23120205056', 'Ali Emre', 'Aydin');
    pkg_payroll_entry.add_contract(4, 4, 4, 1.0);


    -- HER ŞİRKETE 6 UNVAN, 3 DEPARTMAN VE 30 ÇALIŞAN EKLENMESİ (DÖNGÜ)
    FOR v_comp_id IN 1..4 LOOP
        
        -- Şirket başına standart departmanlar
        pkg_payroll_entry.add_department(v_dept_id, v_comp_id, 'Engineering');
        pkg_payroll_entry.add_department(v_dept_id + 1, v_comp_id, 'Human Resources');
        pkg_payroll_entry.add_department(v_dept_id + 2, v_comp_id, 'Sales');
        
        -- Şirket başına standart unvanlar ve baz maaşlar
        pkg_payroll_entry.add_job_title(v_job_id, v_comp_id, 'Senior Software Engineer', 120000);
        pkg_payroll_entry.add_job_title(v_job_id + 1, v_comp_id, 'Junior Software Engineer', 60000);
        pkg_payroll_entry.add_job_title(v_job_id + 2, v_comp_id, 'HR Manager', 85000);
        pkg_payroll_entry.add_job_title(v_job_id + 3, v_comp_id, 'HR Specialist', 45000);
        pkg_payroll_entry.add_job_title(v_job_id + 4, v_comp_id, 'Sales Director', 100000);
        pkg_payroll_entry.add_job_title(v_job_id + 5, v_comp_id, 'Sales Representative', 40000);
        
        -- Her şirket için 30 çalışan oluştur
        FOR i IN 1..30 LOOP
            -- Rastgele departman ve unvan seçimi için basit modüler aritmetik
            v_current_dept := v_dept_id + MOD(i, 3);
            v_current_job := v_job_id + MOD(i, 6);
            
            pkg_payroll_entry.add_employee(
                v_emp_id, 
                v_comp_id, 
                v_current_dept, 
                v_current_job, 
                TO_CHAR(v_tckn_base + v_emp_id), -- Benzersiz TCKN
                'Person' || v_emp_id, 
                'Surname' || v_emp_id
            );
            
            -- Çalışan Sözleşmesi (Rastgele çarpan: 1.0 ile 1.2 arası)
            pkg_payroll_entry.add_contract(v_contract_id, v_emp_id, v_comp_id, 1.0 + (MOD(i, 3)/10));
            
            v_emp_id := v_emp_id + 1;
            v_contract_id := v_contract_id + 1;
        END LOOP;
        
        -- ID'leri bir sonraki şirket için ilerlet
        v_dept_id := v_dept_id + 10;
        v_job_id := v_job_id + 10;
    END LOOP;
    
    COMMIT;
END;
/
```

# 5.  Projenizin veri güncellemesini bir PL/SQL paketten çağrılabilen bir kod aracılığı(prosedür veya fonksiyon) ile gerçekleştiriniz.

## 5.1. Güncelleme Paketi Tanımı (Specification)

```PLSQL
CREATE OR REPLACE PACKAGE pkg_payroll_update AS
    
    -- 1. Personel Terfi veya Departman Değişikliği
    PROCEDURE update_employee_job(
        p_employee_id NUMBER, 
        p_company_id NUMBER, 
        p_new_dept_id NUMBER, 
        p_new_job_id NUMBER
    );
    
    -- 2. Maaş Sözleşmesi Güncellemesi (Zam Yapılması)
    PROCEDURE update_contract_salary(
        p_employee_id NUMBER, 
        p_company_id NUMBER, 
        p_new_multiplier NUMBER, 
        p_new_fixed_salary NUMBER
    );
    
    -- 3. Hatalı Girilen Puantajı (Mesai/Çalışma Günü) Düzeltme
    PROCEDURE update_attendance(
        p_attendance_id NUMBER, 
        p_employee_id NUMBER, 
        p_company_id NUMBER, 
        p_new_worked_days NUMBER, 
        p_new_overtime_hours NUMBER
    );

END pkg_payroll_update;
/
```

## 5.2. Güncelleme Paketi Gövdesi (Body)

```PLSQL
CREATE OR REPLACE PACKAGE BODY pkg_payroll_update AS

    -- 1. Personel Terfi İşlemi
    PROCEDURE update_employee_job(
        p_employee_id NUMBER, 
        p_company_id NUMBER, 
        p_new_dept_id NUMBER, 
        p_new_job_id NUMBER
    ) IS
    BEGIN
        UPDATE Employees
        SET fk_department_id = p_new_dept_id,
            fk_job_title_id = p_new_job_id
        WHERE employee_id = p_employee_id 
          AND fk_company_id = p_company_id; -- Güvenlik kısıtı: Sadece kendi şirketinin personeli
          
        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20001, 'Personel bulunamadı veya bu şirkete ait değil.');
        END IF;
    END update_employee_job;

    -- 2. Maaş Sözleşmesi Güncellemesi
    PROCEDURE update_contract_salary(
        p_employee_id NUMBER, 
        p_company_id NUMBER, 
        p_new_multiplier NUMBER, 
        p_new_fixed_salary NUMBER
    ) IS
    BEGIN
        UPDATE Employee_Contracts
        SET salary_multiplier = p_new_multiplier,
            additional_fixed_salary = p_new_fixed_salary
        WHERE fk_employee_id = p_employee_id 
          AND fk_company_id = p_company_id
          AND is_active = 1; -- Sadece aktif sözleşme güncellenir
          
        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20002, 'Aktif sözleşme bulunamadı veya yetkisiz işlem.');
        END IF;
    END update_contract_salary;

    -- 3. Puantaj Düzeltmesi
    PROCEDURE update_attendance(
        p_attendance_id NUMBER, 
        p_employee_id NUMBER, 
        p_company_id NUMBER, 
        p_new_worked_days NUMBER, 
        p_new_overtime_hours NUMBER
    ) IS
    BEGIN
        UPDATE Attendance_Records
        SET worked_days = p_new_worked_days,
            overtime_hours = p_new_overtime_hours
        WHERE attendance_id = p_attendance_id 
          AND fk_employee_id = p_employee_id
          AND fk_company_id = p_company_id;
          
        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20003, 'Puantaj kaydı bulunamadı veya şirket eşleşmiyor.');
        END IF;
    END update_attendance;

END pkg_payroll_update;
/
```

## 5.3. Örnek Kullanım (Test Bloğu)

```PLSQL
BEGIN
    -- IMSA şirketindeki (ID:1) 1 numaralı personelin departmanını(ID:2) ve unvanını(ID:2) değiştir
    pkg_payroll_update.update_employee_job(
        p_employee_id => 1, 
        p_company_id => 1, 
        p_new_dept_id => 2, 
        p_new_job_id => 2
    );

    -- Aynı personelin maaş çarpanını 1.50 (%50 zam) ve sabit ek ödemesini 10000 yap
    pkg_payroll_update.update_contract_salary(
        p_employee_id => 1, 
        p_company_id => 1, 
        p_new_multiplier => 1.50, 
        p_new_fixed_salary => 10000
    );
    
    COMMIT;
END;
/
```

# 6. Projenizin veri silme işlemini bir PL/SQL paketten çağrılabilen bir kod aracılığı(prosedür veya fonksiyon) ile gerçekleştiriniz.

## 6.1. Silme Paketi Tanımı (Specification)

```PLSQL
CREATE OR REPLACE PACKAGE pkg_payroll_delete AS
    
    -- 1. Personeli ve ona bağlı tüm hareket/sözleşme kayıtlarını hiyerarşik olarak siler
    PROCEDURE delete_employee(p_employee_id NUMBER, p_company_id NUMBER);
    
    -- 2. Hatalı girilen bir ek ödemeyi siler (Örn: Yanlışlıkla verilen bonus)
    PROCEDURE delete_allowance(p_emp_allowance_id NUMBER, p_company_id NUMBER);
    
    -- 3. Hatalı hesaplanmış bir bordroyu ve ona bağlı logları siler
    PROCEDURE delete_payroll(p_payroll_id NUMBER, p_company_id NUMBER);

END pkg_payroll_delete;
/
```

## 6.2. Silme Paketi Gövdesi (Body)
```PLSQL
CREATE OR REPLACE PACKAGE BODY pkg_payroll_delete AS

    -- 1. Hiyerarşik Personel Silme
    PROCEDURE delete_employee(p_employee_id NUMBER, p_company_id NUMBER) IS
    BEGIN
        -- Adım 1: Logları ve Bordro Özetini Sil (En alt katman)
        DELETE FROM Payroll_Logs 
        WHERE fk_payroll_id IN (
            SELECT payroll_id FROM Payroll_Summary 
            WHERE fk_employee_id = p_employee_id AND fk_company_id = p_company_id
        );
        DELETE FROM Payroll_Summary 
        WHERE fk_employee_id = p_employee_id AND fk_company_id = p_company_id;

        -- Adım 2: Ek Ödeme, Kesinti ve Puantajları Sil (Hareket tabloları)
        DELETE FROM Employee_Allowances 
        WHERE fk_employee_id = p_employee_id AND fk_company_id = p_company_id;
        
        DELETE FROM Employee_Deductions 
        WHERE fk_employee_id = p_employee_id AND fk_company_id = p_company_id;
        
        DELETE FROM Attendance_Records 
        WHERE fk_employee_id = p_employee_id AND fk_company_id = p_company_id;

        -- Adım 3: Sözleşmeyi Sil
        DELETE FROM Employee_Contracts 
        WHERE fk_employee_id = p_employee_id AND fk_company_id = p_company_id;

        -- Adım 4: Personeli Ana Tablodan Sil
        DELETE FROM Employees 
        WHERE employee_id = p_employee_id AND fk_company_id = p_company_id;

        -- Eğer hiçbir satır silinmediyse (personel yoksa veya şirket yanlışsa) hata fırlat
        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20004, 'Silinecek personel bulunamadı veya yetkisiz şirket işlemi.');
        END IF;
    END delete_employee;

    -- 2. Ek Ödeme Silme
    PROCEDURE delete_allowance(p_emp_allowance_id NUMBER, p_company_id NUMBER) IS
    BEGIN
        DELETE FROM Employee_Allowances
        WHERE emp_allowance_id = p_emp_allowance_id
          AND fk_company_id = p_company_id;

        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20005, 'Ek ödeme kaydı bulunamadı.');
        END IF;
    END delete_allowance;

    -- 3. Bordro ve Log Silme
    PROCEDURE delete_payroll(p_payroll_id NUMBER, p_company_id NUMBER) IS
    BEGIN
        -- Önce logları sil (Foreign Key kısıtlamasını aşmak için)
        DELETE FROM Payroll_Logs WHERE fk_payroll_id = p_payroll_id AND fk_company_id = p_company_id;

        -- Sonra bordroyu sil
        DELETE FROM Payroll_Summary WHERE payroll_id = p_payroll_id AND fk_company_id = p_company_id;

        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20006, 'Bordro kaydı bulunamadı.');
        END IF;
    END delete_payroll;

END pkg_payroll_delete;
/
```

## 6.3. Örnek Kullanım (Test Bloğu)

```PLSQL
BEGIN
    pkg_payroll_delete.delete_employee(
        p_employee_id => 300, 
        p_company_id => 1
    );
    
    COMMIT;
END;
/
```

# 7.  PL/SQL tetik(trigger) yardımı ile bir tanım tablosuna veri girişi yapılırken, hareket tablosuna da veri girişini sağlayınız.

Adım 7'de, veritabanı seviyesinde otomasyon ve denetim (audit) sağlamak amacıyla iki kritik tetikleyici (trigger) mekanizması kurduk. İlk olarak, insan kaynakları operasyonlarında sıkça karşılaşılan "yeni personelin puantaj listesine eklenmesinin unutulması" operasyonel hatasını rasyonel bir yaklaşımla tamamen ortadan kaldırdık. `Employees` (Tanım) tablosuna yeni bir çalışan eklendiği anda devreye giren `trg_after_emp_insert` tetikleyicisi, o personelin içinde bulunduğumuz aya ait `Attendance_Records` (Hareket) puantaj kaydını sıfır değerlerle otomatik olarak açar. Bu sayede veri tutarlılığı insan inisiyatifine bırakılmadan güvence altına alınır.

İkinci olarak, sistemin veri güvenliği ve izlenebilirlik gereksinimlerini karşılamak üzere ana bordro tablosu üzerinde bir denetim mekanizması inşa ettik. `trg_payroll_audit` tetikleyicisi, `Payroll_Summary` tablosunda yapılan tüm ekleme (INSERT), güncelleme (UPDATE) ve silme (DELETE) işlemlerini anında yakalayarak `Payroll_Logs` tablosuna işlem tipi ve zaman damgasıyla (timestamp) yazar. Bu loglama mimarisi, birden fazla şirkete hizmet veren bir SaaS sisteminde olası finansal hataları veya yetkisiz müdahaleleri geriye dönük olarak kesin bir şekilde takip edebilmek için zorunlu bir mühendislik standardıdır.

```PLSQL
-- ==========================================
-- 1. PUANTAJ (ATTENDANCE) OTOMASYONU
-- ==========================================
-- Personel (Employees) tablosuna yeni kayıt atıldığında o ayki puantaj kaydını otomatik açar.

CREATE SEQUENCE seq_attendance_id 
START WITH 10000 
INCREMENT BY 1;
/

CREATE OR REPLACE TRIGGER trg_after_emp_insert
AFTER INSERT ON Employees
FOR EACH ROW
DECLARE
    v_current_month NUMBER;
    v_current_year NUMBER;
BEGIN
    -- Sistemin o anki ay ve yıl bilgisini al
    v_current_month := EXTRACT(MONTH FROM SYSDATE);
    v_current_year := EXTRACT(YEAR FROM SYSDATE);
    
    -- Yeni personel için sıfır değerli puantaj kaydını oluştur
    INSERT INTO Attendance_Records (
        attendance_id, 
        fk_employee_id, 
        fk_company_id, 
        record_month, 
        record_year, 
        worked_days, 
        overtime_hours
    ) VALUES (
        seq_attendance_id.NEXTVAL,
        :NEW.employee_id,
        :NEW.fk_company_id,
        v_current_month,
        v_current_year,
        0,
        0
    );
END;
/

-- ==========================================
-- 2. DENETİM (AUDIT LOG) OTOMASYONU
-- ==========================================
-- Bordro (Payroll_Summary) tablosunda yapılan DML (Insert/Update/Delete) işlemlerini loglar.

CREATE SEQUENCE seq_payroll_log_id 
START WITH 1000 
INCREMENT BY 1;
/

CREATE OR REPLACE TRIGGER trg_payroll_audit
AFTER INSERT OR UPDATE OR DELETE ON Payroll_Summary
FOR EACH ROW
DECLARE
    v_action_type VARCHAR2(50);
    v_target_payroll_id NUMBER;
    v_target_company_id NUMBER;
BEGIN
    -- Yapılan işlemin türünü Oracle dahili değişkenleriyle tespit et
    IF INSERTING THEN
        v_action_type := 'INSERT - YENI BORDRO HESAPLANDI';
        v_target_payroll_id := :NEW.payroll_id;
        v_target_company_id := :NEW.fk_company_id;
        
    ELSIF UPDATING THEN
        v_action_type := 'UPDATE - BORDRO RAKAMLARI DEGISTIRILDI';
        v_target_payroll_id := :NEW.payroll_id;
        v_target_company_id := :NEW.fk_company_id;
        
    ELSIF DELETING THEN
        v_action_type := 'DELETE - BORDRO IPTAL EDILDI';
        v_target_payroll_id := :OLD.payroll_id;
        v_target_company_id := :OLD.fk_company_id;
    END IF;

    -- Tespit edilen hareketi Payroll_Logs tablosuna yaz
    INSERT INTO Payroll_Logs (
        log_id, 
        fk_payroll_id, 
        fk_company_id, 
        fk_user_id, 
        action_type, 
        action_timestamp
    ) VALUES (
        seq_payroll_log_id.NEXTVAL,
        v_target_payroll_id,
        v_target_company_id,
        NULL, -- Tetikleyici veritabanı seviyesinde çalıştığı için uygulama kullanıcısı boş geçilir
        CURRENT_TIMESTAMP
    );
END;
/
```

# 8. Rapor alabilmek için PL/SQL yardımı ile bir çok sorgu kod parçacığı yazınız. Select deyimlerinin Where kriterine dinamik olarak kısıt yollayınız.

## 8.1. Raporlama Paketi Tanımı (Specification)

```PLSQL
CREATE OR REPLACE PACKAGE pkg_payroll_reports AS
    
    -- 1. Dinamik Çalışan Raporu (Departman veya Unvan filtresi opsiyoneldir)
    FUNCTION get_employee_report(
        p_company_id NUMBER,
        p_department_id NUMBER DEFAULT NULL,
        p_job_title_id NUMBER DEFAULT NULL
    ) RETURN SYS_REFCURSOR;
    
    -- 2. Dinamik Aylık Bordro Raporu (Belirli bir personel veya tüm şirket için)
    FUNCTION get_monthly_payroll(
        p_company_id NUMBER,
        p_period_month NUMBER,
        p_period_year NUMBER,
        p_employee_id NUMBER DEFAULT NULL
    ) RETURN SYS_REFCURSOR;

END pkg_payroll_reports;
/
```

## 8.2. Raporlama Paketi Gövdesi (Body)

```PLSQL
CREATE OR REPLACE PACKAGE BODY pkg_payroll_reports AS

    -- 1. Dinamik Çalışan Raporu
    FUNCTION get_employee_report(
        p_company_id NUMBER,
        p_department_id NUMBER DEFAULT NULL,
        p_job_title_id NUMBER DEFAULT NULL
    ) RETURN SYS_REFCURSOR 
    IS
        v_sql VARCHAR2(4000);
        v_cursor SYS_REFCURSOR;
    BEGIN
        -- Temel sorgu ve zorunlu şirket kısıtı (SaaS güvenliği için)
        v_sql := 'SELECT e.employee_code, e.national_id, e.first_name, e.last_name, ' ||
                 'd.department_name, j.title_name, c.salary_multiplier ' ||
                 'FROM Employees e ' ||
                 'JOIN Departments d ON e.fk_department_id = d.department_id ' ||
                 'JOIN Job_Titles j ON e.fk_job_title_id = j.job_title_id ' ||
                 'JOIN Employee_Contracts c ON e.employee_id = c.fk_employee_id ' ||
                 'WHERE e.fk_company_id = ' || p_company_id || ' AND c.is_active = 1';
        
        -- Dinamik Kısıt 1: Departman filtresi geldiyse WHERE cümlesine ekle
        IF p_department_id IS NOT NULL THEN
            v_sql := v_sql || ' AND e.fk_department_id = ' || p_department_id;
        END IF;
        
        -- Dinamik Kısıt 2: Unvan filtresi geldiyse WHERE cümlesine ekle
        IF p_job_title_id IS NOT NULL THEN
            v_sql := v_sql || ' AND e.fk_job_title_id = ' || p_job_title_id;
        END IF;
        
        -- Sorguyu sıraya koy (ORDER BY)
        v_sql := v_sql || ' ORDER BY e.first_name, e.last_name';
        
        -- Dinamik SQL'i çalıştır ve imleci (cursor) döndür
        OPEN v_cursor FOR v_sql;
        RETURN v_cursor;
    END get_employee_report;

    -- 2. Dinamik Aylık Bordro Raporu
    FUNCTION get_monthly_payroll(
        p_company_id NUMBER,
        p_period_month NUMBER,
        p_period_year NUMBER,
        p_employee_id NUMBER DEFAULT NULL
    ) RETURN SYS_REFCURSOR 
    IS
        v_sql VARCHAR2(4000);
        v_cursor SYS_REFCURSOR;
    BEGIN
        -- Temel sorgu (Belirli bir ay ve yıl için)
        v_sql := 'SELECT p.payroll_id, e.first_name || '' '' || e.last_name AS full_name, ' ||
                 'p.gross_salary, p.total_tax, p.net_salary, p.payment_status ' ||
                 'FROM Payroll_Summary p ' ||
                 'JOIN Employees e ON p.fk_employee_id = e.employee_id ' ||
                 'WHERE p.fk_company_id = ' || p_company_id || 
                 ' AND p.period_month = ' || p_period_month || 
                 ' AND p.period_year = ' || p_period_year;
                 
        -- Dinamik Kısıt: Eğer tek bir personele ait döküm isteniyorsa
        IF p_employee_id IS NOT NULL THEN
            v_sql := v_sql || ' AND p.fk_employee_id = ' || p_employee_id;
        END IF;
        
        OPEN v_cursor FOR v_sql;
        RETURN v_cursor;
    END get_monthly_payroll;

END pkg_payroll_reports;
/
```

## 8.3. Kodun Test Edilmesi ve Sonucun Alınması

```PLSQL
SET SERVEROUTPUT ON;

DECLARE
    v_report_cursor SYS_REFCURSOR;
    
    -- Çalışan Raporu için değişkenler
    v_emp_code VARCHAR2(30);
    v_tc VARCHAR2(11);
    v_fname VARCHAR2(50);
    v_lname VARCHAR2(50);
    v_dept VARCHAR2(100);
    v_title VARCHAR2(100);
    v_mult NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('--- IMSA ŞİRKETİ BÜTÜN ÇALIŞANLAR RAPORU ---');
    
    -- Fonksiyonu sadece Şirket ID (1) ile çağırıyoruz. (Departman ve unvan kısıtı yollamıyoruz, dinamik olarak tümünü getirecek)
    v_report_cursor := pkg_payroll_reports.get_employee_report(p_company_id => 1);
    
    LOOP
        FETCH v_report_cursor INTO v_emp_code, v_tc, v_fname, v_lname, v_dept, v_title, v_mult;
        EXIT WHEN v_report_cursor%NOTFOUND;
        
        DBMS_OUTPUT.PUT_LINE(v_emp_code || ' - ' || v_fname || ' ' || v_lname || ' | ' || v_dept || ' | ' || v_title);
    END LOOP;
    
    CLOSE v_report_cursor;
END;
/
```

# 9. Projenizin E-R diyagramındaki veri tabanınızın 3. normal formda olduğunuz gösteriniz.

```
Veritabanı mühendisliğinde bir tasarımın 3. Normal Formda (3NF) olduğunu kanıtlamak için, o tasarımın sırasıyla 1NF, 2NF ve 3NF kurallarından başarıyla geçtiğini göstermek zorundayız.

Tasarladığımız 15 tablolu SaaS Bordro Veritabanı E-R diyagramının neden tam olarak 3NF standartlarında olduğunu aşama aşama analiz edelim:

### 1. Birinci Normal Form (1NF) İspatı

**Kural:** Her hücrede tek bir veri (atomik) bulunmalıdır ve tekrarlayan sütun grupları olmamalıdır.

**Bizim Projedeki Karşılığı:**

- `Employees` tablomuzda hiçbir zaman personelin birden fazla telefon numarasını virgülle ayırarak aynı hücreye (örn: `0532..., 0533...`) yazmadık.
    
- "Ocak_Maaşı, Subat_Maaşı, Mart_Maaşı" gibi tekrarlayan sütunlar açmak yerine, `Payroll_Summary` tablosunda `period_month` ve `period_year` sütunlarını kullanarak her ayı ayrı bir satır (kayıt) haline getirdik. Bu sayede tasarımımız 1NF'yi başarıyla geçmektedir.
    

### 2. İkinci Normal Form (2NF) İspatı

**Kural:** Tablo 1NF olmalı ve **kısmi bağımlılık (partial dependency)** içermemelidir. Kısmi bağımlılık, anahtarı birden fazla sütundan oluşan (Composite Key) tablolarda, bazı alanların anahtarın sadece bir kısmına bağlı olmasıdır.

**Bizim Projedeki Karşılığı:**

- Bizim tasarımımızdaki tüm tablolar tekil bir **Surrogate Key** (Vekil Anahtar) kullanmaktadır (`company_id`, `employee_id`, `payroll_id` vb.).
    
- Birincil anahtarlarımız (Primary Key) tek bir sütundan oluştuğu için, matematiksel ve mantıksal olarak tasarımımızda kısmi bağımlılık olması **imkansızdır**. Bütün anahtar olmayan sütunlar, birincil anahtarın bütününe bağlıdır. Dolayısıyla tasarımımız kesin olarak 2NF'dir.
    

### 3. Üçüncü Normal Form (3NF) İspatı

**Kural:** Tablo 2NF olmalı ve **geçişli bağımlılık (transitive dependency)** içermemelidir. Yani anahtar olmayan bir sütun, anahtar olmayan başka bir sütuna bağlı olamaz; her şey sadece ve sadece Birincil Anahtara (Primary Key) bağlı olmalıdır.

**Bizim Projedeki Karşılığı:**

Bu kuralı sistemdeki en kritik tablolar üzerinden kanıtlayalım:

- **Örnek 1 (Departmanlar):** `Employees` tablosuna `department_name` sütununu eklemedik. Sadece `fk_department_id`ekledik. Eğer departman adını çalışanın tablosuna yazsaydık, departman adı `employee_id`'ye değil, `fk_department_id`'ye bağlı olurdu (Geçişli Bağımlılık). Bunu ayırarak `Departments` tablosuna aldık. Böylece bir departmanın adı değiştiğinde binlerce çalışanın kaydını güncellemekten (Update Anomaly) kurtulduk.
    
- **Örnek 2 (Unvan ve Maaşlar):** `Employees` tablosunda personelin unvan adını veya taban maaşını tutmadık. Bunları `Job_Titles` tablosuna böldük. Personelin unvan adı `employee_id`'ye bağlı değildir, yaptığı işe (`job_title_id`) bağlıdır.
    
- **Örnek 3 (Ek Ödeme Türleri):** Personele verilen bir bonusun adını veya vergiye tabi olup olmadığını (is_taxable) `Employee_Allowances` (hareket) tablosuna yazmadık. Bunu `Allowance_Types` tablosuna ayırdık.
    

**Sonuç:**

Tasarımımızdaki hiçbir tabloda "geçişli bağımlılık" bulunmamaktadır. Tüm referans veriler ayrı tablolara bölünmüş ve birbirlerine `Foreign Key` ile bağlanmıştır. Bu sayede Ekleme (Insert), Güncelleme (Update) ve Silme (Delete) anomalileri tamamen ortadan kaldırılmış olup veritabanımız **saf 3. Normal Form (3NF)** yapısındadır.

Bu teorik ve rasyonel açıklama, projenin akademik ve mühendislik standardını kanıtlamaktadır.
```

# 10. PL/SQL paketten çağrılabilen prosedür veya fonksiyon aracılığı ile tablolarda tekrar eden kayıtları siliniz.

```
Öncelikle rasyonel bir mühendislik gerçeğini vurgulamam gerek: **Adım 3'te** tablolarımıza `UNIQUE` (Tekil) kısıtlamalar (Örneğin; bir şirkette aynı TCKN ile iki personel olamaması veya bir personelin aynı ay/yıl için iki puantajı olamaması) eklemiştik. Bu kısıtlamalar aktifken veritabanı zaten mükerrer kayda fiziksel olarak izin vermez. Ancak, büyük sistemlerde toplu veri aktarımları (Migration/ETL) sırasında kısıtlamalar geçici olarak kapatılabilir (DISABLE CONSTRAINT) ve bu süreçte içeriye mükerrer veri sızabilir.

Bu ihtimale karşı, Oracle'ın en performanslı mükerrer kayıt bulma yöntemi olan **`ROWID`** (fiziksel disk adresi) mantığını kullanarak, 1-2 tablo ile sınırlı kalmadan **15 tablonun tamamı için** "İş Zekası Anahtarlarına" (Business Keys) göre mükerrer kayıtları silen bakım paketini aşağıda sunuyorum.
```

## 10.1. Bakım Paketi Tanımı (Specification)

```PLSQL
CREATE OR REPLACE PACKAGE pkg_payroll_maintenance AS
    
    -- Tüm tablolardaki mükerrer kayıtları temizleyen ana prosedür
    PROCEDURE remove_all_duplicates;

END pkg_payroll_maintenance;
/
```

## 10.2. Bakım Paketi Gövdesi (Body)
```PLSQL
CREATE OR REPLACE PACKAGE BODY pkg_payroll_maintenance AS

    PROCEDURE remove_all_duplicates IS
    BEGIN
        -- 1. Companies (Aynı vergi numarasına sahip kopyaları sil)
        DELETE FROM Companies 
        WHERE rowid NOT IN (
            SELECT MIN(rowid) FROM Companies GROUP BY tax_number
        );

        -- 2. Users (Aynı şirketteki aynı kullanıcı adlarını sil)
        DELETE FROM Users 
        WHERE rowid NOT IN (
            SELECT MIN(rowid) FROM Users GROUP BY fk_company_id, username
        );

        -- 3. Departments (Aynı şirketteki aynı isimli departmanları sil)
        DELETE FROM Departments 
        WHERE rowid NOT IN (
            SELECT MIN(rowid) FROM Departments GROUP BY fk_company_id, department_name
        );

        -- 4. Job_Titles (Aynı şirketteki aynı isimli unvanları sil)
        DELETE FROM Job_Titles 
        WHERE rowid NOT IN (
            SELECT MIN(rowid) FROM Job_Titles GROUP BY fk_company_id, title_name
        );

        -- 5. Employees (Aynı şirkette aynı TCKN'ye sahip personellerin kopyalarını sil)
        DELETE FROM Employees 
        WHERE rowid NOT IN (
            SELECT MIN(rowid) FROM Employees GROUP BY fk_company_id, national_id
        );

        -- 6. Employee_Contracts (Bir personelin aynı tarihte başlayan mükerrer sözleşmelerini sil)
        DELETE FROM Employee_Contracts 
        WHERE rowid NOT IN (
            SELECT MIN(rowid) FROM Employee_Contracts GROUP BY fk_employee_id, contract_start_date
        );

        -- 7. Tax_Slabs (Aynı şirketin aynı vergi dilim sınırlarını sil)
        DELETE FROM Tax_Slabs 
        WHERE rowid NOT IN (
            SELECT MIN(rowid) FROM Tax_Slabs GROUP BY fk_company_id, min_income, max_income
        );

        -- 8. Statutory_Parameters (Aynı şirketin aynı tarihte yürürlüğe giren aynı yasal parametrelerini sil)
        DELETE FROM Statutory_Parameters 
        WHERE rowid NOT IN (
            SELECT MIN(rowid) FROM Statutory_Parameters GROUP BY fk_company_id, param_name, effective_date
        );

        -- 9. Allowance_Types (Aynı şirketteki aynı isimli ek ödeme türlerini sil)
        DELETE FROM Allowance_Types 
        WHERE rowid NOT IN (
            SELECT MIN(rowid) FROM Allowance_Types GROUP BY fk_company_id, allowance_name
        );

        -- 10. Deduction_Types (Aynı şirketteki aynı isimli kesinti türlerini sil)
        DELETE FROM Deduction_Types 
        WHERE rowid NOT IN (
            SELECT MIN(rowid) FROM Deduction_Types GROUP BY fk_company_id, deduction_name
        );

        -- 11. Attendance_Records (Bir personelin aynı ay ve yıla ait birden fazla puantajı varsa sil)
        DELETE FROM Attendance_Records 
        WHERE rowid NOT IN (
            SELECT MIN(rowid) FROM Attendance_Records GROUP BY fk_employee_id, record_month, record_year
        );

        -- 12. Employee_Allowances (Bir personele aynı gün aynı türde iki kez ödeme girilmişse sil)
        DELETE FROM Employee_Allowances 
        WHERE rowid NOT IN (
            SELECT MIN(rowid) FROM Employee_Allowances GROUP BY fk_employee_id, fk_allowance_type_id, payment_date
        );

        -- 13. Employee_Deductions (Bir personele aynı gün aynı türde iki kez kesinti girilmişse sil)
        DELETE FROM Employee_Deductions 
        WHERE rowid NOT IN (
            SELECT MIN(rowid) FROM Employee_Deductions GROUP BY fk_employee_id, fk_deduction_type_id, deduction_date
        );

        -- 14. Payroll_Summary (Bir personelin aynı döneme ait birden fazla bordrosu varsa ilkini bırak diğerlerini sil)
        DELETE FROM Payroll_Summary 
        WHERE rowid NOT IN (
            SELECT MIN(rowid) FROM Payroll_Summary GROUP BY fk_employee_id, period_month, period_year
        );

        -- 15. Payroll_Logs (Aynı saniye içinde aynı işlemi yapan birebir aynı log kayıtları oluşmuşsa temizle)
        DELETE FROM Payroll_Logs 
        WHERE rowid NOT IN (
            SELECT MIN(rowid) FROM Payroll_Logs GROUP BY fk_payroll_id, fk_user_id, action_type, action_timestamp
        );

        -- Tüm silme işlemleri başarılı olursa veritabanına kalıcı olarak yaz.
        COMMIT;

    EXCEPTION
        -- Eğer silme işlemleri sırasında bir Foreign Key ihlali gibi beklenmedik hata olursa işlemi geri al.
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20010, 'Mükerrer kayıt temizliği sırasında bir hata oluştu: ' || SQLERRM);
    END remove_all_duplicates;

END pkg_payroll_maintenance;
/
```

## 10.3. Kullanımı

```PLSQL
BEGIN
    pkg_payroll_maintenance.remove_all_duplicates();
END;
/
```

---


> [!NOTE] Dikkat Edilmesi Gerekenler
>    Bu pdfteki 5. , 6. ve 8. maddelerdeki örneklerin rapor için çoğaltılması gerekebilir veya gerekmeyebilir de bunu dışındaki tüm maddeleri kontrol ettim ve açıklanması gerektiğini düşündüğüm şeyleri paragraflar halinde açıklattım. Bunlar dışındakiler kolaylıkla anlaşılabilecek başlıklar ve kodlar. 
>
