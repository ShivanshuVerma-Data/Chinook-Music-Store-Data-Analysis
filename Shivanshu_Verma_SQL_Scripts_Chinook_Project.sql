-- Queries for objective questions : 

-- QUESTION 1  
-- To find count of nulls in the columns of a table 
 
select 
    sum(case when customer_id is null then 1 else 0 end) as column1_nulls,
    sum(case when first_name is null then 1 else 0 end) as column2_nulls,
    sum(case when last_name is null then 1 else 0 end) as column3_nulls,
    sum(case when company is null then 1 else 0 end) as column4_nulls,
    sum(case when address is null then 1 else 0 end) as column5_nulls,
    sum(case when city is null then 1 else 0 end) as column6_nulls,
    sum(case when state is null then 1 else 0 end) as column7_nulls,
    sum(case when country is null then 1 else 0 end) as column8_nulls,
    sum(case when postal_code is null then 1 else 0 end) as column9_nulls,
    sum(case when phone is null then 1 else 0 end) as column10_nulls,
    sum(case when fax is null then 1 else 0 end) as column11_nulls,
    sum(case when email is null then 1 else 0 end) as column12_nulls,
    sum(case when support_rep_id is null then 1 else 0 end) as column13_nulls
from customer;

-- To replace the NULL 

update customer  
set last_name = coalesce(last_name, 'Not Available'),  
    state = coalesce(state, 'Not Available'),  
    postal_code = coalesce(postal_code, 'N/A'),
    phone = coalesce(phone, 'Not Available'),  
    fax = coalesce(fax, 'Not Available')  
where last_name is null or state is null or postal_code is null  
or phone is null or fax is null;

-- To find the DUPLICATES 

select first_name, last_name, company, city, state, country, postal_code, 
phone, fax, email, support_rep_id,  count(*) as count
from customer 
group by first_name, last_name, company, city, state, country, postal_code, phone, fax, email, support_rep_id
having count(*) > 1;

-- To remove the DUPLICATES 

with remove_duplicates as 
(select customer_id, 
 row_number() over (partition by first_name, last_name, company, city, state, country, postal_code, phone, fax, email, support_rep_id 
order by customer_id) as row_num
from customer)

delete from customer 
where customer_id in (select customer_id from remove_duplicates 
 where row_num > 1);
 
-- QUESTION 2 

-- Top Selling Tracks and Artists in USA 

with top_in_USA as 
(select l.track_id, i.billing_country, t.name as track_title,
a.title as album_title, art.name as artist_name, g.name as genre_name
from invoice i 
join invoice_line l 
on i.invoice_id = l.invoice_id 
join track t 
on l.track_id = t.track_id
join album a 
on t.album_id = a.album_id
join artist art 
on a.artist_id = art.artist_id
join genre g 
on t.genre_id = g.genre_id
where billing_country = 'USA')

select track_id, track_title, artist_name, genre_name, count(*) as top_count from top_in_USA 
group by track_id, track_title, artist_name, genre_name
order by top_count desc
limit 3;

-- QUESTION 3 

-- Customer Demographic breakdown 
-- Country wise 
  
select country, count(*) as cust_count
from customer
group by country
order by count(*) desc;

-- Country, State and City combined 
 
SELECT country, state, city, count(*) as cust_count
from customer
group by country, state, city
order by count(*) desc, country, state;

-- QUESTION 4 
-- Total Invoice and Revenue Country wise 

select billing_country, sum(total) as total_revenue, 
count(*) as total_invoice 
from invoice 
group by billing_country
order by total_revenue desc, total_invoice desc;

-- Total Invoice and Revenue State wise

select billing_state, sum(total) as total_revenue, 
count(*) as total_invoice 
from invoice 
group by billing_state
order by total_revenue desc, total_invoice desc;

-- Total Invoice and Revenue City wise

select billing_city, sum(total) as total_revenue, 
count(*) as total_invoice 
from invoice 
group by billing_city
order by total_revenue desc, total_invoice desc;

-- Comdined 

select billing_country, billing_state, billing_city, 
sum(total) as total_revenue, count(*) as total_invoice 
from invoice 
group by billing_country, billing_state, billing_city
order by total_revenue desc, total_invoice desc;

-- QUESTION 5 
-- Top 5 customers in each country by total revenue 

with top5_cust as 
(select i.customer_id as cust_id, 
concat(c.first_name, ' ', c.last_name) as name, 
i.billing_country as country, sum(total) as total_revenue,
dense_rank() over (partition by i.billing_country order by sum(total) desc) as ranking
from invoice i 
join customer c 
on i.customer_id = c.customer_id
group by i.customer_id, name, I.billing_country
order by country, total_revenue desc)

select cust_id, name, country, total_revenue from top5_cust 
where ranking <= 5;

-- QUESTION 6 
-- Top Selling Tracks for each Customer


with tracksales as 
(select c.customer_id, concat(c.first_name,' ', c.last_name) as name,
il.track_id, t.name as track_name,
count(il.track_id) as purchase_count,
row_number() over 
(partition by c.customer_id order by count(il.track_id) desc, t.name asc) 
as rank_order
from customer c
join invoice i 
on c.customer_id = i.customer_id
join invoice_line il 
on i.invoice_id = il.invoice_id
join track t 
on il.track_id = t.track_id
group by c.customer_id, c.first_name, c.last_name, il.track_id, t.name)

select customer_id, name, track_id, track_name, purchase_count
from tracksales
where rank_order = 1
order by purchase_count desc;

-- QUESTION 7
-- CUSTOMER PURCHASE BEHAVIOUR 
-- Total orders and Avg purchase Days per Customer 

with purchase_gaps as 
(select customer_id, invoice_date, 
lead(invoice_date) over (partition by customer_id order by invoice_date) as next_purchase_date
from invoice)

select customer_id, count(invoice_date) as total_purchases, 
round(avg(datediff(next_purchase_date, invoice_date)), 2) as avg_days_between_purchase_
from purchase_gaps
group by customer_id
order by total_purchases desc;

--  Avg Order Value per Customer 

select customer_id, 
round(avg(total), 2) as avg_order_value, 
sum(total) as total_spent, 
count(invoice_id) as total_orders
from invoice
group by customer_id
order by avg_order_value desc;

--  QUESTION 8 
-- Customer Churn Rate by Month 

with monthly_active_customers as 
(select date_format(str_to_date(invoice_date, '%Y-%m-%d'), '%Y-%m') as month_year, count(distinct customer_id) as active_customers
from invoice
group by month_year),
	
churn_analysis as 
(select month_year, active_customers, 
lag(active_customers) over (order by month_year) as prev_month_customers,
lag(active_customers) over (order by month_year) - active_customers as churned_customers
from monthly_active_customers)

select month_year, active_customers, prev_month_customers,
case 
when churned_customers > 0 then concat('+', round((churned_customers / prev_month_customers) * 100, 2), '%')
else concat(round((churned_customers / prev_month_customers) * 100, 2), '%')
end as churn_rate
from churn_analysis
order by month_year;

-- QUESTION 9 
-- Total Sales for each Artist in USA 

with artist_sales as 
(select g.name as genre_name, ar.name as artist_name, 
sum(i.total) as total_sales
from invoice i 
join invoice_line il 
on i.invoice_id = il.invoice_id 
join track t 
on il.track_id = t.track_id 
join album al 
on t.album_id = al.album_id 
join artist ar 
on al.artist_id = ar.artist_id 
join genre g 
on t.genre_id = g.genre_id
where i.billing_country = 'USA'
group by genre_name, artist_name),

total_sales as 
(select sum(total_sales) as usa_total_sales from artist_sales)

select ars.artist_name, ars.total_sales, 
concat(round((ars.total_sales / ts.usa_total_sales) * 100, 2),'%') as sales_contribution
from artist_sales ars 
join total_sales ts
order by ars.total_sales desc;

--  Sales contribution by Genre in USA 

 with genre_sales as 
(select g.name as genre_name, sum(i.total) as total_sales
from invoice i 
join invoice_line il 
on i.invoice_id = il.invoice_id 
join track t 
on il.track_id = t.track_id 
join genre g 
on t.genre_id = g.genre_id
where i.billing_country = 'USA'
group by genre_name),

total_sales as 
(select sum(total_sales) as usa_total_sales from genre_sales)

select gs.genre_name, gs.total_sales, 
concat(round((gs.total_sales / ts.usa_total_sales) * 100, 2),'%') as sales_contribution
from genre_sales gs 
join total_sales ts
order by total_sales desc, sales_contribution desc;

-- QUESTION 10 
-- Customers who have purchased tracks from at least 3 different genres

with customer_genre_count as 
(select i.customer_id, count(distinct g.genre_id) as genre_count
from invoice i 
join invoice_line il 
on i.invoice_id = il.invoice_id 
join track t 
on il.track_id = t.track_id 
join genre g 
on t.genre_id = g.genre_id
group by i.customer_id)

select customer_id, genre_count
from customer_genre_count
where genre_count >= 3
order by genre_count desc, customer_id;

-- QUESTION 11 
-- Genres ranking based on total sales in the USA

select g.genre_id, g.name as genre_name, sum(i.total) as total_sales,
rank() over (order by sum(i.total) desc) as genre_rank
from genre g 
join track t
on g.genre_id = t.genre_id 
join invoice_line il 
on t.track_id = il.track_id 
join invoice i 
on il.invoice_id = i.invoice_id
where i.billing_country = 'USA' 
group by g.genre_id, g.name;

-- SUBJECTIVE QUESTIONS : 

-- QQUESTION 1 
-- Albums for advertising and promotion in the USA based on genre sales 

with genre_sales as 
	(select g.genre_id, g.name as genre_name, sum(i.total) as total_sales
 from genre g
 join track t on g.genre_id = t.genre_id
 join invoice_line il on t.track_id = il.track_id
 join invoice i on il.invoice_id = i.invoice_id
 where i.billing_country = 'USA'
 group by g.genre_id, g.name
 order by total_sales desc
 limit 3), 

top_albums as 
	(select al.album_id, al.title as album_name, g.name as genre_name, 
sum(il.unit_price * il.quantity) as album_sales
    	from track t
    	join album al 
on t.album_id = al.album_id
    	join genre g 
on t.genre_id = g.genre_id
    	join invoice_line il 
on t.track_id = il.track_id
    	join invoice i 
on il.invoice_id = i.invoice_id
    	where i.billing_country = 'USA' 
    	and g.genre_id in (select genre_id from genre_sales)
    	group by al.album_id, al.title, g.name
    	order by album_sales desc)
select * from top_albums;

-- QUESTION 2 
-- Top-selling genres in countries other than the USA

with top_genres as 
(select i.billing_country, g.genre_id, g.name as genre_name, sum(i.total) as total_sales,
rank() over (partition by i.billing_country order by sum(i.total) desc) as genre_rank
from invoice i
join invoice_line il 
on i.invoice_id = il.invoice_id
join track t 
on il.track_id = t.track_id
join genre g 
on t.genre_id = g.genre_id
where i.billing_country <> 'USA'
group by i.billing_country, g.genre_id, g.name)

select * from top_genres 
where genre_rank <= 3;

-- QUESTION 3 
-- Customer Purchasing Behavior Analysis

with customer_purchase_stats as 
	(select i.customer_id, 
	min(i.invoice_date) as first_purchase_date,
	count(distinct i.invoice_id) as total_orders, 
	sum(i.total) as total_revenue,
	avg(i.total) as avg_order_value
	from invoice i
	group by i.customer_id),

customer_type as 
	(select cps.customer_id, cps.total_orders, cps.total_revenue,
cps.avg_order_value,
   	 round(datediff((select max(invoice_date) from invoice),
cps.first_purchase_date) / 365, 2) as tenure_years,
	case 
		when round(datediff((select max(invoice_date) from invoice), 
cps.first_purchase_date) / 365, 2) > 1 				and cps.total_orders > (select avg(total_orders) from
 customer_purchase_stats) 
		then 'Long-Term Customer' 
		else 'New Customer' 
	end as customer_category
	from customer_purchase_stats cps)

select customer_category, 
round(avg(total_orders), 2) as avg_orders_per_customer, 
round(avg(total_revenue), 2) as avg_total_revenue_per_customer, 
round(avg(avg_order_value), 2) as avg_order_value, 
round(avg(tenure_years), 2) as avg_tenure_years
from customer_type
group by customer_category;

-- QUESTION 4 
-- Product Affinity Analysis

with purchase_pairs as 
	(select il1.invoice_id,  
	 t1.genre_id as genre_1, t2.genre_id as genre_2,  
	 al1.artist_id as artist_1, al2.artist_id as artist_2,  
 al1.album_id as album_1, al2.album_id as album_2  
 from invoice_line il1  
    join invoice_line il2  
    on il1.invoice_id = il2.invoice_id and il1.track_id < il2.track_id  
    join track t1 
    on il1.track_id = t1.track_id  
    join track t2 
    on il2.track_id = t2.track_id  
    join album al1 
    on t1.album_id = al1.album_id  
    join album al2 
    on t2.album_id = al2.album_id  
    where al1.album_id != al2.album_id),  
  
paired_purchases as 
	(select genre_1, genre_2, artist_1, artist_2, album_1, album_2,  
	count(*) as times_purchased_together  
   	from purchase_pairs  
  	group by genre_1, genre_2, artist_1, artist_2, album_1, album_2)  
  
select g1.name as genre_1, g2.name as genre_2,  
a1.name as artist_1, a2.name as artist_2,  
al1.title as album_1, al2.title as album_2,  
times_purchased_together  
from paired_purchases pp  
join genre g1 
on pp.genre_1 = g1.genre_id  
join genre g2 
on pp.genre_2 = g2.genre_id  
join artist a1 
on pp.artist_1 = a1.artist_id  
join artist a2 
on pp.artist_2 = a2.artist_id  
join album al1 
on pp.album_1 = al1.album_id  
join album al2 
on pp.album_2 = al2.album_id  
order by times_purchased_together desc;

-- QUESTION 5 
-- Regional Market Analysis

with monthly_active as 
	(select customer_id, billing_country, 
	date_format(invoice_date, '%Y-%m') as purchase_month
    	from invoice
    	group by customer_id, billing_country, purchase_month),
    
customer_counts as 
	(select billing_country, purchase_month, 
	count(distinct customer_id) as active_customers
  	from monthly_active
    	group by billing_country, purchase_month),

churn_analysis as 
	(select billing_country, purchase_month, active_customers,
	lag(active_customers) over (partition by billing_country order by 
purchase_month) as prev_month_customers
  	 from customer_counts)
    
select billing_country, purchase_month, 
       sum(active_customers) as total_active_customers, 
       sum(case when prev_month_customers is null then 0 
                else prev_month_customers - active_customers 
          	   end) as total_churned_customers,
       concat(case when sum(prev_month_customers - active_customers) > 0 
then '+' else '' end,
           round((sum(prev_month_customers - active_customers) * 100.0 / 
nullif(sum(prev_month_customers), 0)), 
           2),' %') as churn_rate
from churn_analysis
group by billing_country, purchase_month
order by purchase_month asc, billing_country asc;

-- QUESTION 6 
-- Customer Risk Profiling 

with customer_spending as 
    (select c.customer_id, c.country, 
    date_format(i.invoice_date, '%Y-%m-01') as purchase_month, 
    count(distinct i.invoice_id) as purchase_count, 
    sum(i.total) as total_spent  
    from customer c  
    join invoice i on c.customer_id = i.customer_id  
    group by c.customer_id, c.country, purchase_month),  

purchase_intervals as 
    (select customer_id, invoice_date, 
    lag(invoice_date) over (partition by customer_id order by invoice_date) as 
    prev_purchase_date  
    from invoice),  

customer_avg_purchase as 
    (select customer_id, 
     round(avg(datediff(invoice_date, prev_purchase_date)), 2) as 
     avg_purchase_days  
     from purchase_intervals  
     where prev_purchase_date is not null  
     group by customer_id),   

spending_with_lag as 
    (select cs.*, cap.avg_purchase_days,  
    lag(cs.total_spent) over (partition by cs.customer_id order by 
cs.purchase_month) as prev_month_spent  
    from customer_spending cs  
    left join customer_avg_purchase cap 
    on cs.customer_id = cap.customer_id),  

spending_risk as 
    (select customer_id, country, purchase_month, purchase_count, total_spent,
     avg_purchase_days, prev_month_spent,
     case  
        when total_spent < prev_month_spent then 'High Risk'  
        when total_spent = prev_month_spent then 'Moderate Risk'  
        else 'Low Risk'  
     end as risk_category  
     from spending_with_lag)  

select country, purchase_month, risk_category, 
count(customer_id) as customer_count, 
round(avg(purchase_count), 2) as avg_purchases, 
round(avg(total_spent), 2) as avg_spent, 
round(avg(avg_purchase_days), 2) as avg_purchase_days  
from spending_risk  
group by purchase_month, risk_category, country  
order by purchase_month asc, risk_category asc;

-- QUESTION 7 
--  Customer Lifetime Value Modeling

with data_boundaries as 
 (select max(invoice_date) as latest_date from invoice),  

customer_spending as 
    (select c.customer_id, c.country, 
	sum(i.total) as total_spend, 
	count(i.invoice_id) as total_orders, 
	avg(i.total) as avg_order_value, 
	min(i.invoice_date) as first_order_date, 
	max(i.invoice_date) as last_order_date,
	timestampdiff(month, min(i.invoice_date), 
	(select latest_date from data_boundaries)) as tenure_months  
    from customer c  
    join invoice i 
    on c.customer_id = i.customer_id  
    group by c.customer_id, c.country),  

customer_churn as 
    (select customer_id, country, 
	lag(last_order_date) over (partition by customer_id order by last_order_date) as prev_order_date,
    last_order_date  
    from customer_spending),  

churn_analysis as 
    (select country, 
    count(case when datediff((select latest_date from data_boundaries), last_order_date) > 180  
    then customer_id end) as churned_customers, 
    count(customer_id) as total_customers,
	round(avg(tenure_months),1) as avg_tenure,
	round(avg(total_spend),2) as avg_lifetime_spend  
    from customer_spending  
    group by country),  

clv_estimation as 
    (select country, 
	avg_lifetime_spend / nullif((churned_customers / total_customers),0) as estimated_clv  
    from churn_analysis)  

select c.country, c.total_customers, 
c.churned_customers, c.avg_tenure, c.avg_lifetime_spend, 
round(100 * c.churned_customers / nullif(c.total_customers,0),2) as churn_rate,
round(e.estimated_clv,2) as estimated_clv  
from churn_analysis c  
left join clv_estimation e 
on c.country = e.country  
order by estimated_clv desc;

-- QUESTION 9 
-- A new column named "ReleaseYear" of type INTEGER

alter table album
add column ReleaseYear integer;

describe album;

-- QUESTION 11 
-- Average total amount spent by customers from each country, 
-- along with the number of customers and the average number of 
-- tracks purchased per customer


with CountryStats as 
    (select i.billing_country as country,  
    count(distinct i.customer_id) as customer_count,  
    sum(i.total) as total_amount_spent,  
    sum(il.quantity) as total_tracks_purchased  
    from invoice i  
    join invoice_line il  
    on i.invoice_id = il.invoice_id  
    group by i.billing_country),  

FinalStats as 
    (select country,  
    customer_count,  
    round(total_amount_spent / customer_count, 2) as avg_total_spending,  
    round(total_tracks_purchased / customer_count, 2) as 
    avg_tracks_purchased 
    from CountryStats)  

select * from FinalStats  
order by country, avg_total_spending desc;


