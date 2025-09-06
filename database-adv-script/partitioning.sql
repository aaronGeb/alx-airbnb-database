-- partitioning_mysql.sql

-- 1. Create the partitioned table (RANGE by QUARTER of start_date)
DROP TABLE IF EXISTS bookings_partitioned;

CREATE TABLE bookings_partitioned (
    booking_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT,
    property_id BIGINT,
    start_date DATE,
    end_date DATE,
    total_price DECIMAL(10,2),
    status VARCHAR(20),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)
PARTITION BY RANGE (TO_DAYS(start_date)) (
    PARTITION p2024_q1 VALUES LESS THAN (TO_DAYS('2024-04-01')),
    PARTITION p2024_q2 VALUES LESS THAN (TO_DAYS('2024-07-01')),
    PARTITION p2024_q3 VALUES LESS THAN (TO_DAYS('2024-10-01')),
    PARTITION p2024_q4 VALUES LESS THAN (TO_DAYS('2025-01-01')),
    PARTITION pmax     VALUES LESS THAN MAXVALUE
);

-- 2. Indexes on partitioned table
ALTER TABLE bookings_partitioned ADD INDEX idx_bookings_part_start_date (start_date);
ALTER TABLE bookings_partitioned ADD INDEX idx_bookings_part_user_id (user_id);
ALTER TABLE bookings_partitioned ADD INDEX idx_bookings_part_property_id (property_id);
ALTER TABLE bookings_partitioned ADD INDEX idx_bookings_part_status (status);

-- 3. Migrate existing data
INSERT INTO bookings_partitioned (booking_id, user_id, property_id, start_date, end_date, total_price, status, created_at, updated_at)
SELECT booking_id, user_id, property_id, start_date, end_date, total_price, status, created_at, updated_at
FROM bookings
WHERE start_date >= '2024-01-01' AND start_date < '2025-01-01';

-- 4. Test Queries

-- Test Query 1: Range scan for Q1
EXPLAIN ANALYZE
SELECT *
FROM bookings_partitioned
WHERE start_date >= '2024-01-01' 
  AND start_date < '2024-04-01';

-- Test Query 2: Multi-quarter aggregation
EXPLAIN ANALYZE
SELECT 
    DATE_FORMAT(start_date, '%Y-%m') as booking_month,
    COUNT(*) as booking_count,
    SUM(total_price) as total_revenue
FROM bookings_partitioned
WHERE start_date >= '2024-01-01' 
  AND start_date < '2024-07-01'
GROUP BY booking_month
ORDER BY booking_month;

-- Test Query 3: Join with users + properties
EXPLAIN ANALYZE
SELECT 
    b.booking_id,
    u.email,
    p.property_name,
    b.start_date,
    b.total_price
FROM bookings_partitioned b
JOIN users u ON b.user_id = u.user_id
JOIN properties p ON b.property_id = p.property_id
WHERE b.start_date BETWEEN '2024-01-01' AND '2024-03-31'
  AND b.status = 'confirmed';


-- 5. Stored Procedure: Create next partition
DELIMITER //
CREATE PROCEDURE create_next_partition(
    IN start_date DATE,
    IN end_date DATE,
    IN partition_name VARCHAR(64)
)
BEGIN
    SET @stmt = CONCAT(
        'ALTER TABLE bookings_partitioned ',
        'ADD PARTITION (PARTITION ', partition_name,
        ' VALUES LESS THAN (TO_DAYS(\'', end_date, '\')))'
    );
    PREPARE s FROM @stmt;
    EXECUTE s;
    DEALLOCATE PREPARE s;
END;
//
DELIMITER ;

-- 6. Event Scheduler: Auto-create partitions every quarter
SET GLOBAL event_scheduler = ON;

DELIMITER //
CREATE EVENT IF NOT EXISTS ev_create_future_partitions
ON SCHEDULE EVERY 3 MONTH
DO
BEGIN
    CALL create_next_partition(CURDATE(), DATE_ADD(CURDATE(), INTERVAL 3 MONTH), CONCAT('p', YEAR(CURDATE()), '_q', QUARTER(CURDATE())));
END;
//
DELIMITER ;


-- 7. Monitoring Partition Sizes
SELECT
    table_name,
    partition_name,
    table_rows,
    data_length/1024/1024 AS data_mb,
    index_length/1024/1024 AS index_mb
FROM information_schema.partitions
WHERE table_schema = DATABASE()
  AND table_name = 'bookings_partitioned';

-- 8. Cleanup Procedure: Drop old partitions
DELIMITER //
CREATE PROCEDURE cleanup_old_partitions(IN cutoff DATE)
BEGIN
    DECLARE done INT DEFAULT 0;
    DECLARE pname VARCHAR(64);

    DECLARE cur CURSOR FOR
        SELECT partition_name
        FROM information_schema.partitions
        WHERE table_schema = DATABASE()
          AND table_name = 'bookings_partitioned'
          AND partition_name IS NOT NULL;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    OPEN cur;
    read_loop: LOOP
        FETCH cur INTO pname;
        IF done THEN
            LEAVE read_loop;
        END IF;

        SET @drop_stmt = CONCAT('ALTER TABLE bookings_partitioned DROP PARTITION ', pname);
    END LOOP;

    CLOSE cur;
END;
//
DELIMITER ;
