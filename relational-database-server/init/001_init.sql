CREATE DATABASE IF NOT EXISTS studentdb
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE studentdb;

CREATE TABLE IF NOT EXISTS students (
    id INT AUTO_INCREMENT PRIMARY KEY,
    student_id VARCHAR(10) NOT NULL UNIQUE,
    fullname VARCHAR(100) NOT NULL,
    dob DATE NOT NULL,
    major VARCHAR(50) NOT NULL,
    gpa DECIMAL(3, 2) NOT NULL
);

INSERT INTO students (student_id, fullname, dob, major, gpa) VALUES
    ('SV001', 'Võ Nguyễn Duy Hoàng', '2006-11-15', 'Information Technology', 3.70),
    ('SV002', 'Châu Ngọc Đăng Khoa', '2003-08-22', 'Information Technology', 3.50),
    ('SV003', 'Lê Thành Nam', '2003-12-03', 'Information Technology', 3.80),
    ('SV004', 'Lê Trần Huy Khang', '2006-10-21', 'Computer Science', 3.60),
    ('SV005', 'Lê V', '2008-10-04', 'Computer Science', 3.40)
ON DUPLICATE KEY UPDATE
    fullname = VALUES(fullname),
    dob = VALUES(dob),
    major = VALUES(major),
    gpa = VALUES(gpa);