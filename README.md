# Mattermost SQL Queries

This repo contains a mix of SQL queries that were found [on this repo](https://github.com/cvitter/mattermost-scripts), work directly with customers, and other modes.

**Import Note**: All queries are provided as is and should only be used if you know what you're doing. Running some of these can be resource intensive on your Mattermost server, so it's suggested run these during low traffic periods.

# Contents:

**[System Console Metrics](#system-console-metrics)**

- [Active Users](#active-users)
- [Monthly Active Users](#monthly-active-users)

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
- [Posts From User Within Timestamp including Audience](#posts-from-user-within-timestamp-including-audience)
- [Posts grouped by DM, GM and Channels in last 30 days](#posts-grouped-by-dm-gm-and-channels-in-the-last-30-days)
- [Posts per user per channel in the last 30 days](#posts-per-user-per-channel-in-the-last-30-days)
- [Word count within all posts per channel per team](#word-count-within-all-posts-per-channel-per-team)
- [Direct Messages between two users](#direct-messages-between-two-users)
- [Get all messages for a user](#get-all-messages-for-a-user)

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

```

## Monthly Active Users

Monthly active users show the number of users who have interacted with Mattermost within the last month (31 days). The `status` table is what drives the online / offline indicator within Mattermost. So, any conditions that would change the status there would update this table.

Replace the `MonthlyMillisecond` with the current time in milli minus 31 days (`2678400000`).

### PostgreSQL

```sql
SELECT
    count(*)
FROM
    status as s
LEFT JOIN
    Bots ON s.UserId = Bots.UserId
LEFT JOIN
    Users ON s.UserId = Users.Id
WHERE
    Users.deleteat = 0
    and Bots.UserId IS NULL;
    AND s.LastActivityAt > MonthlyMillisecond
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
   COUNT(*)
FROM
   Users
WHERE
   DeleteAt != 0;
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

| username  | firstname | lastname   | lastactivityat | last_login_date | totalposts | roles                    |
| --------- | --------- | ---------- | -------------- | --------------- | ---------- | ------------------------ |
| billy     |           |            | 2022-10-05     | 2022-10-05      | 2          | system_guest             |
| professor | Hubert    | Farnsworth | 2022-10-05     | 2022-09-29      | 124        | system_user system_admin |

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

| postdate            | teamname | channelname          | message                                           | channelmembers                                               |
| ------------------- | -------- | -------------------- | ------------------------------------------------- | ------------------------------------------------------------ |
| 2023-04-03 14:57:50 | test     | new-hires            | Excited to have you here!                         | colton, haley, tom                                           |
| 2023-04-03 14:50:52 | test     | sev-1-systems-outage | @here - Who can help us troubleshoot this?        | colton, tom, haley                                           |
| 2023-04-03 14:50:01 | test     | sev-1-systems-outage | @here - Who can help us troubleshoot this?        | colton, tom, haley                                           |
| 2023-03-31 13:52:09 | test     | off-topic            | Hey @channel, I'll be late for our meeting today! | haley, testperson1711, hermes, tom, testperson1698           |
| 2023-03-31 13:45:50 | test     | off-topic            | @channel                                          | testperson21, testperson1783, testperson1171, testperson1421 |

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

## Direct Messages between two users

This query is used to track down messages between 2 specific users during a given timeframe.  As with previous examples on this page, the `createat` field will contain
an epoch time in milliseconds.  [This website](https://www.epochconverter.com) can be used to help you figure out the values for specific dates and timezones.

```sql
select * from posts 
where channelid in
(select id from channels 
where position((select id from users where username='<user1>') in name) > 0
and position((select id from users where username='<user2>') in name) > 0)
and createat >= 1685577600000
and createat <= 1693526399000;
```

## Get all messages for a user

This query returns all posts for a specific user in both public and private channels, including DMs.  Again, the timeframe can be specified using Epoch milliseconds.

```sql
WITH UserSearch AS (
  SELECT '<username>' AS search_username
),
TimezoneSetting AS (
  SELECT 'UTC' AS timezone
)

SELECT
  u.username,
  to_timestamp(p.createat / 1000) AT TIME ZONE (SELECT timezone FROM TimezoneSetting) as posttimestamp,
  CASE
    WHEN c.Type = 'D' THEN (
      SELECT u2.username
      FROM users u2, UserSearch us
      WHERE (u2.id = SPLIT_PART(c.name, '__', 1) OR u2.id = SPLIT_PART(c.name, '__', 2))
      AND u2.username = us.search_username
      LIMIT 1
    )
    ELSE c.name
  END as channel_or_dm_name,
  CASE
    WHEN p.deleteat != 0 THEN 'Edited Or Deleted'
    ELSE NULL
  END as IsThePostDeletedOrEdited,
  p.message,
  fi.path
FROM
  posts p
JOIN
  users u ON u.id = p.userid
JOIN
  channels c ON p.channelid = c.id
LEFT JOIN
  fileinfo fi ON p.id = fi.postid,
  UserSearch us,
  TimezoneSetting ts
WHERE
  p.createat >= 1685577600000
  AND p.createat <= 1693526399000
  AND u.username = us.search_username
ORDER BY
  p.createat ASC;
```

## Posts grouped by DM, GM and Channels in the last 30 days

This query fetches the posts count per user, grouped by DM, GM and Channels in the last 30 days.

### Example Output

| username       | firstname | lastname | channel_type | total_posts |
| -------------- | --------- | -------- | ------------ | ----------- |
| aaron.carroll  | Aaron     | Carroll  | channel      | 56          |
| aaron.carroll  | Aaron     | Carroll  | DM           | 15          |
| alice.matthews | Alice     | Matthews | channel      | 47          |
| alice.matthews | Alice     | Matthews | GM           | 8           |

### Postgres

```sql
with channel_posts as (
	select u.username, u.firstname, u.lastname, c.id as channel_id, count(*) total_posts
	from posts p
	join users u on u.id = p.userid
	join channels c on c.id = p.channelid
	-- last 30 days
	where p.createat >= (cast(extract(epoch from current_timestamp) as bigint) - (60*60*24*30))*1000
		and u.deleteat = 0
	group by p.userid, p.channelid, u.username, u.firstname, u.lastname, c.id
)
select cp.username, cp.firstname, cp.lastname, ct.channel_type, sum(cp.total_posts)
from channel_posts cp
join (
	select ic.id, case
    when ic."type"='D' then 'DM'
    when ic."type"='G' then 'GM'
    else 'channel' end as channel_type
  	from channels ic
) ct on ct.id = cp.channel_id
group by ct.channel_type, cp.username, cp.firstname, cp.lastname
order by cp.username;
```

## Posts per user per channel in the last 30 days

This query fetches the posts count per user with channel details in the last 30 days.

### Example Output

| username       | firstname | lastname | channel_type    | name                                     | displayname                                             | total_posts |
| -------------- | --------- | -------- | --------------- | ---------------------------------------- | ------------------------------------------------------- | ----------- |
| aaron.carroll  | Aaron     | Carroll  | private_channel | iusto-9                                  | incidunt                                                | 2           |
| aaron.carroll  | Aaron     | Carroll  | group_message   | a98b031d90f4fcb56f8138c86c00a8746afb6fc0 | aaron.carroll, amanda.little, rebecca.simpson, sysadmin | 9           |
| alice.matthews | Alice     | Matthews | private_channel | iusto-9                                  | incidunt                                                | 1           |
| alice.matthews | Alice     | Matthews | public_channel  | doloremque-0                             | amet                                                    | 1           |

### Postgres

```sql
select u.username, u.firstname, u.lastname
, case
		when c."type"='D' then 'direct_message'
		when c."type"='G' then 'group_message'
		when c."type"='O' then 'public_channel'
		when c."type"='P' then 'private_channel'
	end as channel_type
, c."name", c.displayname, count(*) total_posts
from posts p
join users u on u.id = p.userid
join channels c on c.id = p.channelid
-- last 30 days
where p.createat > ((extract(epoch from current_timestamp) * 1000) - (cast(1000 as bigint)*60*60*24*30))
	and u.deleteat = 0
group by p.userid, p.channelid, u.username, u.firstname, u.lastname, c."name", c.displayname, c."type"
order by u.username;
```

## Word count within all posts per channel per team

This query is used to gather a count of words used in each channel across all teams.

### PostgreSQL

```sql
SELECT
    t.DisplayName AS Team,
    c.DisplayName AS Channel,
    c.Type,
    COUNT(p.id) AS Posts,
    COALESCE(SUM(array_length(string_to_array(p.message, ' '), 1)), 0) AS WordCount
FROM
    channels c
JOIN
    teams t ON c.TeamId = t.Id
LEFT JOIN
    posts p ON p.ChannelId = c.Id AND p.DeleteAt = 0
WHERE
    c.DeleteAt = 0
    AND c.Type IN ('O', 'P')
    AND t.DeleteAt = 0
GROUP BY
    t.DisplayName, c.DisplayName, c.Type
ORDER BY
    Team, Channel;
```
