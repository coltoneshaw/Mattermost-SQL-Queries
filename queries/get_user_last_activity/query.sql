# The following SQL query retrieves a list of all users
# and their last session activity at date and time.
# Important Note: If the time that the the user was last 
# active at exceeded the configured session legnth in
# days, or the user has never logged in, the
# LastActivityAt field will be null.
# Tested on MySQL 5.7.24
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