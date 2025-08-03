# Анализ рынка недвижимости СПб и Ленинградской области 

Этот проект представляет собой набор SQL-запросов для анализа рынка недвижимости. Исследование включает фильтрацию выбросов, анализ продолжительности публикации объявлений, сезонность рынка и анализ по населённым пунктам. А также доработку существующего дашборда по требованиям заказчика.

## 📊 Цель

Помочь агентству недвижимости выявить закономерности в активности пользователей, сезонные изменения, а также получить инсайты по различным регионам.

## 📂 Структура проекта

- [`01_outlier_filtering.sql`](https://github.com/VladaMorozova/Practicum_projects/blob/main/Project_flats/1_outlier_filtering.sql) — фильтрация аномалий (выбросов) в данных
- [`02_listing_duration_analysis.sql`](https://github.com/VladaMorozova/Practicum_projects/blob/main/Project_flats/2_listing_duration_analysis.sql) — анализ длительности размещения объявлений
- [`03_seasonality_analysis.sql`](https://github.com/VladaMorozova/Practicum_projects/blob/main/Project_flats/3_seasonality_analysis.sql) — исследование сезонных трендов
- [`04_lenobl_market_analysis.sql`](https://github.com/VladaMorozova/Practicum_projects/blob/main/Project_flats/4_lenobl_market_analysis.sql) — анализ рынка недвижимости Ленобласти

## 🧰 Используемые технологии

- SQL (PostgreSQL)
- DBeaver для написания и тестирования запросов
- [Datalens](https://datalens.yandex.cloud/xmxz3e9t9e3yj-dashbord-dlya-agentstva-nedvizhimosti?tab=aW)

## Общий вывод

🔹 Наиболее активный рынок недвижимости — в Санкт-Петербурге и ближайших пригородах.

🔹 Большинство объектов продаются в срок до полугода.

🔹 Лучше всего продаются квартиры площадью 50–60 м² по цене 90–100 тыс. руб./м².

🔹 Сезонная активность наблюдается весной и осенью — в эти периоды размещают и снимают больше объявлений.

🔹 Апартаменты имеют низкий спрос — чаще остаются непроданными или продаются дольше.
