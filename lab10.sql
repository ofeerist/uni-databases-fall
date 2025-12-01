CREATE TABLE accounts (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    balance DECIMAL(10, 2) DEFAULT 0.00
);

CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    shop VARCHAR(100) NOT NULL,
    product VARCHAR(100) NOT NULL,
    price DECIMAL(10, 2) NOT NULL
);

INSERT INTO accounts (name, balance) VALUES
    ('Alice', 1000.00),
    ('Bob', 500.00),
    ('Wally', 750.00);

INSERT INTO products (shop, product, price) VALUES
    ('Joe''s Shop', 'Coke', 2.50),
    ('Joe''s Shop', 'Pepsi', 3.00);

BEGIN;
UPDATE accounts SET balance = balance - 100.00 WHERE name = 'Alice';
UPDATE accounts SET balance = balance + 100.00 WHERE name = 'Bob';
COMMIT;

BEGIN;
UPDATE accounts SET balance = 500.00 WHERE name = 'Alice';
SELECT * FROM accounts WHERE name = 'Alice';
ROLLBACK;
SELECT * FROM accounts WHERE name = 'Alice';

BEGIN;
UPDATE accounts SET balance = balance - 100.00 WHERE name = 'Alice';
SAVEPOINT my_savepoint;
UPDATE accounts SET balance = balance + 100.00 WHERE name = 'Bob';
ROLLBACK TO my_savepoint;
UPDATE accounts SET balance = balance + 100.00 WHERE name = 'Wally';
COMMIT;

/*
a) Alice: 800.00, Bob: 600.00, Wally: 850.00.
b) No. The credit to Bob was rolled back using ROLLBACK TO my_savepoint, undoing that specific operation while keeping the debit from Alice.
c) SAVEPOINT allows partial rollbacks of a transaction without aborting the entire set of operations, enabling error recovery within a complex process.
*/

/*
 a) In READ COMMITTED, Terminal 1 sees the old data before Terminal 2 commits. After Terminal 2 commits, Terminal 1 sees the new data (deleted rows/inserted rows) upon re-querying within the same transaction.
b) In SERIALIZABLE, Terminal 1 continues to see the original data state as it existed at the start of the transaction, ignoring changes committed by Terminal 2.
c) READ COMMITTED allows "Non-repeatable reads" (data can change between reads). SERIALIZABLE ensures strict isolation where transactions appear to execute sequentially, preventing all concurrency phenomena.
 */

/*
a) No. REPEATABLE READ prevents seeing the new row (phantom) inserted by Terminal 2 for the duration of the transaction in PostgreSQL (though standard SQL definition allows phantoms, PostgreSQL's implementation often prevents them in this level).
b) A phantom read occurs when a transaction re-executes a query returning a set of rows that satisfy a search condition and finds the set of rows has changed due to another recently committed transaction (e.g., new rows added).
c) SERIALIZABLE (and often REPEATABLE READ in specific implementations like PostgreSQL)
 */

/*
a) Yes (if the database supports READ UNCOMMITTED fully; PostgreSQL maps this to READ COMMITTED, but in standard SQL definition, yes). It is problematic because the price was never committed; if Terminal 2 rolls back, Terminal 1 acted on invalid data.
b) A dirty read is reading data that has been written by another transaction but not yet committed.
c) It compromises data integrity by allowing decisions based on temporary, unverified, or incorrect data that may be rolled back.
 */


BEGIN;
DO $$
DECLARE
    bob_balance NUMERIC;
BEGIN
    SELECT balance INTO bob_balance FROM accounts WHERE name = 'Bob';

    IF bob_balance >= 200.00 THEN
        UPDATE accounts SET balance = balance - 200.00 WHERE name = 'Bob';
        UPDATE accounts SET balance = balance + 200.00 WHERE name = 'Wally';
    ELSE
        RAISE NOTICE 'Insufficient funds for Bob';
    END IF;
END $$;
COMMIT;

BEGIN;
INSERT INTO products (shop, product, price) VALUES ('My Shop', 'Water', 1.00);
SAVEPOINT insert_point;

-- Update price
UPDATE products SET price = 1.50 WHERE product = 'Water';
SAVEPOINT update_point;

-- Delete product
DELETE FROM products WHERE product = 'Water';

-- Rollback to first savepoint (undoes delete and update)
ROLLBACK TO insert_point;
COMMIT;

-- Initial Data: Coke 2.50, Pepsi 3.00

-- Terminal 1 (Sally)
BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;
SELECT MAX(price) FROM products;

-- Terminal 2 (Joe - updates Pepsi to 1.00)
BEGIN;
UPDATE products SET price = 1.00 WHERE product = 'Pepsi';
COMMIT;

-- Terminal 1 (Sally - continues)
SELECT MIN(price) FROM products;
COMMIT;

-- Result:
-- Sally sees MAX = 3.00 and MIN = 1.00.
-- She thinks the range is [1.00, 3.00], but at no single point in time did a product cost 1.00 AND another cost 3.00 simultaneously (if Coke is 2.50).
-- This is inconsistent analysis.

-- Fix:
-- Use SERIALIZABLE or REPEATABLE READ in Terminal 1.
-- The second query (MIN) would typically see the snapshot established at the start, returning the old MIN (2.50) ignoring Joe's update.


/*
 Atomicity: All or nothing (e.g., money leaves A and enters B; if one fails, both fail). Consistency: DB rules preserved (e.g., balance cannot be negative). Isolation: Transactions don't interfere (e.g., User A doesn't see User B's half-finished edit). Durability: Committed data survives crashes (e.g., power loss doesn't erase a saved transfer).

COMMIT saves changes permanently. ROLLBACK undoes changes since the start of the transaction.


Use SAVEPOINT when you want to undo only part of a transaction (e.g., retry a specific step) without losing the previous valid work in the transaction.

Read Uncommitted: Dirtiest, fastest, sees uncommitted data. Read Committed: Sees only committed data, data can change between reads. Repeatable Read: Guarantees same data on re-read, may have phantoms. Serializable: Strictest, acts as if sequential.

(Skipped in source numbering).

A dirty read is reading uncommitted data. Allowed by READ UNCOMMITTED.

Non-repeatable read: Reading the same row twice retrieves different data because another transaction modified it. Example: reading a balance, another user updates it, reading it again shows new balance.

Phantom read: A query returns different rows (e.g., a new row appears) on re-execution. Prevented by SERIALIZABLE (and REPEATABLE READ in some implementations).

READ COMMITTED offers higher concurrency (fewer locks/blocking) than SERIALIZABLE, which is better for performance in high-traffic systems where strict consistency anomalies are acceptable or handled by app logic.

Uncommitted changes are lost/rolled back automatically if the system crashes
 */