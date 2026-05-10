-- ==========================================
-- Madde 8: Dinamik Raporlama Paketi (pkg_payroll_reports)
-- Specification + Body
-- ==========================================

CREATE OR REPLACE PACKAGE pkg_payroll_reports AS

    -- 1. Dinamik Calisan Raporu (Departman veya Unvan filtresi opsiyoneldir)
    FUNCTION get_employee_report(
        p_company_id NUMBER,
        p_department_id NUMBER DEFAULT NULL,
        p_job_title_id NUMBER DEFAULT NULL
    ) RETURN SYS_REFCURSOR;

    -- 2. Dinamik Aylik Bordro Raporu (Belirli bir personel veya tum sirket icin)
    FUNCTION get_monthly_payroll(
        p_company_id NUMBER,
        p_period_month NUMBER,
        p_period_year NUMBER,
        p_employee_id NUMBER DEFAULT NULL
    ) RETURN SYS_REFCURSOR;

END pkg_payroll_reports;
/

CREATE OR REPLACE PACKAGE BODY pkg_payroll_reports AS

    -- 1. Dinamik Calisan Raporu
    FUNCTION get_employee_report(
        p_company_id NUMBER,
        p_department_id NUMBER DEFAULT NULL,
        p_job_title_id NUMBER DEFAULT NULL
    ) RETURN SYS_REFCURSOR
    IS
        v_sql VARCHAR2(4000);
        v_cursor SYS_REFCURSOR;
    BEGIN
        -- Temel sorgu ve zorunlu sirket kisiti (SaaS guvenligi icin)
        v_sql := 'SELECT e.employee_code, e.national_id, e.first_name, e.last_name, ' ||
                 'd.department_name, j.title_name, c.salary_multiplier ' ||
                 'FROM Employees e ' ||
                 'JOIN Departments d ON e.fk_department_id = d.department_id ' ||
                 'JOIN Job_Titles j ON e.fk_job_title_id = j.job_title_id ' ||
                 'JOIN Employee_Contracts c ON e.employee_id = c.fk_employee_id ' ||
                 'WHERE e.fk_company_id = ' || p_company_id || ' AND c.is_active = 1';

        -- Dinamik Kisit 1: Departman filtresi geldiyse WHERE cumlesine ekle
        IF p_department_id IS NOT NULL THEN
            v_sql := v_sql || ' AND e.fk_department_id = ' || p_department_id;
        END IF;

        -- Dinamik Kisit 2: Unvan filtresi geldiyse WHERE cumlesine ekle
        IF p_job_title_id IS NOT NULL THEN
            v_sql := v_sql || ' AND e.fk_job_title_id = ' || p_job_title_id;
        END IF;

        -- Sorguyu siraya koy (ORDER BY)
        v_sql := v_sql || ' ORDER BY e.first_name, e.last_name';

        -- Dinamik SQL'i calistir ve imleci (cursor) dondur
        OPEN v_cursor FOR v_sql;
        RETURN v_cursor;
    END get_employee_report;

    -- 2. Dinamik Aylik Bordro Raporu
    FUNCTION get_monthly_payroll(
        p_company_id NUMBER,
        p_period_month NUMBER,
        p_period_year NUMBER,
        p_employee_id NUMBER DEFAULT NULL
    ) RETURN SYS_REFCURSOR
    IS
        v_sql VARCHAR2(4000);
        v_cursor SYS_REFCURSOR;
    BEGIN
        -- Temel sorgu (Belirli bir ay ve yil icin)
        v_sql := 'SELECT p.payroll_id, e.first_name || '' '' || e.last_name AS full_name, ' ||
                 'p.gross_salary, p.total_tax, p.net_salary, p.payment_status ' ||
                 'FROM Payroll_Summary p ' ||
                 'JOIN Employees e ON p.fk_employee_id = e.employee_id ' ||
                 'WHERE p.fk_company_id = ' || p_company_id ||
                 ' AND p.period_month = ' || p_period_month ||
                 ' AND p.period_year = ' || p_period_year;

        -- Dinamik Kisit: Eger tek bir personele ait dokum isteniyorsa
        IF p_employee_id IS NOT NULL THEN
            v_sql := v_sql || ' AND p.fk_employee_id = ' || p_employee_id;
        END IF;

        OPEN v_cursor FOR v_sql;
        RETURN v_cursor;
    END get_monthly_payroll;

END pkg_payroll_reports;
/
