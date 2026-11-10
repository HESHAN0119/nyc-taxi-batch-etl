-- Task 5: analytics queries on the star schema (silver.fact_taxi_trips + dimensions).
-- The fact table holds raw trips, so each query filters out what would distort its metric
-- (refunds with negative amounts, zero-distance trips).

-- ============================================================================
-- 1. Average fare amount per mile
-- ============================================================================

-- 1a. Overall. Two ways to measure it:
--   weighted   = total fare / total miles (recommended: short trips can't dominate)
--   per_trip   = average of each trip's fare/mile (inflated by very short trips)
SELECT COUNT(*)                                           AS trips,
       ROUND(SUM(fare_amount) / SUM(trip_distance), 2)    AS avg_fare_per_mile_weighted,
       ROUND(AVG(fare_amount / trip_distance), 2)         AS avg_fare_per_mile_per_trip
FROM   silver.fact_taxi_trips
WHERE  trip_distance > 0
  AND  trip_distance <= 100      -- drop GPS/meter errors (e.g. 187,872 miles in 10 min)
  AND  fare_amount > 0;

-- 1b. Per day (for a dashboard trend line)
SELECT pickup_date,
       COUNT(*)                                           AS trips,
       ROUND(SUM(fare_amount) / SUM(trip_distance), 2)    AS avg_fare_per_mile
FROM   silver.fact_taxi_trips
WHERE  trip_distance > 0
  AND  trip_distance <= 100      -- drop GPS/meter errors (e.g. 187,872 miles in 10 min)
  AND  fare_amount > 0
GROUP  BY pickup_date
ORDER  BY pickup_date;

-- ============================================================================
-- 2. Peak hours for taxi rides
-- ============================================================================

-- 2a. Trips per hour of day, busiest first (top rows = peak hours)
SELECT d.hour                                             AS pickup_hour,
       COUNT(*)                                           AS trips,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_trips,
       RANK() OVER (ORDER BY COUNT(*) DESC)               AS busyness_rank
FROM   silver.fact_taxi_trips f
JOIN   silver.dim_datetime d ON d.datetime_key = f.pickup_datetime_key
GROUP  BY d.hour
ORDER  BY trips DESC;

-- 2b. Weekday vs weekend: peak hours differ (commute peaks vs late-night peaks)
SELECT CASE WHEN d.is_weekend THEN 'Weekend' ELSE 'Weekday' END AS day_type,
       d.hour                                             AS pickup_hour,
       COUNT(*)                                           AS trips,
       ROUND(COUNT(*)::numeric / COUNT(DISTINCT d.date), 0) AS avg_trips_per_day
FROM   silver.fact_taxi_trips f
JOIN   silver.dim_datetime d ON d.datetime_key = f.pickup_datetime_key
GROUP  BY 1, d.hour
ORDER  BY 1, d.hour;

-- ============================================================================
-- 3. Total revenue by payment type
-- ============================================================================

-- Net revenue: refunds (negative total_amount) are included so they cancel their original charge.
SELECT p.payment_type_id,
       p.description                                       AS payment_type,
       COUNT(*)                                            AS trips,
       SUM(f.total_amount)                                 AS total_revenue,
       ROUND(100.0 * SUM(f.total_amount) / SUM(SUM(f.total_amount)) OVER (), 1) AS pct_of_revenue,
       ROUND(AVG(f.total_amount), 2)                       AS avg_revenue_per_trip
FROM   silver.fact_taxi_trips f
JOIN   silver.dim_payment_type p ON p.payment_type_id = f.payment_type_id
GROUP  BY p.payment_type_id, p.description
ORDER  BY total_revenue DESC;
