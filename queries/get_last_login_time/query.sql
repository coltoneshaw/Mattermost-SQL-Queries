# The following MySQL query retrieves the last login time
# for all users in Mattermost
SELECT 
   u.UserName, u.Email, FROM_UNIXTIME((lastlogin.LastLogin/1000)) as last_login_date
FROM
   Users u
INNER JOIN
   (SELECT UserId, MAX(CreateAt) as LastLogin 
FROM 
   Audits 
WHERE 
   Audits.action = '/api/v4/users/login' AND Audits.extrainfo LIKE 'success%' 
GROUP BY 
   UserId) lastlogin
ON 
   u.Id = lastlogin.UserId;


# The following PostgreSQL query retrieves the last login time
# for all users in Mattermost

SELECT 
   u.UserName, u.Email, to_timestamp((lastlogin.LastLogin/1000)) as last_login_date
FROM 
   Users u
INNER JOIN
   (SELECT UserId, MAX(CreateAt) as LastLogin 
FROM 
   Audits 
WHERE 
   Audits.action = '/api/v4/users/login' AND Audits.extrainfo LIKE 'success%' 
GROUP BY 
   UserId) lastlogin
ON 
   u.Id = lastlogin.UserId;