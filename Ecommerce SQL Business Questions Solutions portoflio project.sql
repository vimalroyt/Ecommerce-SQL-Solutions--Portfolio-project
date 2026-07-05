USE ecommerce_portfolio_project;
# Note: here after importing all the tables, i checked the tables datatypes and fixed them.

show tables;
select * from customer_campaign;
select * from customers;
select * from marketing_campaigns;
select * from orders;
select * from products;
select * from returns;
-- ---------------------------- Let's sovle the business questions ----------------------------------------------
-- Problem Statement: Divide customers into Premium, Regular, and Low Value groups based on how much they spend?
select customer_id, round(sum(final_amount),2) as total_sales,
CASE
When sum(final_amount)>=50000 then "Premium Customer"
when sum(final_amount)>=20000 then "Regular customer"
ELSE "low value" END as "Customer segment"
FROM orders
group by customer_id;


# CTE
-- Problem Statement: Make a big analysis easier to read and work with?
WITH Customer_sales AS(
						select customer_id, round(sum(final_amount)) as revenue
						from orders
						group by Customer_ID
)                        
select * from customer_sales
where revenue>100000;

-- ----------------------------------Window function based problems ---------------------------------------------
# Aggregate Window Functions
-- Problem Statement: How is revenue changing over time and how does it compare with the average, 
-- highest, and lowest revenue?(Revenue trend analysis)
select order_date,
sum(Final_Amount) over(order by Order_Date) as running_total_revenue,
avg(Final_Amount) over() as avg_revenue,
max(final_amount) over() as max_revenue,
min(final_amount) over() as min_revenue
from orders;

# ROW_NUMBER()
-- Problem Statement: Who is the top customer in each city or state?
select * from(
		select customers.city, customers.Customer_ID, sum(Final_Amount) as revenue,
		row_number() over(partition by city order by sum(final_amount)desc) as row_n
		from customers join orders
		on customers.customer_id=orders.customer_id
		group by city,customer_id) as x
where row_n=1;


# RANK()
-- Problem Statement: How do customers rank based on how much money they spend?
select Customer_ID, sum(Final_Amount) as revenue,
rank() over(order by sum(final_amount) desc) rnk
from orders
group by Customer_ID;

-- if we require to find the second highest customers based on spend then
select * from(
select Customer_ID, sum(Final_Amount) as revenue,
rank() over(order by sum(final_amount) desc) rnk
from orders
group by Customer_ID) as x
where rnk=2;

# DENSE_RANK()
-- Problem Statement: Who are the top spending customers without skipping ranks?
SELECT customer_id,
SUM(final_amount) revenue,
DENSE_RANK() OVER(ORDER BY SUM(final_amount) DESC) drnk
FROM orders
GROUP BY customer_id;

# LAG()
-- Problem Statement: How many days passed between a customer's previous order and current order?
select customer_id, order_date as current_order,
lag(order_date) over(partition by customer_id order by order_date) as prev_order,
datediff(order_date,lag(order_date) over(partition by customer_id order by order_date)) as days_beeween_last_orders
from orders;

#LEAD()
-- Problem Statement: After placing an order, how many days later does the customer order again? 
-- (Next purchase date)
select customer_id, order_date as current_order,
lead(order_date) over(partition by Customer_ID order by order_date) as next_order,
datediff(lead(order_date) over(partition by Customer_ID order by order_date),order_date) as days_betwee_next_orders
from orders;


# FIRST_VALUE()
-- Problem Statement: What was the first product purchased by each customer?
select distinct(Customer_ID),
first_value(product_id) over(partition by customer_id order by Order_Date) as first_product
from orders;

-- if we want the exactly name of the customers and products not the product id then.
select distinct(customers.customer_name),
first_value(products.product_name) 
	over(partition by customers.customer_name order by orders.order_date) as first_product
from customers join orders on customers.customer_id = orders.customer_id
join products on orders.product_id = products.product_id;


# LAST_VALUE()
-- Problem Statement: What is the latest product purchased by each customer?
select distinct(customer_id),
last_value(product_id) over(partition by customer_id order by order_date
 ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) as lattest_purchase
from orders;


# NTH_VALUE()
-- Problem Statement: What was the third product purchased by each customer?
select distinct(customer_id),
nth_value(product_id,3) over(partition by customer_id order by order_date
ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) as thirt_purchase
from orders;

# NTILE()
-- Problem Statement: Divide customers into Platinum, Gold, Silver, and Bronze groups?
select customer_id,sum(final_amount),
ntile(4) over(order by sum(Final_Amount)desc) as customer_tier
from orders
group by customer_id;

 
# CUME_DIST()
-- Problem Statement: What percentage of customers spend less than a particular customer?
-- "Is customer se kam kharch karne wale kitne percent customers hain?"
select customer_id,sum(final_amount) as revenue,
cume_dist() over (order by sum(final_amount))as cd
from orders group by customer_id;

 
# PERCENT_RANK()
-- Problem Statement: What is the spending percentile of each customer?
SELECT customer_id,
SUM(final_amount) revenue,
PERCENT_RANK() OVER(ORDER BY SUM(final_amount)) pct_rank
FROM orders
GROUP BY customer_id;

/* Difference between they both_
CUME_DIST()	"Kitne log x customer ke neeche hai?"
PERCENT_RANK()	"x customer ranking me kitna upar hai?"
*/
-- --------------------------------------- Subquery based problems. ---------------------------------------------
# Scalar Subquery
-- Problem Statement: Which customers spend more money than the average customer?
SELECT customer_id,SUM(final_amount) spend
FROM orders
GROUP BY customer_id
HAVING spend >
			(SELECT AVG(customer_spend)
			 FROM (SELECT SUM(final_amount) customer_spend FROM orders GROUP BY customer_id) x
 );


# Multiple Row Subquery ( read the question again)
-- Problem Statement: Which products belong to the top-selling categories? (Jo categories sabse zyada 
-- sales la rahi hain, 
-- un categories ke andar kaunse products aate hain?)
    
SELECT * FROM products WHERE category IN(
				SELECT category FROM (
									SELECT p.category FROM products p JOIN orders o
									ON p.product_id = o.product_id
									GROUP BY p.category
									ORDER BY SUM(o.final_amount) DESC
									LIMIT 1) top_1st_category
);

# Correlated Subquery
-- Problem Statement: Which products are priced higher than the average price in their category?
SELECT product_name, category, selling_price
FROM products p WHERE selling_price > (
								SELECT AVG(selling_price)
								FROM products p2
								WHERE p2.category = p.category
							);


# Nested Subquery
-- Problem Statement: Which products are doing better than both their category average and the overall company average?
select product_id from(
		select product_id, avg(final_amount) as avg_sales
		from orders	group by product_id
        ) as x
where avg_sales> (select avg(final_amount) from orders);


# Subquery in WHERE Clause
-- Problem Statement: Which customers spend more than the average customer over their lifetime 
-- (Which customers have spent more than the average spending of all customers) ?

# this query will compare customer total spent lifetime vs customer spent average lifetime
select * from customers
where customer_id IN(
					select customer_id from orders
					group by customer_id having sum(final_amount)> (select avg(total_sales) from 
				(
				# This will return per customer spent over their lifetime.
				SELECT SUM(final_amount) total_sales
				FROM orders
				GROUP BY customer_id)x)                
); -- need to optimize this query...


# Subquery in FROM Clause
-- Problem Statement: Which months performed better than an average month?
-- (Kaunse months ki revenue average monthly revenue se zyada thi)

select * from (
			select month(order_date) as mnth,sum(final_amount) as revenue from orders group by month(order_date)) as x
where revenue>(
			select avg(Total_revenue) from (
									select sum(final_amount) as Total_revenue from orders group by month(order_date))as xx);

#Subquery in SELECT Clause
-- Problem Statement: Show each customer's spending along with the company average in the same report?
-- (Compare customer spend vs average)
select customer_id, sum(final_amount) as customer_wise_spend, 
(select avg(final_amount) as avg_spend from orders) as company_avg_spend
from orders
group by customer_id;


#Subquery in HAVING Clause
-- Problem Statement: Which cities bring in more revenue than the average city?
-- Which cities generate more revenue than the average city revenue?
select customers.city, round(sum(orders.final_amount)) as revenue
from customers join orders
on customers.Customer_ID=orders.Customer_ID
group by customers.city
having revenue> (select avg(revenue) 
						from(
							select customers.city, sum(orders.final_amount) as revenue
							from customers join orders
							on customers.Customer_ID=orders.Customer_ID
							group by customers.city
                            )as x
				);


# Subquery with INSERT
-- Problem Statement: Move inactive customers to a history table without adding duplicates?

# let's create table first
CREATE TABLE customer_history (
    customer_id VARCHAR(20) PRIMARY KEY,
    customer_name VARCHAR(100),
    gender VARCHAR(20),
    age INT,
    city VARCHAR(100),
    state VARCHAR(100),
    join_date DATE,
    customer_segment VARCHAR(50),
	acquisition_channel VARCHAR(100)
);

Insert into customer_history select * from customers
where customer_id not in (select distinct customer_id from orders);

-- let's see that table.
select * from customer_history;

-- Since the condition is not matching no values got inserted..

#Subquery with UPDATE
-- Problem Statement: How can we automatically update customer segments based on their spending?
update customers 
set customer_segment = "Premium"
where customers.Customer_ID in (
								select customer_id from orders
                                group by Customer_ID
                                having sum(final_amount)>60000);
                                
set sql_safe_updates =0;

-- It also needs to improved.

# Subquery with DELETE
-- Problem Statement: How can we remove records that are no longer useful?
Delete from customers
where Customer_ID not in (select distinct Customer_ID from orders);

-- here also no condition matched, no values got deleted.
set sql_safe_updates=0;


-- -------------------------------------------------- The End, Thanks for watching till here.--------------