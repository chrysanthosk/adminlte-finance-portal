require('dotenv').config();
const express = require('express');
const cors = require('cors');
const bcrypt = require('bcryptjs');
const { Pool } = require('pg');

const app = express();
const port = 3000;

// --- HELPERS to convert snake_case from DB to camelCase for the frontend ---
const toCamel = (s) => s.replace(/(_\w)/g, (m) => m[1].toUpperCase());

const convertKeysToCamel = (o) => {
  if (Array.isArray(o)) {
    return o.map(v => convertKeysToCamel(v));
  } else if (o !== null && typeof o === 'object' && o.constructor === Object) {
    const n = {};
    Object.keys(o).forEach((k) => {
      n[toCamel(k)] = convertKeysToCamel(o[k]);
    });
    return n;
  }
  return o;
};


// --- DATABASE CONNECTION ---
const pool = new Pool({
  user: process.env.DB_USER,
  // Force TCP/IP connection by using '127.0.0.1' for 'localhost' to ensure password auth is used,
  // bypassing potential 'peer' authentication issues that can cause connection failures.
  host: process.env.DB_HOST === 'localhost' ? '127.0.0.1' : process.env.DB_HOST,
  database: process.env.DB_DATABASE,
  password: process.env.DB_PASSWORD,
  port: process.env.DB_PORT,
});

// --- MIDDLEWARE ---
app.use(cors());
app.use(express.json({ limit: '5mb' })); // Allow larger payloads for attachments


// --- API ENDPOINTS ---

// [POST] /api/login
app.post('/api/login', async (req, res) => {  
  const { username, password } = req.body;
  if (!username || !password) {
    return res.status(400).json({ success: false, message: 'Username and password required' });
  }

  try {
    const result = await pool.query('SELECT * FROM users WHERE username = $1', [username]);
    if (result.rows.length === 0) {
      return res.json({ success: false, message: 'Invalid credentials' });
    }

    const user = result.rows[0];
    const passwordMatch = await bcrypt.compare(password, user.password);

    if (passwordMatch) {
      delete user.password; // Never send password hash to client
      res.json({ success: true, user: convertKeysToCamel(user) });
    } else {
      res.json({ success: false, message: 'Invalid credentials' });
    }
  } catch (err) {
    console.error('Login error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});


// [GET] /api/loadAll
app.get('/api/loadAll', async (req, res) => {
    try {
        const [
            settings, smtpSettings, users, incomeMethods, 
            expenseTypes, expenseCategories, accounts, 
            incomeEntries, expenseEntries, snapshots
        ] = await Promise.all([
            pool.query('SELECT * FROM app_settings LIMIT 1').then(r => r.rows[0] || {}),
            pool.query('SELECT * FROM smtp_settings LIMIT 1').then(r => r.rows[0] || {}),
            pool.query('SELECT username, name, surname, email, role, two_factor_enabled, two_factor_secret FROM users ORDER BY username').then(r => r.rows),
            pool.query('SELECT * FROM income_methods ORDER BY name').then(r => r.rows),
            pool.query('SELECT * FROM expense_types ORDER BY name').then(r => r.rows),
            pool.query('SELECT * FROM expense_categories ORDER BY name').then(r => r.rows),
            pool.query('SELECT * FROM accounts ORDER BY name').then(r => r.rows),
            pool.query('SELECT * FROM income_entries ORDER BY date DESC').then(r => r.rows),
            pool.query('SELECT * FROM expense_entries ORDER BY date DESC').then(r => r.rows),
            pool.query('SELECT * FROM account_snapshots ORDER BY month DESC').then(r => r.rows),
        ]);

        res.json(convertKeysToCamel({
            settings, smtpSettings, users, incomeMethods, expenseTypes,
            expenseCategories, accounts, incomeEntries, expenseEntries, snapshots
        }));
    } catch (err) {
        console.error('loadAll error:', err);
        res.status(500).json({ message: 'Failed to load data' });
    }
});

// All other actions are POST for simplicity
app.post('/api/:action', async (req, res) => {
    const { action } = req.params;
    const body = req.body;

    try {
        switch (action) {
            case 'updateSettings': {
                // Assuming only one row exists in app_settings
                await pool.query('UPDATE app_settings SET company_name = $1', [body.companyName]);
                break;
            }
            case 'updateSmtp': {
                // This query safely updates the single SMTP settings row.
                // It correctly quotes the "user" column and prevents an empty password from being saved.
                const query = `
                    WITH old AS (SELECT password FROM smtp_settings LIMIT 1)
                    UPDATE smtp_settings SET
                        host = $1,
                        port = $2,
                        "user" = $3,
                        password = COALESCE(NULLIF($4, ''), (SELECT password FROM old)),
                        secure = $5,
                        from_name = $6,
                        from_email = $7
                `;
                await pool.query(query, [body.host, body.port, body.user, body.password, body.secure, body.fromName, body.fromEmail]);
                break;
            }
            case 'addUser': {
                const { username, password, email, name, surname, role } = body;
                if (!password) {
                    return res.status(400).json({ success: false, message: 'Password is required for a new user.' });
                }
                const hashedPassword = await bcrypt.hash(password, 10);
                try {
                    const query = `
                        INSERT INTO users (username, password, email, name, surname, role) 
                        VALUES ($1, $2, $3, $4, $5, $6)
                        RETURNING username, name, surname, email, role, two_factor_enabled, two_factor_secret;
                    `;
                    const result = await pool.query(query, [username, hashedPassword, email, name, surname, role]);
                    return res.json(convertKeysToCamel(result.rows[0]));
                } catch (err) {
                    if (err.code === '23505') { // unique_violation
                        return res.status(409).json({ success: false, message: 'Username or email already exists.' });
                    }
                    // Re-throw for the main error handler
                    throw err;
                }
            }
            case 'updateUser': {
                 // Password update is handled separately if provided
                if(body.password && body.password.length > 0) {
                     const hashedPassword = await bcrypt.hash(body.password, 10);
                     await pool.query('UPDATE users SET password = $1 WHERE username = $2', [hashedPassword, body.username]);
                }
                const query = `
                    UPDATE users SET name=$1, surname=$2, email=$3, role=$4, two_factor_enabled=$5, two_factor_secret=$6
                    WHERE username = $7
                `;
                await pool.query(query, [body.name, body.surname, body.email, body.role, body.twoFactorEnabled, body.twoFactorSecret, body.username]);
                break;
            }
             case 'removeUser':
                await pool.query('DELETE FROM users WHERE username = $1', [body.username]);
                break;
            
            // --- Income/Expense Config ---
            case 'addIncomeMethod': {
                const result = await pool.query('INSERT INTO income_methods (name) VALUES ($1) RETURNING *', [body.name]);
                return res.json(convertKeysToCamel(result.rows[0]));
            }
            case 'updateIncomeMethod':
                await pool.query('UPDATE income_methods SET name = $1 WHERE id = $2', [body.name, body.id]);
                break;
            case 'removeIncomeMethod':
                 await pool.query('DELETE FROM income_methods WHERE id = $1', [body.id]);
                 break;
            case 'addCategory': {
                const result = await pool.query('INSERT INTO expense_categories (name) VALUES ($1) RETURNING *', [body.name]);
                return res.json(convertKeysToCamel(result.rows[0]));
            }
            case 'updateCategory':
                 await pool.query('UPDATE expense_categories SET name = $1 WHERE id = $2', [body.name, body.id]);
                 break;
            case 'removeCategory':
                 await pool.query('DELETE FROM expense_categories WHERE id = $1', [body.id]);
                 break;
            case 'addType': {
                const result = await pool.query('INSERT INTO expense_types (name) VALUES ($1) RETURNING *', [body.name]);
                return res.json(convertKeysToCamel(result.rows[0]));
            }
            case 'updateType':
                await pool.query('UPDATE expense_types SET name = $1 WHERE id = $2', [body.name, body.id]);
                break;
            case 'removeType':
                 await pool.query('DELETE FROM expense_types WHERE id = $1', [body.id]);
                 break;

            // --- Transactions ---
            case 'addIncome': {
                const result = await pool.query(
                    'INSERT INTO income_entries (date, lines, notes, created_by) VALUES ($1, $2, $3, $4) RETURNING *',
                    [body.date, JSON.stringify(body.lines), body.notes, body.createdBy]
                );
                return res.json(convertKeysToCamel(result.rows[0]));
            }
            case 'updateIncome':
                 await pool.query(
                    'UPDATE income_entries SET date=$1, lines=$2, notes=$3 WHERE id=$4',
                    [body.date, JSON.stringify(body.lines), body.notes, body.id]
                 );
                 break;
            case 'addExpense': {
                const result = await pool.query(
                    'INSERT INTO expense_entries (date, vendor, amount, payment_type_id, category_id, cheque_no, reason, attachment, created_by) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING *',
                    [body.date, body.vendor, body.amount, body.paymentTypeId, body.categoryId, body.chequeNo, body.reason, body.attachment, body.createdBy]
                );
                return res.json(convertKeysToCamel(result.rows[0]));
            }
            case 'updateExpense':
                await pool.query(
                    'UPDATE expense_entries SET date=$1, vendor=$2, amount=$3, payment_type_id=$4, category_id=$5, cheque_no=$6, reason=$7, attachment=$8 WHERE id=$9',
                    [body.date, body.vendor, body.amount, body.paymentTypeId, body.categoryId, body.chequeNo, body.reason, body.attachment, body.id]
                );
                break;
            case 'removeExpense':
                await pool.query('DELETE FROM expense_entries WHERE id = $1', [body.id]);
                break;
            
            // --- Accounts & Snapshots ---
            case 'addAccount': {
                 const result = await pool.query(
                    'INSERT INTO accounts (name, type, currency, active) VALUES ($1, $2, $3, $4) RETURNING *',
                    [body.name, body.type, body.currency, body.active]
                 );
                 return res.json(convertKeysToCamel(result.rows[0]));
            }
            case 'updateAccount':
                 await pool.query(
                    'UPDATE accounts SET name=$1, type=$2, currency=$3, active=$4 WHERE id=$5',
                    [body.name, body.type, body.currency, body.active, body.id]
                 );
                 break;
            case 'addSnapshot': {
                 const result = await pool.query(
                    'INSERT INTO account_snapshots (month, balances, is_locked) VALUES ($1, $2, $3) ON CONFLICT (month) DO UPDATE SET balances=$2, is_locked=$3 RETURNING *',
                    [body.month, JSON.stringify(body.balances), body.isLocked]
                 );
                 return res.json(convertKeysToCamel(result.rows[0]));
            }

            default:
                return res.status(404).json({ message: 'Action not found' });
        }
        res.json({ success: true });
    } catch (err) {
        console.error(`Error processing action "${action}":`, err);
        res.status(500).json({ success: false, message: 'Server error' });
    }
});


app.listen(port, () => {
  console.log(`Finance Portal API listening on http://localhost:${port}`);
});