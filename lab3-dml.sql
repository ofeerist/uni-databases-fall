-- 1. Create database and tables

CREATE DATABASE advanced_lab;

CREATE TABLE employees (
    emp_id SERIAL PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    department VARCHAR(50) DEFAULT 'General',
    salary INT DEFAULT 10000,
    hire_date DATE,
    status VARCHAR(20) DEFAULT 'Active'
);

CREATE TABLE departments (
    dept_id SERIAL PRIMARY KEY,
    dept_name VARCHAR(50) UNIQUE NOT NULL,
    budget INT,
    manager_id INT
);

CREATE TABLE projects (
    project_id SERIAL PRIMARY KEY,
    project_name VARCHAR(100) NOT NULL,
    dept_id INT,
    start_date DATE,
    end_date DATE,
    budget INT
);

-- 2. INSERT with column specification

INSERT INTO employees (emp_id, first_name, last_name, department) VALUES
(0,'Peter','Griffin','IT');
INSERT INTO employees (emp_id, first_name, last_name, department) VALUES
(1,'Yana','Brik','HR');
INSERT INTO employees (emp_id, first_name, last_name, department) VALUES
(2,'Tempest','Hole','IT');
INSERT INTO employees (emp_id, first_name, last_name, department) VALUES
(3,'Mya','Mur','Senior');
INSERT INTO employees (emp_id, first_name, last_name, department) VALUES
(4,'Mia','Mao','Junior');
INSERT INTO employees (emp_id, first_name, last_name, department, hire_date, salary) VALUES
(5,'Euthan','Asia','IT', '2019-01-01', 80000);

-- 3. INSERT with DEFAULT values

INSERT INTO employees (first_name, last_name, salary, status) VALUES
('Bob', 'Martin', DEFAULT, DEFAULT);

-- 4. INSERT multiple rows in single statement

INSERT INTO departments (dept_name, budget, manager_id) VALUES
('IT', 100000, 4),
('HR', 200000, 5),
('Senior', 50000, 7),
('Junior', 10000, 8);

-- 5. INSERT with expressions

INSERT INTO employees (first_name, last_name, hire_date, salary) VALUES
('Charly', 'Stickman', CURRENT_DATE, 50000 * 1.1);

-- 6. INSERT from SELECT (subquery)

CREATE TABLE temp_employees AS
SELECT * FROM employees WHERE department = 'IT';

-- 7. UPDATE with arithmetic expressions

UPDATE employees SET salary = salary * 1.10;

-- 8. UPDATE with WHERE clause and multiple conditions

UPDATE employees SET status = 'Senior'
WHERE salary > 60000 AND hire_date < '2020-01-01';

-- 9. UPDATE using CASE expression

UPDATE employees SET department =
    CASE
        WHEN salary > 80000 THEN 'Management'
        WHEN salary BETWEEN 50000 AND 80000 THEN 'Senior'
        ELSE 'Junior'
    END;

-- 10. UPDATE with DEFAULT

UPDATE employees SET department = DEFAULT WHERE status = 'Inactive';

-- 11. UPDATE with subquery

UPDATE departments d
SET budget = (SELECT AVG(e.salary) * 1.2 FROM employees e WHERE e.department = d.dept_name);

-- 12. UPDATE multiple columns

UPDATE employees
SET salary = salary * 1.15, status = 'Promoted'
WHERE department = 'Sales';

-- 13. DELETE with simple WHERE condition

INSERT INTO employees (first_name, last_name, status) VALUES ('Oh', 'no', 'Terminated');
DELETE FROM employees WHERE status = 'Terminated';

-- 14. DELETE with complex WHERE clause

DELETE FROM employees
WHERE salary < 40000 AND hire_date > '2023-01-01' AND department IS NULL;

-- 15. DELETE with subquery

DELETE FROM departments
WHERE dept_name NOT IN (SELECT DISTINCT department FROM employees WHERE department IS NOT NULL);

-- 16. DELETE with RETURNING clause

DELETE FROM projects WHERE end_date < '2023-01-01' RETURNING *;

-- 17. INSERT with NULL values

INSERT INTO employees (first_name, last_name, salary, department) VALUES
('Null', 'Pointer', NULL, NULL);

-- 18. UPDATE NULL handling

UPDATE employees SET department = 'Unassigned' WHERE department IS NULL;

-- 19. DELETE with NULL condition

DELETE FROM employees WHERE salary IS NULL OR department IS NULL;

-- 20. INSERT with RETURNING

INSERT INTO employees (first_name, last_name, department, salary, hire_date) VALUES
('New', 'Meat', 'IT', 58000, '2025-09-29')
RETURNING emp_id, first_name || ' ' || last_name AS full_name;

-- 21. UPDATE with RETURNING

UPDATE employees
SET salary = salary + 5000
WHERE department = 'IT'
RETURNING emp_id, salary - 5000 AS old_salary, salary AS new_salary;

-- 22. DELETE with RETURNING all columns

DELETE FROM employees
WHERE hire_date < '2020-01-01'
RETURNING *;

-- 23. Conditional INSERT

INSERT INTO employees (first_name, last_name, department)
SELECT 'Unique', 'Person', 'IT'
WHERE NOT EXISTS (
    SELECT 1 FROM employees WHERE first_name = 'Unique' AND last_name = 'Person'
);

-- 24. UPDATE with JOIN logic using subqueries

UPDATE employees e
SET salary = salary *
    CASE
        WHEN d.budget > 100000 THEN 1.10
        ELSE 1.05
    END
FROM departments d
WHERE e.department = d.dept_name;

-- 25. Bulk operations

INSERT INTO employees (first_name, last_name, department) VALUES
('Bulk', 'One', 'IT'),
('Bulk', 'Two', 'IT'),
('Bulk', 'Three', 'IT'),
('Bulk', 'Four', 'IT'),
('Bulk', 'Five', 'IT');

UPDATE employees SET salary = salary * 1.10 WHERE first_name = 'Bulk';

-- 26. Data migration simulation

CREATE TABLE employee_archive (LIKE employees INCLUDING ALL);

WITH moved_rows AS (
    DELETE FROM employees
    WHERE status = 'Inactive'
    RETURNING *
)
INSERT INTO employee_archive
SELECT * FROM moved_rows;

-- 27. Complex business logic

UPDATE projects
SET end_date = end_date + INTERVAL '30 day'
WHERE
    budget > 50000 AND
    dept_id IN (
        SELECT d.dept_id
        FROM departments d
        JOIN employees e ON d.dept_name = e.department
        GROUP BY d.dept_id
        HAVING COUNT(e.emp_id) > 3
    );