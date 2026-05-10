-- ==========================================
-- Test 2: Trigger Test Blogu (Madde 7.1)
-- trg_after_emp_insert ve trg_payroll_audit dogrulama testleri.
-- 4 senaryo: personel ekleme + bordro INSERT/UPDATE/DELETE.
-- Test sonunda olusturulan veriler ve loglar otomatik temizlenir.
-- ==========================================

SET SERVEROUTPUT ON;

DECLARE
    v_attendance_count NUMBER;
    v_log_count        NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== TRIGGER TEST BLOGU BASLADI ===');
    DBMS_OUTPUT.PUT_LINE('');

    -- TEST 1: Personel ekleme trigger'i (trg_after_emp_insert)
    DBMS_OUTPUT.PUT_LINE('TEST 1: Yeni personel ekleniyor (ID=9999)...');

    pkg_payroll_entry.add_employee(
        p_emp_id      => 9999,
        p_company_id  => 1,
        p_dept_id     => 100,
        p_job_id      => 200,
        p_national_id => '99999999999',
        p_first_name  => 'Test',
        p_last_name   => 'Personeli'
    );

    SELECT COUNT(*) INTO v_attendance_count
    FROM Attendance_Records WHERE fk_employee_id = 9999;

    DBMS_OUTPUT.PUT_LINE('--> Trigger sonucu: ' || v_attendance_count || ' adet puantaj kaydi otomatik olusturuldu.');
    DBMS_OUTPUT.PUT_LINE('');

    -- TEST 2: Bordro INSERT trigger'i (trg_payroll_audit - INSERTING)
    DBMS_OUTPUT.PUT_LINE('TEST 2: Test personeli icin bordro ekleniyor (payroll_id=9999)...');

    pkg_payroll_entry.add_payroll(
        p_payroll_id     => 9999,
        p_employee_id    => 9999,
        p_company_id     => 1,
        p_period_month   => 5,
        p_period_year    => 2026,
        p_gross_salary   => 120000,
        p_net_salary     => 95000,
        p_total_tax      => 25000,
        p_payment_status => 'PAID'
    );

    SELECT COUNT(*) INTO v_log_count FROM Payroll_Logs WHERE fk_payroll_id = 9999;
    DBMS_OUTPUT.PUT_LINE('--> Trigger sonucu: ' || v_log_count || ' adet INSERT logu olusturuldu.');
    DBMS_OUTPUT.PUT_LINE('');

    -- TEST 3: Bordro UPDATE trigger'i (trg_payroll_audit - UPDATING)
    DBMS_OUTPUT.PUT_LINE('TEST 3: Bordro guncelleniyor...');
    UPDATE Payroll_Summary SET net_salary = 100000 WHERE payroll_id = 9999;
    SELECT COUNT(*) INTO v_log_count FROM Payroll_Logs WHERE fk_payroll_id = 9999;
    DBMS_OUTPUT.PUT_LINE('--> Trigger sonucu: Toplam ' || v_log_count || ' adet log var.');
    DBMS_OUTPUT.PUT_LINE('');

    -- TEST 4: Bordro DELETE trigger'i (trg_payroll_audit - DELETING)
    DBMS_OUTPUT.PUT_LINE('TEST 4: Bordro siliniyor...');
    DELETE FROM Payroll_Summary WHERE payroll_id = 9999;
    SELECT COUNT(*) INTO v_log_count FROM Payroll_Logs WHERE fk_payroll_id = 9999;
    DBMS_OUTPUT.PUT_LINE('--> Trigger sonucu: Toplam ' || v_log_count || ' adet log var.');
    DBMS_OUTPUT.PUT_LINE('');

    -- Loglarin detayli listesi
    DBMS_OUTPUT.PUT_LINE('=== OLUSTURULAN LOGLARIN DETAYI ===');
    FOR rec IN (SELECT log_id, action_type FROM Payroll_Logs
                WHERE fk_payroll_id = 9999 ORDER BY action_timestamp) LOOP
        DBMS_OUTPUT.PUT_LINE('Log ID: ' || rec.log_id || ' | Islem: ' || rec.action_type);
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('=== TEST TAMAMLANDI ===');

    -- Test verilerini temizle (veritabanini orijinal haline dondur)
    DELETE FROM Payroll_Logs WHERE fk_payroll_id = 9999;
    DELETE FROM Attendance_Records WHERE fk_employee_id = 9999;
    DELETE FROM Employees WHERE employee_id = 9999;
    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('HATA: ' || SQLERRM);
END;
/
