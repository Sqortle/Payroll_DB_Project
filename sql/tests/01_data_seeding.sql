-- ==========================================
-- Test 1: Veri Girisi Ana Blogu (Madde 4.3)
-- 4 Sirket (IMSA, MISA, SIMA, AIMS) + her birinde 30 calisan
-- Personel ID'leri 300'den baslar.
-- ==========================================

DECLARE
    v_comp_id NUMBER;
    v_dept_id NUMBER := 100;
    v_job_id NUMBER := 200;
    v_emp_id NUMBER := 300;
    v_contract_id NUMBER := 400;
    v_user_id NUMBER := 500;

    -- Gecici degiskenler
    v_current_dept NUMBER;
    v_current_job NUMBER;
    v_tckn_base NUMBER := 10000000000;
BEGIN
    -- 4 SIRKET VE CEO'LARININ EKLENMESI

    -- 1. Isa Mirza Sincap - IMSA
    pkg_payroll_entry.add_company(1, 'IMSA', 'mirzasincap@gmail.com');
    pkg_payroll_entry.add_department(1, 1, 'Executive Board');
    pkg_payroll_entry.add_job_title(1, 1, 'CEO', 500000);
    pkg_payroll_entry.add_user(1, 1, 'isasmirza', 'mirzasincap@gmail.com', 'Admin');
    pkg_payroll_entry.add_employee(1, 1, 1, 1, '23120205033', 'Isa Mirza', 'Sincap');
    pkg_payroll_entry.add_contract(1, 1, 1, 1.0);

    -- 2. Mirza Sakiroglu - MISA
    pkg_payroll_entry.add_company(2, 'MISA', 'mirzasakiroglu@gmail.com');
    pkg_payroll_entry.add_department(2, 2, 'Executive Board');
    pkg_payroll_entry.add_job_title(2, 2, 'CEO', 500000);
    pkg_payroll_entry.add_user(2, 2, 'mirzas', 'mirzasakiroglu@gmail.com', 'Admin');
    pkg_payroll_entry.add_employee(2, 2, 2, 2, '23120205028', 'Mirza', 'Sakiroglu');
    pkg_payroll_entry.add_contract(2, 2, 2, 1.0);

    -- 3. Selim Genc - SIMA
    pkg_payroll_entry.add_company(3, 'SIMA', 'selingnc44@gmail.com');
    pkg_payroll_entry.add_department(3, 3, 'Executive Board');
    pkg_payroll_entry.add_job_title(3, 3, 'CEO', 500000);
    pkg_payroll_entry.add_user(3, 3, 'selimg', 'selingnc44@gmail.com', 'Admin');
    pkg_payroll_entry.add_employee(3, 3, 3, 3, '23120205034', 'Selim', 'Genc');
    pkg_payroll_entry.add_contract(3, 3, 3, 1.0);

    -- 4. Ali Emre Aydin - AIMS
    pkg_payroll_entry.add_company(4, 'AIMS', 'aliemreaydin111@gmail.com');
    pkg_payroll_entry.add_department(4, 4, 'Executive Board');
    pkg_payroll_entry.add_job_title(4, 4, 'CEO', 500000);
    pkg_payroll_entry.add_user(4, 4, 'aliemrea', 'aliemreaydin111@gmail.com', 'Admin');
    pkg_payroll_entry.add_employee(4, 4, 4, 4, '23120205056', 'Ali Emre', 'Aydin');
    pkg_payroll_entry.add_contract(4, 4, 4, 1.0);


    -- HER SIRKETE 6 UNVAN, 3 DEPARTMAN VE 30 CALISAN EKLENMESI (DONGU)
    FOR v_comp_id IN 1..4 LOOP

        -- Sirket basina standart departmanlar
        pkg_payroll_entry.add_department(v_dept_id, v_comp_id, 'Engineering');
        pkg_payroll_entry.add_department(v_dept_id + 1, v_comp_id, 'Human Resources');
        pkg_payroll_entry.add_department(v_dept_id + 2, v_comp_id, 'Sales');

        -- Sirket basina standart unvanlar ve baz maaslar
        pkg_payroll_entry.add_job_title(v_job_id, v_comp_id, 'Senior Software Engineer', 120000);
        pkg_payroll_entry.add_job_title(v_job_id + 1, v_comp_id, 'Junior Software Engineer', 60000);
        pkg_payroll_entry.add_job_title(v_job_id + 2, v_comp_id, 'HR Manager', 85000);
        pkg_payroll_entry.add_job_title(v_job_id + 3, v_comp_id, 'HR Specialist', 45000);
        pkg_payroll_entry.add_job_title(v_job_id + 4, v_comp_id, 'Sales Director', 100000);
        pkg_payroll_entry.add_job_title(v_job_id + 5, v_comp_id, 'Sales Representative', 40000);

        -- Her sirket icin 30 calisan olustur
        FOR i IN 1..30 LOOP
            -- Rastgele departman ve unvan secimi icin basit moduler aritmetik
            v_current_dept := v_dept_id + MOD(i, 3);
            v_current_job := v_job_id + MOD(i, 6);

            pkg_payroll_entry.add_employee(
                v_emp_id,
                v_comp_id,
                v_current_dept,
                v_current_job,
                TO_CHAR(v_tckn_base + v_emp_id), -- Benzersiz TCKN
                'Person' || v_emp_id,
                'Surname' || v_emp_id
            );

            -- Calisan Sozlesmesi (Rastgele carpan: 1.0 ile 1.2 arasi)
            pkg_payroll_entry.add_contract(v_contract_id, v_emp_id, v_comp_id, 1.0 + (MOD(i, 3)/10));

            v_emp_id := v_emp_id + 1;
            v_contract_id := v_contract_id + 1;
        END LOOP;

        -- ID'leri bir sonraki sirket icin ilerlet
        v_dept_id := v_dept_id + 10;
        v_job_id := v_job_id + 10;
    END LOOP;

    COMMIT;
END;
/
