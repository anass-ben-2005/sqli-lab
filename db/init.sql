-- LibraryOS SQL Injection Lab Database Schema
-- This runs automatically on first container start

CREATE DATABASE IF NOT EXISTS librarydb CHARACTER SET utf8mb4;
USE librarydb;

-- Members table (contains authentication credentials)
CREATE TABLE members (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    username   VARCHAR(64)  NOT NULL UNIQUE,
    password   VARCHAR(255) NOT NULL,  -- plain-text: INTENTIONAL for demo
    email      VARCHAR(128) NOT NULL,
    role       ENUM('user','admin','super_admin') NOT NULL DEFAULT 'user',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
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
INSERT INTO members (username, password, email, role) VALUES
    ('alice',       'alice123',      'alice@library.local',     'user'),
    ('bob',         'bobpass',       'bob@library.local',       'user'),
    ('librarian',   'lib2024!',      'lib@library.local',       'admin'),
    ('root_admin',  'R00t$uper!99',  'root@library.local',      'super_admin');

-- Sample books
INSERT INTO books (title, author, genre, year, copies) VALUES
    ('The Pragmatic Programmer', 'Thomas & Hunt', 'Technology', 1999, 4),
    ('Clean Code',               'Robert Martin', 'Technology', 2008, 3),
    ('1984',                     'George Orwell', 'Fiction',    1949, 5),
    ('Hacking: The Art of Exploitation', 'Jon Erickson', 'Security', 2008, 2);