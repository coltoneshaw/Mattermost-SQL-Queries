# Get User Last Activity

This query retrieves a list of all users and their last session activity at date and time. Important Note: If the time that the the user was last active at exceeded the configured session length in days, or the user has never logged in, the LastActivityAt field will be null.


## Postgres

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

## MySQL

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
