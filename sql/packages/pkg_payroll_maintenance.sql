-- ==========================================
-- Madde 10: Mukerrer Kayit Silme Paketi (pkg_payroll_maintenance)
-- Specification + Body
-- ROWID mantigiyla 15 tablonun tamami icin "Business Key" bazli temizlik.
-- ==========================================

CREATE OR REPLACE PACKAGE pkg_payroll_maintenance AS

    -- Tum tablolardaki mukerrer kayitlari temizleyen ana prosedur
    PROCEDURE remove_all_duplicates;

END pkg_payroll_maintenance;
/

CREATE OR REPLACE PACKAGE BODY pkg_payroll_maintenance AS

    PROCEDURE remove_all_duplicates IS
    BEGIN
        -- 1. Companies (Ayni vergi numarasina sahip kopyalari sil)
        -- NULL tax_number'lar dedupe'a alinmaz (ayri sirketler olabilir, kotu deger degil)
        DELETE FROM Companies
        WHERE tax_number IS NOT NULL
          AND rowid NOT IN (
            SELECT MIN(rowid) FROM Companies
            WHERE tax_number IS NOT NULL
            GROUP BY tax_number
        );

        -- 2. Users (Ayni sirketteki ayni kullanici adlarini sil)
        DELETE FROM Users
        WHERE rowid NOT IN (
            SELECT MIN(rowid) FROM Users GROUP BY fk_company_id, username
        );

        -- 3. Departments (Ayni sirketteki ayni isimli departmanlari sil)
        DELETE FROM Departments
        WHERE rowid NOT IN (
            SELECT MIN(rowid) FROM Departments GROUP BY fk_company_id, department_name
        );

        -- 4. Job_Titles (Ayni sirketteki ayni isimli unvanlari sil)
        DELETE FROM Job_Titles
        WHERE rowid NOT IN (
            SELECT MIN(rowid) FROM Job_Titles GROUP BY fk_company_id, title_name
        );

        -- 5. Employees (Ayni sirkette ayni TCKN'ye sahip personellerin kopyalarini sil)
        DELETE FROM Employees
        WHERE rowid NOT IN (
            SELECT MIN(rowid) FROM Employees GROUP BY fk_company_id, national_id
        );

        -- 6. Employee_Contracts (Bir personelin ayni tarihte baslayan mukerrer sozlesmelerini sil)
        DELETE FROM Employee_Contracts
        WHERE rowid NOT IN (
            SELECT MIN(rowid) FROM Employee_Contracts GROUP BY fk_employee_id, contract_start_date
        );

        -- 7. Tax_Slabs (Ayni sirketin ayni vergi dilim sinirlarini sil)
        DELETE FROM Tax_Slabs
        WHERE rowid NOT IN (
            SELECT MIN(rowid) FROM Tax_Slabs GROUP BY fk_company_id, min_income, max_income
        );

        -- 8. Statutory_Parameters (Ayni sirketin ayni tarihte yururluge giren ayni yasal parametrelerini sil)
        DELETE FROM Statutory_Parameters
        WHERE rowid NOT IN (
            SELECT MIN(rowid) FROM Statutory_Parameters GROUP BY fk_company_id, param_name, effective_date
        );

        -- 9. Allowance_Types (Ayni sirketteki ayni isimli ek odeme turlerini sil)
        DELETE FROM Allowance_Types
        WHERE rowid NOT IN (
            SELECT MIN(rowid) FROM Allowance_Types GROUP BY fk_company_id, allowance_name
        );

        -- 10. Deduction_Types (Ayni sirketteki ayni isimli kesinti turlerini sil)
        DELETE FROM Deduction_Types
        WHERE rowid NOT IN (
            SELECT MIN(rowid) FROM Deduction_Types GROUP BY fk_company_id, deduction_name
        );

        -- 11. Attendance_Records (Bir personelin ayni ay ve yila ait birden fazla puantaji varsa sil)
        DELETE FROM Attendance_Records
        WHERE rowid NOT IN (
            SELECT MIN(rowid) FROM Attendance_Records GROUP BY fk_employee_id, record_month, record_year
        );

        -- 12. Employee_Allowances (Bir personele ayni gun ayni turde iki kez odeme girilmisse sil)
        DELETE FROM Employee_Allowances
        WHERE rowid NOT IN (
            SELECT MIN(rowid) FROM Employee_Allowances GROUP BY fk_employee_id, fk_allowance_type_id, payment_date
        );

        -- 13. Employee_Deductions (Bir personele ayni gun ayni turde iki kez kesinti girilmisse sil)
        DELETE FROM Employee_Deductions
        WHERE rowid NOT IN (
            SELECT MIN(rowid) FROM Employee_Deductions GROUP BY fk_employee_id, fk_deduction_type_id, deduction_date
        );

        -- 14. Payroll_Summary (Bir personelin ayni doneme ait birden fazla bordrosu varsa ilkini birak digerlerini sil)
        DELETE FROM Payroll_Summary
        WHERE rowid NOT IN (
            SELECT MIN(rowid) FROM Payroll_Summary GROUP BY fk_employee_id, period_month, period_year
        );

        -- 15. Payroll_Logs (Ayni saniye icinde ayni islemi yapan birebir ayni log kayitlari olusmussa temizle)
        DELETE FROM Payroll_Logs
        WHERE rowid NOT IN (
            SELECT MIN(rowid) FROM Payroll_Logs GROUP BY fk_payroll_id, fk_user_id, action_type, action_timestamp
        );

        -- Tum silme islemleri basarili olursa veritabanina kalici olarak yaz.
        COMMIT;

    EXCEPTION
        -- Eger silme islemleri sirasinda bir Foreign Key ihlali gibi beklenmedik hata olursa islemi geri al.
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20010, 'Mukerrer kayit temizligi sirasinda bir hata olustu: ' || SQLERRM);
    END remove_all_duplicates;

END pkg_payroll_maintenance;
/
