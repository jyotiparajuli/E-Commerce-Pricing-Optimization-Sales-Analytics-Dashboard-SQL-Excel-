--------------------------------------------------
-- SQL PROJECT: PRICING OPTIMIZATION MODEL
--------------------------------------------------

--------------------------------------------------
-- 1️⃣ Create Database
--------------------------------------------------
CREATE DATABASE pricing_optimization;

--------------------------------------------------
-- 2️⃣ Create Tables
--------------------------------------------------
CREATE TABLE products (
    product_id SERIAL PRIMARY KEY,
    product_name VARCHAR(100) NOT NULL,
    category VARCHAR(50),
    cost_price NUMERIC(10,2),
    base_price NUMERIC(10,2)
);

CREATE TABLE competitor_prices (
    comp_id SERIAL PRIMARY KEY,
    product_id INT REFERENCES products(product_id),
    competitor_name VARCHAR(50),
    competitor_price NUMERIC(10,2)
);

CREATE TABLE sales (
    sale_id SERIAL PRIMARY KEY,
    product_id INT REFERENCES products(product_id),
    sale_date DATE,
    quantity_sold INT,
    discount_percent NUMERIC(5,2),
    final_sale_price NUMERIC(10,2)
);

CREATE TABLE reviews (
    review_id SERIAL PRIMARY KEY,
    product_id INT REFERENCES products(product_id),
    rating INT CHECK (rating BETWEEN 1 AND 5),
    review_text TEXT
);

--------------------------------------------------
-- 3️⃣ Import CSV Files
---------------------------------------------------------------------------------------------

-- Imported data into the table using the Import/Export tool for efficiency and ease of use.

---------------------------------------------------------------------------------------------
-- 4️⃣ Professional Business Queries :-
--------------------------------------------------

-- 4.1: Identify High-Profit Products
-- Shows which products generate maximum profit 
SELECT p.product_name,
       SUM((COALESCE(s.final_sale_price, p.base_price) - p.cost_price) * s.quantity_sold) AS total_profit,
       SUM(s.quantity_sold) AS units_sold
FROM sales s
JOIN products p ON s.product_id = p.product_id
GROUP BY p.product_name
ORDER BY total_profit DESC
LIMIT 10;

-- 4.2: Discount Efficiency
-- Which discount levels drive maximum revenue & profit
SELECT s.discount_percent,
       SUM(s.quantity_sold) AS total_units_sold,
       SUM(COALESCE(s.final_sale_price, p.base_price) * s.quantity_sold) AS total_revenue,
       SUM((COALESCE(s.final_sale_price, p.base_price) - p.cost_price) * s.quantity_sold) AS total_profit
FROM sales s
JOIN products p ON s.product_id = p.product_id
GROUP BY s.discount_percent
ORDER BY total_profit DESC;

-- 4.3: High-Risk / Low-Performing Products
-- Products with low sales or low ratings
SELECT p.product_name,
       SUM(s.quantity_sold) AS total_units_sold,
       ROUND(AVG(r.rating),2) AS avg_rating,
       p.base_price,
      ROUND(AVG(c.competitor_price),2) AS avg_comp_price
FROM products p
LEFT JOIN sales s ON p.product_id = s.product_id
LEFT JOIN reviews r ON p.product_id = r.product_id
LEFT JOIN competitor_prices c ON p.product_id = c.product_id
GROUP BY p.product_name, p.base_price
HAVING SUM(s.quantity_sold) < 20 OR AVG(r.rating) < 3
ORDER BY avg_rating ASC, total_units_sold ASC;

-- 4.4: Price Sensitivity Analysis
-- Identify products that are highly sensitive to price changes
WITH price_sales AS (
    SELECT p.product_id, p.product_name,
          COALESCE(AVG(s.final_sale_price),p.base_price) AS avg_price,
           COALESCE(SUM(s.quantity_sold),0) AS total_units_sold
    FROM sales s
    JOIN products p ON s.product_id = p.product_id
    GROUP BY p.product_id, p.product_name
)
SELECT *,
       ROUND(total_units_sold / NULLIF(avg_price,0),2) AS price_sensitivity
FROM price_sales
ORDER BY price_sensitivity DESC;

-- 4.5: Correlation Between Rating & Sales
-- Identify if higher-rated products generate more revenue
SELECT p.product_name,
       ROUND(COALESCE(AVG(r.rating), 0), 2) AS avg_rating,
       ROUND(COALESCE(AVG(s.final_sale_price), p.base_price), 2) AS avg_price,
       COALESCE(SUM(s.quantity_sold), 0) AS total_units_sold
FROM products p
JOIN sales s ON p.product_id = s.product_id
JOIN reviews r ON p.product_id = r.product_id
GROUP BY p.product_name, p.base_price
ORDER BY total_units_sold DESC;

-- 4.6: Competitor Gap Analysis
-- Identify underpriced, overpriced, or competitive products
SELECT p.product_name, p.base_price, ROUND(AVG(c.competitor_price),2) AS avg_comp_price,
       CASE 
           WHEN p.base_price < AVG(c.competitor_price) THEN 'Underpriced'
           WHEN p.base_price > AVG(c.competitor_price) THEN 'Overpriced'
           ELSE 'Competitive'
       END AS price_position
FROM products p
JOIN competitor_prices c ON p.product_id = c.product_id
GROUP BY p.product_name, p.base_price
ORDER BY price_position;

-- 4.7: Seasonal / Monthly Revenue Trends
-- Identify seasonal trends per category
SELECT p.category,
       TO_CHAR(DATE_TRUNC('month', s.sale_date), 'YYYY-MM') AS month,
       SUM(COALESCE(s.final_sale_price, p.base_price) * s.quantity_sold) AS monthly_revenue
FROM sales s
JOIN products p ON s.product_id = p.product_id
GROUP BY p.category, month
ORDER BY p.category, month;

-- 4.8: Suggested Optimal Price per Product
-- Combines competitor price & ratings to recommend price adjustments
WITH comp_avg AS (
    SELECT p.product_id, ROUND(AVG(c.competitor_price),2) AS avg_comp_price
    FROM products p
    JOIN competitor_prices c ON p.product_id = c.product_id
    GROUP BY p.product_id
),
rating_factor AS (
    SELECT product_id, ROUND(AVG(r.rating),2) AS avg_rating
    FROM reviews r
    GROUP BY product_id
)
SELECT p.product_name,
       p.base_price AS current_price,
       c.avg_comp_price,
       r.avg_rating,
       ROUND(
           p.base_price * (0.5 + 0.25 * (r.avg_rating/5) + 0.25 * (c.avg_comp_price/p.base_price)), 2
       ) AS suggested_price
FROM products p
LEFT JOIN comp_avg c ON p.product_id = c.product_id
LEFT JOIN rating_factor r ON p.product_id = r.product_id
ORDER BY suggested_price DESC;

-- 4.9: Category-Level Suggested Price
-- Provides pricing recommendation at category level
SELECT p.category,
       ROUND(AVG(p.base_price), 2) AS avg_base_price,
       ROUND(AVG(c.competitor_price), 2) AS avg_comp_price,
       ROUND(AVG(r.rating), 2) AS avg_rating,
       ROUND(
           AVG(p.base_price) * (0.5 + 0.25 * (AVG(r.rating)/5) + 0.25 * (AVG(c.competitor_price)/AVG(p.base_price))), 2
       ) AS suggested_category_price
FROM products p
JOIN competitor_prices c ON p.product_id = c.product_id
JOIN reviews r ON p.product_id = r.product_id
GROUP BY p.category
ORDER BY suggested_category_price DESC;


--------------------------------------------------
-- 5️: Create View for Easy Reporting
--------------------------------------------------
CREATE OR REPLACE VIEW product_revenue_summary AS
SELECT p.product_id, 
       p.product_name, 
       p.category,
       COALESCE(SUM(s.quantity_sold), 0) AS total_units_sold,
       COALESCE(SUM(COALESCE(s.final_sale_price, p.base_price) * s.quantity_sold), 0) AS total_revenue,
       ROUND(COALESCE(AVG(r.rating), 0), 2) AS avg_rating,
       ROUND(COALESCE(AVG(c.competitor_price), 0), 2) AS avg_comp_price
FROM products p
LEFT JOIN sales s ON p.product_id = s.product_id
LEFT JOIN reviews r ON p.product_id = r.product_id
LEFT JOIN competitor_prices c ON p.product_id = c.product_id
GROUP BY p.product_id, p.product_name, p.category;

--------------------------------------------------
-- 5.1: The view to see the data
SELECT * FROM product_revenue_summary;

--------------------------------------------------
-- END OF SCRIPT
--------------------------------------------------