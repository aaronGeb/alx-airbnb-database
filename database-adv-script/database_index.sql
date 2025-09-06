-- database_index_mysql.sql
-- Query performance check
   
EXPLAIN ANALYZE
SELECT u.user_id, u.email, COUNT(b.booking_id) 
FROM users u 
LEFT JOIN bookings b ON u.user_id = b.user_id 
GROUP BY u.user_id, u.email;


-- Create indexes Use SHOW INDEX FROM table_name; to verify

CREATE INDEX idx_users_email       ON users(email);
CREATE INDEX idx_users_last_name   ON users(last_name);
CREATE INDEX idx_users_created_at  ON users(created_at);

CREATE INDEX idx_bookings_user_id        ON bookings(user_id);
CREATE INDEX idx_bookings_property_id    ON bookings(property_id);
CREATE INDEX idx_bookings_check_in_date  ON bookings(check_in_date);
CREATE INDEX idx_bookings_check_out_date ON bookings(check_out_date);
CREATE INDEX idx_bookings_status         ON bookings(status);

CREATE INDEX idx_properties_owner_id       ON properties(owner_id);
CREATE INDEX idx_properties_status         ON properties(status);
CREATE INDEX idx_properties_property_type  ON properties(property_type);
CREATE INDEX idx_properties_city           ON properties(city);

-- Composite indexes
CREATE INDEX idx_bookings_user_dates ON bookings(user_id, check_in_date, check_out_date);
CREATE INDEX idx_properties_location ON properties(city, property_type, status);

-- Update statistics
  
ANALYZE TABLE users;
ANALYZE TABLE bookings;
ANALYZE TABLE properties;

-- Test queries

-- Test 1: User booking search
EXPLAIN ANALYZE
SELECT u.user_id, u.email, b.booking_id, b.check_in_date
FROM users u
JOIN bookings b ON u.user_id = b.user_id
WHERE u.email = 'test@example.com'
  AND b.check_in_date BETWEEN '2024-01-01' AND '2024-12-31';

-- Test 2: Property search
EXPLAIN ANALYZE
SELECT p.property_id, p.property_type, COUNT(b.booking_id) AS booking_count
FROM properties p
LEFT JOIN bookings b ON p.property_id = b.property_id
WHERE p.city = 'New York'
  AND p.status = 'active'
GROUP BY p.property_id, p.property_type;

-- Test 3: Booking analysis
EXPLAIN ANALYZE
SELECT 
    u.user_id,
    u.email,
    COUNT(b.booking_id) AS total_bookings,
    AVG(b.total_price) AS avg_booking_price
FROM users u
LEFT JOIN bookings b ON u.user_id = b.user_id
WHERE b.status = 'completed'
GROUP BY u.user_id, u.email
HAVING COUNT(b.booking_id) > 5;

-- Index and table statistics
  
-- Indexes on a table
SHOW INDEX FROM users;
SHOW INDEX FROM bookings;
SHOW INDEX FROM properties;

-- Table size info
SELECT 
    table_name,
    table_rows,
    data_length,
    index_length,
    ROUND((data_length + index_length) / 1024 / 1024, 2) AS total_mb
FROM information_schema.tables
WHERE table_schema = DATABASE()
  AND table_name IN ('users','bookings','properties');

-- Index usage (requires performance_schema enabled)
SELECT 
    OBJECT_SCHEMA, OBJECT_NAME, INDEX_NAME,
    COUNT_STAR, SUM_TIMER_WAIT
FROM performance_schema.table_io_waits_summary_by_index_usage
WHERE OBJECT_SCHEMA = DATABASE()
ORDER BY COUNT_STAR DESC;

-- Unused indexes (if sys schema installed)
SELECT * FROM sys.schema_unused_indexes WHERE schema_name = DATABASE();
