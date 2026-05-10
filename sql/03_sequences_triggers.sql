-- ==========================================
-- Madde 7: Sequence'ler ve Trigger'lar
-- (Tanim Tablosuna Veri Girisi -> Hareket Tablosuna Otomatik Veri)
-- ==========================================

-- ==========================================
-- 1. PUANTAJ (ATTENDANCE) OTOMASYONU
-- ==========================================
-- Personel (Employees) tablosuna yeni kayit atildiginda o ayki puantaj kaydini otomatik acar.

CREATE SEQUENCE seq_attendance_id
START WITH 10000
INCREMENT BY 1;
/

CREATE OR REPLACE TRIGGER trg_after_emp_insert
AFTER INSERT ON Employees
FOR EACH ROW
DECLARE
    v_current_month NUMBER;
    v_current_year NUMBER;
BEGIN
    -- Sistemin o anki ay ve yil bilgisini al
    v_current_month := EXTRACT(MONTH FROM SYSDATE);
    v_current_year := EXTRACT(YEAR FROM SYSDATE);

    -- Yeni personel icin sifir degerli puantaj kaydini olustur
    INSERT INTO Attendance_Records (
        attendance_id,
        fk_employee_id,
        fk_company_id,
        record_month,
        record_year,
        worked_days,
        overtime_hours
    ) VALUES (
        seq_attendance_id.NEXTVAL,
        :NEW.employee_id,
        :NEW.fk_company_id,
        v_current_month,
        v_current_year,
        0,
        0
    );
END;
/

-- ==========================================
-- 2. DENETIM (AUDIT LOG) OTOMASYONU
-- ==========================================
-- Bordro (Payroll_Summary) tablosunda yapilan DML (Insert/Update/Delete) islemlerini loglar.

CREATE SEQUENCE seq_payroll_log_id
START WITH 1000
INCREMENT BY 1;
/

CREATE OR REPLACE TRIGGER trg_payroll_audit
AFTER INSERT OR UPDATE OR DELETE ON Payroll_Summary
FOR EACH ROW
DECLARE
    v_action_type VARCHAR2(50);
    v_target_payroll_id NUMBER;
    v_target_company_id NUMBER;
BEGIN
    -- Yapilan islemin turunu Oracle dahili degiskenleriyle tespit et
    IF INSERTING THEN
        v_action_type := 'INSERT - YENI BORDRO HESAPLANDI';
        v_target_payroll_id := :NEW.payroll_id;
        v_target_company_id := :NEW.fk_company_id;

    ELSIF UPDATING THEN
        v_action_type := 'UPDATE - BORDRO RAKAMLARI DEGISTIRILDI';
        v_target_payroll_id := :NEW.payroll_id;
        v_target_company_id := :NEW.fk_company_id;

    ELSIF DELETING THEN
        v_action_type := 'DELETE - BORDRO IPTAL EDILDI';
        v_target_payroll_id := :OLD.payroll_id;
        v_target_company_id := :OLD.fk_company_id;
    END IF;

    -- Tespit edilen hareketi Payroll_Logs tablosuna yaz
    INSERT INTO Payroll_Logs (
        log_id,
        fk_payroll_id,
        fk_company_id,
        fk_user_id,
        action_type,
        action_timestamp
    ) VALUES (
        seq_payroll_log_id.NEXTVAL,
        v_target_payroll_id,
        v_target_company_id,
        NULL, -- Tetikleyici veritabani seviyesinde calistigi icin uygulama kullanicisi bos gecilir
        v_action_type,
        CURRENT_TIMESTAMP
    );
END;
/
