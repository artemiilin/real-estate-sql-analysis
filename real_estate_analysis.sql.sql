-- Проект. Анализ данных для агентства недвижимости

-- Задача 1: Время активности объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:

WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
filtered_id AS (
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND (
            (ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
             AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits))
            OR ceiling_height IS NULL
        )
)
,parameters AS (
    SELECT 
        f.id
        ,a.days_exposition
        ,a.last_price
        ,f.total_area
        ,f.rooms
        ,f.balcony
        ,f.floor
        ,c.city
        ,t.type
        ,a.last_price / f.total_area AS price_one_square
    FROM real_estate.flats f
    JOIN real_estate.advertisement a ON a.id = f.id
    JOIN real_estate.type t ON t.type_id = f.type_id
    JOIN real_estate.city c ON c.city_id = f.city_id 
    WHERE 
        a.id IN (SELECT id FROM filtered_id) AND t.type = 'город' AND EXTRACT(YEAR FROM a.first_day_exposition) BETWEEN 2015 AND 2018
)
,categories AS (
    SELECT 
        *
        ,CASE 
            WHEN city = 'Санкт-Петербург' THEN 'Санкт-Петербург' 
            ELSE 'ЛенОбл'
        END AS region

        ,CASE 
            WHEN days_exposition IS NULL THEN 'non category'
            WHEN days_exposition BETWEEN 1 AND 30 THEN 'до месяца'
            WHEN days_exposition BETWEEN 31 AND 90 THEN 'до трёх месяцев' 
            WHEN days_exposition BETWEEN 91 AND 180 THEN 'до полугода'
            ELSE 'более полугода'
        END AS segment_active

        ,CASE 
            WHEN days_exposition BETWEEN 1 AND 30 THEN 1
            WHEN days_exposition BETWEEN 31 AND 90 THEN 2 
            WHEN days_exposition BETWEEN 91 AND 180 THEN 3
            WHEN days_exposition > 180 THEN 4
            ELSE 5
        END AS segment_order
    FROM parameters
)
SELECT
    region
    ,segment_active
    ,ROUND(AVG(price_one_square)::numeric, 2) AS "Средняя стоимость кв.метра"
    ,ROUND(AVG(total_area)::numeric, 2) AS "Средняя площадь"
    ,PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY rooms) AS "Медиана кол-ва комнат"
    ,PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY balcony) AS "Медиана кол-ва балконов"
    ,PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY floor) AS "Медиана этажности"
FROM categories
GROUP BY region, segment_active, segment_order
ORDER BY region, segment_order;


-- Задача 2: Сезонность объявлений

-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
filtered_id AS (
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND (
            (ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
             AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits))
            OR ceiling_height IS NULL
        )
)
,months AS (
    SELECT
        a.id
        ,EXTRACT(MONTH FROM a.first_day_exposition) AS publish_month
		,CASE 
            WHEN a.days_exposition IS NOT NULL
            THEN EXTRACT(MONTH FROM a.first_day_exposition + a.days_exposition * INTERVAL '1 day')
        END AS finish_month
		,f.total_area
        ,a.last_price / NULLIF(f.total_area, 0) AS price_one_square
    FROM real_estate.advertisement a
    JOIN real_estate.flats f ON a.id = f.id
    JOIN real_estate.type t ON f.type_id = t.type_id
    WHERE 
        a.id IN (SELECT id FROM filtered_id) AND t.type = 'город' AND EXTRACT(YEAR FROM a.first_day_exposition) BETWEEN 2015 AND 2018
)
,publish_stats AS (
    SELECT
        publish_month AS month
        ,COUNT(*) AS publish_ads
        ,ROUND(AVG(price_one_square)::numeric, 2) AS avg_price_one_square
        ,ROUND(AVG(total_area)::numeric, 2) AS avg_total_area
    FROM months
    GROUP BY publish_month
)
,finish_stats AS (
    SELECT
        finish_month AS month
        ,COUNT(*) AS finish_ads
    FROM months
    WHERE finish_month IS NOT NULL
    GROUP BY finish_month
)
SELECT
    p.month AS "Месяц"
    ,p.publish_ads AS "Кол-во опубликованных объявлений"
    ,f.finish_ads AS "Кол-во снятых объявлений"
    ,p.avg_price_one_square AS "Средняя стоимость кв.метра"
    ,p.avg_total_area AS "Средняя площадь недвижимости"
FROM publish_stats p
LEFT JOIN finish_stats f USING (month)
ORDER BY p.month;







