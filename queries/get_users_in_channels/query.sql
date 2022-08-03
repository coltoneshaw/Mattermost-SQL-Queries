# The following SQL query retrieves a list of active channels and
# the active users that are members of the channel ordered by
# Team, Channel, LastName and Username fields
# Note: Returns only Public ('O') and Private ('P') channels
# Tested on MySQL 5.7.24
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