---시간대별 이용량 쿼리
SELECT
strftime('%H', 대여일시) AS hour,
COUNT(*) AS rental_count
FROM "서울특별시_공공자전거_대여이력_정보"
GROUP BY hour
ORDER BY rental_count;


