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
