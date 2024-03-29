#!/usr/local/bin/tclsh8.6
#LOAD LIBRARIES AND MODULES
set library tdbc::odbc
set version 1.1.1
if [catch {package require $library $version} message] { error "Failed to load $library - $message" }
if [catch {::tcl::tm::path add modules} ] { error "Failed to find modules directory" }
if [catch {package require tpcccommon} ] { error "Failed to load tpcc common functions" } else { namespace import tpcccommon::* }
proc CreateStoredProcs { odbc imdb } {
puts "CREATING TPCC STORED PROCEDURES"
if { $imdb } {
set sql(1) {CREATE PROCEDURE [dbo].[neword]  
@no_w_id int,
@no_max_w_id int,
@no_d_id int,
@no_c_id int,
@no_o_ol_cnt int,
@TIMESTAMP datetime2(0)
AS 
BEGIN
SET ANSI_WARNINGS OFF
DECLARE
@no_c_discount smallmoney,
@no_c_last char(16),
@no_c_credit char(2),
@no_d_tax smallmoney,
@no_w_tax smallmoney,
@no_d_next_o_id int,
@no_ol_supply_w_id int, 
@no_ol_i_id int, 
@no_ol_quantity int, 
@no_o_all_local int, 
@o_id int, 
@no_i_name char(24), 
@no_i_price smallmoney, 
@no_i_data char(50), 
@no_s_quantity int, 
@no_ol_amount int, 
@no_s_dist_01 char(24), 
@no_s_dist_02 char(24), 
@no_s_dist_03 char(24), 
@no_s_dist_04 char(24), 
@no_s_dist_05 char(24), 
@no_s_dist_06 char(24), 
@no_s_dist_07 char(24), 
@no_s_dist_08 char(24), 
@no_s_dist_09 char(24), 
@no_s_dist_10 char(24), 
@no_ol_dist_info char(24), 
@no_s_data char(50), 
@x int, 
@rbk int
BEGIN TRANSACTION
BEGIN TRY

SET @no_o_all_local = 0
SELECT @no_c_discount = customer.c_discount
, @no_c_last = customer.c_last
, @no_c_credit = customer.c_credit
, @no_w_tax = warehouse.w_tax 
FROM dbo.customer, dbo.warehouse
WHERE warehouse.w_id = @no_w_id 
AND customer.c_w_id = @no_w_id 
AND customer.c_d_id = @no_d_id 
AND customer.c_id = @no_c_id

UPDATE dbo.district 
SET @no_d_tax = d_tax
, @o_id = d_next_o_id
,  d_next_o_id = district.d_next_o_id + 1 
WHERE district.d_id = @no_d_id 
AND district.d_w_id = @no_w_id
SET @no_d_next_o_id = @o_id+1

INSERT dbo.orders( o_id, o_d_id, o_w_id, o_c_id, o_entry_d, o_ol_cnt, o_all_local) 
VALUES ( @o_id, @no_d_id, @no_w_id, @no_c_id, @TIMESTAMP, @no_o_ol_cnt, @no_o_all_local)

INSERT dbo.new_order(no_o_id, no_d_id, no_w_id) 
VALUES (@o_id, @no_d_id, @no_w_id)

SET @rbk = CAST(100 * RAND() + 1 AS INT)
DECLARE
@loop_counter int
SET @loop_counter = 1
DECLARE
@loop$bound int
SET @loop$bound = @no_o_ol_cnt
WHILE @loop_counter <= @loop$bound
BEGIN
IF ((@loop_counter = @no_o_ol_cnt) AND (@rbk = 1))
SET @no_ol_i_id = 100001
ELSE 
SET @no_ol_i_id =  CAST(1000000 * RAND() + 1 AS INT)
SET @x = CAST(100 * RAND() + 1 AS INT)
IF (@x > 1)
SET @no_ol_supply_w_id = @no_w_id
ELSE 
BEGIN
SET @no_ol_supply_w_id = @no_w_id
SET @no_o_all_local = 0
WHILE ((@no_ol_supply_w_id = @no_w_id) AND (@no_max_w_id != 1))
BEGIN
SET @no_ol_supply_w_id = CAST(@no_max_w_id * RAND() + 1 AS INT)
DECLARE
@db_null_statement$2 int
END
END
SET @no_ol_quantity = CAST(10 * RAND() + 1 AS INT)

SELECT @no_i_price = item.i_price
, @no_i_name = item.i_name
, @no_i_data = item.i_data 
FROM dbo.item 
WHERE item.i_id = @no_ol_i_id

SELECT @no_s_quantity = stock.s_quantity
, @no_s_data = stock.s_data
, @no_s_dist_01 = stock.s_dist_01
, @no_s_dist_02 = stock.s_dist_02
, @no_s_dist_03 = stock.s_dist_03
, @no_s_dist_04 = stock.s_dist_04
, @no_s_dist_05 = stock.s_dist_05
, @no_s_dist_06 = stock.s_dist_06
, @no_s_dist_07 = stock.s_dist_07
, @no_s_dist_08 = stock.s_dist_08
, @no_s_dist_09 = stock.s_dist_09
, @no_s_dist_10 = stock.s_dist_10 
FROM dbo.stock
WHERE stock.s_i_id = @no_ol_i_id 
AND stock.s_w_id = @no_ol_supply_w_id


IF (@no_s_quantity > @no_ol_quantity)
SET @no_s_quantity = (@no_s_quantity - @no_ol_quantity)
ELSE 
SET @no_s_quantity = (@no_s_quantity - @no_ol_quantity + 91)

UPDATE dbo.stock
SET s_quantity = @no_s_quantity 
WHERE stock.s_i_id = @no_ol_i_id 
AND stock.s_w_id = @no_ol_supply_w_id

SET @no_ol_amount = (@no_ol_quantity * @no_i_price * (1 + @no_w_tax + @no_d_tax) * (1 - @no_c_discount))
IF @no_d_id = 1
SET @no_ol_dist_info = @no_s_dist_01
ELSE 
IF @no_d_id = 2
SET @no_ol_dist_info = @no_s_dist_02
ELSE 
IF @no_d_id = 3
SET @no_ol_dist_info = @no_s_dist_03
ELSE 
IF @no_d_id = 4
SET @no_ol_dist_info = @no_s_dist_04
ELSE 
IF @no_d_id = 5
SET @no_ol_dist_info = @no_s_dist_05
ELSE 
IF @no_d_id = 6
SET @no_ol_dist_info = @no_s_dist_06
ELSE 
IF @no_d_id = 7
SET @no_ol_dist_info = @no_s_dist_07
ELSE 
IF @no_d_id = 8
SET @no_ol_dist_info = @no_s_dist_08
ELSE 
IF @no_d_id = 9
SET @no_ol_dist_info = @no_s_dist_09
ELSE 
BEGIN
IF @no_d_id = 10
SET @no_ol_dist_info = @no_s_dist_10
END
INSERT dbo.order_line( ol_o_id, ol_d_id, ol_w_id, ol_number, ol_i_id, ol_supply_w_id, ol_quantity, ol_amount, ol_dist_info)
VALUES ( @o_id, @no_d_id, @no_w_id, @loop_counter, @no_ol_i_id, @no_ol_supply_w_id, @no_ol_quantity, @no_ol_amount, @no_ol_dist_info)
SET @loop_counter = @loop_counter + 1
END
SELECT convert(char(8), @no_c_discount) as N'@no_c_discount', @no_c_last as N'@no_c_last', @no_c_credit as N'@no_c_credit', convert(char(8),@no_d_tax) as N'@no_d_tax', convert(char(8),@no_w_tax) as N'@no_w_tax', @no_d_next_o_id as N'@no_d_next_o_id'

END TRY
BEGIN CATCH
IF (error_number() in (701, 41839, 41823, 41302, 41305, 41325, 41301))
SELECT 'IMOLTPERROR',ERROR_NUMBER() AS ErrorNumber
ELSE
SELECT 
ERROR_NUMBER() AS ErrorNumber
,ERROR_SEVERITY() AS ErrorSeverity
,ERROR_STATE() AS ErrorState
,ERROR_PROCEDURE() AS ErrorProcedure
,ERROR_LINE() AS ErrorLine
,ERROR_MESSAGE() AS ErrorMessage;
IF @@TRANCOUNT > 0
ROLLBACK TRANSACTION;
END CATCH;
IF @@TRANCOUNT > 0
COMMIT TRANSACTION;

END}
set sql(2) {CREATE PROCEDURE [dbo].[delivery]  
@d_w_id int,
@d_o_carrier_id int,
@timestamp datetime2(0)
AS 
BEGIN
SET ANSI_WARNINGS OFF
DECLARE
@d_no_o_id int, 
@d_d_id int, 
@d_c_id int, 
@d_ol_total int
BEGIN TRANSACTION
BEGIN TRY
DECLARE
@loop_counter int
SET @loop_counter = 1
WHILE @loop_counter <= 10
BEGIN
SET @d_d_id = @loop_counter


DECLARE @d_out TABLE (d_no_o_id INT)

DELETE TOP (1) 
FROM dbo.new_order 
OUTPUT deleted.no_o_id INTO @d_out -- @d_no_o_id
WHERE new_order.no_w_id = @d_w_id 
AND new_order.no_d_id = @d_d_id 

SELECT @d_no_o_id = d_no_o_id FROM @d_out
 

UPDATE dbo.orders 
SET o_carrier_id = @d_o_carrier_id 
, @d_c_id = orders.o_c_id 
WHERE orders.o_id = @d_no_o_id 
AND orders.o_d_id = @d_d_id 
AND orders.o_w_id = @d_w_id


 SET @d_ol_total = 0

UPDATE dbo.order_line 
SET ol_delivery_d = @timestamp
	, @d_ol_total = @d_ol_total + ol_amount
WHERE order_line.ol_o_id = @d_no_o_id 
AND order_line.ol_d_id = @d_d_id 
AND order_line.ol_w_id = @d_w_id


UPDATE dbo.customer SET c_balance = customer.c_balance + @d_ol_total 
WHERE customer.c_id = @d_c_id 
AND customer.c_d_id = @d_d_id 
AND customer.c_w_id = @d_w_id


PRINT 
'D: '
+ 
ISNULL(CAST(@d_d_id AS nvarchar(4000)), '')
+ 
'O: '
+ 
ISNULL(CAST(@d_no_o_id AS nvarchar(4000)), '')
+ 
'time '
+ 
ISNULL(CAST(@timestamp AS nvarchar(4000)), '')
SET @loop_counter = @loop_counter + 1
END
SELECT	@d_w_id as N'@d_w_id', @d_o_carrier_id as N'@d_o_carrier_id', @timestamp as N'@TIMESTAMP'
END TRY
BEGIN CATCH
IF (error_number() in (701, 41839, 41823, 41302, 41305, 41325, 41301))
SELECT 'IMOLTPERROR',ERROR_NUMBER() AS ErrorNumber
ELSE
SELECT 
ERROR_NUMBER() AS ErrorNumber
,ERROR_SEVERITY() AS ErrorSeverity
,ERROR_STATE() AS ErrorState
,ERROR_PROCEDURE() AS ErrorProcedure
,ERROR_LINE() AS ErrorLine
,ERROR_MESSAGE() AS ErrorMessage;
IF @@TRANCOUNT > 0
ROLLBACK TRANSACTION;
END CATCH;
IF @@TRANCOUNT > 0
COMMIT TRANSACTION;
END}
set sql(3) {CREATE PROCEDURE [dbo].[payment]  
@p_w_id int,
@p_d_id int,
@p_c_w_id int,
@p_c_d_id int,
@p_c_id int,
@byname int,
@p_h_amount numeric(6,2),
@p_c_last char(16),
@TIMESTAMP datetime2(0)
AS 
BEGIN
SET ANSI_WARNINGS OFF
DECLARE
@p_w_street_1 char(20),
@p_w_street_2 char(20),
@p_w_city char(20),
@p_w_state char(2),
@p_w_zip char(10),
@p_d_street_1 char(20),
@p_d_street_2 char(20),
@p_d_city char(20),
@p_d_state char(20),
@p_d_zip char(10),
@p_c_first char(16),
@p_c_middle char(2),
@p_c_street_1 char(20),
@p_c_street_2 char(20),
@p_c_city char(20),
@p_c_state char(20),
@p_c_zip char(9),
@p_c_phone char(16),
@p_c_since datetime2(0),
@p_c_credit char(32),
@p_c_credit_lim  numeric(12,2), 
@p_c_discount  numeric(4,4),
@p_c_balance numeric(12,2),
@p_c_data varchar(500),
@namecnt int, 
@p_d_name char(11), 
@p_w_name char(11), 
@p_c_new_data varchar(500), 
@h_data varchar(30)
BEGIN TRANSACTION
BEGIN TRY

SELECT @p_w_street_1 = warehouse.w_street_1
, @p_w_street_2 = warehouse.w_street_2
, @p_w_city = warehouse.w_city
, @p_w_state = warehouse.w_state
, @p_w_zip = warehouse.w_zip
, @p_w_name = warehouse.w_name 
FROM dbo.warehouse
WHERE warehouse.w_id = @p_w_id

UPDATE dbo.district 
SET d_ytd = district.d_ytd + @p_h_amount 
WHERE district.d_w_id = @p_w_id 
AND district.d_id = @p_d_id

SELECT @p_d_street_1 = district.d_street_1
, @p_d_street_2 = district.d_street_2
, @p_d_city = district.d_city
, @p_d_state = district.d_state
, @p_d_zip = district.d_zip
, @p_d_name = district.d_name 
FROM dbo.district
WHERE district.d_w_id = @p_w_id 
AND district.d_id = @p_d_id
IF (@byname = 1)
BEGIN
SELECT @namecnt = count(customer.c_id) 
FROM dbo.customer
WHERE customer.c_last = @p_c_last 
AND customer.c_d_id = @p_c_d_id 
AND customer.c_w_id = @p_c_w_id

DECLARE
c_byname CURSOR STATIC LOCAL FOR 
SELECT customer.c_first
, customer.c_middle
, customer.c_id
, customer.c_street_1
, customer.c_street_2
, customer.c_city
, customer.c_state
, customer.c_zip
, customer.c_phone
, customer.c_credit
, customer.c_credit_lim
, customer.c_discount
, C_BAL.c_balance
, customer.c_since 
FROM dbo.customer  AS customer
INNER LOOP JOIN dbo.customer AS C_BAL
ON C_BAL.c_w_id = customer.c_w_id
  AND C_BAL.c_d_id = customer.c_d_id
  AND C_BAL.c_id = customer.c_id
WHERE customer.c_w_id = @p_c_w_id 
  AND customer.c_d_id = @p_c_d_id 
  AND customer.c_last = @p_c_last 
ORDER BY customer.c_first
OPTION ( MAXDOP 1)
OPEN c_byname
IF ((@namecnt % 2) = 1)
SET @namecnt = (@namecnt + 1)
BEGIN
DECLARE
@loop_counter int
SET @loop_counter = 0
DECLARE
@loop$bound int
SET @loop$bound = (@namecnt / 2)
WHILE @loop_counter <= @loop$bound
BEGIN
FETCH c_byname
INTO 
@p_c_first, 
@p_c_middle, 
@p_c_id, 
@p_c_street_1, 
@p_c_street_2, 
@p_c_city, 
@p_c_state, 
@p_c_zip, 
@p_c_phone, 
@p_c_credit, 
@p_c_credit_lim, 
@p_c_discount, 
@p_c_balance, 
@p_c_since
SET @loop_counter = @loop_counter + 1
END
END
CLOSE c_byname
DEALLOCATE c_byname
END
ELSE 
BEGIN
SELECT @p_c_first = customer.c_first, @p_c_middle = customer.c_middle, @p_c_last = customer.c_last
, @p_c_street_1 = customer.c_street_1, @p_c_street_2 = customer.c_street_2
, @p_c_city = customer.c_city, @p_c_state = customer.c_state
, @p_c_zip = customer.c_zip, @p_c_phone = customer.c_phone
, @p_c_credit = customer.c_credit, @p_c_credit_lim = customer.c_credit_lim
, @p_c_discount = customer.c_discount, @p_c_balance = customer.c_balance
, @p_c_since = customer.c_since 
FROM dbo.customer 
WHERE customer.c_w_id = @p_c_w_id 
AND customer.c_d_id = @p_c_d_id 
AND customer.c_id = @p_c_id 

END
SET @p_c_balance = (@p_c_balance + @p_h_amount)
IF @p_c_credit = 'BC'
BEGIN
SELECT @p_c_data = customer.c_data FROM dbo.customer WHERE customer.c_w_id = @p_c_w_id 
AND customer.c_d_id = @p_c_d_id AND customer.c_id = @p_c_id
SET @h_data = (ISNULL(@p_w_name, '') + ' ' + ISNULL(@p_d_name, ''))
SET @p_c_new_data = (
ISNULL(CAST(@p_c_id AS char), '')
 + 
' '
 + 
ISNULL(CAST(@p_c_d_id AS char), '')
 + 
' '
 + 
ISNULL(CAST(@p_c_w_id AS char), '')
 + 
' '
 + 
ISNULL(CAST(@p_d_id AS char), '')
 + 
' '
 + 
ISNULL(CAST(@p_w_id AS char), '')
 + 
' '
 + 
ISNULL(CAST(@p_h_amount AS CHAR(8)), '')
 + 
ISNULL(CAST(@TIMESTAMP AS char), '')
 + 
ISNULL(@h_data, ''))
SET @p_c_new_data = substring((@p_c_new_data + @p_c_data), 1, 500 - LEN(@p_c_new_data))
UPDATE dbo.customer SET c_balance = @p_c_balance, c_data = @p_c_new_data 
WHERE customer.c_w_id = @p_c_w_id 
AND customer.c_d_id = @p_c_d_id AND customer.c_id = @p_c_id
END
ELSE 
UPDATE dbo.customer SET c_balance = @p_c_balance 
WHERE customer.c_w_id = @p_c_w_id 
AND customer.c_d_id = @p_c_d_id 
AND customer.c_id = @p_c_id

SET @h_data = (ISNULL(@p_w_name, '') + ' ' + ISNULL(@p_d_name, ''))

INSERT dbo.history( h_c_d_id, h_c_w_id, h_c_id, h_d_id, h_w_id, h_date, h_amount, h_data) 
VALUES ( @p_c_d_id, @p_c_w_id, @p_c_id, @p_d_id, @p_w_id, @TIMESTAMP, @p_h_amount, @h_data)
SELECT	@p_c_id as N'@p_c_id', @p_c_last as N'@p_c_last', @p_w_street_1 as N'@p_w_street_1'
, @p_w_street_2 as N'@p_w_street_2', @p_w_city as N'@p_w_city'
, @p_w_state as N'@p_w_state', @p_w_zip as N'@p_w_zip'
, @p_d_street_1 as N'@p_d_street_1', @p_d_street_2 as N'@p_d_street_2'
, @p_d_city as N'@p_d_city', @p_d_state as N'@p_d_state'
, @p_d_zip as N'@p_d_zip', @p_c_first as N'@p_c_first'
, @p_c_middle as N'@p_c_middle', @p_c_street_1 as N'@p_c_street_1'
, @p_c_street_2 as N'@p_c_street_2'
, @p_c_city as N'@p_c_city', @p_c_state as N'@p_c_state', @p_c_zip as N'@p_c_zip'
, @p_c_phone as N'@p_c_phone', @p_c_since as N'@p_c_since', @p_c_credit as N'@p_c_credit'
, @p_c_credit_lim as N'@p_c_credit_lim', @p_c_discount as N'@p_c_discount', @p_c_balance as N'@p_c_balance'
, @p_c_data as N'@p_c_data'


UPDATE dbo.warehouse
SET w_ytd = warehouse.w_ytd + @p_h_amount 
WHERE warehouse.w_id = @p_w_id

END TRY
BEGIN CATCH
IF (error_number() in (701, 41839, 41823, 41302, 41305, 41325, 41301))
SELECT 'IMOLTPERROR',ERROR_NUMBER() AS ErrorNumber
ELSE
SELECT 
ERROR_NUMBER() AS ErrorNumber
,ERROR_SEVERITY() AS ErrorSeverity
,ERROR_STATE() AS ErrorState
,ERROR_PROCEDURE() AS ErrorProcedure
,ERROR_LINE() AS ErrorLine
,ERROR_MESSAGE() AS ErrorMessage;
IF @@TRANCOUNT > 0
ROLLBACK TRANSACTION;
END CATCH;
IF @@TRANCOUNT > 0
COMMIT TRANSACTION;
END}
set sql(4) {CREATE PROCEDURE [dbo].[ostat] 
@os_w_id int,
@os_d_id int,
@os_c_id int,
@byname int,
@os_c_last char(20)
AS 
BEGIN
SET ANSI_WARNINGS OFF
DECLARE
@os_c_first char(16),
@os_c_middle char(2),
@os_c_balance money,
@os_o_id int,
@os_entdate datetime2(0),
@os_o_carrier_id int,
@os_ol_i_id 	INT,
@os_ol_supply_w_id INT,
@os_ol_quantity INT,
@os_ol_amount 	INT,
@os_ol_delivery_d DATE,
@namecnt int, 
@i int,
@os_ol_i_id_array VARCHAR(200),
@os_ol_supply_w_id_array VARCHAR(200),
@os_ol_quantity_array VARCHAR(200),
@os_ol_amount_array VARCHAR(200),
@os_ol_delivery_d_array VARCHAR(210)
BEGIN TRANSACTION
BEGIN TRY
SET @os_ol_i_id_array = 'CSV,'
SET @os_ol_supply_w_id_array = 'CSV,'
SET @os_ol_quantity_array = 'CSV,'
SET @os_ol_amount_array = 'CSV,'
SET @os_ol_delivery_d_array = 'CSV,'
IF (@byname = 1)
BEGIN

SELECT @namecnt = count_big(customer.c_id) 
FROM dbo.customer 
WHERE customer.c_last = @os_c_last AND customer.c_d_id = @os_d_id AND customer.c_w_id = @os_w_id

IF ((@namecnt % 2) = 1)
SET @namecnt = (@namecnt + 1)
DECLARE
c_name CURSOR LOCAL FOR 
SELECT customer.c_balance
, customer.c_first
, customer.c_middle
, customer.c_id 
FROM dbo.customer 
WHERE customer.c_last = @os_c_last 
AND customer.c_d_id = @os_d_id 
AND customer.c_w_id = @os_w_id 
ORDER BY customer.c_first

OPEN c_name
BEGIN
DECLARE
@loop_counter int
SET @loop_counter = 0
DECLARE
@loop$bound int
SET @loop$bound = (@namecnt / 2)
WHILE @loop_counter <= @loop$bound
BEGIN
FETCH c_name
INTO @os_c_balance, @os_c_first, @os_c_middle, @os_c_id
SET @loop_counter = @loop_counter + 1
END
END
CLOSE c_name
DEALLOCATE c_name
END
ELSE 
BEGIN
SELECT @os_c_balance = customer.c_balance, @os_c_first = customer.c_first
, @os_c_middle = customer.c_middle, @os_c_last = customer.c_last 
FROM dbo.customer
WHERE customer.c_id = @os_c_id AND customer.c_d_id = @os_d_id AND customer.c_w_id = @os_w_id
END
BEGIN
SELECT TOP (1) @os_o_id = fci.o_id, @os_o_carrier_id = fci.o_carrier_id, @os_entdate = fci.o_entry_d
FROM 
(SELECT TOP 9223372036854775807 orders.o_id, orders.o_carrier_id, orders.o_entry_d 
FROM dbo.orders
WHERE orders.o_d_id = @os_d_id 
AND orders.o_w_id = @os_w_id 
AND orders.o_c_id = @os_c_id 
ORDER BY orders.o_id DESC)  AS fci
IF @@ROWCOUNT = 0
PRINT 'No orders for customer';
END
SET @i = 0
DECLARE
c_line CURSOR LOCAL FORWARD_ONLY FOR 
SELECT order_line.ol_i_id
, order_line.ol_supply_w_id
, order_line.ol_quantity
, order_line.ol_amount
, order_line.ol_delivery_d 
FROM dbo.order_line 
WHERE order_line.ol_o_id = @os_o_id 
AND order_line.ol_d_id = @os_d_id 
AND order_line.ol_w_id = @os_w_id
OPEN c_line
WHILE 1 = 1
BEGIN
FETCH c_line
INTO 
@os_ol_i_id,
@os_ol_supply_w_id,
@os_ol_quantity,
@os_ol_amount,
@os_ol_delivery_d
IF @@FETCH_STATUS = -1
BREAK
set @os_ol_i_id_array += CAST(@i AS CHAR) + ',' + CAST(@os_ol_i_id AS CHAR)
set @os_ol_supply_w_id_array += CAST(@i AS CHAR) + ',' + CAST(@os_ol_supply_w_id AS CHAR)
set @os_ol_quantity_array += CAST(@i AS CHAR) + ',' + CAST(@os_ol_quantity AS CHAR)
set @os_ol_amount_array += CAST(@i AS CHAR) + ',' + CAST(@os_ol_amount AS CHAR);
set @os_ol_delivery_d_array += CAST(@i AS CHAR) + ',' + CAST(@os_ol_delivery_d AS CHAR)
SET @i = @i + 1
END
CLOSE c_line
DEALLOCATE c_line
SELECT	@os_c_id as N'@os_c_id', @os_c_last as N'@os_c_last', @os_c_first as N'@os_c_first', @os_c_middle as N'@os_c_middle', @os_c_balance as N'@os_c_balance', @os_o_id as N'@os_o_id', @os_entdate as N'@os_entdate', @os_o_carrier_id as N'@os_o_carrier_id'
END TRY
BEGIN CATCH
IF (error_number() in (701, 41839, 41823, 41302, 41305, 41325, 41301))
SELECT 'IMOLTPERROR',ERROR_NUMBER() AS ErrorNumber
ELSE
SELECT 
ERROR_NUMBER() AS ErrorNumber
,ERROR_SEVERITY() AS ErrorSeverity
,ERROR_STATE() AS ErrorState
,ERROR_PROCEDURE() AS ErrorProcedure
,ERROR_LINE() AS ErrorLine
,ERROR_MESSAGE() AS ErrorMessage;
IF @@TRANCOUNT > 0
ROLLBACK TRANSACTION;
END CATCH;
IF @@TRANCOUNT > 0
COMMIT TRANSACTION;
END}
set sql(5) {CREATE PROCEDURE [dbo].[slev]  
@st_w_id int,
@st_d_id int,
@threshold int
AS 
BEGIN
DECLARE
@st_o_id int, 
@stock_count int 
BEGIN TRANSACTION
BEGIN TRY

SELECT @st_o_id = district.d_next_o_id 
FROM dbo.district 
WHERE district.d_w_id = @st_w_id AND district.d_id = @st_d_id

SELECT @stock_count = count_big(DISTINCT stock.s_i_id) 
FROM dbo.order_line
, dbo.stock
WHERE order_line.ol_w_id = @st_w_id 
AND order_line.ol_d_id = @st_d_id 
AND (order_line.ol_o_id < @st_o_id) 
AND order_line.ol_o_id >= (@st_o_id - 20) 
AND stock.s_w_id = @st_w_id 
AND stock.s_i_id = order_line.ol_i_id 
AND stock.s_quantity < @threshold
OPTION (LOOP JOIN, MAXDOP 1)

SELECT	@st_o_id as N'@st_o_id', @stock_count as N'@stock_count'
END TRY
BEGIN CATCH
IF (error_number() in (701, 41839, 41823, 41302, 41305, 41325, 41301))
SELECT 'IMOLTPERROR',ERROR_NUMBER() AS ErrorNumber
ELSE
SELECT 
ERROR_NUMBER() AS ErrorNumber
,ERROR_SEVERITY() AS ErrorSeverity
,ERROR_STATE() AS ErrorState
,ERROR_PROCEDURE() AS ErrorProcedure
,ERROR_LINE() AS ErrorLine
,ERROR_MESSAGE() AS ErrorMessage;
IF @@TRANCOUNT > 0
ROLLBACK TRANSACTION;
END CATCH;
IF @@TRANCOUNT > 0
COMMIT TRANSACTION;
END} 
} else {
set sql(1) {CREATE PROCEDURE [dbo].[neword]  
@no_w_id int,
@no_max_w_id int,
@no_d_id int,
@no_c_id int,
@no_o_ol_cnt int,
@TIMESTAMP datetime2(0)
AS 
BEGIN
SET ANSI_WARNINGS OFF
DECLARE
@no_c_discount smallmoney,
@no_c_last char(16),
@no_c_credit char(2),
@no_d_tax smallmoney,
@no_w_tax smallmoney,
@no_d_next_o_id int,
@no_ol_supply_w_id int, 
@no_ol_i_id int, 
@no_ol_quantity int, 
@no_o_all_local int, 
@o_id int, 
@no_i_name char(24), 
@no_i_price smallmoney, 
@no_i_data char(50), 
@no_s_quantity int, 
@no_ol_amount int, 
@no_s_dist_01 char(24), 
@no_s_dist_02 char(24), 
@no_s_dist_03 char(24), 
@no_s_dist_04 char(24), 
@no_s_dist_05 char(24), 
@no_s_dist_06 char(24), 
@no_s_dist_07 char(24), 
@no_s_dist_08 char(24), 
@no_s_dist_09 char(24), 
@no_s_dist_10 char(24), 
@no_ol_dist_info char(24), 
@no_s_data char(50), 
@x int, 
@rbk int
BEGIN TRANSACTION
BEGIN TRY

SET @no_o_all_local = 0
SELECT @no_c_discount = customer.c_discount
, @no_c_last = customer.c_last
, @no_c_credit = customer.c_credit
, @no_w_tax = warehouse.w_tax 
FROM dbo.customer, dbo.warehouse WITH (INDEX = w_details)
WHERE warehouse.w_id = @no_w_id 
AND customer.c_w_id = @no_w_id 
AND customer.c_d_id = @no_d_id 
AND customer.c_id = @no_c_id

UPDATE dbo.district 
SET @no_d_tax = d_tax
, @o_id = d_next_o_id
,  d_next_o_id = district.d_next_o_id + 1 
WHERE district.d_id = @no_d_id 
AND district.d_w_id = @no_w_id
SET @no_d_next_o_id = @o_id+1

INSERT dbo.orders( o_id, o_d_id, o_w_id, o_c_id, o_entry_d, o_ol_cnt, o_all_local) 
VALUES ( @o_id, @no_d_id, @no_w_id, @no_c_id, @TIMESTAMP, @no_o_ol_cnt, @no_o_all_local)

INSERT dbo.new_order(no_o_id, no_d_id, no_w_id) 
VALUES (@o_id, @no_d_id, @no_w_id)

SET @rbk = CAST(100 * RAND() + 1 AS INT)
DECLARE
@loop_counter int
SET @loop_counter = 1
DECLARE
@loop$bound int
SET @loop$bound = @no_o_ol_cnt
WHILE @loop_counter <= @loop$bound
BEGIN
IF ((@loop_counter = @no_o_ol_cnt) AND (@rbk = 1))
SET @no_ol_i_id = 100001
ELSE 
SET @no_ol_i_id =  CAST(1000000 * RAND() + 1 AS INT)
SET @x = CAST(100 * RAND() + 1 AS INT)
IF (@x > 1)
SET @no_ol_supply_w_id = @no_w_id
ELSE 
BEGIN
SET @no_ol_supply_w_id = @no_w_id
SET @no_o_all_local = 0
WHILE ((@no_ol_supply_w_id = @no_w_id) AND (@no_max_w_id != 1))
BEGIN
SET @no_ol_supply_w_id = CAST(@no_max_w_id * RAND() + 1 AS INT)
DECLARE
@db_null_statement$2 int
END
END
SET @no_ol_quantity = CAST(10 * RAND() + 1 AS INT)

SELECT @no_i_price = item.i_price
, @no_i_name = item.i_name
, @no_i_data = item.i_data 
FROM dbo.item 
WHERE item.i_id = @no_ol_i_id

SELECT @no_s_quantity = stock.s_quantity
, @no_s_data = stock.s_data
, @no_s_dist_01 = stock.s_dist_01
, @no_s_dist_02 = stock.s_dist_02
, @no_s_dist_03 = stock.s_dist_03
, @no_s_dist_04 = stock.s_dist_04
, @no_s_dist_05 = stock.s_dist_05
, @no_s_dist_06 = stock.s_dist_06
, @no_s_dist_07 = stock.s_dist_07
, @no_s_dist_08 = stock.s_dist_08
, @no_s_dist_09 = stock.s_dist_09
, @no_s_dist_10 = stock.s_dist_10 
FROM dbo.stock
WHERE stock.s_i_id = @no_ol_i_id 
AND stock.s_w_id = @no_ol_supply_w_id


IF (@no_s_quantity > @no_ol_quantity)
SET @no_s_quantity = (@no_s_quantity - @no_ol_quantity)
ELSE 
SET @no_s_quantity = (@no_s_quantity - @no_ol_quantity + 91)

UPDATE dbo.stock
SET s_quantity = @no_s_quantity 
WHERE stock.s_i_id = @no_ol_i_id 
AND stock.s_w_id = @no_ol_supply_w_id

SET @no_ol_amount = (@no_ol_quantity * @no_i_price * (1 + @no_w_tax + @no_d_tax) * (1 - @no_c_discount))
IF @no_d_id = 1
SET @no_ol_dist_info = @no_s_dist_01
ELSE 
IF @no_d_id = 2
SET @no_ol_dist_info = @no_s_dist_02
ELSE 
IF @no_d_id = 3
SET @no_ol_dist_info = @no_s_dist_03
ELSE 
IF @no_d_id = 4
SET @no_ol_dist_info = @no_s_dist_04
ELSE 
IF @no_d_id = 5
SET @no_ol_dist_info = @no_s_dist_05
ELSE 
IF @no_d_id = 6
SET @no_ol_dist_info = @no_s_dist_06
ELSE 
IF @no_d_id = 7
SET @no_ol_dist_info = @no_s_dist_07
ELSE 
IF @no_d_id = 8
SET @no_ol_dist_info = @no_s_dist_08
ELSE 
IF @no_d_id = 9
SET @no_ol_dist_info = @no_s_dist_09
ELSE 
BEGIN
IF @no_d_id = 10
SET @no_ol_dist_info = @no_s_dist_10
END
INSERT dbo.order_line( ol_o_id, ol_d_id, ol_w_id, ol_number, ol_i_id, ol_supply_w_id, ol_quantity, ol_amount, ol_dist_info)
VALUES ( @o_id, @no_d_id, @no_w_id, @loop_counter, @no_ol_i_id, @no_ol_supply_w_id, @no_ol_quantity, @no_ol_amount, @no_ol_dist_info)
SET @loop_counter = @loop_counter + 1
END
SELECT convert(char(8), @no_c_discount) as N'@no_c_discount', @no_c_last as N'@no_c_last', @no_c_credit as N'@no_c_credit', convert(char(8),@no_d_tax) as N'@no_d_tax', convert(char(8),@no_w_tax) as N'@no_w_tax', @no_d_next_o_id as N'@no_d_next_o_id'

END TRY
BEGIN CATCH
SELECT 
ERROR_NUMBER() AS ErrorNumber
,ERROR_SEVERITY() AS ErrorSeverity
,ERROR_STATE() AS ErrorState
,ERROR_PROCEDURE() AS ErrorProcedure
,ERROR_LINE() AS ErrorLine
,ERROR_MESSAGE() AS ErrorMessage;
IF @@TRANCOUNT > 0
ROLLBACK TRANSACTION;
END CATCH;
IF @@TRANCOUNT > 0
COMMIT TRANSACTION;

END}
set sql(2) {CREATE PROCEDURE [dbo].[delivery]  
@d_w_id int,
@d_o_carrier_id int,
@timestamp datetime2(0)
AS 
BEGIN
SET ANSI_WARNINGS OFF
DECLARE
@d_no_o_id int, 
@d_d_id int, 
@d_c_id int, 
@d_ol_total int
BEGIN TRANSACTION
BEGIN TRY
DECLARE
@loop_counter int
SET @loop_counter = 1
WHILE @loop_counter <= 10
BEGIN
SET @d_d_id = @loop_counter


DECLARE @d_out TABLE (d_no_o_id INT)

DELETE TOP (1) 
FROM dbo.new_order 
OUTPUT deleted.no_o_id INTO @d_out -- @d_no_o_id
WHERE new_order.no_w_id = @d_w_id 
AND new_order.no_d_id = @d_d_id 

SELECT @d_no_o_id = d_no_o_id FROM @d_out
 

UPDATE dbo.orders 
SET o_carrier_id = @d_o_carrier_id 
, @d_c_id = orders.o_c_id 
WHERE orders.o_id = @d_no_o_id 
AND orders.o_d_id = @d_d_id 
AND orders.o_w_id = @d_w_id


 SET @d_ol_total = 0

UPDATE dbo.order_line 
SET ol_delivery_d = @timestamp
	, @d_ol_total = @d_ol_total + ol_amount
WHERE order_line.ol_o_id = @d_no_o_id 
AND order_line.ol_d_id = @d_d_id 
AND order_line.ol_w_id = @d_w_id


UPDATE dbo.customer SET c_balance = customer.c_balance + @d_ol_total 
WHERE customer.c_id = @d_c_id 
AND customer.c_d_id = @d_d_id 
AND customer.c_w_id = @d_w_id


PRINT 
'D: '
+ 
ISNULL(CAST(@d_d_id AS nvarchar(4000)), '')
+ 
'O: '
+ 
ISNULL(CAST(@d_no_o_id AS nvarchar(4000)), '')
+ 
'time '
+ 
ISNULL(CAST(@timestamp AS nvarchar(4000)), '')
SET @loop_counter = @loop_counter + 1
END
SELECT	@d_w_id as N'@d_w_id', @d_o_carrier_id as N'@d_o_carrier_id', @timestamp as N'@TIMESTAMP'
END TRY
BEGIN CATCH
SELECT 
ERROR_NUMBER() AS ErrorNumber
,ERROR_SEVERITY() AS ErrorSeverity
,ERROR_STATE() AS ErrorState
,ERROR_PROCEDURE() AS ErrorProcedure
,ERROR_LINE() AS ErrorLine
,ERROR_MESSAGE() AS ErrorMessage;
IF @@TRANCOUNT > 0
ROLLBACK TRANSACTION;
END CATCH;
IF @@TRANCOUNT > 0
COMMIT TRANSACTION;
END}
set sql(3) {CREATE PROCEDURE [dbo].[payment]  
@p_w_id int,
@p_d_id int,
@p_c_w_id int,
@p_c_d_id int,
@p_c_id int,
@byname int,
@p_h_amount numeric(6,2),
@p_c_last char(16),
@TIMESTAMP datetime2(0)
AS 
BEGIN
SET ANSI_WARNINGS OFF
DECLARE
@p_w_street_1 char(20),
@p_w_street_2 char(20),
@p_w_city char(20),
@p_w_state char(2),
@p_w_zip char(10),
@p_d_street_1 char(20),
@p_d_street_2 char(20),
@p_d_city char(20),
@p_d_state char(20),
@p_d_zip char(10),
@p_c_first char(16),
@p_c_middle char(2),
@p_c_street_1 char(20),
@p_c_street_2 char(20),
@p_c_city char(20),
@p_c_state char(20),
@p_c_zip char(9),
@p_c_phone char(16),
@p_c_since datetime2(0),
@p_c_credit char(32),
@p_c_credit_lim  numeric(12,2), 
@p_c_discount  numeric(4,4),
@p_c_balance numeric(12,2),
@p_c_data varchar(500),
@namecnt int, 
@p_d_name char(11), 
@p_w_name char(11), 
@p_c_new_data varchar(500), 
@h_data varchar(30)
BEGIN TRANSACTION
BEGIN TRY

SELECT @p_w_street_1 = warehouse.w_street_1
, @p_w_street_2 = warehouse.w_street_2
, @p_w_city = warehouse.w_city
, @p_w_state = warehouse.w_state
, @p_w_zip = warehouse.w_zip
, @p_w_name = warehouse.w_name 
FROM dbo.warehouse WITH (INDEX = [w_details])
WHERE warehouse.w_id = @p_w_id

UPDATE dbo.district 
SET d_ytd = district.d_ytd + @p_h_amount 
WHERE district.d_w_id = @p_w_id 
AND district.d_id = @p_d_id

SELECT @p_d_street_1 = district.d_street_1
, @p_d_street_2 = district.d_street_2
, @p_d_city = district.d_city
, @p_d_state = district.d_state
, @p_d_zip = district.d_zip
, @p_d_name = district.d_name 
FROM dbo.district WITH (INDEX = d_details)
WHERE district.d_w_id = @p_w_id 
AND district.d_id = @p_d_id
IF (@byname = 1)
BEGIN
SELECT @namecnt = count(customer.c_id) 
FROM dbo.customer WITH (repeatableread) 
WHERE customer.c_last = @p_c_last 
AND customer.c_d_id = @p_c_d_id 
AND customer.c_w_id = @p_c_w_id

DECLARE
c_byname CURSOR STATIC LOCAL FOR 
SELECT customer.c_first
, customer.c_middle
, customer.c_id
, customer.c_street_1
, customer.c_street_2
, customer.c_city
, customer.c_state
, customer.c_zip
, customer.c_phone
, customer.c_credit
, customer.c_credit_lim
, customer.c_discount
, C_BAL.c_balance
, customer.c_since 
FROM dbo.customer  AS customer WITH (INDEX = [customer_i2], repeatableread)
INNER LOOP JOIN dbo.customer AS C_BAL WITH (INDEX = [customer_i1], repeatableread) 
ON C_BAL.c_w_id = customer.c_w_id
  AND C_BAL.c_d_id = customer.c_d_id
  AND C_BAL.c_id = customer.c_id
WHERE customer.c_w_id = @p_c_w_id 
  AND customer.c_d_id = @p_c_d_id 
  AND customer.c_last = @p_c_last 
ORDER BY customer.c_first
OPTION ( MAXDOP 1)
OPEN c_byname
IF ((@namecnt % 2) = 1)
SET @namecnt = (@namecnt + 1)
BEGIN
DECLARE
@loop_counter int
SET @loop_counter = 0
DECLARE
@loop$bound int
SET @loop$bound = (@namecnt / 2)
WHILE @loop_counter <= @loop$bound
BEGIN
FETCH c_byname
INTO 
@p_c_first, 
@p_c_middle, 
@p_c_id, 
@p_c_street_1, 
@p_c_street_2, 
@p_c_city, 
@p_c_state, 
@p_c_zip, 
@p_c_phone, 
@p_c_credit, 
@p_c_credit_lim, 
@p_c_discount, 
@p_c_balance, 
@p_c_since
SET @loop_counter = @loop_counter + 1
END
END
CLOSE c_byname
DEALLOCATE c_byname
END
ELSE 
BEGIN
SELECT @p_c_first = customer.c_first, @p_c_middle = customer.c_middle, @p_c_last = customer.c_last
, @p_c_street_1 = customer.c_street_1, @p_c_street_2 = customer.c_street_2
, @p_c_city = customer.c_city, @p_c_state = customer.c_state
, @p_c_zip = customer.c_zip, @p_c_phone = customer.c_phone
, @p_c_credit = customer.c_credit, @p_c_credit_lim = customer.c_credit_lim
, @p_c_discount = customer.c_discount, @p_c_balance = customer.c_balance
, @p_c_since = customer.c_since 
FROM dbo.customer 
WHERE customer.c_w_id = @p_c_w_id 
AND customer.c_d_id = @p_c_d_id 
AND customer.c_id = @p_c_id 

END
SET @p_c_balance = (@p_c_balance + @p_h_amount)
IF @p_c_credit = 'BC'
BEGIN
SELECT @p_c_data = customer.c_data FROM dbo.customer WHERE customer.c_w_id = @p_c_w_id 
AND customer.c_d_id = @p_c_d_id AND customer.c_id = @p_c_id
SET @h_data = (ISNULL(@p_w_name, '') + ' ' + ISNULL(@p_d_name, ''))
SET @p_c_new_data = (
ISNULL(CAST(@p_c_id AS char), '')
 + 
' '
 + 
ISNULL(CAST(@p_c_d_id AS char), '')
 + 
' '
 + 
ISNULL(CAST(@p_c_w_id AS char), '')
 + 
' '
 + 
ISNULL(CAST(@p_d_id AS char), '')
 + 
' '
 + 
ISNULL(CAST(@p_w_id AS char), '')
 + 
' '
 + 
ISNULL(CAST(@p_h_amount AS CHAR(8)), '')
 + 
ISNULL(CAST(@TIMESTAMP AS char), '')
 + 
ISNULL(@h_data, ''))
SET @p_c_new_data = substring((@p_c_new_data + @p_c_data), 1, 500 - LEN(@p_c_new_data))
UPDATE dbo.customer SET c_balance = @p_c_balance, c_data = @p_c_new_data 
WHERE customer.c_w_id = @p_c_w_id 
AND customer.c_d_id = @p_c_d_id AND customer.c_id = @p_c_id
END
ELSE 
UPDATE dbo.customer SET c_balance = @p_c_balance 
WHERE customer.c_w_id = @p_c_w_id 
AND customer.c_d_id = @p_c_d_id 
AND customer.c_id = @p_c_id

SET @h_data = (ISNULL(@p_w_name, '') + ' ' + ISNULL(@p_d_name, ''))

INSERT dbo.history( h_c_d_id, h_c_w_id, h_c_id, h_d_id, h_w_id, h_date, h_amount, h_data) 
VALUES ( @p_c_d_id, @p_c_w_id, @p_c_id, @p_d_id, @p_w_id, @TIMESTAMP, @p_h_amount, @h_data)
SELECT	@p_c_id as N'@p_c_id', @p_c_last as N'@p_c_last', @p_w_street_1 as N'@p_w_street_1'
, @p_w_street_2 as N'@p_w_street_2', @p_w_city as N'@p_w_city'
, @p_w_state as N'@p_w_state', @p_w_zip as N'@p_w_zip'
, @p_d_street_1 as N'@p_d_street_1', @p_d_street_2 as N'@p_d_street_2'
, @p_d_city as N'@p_d_city', @p_d_state as N'@p_d_state'
, @p_d_zip as N'@p_d_zip', @p_c_first as N'@p_c_first'
, @p_c_middle as N'@p_c_middle', @p_c_street_1 as N'@p_c_street_1'
, @p_c_street_2 as N'@p_c_street_2'
, @p_c_city as N'@p_c_city', @p_c_state as N'@p_c_state', @p_c_zip as N'@p_c_zip'
, @p_c_phone as N'@p_c_phone', @p_c_since as N'@p_c_since', @p_c_credit as N'@p_c_credit'
, @p_c_credit_lim as N'@p_c_credit_lim', @p_c_discount as N'@p_c_discount', @p_c_balance as N'@p_c_balance'
, @p_c_data as N'@p_c_data'


UPDATE dbo.warehouse WITH (XLOCK)
SET w_ytd = warehouse.w_ytd + @p_h_amount 
WHERE warehouse.w_id = @p_w_id

END TRY
BEGIN CATCH
SELECT 
ERROR_NUMBER() AS ErrorNumber
,ERROR_SEVERITY() AS ErrorSeverity
,ERROR_STATE() AS ErrorState
,ERROR_PROCEDURE() AS ErrorProcedure
,ERROR_LINE() AS ErrorLine
,ERROR_MESSAGE() AS ErrorMessage;
IF @@TRANCOUNT > 0
ROLLBACK TRANSACTION;
END CATCH;
IF @@TRANCOUNT > 0
COMMIT TRANSACTION;
END}
set sql(4) {CREATE PROCEDURE [dbo].[ostat] 
@os_w_id int,
@os_d_id int,
@os_c_id int,
@byname int,
@os_c_last char(20)
AS 
BEGIN
SET ANSI_WARNINGS OFF
DECLARE
@os_c_first char(16),
@os_c_middle char(2),
@os_c_balance money,
@os_o_id int,
@os_entdate datetime2(0),
@os_o_carrier_id int,
@os_ol_i_id 	INT,
@os_ol_supply_w_id INT,
@os_ol_quantity INT,
@os_ol_amount 	INT,
@os_ol_delivery_d DATE,
@namecnt int, 
@i int,
@os_ol_i_id_array VARCHAR(200),
@os_ol_supply_w_id_array VARCHAR(200),
@os_ol_quantity_array VARCHAR(200),
@os_ol_amount_array VARCHAR(200),
@os_ol_delivery_d_array VARCHAR(210)
BEGIN TRANSACTION
BEGIN TRY
SET @os_ol_i_id_array = 'CSV,'
SET @os_ol_supply_w_id_array = 'CSV,'
SET @os_ol_quantity_array = 'CSV,'
SET @os_ol_amount_array = 'CSV,'
SET @os_ol_delivery_d_array = 'CSV,'
IF (@byname = 1)
BEGIN

SELECT @namecnt = count_big(customer.c_id) 
FROM dbo.customer 
WHERE customer.c_last = @os_c_last AND customer.c_d_id = @os_d_id AND customer.c_w_id = @os_w_id

IF ((@namecnt % 2) = 1)
SET @namecnt = (@namecnt + 1)
DECLARE
c_name CURSOR LOCAL FOR 
SELECT customer.c_balance
, customer.c_first
, customer.c_middle
, customer.c_id 
FROM dbo.customer 
WHERE customer.c_last = @os_c_last 
AND customer.c_d_id = @os_d_id 
AND customer.c_w_id = @os_w_id 
ORDER BY customer.c_first

OPEN c_name
BEGIN
DECLARE
@loop_counter int
SET @loop_counter = 0
DECLARE
@loop$bound int
SET @loop$bound = (@namecnt / 2)
WHILE @loop_counter <= @loop$bound
BEGIN
FETCH c_name
INTO @os_c_balance, @os_c_first, @os_c_middle, @os_c_id
SET @loop_counter = @loop_counter + 1
END
END
CLOSE c_name
DEALLOCATE c_name
END
ELSE 
BEGIN
SELECT @os_c_balance = customer.c_balance, @os_c_first = customer.c_first
, @os_c_middle = customer.c_middle, @os_c_last = customer.c_last 
FROM dbo.customer WITH (repeatableread) 
WHERE customer.c_id = @os_c_id AND customer.c_d_id = @os_d_id AND customer.c_w_id = @os_w_id
END
BEGIN
SELECT TOP (1) @os_o_id = fci.o_id, @os_o_carrier_id = fci.o_carrier_id, @os_entdate = fci.o_entry_d
FROM 
(SELECT TOP 9223372036854775807 orders.o_id, orders.o_carrier_id, orders.o_entry_d 
FROM dbo.orders WITH (serializable) 
WHERE orders.o_d_id = @os_d_id 
AND orders.o_w_id = @os_w_id 
AND orders.o_c_id = @os_c_id 
ORDER BY orders.o_id DESC)  AS fci
IF @@ROWCOUNT = 0
PRINT 'No orders for customer';
END
SET @i = 0
DECLARE
c_line CURSOR LOCAL FORWARD_ONLY FOR 
SELECT order_line.ol_i_id
, order_line.ol_supply_w_id
, order_line.ol_quantity
, order_line.ol_amount
, order_line.ol_delivery_d 
FROM dbo.order_line WITH (repeatableread) 
WHERE order_line.ol_o_id = @os_o_id 
AND order_line.ol_d_id = @os_d_id 
AND order_line.ol_w_id = @os_w_id
OPEN c_line
WHILE 1 = 1
BEGIN
FETCH c_line
INTO 
@os_ol_i_id,
@os_ol_supply_w_id,
@os_ol_quantity,
@os_ol_amount,
@os_ol_delivery_d
IF @@FETCH_STATUS = -1
BREAK
set @os_ol_i_id_array += CAST(@i AS CHAR) + ',' + CAST(@os_ol_i_id AS CHAR)
set @os_ol_supply_w_id_array += CAST(@i AS CHAR) + ',' + CAST(@os_ol_supply_w_id AS CHAR)
set @os_ol_quantity_array += CAST(@i AS CHAR) + ',' + CAST(@os_ol_quantity AS CHAR)
set @os_ol_amount_array += CAST(@i AS CHAR) + ',' + CAST(@os_ol_amount AS CHAR);
set @os_ol_delivery_d_array += CAST(@i AS CHAR) + ',' + CAST(@os_ol_delivery_d AS CHAR)
SET @i = @i + 1
END
CLOSE c_line
DEALLOCATE c_line
SELECT	@os_c_id as N'@os_c_id', @os_c_last as N'@os_c_last', @os_c_first as N'@os_c_first', @os_c_middle as N'@os_c_middle', @os_c_balance as N'@os_c_balance', @os_o_id as N'@os_o_id', @os_entdate as N'@os_entdate', @os_o_carrier_id as N'@os_o_carrier_id'
END TRY
BEGIN CATCH
SELECT 
ERROR_NUMBER() AS ErrorNumber
,ERROR_SEVERITY() AS ErrorSeverity
,ERROR_STATE() AS ErrorState
,ERROR_PROCEDURE() AS ErrorProcedure
,ERROR_LINE() AS ErrorLine
,ERROR_MESSAGE() AS ErrorMessage;
IF @@TRANCOUNT > 0
ROLLBACK TRANSACTION;
END CATCH;
IF @@TRANCOUNT > 0
COMMIT TRANSACTION;
END}
set sql(5) {CREATE PROCEDURE [dbo].[slev]  
@st_w_id int,
@st_d_id int,
@threshold int
AS 
BEGIN
DECLARE
@st_o_id int, 
@stock_count int 
BEGIN TRANSACTION
BEGIN TRY

SELECT @st_o_id = district.d_next_o_id 
FROM dbo.district 
WHERE district.d_w_id = @st_w_id AND district.d_id = @st_d_id

SELECT @stock_count = count_big(DISTINCT stock.s_i_id) 
FROM dbo.order_line
, dbo.stock
WHERE order_line.ol_w_id = @st_w_id 
AND order_line.ol_d_id = @st_d_id 
AND (order_line.ol_o_id < @st_o_id) 
AND order_line.ol_o_id >= (@st_o_id - 20) 
AND stock.s_w_id = @st_w_id 
AND stock.s_i_id = order_line.ol_i_id 
AND stock.s_quantity < @threshold
OPTION (LOOP JOIN, MAXDOP 1)

SELECT	@st_o_id as N'@st_o_id', @stock_count as N'@stock_count'
END TRY
BEGIN CATCH
SELECT 
ERROR_NUMBER() AS ErrorNumber
,ERROR_SEVERITY() AS ErrorSeverity
,ERROR_STATE() AS ErrorState
,ERROR_PROCEDURE() AS ErrorProcedure
,ERROR_LINE() AS ErrorLine
,ERROR_MESSAGE() AS ErrorMessage;
IF @@TRANCOUNT > 0
ROLLBACK TRANSACTION;
END CATCH;
IF @@TRANCOUNT > 0
COMMIT TRANSACTION;
END}
}
for { set i 1 } { $i <= 5 } { incr i } {
$odbc evaldirect $sql($i)
		}
return
}


proc UpdateStatistics { odbc db azure } {
puts "UPDATING SCHEMA STATISTICS"
if {!$azure} {
$odbc evaldirect "CREATE OR ALTER PROCEDURE dbo.sp_updstats
with execute as 'dbo'
as
exec sp_updatestats
"
$odbc evaldirect "EXEC dbo.sp_updstats"
} else {
set sql(1) "USE $db"
set sql(2) "EXEC sp_updatestats"
for { set i 1 } { $i <= 2 } { incr i } {
$odbc evaldirect $sql($i)
		}
	}
return
}

proc CreateDatabase { odbc db imdb azure } {
set table_count 0
puts "CHECKING IF DATABASE $db EXISTS"
set rows [ $odbc allrows "IF DB_ID('$db') is not null SELECT 1 AS res ELSE SELECT 0 AS res" ]
set db_exists [ lindex {*}$rows 1 ]
if { $db_exists } {
if {!$azure} {$odbc evaldirect "use $db"}
set rows [ $odbc allrows "select COUNT(*) from sys.tables" ]
set table_count [ lindex {*}$rows 1 ]
if { $table_count == 0 } {
puts "Empty database $db exists"
if { $imdb } {
$odbc evaldirect "ALTER DATABASE $db SET AUTO_CREATE_STATISTICS OFF"
$odbc evaldirect "ALTER DATABASE $db SET AUTO_UPDATE_STATISTICS OFF"
set rows [ $odbc allrows {SELECT TOP 1 1 FROM sys.filegroups FG JOIN sys.database_files F ON FG.data_space_id = F.data_space_id WHERE FG.type = 'FX' AND F.type = 2} ]
set imdb_fg [ lindex {*}$rows 1 ] 
if { $imdb_fg eq "1" } { 
set rows [ $odbc allrows "SELECT is_memory_optimized_elevate_to_snapshot_on FROM sys.databases WHERE name = '$db'" ]
set elevatetosnap [ lindex {*}$rows 1 ]
if { $elevatetosnap eq "1" } {
puts "Using existing Memory Optimized Database $db with ELEVATE_TO_SNAPSHOT for Schema build"
	} else {
puts "Existing Memory Optimized Database $db exists, setting ELEVATE_TO_SNAPSHOT"
unset -nocomplain rows
unset -nocomplain elevatetosnap
$odbc evaldirect "ALTER DATABASE $db SET MEMORY_OPTIMIZED_ELEVATE_TO_SNAPSHOT = ON"
set rows [ $odbc allrows "SELECT is_memory_optimized_elevate_to_snapshot_on FROM sys.databases WHERE name = '$db'" ]
set elevatetosnap [ lindex {*}$rows 1 ]
if { $elevatetosnap eq "1" } {
puts "Success: Set ELEVATE_TO_SNAPSHOT for Database $db"
	} else {
puts "Failed to set ELEVATE_TO_SNAPSHOT for Database $db"
error "Set ELEVATE_TO_SNAPSHOT for Database $db and retry build"
	}
	}
	} else {
puts "Database $db must be in a MEMORY_OPTIMIZED_DATA filegroup"
error "Database $db exists but is not in a MEMORY_OPTIMIZED_DATA filegroup"
	}
      } else {
puts "Using existing empty Database $db for Schema build"
	}
      } else {
puts "Database with tables $db exists"
error "Database $db exists but is not empty, specify a new or empty database name"
        }
      } else {
if { $imdb } {
puts "In Memory Database chosen but $db does not exist"
error "Database $db must be pre-created in a MEMORY_OPTIMIZED_DATA filegroup and empty, to specify an In-Memory build"
      } else {
puts "CREATING DATABASE $db"
$odbc evaldirect "create database $db"
		}
        }
}

proc CreateTables { odbc imdb count_ware bucket_factor durability } {
puts "CREATING TPCC TABLES"
if { $imdb } {
set stmnt_cnt 9 
set ware_bc  [ expr $count_ware * 1 ]
set dist_bc  [ expr $count_ware * 10 ]
set item_bc 131072
set cust_bc [ expr $count_ware * 30000 ]
set stock_bc  [ expr $count_ware * 100000 ]
set neword_bc  [ expr $count_ware * (40000 * $bucket_factor) ]
set orderl_bc  [ expr $count_ware * (400000 * $bucket_factor) ]
set order_bc  [ expr $count_ware * (40000 * $bucket_factor) ]
set sql(1) [ subst -nocommands {CREATE TABLE [dbo].[customer] ( [c_id] [int] NOT NULL, [c_d_id] [tinyint] NOT NULL, [c_w_id] [int] NOT NULL, [c_discount] [smallmoney] NULL, [c_credit_lim] [money] NULL, [c_last] [char](16) COLLATE Latin1_General_CI_AS NULL, [c_first] [char](16) COLLATE Latin1_General_CI_AS NULL, [c_credit] [char](2) COLLATE Latin1_General_CI_AS NULL, [c_balance] [money] NULL, [c_ytd_payment] [money] NULL, [c_payment_cnt] [smallint] NULL, [c_delivery_cnt] [smallint] NULL, [c_street_1] [char](20) COLLATE Latin1_General_CI_AS NULL, [c_street_2] [char](20) COLLATE Latin1_General_CI_AS NULL, [c_city] [char](20) COLLATE Latin1_General_CI_AS NULL, [c_state] [char](2) COLLATE Latin1_General_CI_AS NULL, [c_zip] [char](9) COLLATE Latin1_General_CI_AS NULL, [c_phone] [char](16) COLLATE Latin1_General_CI_AS NULL, [c_since] [datetime] NULL, [c_middle] [char](2) COLLATE Latin1_General_CI_AS NULL, [c_data] [char](500) COLLATE Latin1_General_CI_AS NULL, CONSTRAINT [customer_i1] PRIMARY KEY NONCLUSTERED HASH ([c_id], [c_d_id], [c_w_id]) WITH (BUCKET_COUNT = $cust_bc), INDEX [customer_i2] NONCLUSTERED ([c_last], [c_w_id], [c_d_id], [c_first], [c_id])) WITH (MEMORY_OPTIMIZED = ON, DURABILITY = $durability)}]
set sql(2) [ subst -nocommands {CREATE TABLE [dbo].[district] ( [d_id] [tinyint] NOT NULL, [d_w_id] [int] NOT NULL, [d_ytd] [money] NOT NULL, [d_next_o_id] [int] NULL, [d_tax] [smallmoney] NULL, [d_name] [char](10) COLLATE Latin1_General_CI_AS NULL, [d_street_1] [char](20) COLLATE Latin1_General_CI_AS NULL, [d_street_2] [char](20) COLLATE Latin1_General_CI_AS NULL, [d_city] [char](20) COLLATE Latin1_General_CI_AS NULL, [d_state] [char](2) COLLATE Latin1_General_CI_AS NULL, [d_zip] [char](9) COLLATE Latin1_General_CI_AS NULL, CONSTRAINT [district_i1] PRIMARY KEY NONCLUSTERED HASH ([d_id], [d_w_id]) WITH (BUCKET_COUNT = $dist_bc)) WITH (MEMORY_OPTIMIZED = ON, DURABILITY = $durability)}]
set sql(3) [ subst -nocommands {CREATE TABLE [dbo].[history] ( [h_id] [int] IDENTITY(1,1) NOT NULL, [h_c_id] [int] NOT NULL, [h_c_d_id] [tinyint] NULL, [h_c_w_id] [int] NULL, [h_d_id] [tinyint] NULL, [h_w_id] [int] NULL, [h_date] [datetime] NOT NULL, [h_amount] [smallmoney] NULL, [h_data] [char](24) COLLATE Latin1_General_CI_AS NULL, CONSTRAINT [history_i1] PRIMARY KEY NONCLUSTERED ([h_id])) WITH (MEMORY_OPTIMIZED = ON, DURABILITY = $durability)}]
set sql(4) [ subst -nocommands {CREATE TABLE [dbo].[item] ( [i_id] [int] NOT NULL, [i_name] [char](24) COLLATE Latin1_General_CI_AS NULL, [i_price] [smallmoney] NULL, [i_data] [char](50) COLLATE Latin1_General_CI_AS NULL, [i_im_id] [int] NULL, CONSTRAINT [item_i1]  PRIMARY KEY NONCLUSTERED HASH ([i_id]) WITH (BUCKET_COUNT = $item_bc)) WITH (MEMORY_OPTIMIZED = ON , DURABILITY = $durability)}]
set sql(5) [ subst -nocommands {CREATE TABLE [dbo].[new_order] ( [no_o_id] [int] NOT NULL, [no_d_id] [tinyint] NOT NULL, [no_w_id] [int] NOT NULL, CONSTRAINT [new_order_i1]  PRIMARY KEY NONCLUSTERED HASH ([no_w_id], [no_d_id], [no_o_id]) WITH (BUCKET_COUNT = $neword_bc)) WITH (MEMORY_OPTIMIZED = ON, DURABILITY = $durability)}] 
set sql(6) [ subst -nocommands {CREATE TABLE [dbo].[order_line] ([ol_o_id] [int] NOT NULL, [ol_d_id] [tinyint] NOT NULL, [ol_w_id] [int] NOT NULL, [ol_number] [tinyint] NOT NULL, [ol_i_id] [int] NULL, [ol_delivery_d] [datetime] NULL, [ol_amount] [smallmoney] NULL, [ol_supply_w_id] [int] NULL, [ol_quantity] [smallint] NULL, [ol_dist_info] [char](24) COLLATE Latin1_General_CI_AS NULL, CONSTRAINT [order_line_i1] PRIMARY KEY NONCLUSTERED HASH ([ol_o_id], [ol_d_id], [ol_w_id], [ol_number]) WITH (BUCKET_COUNT = $orderl_bc), INDEX [orderline_i2] NONCLUSTERED ([ol_d_id], [ol_w_id], [ol_o_id])) WITH (MEMORY_OPTIMIZED = ON, DURABILITY = $durability )}]
set sql(7) [ subst -nocommands {CREATE TABLE [dbo].[orders] ( [o_id] [int] NOT NULL, [o_d_id] [tinyint] NOT NULL, [o_w_id] [int] NOT NULL, [o_c_id] [int] NOT NULL, [o_carrier_id] [tinyint] NULL, [o_ol_cnt] [tinyint] NULL, [o_all_local] [tinyint] NULL, [o_entry_d] [datetime] NULL, CONSTRAINT [orders_i1]  PRIMARY KEY NONCLUSTERED HASH ([o_w_id], [o_d_id], [o_id]) WITH (BUCKET_COUNT = $order_bc), INDEX [orders_i2] NONCLUSTERED ([o_c_id], [o_d_id], [o_w_id], [o_id])) WITH (MEMORY_OPTIMIZED = ON , DURABILITY = $durability)}]
set sql(8) [ subst -nocommands {CREATE TABLE [dbo].[stock] ( [s_i_id] [int] NOT NULL, [s_w_id] [int] NOT NULL, [s_quantity] [smallint] NOT NULL, [s_ytd] [int] NOT NULL, [s_order_cnt] [smallint] NULL, [s_remote_cnt] [smallint] NULL, [s_data] [char](50) COLLATE Latin1_General_CI_AS NULL, [s_dist_01] [char](24) COLLATE Latin1_General_CI_AS NULL, [s_dist_02] [char](24) COLLATE Latin1_General_CI_AS NULL, [s_dist_03] [char](24) COLLATE Latin1_General_CI_AS NULL, [s_dist_04] [char](24) COLLATE Latin1_General_CI_AS NULL, [s_dist_05] [char](24) COLLATE Latin1_General_CI_AS NULL, [s_dist_06] [char](24) COLLATE Latin1_General_CI_AS NULL, [s_dist_07] [char](24) COLLATE Latin1_General_CI_AS NULL, [s_dist_08] [char](24) COLLATE Latin1_General_CI_AS NULL, [s_dist_09] [char](24) COLLATE Latin1_General_CI_AS NULL, [s_dist_10] [char](24) COLLATE Latin1_General_CI_AS NULL, CONSTRAINT [stock_i1]  PRIMARY KEY NONCLUSTERED HASH ( [s_i_id], [s_w_id]) WITH (BUCKET_COUNT = $stock_bc)) WITH (MEMORY_OPTIMIZED = ON, DURABILITY = $durability)}]
set sql(9) [ subst -nocommands {CREATE TABLE [dbo].[warehouse] ([w_id] [int] NOT NULL, [w_ytd] [money] NOT NULL, [w_tax] [smallmoney] NOT NULL, [w_name] [char](10) COLLATE Latin1_General_CI_AS NULL, [w_street_1] [char](20) COLLATE Latin1_General_CI_AS NULL, [w_street_2] [char](20) COLLATE Latin1_General_CI_AS NULL, [w_city] [char](20) COLLATE Latin1_General_CI_AS NULL, [w_state] [char](2) COLLATE Latin1_General_CI_AS NULL, [w_zip] [char](9) COLLATE Latin1_General_CI_AS NULL, CONSTRAINT [warehouse_i1]  PRIMARY KEY NONCLUSTERED HASH ([w_id]) WITH (BUCKET_COUNT = $ware_bc)) WITH (MEMORY_OPTIMIZED = ON, DURABILITY = $durability)}]
	} else {
set stmnt_cnt 20 
set sql(1) {CREATE TABLE [dbo].[customer]( [c_id] [int] NOT NULL, [c_d_id] [tinyint] NOT NULL, [c_w_id] [int] NOT NULL, [c_discount] [smallmoney] NULL, [c_credit_lim] [money] NULL, [c_last] [char](16) NULL, [c_first] [char](16) NULL, [c_credit] [char](2) NULL, [c_balance] [money] NULL, [c_ytd_payment] [money] NULL, [c_payment_cnt] [smallint] NULL, [c_delivery_cnt] [smallint] NULL, [c_street_1] [char](20) NULL, [c_street_2] [char](20) NULL, [c_city] [char](20) NULL, [c_state] [char](2) NULL, [c_zip] [char](9) NULL, [c_phone] [char](16) NULL, [c_since] [datetime] NULL, [c_middle] [char](2) NULL, [c_data] [char](500) NULL)}
set sql(2) {CREATE TABLE [dbo].[district]( [d_id] [tinyint] NOT NULL, [d_w_id] [int] NOT NULL, [d_ytd] [money] NOT NULL, [d_next_o_id] [int] NULL, [d_tax] [smallmoney] NULL, [d_name] [char](10) NULL, [d_street_1] [char](20) NULL, [d_street_2] [char](20) NULL, [d_city] [char](20) NULL, [d_state] [char](2) NULL, [d_zip] [char](9) NULL, [padding] [char](6000) NOT NULL, CONSTRAINT [PK_DISTRICT] PRIMARY KEY CLUSTERED ( [d_w_id] ASC, [d_id] ASC) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON))}
set sql(3) {CREATE TABLE [dbo].[history]( [h_c_id] [int] NULL, [h_c_d_id] [tinyint] NULL, [h_c_w_id] [int] NULL, [h_d_id] [tinyint] NULL, [h_w_id] [int] NULL, [h_date] [datetime] NULL, [h_amount] [smallmoney] NULL, [h_data] [char](24) NULL)} 
set sql(4) {CREATE TABLE [dbo].[item]( [i_id] [int] NOT NULL, [i_name] [char](24) NULL, [i_price] [smallmoney] NULL, [i_data] [char](50) NULL, [i_im_id] [int] NULL, CONSTRAINT [PK_ITEM] PRIMARY KEY CLUSTERED ( [i_id] ASC) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON))} 
set sql(5) {CREATE TABLE [dbo].[new_order]( [no_o_id] [int] NOT NULL, [no_d_id] [tinyint] NOT NULL, [no_w_id] [int] NOT NULL)} 
set sql(6) {CREATE TABLE [dbo].[orders]( [o_id] [int] NOT NULL, [o_d_id] [tinyint] NOT NULL, [o_w_id] [int] NOT NULL, [o_c_id] [int] NOT NULL, [o_carrier_id] [tinyint] NULL, [o_ol_cnt] [tinyint] NULL, [o_all_local] [tinyint] NULL, [o_entry_d] [datetime] NULL)} 
set sql(7) {CREATE TABLE [dbo].[order_line]( [ol_o_id] [int] NOT NULL, [ol_d_id] [tinyint] NOT NULL, [ol_w_id] [int] NOT NULL, [ol_number] [tinyint] NOT NULL, [ol_i_id] [int] NULL, [ol_delivery_d] [datetime] NULL, [ol_amount] [smallmoney] NULL, [ol_supply_w_id] [int] NULL, [ol_quantity] [smallint] NULL, [ol_dist_info] [char](24) NULL)} 
set sql(8) {CREATE TABLE [dbo].[stock]( [s_i_id] [int] NOT NULL, [s_w_id] [int] NOT NULL, [s_quantity] [smallint] NOT NULL, [s_ytd] [int] NOT NULL, [s_order_cnt] [smallint] NULL, [s_remote_cnt] [smallint] NULL, [s_data] [char](50) NULL, [s_dist_01] [char](24) NULL, [s_dist_02] [char](24) NULL, [s_dist_03] [char](24) NULL, [s_dist_04] [char](24) NULL, [s_dist_05] [char](24) NULL, [s_dist_06] [char](24) NULL, [s_dist_07] [char](24) NULL, [s_dist_08] [char](24) NULL, [s_dist_09] [char](24) NULL, [s_dist_10] [char](24) NULL, CONSTRAINT [PK_STOCK] PRIMARY KEY CLUSTERED ( [s_w_id] ASC, [s_i_id] ASC) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON))}
set sql(9) {CREATE TABLE [dbo].[warehouse]( [w_id] [int] NOT NULL, [w_ytd] [money] NOT NULL, [w_tax] [smallmoney] NOT NULL, [w_name] [char](10) NULL, [w_street_1] [char](20) NULL, [w_street_2] [char](20) NULL, [w_city] [char](20) NULL, [w_state] [char](2) NULL, [w_zip] [char](9) NULL, [padding] [char](4000) NOT NULL, CONSTRAINT [PK_WAREHOUSE] PRIMARY KEY CLUSTERED ( [w_id] ASC) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON))} 
set sql(10) {ALTER TABLE [dbo].[customer] SET (LOCK_ESCALATION = DISABLE)}
set sql(11) {ALTER TABLE [dbo].[district] SET (LOCK_ESCALATION = DISABLE)}
set sql(12) {ALTER TABLE [dbo].[history] SET (LOCK_ESCALATION = DISABLE)}
set sql(13) {ALTER TABLE [dbo].[item] SET (LOCK_ESCALATION = DISABLE)}
set sql(14) {ALTER TABLE [dbo].[new_order] SET (LOCK_ESCALATION = DISABLE)}
set sql(15) {ALTER TABLE [dbo].[orders] SET (LOCK_ESCALATION = DISABLE)}
set sql(16) {ALTER TABLE [dbo].[order_line] SET (LOCK_ESCALATION = DISABLE)}
set sql(17) {ALTER TABLE [dbo].[stock] SET (LOCK_ESCALATION = DISABLE)}
set sql(18) {ALTER TABLE [dbo].[warehouse] SET (LOCK_ESCALATION = DISABLE)}
set sql(19) {ALTER TABLE [dbo].[district] ADD  CONSTRAINT [DF__DISTRICT__paddin__282DF8C2]  DEFAULT (replicate('X',(6000))) FOR [padding]}
set sql(20) {ALTER TABLE [dbo].[warehouse] ADD  CONSTRAINT [DF__WAREHOUSE__paddi__14270015]  DEFAULT (replicate('x',(4000))) FOR [padding]}
	}
for { set i 1 } { $i <= $stmnt_cnt } { incr i } {
$odbc evaldirect $sql($i)
		}
return
}

proc CreateIndexes { odbc imdb } {
puts "CREATING TPCC INDEXES"
if { $imdb } {
#In-memory Indexes created with tables
   } else {
set sql(1) {CREATE UNIQUE CLUSTERED INDEX [customer_i1] ON [dbo].[customer] ( [c_w_id] ASC, [c_d_id] ASC, [c_id] ASC) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = OFF)}
set sql(2) {CREATE UNIQUE CLUSTERED INDEX [new_order_i1] ON [dbo].[new_order] ( [no_w_id] ASC, [no_d_id] ASC, [no_o_id] ASC) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = OFF)}
set sql(3) {CREATE UNIQUE CLUSTERED INDEX [orders_i1] ON [dbo].[orders] ( [o_w_id] ASC, [o_d_id] ASC, [o_id] ASC) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = OFF)}
set sql(4) {CREATE UNIQUE CLUSTERED INDEX [order_line_i1] ON [dbo].[order_line] ( [ol_w_id] ASC, [ol_d_id] ASC, [ol_o_id] ASC, [ol_number] ASC)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = OFF)} 
set sql(5) {CREATE UNIQUE NONCLUSTERED INDEX [customer_i2] ON [dbo].[customer] ( [c_w_id] ASC, [c_d_id] ASC, [c_last] ASC, [c_id] ASC) INCLUDE ([c_credit], [c_street_1], [c_street_2], [c_city], [c_state], [c_zip], [c_phone], [c_middle], [c_credit_lim], [c_since], [c_discount], [c_first]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = OFF)}
set sql(6) {CREATE NONCLUSTERED INDEX [d_details] ON [dbo].[district] ( [d_id] ASC, [d_w_id] ASC) INCLUDE ([d_name], [d_street_1], [d_street_2], [d_city], [d_state], [d_zip], [padding]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)}
set sql(7) {CREATE NONCLUSTERED INDEX [orders_i2] ON [dbo].[orders] ( [o_w_id] ASC, [o_d_id] ASC, [o_c_id] ASC, [o_id] ASC)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = OFF)}
set sql(8) {CREATE UNIQUE NONCLUSTERED INDEX [w_details] ON [dbo].[warehouse] ( [w_id] ASC) INCLUDE ([w_tax], [w_name], [w_street_1], [w_street_2], [w_city], [w_state], [w_zip], [padding]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = OFF)}
for { set i 1 } { $i <= 8 } { incr i } {
$odbc evaldirect $sql($i)
		}
     }
return
}

proc gettimestamp { } {
	set tstamp [ clock format [ clock seconds ] -format %Y%m%d%H%M%S ]
	return $tstamp
}

proc Customer { odbc d_id w_id CUST_PER_DIST } {
set globArray [ list 0 1 2 3 4 5 6 7 8 9 A B C D E F G H I J K L M N O P Q R S T U V W X Y Z a b c d e f g h i j k l m n o p q r s t u v w x y z ]
set namearr [list BAR OUGHT ABLE PRI PRES ESE ANTI CALLY ATION EING]
set chalen [ llength $globArray ]
set bld_cnt 1
set c_d_id $d_id
set c_w_id $w_id
set c_middle "OE"
set c_balance -10.0
set c_credit_lim 50000
set h_amount 10.0
puts "Loading Customer for DID=$d_id WID=$w_id"
for {set c_id 1} {$c_id <= $CUST_PER_DIST } {incr c_id } {
set c_first [ MakeAlphaString 8 16 $globArray $chalen ]
if { $c_id <= 1000 } {
set c_last [ Lastname [ expr {$c_id - 1} ] $namearr ]
	} else {
set nrnd [ NURand 255 0 999 123 ]
set c_last [ Lastname $nrnd $namearr ]
	}
set c_add [ MakeAddress $globArray $chalen ]
set c_phone [ MakeNumberString ]
if { [RandomNumber 0 1] eq 1 } {
set c_credit "GC"
	} else {
set c_credit "BC"
	}
set disc_ran [ RandomNumber 0 50 ]
set c_discount [ expr {$disc_ran / 100.0} ]
set c_data [ MakeAlphaString 300 500 $globArray $chalen ]
append c_val_list ('$c_id', '$c_d_id', '$c_w_id', '$c_first', '$c_middle', '$c_last', '[ lindex $c_add 0 ]', '[ lindex $c_add 1 ]', '[ lindex $$c_add 2 ]', '[ lindex $c_add 3 ]', '[ lindex $c_add 4 ]', '$c_phone', getdate(), '$c_credit', '$c_credit_lim', '$c_discount', '$c_balance', '$c_data', '10.0', '1', '0')
set h_data [ MakeAlphaString 12 24 $globArray $chalen ]
append h_val_list ('$c_id', '$c_d_id', '$c_w_id', '$c_w_id', '$c_d_id', getdate(), '$h_amount', '$h_data')
if { $bld_cnt<= 1 } { 
append c_val_list ,
append h_val_list ,
	}
incr bld_cnt
if { ![ expr {$c_id % 2} ] } {
$odbc evaldirect "insert into customer (c_id, c_d_id, c_w_id, c_first, c_middle, c_last, c_street_1, c_street_2, c_city, c_state, c_zip, c_phone, c_since, c_credit, c_credit_lim, c_discount, c_balance, c_data, c_ytd_payment, c_payment_cnt, c_delivery_cnt) values $c_val_list"
$odbc evaldirect "insert into history (h_c_id, h_c_d_id, h_c_w_id, h_w_id, h_d_id, h_date, h_amount, h_data) values $h_val_list"
	set bld_cnt 1
	unset c_val_list
	unset h_val_list
		}
	}
puts "Customer Done"
return
}

proc Orders { odbc d_id w_id MAXITEMS ORD_PER_DIST } {
set globArray [ list 0 1 2 3 4 5 6 7 8 9 A B C D E F G H I J K L M N O P Q R S T U V W X Y Z a b c d e f g h i j k l m n o p q r s t u v w x y z ]
set chalen [ llength $globArray ]
set bld_cnt 1
puts "Loading Orders for D=$d_id W=$w_id"
set o_d_id $d_id
set o_w_id $w_id
for {set i 1} {$i <= $ORD_PER_DIST } {incr i } {
set cust($i) $i
}
for {set i 1} {$i <= $ORD_PER_DIST } {incr i } {
set r [ RandomNumber $i $ORD_PER_DIST ]
set t $cust($i)
set cust($i) $cust($r)
set $cust($r) $t
}
set e ""
for {set o_id 1} {$o_id <= $ORD_PER_DIST } {incr o_id } {
set o_c_id $cust($o_id)
set o_carrier_id [ RandomNumber 1 10 ]
set o_ol_cnt [ RandomNumber 5 15 ]
if { $o_id > 2100 } {
set e "o1"
append o_val_list ('$o_id', '$o_c_id', '$o_d_id', '$o_w_id', getdate(), null, '$o_ol_cnt', '1')
set e "no1"
append no_val_list ('$o_id', '$o_d_id', '$o_w_id')
  } else {
  set e "o3"
append o_val_list ('$o_id', '$o_c_id', '$o_d_id', '$o_w_id', getdate(), '$o_carrier_id', '$o_ol_cnt', '1')
	}
for {set ol 1} {$ol <= $o_ol_cnt } {incr ol } {
set ol_i_id [ RandomNumber 1 $MAXITEMS ]
set ol_supply_w_id $o_w_id
set ol_quantity 5
set ol_amount 0.0
set ol_dist_info [ MakeAlphaString 24 24 $globArray $chalen ]
if { $o_id > 2100 } {
set e "ol1"
append ol_val_list ('$o_id', '$o_d_id', '$o_w_id', '$ol', '$ol_i_id', '$ol_supply_w_id', '$ol_quantity', '$ol_amount', '$ol_dist_info', null)
if { $bld_cnt<= 1 } { append ol_val_list , } else {
if { $ol != $o_ol_cnt } { append ol_val_list , }
		}
	} else {
set amt_ran [ RandomNumber 10 10000 ]
set ol_amount [ expr {$amt_ran / 100.0} ]
set e "ol2"
append ol_val_list ('$o_id', '$o_d_id', '$o_w_id', '$ol', '$ol_i_id', '$ol_supply_w_id', '$ol_quantity', '$ol_amount', '$ol_dist_info', getdate())
if { $bld_cnt<= 1 } { append ol_val_list , } else {
if { $ol != $o_ol_cnt } { append ol_val_list , }
		}
	}
}
if { $bld_cnt<= 1 } {
append o_val_list ,
if { $o_id > 2100 } {
append no_val_list ,
		}
        }
incr bld_cnt
 if { ![ expr {$o_id % 2} ] } {
 if { ![ expr {$o_id % 1000} ] } {
	puts "...$o_id"
	}
$odbc evaldirect "insert into orders (o_id, o_c_id, o_d_id, o_w_id, o_entry_d, o_carrier_id, o_ol_cnt, o_all_local) values $o_val_list"
if { $o_id > 2100 } {
$odbc evaldirect "insert into new_order (no_o_id, no_d_id, no_w_id) values $no_val_list"
	}
$odbc evaldirect "insert into order_line (ol_o_id, ol_d_id, ol_w_id, ol_number, ol_i_id, ol_supply_w_id, ol_quantity, ol_amount, ol_dist_info, ol_delivery_d) values $ol_val_list"
	set bld_cnt 1
	unset o_val_list
	unset -nocomplain no_val_list
	unset ol_val_list
			}
		}
	puts "Orders Done"
	return
}

proc LoadItems { odbc MAXITEMS } {
set globArray [ list 0 1 2 3 4 5 6 7 8 9 A B C D E F G H I J K L M N O P Q R S T U V W X Y Z a b c d e f g h i j k l m n o p q r s t u v w x y z ]
set chalen [ llength $globArray ]
puts "Loading Item"
for {set i 0} {$i < [ expr {$MAXITEMS/10} ] } {incr i } {
set orig($i) 0
}
for {set i 0} {$i < [ expr {$MAXITEMS/10} ] } {incr i } {
set pos [ RandomNumber 0 $MAXITEMS ] 
set orig($pos) 1
	}
for {set i_id 1} {$i_id <= $MAXITEMS } {incr i_id } {
set i_im_id [ RandomNumber 1 10000 ] 
set i_name [ MakeAlphaString 14 24 $globArray $chalen ]
set i_price_ran [ RandomNumber 100 10000 ]
set i_price [ format "%4.2f" [ expr {$i_price_ran / 100.0} ] ]
set i_data [ MakeAlphaString 26 50 $globArray $chalen ]
if { [ info exists orig($i_id) ] } {
if { $orig($i_id) eq 1 } {
set first [ RandomNumber 0 [ expr {[ string length $i_data] - 8}] ]
set last [ expr {$first + 8} ]
set i_data [ string replace $i_data $first $last "original" ]
	}
}
	$odbc evaldirect "insert into item (i_id, i_im_id, i_name, i_price, i_data) VALUES ('$i_id', '$i_im_id', '$i_name', '$i_price', '$i_data')"
      if { ![ expr {$i_id % 50000} ] } {
	puts "Loading Items - $i_id"
			}
		}
	puts "Item done"
	return
	}

proc Stock { odbc w_id MAXITEMS } {
set globArray [ list 0 1 2 3 4 5 6 7 8 9 A B C D E F G H I J K L M N O P Q R S T U V W X Y Z a b c d e f g h i j k l m n o p q r s t u v w x y z ]
set chalen [ llength $globArray ]
set bld_cnt 1
puts "Loading Stock Wid=$w_id"
set s_w_id $w_id
for {set i 0} {$i < [ expr {$MAXITEMS/10} ] } {incr i } {
set orig($i) 0
}
for {set i 0} {$i < [ expr {$MAXITEMS/10} ] } {incr i } {
set pos [ RandomNumber 0 $MAXITEMS ] 
set orig($pos) 1
	}
for {set s_i_id 1} {$s_i_id <= $MAXITEMS } {incr s_i_id } {
set s_quantity [ RandomNumber 10 100 ]
set s_dist_01 [ MakeAlphaString 24 24 $globArray $chalen ]
set s_dist_02 [ MakeAlphaString 24 24 $globArray $chalen ]
set s_dist_03 [ MakeAlphaString 24 24 $globArray $chalen ]
set s_dist_04 [ MakeAlphaString 24 24 $globArray $chalen ]
set s_dist_05 [ MakeAlphaString 24 24 $globArray $chalen ]
set s_dist_06 [ MakeAlphaString 24 24 $globArray $chalen ]
set s_dist_07 [ MakeAlphaString 24 24 $globArray $chalen ]
set s_dist_08 [ MakeAlphaString 24 24 $globArray $chalen ]
set s_dist_09 [ MakeAlphaString 24 24 $globArray $chalen ]
set s_dist_10 [ MakeAlphaString 24 24 $globArray $chalen ]
set s_data [ MakeAlphaString 26 50 $globArray $chalen ]
if { [ info exists orig($s_i_id) ] } {
if { $orig($s_i_id) eq 1 } {
set first [ RandomNumber 0 [ expr {[ string length $s_data]} - 8 ] ]
set last [ expr {$first + 8} ]
set s_data [ string replace $s_data $first $last "original" ]
		}
	}
append val_list ('$s_i_id', '$s_w_id', '$s_quantity', '$s_dist_01', '$s_dist_02', '$s_dist_03', '$s_dist_04', '$s_dist_05', '$s_dist_06', '$s_dist_07', '$s_dist_08', '$s_dist_09', '$s_dist_10', '$s_data', '0', '0', '0')
if { $bld_cnt<= 1 } { 
append val_list ,
}
incr bld_cnt
      if { ![ expr {$s_i_id % 2} ] } {
$odbc evaldirect "insert into stock (s_i_id, s_w_id, s_quantity, s_dist_01, s_dist_02, s_dist_03, s_dist_04, s_dist_05, s_dist_06, s_dist_07, s_dist_08, s_dist_09, s_dist_10, s_data, s_ytd, s_order_cnt, s_remote_cnt) values $val_list"
	set bld_cnt 1
	unset val_list
	}
      if { ![ expr {$s_i_id % 20000} ] } {
	puts "Loading Stock - $s_i_id"
			}
	}
	puts "Stock done"
	return
}

proc District { odbc w_id DIST_PER_WARE } {
set globArray [ list 0 1 2 3 4 5 6 7 8 9 A B C D E F G H I J K L M N O P Q R S T U V W X Y Z a b c d e f g h i j k l m n o p q r s t u v w x y z ]
set chalen [ llength $globArray ]
puts "Loading District"
set d_w_id $w_id
set d_ytd 30000.0
set d_next_o_id 3001
for {set d_id 1} {$d_id <= $DIST_PER_WARE } {incr d_id } {
set d_name [ MakeAlphaString 6 10 $globArray $chalen ]
set d_add [ MakeAddress $globArray $chalen ]
set d_tax_ran [ RandomNumber 10 20 ]
set d_tax [ string replace [ format "%.2f" [ expr {$d_tax_ran / 100.0} ] ] 0 0 "" ]
$odbc evaldirect "insert into district (d_id, d_w_id, d_name, d_street_1, d_street_2, d_city, d_state, d_zip, d_tax, d_ytd, d_next_o_id) values ('$d_id', '$d_w_id', '$d_name', '[ lindex $d_add 0 ]', '[ lindex $d_add 1 ]', '[ lindex $d_add 2 ]', '[ lindex $d_add 3 ]', '[ lindex $d_add 4 ]', '$d_tax', '$d_ytd', '$d_next_o_id')"
	}
	puts "District done"
	return
}

proc LoadWare { odbc ware_start count_ware MAXITEMS DIST_PER_WARE } {
set globArray [ list 0 1 2 3 4 5 6 7 8 9 A B C D E F G H I J K L M N O P Q R S T U V W X Y Z a b c d e f g h i j k l m n o p q r s t u v w x y z ]
set chalen [ llength $globArray ]
puts "Loading Warehouse"
set w_ytd 3000000.00
for {set w_id $ware_start } {$w_id <= $count_ware } {incr w_id } {
set w_name [ MakeAlphaString 6 10 $globArray $chalen ]
set add [ MakeAddress $globArray $chalen ]
set w_tax_ran [ RandomNumber 10 20 ]
set w_tax [ string replace [ format "%.2f" [ expr {$w_tax_ran / 100.0} ] ] 0 0 "" ]
$odbc evaldirect "insert into warehouse (w_id, w_name, w_street_1, w_street_2, w_city, w_state, w_zip, w_tax, w_ytd) values ('$w_id', '$w_name', '[ lindex $add 0 ]', '[ lindex $add 1 ]', '[ lindex $add 2 ]' , '[ lindex $add 3 ]', '[ lindex $add 4 ]', '$w_tax', '$w_ytd')"
	Stock $odbc $w_id $MAXITEMS
	District $odbc $w_id $DIST_PER_WARE
	}
}

proc LoadCust { odbc ware_start count_ware CUST_PER_DIST DIST_PER_WARE } {
for {set w_id $ware_start} {$w_id <= $count_ware } {incr w_id } {
for {set d_id 1} {$d_id <= $DIST_PER_WARE } {incr d_id } {
	Customer $odbc $d_id $w_id $CUST_PER_DIST
		}
	}
	return
}

proc LoadOrd { odbc ware_start count_ware MAXITEMS ORD_PER_DIST DIST_PER_WARE } {
for {set w_id $ware_start} {$w_id <= $count_ware } {incr w_id } {
for {set d_id 1} {$d_id <= $DIST_PER_WARE } {incr d_id } {
	Orders $odbc $d_id $w_id $MAXITEMS $ORD_PER_DIST
		}
	}
	return
}

proc connect_string { server port odbc_driver authentication uid pwd tcp azure db } {
if { $tcp eq "true" } { set server tcp:$server,$port }
if {[ string toupper $authentication ] eq "WINDOWS" } {
set connection "DRIVER=$odbc_driver;SERVER=$server;TRUSTED_CONNECTION=YES"
} else {
if {[ string toupper $authentication ] eq "SQL" } {
set connection "DRIVER=$odbc_driver;SERVER=$server;UID=$uid;PWD=$pwd"
        } else {
puts stderr "Error: neither WINDOWS or SQL Authentication has been specified"
set connection "DRIVER=$odbc_driver;SERVER=$server"
        }
}
if { $azure eq "true" } { append connection ";" "DATABASE=$db" }
return $connection
}

proc do_tpcc { server port odbc_driver authentication uid pwd tcp azure count_ware db imdb bucket_factor durability num_vu } {
set MAXITEMS 100000
set CUST_PER_DIST 3000
set DIST_PER_WARE 10
set ORD_PER_DIST 3000
set connection [ connect_string $server $port $odbc_driver $authentication $uid $pwd $tcp $azure $db ]
if { $num_vu > $count_ware } { set num_vu $count_ware }
if { $num_vu > 1 && [ chk_thread ] eq "TRUE" } {
set threaded "MULTI-THREADED"
set rema [ lassign [ findvuposition ] myposition totalvirtualusers ]
switch $myposition {
        1 {
puts "Monitor Thread"
if { $threaded eq "MULTI-THREADED" } {
tsv::lappend common thrdlst monitor
for { set th 1 } { $th <= $totalvirtualusers } { incr th } {
tsv::lappend common thrdlst idle
                        }
tsv::set application load "WAIT"
                }
        }
        default {
puts "Worker Thread"
if { [ expr $myposition - 1 ] > $count_ware } { puts "No Warehouses to Create"; return }
     }
   }
} else {
set threaded "SINGLE-THREADED"
set num_vu 1
  }
if { $threaded eq "SINGLE-THREADED" ||  $threaded eq "MULTI-THREADED" && $myposition eq 1 } {
puts "CREATING [ string toupper $db ] SCHEMA"
if [catch {tdbc::odbc::connection create odbc $connection} message ] {
error "Connection to $connection could not be established : $message"
 } else {
CreateDatabase odbc $db $imdb $azure 
if {!$azure} {odbc evaldirect "use $db"}
CreateTables odbc $imdb $count_ware $bucket_factor $durability
}
if { $threaded eq "MULTI-THREADED" } {
tsv::set application load "READY"
LoadItems odbc $MAXITEMS
puts "Monitoring Workers..."
set prevactive 0
while 1 {
set idlcnt 0; set lvcnt 0; set dncnt 0;
for {set th 2} {$th <= $totalvirtualusers } {incr th} {
switch [tsv::lindex common thrdlst $th] {
idle { incr idlcnt }
active { incr lvcnt }
done { incr dncnt }
        }
}
if { $lvcnt != $prevactive } {
puts "Workers: $lvcnt Active $dncnt Done"
        }
set prevactive $lvcnt
if { $dncnt eq [expr  $totalvirtualusers - 1] } { break }
after 10000
}} else {
LoadItems odbc $MAXITEMS
}}
if { $threaded eq "SINGLE-THREADED" ||  $threaded eq "MULTI-THREADED" && $myposition != 1 } {
if { $threaded eq "MULTI-THREADED" } {
puts "Waiting for Monitor Thread..."
set mtcnt 0
while 1 {
if { [ tsv::exists application load ] } {
incr mtcnt
if {  [ tsv::get application load ] eq "READY" } { break }
if { $mtcnt eq 48 } {
puts "Monitor failed to notify ready state"
return
        }
}
after 5000
}
if [catch {tdbc::odbc::connection create odbc $connection} message ] {
error "Connection to $connection could not be established : $message"
 } else {
if {!$azure} {odbc evaldirect "use $db"}
odbc evaldirect "set implicit_transactions OFF"
} 
set remb [ lassign [ findchunk $num_vu $count_ware $myposition ] chunk mystart myend ]
puts "Loading $chunk Warehouses start:$mystart end:$myend"
tsv::lreplace common thrdlst $myposition $myposition active
} else {
set mystart 1
set myend $count_ware
}
puts "Start:[ clock format [ clock seconds ] ]"
LoadWare odbc $mystart $myend $MAXITEMS $DIST_PER_WARE
LoadCust odbc $mystart $myend $CUST_PER_DIST $DIST_PER_WARE
LoadOrd odbc $mystart $myend $MAXITEMS $ORD_PER_DIST $DIST_PER_WARE
puts "End:[ clock format [ clock seconds ] ]"
if { $threaded eq "MULTI-THREADED" } {
tsv::lreplace common thrdlst $myposition $myposition done
        }
}
if { $threaded eq "SINGLE-THREADED" || $threaded eq "MULTI-THREADED" && $myposition eq 1 } {
CreateIndexes odbc $imdb 
CreateStoredProcs odbc $imdb 
UpdateStatistics odbc $db $azure
puts "[ string toupper $db ] SCHEMA COMPLETE"
odbc close
return
		}
	}
do_tpcc {sql} 1433 {SQL Server Native Client 11.0} windows sa admin true false 320 TPCC false 1 SCHEMA_AND_DATA 3

