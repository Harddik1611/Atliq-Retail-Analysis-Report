-- Insight1: Find the number of Orders placed on weekends (Saturday & Sunday)
select count(*) as weekend_order_count
from (
select order_id,customer_id,order_datetime,payment_method,order_total,
dayofweek(order_datetime) as week
from orders
where dayofweek(order_datetime) in (1,7)
) t;

-- Insight2: For each customer,fetch their latest order along with corresponding  order_id
select *
from (
select c.customer_id,first_name,city,order_id,order_datetime,order_total,
row_number() over(partition by c.customer_id order by o.order_datetime desc) as rn
from customers c
join orders o
on o.customer_id=c.customer_id
) t
where t.rn = 1;

-- Insight3: Customers who returned  at least one item
select o.customer_id
from returns r
join order_items oi
on r.order_item_id = oi.order_item_id
join orders o
on oi.order_id= o.order_id;

/* Insight4: Make order value bucketing agianst each customers orders
   if order_total is below 1000 - "Low"
   if order_total greater than or equal to 1000 less than 5000 - "Medium"
   otherwise "High" for any value of order total greater than 5000
*/
select c.customer_id,first_name,order_id,order_total,
case 
	when order_total < 1000 then "Low"
    when order_total >= 1000 and order_total < 5000 then "Medium"
    else "High"  end as order_bucketing
from customers c
join orders o
on c.customer_id = o.customer_id;

-- Insight 5: Products sold more than average quantity
select product_id,sum(quantity) as total_quantity
from order_items 
group by product_id
having sum(quantity) > (
	select avg(quantity)
	from order_items
    );

-- Insight 6: Find the Total orders and total revenue month wise
select date_format(order_datetime,"%Y-%m") as order_month,
count(order_id) as total_order,
sum(order_total) as total_revenue
from orders
group by date_format(order_datetime,"%Y-%m")
order by order_month ;

-- Insight 7: Find the order that are not yet delivered
select count(order_status) as total_not_delivered_order
from orders
where order_status <> "DELIVERED";

-- Insight 8:  Payment method contributing maximum revenue
select distinct payment_method,sum(order_total) as total_revenue
from orders
group by payment_method
order by total_revenue desc;

-- Insight 9: Find the top 5 cities by total prder values
select shipping_city,sum(order_total) as city_wise_revenue
from orders
group by shipping_city
order by city_wise_revenue desc
limit 5;

-- Insight 10: Average Order Value (AOV) 
select o.customer_id,first_name,city,round(avg(order_total),2) as AOV
from orders o
join customers c
on o.customer_id =c.customer_id
group by customer_id,first_name,city
order by AOV desc;


-- Insight 11 : Orders where order_total != sum(line_total) (To check whether is any Data Leakage or not)
select o.order_id,order_total,
sum(line_total) as calculated_sum
from orders o
join order_items oi
on o.order_id=oi.order_id
group by o.order_id,order_total
having order_total != sum(line_total);


-- Insight 12: Top 5 products by quantity sold
select oi.product_id,product_name,sum(quantity) as total_qty_sold
from products p
join order_items oi
on p.product_id = oi.product_id
group by oi.product_id,product_name
order by total_qty_sold desc
limit 5;

-- Insight 13: Category-wise revenue contribution
select p.category,sum(line_total) as category_revenue
from products p
join order_items oi
on p.product_id = oi.product_id
group by p.category
order by category_revenue desc;

-- Insight 14: Find the Discount percentage applied per order_item
select order_item_id, product_id,unit_price,
discount,round((discount/unit_price)* 100,2) as discount_pct
from order_items
order by discount_pct desc
limit 10;

select avg(item_count) as avag_items_per_order
from (
	select order_id , sum(quantity) as item_count
	from order_items
	group by order_id
) t;


-- Insight 16: Find out the Customer with more than 2 orders in last 6 month
select c.customer_id,c.first_name,city,count(order_id) as total_order
from orders o
join customers c
on c.customer_id=o.customer_id
where order_datetime > (select max(order_datetime) from orders) - interval 6 month
group by customer_id
having count(order_id) > 2;


-- Insight 17 : Find the  Active Products with zero sales in last 90 days.
Select p.product_id,product_name,count(o.order_id) as total_order
from products p
left join order_items oi
on p.product_id =oi.prodcut_id
left join orders o
on o.order_id = oi.order_id and  order_datetime >= (
select max(order_datetime) from orders) - interval 90 day
group by p.product_id, product_name
having count(o.order_id) = 0;


-- Insight 18 :  Average time gap between consecutive orders per customer
select customer_id,
avg(datediff(order_datetime,previous_order_date)) as avg_diff_date
from (
select customer_id,order_datetime,
lag(order_date) over(partition by customer_id order by order_datetime) as prev_order_date
from orders 
order by  customer_id
) t
where previous_order_date is not null
group by cusgtomer_id
order by avg_diff_date desc;

-- Business insights: We can perform email marketing or run ad campaign for the customer with highest order_time_gap  to convert one organic  customer  to a loyal customer count.


-- Insight 19 :  Find the First order value vs Latest Order value
select customer_id,
max(case when rank_asc = 1 then order_total end ) as first_order_value,
max(case when rank_desc = 1 then order_total end ) as latest_order_value
from (
select customer_id,order_datetime,
row_number() over(partition by customer_id order by order_datetime asc) as rank_asc,
row_number() over(partition by customer_id order by order_datetime desc) as rank_desc
from orders
)t
group  by customer_id;

-- Insight 20 :  Highest Contributing order_item per order
with cte as (
select order_id,order_item_id,p.product_name,line_total,
row_number() over(partition  by order_id order by line_total desc) as rnk
from order_items oi
join products p
on p.product_id=oi.product_id
)
select order_item_id,order_id, product_name,line_total
from  cte 
where rnk=1;


-- Insight 21: Calculate the no of Return requests approved more than or equal to 5 days
select return_id,refund_amount,
datediff(approved_at,requested_at) as approval_days
from returns
where approved_at is not null and
datediff(approved_at,requested_at) >= 5;

-- Insight 22 :  Find the Category wise return rate
with category_sales as (
	select category, sum(quantity) as total_sold
	from products p
	join order_items oi
	on p.product_id = oi.product_id
	group by category
) , category_returns as (
	select category,sum(quantity) as total_returns
	from products p
	join order_items oi
	using(product_id)
	join returns r
	using(return_id)
	group by category
)
select cs.category,cs.total_sold,cr.total_returns,
round((cr.total_returns/cs.total_sold) * 100,2) as return_rate_pct
from category_sales cs
join category_returns cr
using(category)
group by cs.category;

-- Insight 23:  Calculate the Brand-Wise Revenue Contribution
select brand,sum(line_total) as brand_revenue
from products p
join order_items oi
on p.product_id = oi.product_id
group by brand
order by brand_revenue desc;

-- Insight 24 : Fidn out the  High Return customers (Return amount > 25% of total purchase)
with customer_purchase as (
select customer_id,sum(order_total) as total_purchase
from orders
group by customer_id)
, customer_returns as (
select customer_id,sum(refund_amount) as total_returms
from orders o
join order_items oi
using(order_id)
join returns r
using(order_item_id)
group by customer_id
)
select customer_id, cp.total_purchase,cr.total_returns,
round((total_returns/total_purchase)* 100,2)  as return_pct
from customer_purchase cp
join customers_returns cr
using(customer_id)
group by customer_id
having round((total_returns/total_purchase)* 100,2) > 25;

-- Insight 25 :  Calculate the no of Order placed but later cancelled along with total cancelled revenue
select count(order_id) as cancelled_orders,
sum(order_total) as cancelled_revenue
from orders
where order_status = "cancelled";

-- Insight 26 :  Find the no of Order Per customer distribution bucket (1,2-5,6-10, >10)
select customer_id,total_order,
case 
	when total_order = 1 then "1"
    when total_order between 2 and 5 then "2-5"
    when total_order between 6 and 10 then "6-10"
    else ">10" end as order_bucket
from (
select customer_id,count(order_id) as total_order
from orders 
group by customer_id
)t;

-- Insight 27: Find the Month wise Revenue Loss due to Returns
select date_format(order_datetime,"%Y-%m")  as month_year,
sum(refund_amount) as revenue_loss
from orders o
join orders_items oi
using(order_id)
join returns r
using(order_item_id)
group by date_format(order_datetime,"%Y-%m")
order by date_format(order_datetime,"%Y-%m");

-- Insight 28 :  Identify customers whose order value is increasing compared to thier previous purchase
with customer_order_analysis as (
select customer_id, order_datetime,order_total,
lag(order_total) over(partition by customer_id  order by order_datetime) as previous_order_value
from orders
order by customer_id)
select * 
from customer_order_analysis
where order_total > previous_order_value;

-- Insight 29: Find Repeat vs One-Time Customer Revenue Contribution
with customer_orders as (
select customer_id ,count(order_id) as total_orders
,sum(order_total) as total_revenue
from orders
group by customer_id
), customer_segmentation as 
(select *,
case
	when total_orders=1  then "One-time"
    when total_orders > 1 then "Repeat" end as customer_type
    from customer_orders
)  
select customer_type,sum(total_revenue) as revenue_contribution
from customer_segmentation
group by customer_type;

-- Insight 30:  Find the Peak Hours in a Day(Max Orders)
select hours(order_datetime) as order_hour,
count(order_id) as order_total
from orders
group by hour(order_datetime)
order by order_total desc;

-- Insight 31:
/* We perform this analysis in order to determine following business questions:
1. To run a flash sale  on website
2. To run marketing campaign 
2. To scale the traffic on server during the peak hours
*/

-- Insight 32:  Find the Month-Over-Month (MoM) Revenue Growth Rate
with monthly_revenue as (
select date_format(order_datetime,"%Y-%m") as month_year,
sum(order_total) as total_revenue
from orders
group by date_format(order_datetime,"%Y-%m")
order by month_year)
select *,
lag(total_revenue) over(order by month_year) as prev_month_revenue,
round((total_revenue - lag(total_revenue) over(order by month_year))/lag(total_revenue) over(order by month_year),2) * 1oo as mom_growth_pct
from monthly_revenue;

-- Insight 33:  Find the Customers Who stopped Ordering (Churn Detection- 150 Days window)
select customer_id,max(order_datetime) as last_order_date
from orders o
join customers c
on c.customer_id = o.custoner_id
group by customer_id
having max(order_datetime) < (select max(order_datetime) from orders) - interval 150 day;

-- Insight 34:  Find Brand Loyalty - (Customer buying the same brand repeatedly)
select o.customer_id , brand,
count(distinct o.order_id) as total_order
from products p
join order_items oi
on oi.product_id=p.product_id
join orders o
on o.order_id=oi.order_id
group by customer_id,brand
having count(distinct o.order_id) > 2;

-- Insight 35:  State- Wise Revenue vs Returns Comparison
with statewise_revenue as (
Select shipping_state,sum(order_total) as total_revenue
from orders
group by shipping_state
order by total_revenue desc
), state_return_revenue as (
select o.shipping_state,sum(r.refund_amount) as return_amount
from orders o
join order_items oi
on o.order_id=oi.order_id
join returns r
on oi.order_item_id=r.order_item_id
group by o.shipping_state
)
select sr.shipping_state,total_revenue,ifnull(return_amount,0) as refund_amount,
round(sum(return_amount/total_revenue) * 100,2) as return_pct
from statewise_revenue sr
join state_return_revenue srr
on sr.shipping_state=srr.shipping_state
group by sr.shipping_state
order by return_pct desc;

-- Insight 36:  Product sold consistently every month in the last 3 months
with products_sold_last_3_months as (
select p.product_id,p.product_name,date_format(order_datetime,"%Y-%m") as order_month
from products p
join order_items oi
on oi.product_id=p.product_id
join orders o
on o.order_id=oi.order_id
where order_datetime > (select max(order_datetime) from orders) - interval 3 month 
group by p.product_id,p.product_name,date_format(order_datetime,"%Y-%m"))
select product_id,product_name,count(order_month) as order_per_month
from products_sold_last_3_months 
group by product_id,product_name
having count(order_month) >= 3;

-- Insight 37:  Find the Products having high avg discount pct (> 10%) and quantity sold is less than avg sold quantity.
with product_sales as (
select p.product_id,product_name,sum(quantity) as total_quantity,
round(avg((oi.discount/oi.unit_price)* 100),2) as avg_discount_pct
from products p
join order_items oi
on p.product_id=oi.product_id
group by p.product_id,product_name
order by avg_discount_pct desc
)
select *
from product_sales
where avg_discount_pct > 10 and 
total_quantity < (select avg(total_quantity) from product_sales);
-- With this insights a company will be able to segregate those under performing  products where disouct pct is higher than 10% and along with very less amount of sales.

-- Insight 38:  Order fulfilment efficiency by each city
select shipping_city,count(order_id) as total_order,
sum(case when order_status="Delivered" then 1 else 0 end) as delivered_order,
round(sum(case when order_status="Delivered" then 1 else 0 end)/count(order_id)* 100,2) as fulfilment_efficiency_pct
from orders
group by shipping_city;

-- Insight 39:  Return Reason Analysis impacting revenue
select reason,count(return_id) as total_return,
sum(refund_amount) as total_refund_amount,
round(sum(refund_amount)/(select sum(order_total) from orders) * 100,2)  as revenue_impact_pct
from returns
group by reason
order by revenue_impact_pct desc;

-- Insight 40:  Identify the first product purchase by each customer
with first_purchase as (
select 
	c.customer_id,
	first_name,
	order_datetime,
	p.product_id,
	product_name,
    row_number() over(partition by customer_id order by order_datetime) as rnk
from customers c
join orders o
on c.customer_id = o.customer_id
join order_items oi
on oi.order_id=o.order_id
join products p
on oi.product_id=p.product_id
)
select customer_id,product_name,date(order_datetime)
from first_purchase
where rnk = 1;

-- Insight 41:  Find the order details where only one distinct product was purchased
select order_id
from (
select order_id,count(p.product_id) as product_count
from order_items oi
join products p
using (product_id)
group by order_id
having count(distinct p.product_id)=1
)t 
where t.product_count=1;

-- Insight 42: Identify customers who placed orders on two consecutive days
select * 
from (
select
	customer_id,
    order_datetime as curr_order_date,
	lag(order_datetime) over(partition by customer_id order by order_datetime) as prev_order_date
from orders
) t
where datediff(curr_order_date,prev_order_date) = 1;

-- Insight 43:  Find State Wise Total orders and  Total Revenue Generated
Select shipping_state,
count(order_id) as total_orders,
sum(order_total) as total_revenue
from orders
group by shipping_state
order by total_orders desc,total_revenue desc;

-- Insight 44:  Find Funnel Analysis (Customer -> Order -> Return)
select
(select count(customer_id)  from customers) as total_customers,
(select count(distinct customer_id)  from orders) as total_ordered_customers,
(select count(distinct o.customer_id) 
from returns r
join order_items oi
on oi.order_item_id = r.order_item_id
join orders o
on o.order_id = oi.order_id) as customer_with_returns;

-- Insight 45: Find city wise total Orders or Total Revenue Generated
select shipping_city,count(order_id) as total_order,
sum(order_total) as total_revenue
from orders
group by shipping_city
order by total_order;

-- Insight 46: Generate the state-wise breakdown of orders by different order_status
-- along with total orders

select distinct shipping_state,
sum(case when order_status = "Placed" then 1 else 0 end) as "placed_orders" ,
sum(case when order_status = "Confirmed" then 1 else 0 end )  as "Confirmed_orders",
sum(case when order_status = "Shipped" then 1 else 0 end )  as "Shipped_orders",
sum(case when order_status = "Delivered" then 1 else 0 end )  as "Delivered_orders",
sum(case when order_status = "RETURN_REQUESTED" then 1 else 0 end )  as "Return_requested"
from orders;

-- Insight 47:  Total registered customers vs customers who placed atleast one order 
select count(distinct c.customer_id) as total_registered_customers,
count(distinct o.customer_id) as customer_with_order
from customers c
left join orders o
using (customer_id);

-- Insight 48:  Identify Products where sell_price varies significantly across  orders.(Price Anomalies across Product)
select p.product_id,product_name,
max(sell_price) - min(sell_price) as price_variation
from products p
join order_items oi
on p.product_id=  oi.product_id
group by p.product_id,product_name
having max(sell_price) - min(sell_price) > 1000;

-- Insight 49:  Identify the Products  that are sold in high quantity (> 25)
-- but contribute low revenue (< 5000) 

select p.product_id,
	sum(quantity) as total_quantity,
	sum(line_total) as total_revenue
from order_items oi
join products p 
on p.product_id=oi.product_id
group by p.product_id
having sum(quantity) > 25
and sum(line_total) < 5000;

-- Insight 50:  Identify cities where refund per unit sold is highest
select shipping_city,
round(sum(refund_amount)/sum(quantity),2) as refund_per_unit
from orders o
join order_items oi
on o.order_id=oi.order_id
join returns r
on oi.order_item_id=r.order_item_id
group by shipping_city
order by refund_per_unit desc;

-- Insight 51:  Find the products that were sold but never returned
select count(*) as product_count_without_returns
from (
	select p.product_id,product_name,oi.order_item_id,return_id
	from products p
	join order_items oi
	on p.product_id=oi.product_id
	left join returns r
	on oi.order_item_id=r.order_item_id
	where return_id is null	
) t;

-- Insight 52:  Find orders where a single product contributes more than 50% of total order value
select o.order_id,order_item_id,product_id,line_total, order_total
from orders o
join order_items oi
on o.order_id=oi.order_id
where line_total > 0.5 * order_total
and line_total != order_total;

/* Insight 53: Classify customers based on their ordering frequency (in days)
	(Slow>=91 / Medium>= 31 & <=90 / Fast<=30)
*/
with order_date_analysis as (
select customer_id ,order_datetime,
lag(order_datetime) over(partition by customer_id order by order_datetime)
as previous_date,
datediff(order_datetime,lag(order_datetime) over(partition by customer_id order by order_datetime)) as gap_days
from orders)
select customer_id,
case when avg(gap_days) <= 30 then "Fast"
	when avg(gap_days) >= 31 and avg(gap_days) <= 90 then "Medium"
    else "Slow" end as order_date_frequency
from order_date_analysis
group by customer_id;
