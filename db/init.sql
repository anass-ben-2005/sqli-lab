-- LibraryOS SQL Injection Lab Database Schema
-- This runs automatically on first container start

CREATE DATABASE IF NOT EXISTS librarydb CHARACTER SET utf8mb4;
USE librarydb;

-- Members table (contains authentication credentials)
CREATE TABLE members (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    username    VARCHAR(64)  NOT NULL UNIQUE,
    password    VARCHAR(255) NOT NULL,  -- plain-text: INTENTIONAL for demo
    email       VARCHAR(128) NOT NULL,
    role        ENUM('user','admin','super_admin') NOT NULL DEFAULT 'user',
    card_number VARCHAR(19)  DEFAULT NULL,  -- fake credit card number
    card_expiry VARCHAR(5)   DEFAULT NULL,  -- MM/YY
    card_cvv    VARCHAR(4)   DEFAULT NULL,
    card_type   VARCHAR(20)  DEFAULT NULL,  -- Visa, Mastercard, etc.
    created_at  DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Books catalogue
CREATE TABLE books (
    id     INT AUTO_INCREMENT PRIMARY KEY,
    title  VARCHAR(255) NOT NULL,
    author VARCHAR(128) NOT NULL,
    genre  VARCHAR(64),
    year   SMALLINT,
    copies TINYINT DEFAULT 3
);

-- Loans tracking
CREATE TABLE loans (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    member_id   INT NOT NULL,
    book_id     INT NOT NULL,
    loaned_at   DATETIME DEFAULT CURRENT_TIMESTAMP,
    due_at      DATETIME,
    returned_at DATETIME,
    FOREIGN KEY (member_id) REFERENCES members(id),
    FOREIGN KEY (book_id)   REFERENCES books(id)
);

-- Seed users with three privilege levels
INSERT INTO members (username, password, email, role, card_number, card_expiry, card_cvv, card_type) VALUES
    ('alice',       'alice123',      'alice@library.local',     'user',        '4539 1488 0343 6467', '08/28', '953', 'Visa'),
    ('bob',         'bobpass',       'bob@library.local',       'user',        NULL, NULL, NULL, NULL),
    ('charlie',     'charlie77',     'charlie@library.local',   'user',        '5100 2341 8765 9012', '12/25', '123', 'Mastercard'),
    ('diana',       'wonderwoman',   'diana@library.local',     'user',        '3782 112233 44556',   '05/30', '881', 'Amex'),
    ('evan',        'evan_password', 'evan@library.local',      'user',        '4539 0011 2233 4455', '01/26', '002', 'Visa'),
    ('fiona',       'shrekfan',      'fiona@library.local',     'user',        '6011 1234 5678 9012', '10/29', '456', 'Discover'),
    ('george',      'curious1',      'george@library.local',    'user',        NULL, NULL, NULL, NULL),
    ('hannah',      'hannah_montana','hannah@library.local',    'user',        '5425 8899 0011 2233', '07/27', '789', 'Mastercard'),
    ('ian',         'ian_hacks',     'ian@library.local',       'user',        '4539 9988 7766 5544', '04/28', '321', 'Visa'),
    ('julia',       'julia_childs',  'julia@library.local',     'user',        '3782 998877 66554',   '09/31', '654', 'Amex'),
    ('kyle',        'kyle_bro',      'kyle@library.local',      'user',        NULL, NULL, NULL, NULL),
    ('laura',       'laura_croft',   'laura@library.local',     'user',        '5100 3344 5566 7788', '02/26', '987', 'Mastercard'),
    ('mike',        'mike_drop',     'mike@library.local',      'user',        '4539 2233 4455 6677', '11/28', '111', 'Visa'),
    ('nina',        'nina_simone',   'nina@library.local',      'user',        '6011 9876 5432 1098', '06/29', '222', 'Discover'),
    ('oscar',       'oscar_grouch',  'oscar@library.local',     'user',        NULL, NULL, NULL, NULL),
    ('librarian',   'lib2024!',      'lib@library.local',       'admin',       '5425 2334 1098 7620', '11/27', '412', 'Mastercard'),
    ('root_admin',  'R00t$uper!99',  'root@library.local',      'super_admin', '3782 822463 10005',   '03/29', '7291','Amex');

-- Sample books
INSERT INTO books (title, author, genre, year, copies) VALUES
    ('The Pragmatic Programmer', 'Thomas & Hunt', 'Technology', 1999, 4),
    ('Clean Code',               'Robert Martin', 'Technology', 2008, 3),
    ('1984',                     'George Orwell', 'Fiction',    1949, 5),
    ('Hacking: The Art of Exploitation', 'Jon Erickson', 'Security', 2008, 2),
    ('The Hobbit',               'J.R.R. Tolkien', 'Fantasy',   1937, 6),
    ('Dune',                     'Frank Herbert', 'Science Fiction', 1965, 4),
    ('To Kill a Mockingbird',    'Harper Lee', 'Fiction', 1960, 5),
    ('The Great Gatsby',         'F. Scott Fitzgerald', 'Fiction', 1925, 3),
    ('Design Patterns',          'Gamma, Helm, Johnson, Vlissides', 'Technology', 1994, 2),
    ('Introduction to Algorithms', 'Cormen, Leiserson, Rivest, Stein', 'Technology', 1990, 2),
    ('The Catcher in the Rye',   'J.D. Salinger', 'Fiction', 1951, 4),
    ('Pride and Prejudice',      'Jane Austen', 'Fiction', 1813, 5),
    ('Fahrenheit 451',           'Ray Bradbury', 'Science Fiction', 1953, 3),
    ('The Lord of the Rings',    'J.R.R. Tolkien', 'Fantasy', 1954, 7),
    ('Brave New World',          'Aldous Huxley', 'Science Fiction', 1932, 4),
    ('The Art of Computer Programming', 'Donald Knuth', 'Technology', 1968, 1),
    ('Refactoring',              'Martin Fowler', 'Technology', 1999, 3),
    ('Moby-Dick',                'Herman Melville', 'Fiction', 1851, 2),
    ('War and Peace',            'Leo Tolstoy', 'Fiction', 1869, 3),
    ('Crime and Punishment',     'Fyodor Dostoevsky', 'Fiction', 1866, 4);

-- Sample loans
INSERT INTO loans (member_id, book_id, loaned_at, due_at, returned_at) VALUES
    (1, 1, DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 5 DAY), DATE_ADD(CURRENT_TIMESTAMP, INTERVAL 9 DAY), NULL),
    (2, 3, DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 15 DAY), DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 1 DAY), NULL),
    (3, 5, DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 2 DAY), DATE_ADD(CURRENT_TIMESTAMP, INTERVAL 12 DAY), NULL),
    (4, 7, DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 10 DAY), DATE_ADD(CURRENT_TIMESTAMP, INTERVAL 4 DAY), NULL),
    (5, 2, DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 20 DAY), DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 6 DAY), DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 5 DAY)),
    (1, 8, DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 1 DAY), DATE_ADD(CURRENT_TIMESTAMP, INTERVAL 13 DAY), NULL),
    (6, 12, DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 8 DAY), DATE_ADD(CURRENT_TIMESTAMP, INTERVAL 6 DAY), NULL),
    (8, 15, DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 30 DAY), DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 16 DAY), DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 20 DAY)),
    (10, 18, DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 3 DAY), DATE_ADD(CURRENT_TIMESTAMP, INTERVAL 11 DAY), NULL),
    (12, 10, DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 12 DAY), DATE_ADD(CURRENT_TIMESTAMP, INTERVAL 2 DAY), NULL);