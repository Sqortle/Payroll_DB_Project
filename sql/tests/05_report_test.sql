-- ==========================================
-- Test 5: Dinamik Rapor Testi (Madde 8.3)
-- IMSA sirketinin (company_id=1) butun calisanlarini listele.
-- ==========================================

SET SERVEROUTPUT ON;

DECLARE
    v_report_cursor SYS_REFCURSOR;

    -- Calisan Raporu icin degiskenler
    v_emp_code VARCHAR2(30);
    v_tc VARCHAR2(11);
    v_fname VARCHAR2(50);
    v_lname VARCHAR2(50);
    v_dept VARCHAR2(100);
    v_title VARCHAR2(100);
    v_mult NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('--- IMSA SIRKETI BUTUN CALISANLAR RAPORU ---');

    -- Fonksiyonu sadece Sirket ID (1) ile cagiriyoruz. (Departman ve unvan kisiti yollamiyoruz, dinamik olarak tumunu getirecek)
    v_report_cursor := pkg_payroll_reports.get_employee_report(p_company_id => 1);

    LOOP
        FETCH v_report_cursor INTO v_emp_code, v_tc, v_fname, v_lname, v_dept, v_title, v_mult;
        EXIT WHEN v_report_cursor%NOTFOUND;

        DBMS_OUTPUT.PUT_LINE(v_emp_code || ' - ' || v_fname || ' ' || v_lname || ' | ' || v_dept || ' | ' || v_title);
    END LOOP;

    CLOSE v_report_cursor;
END;
/
