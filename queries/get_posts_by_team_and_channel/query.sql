# The following SQL query retrieves a list of active channels
# by team and the total number of posts in each channel
# ordered by Team and Channel.
# Note: This query returns only Public ('O') and Private ('P') 
# channels and posts that are visible (not deleted or past 
# revisions of edited posts).
# Tested on MySQL 5.7.24
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