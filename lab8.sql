-- ARTYOM GORBACHYOV
-- 24B031727

-- Exercise 2.1: Create a Simple B-tree Index
CREATE INDEX emp_salary_idx ON employees(salary);

-- Verify the index was created:
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'employees';

-- Question: How many indexes exist on the employees table? (Hint: PRIMARY KEY creates an automatic index)
/*
Answer:
Two.
1. 'employees_pkey'id'
2. 'emp_salary_idx'
*/


-- Exercise 2.2: Create an Index on a Foreign Key
CREATE INDEX emp_dept_idx ON employees(dept_id);

SELECT * FROM employees WHERE dept_id = 101;

-- Question: Why is it beneficial to index foreign key columns?
/*
Answer:
It is highly beneficial because foreign key columns are very frequently used in
JOIN conditions.
*/

-- Exercise 2.3: View Index Information
SELECT
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;

-- Question: List all the indexes you see. Which ones were created automatically?
/*
Answer:
- departments: departments_pkey
- employees: employees_pkey
- employees: emp_dept_idx
- employees: emp_salary_idx
- projects: projects_pkey

The automatically created indexes are the ones ending in '_pkey':
'departments_pkey', 'employees_pkey', and 'projects_pkey'.
*/

-- Exercise 3.1: Create a Multicolumn Index
CREATE INDEX emp_dept_salary_idx ON employees(dept_id, salary);

SELECT emp_name, salary
FROM employees
WHERE dept_id = 101 AND salary > 52000;

-- Question: Would this index be useful for a query that only filters by salary (without dept_id)? Why or why not?
/*
Answer:
No, it would not be very useful. A multicolumn index on (dept_id, salary) is
sorted like a phone book: first by 'dept_id', and *then* by 'salary'.
If you only query by 'salary', the database can't use the primary sort order
of the index and will likely not use it efficiently (it might have to scan
the whole index or just do a full table scan).
*/


-- Exercise 3.2: Understanding Column Order
CREATE INDEX emp_salary_dept_idx ON employees(salary, dept_id);

-- Compare with queries:
-- Query 1: Filters by dept_id first (can use emp_dept_salary_idx)
SELECT * FROM employees WHERE dept_id = 102 AND salary > 50000;

-- Query 2: Filters by salary first (can use emp_salary_dept_idx)
SELECT * FROM employees WHERE salary > 50000 AND dept_id = 102;

-- Question: Does the order of columns in a multicolumn index matter? Explain.
/*
Answer:
Yes, the order of columns matters significantly. The database can use the
index most efficiently if the query's WHERE clause filters on the *leading*
(leftmost) columns of the index.
- An index on (dept_id, salary) is best for queries filtering by 'dept_id'.
- An index on (salary, dept_id) is best for queries filtering by 'salary'.
- Both queries above can use an index, but they would preferentially use the
  one that matches their leading filter condition.
*/


-- Exercise 4.1: Create a Unique Index
ALTER TABLE employees ADD COLUMN email VARCHAR(100);

UPDATE employees SET email = 'john.smith@company.com' WHERE emp_id = 1;
UPDATE employees SET email = 'jane.doe@company.com' WHERE emp_id = 2;
UPDATE employees SET email = 'mike.johnson@company.com' WHERE emp_id = 3;
UPDATE employees SET email = 'sarah.williams@company.com' WHERE emp_id = 4;
UPDATE employees SET email = 'tom.brown@company.com' WHERE emp_id = 5;

-- Now create a unique index on the email column:
CREATE UNIQUE INDEX emp_email_unique_idx ON employees(email);

-- Test the uniqueness constraint:
INSERT INTO employees (emp_id, emp_name, dept_id, salary, email)
VALUES (6, 'New Employee', 101, 55000, 'john.smith@company.com');

-- Question: What error message did you receive?
/*
Answer:
"ERROR: duplicate key value violates unique constraint 'emp_email_unique_idx'
 DETAIL: Key (email)=(john.smith@company.com) already exists."
*/


-- Exercise 4.2: Unique Index vs UNIQUE Constraint
-- Add a phone column with UNIQUE constraint
ALTER TABLE employees ADD COLUMN phone VARCHAR(20) UNIQUE;

-- View the indexes:
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'employees' AND indexname LIKE '%phone%';

-- Question: Did PostgreSQL automatically create an index? What type of index?
/*
Answer:
Yes.
The query will show a new index (e.g., 'employees_phone_key') and its
definition (in the 'indexdef' column) will show it is a B-tree index.
*/


-- Exercise 5.1: Create an Index for Sorting
CREATE INDEX emp_salary_desc_idx ON employees(salary DESC);

-- Test with an ORDER BY query:
SELECT emp_name, salary
FROM employees
ORDER BY salary DESC;

-- Question: How does this index help with ORDER BY queries?
/*
Answer:
The index stores the 'salary' values in pre-sorted descending order.
When the query asks to 'ORDER BY salary DESC', the database can read the
values directly from the index in the correct order. This avoids a separate,
time-consuming "sort" operation on the results.
*/


-- Exercise 5.2: Index with NULL Handling
CREATE INDEX proj_budget_nulls_first_idx ON projects(budget NULLS FIRST);

-- Test the index:
SELECT project_name, budget
FROM projects
ORDER BY budget NULLS FIRST;


-- Exercise 6.1: Create a Function-Based Index
CREATE INDEX emp_name_lower_idx ON employees (LOWER(emp_name));

-- Test the expression index:
SELECT * FROM employees WHERE LOWER(emp_name) = 'john smith';

-- Question: Without this index, how would PostgreSQL search for names case-insensitively?
/*
Answer:
Without this index, PostgreSQL would have to perform a "Sequential Scan"
(Seq Scan). This means it would read *every single row* in the 'employees'
table, apply the LOWER() function to the 'emp_name' column for each row,
and then compare the result to 'john smith'.
*/


-- Exercise 6.2: Index on Calculated Values
ALTER TABLE employees ADD COLUMN hire_date DATE;

UPDATE employees SET hire_date = '2020-01-15' WHERE emp_id = 1;
UPDATE employees SET hire_date = '2019-06-20' WHERE emp_id = 2;
UPDATE employees SET hire_date = '2021-03-10' WHERE emp_id = 3;
UPDATE employees SET hire_date = '2020-11-05' WHERE emp_id = 4;
UPDATE employees SET hire_date = '2018-08-25' WHERE emp_id = 5;

-- Create index on the year extracted from hire_date
CREATE INDEX emp_hire_year_idx ON employees (EXTRACT(YEAR FROM hire_date));

-- Test the index:
SELECT emp_name, hire_date
FROM employees
WHERE EXTRACT(YEAR FROM hire_date) = 2020;

-- Exercise 7.1: Rename an Index
ALTER INDEX emp_salary_idx RENAME TO employees_salary_index;

-- Verify the rename:
SELECT indexname FROM pg_indexes WHERE tablename = 'employees';

-- Exercise 7.2: Drop Unused Indexes
DROP INDEX emp_salary_dept_idx;

-- Question: Why might you want to drop an index?
/*
Answer:
You would drop an index if it is:
1. Unused: It's not helping any queries (or very few).
2. Redundant: Another index (e.g., a multicolumn index) already covers its purpose.
3. Hurting Write Performance: Indexes speed up reads but *slow down* writes
   (INSERT, UPDATE, DELETE) because the index itself must be updated. If a
   table has many writes and the index is rarely used, it's better to drop it.
4. Consuming too much disk space.
*/


-- Exercise 7.3: Reindex
-- Note: REINDEX is often used when an index becomes "bloated" after many
-- updates and deletes.
REINDEX INDEX employees_salary_index;

-- Exercise 8.1: Optimize a Slow Query
-- Consider this query:
/*
SELECT e.emp_name, e.salary, d.dept_name
FROM employees e
JOIN departments d ON e.dept_id = d.dept_id
WHERE e.salary > 50000
ORDER BY e.salary DESC;
*/

-- Create indexes to optimize this query:
-- Index for the WHERE clause (Partial Index)
CREATE INDEX emp_salary_filter_idx ON employees(salary) WHERE salary > 50000;

-- Index for the JOIN (already created: emp_dept_idx)
-- Index for ORDER BY (already created: emp_salary_desc_idx)


-- Exercise 8.2: Partial Index
CREATE INDEX proj_high_budget_idx ON projects(budget)
WHERE budget > 80000;

-- Test the partial index:
SELECT project_name, budget
FROM projects
WHERE budget > 80000;

-- Question: What's the advantage of a partial index compared to a regular index?
/*
Answer:
A partial index is much smaller than a regular index because it *only*
stores entries for the rows that match the WHERE clause.
Advantages:
1. Less Disk Space: It consumes far less storage.
2. Faster Writes: It has less overhead on INSERT/UPDATE/DELETE operations
   (it only needs to be updated if the changed row matches the WHERE clause).
3. Faster Reads: A smaller index can be scanned more quickly.
*/


-- Exercise 8.3: Analyze Index Usage
-- Use EXPLAIN to see if indexes are being used:
EXPLAIN SELECT * FROM employees WHERE salary > 52000;

-- Question: Does the output show an "Index Scan" or a "Seq Scan" (Sequential Scan)? What does this tell you?
/*
Answer:
"Seq Scan", it tells that salary index is redundant
*/

-- Exercise 9.1: Create a Hash Index
CREATE INDEX dept_name_hash_idx ON departments USING HASH (dept_name);

-- Test the hash index:
SELECT * FROM departments WHERE dept_name = 'IT';

-- Question: When should you use a HASH index instead of a B-tree index?
/*
Answer:
You should use a HASH index *only* for simple equality comparisons
(e.g., WHERE column = 'some_value'). They are not suitable for range
queries (e.g., >, <, LIKE) or sorting (ORDER BY).
B-tree (the default) is the general-purpose index that works for
equality, range queries, and sorting.
*/


-- Exercise 9.2: Compare Index Types
-- B-tree index
CREATE INDEX proj_name_btree_idx ON projects(project_name);

-- Hash index
CREATE INDEX proj_name_hash_idx ON projects USING HASH (project_name);

-- Test with different queries:
-- Equality search (both can be used)
EXPLAIN SELECT * FROM projects WHERE project_name = 'Website Redesign';

-- Range search (only B-tree can be used)
EXPLAIN SELECT * FROM projects WHERE project_name > 'Database';

-- Exercise 10.1: Review All Indexes
SELECT
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexname::regclass)) as index_size
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;

-- Question: Which index is the largest? Why?
/*
Answer:
dept_name_hash_idx. Because it is a hash index.
*/


-- Exercise 10.2: Drop Unnecessary Indexes
-- Drop the duplicate hash index on project name
DROP INDEX IF EXISTS proj_name_hash_idx;


-- Exercise 10.3: Document Your Indexes
CREATE VIEW index_documentation AS
SELECT
    tablename,
    indexname,
    indexdef,
    'Improves salary-based queries' as purpose
FROM pg_indexes
WHERE schemaname = 'public'
AND indexname LIKE '%salary%';

SELECT * FROM index_documentation;


/*
-----------------------------------------------------------------
-- Summary Questions
-----------------------------------------------------------------

1. What is the default index type in PostgreSQL?
   Answer: B-tree.

2. Name three scenarios where you should create an index:
   Answer:
   - On columns used frequently in WHERE clauses.
   - On foreign key columns (or any columns used in JOIN conditions).
   - On columns used frequently in ORDER BY clauses.

3. Name two scenarios where you should NOT create an index:
   Answer:
   - On columns that are not queried frequently (or at all).
   - On tables with very high write (INSERT/UPDATE/DELETE) volume and
     low read volume, as the index overhead will slow down writes.
   - On columns with very low cardinality (e.g., a "gender" column
     with only 'M', 'F', 'Other'). A full table scan is often faster.

4. What happens to indexes when you INSERT, UPDATE, or DELETE data?
   Answer:
   The indexes must also be updated to reflect the data changes. This
   adds overhead and *slows down* these write operations.

5. How can you check if a query is using an index?
   Answer:
   You can use the `EXPLAIN` command before your query
   (e.g., `EXPLAIN SELECT ...`). The resulting query plan will show if
   an "Index Scan" is being used instead of a "Seq Scan" (Sequential Scan).

*/

-- 1. Create an index that would optimize finding all employees hired in a specific month
CREATE INDEX emp_hire_month_idx ON employees (EXTRACT(MONTH FROM hire_date));
EXPLAIN SELECT * FROM employees WHERE EXTRACT(MONTH FROM hire_date) = 6;


-- 2. Create a composite unique index on dept_id and email in employees table
-- ALTER TABLE employees DROP CONSTRAINT employees_phone_key;
CREATE UNIQUE INDEX emp_dept_phone_unique_idx ON employees (dept_id, phone);


-- 3. Use EXPLAIN ANALYZE to compare query performance with and without indexes
CREATE INDEX emp_name_lower_idx ON employees (LOWER(emp_name));
EXPLAIN ANALYZE SELECT * FROM employees WHERE LOWER(emp_name) = 'john smith';
-- 0.240 ms

DROP INDEX emp_name_lower_idx;
EXPLAIN ANALYZE SELECT * FROM employees WHERE LOWER(emp_name) = 'john smith';
-- 0.175

-- No benefits, seq scan on both

-- 4. Create a covering index that includes all columns needed for a specific query
SELECT emp_name, salary FROM employees WHERE dept_id = 101;
CREATE INDEX emp_dept_covering_idx ON employees (dept_id) INCLUDE (emp_name, salary);
EXPLAIN SELECT emp_name, salary FROM employees WHERE dept_id = 101;


