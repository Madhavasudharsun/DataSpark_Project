use dataspark;
SELECT * FROM customers;
SELECT * FROM products;
SELECT * FROM sales;
SELECT * FROM stores;
SELECT * FROM exchange_rates;
describe customers;
describe sales;

#Customer Distribution by Continent, Gender_1
WITH AgeCalculation AS (SELECT CustomerKey,Gender,FLOOR(DATEDIFF(CURDATE(), STR_TO_DATE(Birthday, '%Y-%m-%d')) / 365) AS Age,Continent,
        CASE
            WHEN FLOOR(DATEDIFF(CURDATE(), STR_TO_DATE(Birthday, '%Y-%m-%d')) / 365) < 20 THEN 'Below 20'
            WHEN FLOOR(DATEDIFF(CURDATE(), STR_TO_DATE(Birthday, '%Y-%m-%d')) / 365) BETWEEN 20 AND 40 THEN '20-40'
            ELSE 'Above 40'
        END AS AgeGroup FROM customers)
SELECT Continent,Gender,AgeGroup,COUNT(CustomerKey) AS CustomerCount,
    (SELECT COUNT(*) FROM customers) AS TotalCustomers
FROM AgeCalculation
GROUP BY Continent, Gender, AgeGroup
ORDER BY CustomerCount DESC;
#purchasing pattern = frequency of purchases seasonwise, preferred products_2
WITH OrderDetails AS (SELECT s.order_number,s.order_date,c.Country,s.ProductKey,p.product_name,p.Brand,p.Color,s.Quantity,(s.Quantity * p.unit_price) AS TotalSpending
    FROM sales s JOIN products p ON s.ProductKey = p.ProductKey JOIN customers c ON s.CustomerKey = c.CustomerKey),
SeasonalOrderDetails AS (SELECT order_number,order_date,Country,ProductKey,product_name,Brand,Color,Quantity,TotalSpending,
        CASE
            WHEN MONTH(order_date) IN (11, 12, 1, 2, 3) THEN 'Nov-Mar'
            WHEN MONTH(order_date) IN (4, 5, 6, 7) THEN 'Apr-Jul'
            ELSE 'Aug-Oct'
        END AS Season
    FROM OrderDetails)
SELECT Country,Season,product_name,Brand,Color,
    COUNT(order_number) AS TotalOrders,
    SUM(Quantity) AS TotalQuantitySold,
    SUM(TotalSpending) AS TotalSpending
FROM SeasonalOrderDetails GROUP BY Country, Season, product_name, Brand, Color ORDER BY TotalOrders DESC, TotalQuantitySold DESC, TotalSpending DESC;
# Country-wise Product Sales, Ordered by Month_3
SELECT 
    c.Country,
    DATE_FORMAT(s.order_date, '%Y-%m') AS OrderMonth,
    COUNT(s.order_number) AS TotalOrders,
    SUM(s.Quantity) AS TotalQuantitySold,
    SUM(s.Quantity * p.unit_price) AS TotalRevenueGenerated
FROM sales s
JOIN products p ON s.ProductKey = p.ProductKey
JOIN customers c ON s.CustomerKey = c.CustomerKey
GROUP BY c.Country, DATE_FORMAT(s.order_date, '%Y-%m')
ORDER BY DATE_FORMAT(s.order_date, '%Y-%m'), SUM(s.Quantity) DESC;

#Sales by Currency, Considering Exchange Rates and how products are affected_4
WITH SalesWithExchange AS (
    SELECT s.order_number,s.order_date,s.ProductKey,p.product_name,p.Brand,p.Color,s.Quantity,s.currency_code,e.Exchange AS ExchangeRate,
        (s.Quantity * p.unit_price * e.Exchange) AS TotalSpendingInUSD
    FROM sales s
    JOIN products p ON s.ProductKey = p.ProductKey
    JOIN exchange_rates e ON s.currency_code = e.Currency AND DATE(s.order_date) = DATE(e.Date))
SELECT currency_code,product_name,Brand,Color,
    COUNT(DISTINCT order_number) AS TotalOrders,
    SUM(Quantity) AS TotalQuantitySold,
    SUM(TotalSpendingInUSD) AS TotalRevenueInUSD
FROM SalesWithExchange
GROUP BY currency_code, product_name, Brand, Color
ORDER BY TotalRevenueInUSD DESC, TotalQuantitySold DESC;
#Continent-wise and Age-wise Product Orders_5
WITH CustomerDetails AS (
    SELECT 
        c.CustomerKey,
        c.Continent,
        c.Birthday,
        FLOOR(DATEDIFF(CURDATE(), STR_TO_DATE(c.Birthday, '%Y-%m-%d')) / 365) AS Age
    FROM customers c
),
AgeGroups AS (
    SELECT
        CustomerKey,
        Continent,
        CASE
            WHEN Age BETWEEN 20 AND 40 THEN '20-40'
            WHEN Age > 40 THEN 'Above 40'
        END AS AgeGroup
    FROM CustomerDetails
    WHERE Age BETWEEN 20 AND 40 OR Age > 40
),
OrderDetails AS (
    SELECT 
        s.order_number,
        s.CustomerKey,
        s.ProductKey,
        p.product_name,
        p.Brand,
        p.Color,
        s.Quantity
    FROM sales s
    JOIN products p ON s.ProductKey = p.ProductKey
),
AggregatedData AS (
    SELECT 
        ag.Continent,
        ag.AgeGroup,
        od.product_name,
        od.Brand,
        od.Color,
        COUNT(DISTINCT od.order_number) AS TotalOrders,
        SUM(od.Quantity) AS TotalQuantitySold
    FROM AgeGroups ag
    JOIN OrderDetails od ON ag.CustomerKey = od.CustomerKey
    GROUP BY ag.Continent, ag.AgeGroup, od.product_name, od.Brand, od.Color
)
SELECT 
    Continent,
    AgeGroup,
    product_name,
    Brand,
    Color,
    TotalOrders,
    TotalQuantitySold
FROM AggregatedData
ORDER BY TotalOrders DESC, TotalQuantitySold DESC;
#Most and Least Preferred Products_6
WITH ProductSales AS (
    SELECT 
        p.ProductKey,
        p.product_name,
        p.Brand,
        p.Color,
        SUM(s.Quantity) AS TotalQuantitySold,
        SUM(s.Quantity * p.unit_price) AS TotalRevenueGenerated
    FROM sales s
    JOIN products p ON s.ProductKey = p.ProductKey
    GROUP BY p.ProductKey, p.product_name, p.Brand, p.Color
)
SELECT 
    product_name,
    Brand,
    Color,
    TotalQuantitySold,
    TotalRevenueGenerated
FROM ProductSales
ORDER BY TotalQuantitySold DESC, TotalRevenueGenerated DESC;
#profit margins_7
WITH ProductSales AS (
    SELECT 
        p.ProductKey,
        p.product_name,
        p.Brand,
        p.Color,
        p.unit_cost,
        p.unit_price,
        SUM(s.Quantity) AS TotalQuantitySold,
        SUM(s.Quantity * p.unit_price) AS TotalRevenue,
        SUM(s.Quantity * p.unit_cost) AS TotalCost,
        SUM(s.Quantity * (p.unit_price - p.unit_cost)) AS TotalProfit
    FROM sales s
    JOIN products p ON s.ProductKey = p.ProductKey
    GROUP BY p.ProductKey, p.product_name, p.Brand, p.Color, p.unit_cost, p.unit_price
)
SELECT 
    product_name,
    Brand,
    Color,
    TotalQuantitySold,
    TotalRevenue,
    TotalCost,
    TotalProfit,
    (TotalProfit / TotalRevenue) * 100 AS ProfitMarginPercentage
FROM ProductSales
ORDER BY ProfitMarginPercentage DESC;
#Category Analysis_8
WITH SalesData AS (
    SELECT 
        p.CategoryKey,
        p.SubtextKey,
        p.Category,
        p.Subtext,
        p.product_name,
        p.Brand,
        p.unit_cost,
        p.unit_price,
        SUM(s.Quantity) AS TotalQuantitySold,
        SUM(s.Quantity * p.unit_price) AS TotalRevenue,
        SUM(s.Quantity * p.unit_cost) AS TotalCost,
        SUM(s.Quantity * (p.unit_price - p.unit_cost)) AS TotalProfit
    FROM sales s
    JOIN products p ON s.ProductKey = p.ProductKey
    GROUP BY p.CategoryKey, p.SubtextKey, p.Category, p.Subtext, p.product_name, p.Brand, p.unit_cost, p.unit_price
)
SELECT 
    Category,
    Subtext,
    SUM(TotalQuantitySold) AS TotalQuantitySold,
    SUM(TotalRevenue) AS TotalRevenue,
    SUM(TotalCost) AS TotalCost,
    SUM(TotalProfit) AS TotalProfit,
    (SUM(TotalProfit) / SUM(TotalRevenue)) * 100 AS ProfitMarginPercentage
FROM SalesData
GROUP BY Category, Subtext
ORDER BY TotalRevenue DESC, TotalProfit DESC;
#Store Performance_9
WITH StoreSales AS (
    SELECT 
        st.StoreKey,
        st.Country,
        st.State,
        st.square_meters,
        st.open_date,
        SUM(sl.Quantity) AS TotalQuantitySold,
        SUM(sl.Quantity * p.unit_price) AS TotalRevenue,
        DATEDIFF(CURDATE(), st.open_date) / 365 AS StoreAgeYears
    FROM sales sl
    JOIN stores st ON sl.StoreKey = st.StoreKey
    JOIN products p ON sl.ProductKey = p.ProductKey
    GROUP BY st.StoreKey, st.Country, st.State, st.square_meters, st.open_date
),
PerformanceMetrics AS (
    SELECT 
        StoreKey,
        Country,
        State,
        square_meters,
        open_date,
        TotalQuantitySold,
        TotalRevenue,
        StoreAgeYears,
        TotalRevenue / square_meters AS RevenuePerSquareMeter
    FROM StoreSales
)
SELECT 
    StoreKey,
    Country,
    State,
    square_meters,
    open_date,
    TotalQuantitySold,
    TotalRevenue,
    StoreAgeYears,
    RevenuePerSquareMeter
FROM PerformanceMetrics
ORDER BY TotalRevenue DESC, RevenuePerSquareMeter DESC, StoreAgeYears DESC;
#Analyze sales by store location to identify high-performing regions_10
WITH RegionalSales AS (
    SELECT 
        st.Country,
        st.State,
        SUM(sl.Quantity) AS TotalQuantitySold,
        SUM(sl.Quantity * p.unit_price) AS TotalRevenue,
        COUNT(DISTINCT sl.StoreKey) AS NumberOfStores
    FROM sales sl
    JOIN stores st ON sl.StoreKey = st.StoreKey
    JOIN products p ON sl.ProductKey = p.ProductKey
    GROUP BY st.Country, st.State
),
RegionalPerformance AS (
    SELECT 
        Country,
        State,
        TotalQuantitySold,
        TotalRevenue,
        NumberOfStores,
        CASE
            WHEN NumberOfStores > 0 THEN TotalRevenue / NumberOfStores
            ELSE 0
        END AS RevenuePerStore
    FROM RegionalSales
)
SELECT 
    Country,
    State,
    TotalQuantitySold,
    TotalRevenue,
    NumberOfStores,
    RevenuePerStore
FROM RegionalPerformance
ORDER BY TotalRevenue DESC, TotalQuantitySold DESC, RevenuePerStore DESC;




