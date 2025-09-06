# Partition Performance Report
## 1. Objective

Optimize the bookings table by splitting data into quarter-based partitions.
This improves:

  - Query performance on date range filters.
  - Manageability of historical data (easy drop/archive of old partitions).
  - Reduction in index and scan size for active queries. 
## 2. Partitioning Design
Table Definition

  - Partition key: start_date

  - Method: RANGE partitioning using TO_DAYS(start_date)

  - Primary Key: booking_id (auto-increment)

  - Additional attributes: user_id, property_id, status, created_at, updated_at
  
## 3. Indexing Strategy

- start_date → Partition pruning & range queries
- user_id → Joins with users
- property_id → Joins with properties
- status → Filtering (confirmed, cancelled, completed)
- 
Indexes created at partitioned table level, inherited by all partitions.
## 4. Query Performance Tests
#### Test Query 1:Range Scan (Single Quarter)

```
EXPLAIN ANALYZE
SELECT * 
FROM bookings_partitioned
WHERE start_date >= '2024-01-01'
  AND start_date < '2024-04-01';
```
Partition pruning ensures only p2024_q1 is scanned, not the entire table.
#### Test Query 2: Multi-quarter Aggregation
```
EXPLAIN ANALYZE
SELECT DATE_FORMAT(start_date, '%Y-%m') as booking_month,
       COUNT(*) as booking_count,
       SUM(total_price) as total_revenue
FROM bookings_partitioned
WHERE start_date >= '2024-01-01'
  AND start_date < '2024-07-01'
GROUP BY booking_month;
```
Scans only p2024_q1 + p2024_q2, improving aggregation speed


#### Test Query 3: Joins
```
EXPLAIN ANALYZE
SELECT b.booking_id, u.email, p.property_name, b.start_date, b.total_price
FROM bookings_partitioned b
JOIN users u ON b.user_id = u.user_id
JOIN properties p ON b.property_id = p.property_id
WHERE b.start_date BETWEEN '2024-01-01' AND '2024-03-31'
  AND b.status = 'confirmed';
```
## 5. Maintenance Strategy
### Partition Management

- Procedure: create_next_partition(start_date, end_date, partition_name)  
    - Dynamically adds a new partition for the next quarter.

- Event Scheduler: Automatically runs every 3 months to create new partitions.

### Archiving / Cleanup

- Procedure: cleanup_old_partitions(cutoff_date)

  - Drops partitions older than a given date.
  - Prevents data growth from slowing queries.
## 6. Monitoring
### Partition Size Report
```
SELECT
    table_name,
    partition_name,
    table_rows,
    data_length/1024/1024 AS data_mb,
    index_length/1024/1024 AS index_mb
FROM information_schema.partitions
WHERE table_schema = DATABASE()
  AND table_name = 'bookings_partitioned';
```
## 7 . Risks & Considerations

-  MySQL partitioned tables do not allow foreign keys.
- Too many partitions (>1000) can reduce performance.
-  Maintenance procedures must be tested carefully to avoid dropping active data.

## Conclusion:
Quarterly partitioning of the bookings table in MySQL 8.0.18 provides significant performance improvements for range queries, joins, and aggregations, while simplifying lifecycle management of booking data.