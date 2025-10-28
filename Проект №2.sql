/* Проект: анализ данных для агентства недвижимости
 * Цель: изучить рынок недвижимости 
 * и найти самые перспективные сегменты недвижимости 
 * в Санкт-Петербурге и Ленинградской области
 * 
 * Автор: Логинов Павел Александрович
 * Дата: 29.12.2024
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

-- Напишите ваш запрос здесь

WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
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
c AS (SELECT id, CASE
		   WHEN city_id = '6X8I' THEN 'Санкт-Петербург'
		   ELSE 'ЛенОбл'
		   END AS category_city
		   FROM real_estate.flats),
d AS (SELECT id, CASE WHEN days_exposition IS NULL THEN 'незакрытое объявление'
	   	   WHEN days_exposition BETWEEN 1 AND 30 THEN 'до месяца'
	   	   WHEN days_exposition BETWEEN 31 AND 90 THEN 'до трёх месяцев'
	   	   WHEN days_exposition BETWEEN 91 AND 180 THEN 'до шести месяцев'
	   	   ELSE 'от 6 месяцев'
	   	   END AS category_days_exposition
	       FROM real_estate.advertisement),
e AS (SELECT category_city, COUNT(id) OVER (PARTITION BY category_city) AS count_category_city
      FROM real_estate.flats
      LEFT JOIN c USING(id)
      GROUP BY category_city, id),
f AS (SELECT id, CASE WHEN rooms = 0 THEN 'Cтудия'
			WHEN rooms = 1 THEN '1-комнатная квартира'
         	WHEN rooms = 2 THEN '2-комнатная квартира'
         	WHEN rooms = 3 THEN '3-комнатная квартира'
         	ELSE 'В квартире больше 3-х комнат' END AS count_rooms
         	FROM real_estate.flats)
SELECT category_city,
       category_days_exposition,
       count_rooms,
	       COUNT(id) AS count_id,
		   AVG(last_price/total_area) AS avg_cost_per_meter,
		   AVG(total_area) AS avg_total_area,
		   ROUND(AVG(rooms)::numeric, 2) AS avg_rooms,
		   PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY rooms) AS median_rooms,
		   ROUND(AVG(balcony)::numeric, 2) AS avg_balcony,
		   PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY balcony) AS median_balcony,
		   ROUND(AVG(ceiling_height)::numeric, 2) AS avg_ceiling_height,
		   PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY ceiling_height) AS median_ceiling_height
FROM real_estate.flats
LEFT JOIN real_estate.advertisement USING(id)
LEFT JOIN c USING(id)
LEFT JOIN d USING(id)
LEFT JOIN f USING(id)
WHERE id IN (SELECT * FROM filtered_id) AND type_id = 'F8EM' AND days_exposition IS NOT NULL
GROUP BY category_city, category_days_exposition, count_rooms;

-- Задача 2: Сезонность объявлений
-- Результат запроса должен ответить на такие вопросы:
-- 1. В какие месяцы наблюдается наибольшая активность в публикации объявлений о продаже недвижимости? 
--    А в какие — по снятию? Это показывает динамику активности покупателей.
-- 2. Совпадают ли периоды активной публикации объявлений и периоды, 
--    когда происходит повышенная продажа недвижимости (по месяцам снятия объявлений)?
-- 3. Как сезонные колебания влияют на среднюю стоимость квадратного метра и среднюю площадь квартир? 
--    Что можно сказать о зависимости этих параметров от месяца?

-- Напишите ваш запрос здесь

-- Публикация объявлений
      
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
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
SELECT CASE WHEN DATE_PART('month', first_day_exposition) = 1 THEN 'Январь'
			WHEN DATE_PART('month', first_day_exposition) = 2 THEN 'Февраль'
			WHEN DATE_PART('month', first_day_exposition) = 3 THEN 'Март'
			WHEN DATE_PART('month', first_day_exposition) = 4 THEN 'Апрель'
			WHEN DATE_PART('month', first_day_exposition) = 5 THEN 'Май'
			WHEN DATE_PART('month', first_day_exposition) = 6 THEN 'Июнь'
			WHEN DATE_PART('month', first_day_exposition) = 7 THEN 'Июль'
			WHEN DATE_PART('month', first_day_exposition) = 8 THEN 'Август'
			WHEN DATE_PART('month', first_day_exposition) = 9 THEN 'Сентябрь'
			WHEN DATE_PART('month', first_day_exposition) = 10 THEN 'Октябрь'
			WHEN DATE_PART('month', first_day_exposition) = 11 THEN 'Ноябрь'
			ELSE 'Декабрь'
			END AS month_first_exposition, 
      COUNT(id) AS count_id_month_first_exposition,
      AVG(last_price/total_area) AS avg_cost_per_meter,
      AVG(total_area) AS avg_total_area
      FROM real_estate.advertisement
      LEFT JOIN real_estate.flats USING(id)
      WHERE id IN (SELECT * FROM filtered_id) AND type_id = 'F8EM' 
      GROUP BY DATE_PART('month', first_day_exposition)
      ORDER BY count_id_month_first_exposition DESC;

-- Снятие объявлений  

WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
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
SELECT CASE WHEN DATE_PART('month', first_day_exposition + cast(days_exposition as int)) = 1 THEN 'Январь'
			WHEN DATE_PART('month', first_day_exposition + cast(days_exposition as int)) = 2 THEN 'Февраль'
			WHEN DATE_PART('month', first_day_exposition + cast(days_exposition as int)) = 3 THEN 'Март'
			WHEN DATE_PART('month', first_day_exposition + cast(days_exposition as int)) = 4 THEN 'Апрель'
			WHEN DATE_PART('month', first_day_exposition + cast(days_exposition as int)) = 5 THEN 'Май'
			WHEN DATE_PART('month', first_day_exposition + cast(days_exposition as int)) = 6 THEN 'Июнь'
			WHEN DATE_PART('month', first_day_exposition + cast(days_exposition as int)) = 7 THEN 'Июль'
			WHEN DATE_PART('month', first_day_exposition + cast(days_exposition as int)) = 8 THEN 'Август'
			WHEN DATE_PART('month', first_day_exposition + cast(days_exposition as int)) = 9 THEN 'Сентябрь'
			WHEN DATE_PART('month', first_day_exposition + cast(days_exposition as int)) = 10 THEN 'Октябрь'
			WHEN DATE_PART('month', first_day_exposition + cast(days_exposition as int)) = 11 THEN 'Ноябрь'
			ELSE 'Декабрь'
			END AS date_sale,
      COUNT(id) AS count_id_month_sale,
      AVG(last_price/total_area) AS avg_cost_per_meter,
      AVG(total_area) AS avg_total_area
      FROM real_estate.advertisement
      LEFT JOIN real_estate.flats USING(id)
      WHERE id IN (SELECT * FROM filtered_id) AND type_id = 'F8EM' AND days_exposition IS NOT NULL
      GROUP BY DATE_PART('month', first_day_exposition + cast(days_exposition as int))
      ORDER BY count_id_month_sale DESC;

-- Задача 3: Анализ рынка недвижимости Ленобласти
-- Результат запроса должен ответить на такие вопросы:
-- 1. В каких населённые пунктах Ленинградской области наиболее активно публикуют объявления о продаже недвижимости?
-- 2. В каких населённых пунктах Ленинградской области — самая высокая доля снятых с публикации объявлений? 
--    Это может указывать на высокую долю продажи недвижимости.
-- 3. Какова средняя стоимость одного квадратного метра и средняя площадь продаваемых квартир в различных населённых пунктах? 
--    Есть ли вариация значений по этим метрикам?
-- 4. Среди выделенных населённых пунктов какие пункты выделяются по продолжительности публикации объявлений? 
--    То есть где недвижимость продаётся быстрее, а где — медленнее.

-- Напишите ваш запрос здесь
      
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
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
SELECT city, 
	   COUNT(id) AS count_id,
	   COUNT(CASE 
		   		 WHEN days_exposition IS NOT NULL THEN 1 
		   		 END) AS count_null,
	   ROUND(COUNT(CASE WHEN days_exposition IS NOT NULL THEN 1 END)::numeric/COUNT(id), 4) AS proportion,
	   AVG(last_price/total_area) AS avg_cost_per_meter,
       AVG(total_area) AS avg_total_area,
       AVG(days_exposition) AS avg_days_exposition
	   FROM real_estate.city
	   LEFT JOIN real_estate.flats USING(city_id)
	   LEFT JOIN real_estate.TYPE USING(type_id)
	   LEFT JOIN real_estate.advertisement USING(id)
	   WHERE id IN (SELECT * FROM filtered_id) AND city <> 'Санкт-Петербург'
	   GROUP BY city
	   ORDER BY count_id DESC
	   LIMIT 15;
