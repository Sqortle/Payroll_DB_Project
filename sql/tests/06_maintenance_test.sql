-- ==========================================
-- Test 6: Mukerrer Kayit Temizleme Testi (Madde 10.3)
-- Tum tablolarda ROWID bazli mukerrer kayit silme prosedurunu cagirir.
-- ==========================================

BEGIN
    pkg_payroll_maintenance.remove_all_duplicates();
END;
/
