/*
Tables: 

orders (id, createdAt, userId, quantity, refunded, currency, sales, providerId);
providers (id, defaultOfferType, country, registeredDate);
users (id, country, registeredDate);

*/
-- Let's look a tthe data a bit
SELECT * FROM orders LIMIT 5;
SELECT * FROM providers LIMIT 5;
SELECT * FROM users LIMIT 5;

/*
The analyst wants to make at least the following queries:

- find the top 10 partners by sales

- identify the customers’ favourite partner segments (default offer types). 
    Partners are the companies who sell surplus items on the marketplace.

- find out what is the M1 retention for any given customer cohort. 
    A cohort consists of customers who made their first order within the same month (M0). 
    M1 retention is the share of customers who have made at least one purchase one month after their first purchase month.


OUTPUT:
one table to answer all the questions above
customer_id, customer_cohort, partner_id, , segment, sales, createdAt

*/

-- Let's begin by thinkikng what are the queries like that we need to answer the questions
-- Top partners
SELECT 
    o.providerId AS partner,
    o.sales
FROM orders o INNER JOIN providers p on o.providerId = p.id
GROUP BY partner
ORDER BY sales DESC
LIMIT 10;

-- Favorite segments (by order count instead of sales!)
SELECT 
    p.defaultOfferType AS segment,
    COUNT(o.id) as orderCount
FROM orders o 
INNER JOIN providers p ON o.providerId = p.id
--WHERE o.userId = 833181563296211638 -- uncomment this line to see a specific user
GROUP BY segment
ORDER BY orderCount DESC
LIMIT 10;

-- M1 retention
CREATE TEMP VIEW retention_table AS
WITH ranked_orders AS (
    SELECT 
        userId,
        id,
        createdAt,
        STRFTIME('%Y-%m', createdAt) AS yearmonth,
        ROW_NUMBER() OVER (PARTITION BY userID ORDER BY createdAt) as order_rank
    FROM
        orders
), first_orders AS (
    SELECT 
        userID,
        id, 
        createdAt,
        yearmonth
    FROM ranked_orders
    WHERE order_rank = 1
), second_orders AS (
        SELECT 
        userID,
        id, 
        createdAt,
        yearmonth
    FROM ranked_orders
    WHERE order_rank = 2
)

SELECT 
    f.userId,
    f.yearmonth as first,
    s.yearmonth as second,
    CASE
        WHEN s.yearmonth IS NULL THEN 0  -- No second order
        WHEN s.yearmonth = f.yearmonth THEN 1  -- Same month
        WHEN s.yearmonth = STRFTIME('%Y-%m', DATE(f.createdAt, '+1 month')) THEN 1  -- Next month
        ELSE 0  -- Later than next month
    END AS M1_retention
FROM first_orders f 
LEFT JOIN second_orders s ON f.userId = s.userId;

-- Now we can query from the temp view

SELECT * FROM retention_table
LIMIT 10;

-- Average of the boolean = M1 retention rate of the customer base (who've made at least one order!)
SELECT 
    AVG(M1_retention) * 100 AS retention_rate_percent
FROM retention_table;

/*
Now we've sorted the querys, how to create the pipeline?
*/
CREATE TEMP VIEW final AS
SELECT 
    rt.userId,
    rt.first AS cohort,
    rt.M1_retention,
    o.sales,
    o.providerId as partner,
    p.defaultOfferType
FROM
    orders o 
INNER JOIN retention_table rt on o.userId = rt.userId
INNER JOIN providers p on o.providerId = p.id 
--WHERE rt.first = '2023-05'
;

SELECT 
    partner,
    sales
FROM final
GROUP BY partner
ORDER BY sales DESC
LIMIT 10;

-- Create the output table
CREATE TABLE IF NOT EXISTS output_table AS
SELECT 
    id,    
    createdAt
FROM orders
WHERE quantity > 2;

-- Display the results

--SELECT * FROM output_table LIMIT 10;

