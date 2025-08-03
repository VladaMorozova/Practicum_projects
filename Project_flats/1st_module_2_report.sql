/* Проект первого модуля: анализ данных для агентства недвижимости
 * Часть 2. Решаем ad hoc задачи
 * 
 * Автор: Чучалина Влада Викторовна
 * Дата: 27.01.2025 
*/

-- Пример фильтрации данных от аномальных значений
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
-- Найдем id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    )
-- Выведем объявления без выбросов:
SELECT *
FROM real_estate.flats
WHERE id IN (SELECT * FROM filtered_id);


-- Задача 1: Время активности объявлений
-- Результат запроса должен ответить на такие вопросы:
-- 1. Какие сегменты рынка недвижимости Санкт-Петербурга и городов Ленинградской области 
--    имеют наиболее короткие или длинные сроки активности объявлений?
-- 2. Какие характеристики недвижимости, включая площадь недвижимости, среднюю стоимость квадратного метра, 
--    количество комнат и балконов и другие параметры, влияют на время активности объявлений? 
--    Как эти зависимости варьируют между регионами?
-- 3. Есть ли различия между недвижимостью Санкт-Петербурга и Ленинградской области по полученным результатам?

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
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
-- Выведем объявления без выбросов:
 inf_flat  AS (SELECT  
					CASE 
		 				WHEN city = 'Санкт-Петербург' THEN 'Санкт-Петербург'
	 					ELSE 'ЛенОбл'		
						END AS city_category, -- Вводим категорию по городу
					CASE 
						WHEN days_exposition IS NULL THEN 'Не продано'
		 				WHEN days_exposition BETWEEN 1 and 30 THEN 'Месяц'
		 				WHEN days_exposition BETWEEN 31 and 90 THEN 'Квартал'
		 				WHEN days_exposition BETWEEN 91 and 180 THEN 'Полгода'
	 					ELSE 'Больше полугода'		
					END AS days_category,   -- Вводим категорию по длительности об-ия
						-- Подсчет данных 
						COUNT(id) as count_adv, -- кол-во об-ий 
						-- Ольга.... извините, за грубое кодирование (поиск доли непроданное нед-ии), просто я код этот писала еще в декабре и сейчас лень что-то новое выдумывать!!! :З
						(SUM(CASE WHEN days_exposition IS NULL THEN 1 ELSE 0 END) * 100.0 / 
						(SELECT COUNT(id) 
						FROM real_estate.flats AS f 
						JOIN real_estate.advertisement AS a USING(id) 
						JOIN real_estate.city AS c USING(city_id) 
						WHERE id IN (SELECT * FROM filtered_id) AND type_id = 'F8EM'))::NUMERIC(4,1) AS unsold, -- доля неснятых об-ий
						AVG(last_price / total_area)::numeric(8) AS avg_price_per_qm,  											-- стоимость за 1 кв м
						AVG(total_area)::numeric(5,2) AS avg_total_area,														-- средняя площадь кв
						PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY rooms) AS median_rooms,										-- среднее кол-во комнат 
						PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY balcony) AS median_balc, 									-- среднее кол-во балконов 
    					PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY floors_total) AS median_floors,								-- среднее этажность кв 
    					SUM(is_apartment) as count_apart																		-- кол-во апартаментов 
			FROM real_estate.flats AS f
			JOIN real_estate.city AS c USING(city_id)
			JOIN real_estate.advertisement AS a USING(id) 
			WHERE id IN (SELECT * FROM filtered_id) AND type_id = 'F8EM' -- Отсеиваем аномальные данные и все id вне городов
			GROUP BY city_category, days_category)
SELECT *
FROM inf_flat;

-- Задача 2: Сезонность объявлений
-- Результат запроса должен ответить на такие вопросы:
-- 1. В какие месяцы наблюдается наибольшая активность в публикации объявлений о продаже недвижимости? 
--    А в какие — по снятию? Это показывает динамику активности покупателей.
-- 2. Совпадают ли периоды активной публикации объявлений и периоды, 
--    когда происходит повышенная продажа недвижимости (по месяцам снятия объявлений)?
-- 3. Как сезонные колебания влияют на среднюю стоимость квадратного метра и среднюю площадь квартир? 
--    Что можно сказать о зависимости этих параметров от месяца?

WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS (
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
adv_start AS (
    SELECT 
    		EXTRACT(MONTH FROM first_day_exposition) AS month_start,    
    		EXTRACT(YEAR FROM first_day_exposition) AS year_start,
        	COUNT(*) AS count_adv_st, -- Кол-во об-ний
        	(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER())::NUMERIC(5,2) AS share_adv_st, -- Доля от всех об-ний
        	AVG(last_price / total_area)::NUMERIC(10,2) AS avg_price_per_qm_st, -- средняя стоимость квадратного метра
        	AVG(total_area)::NUMERIC(6,2) AS avg_total_area_st, -- средняя площадь квартир
        	RANK() OVER (ORDER BY COUNT(*) DESC) AS st_rank -- Ранжирование по количеству размещений об-ий
    FROM real_estate.advertisement
    JOIN real_estate.flats AS f USING(id)
		WHERE id IN (SELECT * FROM filtered_id) AND type_id = 'F8EM' -- Отсеиваем аномальные данные и все id вне городов
        AND EXTRACT(YEAR FROM first_day_exposition) NOT IN (2014, 2019) -- Исключаем года без полных данных
        GROUP BY year_start, month_start
),
adv_end AS (
    SELECT 
    		EXTRACT(MONTH FROM first_day_exposition + days_exposition * INTERVAL '1 day') AS month_end,    
    		EXTRACT(YEAR FROM first_day_exposition + days_exposition * INTERVAL '1 day') AS year_end,
        	COUNT(*) AS count_adv_end, -- Кол-во об-ний
        	(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER())::NUMERIC(5,2) AS share_adv_end, -- Доля от всех об-ний
        	AVG(last_price / total_area)::NUMERIC(10,2) AS avg_price_per_qm_end, -- средняя стоимость квадратного метра
            AVG(total_area)::NUMERIC(6,2) AS avg_total_area_end, -- средняя площадь квартир
        	RANK() OVER (ORDER BY COUNT(*) DESC) AS end_rank -- Ранжирование по количеству снятий об-ий
    FROM real_estate.advertisement
    JOIN real_estate.flats AS f USING(id)
		WHERE id IN (SELECT * FROM filtered_id) AND type_id = 'F8EM' -- Отсеиваем аномальные данные и все id вне городов
        AND days_exposition IS NOT NULL
        AND EXTRACT(YEAR FROM first_day_exposition + days_exposition * INTERVAL '1 day') NOT IN (2014, 2019) -- Исключаем года без полных данных
        GROUP BY year_end, month_end
)
			SELECT 
    			year_start AS year,
    			month_start AS month,
    			count_adv_st,                   -- Кол-во об-ний выложенных
    			share_adv_st,                -- доля от всех об-ний выложенных
    			avg_price_per_qm_st,     -- средняя стоимость квадратного метра
    			avg_total_area_st,         -- средняя площадь квартир
    			st_rank,               -- Ранжирование по количеству размещений об-ий
    			count_adv_end,               -- Кол-во об-ний снятых
    			share_adv_end,               -- доля от всех об-ний снятых
    			avg_price_per_qm_end,  -- средняя стоимость квадратного метра
    			avg_total_area_end,        -- средняя площадь квартир
    			end_rank              -- Ранжирование по количеству снятий об-ий
 			FROM adv_start a
			FULL OUTER JOIN adv_end b ON a.year_start = b.year_end AND a.month_start = b.month_end
			ORDER BY year, month;

-- Задача 3: Анализ рынка недвижимости Ленобласти
-- Результат запроса должен ответить на такие вопросы:
-- 1. В каких населённые пунктах Ленинградской области наиболее активно публикуют объявления о продаже недвижимости?
-- 2. В каких населённых пунктах Ленинградской области — самая высокая доля снятых с публикации объявлений? 
--    Это может указывать на высокую долю продажи недвижимости.
-- 3. Какова средняя стоимость одного квадратного метра и средняя площадь продаваемых квартир в различных населённых пунктах? 
--    Есть ли вариация значений по этим метрикам?
-- 4. Среди выделенных населённых пунктов какие пункты выделяются по продолжительности публикации объявлений? 
--    То есть где недвижимость продаётся быстрее, а где — медленнее.

WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
-- Выведем объявления без выбросов:
lenobl_inf AS (SELECT  city,
					COUNT(id) AS adv_count,
					((COUNT(days_exposition)::numeric / COUNT(id))*100)::numeric(4,1) AS sold, 
					AVG(last_price / total_area)::numeric(8) AS avg_price_per_qm,                                                 -- средняя стоимость квадратного метра
					AVG(total_area)::numeric(5,2) AS avg_total_area,                                                             -- средняя площадь квартир
					(AVG(days_exposition) / 30)::NUMERIC(3,1) AS avg_months_dur                                     -- cредняя продолжительность публикации
			FROM real_estate.flats AS f
			JOIN real_estate.city AS c USING(city_id)
			JOIN real_estate.advertisement AS a USING(id) 
			WHERE id IN (SELECT * FROM filtered_id) AND city != 'Санкт-Петербург' -- Отсеиваем аномальные данные и спб
			GROUP BY city)
SELECT  city, 
		adv_count, 
		sold, 
		avg_price_per_qm, 
		avg_total_area, 
		avg_months_dur
FROM lenobl_inf
ORDER BY adv_count DESC
LIMIT 15; 
