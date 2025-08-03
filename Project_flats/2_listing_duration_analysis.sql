-- Задача 1: Время активности объявлений

-- Цель — понять, как характеристики квартир и локации влияют на длительность размещения объявления на сайте.

-- Запрос отвечает на следующие вопросы:
-- 1. Какие типы недвижимости продаются быстрее или дольше в Санкт-Петербурге и Ленобласти?
-- 2. Какие параметры (площадь, стоимость, этажность, число комнат и балконов) влияют на срок продажи?
-- 3. Есть ли различия по времени экспозиции между объектами в Петербурге и области?

-- Результатом является таблица, где для каждого сегмента по локации и сроку активности рассчитываются:
-- Количество объявлений;
-- Доля непроданных объектов;
-- Средняя стоимость за м²;
-- Средняя площадь;
-- Медианное количество комнат и балконов, этажность;
-- Количество апартаментов.

-- Данные очищаются от аномальных значений перед анализом.

-- Определяем выбросы по ключевым числовым параметрам
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
inf_flat AS (
    SELECT
        CASE 
            WHEN city = 'Санкт-Петербург' THEN 'Санкт-Петербург'
            ELSE 'ЛенОбл'
        END AS city_category,
        CASE
            WHEN days_exposition IS NULL THEN 'Не продано'
            WHEN days_exposition BETWEEN 1 AND 30 THEN 'Месяц'
            WHEN days_exposition BETWEEN 31 AND 90 THEN 'Квартал'
            WHEN days_exposition BETWEEN 91 AND 180 THEN 'Полгода'
            ELSE 'Больше полугода'
        END AS days_category,
        COUNT(id) AS count_adv,
        (SUM(CASE WHEN days_exposition IS NULL THEN 1 ELSE 0 END) * 100.0 / 
         (SELECT COUNT(id)
          FROM real_estate.flats AS f
          JOIN real_estate.advertisement AS a USING(id)
          JOIN real_estate.city AS c USING(city_id)
          WHERE id IN (SELECT * FROM filtered_id) AND type_id = 'F8EM'))::NUMERIC(4,1) AS unsold,
        AVG(last_price / total_area)::NUMERIC(8,2) AS avg_price_per_qm,
        AVG(total_area)::NUMERIC(5,2) AS avg_total_area,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY rooms) AS median_rooms,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY balcony) AS median_balc,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY floors_total) AS median_floors,
        SUM(is_apartment) AS count_apart
    FROM real_estate.flats AS f
    JOIN real_estate.city AS c USING(city_id)
    JOIN real_estate.advertisement AS a USING(id)
    WHERE id IN (SELECT * FROM filtered_id)
      AND type_id = 'F8EM'
    GROUP BY city_category, days_category
)
SELECT *
FROM inf_flat;