
-- 1.	Cancellation rate by vehicle type: Which vehicle types 
--(Go Mini, Sedan, Auto, etc.) see the highest driver- or customer-initiated cancellations, and why?


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





-- 2.	Peak-time cancellation behavior: At what times of day do customers cancel most 
-- often vs. drivers cancel most often?

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

 
-- 3.	Cancellation reason clustering: Analyze text reasons and flag common themes—e.g.,
-- pricing complaints, driver delays, location mismatch.

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


-- 4.	Impact of Avg VTAT & CTAT on cancellations: Is higher wait time
-- (driver arrival or customer arrival) strongly correlated with cancellation?



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
 



-- 5.	Avg VTAT & CTAT by location:
-- Which pickup zones cause chronic driver delays? Geo-level bottleneck detection.


SELEct pickup_location,AVG(avg_vtat) as Avg_VTAT,AVG(avg_ctat) as Avg_CTAT
From uber
group by pickup_location
order by Avg_VTAT desc,Avg_CTAT desc;


-- 6.	Vehicle utilization analysis: Track incomplete/cancelled rides 
-- as a proportion of assigned bookings to estimate wasted vehicle capacity.

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


-- 7.	Driver rating impact on cancellations: Are rides with drivers who has lower
-- average ratings more likely to have their rides cancelled by customers?


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




-- 8.	Customer loyalty vs. payment method: Do wallet/credit card
--users show higher ride completion rates compared to cash users?


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




-- 9.	Identify vehicle type who got cancelled excessively
--and measure their impact on system efficiency.


Select *,((cancelled_rides::numeric/total_rides::numeric)*100) as cancellation_per
from(
select  vehicle_type,
count(*) AS total_rides,
Sum(case when cancelled_by_customer is true then 1 else 0 end) As cancelled_rides,
Sum(case when cancelled_by_customer is not true then 1 else 0 end) As comp_rides
from uber
group by 1) t1
order by cancellation_per desc;


--10.	Revenue leakage due to cancellations: Estimate lost revenue 
--from both customer and driver cancellations.


select
Sum(case when cancelled_by_driver is true then booking_value else 0  end ) As lost_revenue_for_driver_cancellations,
Sum(case when cancelled_by_customer is true then booking_value else 0 end ) As lost_revenue_for_customer_cancellations
from uber
where booking_value is not null;



--11.	Profitability by vehicle type: Compare ride value vs. distance 
--across different vehicle categories.

Select vehicle_type,avg(booking_value) as avg_ride_value
,avg(ride_distance)as avg_ride_distance,
 ROUND(AVG(booking_value) / coalesce(AVG(ride_distance), 0), 2) AS value_per_distance

from uber
group by 1
order by avg_ride_value desc,avg_ride_distance desc;

--12.	Payment method profitability: Which payment methods \
--correlate with higher-value bookings? (Credit card rides vs. UPI vs. cash.)

select payment_method,Round (avg(booking_value ),3) as avg_booking_value
from uber
where booking_value is not null
group by 1
order by avg_booking_value desc ;



-- 13.	Temporal ride demand forecasting: Using booking timestamps, 
-- forecast high-demand periods to optimize driver supply.

Select 
extract (hour from booking_time ) As booking_time_hour,
count(*) as no_of_rides
from uber
group by 1
order by no_of_rides desc;

-- 14.	Hotspot detection: Identify locations with high booking 
-- density but high incomplete rates bcz of drivers not found—prime areas for driver allocation.


select *,Round(((incomplete_bcz_no_driver_found::numeric/no_of_rides_booked::numeric)*100),3) as incomplete_rides_per

from (
select pickup_location,count(*) As no_of_rides_booked,
count(case when booking_status ilike 'no driver found' then 1  end ) 
as incomplete_bcz_no_driver_found

from uber
group by 1
order by incomplete_bcz_no_driver_found desc
)t1;


-- 15.	Incomplete rides by geography: Which zones are prone 
-- to incomplete rides, and what are the cited reasons?


select pickup_location,incomplete_reason,
count(*) 
as incomplete_rides

from uber
where booking_status ilike 'Incomplete'
group by 1,2
order by incomplete_rides desc;


