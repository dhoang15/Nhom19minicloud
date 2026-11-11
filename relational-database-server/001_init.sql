CREATE DATABASE IF NOT EXISTS studentdb;
USE studentdb;

CREATE TABLE IF NOT EXISTS students (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    major VARCHAR(50),
    gpa FLOAT
);

INSERT INTO students (name, major, gpa) VALUES 
('Đặng Duy Hoàng', 'Information Technology', 3.7),
('Châu Ngọc Đăng Khoa', 'Information Technology', 3.5),
('Lê Thành Nam', 'Information Technology', 3.8);