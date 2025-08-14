    -- Query 1: created a View and joined all the 3 tables
CREATE VIEW forestation AS
SELECT 
    fo.*,
    la.total_area_sq_mi * 2.59 as total_area_sqkm,
    r.region,
    r.income_group,
    (fo.forest_area_sqkm / (la.total_area_sq_mi * 2.59)) * 100 AS forest_percent
FROM forest_area AS fo
JOIN land_area AS la 
    ON la.country_code = fo.country_code
   AND fo.year = la.year
JOIN regions AS r 
    ON fo.country_code = r.country_code;

-- Query 2: the total forest area of the world in 1990
SELECT 
year, 
forest_area_sqkm
FROM forestation
WHERE year = '1990' and country_name = 'World';

-- Query 3: the total forest area of the world in 2016
SELECT 
year, 
forest_area_sqkm
FROM forestation
WHERE year = '2016' and country_name = 'World';

-- Query 4: to find out the change and the percentage of change
WITH table1 AS (
    SELECT
        year,
        forest_area_sqkm
    FROM forestation
    WHERE year = '1990'
      AND country_name = 'World'
),
table2 AS (
    SELECT
        year,
        forest_area_sqkm
    FROM forestation
    WHERE year = '2016'
      AND country_name = 'World'
)
SELECT
    table1.forest_area_sqkm - table2.forest_area_sqkm AS chaange,
    TRUNC(
        CAST(
            ABS(table2.forest_area_sqkm - table1.forest_area_sqkm) / table1.forest_area_sqkm * 100
            AS numeric
        ),
        4
    ) AS per_change
FROM table1, table2;

-- Query 5: to find out which country's total area in 2016 is closest to the amount of forest area lost between 1990 and 2016
WITH table1 AS (
    SELECT
        year,
        forest_area_sqkm
    FROM forestation
    WHERE year = '1990'
      AND country_name = 'World'
),
table2 AS (
    SELECT
        year,
        forest_area_sqkm
    FROM forestation
    WHERE year = '2016'
      AND country_name = 'World'
),
table3 AS (
    SELECT
        table1.forest_area_sqkm - table2.forest_area_sqkm AS lost
    FROM table1, table2
)
SELECT
    country_name,
    year,
    ROUND(total_area_sqkm)
FROM
    forestation,
    table3
WHERE
    total_area_sqkm >= table3.lost
    AND year = 2016
ORDER BY
    total_area_sqkm ASC
LIMIT 1;

-- Query 6: percent forest of the entire world in 2016, the region with the highest percent forest in 2016 and the region with the lowest
WITH table1 AS (
    SELECT
        region,
        SUM(forest_area_sqkm) AS forest_area,
        SUM(total_area_sqkm) AS land_area
    FROM
        forestation
    GROUP BY
        region,
        year
    HAVING
        year = 2016
)
SELECT
    region,
    ROUND((table1.forest_area / table1.land_area * 100)::numeric, 2) AS per
FROM
    table1
ORDER BY
    per;

-- Query 6 (variant): percent forest of the entire world in 2016, the region with the highest percent forest in 1990 and the region with the lowest
WITH table1 AS (
    SELECT
        region,
        SUM(forest_area_sqkm) AS forest_area,
        SUM(total_area_sqkm) AS land_area
    FROM
        forestation
    GROUP BY
        region,
        year
    HAVING
        year = 1990	
)
SELECT
    region,
    ROUND((table1.forest_area / table1.land_area * 100)::numeric, 2) AS per
FROM
    table1
ORDER BY
    per;

-- Query 7: regions of the world that decreased in forest area from 1990 to 2016
WITH table1 AS (
    SELECT
        region,
        SUM(forest_area_sqkm) AS forest_area,
        SUM(total_area_sqkm) AS land_area
    FROM
        forestation
    GROUP BY
        region,
        year
    HAVING
        year = 2016
),
table2 AS (
    SELECT
        region,
        SUM(forest_area_sqkm) AS forest_area,
        SUM(total_area_sqkm) AS land_area
    FROM
        forestation
    GROUP BY
        region,
        year
    HAVING
        year = 1990
)
SELECT
    table1.region,
    ROUND((table1.forest_area / table1.land_area * 100)::numeric, 2) AS per2016,
    ROUND((table2.forest_area / table2.land_area * 100)::numeric, 2) AS per1990
FROM
    table1
JOIN
    table2 ON table1.region = table2.region;

-- Query 8: top countries decreased in forest area and top countries decreased in percentage
WITH table1 AS (
    SELECT
        country_code,
        country_name,
        region,
        year,
        forest_area_sqkm
    FROM forestation
    WHERE year = 2016
),
table2 AS (
    SELECT
        country_code,
        country_name,
        region,
        year,
        forest_area_sqkm
    FROM forestation
    WHERE year = 1990
),
table3 AS (
    SELECT
        table1.country_name,
        table1.region,
        table1.forest_area_sqkm AS forest_area_2016,
        table2.forest_area_sqkm AS forest_area_1990
    FROM table1
    JOIN table2
        ON table1.country_code = table2.country_code
)
SELECT
    country_name,
    region,
    ROUND((forest_area_2016 - forest_area_1990)::numeric, 2) AS forest_area_change,
    ROUND(((forest_area_2016 - forest_area_1990) / forest_area_1990 * 100)::numeric, 2) AS per_Change
FROM table3
WHERE forest_area_2016 IS NOT NULL
  AND forest_area_1990 IS NOT NULL
ORDER BY 4 ASC;

-- Query 9: count of countries grouped by forestation percent quartiles, 2016
WITH table1 AS (
    SELECT
        country_name,
        CASE
            WHEN forest_percent < 25 THEN '0-25%'
            WHEN forest_percent >= 25 AND forest_percent < 50 THEN '25-50%'
            WHEN forest_percent >= 50 AND forest_percent < 75 THEN '50-75%'
            ELSE '75-100%'
        END AS quartile
    FROM forestation
    WHERE year = 2016
      AND forest_percent IS NOT NULL
)
SELECT
    quartile,
    COUNT(*) AS number_of_Countries
FROM table1
GROUP BY 1;

-- Query 10: top quartile countries in 2016
WITH table1 AS (
    SELECT
        country_name,
        region,
        ROUND(forest_percent::numeric, 2),
        CASE
            WHEN forest_percent < 25 THEN '0-25%'
            WHEN forest_percent >= 25 AND forest_percent < 50 THEN '25-50%'
            WHEN forest_percent >= 50 AND forest_percent < 75 THEN '50-75%'
            ELSE '75-100%'
        END AS quartile
    FROM forestation
    WHERE year = 2016
      AND forest_percent IS NOT NULL
)
SELECT * 
FROM table1
WHERE quartile = '75-100%'
ORDER BY 3 DESC;