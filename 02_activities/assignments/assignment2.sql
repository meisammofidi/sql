/* ASSIGNMENT 2 */
/* SECTION 2 */

-- COALESCE
/* 1. Our favourite manager wants a detailed long list of products, but is afraid of tables! 
We tell them, no problem! We can produce a list with all of the appropriate details. 

Using the following syntax you create our super cool and not at all needy manager a list:

SELECT 
product_name || ', ' || product_size|| ' (' || product_qty_type || ')'
FROM product

But wait! The product table has some bad data (a few NULL values). 
Find the NULLs and then using COALESCE, replace the NULL with a 
blank for the first problem, and 'unit' for the second problem. 

HINT: keep the syntax the same, but edited the correct components with the string. 
The `||` values concatenate the columns into strings. 
Edit the appropriate columns -- you're making two edits -- and the NULL rows will be fixed. 
All the other rows will remain the same.) */

-- Step 1: Find rows with NULL values
SELECT product_id, product_name, product_size, product_qty_type
FROM product
WHERE product_size IS NULL
   OR product_qty_type IS NULL;

-- Step 2: Produce cleaned-up product list using COALESCE
SELECT
  product_name
  || ', '
  || COALESCE(product_size, '')
  || ' ('
  || COALESCE(product_qty_type, 'unit')
  || ')'
AS product_display
FROM product;


--Windowed Functions
/* 1. Write a query that selects from the customer_purchases table and numbers each customer’s  
visits to the farmer’s market (labeling each market date with a different number). 
Each customer’s first visit is labeled 1, second visit is labeled 2, etc. 

You can either display all rows in the customer_purchases table, with the counter changing on
each new market date for each customer, or select only the unique market dates per customer 
(without purchase details) and number those visits. 
HINT: One of these approaches uses ROW_NUMBER() and one uses DENSE_RANK(). */
SELECT
  cp.customer_id,
  cp.market_date,
  cp.product_id,
  cp.vendor_id,
  cp.quantity,
  cp.cost_to_customer_per_qty,
  cp.transaction_time,
  DENSE_RANK() OVER (
    PARTITION BY cp.customer_id
    ORDER BY cp.market_date
  ) AS visit_number
FROM customer_purchases AS cp
ORDER BY cp.customer_id, cp.market_date, cp.transaction_time;


/* 2. Reverse the numbering of the query from a part so each customer’s most recent visit is labeled 1, 
then write another query that uses this one as a subquery (or temp table) and filters the results to 
only the customer’s most recent visit. */

-- Step1: Reverse the numbering: most recent visit per customer = 1
SELECT
  cp.customer_id,
  cp.market_date,
  cp.product_id,
  cp.vendor_id,
  cp.quantity,
  cp.cost_to_customer_per_qty,
  cp.transaction_time,
  DENSE_RANK() OVER (
    PARTITION BY cp.customer_id
    ORDER BY cp.market_date DESC
  ) AS visit_number_desc
FROM customer_purchases AS cp;

-- Step2: Use the above as a subquery and filter to only the most recent visit
WITH ranked AS (
  SELECT
    cp.*,
    DENSE_RANK() OVER (
      PARTITION BY cp.customer_id
      ORDER BY cp.market_date DESC
    ) AS visit_number_desc
  FROM customer_purchases cp
)
SELECT *
FROM ranked
WHERE visit_number_desc = 1
ORDER BY customer_id, market_date DESC, transaction_time DESC;


/* 3. Using a COUNT() window function, include a value along with each row of the 
customer_purchases table that indicates how many different times that customer has purchased that product_id. */
SELECT
  cp.customer_id,
  cp.product_id,
  cp.market_date,
  cp.vendor_id,
  cp.quantity,
  cp.cost_to_customer_per_qty,
  cp.transaction_time,
  COUNT(DISTINCT cp.market_date) OVER (
    PARTITION BY cp.customer_id, cp.product_id
  ) AS times_customer_bought_product
FROM customer_purchases cp
ORDER BY cp.customer_id, cp.product_id, cp.market_date;


-- String manipulations
/* 1. Some product names in the product table have descriptions like "Jar" or "Organic". 
These are separated from the product name with a hyphen. 
Create a column using SUBSTR (and a couple of other commands) that captures these, but is otherwise NULL. 
Remove any trailing or leading whitespaces. Don't just use a case statement for each product! 

| product_name               | description |
|----------------------------|-------------|
| Habanero Peppers - Organic | Organic     |

Hint: you might need to use INSTR(product_name,'-') to find the hyphens. INSTR will help split the column. */

SELECT 
  product_name,
  LTRIM(RTRIM(
    CASE 
      WHEN INSTR(product_name, '-') > 0 
      THEN SUBSTR(product_name, INSTR(product_name, '-') + 1)
    END
  )) AS description
FROM product;


/* 2. Filter the query to show any product_size value that contain a number with REGEXP. */
SELECT product_name, product_size
FROM product
WHERE product_size REGEXP '[0-9]';


-- UNION
/* 1. Using a UNION, write a query that displays the market dates with the highest and lowest total sales.

HINT: There are a possibly a few ways to do this query, but if you're struggling, try the following: 
1) Create a CTE/Temp Table to find sales values grouped dates; 
2) Create another CTE/Temp table with a rank windowed function on the previous query to create 
"best day" and "worst day"; 
3) Query the second temp table twice, once for the best day, once for the worst day, 
with a UNION binding them. */

WITH sales_by_date AS (
  SELECT
    market_date,
    SUM(COALESCE(quantity, 0) * COALESCE(cost_to_customer_per_qty, 0)) AS total_sales
  FROM customer_purchases
  GROUP BY market_date
),
ranked AS (
  SELECT
    market_date,
    total_sales,
    DENSE_RANK() OVER (ORDER BY total_sales DESC) AS best_rank,
    DENSE_RANK() OVER (ORDER BY total_sales ASC)  AS worst_rank
  FROM sales_by_date
)

SELECT 'BEST' AS label, market_date, total_sales
FROM ranked
WHERE best_rank = 1
UNION ALL
SELECT 'WORST' AS label, market_date, total_sales
FROM ranked
WHERE worst_rank = 1
ORDER BY label DESC, total_sales DESC;


/* SECTION 3 */

-- Cross Join
/*1. Suppose every vendor in the `vendor_inventory` table had 5 of each of their products to sell to **every** 
customer on record. How much money would each vendor make per product? 
Show this by vendor_name and product name, rather than using the IDs.

HINT: Be sure you select only relevant columns and rows. 
Remember, CROSS JOIN will explode your table rows, so CROSS JOIN should likely be a subquery. 
Think a bit about the row counts: how many distinct vendors, product names are there (x)?
How many customers are there (y). 
Before your final group by you should have the product of those two queries (x*y).  */

WITH num_customers AS (
  -- y = number of customers
  SELECT COUNT(*) AS customers_cnt
  FROM customer
),
vendor_products AS (
  -- x = distinct vendor–product pairs that are actually carried
  SELECT DISTINCT vendor_id, product_id
  FROM vendor_inventory
),
price_per_vendor_product AS (
  -- unit price per vendor–product, based on actual sales (avg across dates)
  SELECT
    vendor_id,
    product_id,
    AVG(cost_to_customer_per_qty) AS unit_price
  FROM customer_purchases
  GROUP BY vendor_id, product_id
)
SELECT
  v.vendor_name,
  p.product_name,
  5 AS units_per_customer,
  nc.customers_cnt AS customers,
  ROUND(pp.unit_price, 2) AS unit_price,
  ROUND(5 * nc.customers_cnt * pp.unit_price, 2) AS expected_revenue
FROM vendor_products vp
JOIN vendor  v ON v.vendor_id  = vp.vendor_id
JOIN product p ON p.product_id = vp.product_id
JOIN price_per_vendor_product pp
  ON pp.vendor_id = vp.vendor_id
 AND pp.product_id = vp.product_id
CROSS JOIN num_customers nc
ORDER BY v.vendor_name, p.product_name;


-- INSERT
/*1.  Create a new table "product_units". 
This table will contain only products where the `product_qty_type = 'unit'`. 
It should use all of the columns from the product table, as well as a new column for the `CURRENT_TIMESTAMP`.  
Name the timestamp column `snapshot_timestamp`. */
CREATE TABLE product_units AS
SELECT 
    p.*,
    CURRENT_TIMESTAMP AS snapshot_timestamp
FROM product p
WHERE p.product_qty_type = 'unit';


/*2. Using `INSERT`, add a new row to the product_units table (with an updated timestamp). 
This can be any product you desire (e.g. add another record for Apple Pie). */

INSERT INTO product_units
SELECT 
    p.*,
    CURRENT_TIMESTAMP AS snapshot_timestamp
FROM product p
WHERE p.product_name = 'Apple Pie';

-- DELETE
/* 1. Delete the older record for the whatever product you added. 

HINT: If you don't specify a WHERE clause, you are going to have a bad time.*/
DELETE FROM product_units
WHERE product_name = 'Apple Pie'
  AND snapshot_timestamp < (
    SELECT MAX(snapshot_timestamp)
    FROM product_units
    WHERE product_name = 'Apple Pie'
  );


-- UPDATE
/* 1.We want to add the current_quantity to the product_units table. 
First, add a new column, current_quantity to the table using the following syntax.

ALTER TABLE product_units
ADD current_quantity INT;

Then, using UPDATE, change the current_quantity equal to the last quantity value from the vendor_inventory details.

HINT: This one is pretty hard. 
First, determine how to get the "last" quantity per product. 
Second, coalesce null values to 0 (if you don't have null values, figure out how to rearrange your query so you do.) 
Third, SET current_quantity = (...your select statement...), remembering that WHERE can only accommodate one column. 
Finally, make sure you have a WHERE statement to update the right row, 
	you'll need to use product_units.product_id to refer to the correct row within the product_units table. 
When you have all of these components, you can run the update statement. */

-- Step 1: Add the new column
ALTER TABLE product_units
ADD current_quantity INT;

-- Step 2: Update the current_quantity with the last quantity from vendor_inventory
UPDATE product_units
SET current_quantity = COALESCE((
    SELECT vi.quantity
    FROM vendor_inventory vi
    WHERE vi.product_id = product_units.product_id
    ORDER BY vi.market_date DESC
    LIMIT 1
), 0);
