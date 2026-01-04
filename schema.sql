-- schema.sql
CREATE DATABASE IF NOT EXISTS adminlte_finance CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE adminlte_finance;

-- Users Table
CREATE TABLE users (
    id INT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(50) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    name VARCHAR(50),
    surname VARCHAR(50),
    role ENUM('admin', 'user') DEFAULT 'user',
    two_factor_enabled BOOLEAN DEFAULT FALSE,
    two_factor_secret VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Settings Table
CREATE TABLE settings (
    id INT PRIMARY KEY AUTO_INCREMENT,
    company_name VARCHAR(100) DEFAULT 'AdminLTE Finance',
    smtp_host VARCHAR(100),
    smtp_port INT DEFAULT 587,
    smtp_user VARCHAR(100),
    smtp_password VARCHAR(255),
    smtp_secure BOOLEAN DEFAULT TRUE,
    smtp_from_name VARCHAR(100),
    smtp_from_email VARCHAR(100),
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Income Methods
CREATE TABLE income_methods (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(50) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    sort_order INT DEFAULT 0
);

-- Expense Types
CREATE TABLE expense_types (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(50) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE
);

-- Expense Categories
CREATE TABLE expense_categories (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(50) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE
);

-- Accounts
CREATE TABLE accounts (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    type ENUM('Bank', 'Wallet', 'Card', 'Cash') NOT NULL,
    currency VARCHAR(3) DEFAULT 'EUR',
    active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Income Entries
CREATE TABLE income_entries (
    id INT PRIMARY KEY AUTO_INCREMENT,
    date DATE NOT NULL,
    notes TEXT,
    created_by INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL,
    INDEX idx_date (date)
);

-- Income Entry Lines
CREATE TABLE income_entry_lines (
    id INT PRIMARY KEY AUTO_INCREMENT,
    entry_id INT NOT NULL,
    method_id INT NOT NULL,
    amount DECIMAL(10, 2) NOT NULL,
    FOREIGN KEY (entry_id) REFERENCES income_entries(id) ON DELETE CASCADE,
    FOREIGN KEY (method_id) REFERENCES income_methods(id)
);

-- Expense Entries
CREATE TABLE expense_entries (
    id INT PRIMARY KEY AUTO_INCREMENT,
    date DATE NOT NULL,
    vendor VARCHAR(100) NOT NULL,
    amount DECIMAL(10, 2) NOT NULL,
    payment_type_id INT NOT NULL,
    category_id INT NOT NULL,
    cheque_no VARCHAR(50),
    reason TEXT,
    attachment LONGTEXT,
    created_by INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (payment_type_id) REFERENCES expense_types(id),
    FOREIGN KEY (category_id) REFERENCES expense_categories(id),
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL,
    INDEX idx_date (date)
);

-- Account Snapshots
CREATE TABLE account_snapshots (
    id INT PRIMARY KEY AUTO_INCREMENT,
    month DATE NOT NULL,
    is_locked BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY unique_month (month)
);

-- Snapshot Balances
CREATE TABLE snapshot_balances (
    id INT PRIMARY KEY AUTO_INCREMENT,
    snapshot_id INT NOT NULL,
    account_id INT NOT NULL,
    balance DECIMAL(10, 2) NOT NULL,
    FOREIGN KEY (snapshot_id) REFERENCES account_snapshots(id) ON DELETE CASCADE,
    FOREIGN KEY (account_id) REFERENCES accounts(id)
);

-- Insert Default Data
INSERT INTO users (username, password, email, name, surname, role) 
VALUES ('admin', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'admin@company.com', 'Admin', 'User', 'admin');
-- Default password: password

INSERT INTO settings (company_name) VALUES ('AdminLTE Finance');

INSERT INTO income_methods (name, sort_order) VALUES 
('Cash', 1), ('Revolut', 2), ('Visa', 3), ('Other', 4);

INSERT INTO expense_types (name) VALUES 
('SEPA'), ('Cash'), ('Visa'), ('Cheque');

INSERT INTO expense_categories (name) VALUES 
('Rent'), ('Supplies'), ('Utilities'), ('Payroll'), ('Marketing');

INSERT INTO accounts (name, type, currency) VALUES 
('Bank of Cyprus - Biz', 'Bank', 'EUR'),
('Hellenic Bank - Biz', 'Bank', 'EUR'),
('Revolut', 'Wallet', 'EUR'),
('JCC', 'Card', 'EUR');
