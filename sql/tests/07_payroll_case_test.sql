-- ==========================================
-- Test 7: Bordro Cikarma Vakasi (End-to-End)
-- 3 personel uzerinden bordronun 11 adimini calistirir.
-- Senaryo: IMSA sirketi (company_id=1), Mayis 2026 donemi.
--
-- ON KOSULLAR:
--   - 01_create_tables.sql + 02_constraints_indexes.sql + 03_sequences_triggers.sql calistirilmis olmali
--   - pkg_payroll_entry compile edilmis olmali
--   - 01_data_seeding.sql calistirilmis olmali (companies, departments, job_titles, employees, contracts hazir)
--
-- SECILEN PERSONELLER (IMSA / company_id=1):
--   * emp_id=301 -> HR Manager   (baz=85.000, carpan=1.2 -> sozlesmeli=102.000)
--   * emp_id=305 -> Senior SWE   (baz=120.000, carpan=1.0 -> sozlesmeli=120.000)
--   * emp_id=310 -> Sales Rep    (baz=40.000, carpan=1.2 -> sozlesmeli=48.000)
--
-- BORDRO AKISI (anlatildigi gibi):
--   [1] Employees + Companies  -> kim icin
--   [2] Job_Titles              -> baz maas
--   [3] Employee_Contracts      -> carpan & sabit ek
--   [4] Attendance_Records      -> calisilan gun / mesai
--   [5] Employee_Allowances     -> ek odemeler (vergili / vergisiz)
--   [6] Brut hesabi
--   [7] Tax_Slabs               -> gelir vergisi
--   [8] Statutory_Parameters    -> SGK kesintisi
--   [9] Employee_Deductions     -> diger kesintiler
--   [10] Net hesabi
--   [11] Payroll_Summary INSERT (-> trigger Payroll_Logs'a otomatik yazar)
-- ==========================================

SET SERVEROUTPUT ON;
SET LINESIZE 200;

-- ==========================================
-- BOLUM 0: TEMIZLIK (test re-runnable olsun)
-- ==========================================
BEGIN
    -- Once cocuk tablolari (FK'li olanlar) sil
    DELETE FROM Payroll_Logs       WHERE fk_payroll_id IN (7001, 7002, 7003);
    DELETE FROM Payroll_Summary    WHERE payroll_id    IN (7001, 7002, 7003);
    DELETE FROM Employee_Allowances WHERE emp_allowance_id BETWEEN 8001 AND 8010;
    DELETE FROM Employee_Deductions WHERE emp_deduction_id BETWEEN 9001 AND 9010;

    -- Sonra tanim tablolarini sil (ust seviye)
    DELETE FROM Tax_Slabs            WHERE slab_id            BETWEEN 6001 AND 6004;
    DELETE FROM Statutory_Parameters WHERE param_id           BETWEEN 5001 AND 5002;
    DELETE FROM Allowance_Types      WHERE allowance_type_id  IN (1001, 1002);
    DELETE FROM Deduction_Types      WHERE deduction_type_id  = 2001;
    COMMIT;
END;
/

-- ==========================================
-- BOLUM 1: TANIM TABLOLARINI HAZIRLA
-- (Tax_Slabs, Statutory_Parameters, Allowance_Types, Deduction_Types)
-- ==========================================

-- 1.1 Vergi dilimleri (IMSA'ya ozel)
INSERT INTO Tax_Slabs (slab_id, fk_company_id, min_income, max_income, tax_rate)
VALUES (6001, 1,      0,    70000, 15);
INSERT INTO Tax_Slabs (slab_id, fk_company_id, min_income, max_income, tax_rate)
VALUES (6002, 1,  70001,   150000, 20);
INSERT INTO Tax_Slabs (slab_id, fk_company_id, min_income, max_income, tax_rate)
VALUES (6003, 1, 150001,   370000, 27);
INSERT INTO Tax_Slabs (slab_id, fk_company_id, min_income, max_income, tax_rate)
VALUES (6004, 1, 370001,     NULL, 35);

-- 1.2 Yasal parametreler (SGK + Issizlik calisan payi)
INSERT INTO Statutory_Parameters (param_id, fk_company_id, param_name, rate, effective_date)
VALUES (5001, 1, 'SGK_CALISAN',     0.14, DATE '2026-01-01');
INSERT INTO Statutory_Parameters (param_id, fk_company_id, param_name, rate, effective_date)
VALUES (5002, 1, 'ISSIZLIK_CALISAN', 0.01, DATE '2026-01-01');

-- 1.3 Ek odeme turleri
INSERT INTO Allowance_Types (allowance_type_id, fk_company_id, allowance_name, is_taxable)
VALUES (1001, 1, 'Yemek Yardimi',    0); -- vergisiz
INSERT INTO Allowance_Types (allowance_type_id, fk_company_id, allowance_name, is_taxable)
VALUES (1002, 1, 'Performans Primi', 1); -- vergili

-- 1.4 Kesinti turu
INSERT INTO Deduction_Types (deduction_type_id, fk_company_id, deduction_name)
VALUES (2001, 1, 'Icra Kesintisi');

COMMIT;

-- ==========================================
-- BOLUM 2: 3 PERSONEL ICIN BORDRO HESAPLAMA + INSERT
-- ==========================================

DECLARE
    -- Senaryo verisi (3 farkli profilde personel)
    TYPE t_emp_rec IS RECORD (
        emp_id        NUMBER,
        payroll_id    NUMBER,
        worked_days   NUMBER,
        overtime_hrs  NUMBER,
        meal_amount   NUMBER,  -- vergisiz ek (Yemek)
        bonus_amount  NUMBER,  -- vergili ek (Prim)
        deduction     NUMBER   -- diger kesinti (Icra)
    );
    TYPE t_emp_tab IS TABLE OF t_emp_rec INDEX BY PLS_INTEGER;
    v_emps t_emp_tab;

    -- Hesap degiskenleri
    v_first_name        VARCHAR2(50);
    v_last_name         VARCHAR2(50);
    v_base_salary       NUMBER;
    v_multiplier        NUMBER;
    v_addtl_fixed       NUMBER;
    v_contract_salary   NUMBER;
    v_gross             NUMBER;
    v_tax_rate          NUMBER;
    v_income_tax        NUMBER;
    v_sgk_rate          NUMBER;
    v_sgk_cut           NUMBER;
    v_total_tax         NUMBER;
    v_net               NUMBER;

    v_period_month      NUMBER := 5;
    v_period_year       NUMBER := 2026;

    -- ID sayaclari
    v_alw_id            NUMBER := 8001;
    v_ded_id            NUMBER := 9001;

    v_eid               NUMBER;
    v_meal              NUMBER;
    v_bonus             NUMBER;
    v_other_ded         NUMBER;
BEGIN
    -- Senaryo 1: HR Manager (orta-yuksek gelir)
    v_emps(1).emp_id := 301; v_emps(1).payroll_id := 7001;
    v_emps(1).worked_days := 22;   v_emps(1).overtime_hrs := 0;
    v_emps(1).meal_amount := 3000; v_emps(1).bonus_amount := 8000;
    v_emps(1).deduction   := 2000;

    -- Senaryo 2: Senior SWE (yuksek gelir, kesintisiz)
    v_emps(2).emp_id := 305; v_emps(2).payroll_id := 7002;
    v_emps(2).worked_days := 22;   v_emps(2).overtime_hrs := 10;
    v_emps(2).meal_amount := 3000; v_emps(2).bonus_amount := 10000;
    v_emps(2).deduction   := 0;

    -- Senaryo 3: Sales Rep (dusuk gelir, dusuk dilim)
    v_emps(3).emp_id := 310; v_emps(3).payroll_id := 7003;
    v_emps(3).worked_days := 20;   v_emps(3).overtime_hrs := 5;
    v_emps(3).meal_amount := 2500; v_emps(3).bonus_amount := 2000;
    v_emps(3).deduction   := 500;

    DBMS_OUTPUT.PUT_LINE('==========================================================');
    DBMS_OUTPUT.PUT_LINE(' IMSA - Mayis 2026 - 3 Personel Bordro Cikarma Testi');
    DBMS_OUTPUT.PUT_LINE('==========================================================');

    FOR i IN 1..3 LOOP
        v_eid       := v_emps(i).emp_id;
        v_meal      := v_emps(i).meal_amount;
        v_bonus     := v_emps(i).bonus_amount;
        v_other_ded := v_emps(i).deduction;

        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('---------- Personel ID: ' || v_eid || ' ----------');

        -- ADIM 1: Personel kim? (Employees + Companies dogrulama)
        SELECT first_name, last_name
        INTO v_first_name, v_last_name
        FROM Employees
        WHERE employee_id = v_eid AND fk_company_id = 1;
        DBMS_OUTPUT.PUT_LINE(' [1] Employees     -> ' || v_first_name || ' ' || v_last_name);

        -- ADIM 2: Job_Titles -> baz maas
        SELECT j.min_base_salary
        INTO v_base_salary
        FROM Employees e
        JOIN Job_Titles j ON e.fk_job_title_id = j.job_title_id
        WHERE e.employee_id = v_eid;
        DBMS_OUTPUT.PUT_LINE(' [2] Job_Titles    -> baz maas = ' || v_base_salary);

        -- ADIM 3: Employee_Contracts -> aktif sozlesme
        SELECT salary_multiplier, NVL(additional_fixed_salary, 0)
        INTO v_multiplier, v_addtl_fixed
        FROM Employee_Contracts
        WHERE fk_employee_id = v_eid AND is_active = 1 AND ROWNUM = 1;

        v_contract_salary := v_base_salary * v_multiplier + v_addtl_fixed;
        DBMS_OUTPUT.PUT_LINE(' [3] Contracts     -> carpan=' || v_multiplier ||
                              ', sabit_ek=' || v_addtl_fixed ||
                              ' -> sozlesmeli maas=' || v_contract_salary);

        -- ADIM 4: Attendance_Records -> puantaj (varsa update, yoksa insert)
        MERGE INTO Attendance_Records ar
        USING (SELECT v_eid AS eid FROM dual) src
        ON (    ar.fk_employee_id = src.eid
            AND ar.record_month   = v_period_month
            AND ar.record_year    = v_period_year )
        WHEN MATCHED THEN UPDATE SET
            ar.worked_days    = v_emps(i).worked_days,
            ar.overtime_hours = v_emps(i).overtime_hrs
        WHEN NOT MATCHED THEN INSERT
            (attendance_id, fk_employee_id, fk_company_id,
             record_month, record_year, worked_days, overtime_hours)
            VALUES (seq_attendance_id.NEXTVAL, v_eid, 1,
                    v_period_month, v_period_year,
                    v_emps(i).worked_days, v_emps(i).overtime_hrs);
        DBMS_OUTPUT.PUT_LINE(' [4] Attendance    -> ' || v_emps(i).worked_days ||
                              ' gun calisma, ' || v_emps(i).overtime_hrs || ' sa mesai');

        -- ADIM 5: Employee_Allowances -> vergili + vergisiz ek odemeler
        INSERT INTO Employee_Allowances
            (emp_allowance_id, fk_employee_id, fk_company_id,
             fk_allowance_type_id, amount, payment_date)
        VALUES (v_alw_id, v_eid, 1, 1001, v_meal, DATE '2026-05-15');
        v_alw_id := v_alw_id + 1;

        INSERT INTO Employee_Allowances
            (emp_allowance_id, fk_employee_id, fk_company_id,
             fk_allowance_type_id, amount, payment_date)
        VALUES (v_alw_id, v_eid, 1, 1002, v_bonus, DATE '2026-05-15');
        v_alw_id := v_alw_id + 1;

        DBMS_OUTPUT.PUT_LINE(' [5] Allowances    -> Yemek=' || v_meal ||
                              ' (vergisiz), Prim=' || v_bonus || ' (vergili)');

        -- ADIM 6: Brut maas = sozlesmeli + vergili ek
        v_gross := v_contract_salary + v_bonus;
        DBMS_OUTPUT.PUT_LINE(' [6] Brut maas     -> ' || v_gross);

        -- ADIM 7: Tax_Slabs -> gelir vergisi orani
        SELECT tax_rate
        INTO v_tax_rate
        FROM Tax_Slabs
        WHERE v_gross BETWEEN min_income AND NVL(max_income, 99999999999)
          AND (fk_company_id = 1 OR fk_company_id IS NULL)
          AND ROWNUM = 1;

        v_income_tax := v_gross * v_tax_rate / 100;
        DBMS_OUTPUT.PUT_LINE(' [7] Tax_Slabs     -> %' || v_tax_rate ||
                              ' -> gelir vergisi=' || v_income_tax);

        -- ADIM 8: Statutory_Parameters -> SGK toplam orani
        SELECT NVL(SUM(rate), 0)
        INTO v_sgk_rate
        FROM Statutory_Parameters
        WHERE (fk_company_id = 1 OR fk_company_id IS NULL)
          AND effective_date <= DATE '2026-05-31';

        v_sgk_cut := v_gross * v_sgk_rate;
        DBMS_OUTPUT.PUT_LINE(' [8] Statutory     -> oran=' || v_sgk_rate ||
                              ' -> SGK kesinti=' || v_sgk_cut);

        -- ADIM 9: Employee_Deductions -> personel kesintileri
        IF v_other_ded > 0 THEN
            INSERT INTO Employee_Deductions
                (emp_deduction_id, fk_employee_id, fk_company_id,
                 fk_deduction_type_id, amount, deduction_date)
            VALUES (v_ded_id, v_eid, 1, 2001, v_other_ded, DATE '2026-05-15');
            v_ded_id := v_ded_id + 1;
        END IF;
        DBMS_OUTPUT.PUT_LINE(' [9] Deductions    -> diger kesinti=' || v_other_ded);

        -- ADIM 10: Net hesabi
        v_total_tax := v_income_tax + v_sgk_cut;
        v_net       := v_gross - v_total_tax - v_other_ded + v_meal; -- vergisiz ek net'e eklenir
        DBMS_OUTPUT.PUT_LINE(' [10] Hesap        -> total_tax=' || v_total_tax ||
                              ', NET MAAS=' || v_net);

        -- ADIM 11: Payroll_Summary'ye yaz (trigger Payroll_Logs'a otomatik dusurur)
        pkg_payroll_entry.add_payroll(
            p_payroll_id     => v_emps(i).payroll_id,
            p_employee_id    => v_eid,
            p_company_id     => 1,
            p_period_month   => v_period_month,
            p_period_year    => v_period_year,
            p_gross_salary   => v_gross,
            p_net_salary     => v_net,
            p_total_tax      => v_total_tax,
            p_payment_status => 'PAID'
        );
        DBMS_OUTPUT.PUT_LINE(' [11] Payroll_Summary -> bordro #' || v_emps(i).payroll_id || ' yazildi');
        DBMS_OUTPUT.PUT_LINE(' [12] Payroll_Logs    -> trigger ile audit log otomatik olusturuldu');
    END LOOP;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('==========================================================');
    DBMS_OUTPUT.PUT_LINE(' 3 BORDRO BASARIYLA OLUSTURULDU - COMMIT TAMAMLANDI');
    DBMS_OUTPUT.PUT_LINE('==========================================================');

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('HATA: ' || SQLERRM);
        RAISE;
END;
/

-- ==========================================
-- BOLUM 3: DOGRULAMA SORGULARI
-- ==========================================

PROMPT
PROMPT === Bordro Ozeti (Payroll_Summary) ===
SELECT p.payroll_id,
       e.employee_id,
       e.first_name || ' ' || e.last_name AS personel,
       p.period_month || '/' || p.period_year AS donem,
       p.gross_salary,
       p.total_tax,
       p.net_salary,
       p.payment_status
FROM   Payroll_Summary p
JOIN   Employees e ON p.fk_employee_id = e.employee_id
WHERE  p.payroll_id IN (7001, 7002, 7003)
ORDER BY p.payroll_id;

PROMPT
PROMPT === Audit Log (trigger trg_payroll_audit ile otomatik dolduruldu) ===
SELECT log_id,
       fk_payroll_id,
       action_type,
       TO_CHAR(action_timestamp, 'YYYY-MM-DD HH24:MI:SS') AS zaman
FROM   Payroll_Logs
WHERE  fk_payroll_id IN (7001, 7002, 7003)
ORDER BY log_id;

PROMPT
PROMPT === Personel Bazli Detay (allowance + deduction kirilim) ===
SELECT e.employee_id,
       e.first_name || ' ' || e.last_name AS personel,
       (SELECT NVL(SUM(amount), 0) FROM Employee_Allowances
          WHERE fk_employee_id = e.employee_id
            AND fk_allowance_type_id = 1001
            AND TO_CHAR(payment_date, 'MM-YYYY') = '05-2026') AS yemek,
       (SELECT NVL(SUM(amount), 0) FROM Employee_Allowances
          WHERE fk_employee_id = e.employee_id
            AND fk_allowance_type_id = 1002
            AND TO_CHAR(payment_date, 'MM-YYYY') = '05-2026') AS prim,
       (SELECT NVL(SUM(amount), 0) FROM Employee_Deductions
          WHERE fk_employee_id = e.employee_id
            AND TO_CHAR(deduction_date, 'MM-YYYY') = '05-2026') AS kesinti
FROM   Employees e
WHERE  e.employee_id IN (301, 305, 310)
ORDER BY e.employee_id;
