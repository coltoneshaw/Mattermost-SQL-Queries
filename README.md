# Mattermost SQL Queries

This repo contains a mix of SQL queries that were found [on this repo](https://github.com/cvitter/mattermost-scripts), work directly with customers, and other modes.

**Import Note**: All queries are provided as is and should only be used if you know what you're doing. Running some of these can be resource intensive on your Mattermost server, so it's suggested run these during low traffic periods.

# Contents:

**[System Console Metrics](#system-console-metrics)**
- [Active Users](#active-users)

**[General Queries](#general-queries)**

- [Find Empty Teams](#find-empty-teams)
- [Get All Deactivated Users](#get-all-deactivated-users)
- [Get Last Login Time of Users](#get-last-login-time)
- [Get Number of Posts in Channels](#get-number-of-posts-in-channel)
- [Get Posts by Team and Channel](#get-posts-by-team-and-channel)
- [Get User Last Activity](#get-user-last-activity)
- [Get Users in Channels](#get-users-in-channels)
- [Get Users in Teams](#get-users-in-teams)
- [Channel Growth](#channel-growth)
- [Running Count of New Users](#running-count-of-new-users)
- [User Activity with Sessions, Posts, and Logins](#user-activity-with-sessions-posts-and-logins)
- [Posts From User Within Timestamp including Audience](#Posts-from-user-within-timestamp-including-audience



# System Console Metrics

These is a growing list of the queries used to populate the Site Statistics and Team Statistic within the System Console.

## Active Users

Active users shows the number of users who have been **activated** within Mattermost, and removes all users who have been deactivated. This is decided by the `deleteAt` flag on the `users` table. 

### PostgreSQL

```sql
select 
    count(distinct u.id) 
from 
    users as u
left join 
    bots ON u.id = bots.userid
where 
    u.deleteat = 0 
    and bots.userid IS NULL;
```

# General Queries

## Channel Growth

Increase of channels on Mattermost instance over time.

### MySQL

```sql
SELECT  
  t.time,
  @running_total:=@running_total + t.channel_count AS cumulative_sum
FROM  (
      SELECT   
        unix_timestamp(from_unixtime((createat * 0.001))) div 86400 * 86400 AS time,
        count(`channels`.`id`) AS channel_count
      FROM `mattermost`.`channels`
      WHERE deleteat = '0'
      GROUP BY time 
      ) t
JOIN (
      SELECT @running_total:=0
     ) r
ORDER BY t.time; 
```

## Find Empty Teams

### MySQL

```sql
SELECT
    Teams.DisplayName AS Team,
    Teams.Name AS InternalName,
    COUNT(Teams.DisplayName) AS Members,
    SUM( CASE WHEN TeamMembers.DeleteAt = 0 THEN 1 ELSE 0 END ) AS Active,
    SUM( CASE WHEN TeamMembers.DeleteAt > 0 THEN 1 ELSE 0 END ) AS Deleted
FROM 
    Teams
LEFT JOIN
    TeamMembers ON TeamMembers.TeamId = Teams.Id
LEFT JOIN
    Users ON TeamMembers.UserId = Users.Id
WHERE
    Teams.DeleteAt = 0
GROUP BY
    Team, InternalName
ORDER BY
    Team
;
```

## Get All Deactivated Users

This query retrieves all deactivated users in Mattermost.

### MySQL

```sql
SELECT 
   COUNT (*) 
FROM 
   Users 
WHERE 
   DeleteAt = 0;
```

## Get Last Login Time
This query retrieves the last login time for all users in Mattermost.

### MySQL

```sql
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
```

### PostgreSQL

```sql
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
```

## Get Number Of Posts In Channel
This query retrieves the total number of posts in the database for Public ('O') and Private ('P') channels. This includes posts that are marked as deleted or edited so the number will be larger than the total number of posts visible to users in Mattermost.

### MySQL

```sql
SELECT 
   COUNT(*) 
FROM
   mattermost.Posts
JOIN
   mattermost.Channels ON Posts.ChannelId = Channels.Id
WHERE
   Channels.Type = 'P' or Channels.Type = 'O';
```

## Get Posts by Team and Channel

The query retrieves a list of active channels by team and the total number of posts in each channel ordered by Team and Channel. This query returns only Public ('O') and Private ('P') channels and posts that are visible (not deleted or past revisions of edited posts).

### MySQL

```sql
SELECT
    Teams.DisplayName AS Team,
    Channels.DisplayName AS Channel,
    Channels.Type,
    (SELECT COUNT(*) FROM mattermost.Posts WHERE Posts.ChannelId = Channels.Id AND Posts.DeleteAt = 0) AS Posts
FROM
    mattermost.Channels
JOIN
    mattermost.Teams ON Channels.TeamId = Teams.Id
WHERE
    Channels.DeleteAt = 0 AND
    Channels.Type <> 'D' AND
    Teams.DeleteAt = 0
ORDER BY
    Team, Channel;
```

## Get User Last Activity

This query retrieves a list of all users and their last session activity at date and time. 

**Important Note:** If the time that the the user was last active at exceeded the configured session length in days, or the user has never logged in, the LastActivityAt field will be null.

If you want to only search for users who are activated but have no session activity uncomment the `and lastActivityAt IS NULL` to your `WHERE` clause.
### Postgres

```sql
SELECT
    users.username,
    users.firstname,
    users.lastname,
    sessions.props,
    to_timestamp(cast(sessions.lastactivityat/1000 as bigint))::date
FROM
    users
LEFT JOIN
    sessions ON sessions.userid = users.id
LEFT JOIN 
    bots ON users.id = bots.userid
WHERE 
     bots.userid IS NULL
--   and lastActivityAt IS NULL
     and users.deleteat = 0
ORDER BY
    lastActivityAt desc;
```

### MySQL

```sql
SELECT
    Users.Username,
    Users.FirstName,
    Users.LastName,
    Sessions.Props,
    FROM_UNIXTIME(Sessions.LastActivityAt/1000,"%m/%d/%Y  %h:%i") AS LastActivityAt
FROM
    mattermost.Users
LEFT JOIN
    mattermost.Sessions ON Sessions.UserId = Users.Id
LEFT JOIN
    mattermost.Bots on Users.Id = Bots.UserId
WHERE
    Bots.UserId IS NULL
--  AND LastActivityAt IS NULL
    AND Users.DeleteAt = 0
ORDER BY
	LastActivityAt desc;
```

## Get Users in Channels

The following SQL query retrieves a list of active channels and the active users that are members of the channel ordered by Team, Channel, LastName and Username fields. Returns only Public ('O') and Private ('P') channels.

### MySQL

```sql
SELECT
    Teams.DisplayName AS Team,
    Channels.DisplayName AS Channel,
    Channels.Type,
    Users.LastName,
    Users.FirstName,
    Users.Username
FROM
    mattermost.ChannelMembers
JOIN
    mattermost.Channels ON ChannelMembers.ChannelId = Channels.Id
JOIN
    mattermost.Teams ON Channels.TeamId = Teams.Id
JOIN
    mattermost.Users ON ChannelMembers.UserId = Users.Id
WHERE
    Channels.DeleteAt = 0 AND
    Channels.Type <> 'D' AND
    Teams.DeleteAt = 0 AND
    Users.DeleteAt = 0
ORDER BY
    Team, Channel, LastName, Username;
```

## Get Users in Teams

The following SQL query retrieves a list of users who are members of active teams ordered by Team, LastName, and then Username.

### MySQL

```sql
SELECT 
    Teams.DisplayName AS Team,
    Users.LastName,
    Users.FirstName,
    Users.Username
FROM 
    mattermost.TeamMembers
JOIN
    mattermost.Teams ON TeamMembers.TeamId = Teams.Id
JOIN
    mattermost.Users ON TeamMembers.UserId = Users.Id
WHERE
    TeamMembers.DeleteAt = 0 AND
    Teams.DeleteAt = 0
ORDER BY
    Team, LastName, Username;
```

## New Users by Date
Understanding each day how many new users were onboarded.

### MySQL

```sql

SELECT 
    UNIX_TIMESTAMP(FROM_UNIXTIME((createat * 0.001))) DIV 86400 * 86400 as time,
    Count(`Users`.`Id`)
FROM 
  `mattermost`.`Users`
WHERE 
  deleteat = '0'
GROUP BY 1;
```

## Running Count of New Users
Understanding global adoption and increase within Mattermost.
### MySQL

```sql
SELECT
  t.time,
  @running_total:=@running_total + t.user_count AS cumulative_sum
FROM (
      SELECT   
        unix_timestamp(from_unixtime((createat * 0.001))) div 86400 * 86400 AS time,
        count(`users`.`id`) AS user_count
      FROM `mattermost`.`users`
      WHERE deleteat = '0'
      GROUP BY time 
      ) t
JOIN (
      SELECT @running_total:=0
    ) r
ORDER BY t.time; 
```

## User Activity With Sessions, Posts, and Logins

This query will merge together the sessions, users, audits, and posts table. It can be a heavy query on your system because it's using the post table. Consider doing this on off-hours. 

Use this query if you're interested in finding the activity of users, what kind of user they are, and the total number of posts they have in all of your Mattermost history.

Notes:

- `lastactivityat` might be null, this means the user doesn't have an active session. This could be because they logged out or sessions were purged.
- `lastLoginDate` might also be null for various reasons.

### Example Output:

|username |firstname|lastname  |lastactivityat|last_login_date|totalposts|roles                   |
|---------|---------|----------|--------------|---------------|----------|------------------------|
|billy    |         |          |2022-10-05    |2022-10-05     |2         |system_guest            |
|professor|Hubert   |Farnsworth|2022-10-05    |2022-09-29     |124       |system_user system_admin|


### Postgres

```sql
SELECT
    users.username,
    users.firstname,
    users.lastname,
    to_timestamp(cast(sessions.lastactivityat/1000 as bigint))::date as lastActivityAt,
    to_timestamp(cast(lastlogin.LastLogin/1000 as bigint))::date as lastLoginDate,
    p.totalPosts,
    users.roles
FROM
    users
LEFT JOIN
    sessions ON sessions.userid = users.id
LEFT JOIN 
    bots ON users.id = bots.userid
INNER JOIN
	(
	SELECT 
		count(posts.id) as totalPosts, 
		posts.userid 
	FROM 
		posts 
	GROUP BY 
		posts.userid
	) as p on p.userid = users.id 
INNER JOIN
   (
   	SELECT 
   		userid, 
   		MAX(createat) as lastLogin 
	FROM 
	   audits 
	WHERE 
	   audits.action = '/api/v4/users/login' 
	   AND audits.extrainfo LIKE 'success%' 
	GROUP BY 
	   userid) as lastlogin ON users.id = lastlogin.userid;
WHERE 
     bots.userid IS NULL
     and users.deleteat = 0
GROUP BY
	users.username,
	users.firstname,
	users.lastname,
	lastActivityAt,
	users.roles,
	p.totalPosts
ORDER BY
    lastActivityAt desc;
```

## Posts from user within timestamp including audience

This query is designed to allow you to find posts by a specific user and the audience that has current view access to them. This does not look at the `channelmemberhistory` table, so if someone has left the channel they would not be included.

### Example Output

|postdate|teamname                     |channelname|message                                      |channelmembers                                              |
|--------|-----------------------------|-----------|---------------------------------------------|------------------------------------------------------------|
|2023-04-03 14:57:50|test                         |new-hires  |Excited to have you here!                    |colton, haley, tom                                          |
|2023-04-03 14:50:52|test                         |sev-1-systems-outage|@here - Who can help us troubleshoot this?   |colton, tom, haley                                          |
|2023-04-03 14:50:01|test                         |sev-1-systems-outage|@here - Who can help us troubleshoot this?   |colton, tom, haley                                          |
|2023-03-31 13:52:09|test                         |off-topic  |Hey @channel, I'll be late for our meeting today!|haley, testperson1711, hermes, tom, testperson1698          |
|2023-03-31 13:45:50|test                         |off-topic  |@channel                                     |testperson21, testperson1783, testperson1171, testperson1421|


### Postgres

```sql
select 
	to_timestamp(CAST(posts.createat/1000 AS BIGINT))::TIMESTAMP AS postDate,
	teams.name as teamname,
	channels.name AS channelname,
	posts.message,
	string_agg(users.username, ', ') AS channelMembers
FROM
	channelmembers
JOIN channels ON channelmembers.channelid = channels.id
JOIN users ON users.id = channelmembers.userid
JOIN posts ON posts.channelid = channels.id
JOIN teams on channels.teamid = teams.id
WHERE 
  posts.userid = 'gywaej6kctbotgt8psohpfjtwa' 
  and posts.createat BETWEEN '1680269826992' AND '1680533947146'
GROUP BY
	posts.id,
	channels.id,
	teams.name
ORDER BY
	postDate desc;
```
