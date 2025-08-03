-- Задача 2: Сезонность объявлений

-- Описание:
-- Цель этого анализа — выявить сезонные закономерности в активности на рынке недвижимости. Мы хотим понять, в какие месяцы чаще всего публикуются и снимаются объявления, а также как изменяются средняя стоимость квадратного метра и площадь жилья в зависимости от времени года.

-- Вопросы, на которые отвечает запрос:
-- Когда происходит пик размещения и снятия объявлений?
-- Совпадают ли периоды активной публикации и продажи недвижимости?
-- Как соотносятся параметры квартир (цена за квадратный метр, площадь) в разные месяцы?

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
adv_start AS (
    SELECT 
        EXTRACT(MONTH FROM first_day_exposition) AS month_start,
        EXTRACT(YEAR FROM first_day_exposition) AS year_start,
        COUNT(*) AS count_adv_st,
        (COUNT(*) * 100.0 / SUM(COUNT(*)) OVER())::NUMERIC(5,2) AS share_adv_st,
        AVG(last_price / total_area)::NUMERIC(10,2) AS avg_price_per_qm_st,
        AVG(total_area)::NUMERIC(6,2) AS avg_total_area_st,
        RANK() OVER (ORDER BY COUNT(*) DESC) AS st_rank
    FROM real_estate.advertisement
    JOIN real_estate.flats AS f USING(id)
    WHERE id IN (SELECT * FROM filtered_id) AND type_id = 'F8EM'
      AND EXTRACT(YEAR FROM first_day_exposition) NOT IN (2014, 2019)
    GROUP BY year_start, month_start
),
adv_end AS (
    SELECT 
        EXTRACT(MONTH FROM first_day_exposition + days_exposition * INTERVAL '1 day') AS month_end,
        EXTRACT(YEAR FROM first_day_exposition + days_exposition * INTERVAL '1 day') AS year_end,
        COUNT(*) AS count_adv_end,
        (COUNT(*) * 100.0 / SUM(COUNT(*)) OVER())::NUMERIC(5,2) AS share_adv_end,
        AVG(last_price / total_area)::NUMERIC(10,2) AS avg_price_per_qm_end,
        AVG(total_area)::NUMERIC(6,2) AS avg_total_area_end,
        RANK() OVER (ORDER BY COUNT(*) DESC) AS end_rank
    FROM real_estate.advertisement
    JOIN real_estate.flats AS f USING(id)
    WHERE id IN (SELECT * FROM filtered_id) AND type_id = 'F8EM'
      AND days_exposition IS NOT NULL
      AND EXTRACT(YEAR FROM first_day_exposition + days_exposition * INTERVAL '1 day') NOT IN (2014, 2019)
    GROUP BY year_end, month_end
)
SELECT 
    year_start AS year,
    month_start AS month,
    count_adv_st,
    share_adv_st,
    avg_price_per_qm_st,
    avg_total_area_st,
    st_rank,
    count_adv_end,
    share_adv_end,
    avg_price_per_qm_end,
    avg_total_area_end,
    end_rank
FROM adv_start a
FULL OUTER JOIN adv_end b 
    ON a.year_start = b.year_end AND a.month_start = b.month_end
ORDER BY year, month;