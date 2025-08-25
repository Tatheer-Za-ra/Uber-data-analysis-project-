Drop table if exists Uber;

Create table Uber(
 booking_date Date NOT NULL,  
  booking_time TIME NOT NULL,
 booking_id VARCHAR(15), 
    booking_status VARCHAR(25) NOT NULL,
    customer_id VARCHAR(15) NOT NULL,
    vehicle_type VARCHAR(15) NOT NULL,
    pickup_location VARCHAR(30),    -- or GEOGRAPHY(Point,4326)
    drop_location VARCHAR(30),
    avg_vtat NUMERIC(5,2),           -- minutes
    avg_ctat NUMERIC(5,2),
    cancelled_by_customer BOOLEAN DEFAULT FALSE,
    customer_cancel_reason TEXT,
    cancelled_by_driver BOOLEAN DEFAULT FALSE,
    driver_cancel_reason TEXT,
    incomplete BOOLEAN DEFAULT FALSE,
    incomplete_reason TEXT,
    booking_value NUMERIC(10,2),
    ride_distance NUMERIC(6,2),
    driver_rating NUMERIC(2,1),
    customer_rating NUMERIC(2,1),
    payment_method VARCHAR(20)

);


Select * from uber;

