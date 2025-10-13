-- ARTYOM GORBACHYOV
-- 24B031727

-- Task 1.1: Basic CHECK Constraint
CREATE TABLE employees (
    employee_id INTEGER,
    first_name TEXT,
    last_name TEXT,
    age INTEGER CHECK (age >= 18 AND age <= 65),
    salary NUMERIC CHECK (salary > 0)
);

-- Task 1.2: Named CHECK Constraint
CREATE TABLE products_catalog (
    product_id INTEGER,
    product_name TEXT,
    regular_price NUMERIC,
    discount_price NUMERIC,
    CONSTRAINT valid_discount CHECK (
        regular_price > 0 AND
        discount_price > 0 AND
        discount_price < regular_price
    )
);

-- Task 1.3: Multiple Column CHECK
CREATE TABLE bookings (
    booking_id INTEGER,
    check_in_date DATE,
    check_out_date DATE CHECK (check_out_date > check_in_date),
    num_guests INTEGER CHECK (num_guests > 0 AND num_guests <= 10)
);

-- Task 1.4: Testing CHECK Constraints

INSERT INTO employees (employee_id, first_name, last_name, age, salary) VALUES
(1, 'John', 'Smith', 35, 50000),
(2, 'Jane', 'Smith', 25, 60000);

-- Fails: age < 18 and salary < 0
INSERT INTO employees (employee_id, first_name, last_name, age, salary) VALUES
(3, 'Peter', 'Jones', 17, -10000);

INSERT INTO products_catalog (product_id, product_name, regular_price, discount_price) VALUES
(101, 'Laptop', 1200, 999),
(102, 'Mouse', 25, 20);

-- Fails: regular_price and discount_price not > 0 and discount_price not < regular_price
INSERT INTO products_catalog (product_id, product_name, regular_price, discount_price) VALUES
(103, 'Keyboard', -50, -40);

INSERT INTO bookings (booking_id, check_in_date, check_out_date, num_guests) VALUES
(1, '2025-11-01', '2025-11-05', 2),
(2, '2025-12-20', '2025-12-25', 4);

-- Fails: check_out_date not > check_in_date and num_guests is not between 1 and 10
INSERT INTO bookings (booking_id, check_in_date, check_out_date, num_guests) VALUES
(4, '2026-02-05', '2026-02-01', 15);

-- Task 2.1: NOT NULL Implementation
CREATE TABLE customers (
    customer_id INTEGER NOT NULL,
    email TEXT NOT NULL,
    phone TEXT,
    registration_date DATE NOT NULL
);

-- Task 2.2: Combining Constraints
CREATE TABLE inventory (
    item_id INTEGER NOT NULL,
    item_name TEXT NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity >= 0),
    unit_price NUMERIC NOT NULL CHECK (unit_price > 0),
    last_updated TIMESTAMP NOT NULL
);

-- Task 2.3: Testing NOT NULL

INSERT INTO customers (customer_id, email, phone, registration_date) VALUES
(1, 'test@example.com', '123-456-7890', '2025-01-15'),
(2, 'another@example.com', NULL, '2025-02-20');

-- Fails: email is NOT NULL
INSERT INTO customers (customer_id, email, phone, registration_date) VALUES
(3, NULL, '987-654-3210', '2025-03-10');

INSERT INTO inventory (item_id, item_name, quantity, unit_price, last_updated) VALUES
(1, 'Hammer', 150, 12.50, NOW()),
(2, 'Screwdriver', 200, 5.75, NOW());

-- Fails: item_name is NOT NULL
INSERT INTO inventory (item_id, item_name, quantity, unit_price, last_updated) VALUES
(3, NULL, 100, 25.00, NOW());

-- Task 3.1
CREATE TABLE users (
    user_id INTEGER,
    username TEXT UNIQUE,
    email TEXT UNIQUE,
    created_at TIMESTAMP
);

-- Task 3.2: Multi-Column UNIQUE
CREATE TABLE course_enrollments (
    enrollment_id INTEGER,
    student_id INTEGER,
    course_code TEXT,
    semester TEXT,
    CONSTRAINT unique_enrollment UNIQUE (student_id, course_code, semester)
);

-- Task 3.3: Testing UNIQUE Constraints
ALTER TABLE users
ADD CONSTRAINT unique_username UNIQUE (username),
ADD CONSTRAINT unique_email UNIQUE (email);

INSERT INTO users (user_id, username, email, created_at) VALUES
(1, 'jdoe', 'jdoe@example.com', NOW()),
(2, 'asmith', 'asmith@example.com', NOW());

-- Fails: unique_username constraint violated
INSERT INTO users (user_id, username, email, created_at)
VALUES (3, 'jdoe', 'another@example.com', NOW());

INSERT INTO course_enrollments (enrollment_id, student_id, course_code, semester) VALUES
(1, 101, 'CS101', 'Fall 2025'),
(2, 101, 'MATH203', 'Fall 2025'),
(3, 102, 'CS101', 'Fall 2025');

-- Fails: unique_enrollment constraint violated
INSERT INTO course_enrollments (enrollment_id, student_id, course_code, semester)
VALUES (4, 101, 'CS101', 'Fall 2025');

-- Task 4.1: Single Column Primary Key
CREATE TABLE departments (
    dept_id INTEGER PRIMARY KEY,
    dept_name TEXT NOT NULL,
    location TEXT
);

INSERT INTO departments (dept_id, dept_name, location) VALUES
(1, 'Human Resources', 'Building A'),
(2, 'Engineering', 'Building B'),
(3, 'Sales', 'Building C');
-- Fails: duplicate key value violates primary key constraint
INSERT INTO departments (dept_id, dept_name, location) VALUES (1, 'Marketing', 'Building D');
-- Fails: null value violates primary key constraint
INSERT INTO departments (dept_id, dept_name, location) VALUES (NULL, 'Marketing', 'Building D');

-- Task 4.2: Composite Primary Key
CREATE TABLE student_courses (
    student_id INTEGER,
    course_id INTEGER,
    enrollment_date DATE,
    grade TEXT,
    PRIMARY KEY (student_id, course_id)
);

-- Task 4.3: Comparison Exercise
/*
    PRIMARY KEY vs. UNIQUE
    ----------------------
    -- PK: No NULLs. Table has only ONE. It's the main row identifier.
    -- UNIQUE: Allows one NULL. Table can have MANY. Enforces column uniqueness.

    Single vs. Composite PK
    -----------------------
    -- Single-Column PK: Use when one column is a natural key (e.g., student_id).
    -- Composite PK: Use when multiple columns combined are needed to be unique (e.g., student_id + course_id).

    Why Only One PRIMARY KEY?
    -------------------------
    -- PRIMARY KEY has to provide a single, clear, and unambiguous way to identify a row.
    -- Multiple UNIQUE constraints are allowed because they serve as secondary rules, not as the main identifier.
*/

--------------------------------------------------------------------------------
-- Part 5: FOREIGN KEY Constraints
--------------------------------------------------------------------------------

-- Task 5.1: Basic Foreign Key
CREATE TABLE employees_dept (
    emp_id INTEGER PRIMARY KEY,
    emp_name TEXT NOT NULL,
    dept_id INTEGER REFERENCES departments(dept_id),
    hire_date DATE
);

INSERT INTO employees_dept (emp_id, emp_name, dept_id, hire_date) VALUES
(101, 'Alice', 2, '2023-05-10'),
(102, 'Bob', 2, '2024-01-20'),
(103, 'Charlie', 3, '2022-11-15');

-- Fails: dept_id=99 is not present in departments table
INSERT INTO employees_dept (emp_id, emp_name, dept_id, hire_date)
VALUES (104, 'David', 99, '2025-01-01');

-- Task 5.2: Multiple Foreign Keys
CREATE TABLE authors (
    author_id INTEGER PRIMARY KEY,
    author_name TEXT NOT NULL,
    country TEXT
);

CREATE TABLE publishers (
    publisher_id INTEGER PRIMARY KEY,
    publisher_name TEXT NOT NULL,
    city TEXT
);

CREATE TABLE books (
    book_id INTEGER PRIMARY KEY,
    title TEXT NOT NULL,
    author_id INTEGER REFERENCES authors(author_id),
    publisher_id INTEGER REFERENCES publishers(publisher_id),
    publication_year INTEGER,
    isbn TEXT UNIQUE
);

INSERT INTO authors (author_id, author_name, country) VALUES (1, 'George Orwell', 'UK'), (2, 'J.K. Rowling', 'UK');
INSERT INTO publishers (publisher_id, publisher_name, city) VALUES (101, 'Penguin Books', 'London'), (102, 'Bloomsbury', 'London');
INSERT INTO books (book_id, title, author_id, publisher_id, publication_year, isbn) VALUES
(1001, '1984', 1, 101, 1949, '978-0451524935'),
(1002, 'Harry Potter and the Philosopher''s Stone', 2, 102, 1997, '978-0747532699');

-- Task 5.3: ON DELETE Options
CREATE TABLE categories (
    category_id INTEGER PRIMARY KEY,
    category_name TEXT NOT NULL
);

CREATE TABLE products_fk (
    product_id INTEGER PRIMARY KEY,
    product_name TEXT NOT NULL,
    category_id INTEGER REFERENCES categories(category_id) ON DELETE RESTRICT
);

CREATE TABLE orders (
    order_id INTEGER PRIMARY KEY,
    order_date DATE NOT NULL
);

CREATE TABLE order_items (
    item_id INTEGER PRIMARY KEY,
    order_id INTEGER REFERENCES orders(order_id) ON DELETE CASCADE,
    product_id INTEGER REFERENCES products_fk(product_id),
    quantity INTEGER CHECK (quantity > 0)
);

INSERT INTO categories (category_id, category_name) VALUES (1, 'Electronics'), (2, 'Books');
INSERT INTO products_fk (product_id, product_name, category_id) VALUES (1, 'Laptop', 1), (2, 'Programming Book', 2);
INSERT INTO orders (order_id, order_date) VALUES (101, '2025-10-01'), (102, '2025-10-02');
INSERT INTO order_items (item_id, order_id, product_id, quantity) VALUES (1, 101, 1, 1), (2, 101, 2, 2), (3, 102, 1, 1);

-- 1. Try to delete a category that has products (should fail with RESTRICT)
DELETE FROM categories WHERE category_id = 1; -- Fails: violates foreign key constraint on products_fk table.

-- 2. Delete an order and observe that order_items are automatically deleted (CASCADE)
SELECT * FROM order_items WHERE order_id = 101; -- Returns 2 rows before deletion

-- Task 6.1: E-commerce Database Design
CREATE TABLE customers_ecommerce (
    customer_id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    phone TEXT,
    registration_date DATE NOT NULL
);

CREATE TABLE products_ecommerce (
    product_id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    price NUMERIC NOT NULL CHECK (price >= 0),
    stock_quantity INTEGER NOT NULL CHECK (stock_quantity >= 0)
);

CREATE TABLE orders_ecommerce (
    order_id SERIAL PRIMARY KEY,
    customer_id INTEGER REFERENCES customers_ecommerce(customer_id) ON DELETE SET NULL,
    order_date TIMESTAMP NOT NULL DEFAULT NOW(),
    total_amount NUMERIC NOT NULL CHECK (total_amount >= 0),
    status TEXT NOT NULL CHECK (status IN ('pending', 'processing', 'shipped', 'delivered', 'cancelled'))
);

CREATE TABLE order_details (
    order_detail_id SERIAL PRIMARY KEY,
    order_id INTEGER REFERENCES orders_ecommerce(order_id) ON DELETE CASCADE,
    product_id INTEGER REFERENCES products_ecommerce(product_id) ON DELETE RESTRICT,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC NOT NULL CHECK (unit_price >= 0)
);

-- Insert sample records
INSERT INTO customers_ecommerce (name, email, phone) VALUES
('John Smith', 'john.smith@email.com', '555-0101'),
('Jane Doe', 'jane.doe@email.com', '555-0102'),
('Peter Jones', 'peter.jones@email.com', '555-0103'),
('Emily White', 'emily.white@email.com', NULL),
('Michael Brown', 'michael.brown@email.com', '555-0105');

INSERT INTO products_ecommerce (name, description, price, stock_quantity) VALUES
('Laptop Pro', 'A powerful laptop', 1499.99, 50),
('Wireless Mouse', 'Ergonomic wireless mouse', 49.99, 200),
('Mechanical Keyboard', 'RGB mechanical keyboard', 129.99, 100),
('4K Monitor', '27-inch 4K UHD monitor', 399.99, 75),
('USB-C Hub', '7-in-1 USB-C Hub', 39.99, 150);

INSERT INTO orders_ecommerce (customer_id, total_amount, status) VALUES
(1, 1549.98, 'shipped'),
(2, 39.99, 'delivered'),
(1, 129.99, 'processing'),
(3, 839.97, 'pending'),
(4, 49.99, 'cancelled');

INSERT INTO order_details (order_id, product_id, quantity, unit_price) VALUES
(1, 1, 1, 1499.99),
(1, 2, 1, 49.99),
(2, 5, 1, 39.99),
(3, 3, 1, 129.99),
(4, 4, 2, 399.99),
(4, 5, 1, 39.99);


-- Test UNIQUE email constraint
INSERT INTO customers_ecommerce (name, email, phone) VALUES ('Another John', 'john.smith@email.com', '555-0199');
-- Test CHECK price constraint
INSERT INTO products_ecommerce (name, price, stock_quantity) VALUES ('Free Item', -10.00, 5);
-- Test CHECK status constraint
INSERT INTO orders_ecommerce (customer_id, total_amount, status) VALUES (2, 99.00, 'waiting');
-- Test FOREIGN KEY constraint
INSERT INTO orders_ecommerce (customer_id, total_amount, status) VALUES (999, 100.00, 'pending');
