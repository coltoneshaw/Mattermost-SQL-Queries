# The following SQL query retrieves a list of users who are members 
# of active teams ordered by Team, LastName, and then Username
# Tested on MySQL 5.7.24
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