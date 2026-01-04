# 💼 AdminLTE Finance Portal

A comprehensive financial management system built with **Angular 18+** and **MySQL**, featuring income/expense tracking, account management, reporting, and user administration.

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Angular](https://img.shields.io/badge/Angular-18+-red.svg)
![PHP](https://img.shields.io/badge/PHP-8.2+-purple.svg)
![MySQL](https://img.shields.io/badge/MySQL-8.0+-blue.svg)

---

## 📋 Table of Contents

- [Features](#-features)
- [Tech Stack](#-tech-stack)
- [Prerequisites](#-prerequisites)
- [Quick Start](#-quick-start)
- [Manual Installation](#-manual-installation)
- [Project Structure](#-project-structure)
- [Configuration](#-configuration)
- [API Endpoints](#-api-endpoints)
- [User Guide](#-user-guide)
- [Security Features](#-security-features)
- [Troubleshooting](#-troubleshooting)
- [Development](#-development)
- [Production Deployment](#-production-deployment)
- [License](#-license)

---

## ✨ Features

### 📊 **Financial Management**
- **Daily Income Tracking** - Record income by multiple payment methods
- **Expense Management** - Track expenses with categories, vendors, and attachments
- **Account Management** - Manage multiple bank accounts, wallets, and cards
- **Monthly Snapshots** - Capture account balances on the 1st of each month

### 📈 **Reporting & Analytics**
- **Real-time Dashboard** - View today's income, MTD stats, and profit/loss
- **Visual Charts** - Income vs Expenses with D3.js charts
- **Category Breakdown** - Pie charts for expense distribution
- **Monthly Reports** - Detailed monthly income/expense summaries

### 👥 **User Management**
- **Multi-user Support** - Admin and regular user roles
- **User Profiles** - Customizable user information
- **Two-Factor Authentication (2FA)** - Enhanced security with TOTP
- **Password Strength Meter** - Real-time password validation
- **Email Verification** - Secure email change verification

### ⚙️ **Administration**
- **Company Settings** - Configure company name and branding
- **SMTP Configuration** - Email server settings for notifications
- **Expense Categories** - Customizable expense categories
- **Payment Methods** - Manage payment types and income methods
- **User Administration** - Create, edit, and delete users

### 🎨 **User Experience**
- **Dark Mode** - Toggle between light and dark themes
- **Responsive Design** - Mobile-friendly interface with Tailwind CSS
- **Real-time Updates** - Signal-based reactive state management
- **Inline Editing** - Edit records without page navigation
- **Form Validation** - Client-side validation with error messages

### 🔒 **Security**
- **Password Hashing** - BCrypt password encryption
- **SQL Injection Protection** - PDO prepared statements
- **CSRF Protection** - Cross-site request forgery prevention
- **XSS Protection** - Content security headers
- **Role-Based Access Control** - Admin and user permissions
- **Session Management** - Secure session handling

---

## 🛠️ Tech Stack

### **Frontend**
- **Angular 18+** - Modern TypeScript framework
- **Tailwind CSS** - Utility-first CSS framework
- **D3.js** - Data visualization library
- **RxJS** - Reactive programming library
- **Signals** - Angular's new reactivity system

### **Backend**
- **PHP 8.2+** - Server-side scripting
- **MySQL 8.0+** - Relational database
- **RESTful API** - JSON-based communication
- **PDO** - Database abstraction layer

### **Web Server**
- **Nginx** / **Apache** - HTTP server
- **PHP-FPM** - FastCGI Process Manager
- **Let's Encrypt** - Free SSL certificates

### **DevOps**
- **Node.js 20+** - JavaScript runtime
- **npm** - Package manager
- **Angular CLI** - Command-line interface
- **Certbot** - SSL certificate automation

---

## 📦 Prerequisites

### **System Requirements**
- **OS**: Ubuntu 20.04+, Debian 11+, RHEL 8+, CentOS 8+, Rocky Linux 8+, AlmaLinux 8+
- **RAM**: Minimum 2GB (4GB recommended)
- **Disk Space**: 5GB free space
- **Root Access**: sudo privileges required

### **Software (Auto-installed by setup script)**
- MySQL 8.0+
- PHP 8.2+
- Nginx or Apache
- Node.js 20+
- Angular CLI

---

## 🚀 Quick Start

### **Automated Installation (Recommended)**

```bash
# 1. Clone the repository
git clone https://github.com/yourusername/adminlte-finance-portal.git
cd adminlte-finance-portal

# 2. Make setup script executable
chmod +x setup.sh

# 3. Run the automated installer
sudo ./setup.sh
