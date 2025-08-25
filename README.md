Uber Rides Data Analysis using SQL

![]()
 
## Overview

This project delivers an end-to-end analysis of Uber ride data using SQL. The primary aim is to explore business-critical questions around cancellations, operational efficiency, customer experience, pricing, and demand-supply balance. The queries are designed to replicate the challenges a Business Analyst would face in real-world ride-hailing platforms and demonstrate how SQL can be used to generate actionable insights.
## Objectives

•	Investigate cancellation behaviors by vehicle type, customer vs. driver, and time of day.
•	Measure the operational efficiency of Uber’s fleet through utilization and delay analysis.
•	Explore customer experience drivers such as loyalty, payment methods, and ratings.
•	Quantify the revenue impact of cancellations and profitability differences across vehicle types.
•	Detect demand hotspots and forecast peak times for optimal driver allocation.
## Dataset  Details

The Uber dataset consists of ride-level information with the following attributes:
•	Date: Date of the booking.
•	Time: Time of the booking.
•	Booking ID: Unique identifier for each ride booking.
•	Booking Status: Status of booking (Completed, Cancelled by Customer, Cancelled by Driver, Incomplete, etc.).
•	Customer ID: Unique identifier for customers.
•	Vehicle Type: Type of vehicle (Go Mini, Go Sedan, Auto, eBike/Bike, UberXL, Premier Sedan).
•	Pickup Location: Starting location of the ride.
•	Drop Location: Destination location of the ride.
•	Avg VTAT: Average Vehicle Time at Arrival (driver wait time to reach customer).
•	Avg CTAT: Average Customer Time at Arrival (customer wait time to reach pickup point).
•	Cancelled Rides by Customer: Flag for customer-initiated cancellations.
•	Reason for Cancelling by Customer: Text reason provided by customer for cancellation.
•	Cancelled Rides by Driver: Flag for driver-initiated cancellations.
•	Driver Cancellation Reason: Text reason provided by driver for cancellation.
•	Incomplete Rides: Flag for incomplete rides.
•	Incomplete Rides Reason: Text reason for incomplete rides.
•	Booking Value: Total fare amount for the ride.
•	Ride Distance: Distance covered during the ride (in kilometers).
•	Driver Ratings: Rating given to the driver (1–5 scale).
•	Customer Rating: Rating given by the customer (1–5 scale).
•	Payment Method: Method of payment (UPI, Cash, Credit Card, Uber Wallet, Debit Card).

## Schema
CREATE TABLE uber (
    trip_id SERIAL PRIMARY KEY,
    vehicle_type VARCHAR(50),
    booking_time TIMESTAMP,
    booking_value NUMERIC,
    ride_distance NUMERIC,
    pickup_location VARCHAR(100),
    cancelled_by_customer BOOLEAN,
    cancelled_by_driver BOOLEAN,
    customer_cancel_reason TEXT,
    driver_cancel_reason TEXT,
    driver_rating NUMERIC,
    payment_method VARCHAR(50),
    booking_status VARCHAR(50)
);

Dataset originally sourced from Kaggle (Uber Rides Dataset). The original link is no longer available, so the cleaned dataset used in this project is provided directly in this repository for reproducibility.
link:

## Business Problems and Solutions


      **Cancellations & Reliability**
      
### 1.	Cancellation rate by vehicle type
Which vehicle types see the highest cancellations?


```sql
with t1 as (
Select
vehicle_type,
cancelled_by_customer,customer_cancel_reason,
cancelled_by_driver,driver_cancel_reason,
count(*) over(partition by vehicle_type) as total_rides_per_vehicle,
Round(((Count(case when cancelled_by_customer IS TRUE OR cancelled_by_driver IS TRUE then 1 
end)over(partition by vehicle_type)::numeric/count(*) over(partition by vehicle_type)::numeric)*100),3)
As ride_cancellation_percentage_per_vehicle_type
from uber
)

, t2 as(
Select vehicle_type,
total_rides_per_vehicle,
CASE  
WHEN customer_cancel_reason IS NOT NULL then customer_cancel_reason
ELSE driver_cancel_reason 
END AS cancellation_reason,
Count(*) AS ride_cancellation_count,
ride_cancellation_percentage_per_vehicle_type
From t1
Where cancelled_by_customer IS TRUE OR cancelled_by_driver IS TRUE
Group by vehicle_type,total_rides_per_vehicle,cancellation_reason,ride_cancellation_percentage_per_vehicle_type
Order by vehicle_type DESC,ride_cancellation_count DESC
)


  SELECT vehicle_type,total_rides_per_vehicle,cancellation_reason,ride_cancellation_count,
ride_cancellation_percentage_per_vehicle_type
FROM (
    SELECT t2.*,
           ROW_NUMBER() OVER (
               PARTITION BY vehicle_type 
               ORDER BY ride_cancellation_count DESC
           ) AS rn
    FROM t2
) ranked
WHERE rn = 1
order by ride_cancellation_percentage_per_vehicle_type desc;


```

**Objective**: SQL aggregates cancellations vs. total rides per vehicle type, highlighting which segments (e.g., Auto, Go Mini) are most prone to cancellation.

### 2. Peak-time cancellation behavior
When do customers cancel most vs. drivers?

```sql
  With t1 as(

Select
Extract (hour from booking_time) As  booking_time_hour,
Case 
WHEN cancelled_by_driver Is true then 'Driver'
ELSE 'Customer'
END AS cancelled_by,
Count(*) AS ride_cancellation_count 
From uber
where cancelled_by_driver is true or  cancelled_by_customer is true
 group by cancelled_by , booking_time_hour 

)

SELECT  booking_time_hour ,cancelled_by,ride_cancellation_count  
from (
Select *
, Dense_rank()over (partition by t1.cancelled_by order by t1.ride_cancellation_count desc ) AS rk
from t1) ranked
where rk=1;
```
 
**Objective**: By extracting booking hours, we identify peak cancellation windows for supply-demand mismatches.
### 3. Cancellation reason clustering
Why are rides cancelled?

```sql
Select 
CASE 
When cancelled_by_customer Is true then 'customer'
ELSE 'driver'
END AS cancelled_by,

CASE 
When cancelled_by_customer Is true then customer_cancel_reason
ELSE driver_cancel_reason
END AS cancellation_reason,

Count (*) As ride_cancellation_count
From uber
where cancelled_by_customer  is true or 
 cancelled_by_driver  is true
Group by cancelled_by,cancellation_reason ;
```

**Objective**: Grouping textual reasons (driver delay, price complaint, wrong pickup) into clusters surfaces common pain points.

### 4. Impact of VTAT & CTAT on cancellations
Do wait times drive cancellations?

```sql
SELECT 
'Cancelled/Incomplete' AS ride_status,
AVG(avg_vtat)::Numeric(4,2) AS avg_vtat ,avg(avg_ctat)::Numeric(4,2) as avg_ctat,
Count(*) AS no_of_rides
from uber
WHERE cancelled_by_customer  is true or 
 cancelled_by_driver  is true or incomplete is true
 
 Union
 
SELECT 
'Completed' AS ride_status,
AVG(avg_vtat)::Numeric(4,2) AS avg_vtat ,avg(avg_ctat)::Numeric(4,2) as avg_ctat,
COunt(*) AS no_of_rides
from uber
WHERE (cancelled_by_customer  is not true and
 cancelled_by_driver  is not true) and incomplete is not true
 ```


**Objective**: Statistical correlation (avg wait vs. cancellation likelihood) reveals how delays affect reliability.
      **Operational Efficiency**
   
### 5. Avg VTAT & CTAT by location
Which pickup zones cause chronic delays?


```sql
SELEct pickup_location,AVG(avg_vtat) as Avg_VTAT,AVG(avg_ctat) as Avg_CTAT
From uber
group by pickup_location
order by Avg_VTAT desc,Avg_CTAT desc;
```



**Objective**: Geo-level analysis identifies systemic bottlenecks for better driver routing.
### 6. Vehicle utilization analysis
What proportion of rides are wasted?


```sql

With t1 as(
Select vehicle_type,
Count ( case when cancelled_by_customer is true Or cancelled_by_driver is true or incomplete  is true then 1 else null end )
AS "incomplete_cancelled_rides_per_vehicle",
Count (*) AS "total_rides_per_vehicle"
From uber
Group by vehicle_type
)

Select t1.*,
Round(((t1.incomplete_cancelled_rides_per_vehicle::numeric/t1.total_rides_per_vehicle::numeric)
*100),4) AS wasted_vehicle_capacity_percent
From t1;

```



**Objective**:Cancelled/incomplete rides per vehicle type highlight unused fleet capacity.

Customer Experience & Retention
### 7. Driver rating impact on cancellations
Are low-rated drivers more likely to be cancelled?


```sql

with t1 as(
Select vehicle_type,
case when driver_rating > 3.5 then '>3.5'
 when driver_rating > 3.0 then '>3.0'
 when driver_rating > 2.0 then '>2.5'
 when driver_rating > 1.5 then '>1.5'
 else '>=0.0'
end as driver_rating_bucket,
Sum (case when cancelled_by_customer is true then 1 else 0 end) 
AS no_of_rides_cancelled_by_customer
,Count (*) AS total_no_of_rides
from uber
group by vehicle_type,driver_rating_bucket
)

select *,
Round(((no_of_rides_cancelled_by_customer::numeric/total_no_of_rides::numeric)*100),3) as cancellation_percent
from t1
order by vehicle_type, cancellation_percent desc;

```




**Objective**:Bucket analysis of ratings shows cancellation trends tied to driver quality.
### 8. Customer loyalty vs. payment method
Do wallet/credit card users show higher completion rates vs. cash?

```sql

Select *,((incomp_rides::numeric/total_rides::numeric)*100) as cancellation_percent
from(
select 
case 
when payment_method is not null then payment_method
else 'other'
end as payment_method,
count(*) AS total_rides,
Sum(case when incomplete is true then 1 else 0 end) As incomp_rides,
Sum(case when incomplete is not true then 1 else 0 end) As comp_rides

from uber
group by 1) t1
order by cancellation_percent desc;

```


**Objective**:Comparing completion percentages reveals friction with cash-based rides.

### 9. Excessive cancellations by vehicle type
Which vehicles hurt efficiency the most?

```sql

Select *,((cancelled_rides::numeric/total_rides::numeric)*100) as cancellation_per
from(
select  vehicle_type,
count(*) AS total_rides,
Sum(case when cancelled_by_customer is true then 1 else 0 end) As cancelled_rides,
Sum(case when cancelled_by_customer is not true then 1 else 0 end) As comp_rides
from uber
group by 1) t1
order by cancellation_per desc;

```


**Objective**:Cancellation-heavy vehicle types are flagged as high-risk for operations.

      **Revenue & Pricing**
### 10. Revenue leakage due to cancellations
How much money is lost from cancelled bookings?

```sql

select
Sum(case when cancelled_by_driver is true then booking_value else 0  end ) As lost_revenue_for_driver_cancellations,
Sum(case when cancelled_by_customer is true then booking_value else 0 end ) As lost_revenue_for_customer_cancellations
from uber
where booking_value is not null;

```

**Objective**:Summing cancelled ride values quantifies direct revenue impact.
### 11. Profitability by vehicle type
Which vehicle types generate more value per km?


```sql

Select vehicle_type,avg(booking_value) as avg_ride_value
,avg(ride_distance)as avg_ride_distance,
 ROUND(AVG(booking_value) / coalesce(AVG(ride_distance), 0), 2) AS value_per_distance

from uber
group by 1
order by avg_ride_value desc,avg_ride_distance desc;
```

**Objective**:Comparisons of booking value vs. distance clarify margin-rich categories.
### 12. Payment method profitability
Which payment options yield higher fares?


```sql
select payment_method,Round (avg(booking_value ),3) as avg_booking_value
from uber
where booking_value is not null
group by 1
order by avg_booking_value desc ;

```


**Objective**:Averages show if card/wallet rides correlate with higher revenues.

      **Demand & Supply Analysis**
      
### 13. Temporal demand forecasting
When is demand highest?


```sql

Select 
extract (hour from booking_time ) As booking_time_hour,
count(*) as no_of_rides
from uber
group by 1
order by no_of_rides desc;
```



**Objective**:Ride counts grouped by hour/day reveal high-demand periods for driver supply planning.
### 14. Hotspot detection
Which pickup zones need more drivers?

```sql

select *,Round(((incomplete_bcz_no_driver_found::numeric/no_of_rides_booked::numeric)*100),3) as incomplete_rides_per

from (
select pickup_location,count(*) As no_of_rides_booked,
count(case when booking_status ilike 'no driver found' then 1  end ) 
as incomplete_bcz_no_driver_found

from uber
group by 1
order by incomplete_bcz_no_driver_found desc
)t1;

```

**Objective**:High bookings + high cancellations highlight underserved areas.
### 15. Incomplete rides by geography
Where do rides fail to complete?

```sql
select pickup_location,incomplete_reason,
count(*) 
as incomplete_rides

from uber
where booking_status ilike 'Incomplete'
group by 1,2
order by incomplete_rides desc;
```

**Objective**:Location-wise incomplete ride counts expose weak operational coverage.

## Findings & Conclusion
•	Reliability Risks: Uber Xl,Autos and Go Mini often show higher cancellation rates, driven by pricing sensitivity and supply constraints.
•	Peak-Time Stress: Evening  rush hours (the ride cancellation by driver/customer peak hour is 6pm)  reveal the sharpest spike in cancellations, both driver- and customer-initiated.
•	Revenue Loss: Cancelled rides represent a tangible revenue leakage, especially in high-value vehicle types like Sedans and XL.
•	Customer Behavior: Cash-heavy customers cancel more frequently; wallet/credit card users demonstrate stronger completion loyalty.
•	Efficiency Insights: Certain pickup zones consistently underperform, showing bottlenecks in both arrival delays and ride completion.
•	Forecasting Opportunity: Demand clustering by hour and geography provides actionable levers for supply-side optimization.
This project provides a 360° analytical lens on Uber’s core operational, financial, and customer challenges, demonstrating SQL as a powerful tool for business analytics.

## Author – Tatheer Zahra
This project is part of my data analytics portfolio. It showcases my ability to design SQL queries to solve complex business problems and translate raw ride data into actionable business insights.
