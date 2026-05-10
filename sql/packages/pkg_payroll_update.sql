-- ==========================================
-- Madde 5: Veri Guncelleme Paketi (pkg_payroll_update)
-- Specification + Body
-- ==========================================

CREATE OR REPLACE PACKAGE pkg_payroll_update AS

    -- 1. Personel Terfi veya Departman Degisikligi
    PROCEDURE update_employee_job(
        p_employee_id NUMBER,
        p_company_id NUMBER,
        p_new_dept_id NUMBER,
        p_new_job_id NUMBER
    );

    -- 2. Maas Sozlesmesi Guncellemesi (Zam Yapilmasi)
    PROCEDURE update_contract_salary(
        p_employee_id NUMBER,
        p_company_id NUMBER,
        p_new_multiplier NUMBER,
        p_new_fixed_salary NUMBER
    );

    -- 3. Hatali Girilen Puantaji (Mesai/Calisma Gunu) Duzeltme
    PROCEDURE update_attendance(
        p_attendance_id NUMBER,
        p_employee_id NUMBER,
        p_company_id NUMBER,
        p_new_worked_days NUMBER,
        p_new_overtime_hours NUMBER
    );

END pkg_payroll_update;
/

CREATE OR REPLACE PACKAGE BODY pkg_payroll_update AS

    -- 1. Personel Terfi Islemi
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
          AND fk_company_id = p_company_id; -- Guvenlik kisiti: Sadece kendi sirketinin personeli

        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20001, 'Personel bulunamadi veya bu sirkete ait degil.');
        END IF;
    END update_employee_job;

    -- 2. Maas Sozlesmesi Guncellemesi
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
          AND is_active = 1; -- Sadece aktif sozlesme guncellenir

        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20002, 'Aktif sozlesme bulunamadi veya yetkisiz islem.');
        END IF;
    END update_contract_salary;

    -- 3. Puantaj Duzeltmesi
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
            RAISE_APPLICATION_ERROR(-20003, 'Puantaj kaydi bulunamadi veya sirket eslesmiyor.');
        END IF;
    END update_attendance;

END pkg_payroll_update;
/
