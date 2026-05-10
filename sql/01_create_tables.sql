-- ==========================================
-- Madde 2: Tablo Olusturma Kodlari (15 Tablo)
-- ==========================================

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
    salary_multiplier NUMBER(5, 4) DEFAULT 1.0, -- Orn: 1.10 (%10 zam)
    additional_fixed_salary NUMBER(15, 2) DEFAULT 0,
    contract_start_date DATE NOT NULL,
    contract_end_date DATE,
    is_active NUMBER(1) DEFAULT 1 -- 1: Aktif, 0: Pasif (Oracle'da Boolean yerine Number(1) kullanilir)
);

-- 7. Tax_Slabs Tablosu
CREATE TABLE Tax_Slabs (
    slab_id NUMBER,
    fk_company_id NUMBER, -- Global vergi dilimi ise NULL birakilabilir
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
