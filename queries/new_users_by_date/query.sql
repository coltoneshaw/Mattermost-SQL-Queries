# MySQL QUERY

SELECT 
    UNIX_TIMESTAMP(FROM_UNIXTIME((createat * 0.001))) DIV 86400 * 86400 as time,
    Count(`Users`.`Id`)
FROM `mattermost`.`Users`
WHERE deleteat = '0'
GROUP BY 1;