# The following SQL query retrieves the total number of posts
# in the database for Public ('O') and Private ('P') 
# channels. This includes posts that are marked as deleted
# or edited so the number will be larger than the total number
# of posts visible to users in Mattermost
# Tested on MySQL 5.7.24
SELECT 
   COUNT(*) 
FROM
   mattermost.Posts
JOIN
   mattermost.Channels ON Posts.ChannelId = Channels.Id
WHERE
   Channels.Type = 'P' or Channels.Type = 'O';