/*
resq-data-assignment-2024
Topias Pesonen
topias.pesonen@gmail.com

PROBLEM:
The analyst wants to make at least the following queries:

- find the top 10 partners by sales

- identify the customers’ favourite partner segments (default offer types). 
    Partners are the companies who sell surplus items on the marketplace.

- find out what is the M1 retention for any given customer cohort. 
    A cohort consists of customers who made their first order within the same month (M0). 
    M1 retention is the share of customers who have made at least one purchase one month after their first purchase month.


OUTPUT:
one table to answer all the questions above

Tables: 

orders (id, createdAt, userId, quantity, refunded, currency, sales, providerId);
providers (id, defaultOfferType, country, registeredDate);
users (id, country, registeredDate);


columns needed to answer questions above:
userID, cohort, M1_retention, id, sales, partner, segment 

additional columns for CLV analysis:
createdAt

*/
----------------------------------------
-- Let's take a look at the data
----------------------------------------
SELECT * FROM orders LIMIT 5;
SELECT * FROM providers LIMIT 5;
SELECT * FROM users LIMIT 5;

-- Check for duplicate ID. This is the primary key of the new table we'll create
SELECT id, count(*) as countId
FROM orders
GROUP BY id
HAVING countId > 1;


--------------------------------------------------------------------------------------------------------
-- Next, it could be useful to begin by thinkikng what are the queries needed to answer the questions
--------------------------------------------------------------------------------------------------------
-- Top partners
SELECT 
    o.providerId AS partner,
    o.sales
FROM orders o INNER JOIN providers p on o.providerId = p.id
GROUP BY partner
ORDER BY sales DESC
LIMIT 10;

-- Favorite segments (by order count instead of sales here!)
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
-- Using a temp view for easier querying 
CREATE TEMP VIEW retention_table AS
-- Orders for each user ranked by their creation date - 1 is first order, 2 is second etc...
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

-- Average of the boolean = M1 retention rate of the customer base
SELECT 
    AVG(M1_retention) * 100 AS retention_rate_percent
FROM retention_table;

/*
Now we've sorted the queries, let's create a final view that has the necessary columns we used before
*/
CREATE TEMP VIEW final AS
SELECT 
    rt.userId,
    rt.first AS cohort,
    rt.M1_retention,
    o.id,
    o.createdAt,
    o.sales,
    o.providerId as partner,
    p.defaultOfferType as segment
FROM
    orders o 
INNER JOIN retention_table rt on o.userId = rt.userId
INNER JOIN providers p on o.providerId = p.id ;

-- just checking how it looks 
SELECT * FROM final
LIMIT 5;

-- Make sure we can answer the analyst's questions:
-- Find the top 10 partners by sales
SELECT 
    partner,
    sales
FROM final
GROUP BY partner
ORDER BY sales DESC
LIMIT 10;

-- Customer's favorite segments
SELECT 
    segment,
    COUNT(id) as orderCount
FROM final
--WHERE o.userId = 833181563296211638 -- uncomment this line to see a specific user
GROUP BY segment
ORDER BY orderCount DESC
LIMIT 10;

-- M1 retention given a cohort
SELECT 
    AVG(M1_retention) * 100 AS retention_rate_percent
FROM final
WHERE cohort = '2023-05';
-----------------------------------------------------------------------------------
-- Everything looks good, let's create the output table and insert from final view
-----------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS presentation_table (
    id INTEGER PRIMARY KEY,
    userID INTEGER,
    cohort TEXT,
    M1_retention INTEGER, -- This is actually a boolean!
    createdAt TEXT,
    sales REAL,
    partner INTEGER,
    segment TEXT
);

INSERT OR REPLACE INTO presentation_table (id, userID, cohort, M1_retention, createdAt, sales, partner, segment)
SELECT 
    id,
    userID,    
    cohort,
    M1_retention,
    createdAt,
    sales,
    partner,
    segment
FROM final;


-- Final output check
SELECT * FROM presentation_table LIMIT 5;