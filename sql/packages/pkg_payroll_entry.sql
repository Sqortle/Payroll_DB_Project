-- ==========================================
-- Madde 4: Veri Girisi Paketi (pkg_payroll_entry)
-- Specification + Body
-- ==========================================

CREATE OR REPLACE PACKAGE pkg_payroll_entry AS
    -- Sirket Ekleme
    PROCEDURE add_company(p_company_id NUMBER, p_name VARCHAR2, p_email VARCHAR2);

    -- Departman Ekleme
    PROCEDURE add_department(p_dept_id NUMBER, p_company_id NUMBER, p_name VARCHAR2);

    -- Unvan Ekleme
    PROCEDURE add_job_title(p_job_id NUMBER, p_company_id NUMBER, p_title VARCHAR2, p_base_salary NUMBER);

    -- Kullanici (Sisteme Giris Yapacak Kisi) Ekleme
    PROCEDURE add_user(p_user_id NUMBER, p_company_id NUMBER, p_username VARCHAR2, p_email VARCHAR2, p_role VARCHAR2);

    -- Calisan Ekleme
    PROCEDURE add_employee(p_emp_id NUMBER, p_company_id NUMBER, p_dept_id NUMBER, p_job_id NUMBER, p_national_id VARCHAR2, p_first_name VARCHAR2, p_last_name VARCHAR2);

    -- Calisan Sozlesmesi Ekleme
    PROCEDURE add_contract(p_contract_id NUMBER, p_emp_id NUMBER, p_company_id NUMBER, p_multiplier NUMBER);

    -- Bordro Kaydi Ekleme
    PROCEDURE add_payroll(
        p_payroll_id     NUMBER,
        p_employee_id    NUMBER,
        p_company_id     NUMBER,
        p_period_month   NUMBER,
        p_period_year    NUMBER,
        p_gross_salary   NUMBER,
        p_net_salary     NUMBER,
        p_total_tax      NUMBER,
        p_payment_status VARCHAR2
    );
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

    PROCEDURE add_job_title(p_job_id NUMBER, p_company_id NUMBER, p_title VARCHAR2, p_base_salary NUMBER) IS
    BEGIN
        INSERT INTO Job_Titles (job_title_id, fk_company_id, title_name, min_base_salary)
        VALUES (p_job_id, p_company_id, p_title, p_base_salary);
    END add_job_title;

    PROCEDURE add_user(p_user_id NUMBER, p_company_id NUMBER, p_username VARCHAR2, p_email VARCHAR2, p_role VARCHAR2) IS
    BEGIN
        -- Parola gercek senaryoda hashlenir, burada basit geciyoruz.
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

    PROCEDURE add_payroll(
        p_payroll_id     NUMBER,
        p_employee_id    NUMBER,
        p_company_id     NUMBER,
        p_period_month   NUMBER,
        p_period_year    NUMBER,
        p_gross_salary   NUMBER,
        p_net_salary     NUMBER,
        p_total_tax      NUMBER,
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
