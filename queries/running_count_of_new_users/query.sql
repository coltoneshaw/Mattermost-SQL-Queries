SELECT t.time, 
       @running_total:=@running_total + t.user_count AS cumulative_sum
FROM
( SELECT
  UNIX_TIMESTAMP(FROM_UNIXTIME((createat * 0.001))) DIV 86400 * 86400 as time,
  count(`Users`.`Id`) as user_count
  FROM `mattermost`.`Users`
  WHERE  deleteat = '0'
  GROUP BY time ) t
JOIN (SELECT @running_total:=0) r
ORDER BY t.time;