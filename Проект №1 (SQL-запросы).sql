/* Проект: анализ данных для игры
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Логинов Павел Александрович
 * Дата: 04.12.2024
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
-- Напишите ваш запрос здесь

SELECT COUNT(id) AS count_id, 
	   COUNT(CASE 
		   		 WHEN payer = 1 THEN 1 
		   		 END) AS count_payer_1, 
	   ROUND(COUNT(CASE WHEN payer = 1 THEN 1 END)::numeric/COUNT(*), 5) AS proportion_count_payer_1
	   FROM fantasy.users;
 
-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
-- Напишите ваш запрос здесь

SELECT race,
       COUNT(id) AS count_id, 
	   COUNT(CASE 
		   		 WHEN payer = 1 THEN 1 
		   		 END) AS count_payer_1, 
	   ROUND(COUNT(CASE WHEN payer = 1 THEN 1 END)::numeric/COUNT(*), 5) AS proportion_count_payer_1
	   FROM fantasy.users
	   LEFT JOIN fantasy.race USING(race_id)
	   GROUP BY race
	   ORDER BY count_id DESC;
	  
-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
-- Напишите ваш запрос здесь

SELECT COUNT(transaction_id) AS count_transaction_id,
       SUM(amount) AS sum_amount,
       MIN(amount) AS min_amount,
       ROUND(MAX(amount)::numeric, 2) AS max_amount,
       ROUND(AVG(amount)::numeric, 2) AS avg_amount,
       PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY amount) AS median_amount,
       ROUND(STDDEV(amount)::numeric, 2) AS stand_dev_amount
       FROM fantasy.events;
	   
-- 2.2: Аномальные нулевые покупки:
-- Напишите ваш запрос здесь

SELECT COUNT(transaction_id) AS count_transaction_id,
       COUNT(CASE 
	       		 WHEN amount = 0 THEN 1 
	       		 END) AS count_transaction_id_0,
       ROUND(COUNT(CASE WHEN amount = 0 THEN 1 END)/COUNT(amount)::NUMERIC, 5) AS proportion_count_transaction_id_0
	   FROM fantasy.events;
      
-- 2.3: Сравнительный анализ активности платящих и неплатящих игроков:
-- Напишите ваш запрос здесь

WITH a AS (SELECT id, COUNT(transaction_id) AS count_transaction_id, SUM(amount) AS sum_amount
			 FROM fantasy.events
			 WHERE amount <> 0
			 GROUP BY id)
SELECT payer, 
       COUNT(id) AS count_id,
       AVG(count_transaction_id) AS avg_count_transaction_id,
       AVG(sum_amount) AS avg_sum_amount
FROM a
LEFT JOIN fantasy.users USING(id)
GROUP BY payer;
	    
-- 2.4: Популярные эпические предметы:
-- Напишите ваш запрос здесь

WITH a AS (SELECT item_code,
	   COUNT(transaction_id) AS count_transaction_id,
	   COUNT(DISTINCT id) AS distinct_count_id
FROM fantasy.events
GROUP BY item_code)
SELECT item_code, 
			 count_transaction_id,
			 ROUND(count_transaction_id::numeric/SUM(count_transaction_id) OVER (), 7) AS proportion_transaction_id,
			 ROUND(distinct_count_id::numeric/(SELECT COUNT(DISTINCT id) AS count_id FROM fantasy.events), 7) AS proportion_distinct_count_id
FROM a
ORDER BY count_transaction_id DESC;

-- Часть 2. Решение ad hoc-задач
-- Задача 1. Зависимость активности игроков от расы персонажа:
-- Напишите ваш запрос здесь

WITH a AS (SELECT race_id, 
                  race,
                  COUNT(id) AS count_id
           FROM fantasy.race
           LEFT JOIN fantasy.users USING(race_id)
           GROUP BY race_id, race),       
a0 AS (SELECT race_id, 
                  race,
                  COUNT(DISTINCT events.id) AS count_id_payer_0
           FROM fantasy.race
           LEFT JOIN fantasy.users USING(race_id)
           LEFT JOIN fantasy.events USING(id)
           WHERE payer = 0
           GROUP BY race_id, race),
a1 AS (SELECT race_id, 
                  race,
                  COUNT(DISTINCT events.id) AS count_id_payer_1
           FROM fantasy.race
           LEFT JOIN fantasy.users USING(race_id)
           LEFT JOIN fantasy.events USING(id)
           WHERE payer = 1
           GROUP BY race_id, race),          
b AS (SELECT race_id,
             race,
             ROUND(count_id_payer_0::numeric/count_id, 5) AS proportion_count_id_payer_0,
             ROUND(count_id_payer_1::numeric/count_id_payer_0, 5) AS proportion_count_id_payer_1
             FROM a
             LEFT JOIN a0 USING(race_id, race)
             LEFT JOIN a1 USING(race_id, race)),
c AS (SELECT id,
			 race_id,
			 race,
             COUNT(transaction_id) AS count_transaction_id,
             AVG(amount) AS avg_amount,
             SUM(amount) AS sum_amount
             FROM fantasy.race
             LEFT JOIN fantasy.users USING(race_id)
             LEFT JOIN fantasy.events USING(id)
             WHERE amount <> 0
             GROUP BY id, race_id, race)
SELECT race_id,
	   race,
	   count_id,
	   count_id_payer_0, proportion_count_id_payer_0,
	   count_id_payer_1, proportion_count_id_payer_1, 
	   AVG(count_transaction_id) AS avg_count_transaction_id,
	   AVG(sum_amount)/AVG(count_transaction_id) AS avg2_amount,
	   AVG(sum_amount) AS avg_sum_amount
FROM a
LEFT JOIN a0 USING(race_id, race)
LEFT JOIN a1 USING(race_id, race)
LEFT JOIN b USING(race_id, race)
LEFT JOIN c USING(race_id, race)
GROUP BY race_id, race, count_id, count_id_payer_0, proportion_count_id_payer_0, count_id_payer_1, proportion_count_id_payer_1
ORDER BY count_id DESC;