---시간대별 이용량 쿼리
SELECT
strftime('%H', 대여일시) AS hour,
COUNT(*) AS rental_count
FROM "서울특별시_공공자전거_대여이력_정보"
GROUP BY hour
ORDER BY rental_count;

---요일별 이용량 쿼리
SELECT
    CASE strftime('%w', 대여일시)
        WHEN '0' THEN '일요일'
        WHEN '1' THEN '월요일'
        WHEN '2' THEN '화요일'
        WHEN '3' THEN '수요일'
        WHEN '4' THEN '목요일'
        WHEN '5' THEN '금요일'
        WHEN '6' THEN '토요일'
    END AS weekday,
    COUNT(*) AS rental_count
FROM "서울특별시_공공자전거_대여이력_정보"
GROUP BY strftime('%w', 대여일시)
ORDER BY strftime('%w', 대여일시);

---대여소별 수요 분석 쿼리
SELECT
  "대여 대여소명" AS station_name,
  COUNT(*) AS rental_count
FROM "서울특별시_공공자전거_대여이력_정보"
GROUP BY "대여 대여소명"
ORDER BY rental_count DESC
LIMIT 20;

---이용 평균 시간 쿼리
SELECT
  ROUND(AVG("이용시간"), 2) AS "평균 이용시간(분)"
FROM "서울특별시_공공자전거_대여이력_정보"
WHERE "이용시간" IS NOT NULL;

---인기 대여소 상위 쿼리
SELECT
  "대여 대여소명" AS station_name,
  COUNT(*) AS rental_count
FROM "서울특별시_공공자전거_대여이력_정보"
WHERE "대여 대여소명" IS NOT NULL
  AND "대여 대여소명" != ''
  AND "대여 대여소명" != '\\N'
GROUP BY "대여 대여소명"
ORDER BY rental_count DESC
LIMIT 10;

---수급 불균형(순유출 상위) 쿼리
WITH rentals AS (
  SELECT "대여 대여소명" AS station_name, COUNT(*) AS rental_count
  FROM "서울특별시_공공자전거_대여이력_정보"
  WHERE "대여 대여소명" IS NOT NULL
    AND "대여 대여소명" != ''
    AND "대여 대여소명" != '\\N'
  GROUP BY "대여 대여소명"
),
returns AS (
  SELECT "반납대여소명" AS station_name, COUNT(*) AS return_count
  FROM "서울특별시_공공자전거_대여이력_정보"
  WHERE "반납대여소명" IS NOT NULL
    AND "반납대여소명" != ''
    AND "반납대여소명" != '\\N'
  GROUP BY "반납대여소명"
),
stations AS (
  SELECT station_name FROM rentals
  UNION
  SELECT station_name FROM returns
)
SELECT
  s.station_name,
  COALESCE(r.rental_count, 0) AS rental_count,
  COALESCE(t.return_count, 0) AS return_count,
  COALESCE(t.return_count, 0) - COALESCE(r.rental_count, 0) AS net_flow
FROM stations s
LEFT JOIN rentals r ON s.station_name = r.station_name
LEFT JOIN returns t ON s.station_name = t.station_name
ORDER BY net_flow ASC
LIMIT 10;

---수급 불균형(순유입 상위) 쿼리
WITH rentals AS (
  SELECT "대여 대여소명" AS station_name, COUNT(*) AS rental_count
  FROM "서울특별시_공공자전거_대여이력_정보"
  WHERE "대여 대여소명" IS NOT NULL
    AND "대여 대여소명" != ''
    AND "대여 대여소명" != '\\N'
  GROUP BY "대여 대여소명"
),
returns AS (
  SELECT "반납대여소명" AS station_name, COUNT(*) AS return_count
  FROM "서울특별시_공공자전거_대여이력_정보"
  WHERE "반납대여소명" IS NOT NULL
    AND "반납대여소명" != ''
    AND "반납대여소명" != '\\N'
  GROUP BY "반납대여소명"
),
stations AS (
  SELECT station_name FROM rentals
  UNION
  SELECT station_name FROM returns
)
SELECT
  s.station_name,
  COALESCE(r.rental_count, 0) AS rental_count,
  COALESCE(t.return_count, 0) AS return_count,
  COALESCE(t.return_count, 0) - COALESCE(r.rental_count, 0) AS net_flow
FROM stations s
LEFT JOIN rentals r ON s.station_name = r.station_name
LEFT JOIN returns t ON s.station_name = t.station_name
ORDER BY net_flow DESC
LIMIT 10;

---시간대별 순유출 히트맵용 쿼리
WITH rentals AS (
  SELECT
    "대여 대여소명" AS station_name,
    CAST(strftime('%H', "대여일시") AS INTEGER) AS hour,
    COUNT(*) AS rental_count
  FROM "서울특별시_공공자전거_대여이력_정보"
  WHERE "대여 대여소명" IS NOT NULL
    AND "대여 대여소명" != ''
    AND "대여 대여소명" != '\\N'
  GROUP BY "대여 대여소명", hour
),
returns AS (
  SELECT
    "반납대여소명" AS station_name,
    CAST(strftime('%H', "반납일시") AS INTEGER) AS hour,
    COUNT(*) AS return_count
  FROM "서울특별시_공공자전거_대여이력_정보"
  WHERE "반납대여소명" IS NOT NULL
    AND "반납대여소명" != ''
    AND "반납대여소명" != '\\N'
  GROUP BY "반납대여소명", hour
),
station_hours AS (
  SELECT station_name, hour FROM rentals
  UNION
  SELECT station_name, hour FROM returns
),
hourly AS (
  SELECT
    s.station_name,
    s.hour,
    COALESCE(t.return_count, 0) - COALESCE(r.rental_count, 0) AS net_flow
  FROM station_hours s
  LEFT JOIN rentals r ON s.station_name = r.station_name AND s.hour = r.hour
  LEFT JOIN returns t ON s.station_name = t.station_name AND s.hour = t.hour
),
overall AS (
  SELECT station_name, SUM(net_flow) AS net_flow
  FROM hourly
  GROUP BY station_name
),
top_shortage AS (
  SELECT station_name
  FROM overall
  ORDER BY net_flow ASC
  LIMIT 10
)
SELECT
  h.station_name,
  h.hour,
  h.net_flow
FROM hourly h
JOIN top_shortage t ON h.station_name = t.station_name
ORDER BY h.station_name, h.hour;
