-- Write a query to find the total number of bookings made by each user, using the `COUNT` function and `GROUP BY clause`
SELECT 
    u.user_id,
    u.first_name,
    u.last_name,
    COUNT(b.booking_id) as total_bookings,
    COALESCE(SUM(b.total_price), 0) as total_spent
FROM 
    users u
LEFT JOIN 
    bookings b ON u.user_id = b.user_id
GROUP BY 
    u.user_id,
    u.first_name,
    u.last_name
ORDER BY 
    total_bookings DESC;


-- Use a window function `(ROW_NUMBER, RANK)` to rank properties based on the total number of bookings they have received.
 p.property_id,
    p.property_name,
    COUNT(b.booking_id) as total_bookings,
    ROW_NUMBER() OVER (ORDER BY COUNT(b.booking_id) DESC) as booking_rank,
    RANK() OVER (ORDER BY COUNT(b.booking_id) DESC) as booking_rank_with_ties,
    DENSE_RANK() OVER (ORDER BY COUNT(b.booking_id) DESC) as dense_booking_rank
FROM 
    properties p
LEFT JOIN 
    bookings b ON p.property_id = b.property_id
GROUP BY 
    p.property_id,
    p.property_name
ORDER BY 
    total_bookings DESC;
