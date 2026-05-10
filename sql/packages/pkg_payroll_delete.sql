-- ==========================================
-- Madde 6: Veri Silme Paketi (pkg_payroll_delete)
-- Specification + Body
-- ==========================================

CREATE OR REPLACE PACKAGE pkg_payroll_delete AS

    -- 1. Personeli ve ona bagli tum hareket/sozlesme kayitlarini hiyerarsik olarak siler
    PROCEDURE delete_employee(p_employee_id NUMBER, p_company_id NUMBER);

    -- 2. Hatali girilen bir ek odemeyi siler (Orn: Yanlislikla verilen bonus)
    PROCEDURE delete_allowance(p_emp_allowance_id NUMBER, p_company_id NUMBER);

    -- 3. Hatali hesaplanmis bir bordroyu ve ona bagli loglari siler
    PROCEDURE delete_payroll(p_payroll_id NUMBER, p_company_id NUMBER);

END pkg_payroll_delete;
/

CREATE OR REPLACE PACKAGE BODY pkg_payroll_delete AS

    -- 1. Hiyerarsik Personel Silme
    PROCEDURE delete_employee(p_employee_id NUMBER, p_company_id NUMBER) IS
    BEGIN
        -- Adim 1: Loglari ve Bordro Ozetini Sil (En alt katman)
        DELETE FROM Payroll_Logs
        WHERE fk_payroll_id IN (
            SELECT payroll_id FROM Payroll_Summary
            WHERE fk_employee_id = p_employee_id AND fk_company_id = p_company_id
        );
        DELETE FROM Payroll_Summary
        WHERE fk_employee_id = p_employee_id AND fk_company_id = p_company_id;

        -- Adim 2: Ek Odeme, Kesinti ve Puantajlari Sil (Hareket tablolari)
        DELETE FROM Employee_Allowances
        WHERE fk_employee_id = p_employee_id AND fk_company_id = p_company_id;

        DELETE FROM Employee_Deductions
        WHERE fk_employee_id = p_employee_id AND fk_company_id = p_company_id;

        DELETE FROM Attendance_Records
        WHERE fk_employee_id = p_employee_id AND fk_company_id = p_company_id;

        -- Adim 3: Sozlesmeyi Sil
        DELETE FROM Employee_Contracts
        WHERE fk_employee_id = p_employee_id AND fk_company_id = p_company_id;

        -- Adim 4: Personeli Ana Tablodan Sil
        DELETE FROM Employees
        WHERE employee_id = p_employee_id AND fk_company_id = p_company_id;

        -- Eger hicbir satir silinmediyse (personel yoksa veya sirket yanlissa) hata firlat
        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20004, 'Silinecek personel bulunamadi veya yetkisiz sirket islemi.');
        END IF;
    END delete_employee;

    -- 2. Ek Odeme Silme
    PROCEDURE delete_allowance(p_emp_allowance_id NUMBER, p_company_id NUMBER) IS
    BEGIN
        DELETE FROM Employee_Allowances
        WHERE emp_allowance_id = p_emp_allowance_id
          AND fk_company_id = p_company_id;

        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20005, 'Ek odeme kaydi bulunamadi.');
        END IF;
    END delete_allowance;

    -- 3. Bordro ve Log Silme
    PROCEDURE delete_payroll(p_payroll_id NUMBER, p_company_id NUMBER) IS
    BEGIN
        -- Once loglari sil (Foreign Key kisitlamasini asmak icin)
        DELETE FROM Payroll_Logs WHERE fk_payroll_id = p_payroll_id AND fk_company_id = p_company_id;

        -- Sonra bordroyu sil
        DELETE FROM Payroll_Summary WHERE payroll_id = p_payroll_id AND fk_company_id = p_company_id;

        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20006, 'Bordro kaydi bulunamadi.');
        END IF;
    END delete_payroll;

END pkg_payroll_delete;
/
