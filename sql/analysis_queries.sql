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

---순유출 상위 10개 합계/비중 쿼리
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
),
net AS (
  SELECT
    s.station_name,
    COALESCE(t.return_count, 0) - COALESCE(r.rental_count, 0) AS net_flow
  FROM stations s
  LEFT JOIN rentals r ON s.station_name = r.station_name
  LEFT JOIN returns t ON s.station_name = t.station_name
),
top_shortage AS (
  SELECT net_flow
  FROM net
  ORDER BY net_flow ASC
  LIMIT 10
),
totals AS (
  SELECT SUM(CASE WHEN net_flow < 0 THEN net_flow ELSE 0 END) AS total_negative
  FROM net
)
SELECT
  (SELECT SUM(net_flow) FROM top_shortage) AS top10_negative,
  (SELECT total_negative FROM totals) AS total_negative,
  ROUND(
    ABS((SELECT SUM(net_flow) FROM top_shortage)) * 100.0 /
    NULLIF(ABS((SELECT total_negative FROM totals)), 0),
    2
  ) AS top10_negative_share;

---순유입 상위 10개 합계/비중 쿼리
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
),
net AS (
  SELECT
    s.station_name,
    COALESCE(t.return_count, 0) - COALESCE(r.rental_count, 0) AS net_flow
  FROM stations s
  LEFT JOIN rentals r ON s.station_name = r.station_name
  LEFT JOIN returns t ON s.station_name = t.station_name
),
top_surplus AS (
  SELECT net_flow
  FROM net
  ORDER BY net_flow DESC
  LIMIT 10
),
totals AS (
  SELECT SUM(CASE WHEN net_flow > 0 THEN net_flow ELSE 0 END) AS total_positive
  FROM net
)
SELECT
  (SELECT SUM(net_flow) FROM top_surplus) AS top10_positive,
  (SELECT total_positive FROM totals) AS total_positive,
  ROUND(
    ABS((SELECT SUM(net_flow) FROM top_surplus)) * 100.0 /
    NULLIF(ABS((SELECT total_positive FROM totals)), 0),
    2
  ) AS top10_positive_share;

---피크 시간대 순유출 합계 쿼리(상위 부족 10개 기준)
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
),
target AS (
  SELECT h.station_name, h.hour, h.net_flow
  FROM hourly h
  JOIN top_shortage t ON h.station_name = t.station_name
)
SELECT
  SUM(CASE WHEN hour IN (7, 8, 9, 15, 16) THEN net_flow ELSE 0 END) AS peak_net_flow,
  SUM(net_flow) AS total_net_flow,
  ROUND(
    ABS(SUM(CASE WHEN hour IN (7, 8, 9, 15, 16) THEN net_flow ELSE 0 END)) * 100.0 /
    NULLIF(ABS(SUM(net_flow)), 0),
    2
  ) AS peak_share_percent
FROM target;
