-- Write an initial query that retrieves all bookings along with the user details, property details, and payment details and save it on perfomance.sql


-- performance_mysql.sql
-- MySQL 8.0.18+

-- Initial Complex Query

EXPLAIN ANALYZE
SELECT 
    b.booking_id,
    b.check_in_date,
    b.check_out_date,
    b.total_price,
    u.user_id,
    u.first_name,
    u.last_name,
    u.email,
    p.property_id,
    p.property_name,
    p.property_type,
    p.city,
    pay.payment_id,
    pay.payment_status,
    pay.payment_date,
    r.rating,
    r.comment
FROM bookings b
JOIN users u ON b.user_id = u.user_id
JOIN properties p ON b.property_id = p.property_id
LEFT JOIN payments pay ON b.booking_id = pay.booking_id
LEFT JOIN reviews r ON b.booking_id = r.booking_id
WHERE b.check_in_date >= '2024-01-01'
  AND b.status = 'confirmed'
ORDER BY b.check_in_date DESC;



-- Optimized Query V1: Indexes

CREATE INDEX idx_bookings_status_date   ON bookings(status, check_in_date);
CREATE INDEX idx_bookings_user_property ON bookings(user_id, property_id);
CREATE INDEX idx_payments_booking       ON payments(booking_id);
CREATE INDEX idx_reviews_booking        ON reviews(booking_id);

EXPLAIN ANALYZE
SELECT 
    b.booking_id,
    b.check_in_date,
    b.check_out_date,
    b.total_price,
    u.user_id,
    u.first_name,
    u.last_name,
    u.email,
    p.property_id,
    p.property_name,
    p.property_type,
    p.city,
    pay.payment_id,
    pay.payment_status,
    pay.payment_date,
    r.rating,
    r.comment
FROM bookings b
JOIN users u ON b.user_id = u.user_id
JOIN properties p ON b.property_id = p.property_id
LEFT JOIN payments pay ON b.booking_id = pay.booking_id
LEFT JOIN reviews r ON b.booking_id = r.booking_id
WHERE b.check_in_date >= '2024-01-01'
  AND b.status = 'confirmed'
ORDER BY b.check_in_date DESC;

-- Optimized Query V2: 
  
CREATE TABLE mv_booking_details AS
SELECT 
    b.booking_id,
    b.check_in_date,
    b.check_out_date,
    b.total_price,
    b.status,
    u.user_id,
    u.first_name,
    u.last_name,
    u.email,
    p.property_id,
    p.property_name,
    p.property_type,
    p.city
FROM bookings b
JOIN users u ON b.user_id = u.user_id
JOIN properties p ON b.property_id = p.property_id
WHERE b.status = 'confirmed';

-- Add index for date filtering
CREATE INDEX idx_mv_booking_details_date ON mv_booking_details(check_in_date);

-- Query using materialized table
EXPLAIN ANALYZE
SELECT 
    mv.*,
    pay.payment_id,
    pay.payment_status,
    pay.payment_date,
    r.rating,
    r.comment
FROM mv_booking_details mv
LEFT JOIN payments pay ON mv.booking_id = pay.booking_id
LEFT JOIN reviews r ON mv.booking_id = r.booking_id
WHERE mv.check_in_date >= '2024-01-01'
ORDER BY mv.check_in_date DESC;

-- To refresh manually:
TRUNCATE TABLE mv_booking_details;
INSERT INTO mv_booking_details
SELECT 
    b.booking_id,
    b.check_in_date,
    b.check_out_date,
    b.total_price,
    b.status,
    u.user_id,
    u.first_name,
    u.last_name,
    u.email,
    p.property_id,
    p.property_name,
    p.property_type,
    p.city
FROM bookings b
JOIN users u ON b.user_id = u.user_id
JOIN properties p ON b.property_id = p.property_id
WHERE b.status = 'confirmed';

-- Optimized Query V3: Partitioning
 
CREATE TABLE bookings_partitioned (
    booking_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT,
    property_id BIGINT,
    check_in_date DATE,
    check_out_date DATE,
    total_price DECIMAL(10,2),
    status VARCHAR(20)
)
PARTITION BY RANGE (YEAR(check_in_date)) (
    PARTITION p2024 VALUES LESS THAN (2025),
    PARTITION pmax VALUES LESS THAN MAXVALUE
);

-- Query using partitioned table
EXPLAIN ANALYZE
SELECT 
    b.booking_id,
    b.check_in_date,
    b.check_out_date,
    b.total_price,
    u.user_id,
    u.first_name,
    u.last_name,
    u.email,
    p.property_id,
    p.property_name,
    p.property_type,
    p.city,
    pay.payment_id,
    pay.payment_status,
    pay.payment_date,
    r.rating,
    r.comment
FROM bookings_partitioned b
JOIN users u ON b.user_id = u.user_id
JOIN properties p ON b.property_id = p.property_id
LEFT JOIN payments pay ON b.booking_id = pay.booking_id
LEFT JOIN reviews r ON b.booking_id = r.booking_id
WHERE b.check_in_date >= '2024-01-01'
  AND b.status = 'confirmed'
ORDER BY b.check_in_date DESC;


/* ------------------------
   Maintenance and Monitoring
   ------------------------ */

-- Refresh stats
ANALYZE TABLE bookings;
ANALYZE TABLE payments;
ANALYZE TABLE reviews;

-- Index info
SHOW INDEX FROM bookings;
SHOW INDEX FROM payments;
SHOW INDEX FROM reviews;

-- Table size info
SELECT 
    table_name,
    table_rows,
    data_length,
    index_length,
    ROUND((data_length + index_length) / 1024 / 1024, 2) AS total_mb
FROM information_schema.tables
WHERE table_schema = DATABASE()
  AND table_name IN ('bookings','payments','reviews');

-- Index usage (if performance_schema enabled)
SELECT 
    OBJECT_SCHEMA, OBJECT_NAME, INDEX_NAME,
    COUNT_STAR, SUM_TIMER_WAIT
FROM performance_schema.table_io_waits_summary_by_index_usage
WHERE OBJECT_SCHEMA = DATABASE()
ORDER BY COUNT_STAR DESC;
