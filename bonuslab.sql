CREATE TABLE customers (
    customer_id SERIAL PRIMARY KEY,
    iin CHAR(12) NOT NULL UNIQUE,
    full_name VARCHAR(100) NOT NULL,
    phone VARCHAR(20),
    email VARCHAR(100) UNIQUE,
    status VARCHAR(20) CHECK (status IN ('active', 'blocked', 'frozen')) DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    daily_limit_kzt DECIMAL(15, 2) DEFAULT 100000.00
);

CREATE TABLE accounts (
    account_id SERIAL PRIMARY KEY,
    customer_id INTEGER REFERENCES customers(customer_id),
    account_number VARCHAR(20) NOT NULL UNIQUE,
    currency CHAR(3) CHECK (currency IN ('KZT', 'USD', 'EUR', 'RUB')),
    balance DECIMAL(15, 2) DEFAULT 0.00 CHECK (balance >= 0),
    is_active BOOLEAN DEFAULT TRUE,
    opened_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    closed_at TIMESTAMP
);

CREATE TABLE exchange_rates (
    rate_id SERIAL PRIMARY KEY,
    from_currency CHAR(3) NOT NULL,
    to_currency CHAR(3) NOT NULL,
    rate DECIMAL(10, 6) NOT NULL,
    valid_from TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    valid_to TIMESTAMP,
    UNIQUE (from_currency, to_currency, valid_to)
);

CREATE TABLE transactions (
    transaction_id SERIAL PRIMARY KEY,
    from_account_id INTEGER REFERENCES accounts(account_id),
    to_account_id INTEGER REFERENCES accounts(account_id),
    amount DECIMAL(15, 2) NOT NULL,
    currency CHAR(3) NOT NULL,
    exchange_rate DECIMAL(10, 6) DEFAULT 1.0,
    amount_kzt DECIMAL(15, 2),
    type VARCHAR(20) CHECK (type IN ('transfer', 'deposit', 'withdrawal', 'salary')),
    status VARCHAR(20) CHECK (status IN ('pending', 'completed', 'failed', 'reversed')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP,
    description TEXT
);

CREATE TABLE audit_log (
    log_id SERIAL PRIMARY KEY,
    table_name VARCHAR(50),
    record_id INTEGER,
    action VARCHAR(10),
    old_values JSONB,
    new_values JSONB,
    changed_by VARCHAR(50) DEFAULT 'system',
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ip_address INET
);

INSERT INTO customers (iin, full_name, phone, email, status, daily_limit_kzt) VALUES
('111111111111', 'SpongeBob SquarePants', '+77011111111', 'spongebob@bikinitottom.com', 'active', 500000),
('222222222222', 'Patrick Star', '+77022222222', 'patrick@bikinitottom.com', 'active', 200000),
('333333333333', 'Squidward Tentacles', '+77033333333', 'squidward@bikinitottom.com', 'frozen', 100000),
('444444444444', 'Eugene Krabs', '+77044444444', 'krabs@bikinitottom.com', 'active', 1000000),
('555555555555', 'Sandy Cheeks', '+77055555555', 'sandy@bikinitottom.com', 'active', 300000),
('666666666666', 'Sheldon Plankton', '+77066666666', 'plankton@chumbucket.com', 'blocked', 0),
('777777777777', 'Gary the Snail', '+77077777777', 'gary@bikinitottom.com', 'active', 150000),
('888888888888', 'Larry the Lobster', '+77088888888', 'larry@bikinitottom.com', 'active', 5000000),
('999999999999', 'Pearl Krabs', '+77099999999', 'pearl@bikinitottom.com', 'active', 250000),
('000000000000', 'Mrs. Puff', '+77000000000', 'mrspuff@bikinitottom.com', 'active', 400000);

INSERT INTO accounts (customer_id, account_number, currency, balance) VALUES
(1, 'KZ01', 'KZT', 1500000),
(1, 'KZ02', 'USD', 500),
(2, 'KZ03', 'KZT', 50000),
(2, 'KZ04', 'EUR', 100),
(3, 'KZ05', 'KZT', 200000),
(4, 'KZ06', 'KZT', 3000000),
(4, 'KZ07', 'USD', 10000),
(5, 'KZ08', 'KZT', 75000),
(6, 'KZ09', 'KZT', 10000),
(7, 'KZ10', 'RUB', 50000),
(8, 'KZCOMP', 'KZT', 50000000),
(9, 'KZ11', 'KZT', 120000),
(10, 'KZ12', 'KZT', 45000);

INSERT INTO exchange_rates (from_currency, to_currency, rate, valid_to) VALUES
('USD', 'KZT', 450.0, NULL),
('KZT', 'USD', 0.002222, NULL),
('EUR', 'KZT', 490.0, NULL),
('KZT', 'EUR', 0.002041, NULL),
('RUB', 'KZT', 5.0, NULL),
('KZT', 'RUB', 0.2, NULL),
('KZT', 'KZT', 1.0, NULL),
('USD', 'USD', 1.0, NULL);

INSERT INTO transactions (from_account_id, to_account_id, amount, currency, amount_kzt, type, status, created_at) VALUES
(1, 2, 100, 'KZT', 100, 'transfer', 'completed', NOW() - INTERVAL '2 days'),
(1, 3, 5000, 'KZT', 5000, 'transfer', 'completed', NOW() - INTERVAL '1 hour'),
(4, 1, 200, 'USD', 90000, 'transfer', 'completed', NOW() - INTERVAL '30 minutes');

CREATE OR REPLACE PROCEDURE process_transfer(
    p_from_acc_no VARCHAR,
    p_to_acc_no VARCHAR,
    p_amount DECIMAL,
    p_currency CHAR(3),
    p_description TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_from_id INT;
    v_to_id INT;
    v_from_cust_id INT;
    v_to_cust_id INT;
    v_from_cust_status VARCHAR;
    v_from_balance DECIMAL;
    v_from_currency CHAR(3);
    v_to_currency CHAR(3);
    v_daily_limit DECIMAL;
    v_spent_today DECIMAL;
    v_rate DECIMAL := 1.0;
    v_amount_converted DECIMAL;
    v_amount_kzt DECIMAL;
    v_txn_id INT;
BEGIN
    INSERT INTO transactions (amount, currency, type, status, description, created_at)
    VALUES (p_amount, p_currency, 'transfer', 'pending', p_description, NOW())
    RETURNING transaction_id INTO v_txn_id;

    SELECT a.account_id, a.customer_id, a.balance, a.currency, c.status, c.daily_limit_kzt
    INTO v_from_id, v_from_cust_id, v_from_balance, v_from_currency, v_from_cust_status, v_daily_limit
    FROM accounts a
    JOIN customers c ON a.customer_id = c.customer_id
    WHERE a.account_number = p_from_acc_no
    FOR UPDATE OF a;

    IF NOT FOUND THEN
        UPDATE transactions SET status = 'failed', description = 'Sender account not found' WHERE transaction_id = v_txn_id;
        RAISE EXCEPTION 'Sender account % not found', p_from_acc_no;
    END IF;

    SELECT account_id, customer_id, currency INTO v_to_id, v_to_cust_id, v_to_currency
    FROM accounts
    WHERE account_number = p_to_acc_no
    FOR UPDATE;

    IF NOT FOUND THEN
        UPDATE transactions SET status = 'failed', description = 'Receiver account not found' WHERE transaction_id = v_txn_id;
        RAISE EXCEPTION 'Receiver account % not found', p_to_acc_no;
    END IF;

    UPDATE transactions 
    SET from_account_id = v_from_id, to_account_id = v_to_id 
    WHERE transaction_id = v_txn_id;

    IF v_from_cust_status <> 'active' THEN
        UPDATE transactions SET status = 'failed', description = 'Sender customer is not active' WHERE transaction_id = v_txn_id;
        RAISE EXCEPTION 'Customer status is %', v_from_cust_status;
    END IF;

    IF p_currency = 'KZT' THEN
        v_amount_kzt := p_amount;
    ELSE
        SELECT rate INTO v_rate FROM exchange_rates 
        WHERE from_currency = p_currency AND to_currency = 'KZT' AND valid_to IS NULL;
        
        IF NOT FOUND THEN RAISE EXCEPTION 'Exchange rate % to KZT not found', p_currency; END IF;
        v_amount_kzt := p_amount * v_rate;
    END IF;

    IF v_from_currency = p_currency THEN
        IF v_from_balance < p_amount THEN
            UPDATE transactions SET status = 'failed', description = 'Insufficient funds' WHERE transaction_id = v_txn_id;
            RAISE EXCEPTION 'Insufficient funds';
        END IF;
    ELSE
        DECLARE v_rate_temp DECIMAL;
        BEGIN
             SELECT rate INTO v_rate_temp FROM exchange_rates WHERE from_currency = p_currency AND to_currency = v_from_currency AND valid_to IS NULL;
             IF v_from_balance < (p_amount * v_rate_temp) THEN
                UPDATE transactions SET status = 'failed', description = 'Insufficient funds (converted)' WHERE transaction_id = v_txn_id;
                RAISE EXCEPTION 'Insufficient funds';
             END IF;
        END;
    END IF;

    SELECT COALESCE(SUM(amount_kzt), 0) INTO v_spent_today
    FROM transactions
    WHERE from_account_id = v_from_id 
      AND created_at::DATE = CURRENT_DATE 
      AND status = 'completed';

    IF (v_spent_today + v_amount_kzt) > v_daily_limit THEN
        UPDATE transactions SET status = 'failed', description = 'Daily limit exceeded' WHERE transaction_id = v_txn_id;
        RAISE EXCEPTION 'Daily limit exceeded. Used: %, Attempt: %, Limit: %', v_spent_today, v_amount_kzt, v_daily_limit;
    END IF;

    UPDATE accounts 
    SET balance = balance - (
        CASE WHEN currency = p_currency THEN p_amount 
             ELSE p_amount * (SELECT rate FROM exchange_rates WHERE from_currency = p_currency AND to_currency = accounts.currency AND valid_to IS NULL)
        END
    )
    WHERE account_id = v_from_id;

    UPDATE accounts 
    SET balance = balance + (
        CASE WHEN currency = p_currency THEN p_amount 
             ELSE p_amount * (SELECT rate FROM exchange_rates WHERE from_currency = p_currency AND to_currency = accounts.currency AND valid_to IS NULL)
        END
    )
    WHERE account_id = v_to_id;

    UPDATE transactions 
    SET status = 'completed', 
        completed_at = NOW(),
        amount_kzt = v_amount_kzt,
        exchange_rate = (SELECT rate FROM exchange_rates WHERE from_currency = p_currency AND to_currency = v_to_currency AND valid_to IS NULL LIMIT 1)
    WHERE transaction_id = v_txn_id;

    INSERT INTO audit_log (table_name, record_id, action, new_values, changed_by)
    VALUES ('transactions', v_txn_id, 'INSERT', jsonb_build_object('amount', p_amount, 'from', p_from_acc_no, 'to', p_to_acc_no), 'process_transfer');

EXCEPTION WHEN OTHERS THEN
    IF v_txn_id IS NOT NULL THEN
        UPDATE transactions SET status = 'failed', description = SQLERRM WHERE transaction_id = v_txn_id;
    END IF;
    INSERT INTO audit_log (table_name, action, old_values, changed_by)
    VALUES ('transactions', 'ERROR', jsonb_build_object('error', SQLERRM, 'state', SQLSTATE), 'process_transfer');
    RAISE;
END;
$$;

CREATE OR REPLACE VIEW customer_balance_summary AS
SELECT 
    c.full_name,
    a.account_number,
    a.balance,
    a.currency,
    CASE WHEN a.currency = 'KZT' THEN a.balance
         ELSE a.balance * (SELECT rate FROM exchange_rates er WHERE er.from_currency = a.currency AND er.to_currency = 'KZT' LIMIT 1)
    END as balance_in_kzt,
    c.daily_limit_kzt,
    RANK() OVER (PARTITION BY NULL ORDER BY 
        (CASE WHEN a.currency = 'KZT' THEN a.balance
         ELSE a.balance * (SELECT rate FROM exchange_rates er WHERE er.from_currency = a.currency AND er.to_currency = 'KZT' LIMIT 1)
        END) DESC
    ) as global_rank
FROM customers c
JOIN accounts a ON c.customer_id = a.customer_id;

CREATE OR REPLACE VIEW daily_transaction_report AS
SELECT 
    created_at::DATE as txn_date,
    type,
    COUNT(*) as txn_count,
    SUM(amount_kzt) as total_volume_kzt,
    AVG(amount_kzt) as avg_amount_kzt,
    SUM(SUM(amount_kzt)) OVER (ORDER BY created_at::DATE) as running_total
FROM transactions
WHERE status = 'completed'
GROUP BY created_at::DATE, type;

CREATE OR REPLACE VIEW suspicious_activity_view WITH (security_barrier = true) AS
SELECT 
    t.transaction_id,
    c.full_name,
    t.amount_kzt,
    t.created_at,
    'Large Transaction' as reason
FROM transactions t
JOIN accounts a ON t.from_account_id = a.account_id
JOIN customers c ON a.customer_id = c.customer_id
WHERE t.amount_kzt > 5000000

UNION ALL

SELECT 
    t.transaction_id,
    c.full_name,
    t.amount_kzt,
    t.created_at,
    'High Frequency (>10/hr)' as reason
FROM transactions t
JOIN accounts a ON t.from_account_id = a.account_id
JOIN customers c ON a.customer_id = c.customer_id
WHERE (
    SELECT COUNT(*) 
    FROM transactions t2 
    WHERE t2.from_account_id = t.from_account_id 
    AND t2.created_at BETWEEN t.created_at - INTERVAL '1 hour' AND t.created_at
) > 10;

CREATE INDEX idx_transactions_accounts ON transactions(from_account_id, to_account_id);
CREATE INDEX idx_accounts_number_hash ON accounts USING HASH (account_number);
CREATE INDEX idx_audit_log_jsonb ON audit_log USING GIN (new_values);
CREATE INDEX idx_active_accounts ON accounts(account_id) WHERE is_active = TRUE;
CREATE INDEX idx_customer_email_lower ON customers(lower(email));
CREATE INDEX idx_transactions_reporting ON transactions(created_at, type, status) INCLUDE (amount_kzt);

CREATE OR REPLACE PROCEDURE process_salary_batch(
    p_company_acc_no VARCHAR,
    p_payments JSONB
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_comp_id INT;
    v_comp_balance DECIMAL;
    v_total_batch DECIMAL := 0;
    v_payment JSONB;
    v_recipient_iin VARCHAR;
    v_amount DECIMAL;
    v_desc TEXT;
    v_rec_acc_id INT;
    v_success_count INT := 0;
    v_fail_count INT := 0;
    v_failed_details JSONB := '[]'::JSONB;
    v_valid_transfers_temp JSONB := '[]'::JSONB;
    v_temp_record JSONB;
BEGIN
    PERFORM pg_advisory_lock(hashtext(p_company_acc_no));

    FOR v_payment IN SELECT * FROM jsonb_array_elements(p_payments)
    LOOP
        v_total_batch := v_total_batch + (v_payment->>'amount')::DECIMAL;
    END LOOP;

    SELECT account_id, balance INTO v_comp_id, v_comp_balance
    FROM accounts WHERE account_number = p_company_acc_no FOR UPDATE;

    IF v_comp_balance < v_total_batch THEN
        PERFORM pg_advisory_unlock(hashtext(p_company_acc_no));
        RAISE EXCEPTION 'Insufficient company funds for batch. Required: %, Available: %', v_total_batch, v_comp_balance;
    END IF;

    FOR v_payment IN SELECT * FROM jsonb_array_elements(p_payments)
    LOOP
        v_recipient_iin := v_payment->>'iin';
        v_amount := (v_payment->>'amount')::DECIMAL;
        v_desc := v_payment->>'description';
        
        BEGIN
            SELECT a.account_id INTO v_rec_acc_id
            FROM accounts a
            JOIN customers c ON a.customer_id = c.customer_id
            WHERE c.iin = v_recipient_iin AND a.currency = 'KZT' AND a.is_active = TRUE
            LIMIT 1;

            IF v_rec_acc_id IS NULL THEN
                RAISE EXCEPTION 'Recipient IIN % not found or no active KZT account', v_recipient_iin;
            END IF;

            v_valid_transfers_temp := v_valid_transfers_temp || jsonb_build_object(
                'to_account_id', v_rec_acc_id,
                'amount', v_amount,
                'description', v_desc
            );
            
        EXCEPTION WHEN OTHERS THEN
            v_fail_count := v_fail_count + 1;
            v_failed_details := v_failed_details || jsonb_build_object('iin', v_recipient_iin, 'error', SQLERRM);
        END;
    END LOOP;

    IF jsonb_array_length(v_valid_transfers_temp) > 0 THEN
        
        INSERT INTO transactions (from_account_id, to_account_id, amount, currency, amount_kzt, type, status, description, completed_at)
        SELECT 
            v_comp_id,
            (t->>'to_account_id')::INT,
            (t->>'amount')::DECIMAL,
            'KZT',
            (t->>'amount')::DECIMAL,
            'salary',
            'completed',
            (t->>'description'),
            NOW()
        FROM jsonb_array_elements(v_valid_transfers_temp) AS t;

        WITH updates AS (
            SELECT 
                (t->>'to_account_id')::INT as acc_id,
                (t->>'amount')::DECIMAL as amt
            FROM jsonb_array_elements(v_valid_transfers_temp) AS t
        )
        UPDATE accounts a
        SET balance = balance + u.amt
        FROM updates u
        WHERE a.account_id = u.acc_id;

        UPDATE accounts 
        SET balance = balance - (
            SELECT SUM((t->>'amount')::DECIMAL) 
            FROM jsonb_array_elements(v_valid_transfers_temp) AS t
        )
        WHERE account_id = v_comp_id;
        
        v_success_count := jsonb_array_length(v_valid_transfers_temp);
    END IF;

    PERFORM pg_advisory_unlock(hashtext(p_company_acc_no));

    INSERT INTO audit_log (table_name, action, new_values, changed_by)
    VALUES ('batch_salary', 'EXECUTE', jsonb_build_object('success', v_success_count, 'failed', v_fail_count, 'errors', v_failed_details), 'process_salary_batch');

    REFRESH MATERIALIZED VIEW salary_batch_report_mv;

    RAISE NOTICE 'Batch Complete. Success: %, Failed: %', v_success_count, v_fail_count;
END;
$$;

CREATE MATERIALIZED VIEW salary_batch_report_mv AS
SELECT 
    created_at::DATE as batch_date,
    COUNT(*) as total_payments,
    SUM(amount) as total_payout,
    AVG(amount) as avg_salary
FROM transactions 
WHERE type = 'salary' AND status = 'completed'
GROUP BY created_at::DATE;
