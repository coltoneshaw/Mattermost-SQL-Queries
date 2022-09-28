# Mattermost Scripts

This repo contains a mix of SQL queries that were found [on this repo](https://github.com/cvitter/mattermost-scripts), work directly with customers, and other modes.

**Import Note**: All queries are provided as is and should only be used if you know what you're doing. Running some of these can be resource intensive on your Mattermost server, so it's suggested run these during low traffic periods.

## Contents:

- [Find Empty Teams](#find-empty-teams)** -
- [Get All Deactivated Users](#get-all-deactivated-users)
- [Get Last Login Time of Users](#get-last-login-time)
- [Get Number of Posts in Channels](#get-number-of-posts-in-channel)
- [Get Posts by Team and Channel](#get-posts-by-team-and-channel)
- [Get User Last Activity](#get-user-last-activity)
- [Get Users in Channels](#get-users-in-channels)
- [Get Users in Teams](#get-users-in-teams)
- [Channel Growth](#channel-growth)
- [Running Count of New Users](#running-count-of-new-users)

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

This query retrieves a list of all users and their last session activity at date and time. Important Note: If the time that the the user was last active at exceeded the configured session length in days, or the user has never logged in, the LastActivityAt field will be null.


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