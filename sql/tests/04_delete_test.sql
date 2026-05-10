-- ==========================================
-- Test 4: Veri Silme Testi (Madde 6.3)
-- IMSA sirketinden 300 numarali personelin hiyerarsik silinmesi.
-- ==========================================

BEGIN
    pkg_payroll_delete.delete_employee(
        p_employee_id => 300,
        p_company_id => 1
    );

    COMMIT;
END;
/
