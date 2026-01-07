
# AdminLTE Finance Portal

A full-stack, single-page application designed for small to medium-sized businesses to track their daily finances. Built with a modern Angular frontend and a robust Node.js backend, it offers a comprehensive suite of tools for managing income, expenses, and account balances, all presented in a clean, professional interface inspired by AdminLTE.

![Finance Portal Screenshot](https://i.imgur.com/8a6Q4sJ.png) 

## ✨ Features

- **Responsive Dashboard**: At-a-glance view of key metrics like today's income, month-to-date performance, and a 30-day income vs. expense chart.
- **Daily Income Management**: Log daily income totals, categorized by payment method (e.g., Cash, Bank Transfer).
- **Expense Tracking**: Record individual expenses with details like vendor, category, payment type, and an optional receipt attachment.
- **Account Management**: Define financial accounts (e.g., Bank, Cash Wallet) and record monthly balance snapshots.
- **Insightful Reports**: View a monthly profit/loss summary and a visual breakdown of expenses by category.
- **Secure Authentication**: User login system with support for Two-Factor Authentication (2FA).
- **User Roles**: Differentiated access levels for `Admin` and `User` roles.
- **Comprehensive Settings**:
    - Manage company details and SMTP server configuration for email.
    - Add, edit, and remove users.
    - Configure transaction categories (income methods, expense categories, payment types).
- **Profile Management**: Users can update their personal details, change their password, and manage their 2FA settings.
- **Dark/Light Mode**: Toggle between light and dark themes for user comfort.

## 🛠️ Technology Stack

- **Frontend**:
    - **Angular (v20+)**: Modern, zoneless architecture with Standalone Components and Signals for state management.
    - **TypeScript**: For type-safe application logic.
    - **Tailwind CSS**: For a utility-first approach to styling, customized to match AdminLTE aesthetics.
    - **D3.js**: For dynamic and interactive data visualizations.
- **Backend**:
    - **Node.js & Express.js**: For a fast and scalable RESTful API.
    - **PostgreSQL**: A powerful, open-source object-relational database system.
    - **bcryptjs**: For secure password hashing.
- **Deployment**:
    - **Nginx**: High-performance reverse proxy for serving the frontend and API.
    - **PM2**: A production process manager for Node.js applications to ensure uptime.
    - **Bash Script**: An automated `install.sh` script for easy deployment on Linux servers.

## 🚀 Production Deployment (Linux)

This project includes an automated installation script to simplify deployment on a fresh Linux server.

### Prerequisites

1.  A Linux server (tested on Ubuntu 22.04, compatible with Debian/RHEL/CentOS/Fedora).
2.  A domain name with its A record pointing to your server's public IP address.
3.  (Optional but Recommended) A wildcard or commercial SSL certificate if you are on an internal network.

### Installation Steps

1.  **Upload Project**: Transfer the entire project folder to your server (e.g., into `/var/www/finance-portal`).

2.  **Navigate to Directory**:
    ```bash
    cd /path/to/your/project
    ```

3.  **Make Script Executable**:
    ```bash
    chmod +x install.txt
    ```

4.  **Run the Installer**:
    ```bash
    sudo ./install.txt
    ```

5.  **Follow On-Screen Prompts**: The script will guide you through:
    -   Creating a database name, user, and a secure password.
    -   Entering your domain name (e.g., `finance.yourcompany.com`).
    -   Configuring SSL. You will be given two choices:
        -   **Let's Encrypt (Certbot)**: An automatic, free option suitable for public-facing servers.
        -   **Manual/Wildcard Certificate**: The correct choice for internal networks or if you already have a commercial SSL certificate. You will be asked to provide the full server paths to your certificate and private key files.

6.  **Finalize PM2 Setup**: After the script completes, it will output one final command. This command enables the PM2 startup service, which ensures your API server automatically restarts if the server reboots. **Copy this command, paste it into your terminal, and run it.**

7.  **Done!** Your application is now live and accessible at your domain.

## 💻 Local Development

1.  **Backend Setup**:
    -   Navigate to the API directory: `cd api`.
    -   Create a `.env` file and configure your local PostgreSQL database connection:
        ```env
        DB_HOST=localhost
        DB_PORT=5432
        DB_USER=your_db_user
        DB_PASSWORD=your_db_password
        DB_DATABASE=finance_portal
        ```
    -   Install backend dependencies: `npm install`.
    -   Run `db_setup.txt` against your local PostgreSQL instance to create the schema and initial data.

2.  **Frontend Setup**:
    -   Navigate to the project root directory.
    -   Install dependencies: `npm install`.

3.  **Run Application**:
    -   From the project root, run the development script:
        ```bash
        npm run dev
        ```
    -   This will start the backend API on `http://localhost:3000`.
    -   **Note**: The provided scripts are optimized for a production build. For local development, you would typically use a development server like Vite or Angular CLI's `ng serve`. The current setup requires you to build the frontend (`npm run build`) and serve the `dist` folder with a local server.

## 📁 Project Structure

```
.
├── api/                    # Backend Node.js/Express application
│   ├── node_modules/
│   ├── .env                # (Created by you) Environment variables
│   ├── index.js            # API server entry point
│   └── package.json
├── dist/                   # Production build output (generated by `npm run build`)
├── src/                    # Frontend Angular source code
│   ├── app.component.html
│   ├── app.component.ts
│   ├── app.routes.ts
│   ├── components/         # All Angular components
│   └── services/           # Angular services (auth, store)
├── db_setup.txt            # SQL script for database initialization
├── install.txt             # Automated deployment script for Linux
├── index.html              # Main HTML file
├── index.tsx               # Angular application bootstrap entry point
├── package.json            # Frontend dependencies and build scripts
├── README.md               # This file
├── rollup.config.mjs       # Rollup configuration for building the frontend
└── tsconfig.json           # TypeScript configuration
```

## 📄 License

This project is licensed under the ISC License. See the `package.json` for more details.
