-- Задача 3: Ленинградская область — активность и параметры

-- Описание:
-- Проводился локальный анализ по Ленинградской области. Мы изучаем, в каких населённых пунктах чаще всего размещаются объявления, где они снимаются быстрее и как отличаются параметры недвижимости в разрезе городов.

-- Вопросы, на которые отвечает запрос:
-- Какие города лидируют по количеству объявлений?
-- Где самая высокая доля снятых объявлений (проданных объектов)?
-- В каких городах недвижимость дешевле или дороже?
-- Где квартиры в среднем продаются быстрее?

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
),
lenobl_inf AS (
    SELECT  
        city,
        COUNT(id) AS adv_count,
        ((COUNT(days_exposition)::NUMERIC / COUNT(id)) * 100)::NUMERIC(4,1) AS sold,
        AVG(last_price / total_area)::NUMERIC(8) AS avg_price_per_qm,
        AVG(total_area)::NUMERIC(5,2) AS avg_total_area,
        (AVG(days_exposition) / 30)::NUMERIC(3,1) AS avg_months_dur
    FROM real_estate.flats AS f
    JOIN real_estate.city AS c USING(city_id)
    JOIN real_estate.advertisement AS a USING(id)
    WHERE id IN (SELECT * FROM filtered_id) AND city != 'Санкт-Петербург'
    GROUP BY city
)
SELECT 
    city,
    adv_count,
    sold,
    avg_price_per_qm,
    avg_total_area,
    avg_months_dur
FROM lenobl_inf
ORDER BY adv_count DESC
LIMIT 15;