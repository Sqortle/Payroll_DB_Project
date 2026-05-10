-- ==========================================
-- Test 3: Veri Guncelleme Testi (Madde 5.3)
-- IMSA sirketindeki 1 numarali personelin departman/unvan/maas guncellemesi.
-- ==========================================

BEGIN
    -- IMSA sirketindeki (ID:1) 1 numarali personelin departmanini(ID:2) ve unvanini(ID:2) degistir
    pkg_payroll_update.update_employee_job(
        p_employee_id => 1,
        p_company_id => 1,
        p_new_dept_id => 2,
        p_new_job_id => 2
    );

    -- Ayni personelin maas carpanini 1.50 (%50 zam) ve sabit ek odemesini 10000 yap
    pkg_payroll_update.update_contract_salary(
        p_employee_id => 1,
        p_company_id => 1,
        p_new_multiplier => 1.50,
        p_new_fixed_salary => 10000
    );

    COMMIT;
END;
/
