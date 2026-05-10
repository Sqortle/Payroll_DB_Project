-- ==========================================
-- Madde 3: Indeksler (PK / FK / UNIQUE / Composite)
-- ==========================================

-- ==========================================
-- 1. PRIMARY KEY (BIRINCIL ANAHTAR) TANIMLAMALARI
-- ==========================================

ALTER TABLE Companies ADD CONSTRAINT pk_companies PRIMARY KEY (company_id);
ALTER TABLE Users ADD CONSTRAINT pk_users PRIMARY KEY (user_id);
ALTER TABLE Departments ADD CONSTRAINT pk_departments PRIMARY KEY (department_id);
ALTER TABLE Job_Titles ADD CONSTRAINT pk_job_titles PRIMARY KEY (job_title_id);
ALTER TABLE Employees ADD CONSTRAINT pk_employees PRIMARY KEY (employee_id);
ALTER TABLE Employee_Contracts ADD CONSTRAINT pk_contracts PRIMARY KEY (contract_id);
ALTER TABLE Tax_Slabs ADD CONSTRAINT pk_tax_slabs PRIMARY KEY (slab_id);
ALTER TABLE Statutory_Parameters ADD CONSTRAINT pk_stat_params PRIMARY KEY (param_id);
ALTER TABLE Allowance_Types ADD CONSTRAINT pk_allowance_types PRIMARY KEY (allowance_type_id);
ALTER TABLE Deduction_Types ADD CONSTRAINT pk_deduction_types PRIMARY KEY (deduction_type_id);
ALTER TABLE Attendance_Records ADD CONSTRAINT pk_attendance PRIMARY KEY (attendance_id);
ALTER TABLE Employee_Allowances ADD CONSTRAINT pk_emp_allowances PRIMARY KEY (emp_allowance_id);
ALTER TABLE Employee_Deductions ADD CONSTRAINT pk_emp_deductions PRIMARY KEY (emp_deduction_id);
ALTER TABLE Payroll_Summary ADD CONSTRAINT pk_payroll_summary PRIMARY KEY (payroll_id);
ALTER TABLE Payroll_Logs ADD CONSTRAINT pk_payroll_logs PRIMARY KEY (log_id);


-- ==========================================
-- 2. FOREIGN KEY (YABANCI ANAHTAR) TANIMLAMALARI
-- ==========================================

-- Users
ALTER TABLE Users ADD CONSTRAINT fk_user_company FOREIGN KEY (fk_company_id) REFERENCES Companies(company_id);

-- Departments
ALTER TABLE Departments ADD CONSTRAINT fk_dept_company FOREIGN KEY (fk_company_id) REFERENCES Companies(company_id);

-- Job Titles
ALTER TABLE Job_Titles ADD CONSTRAINT fk_job_company FOREIGN KEY (fk_company_id) REFERENCES Companies(company_id);

-- Employees
ALTER TABLE Employees ADD CONSTRAINT fk_emp_company FOREIGN KEY (fk_company_id) REFERENCES Companies(company_id);
ALTER TABLE Employees ADD CONSTRAINT fk_emp_dept FOREIGN KEY (fk_department_id) REFERENCES Departments(department_id);
ALTER TABLE Employees ADD CONSTRAINT fk_emp_job FOREIGN KEY (fk_job_title_id) REFERENCES Job_Titles(job_title_id);

-- Employee Contracts
ALTER TABLE Employee_Contracts ADD CONSTRAINT fk_cont_emp FOREIGN KEY (fk_employee_id) REFERENCES Employees(employee_id);
ALTER TABLE Employee_Contracts ADD CONSTRAINT fk_cont_company FOREIGN KEY (fk_company_id) REFERENCES Companies(company_id);

-- Tax Slabs & Statutory Parameters (SaaS Yapisi)
ALTER TABLE Tax_Slabs ADD CONSTRAINT fk_tax_company FOREIGN KEY (fk_company_id) REFERENCES Companies(company_id);
ALTER TABLE Statutory_Parameters ADD CONSTRAINT fk_stat_company FOREIGN KEY (fk_company_id) REFERENCES Companies(company_id);

-- Allowances & Deductions Types
ALTER TABLE Allowance_Types ADD CONSTRAINT fk_alw_type_company FOREIGN KEY (fk_company_id) REFERENCES Companies(company_id);
ALTER TABLE Deduction_Types ADD CONSTRAINT fk_ded_type_company FOREIGN KEY (fk_company_id) REFERENCES Companies(company_id);

-- Attendance Records
ALTER TABLE Attendance_Records ADD CONSTRAINT fk_att_emp FOREIGN KEY (fk_employee_id) REFERENCES Employees(employee_id);
ALTER TABLE Attendance_Records ADD CONSTRAINT fk_att_company FOREIGN KEY (fk_company_id) REFERENCES Companies(company_id);

-- Employee Allowances
ALTER TABLE Employee_Allowances ADD CONSTRAINT fk_ea_emp FOREIGN KEY (fk_employee_id) REFERENCES Employees(employee_id);
ALTER TABLE Employee_Allowances ADD CONSTRAINT fk_ea_company FOREIGN KEY (fk_company_id) REFERENCES Companies(company_id);
ALTER TABLE Employee_Allowances ADD CONSTRAINT fk_ea_type FOREIGN KEY (fk_allowance_type_id) REFERENCES Allowance_Types(allowance_type_id);

-- Employee Deductions
ALTER TABLE Employee_Deductions ADD CONSTRAINT fk_ed_emp FOREIGN KEY (fk_employee_id) REFERENCES Employees(employee_id);
ALTER TABLE Employee_Deductions ADD CONSTRAINT fk_ed_company FOREIGN KEY (fk_company_id) REFERENCES Companies(company_id);
ALTER TABLE Employee_Deductions ADD CONSTRAINT fk_ed_type FOREIGN KEY (fk_deduction_type_id) REFERENCES Deduction_Types(deduction_type_id);

-- Payroll Summary
ALTER TABLE Payroll_Summary ADD CONSTRAINT fk_pay_emp FOREIGN KEY (fk_employee_id) REFERENCES Employees(employee_id);
ALTER TABLE Payroll_Summary ADD CONSTRAINT fk_pay_company FOREIGN KEY (fk_company_id) REFERENCES Companies(company_id);

-- Payroll Logs
-- NOT: fk_log_payroll FK'si KASTEN eklenmedi. Audit log tablolari kaynak tabloya FK ile baglanmaz;
-- aksi halde bordro DELETE edildiginde mevcut INSERT/UPDATE loglari yuzunden FK ihlali olur (ORA-02292)
-- ve trigger DELETE log'unu yazamaz. Audit log = kalici, kaynak = mutable.
ALTER TABLE Payroll_Logs ADD CONSTRAINT fk_log_company FOREIGN KEY (fk_company_id) REFERENCES Companies(company_id);
ALTER TABLE Payroll_Logs ADD CONSTRAINT fk_log_user FOREIGN KEY (fk_user_id) REFERENCES Users(user_id);


-- ==========================================
-- 3. PERFORMANS ICIN COMPOSITE (BILESIK) VE FK INDEKS TANIMLAMALARI
-- ==========================================

-- Ayni sirkette ayni TCKN ile birden fazla personel acilamamasi icin (Bilesik Unique Indeks)
ALTER TABLE Employees ADD CONSTRAINT uq_emp_national_id UNIQUE (fk_company_id, national_id);
ALTER TABLE Employees ADD CONSTRAINT uq_emp_code UNIQUE (fk_company_id, employee_code);

-- Ayni personelin, ayni ay ve yil icin sadece bir tane puantaj kaydi olabilmesi icin (Bilesik Unique Indeks)
ALTER TABLE Attendance_Records ADD CONSTRAINT uq_attendance_period UNIQUE (fk_employee_id, record_month, record_year);

-- Ayni personelin, ayni ay ve yil icin sadece bir bordrosu olabilmesi icin
ALTER TABLE Payroll_Summary ADD CONSTRAINT uq_payroll_period UNIQUE (fk_employee_id, period_month, period_year);

-- Sorgulama performansini artirmak icin sik kullanilan Foreign Key indeksleri
CREATE INDEX idx_emp_dept ON Employees(fk_department_id);
CREATE INDEX idx_emp_job ON Employees(fk_job_title_id);
CREATE INDEX idx_att_emp ON Attendance_Records(fk_employee_id);
CREATE INDEX idx_payroll_emp ON Payroll_Summary(fk_employee_id);
