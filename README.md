# Mattermost Scripts

This repo contains a mix of SQL queries that were found [on this repo](https://github.com/cvitter/mattermost-scripts), work directly with customers, and other modes. 

**Import Note**: All queries are provided as is and should only be used if you know what you're doing. Running some of these can be resource intensive on your Mattermost server, so it's suggested run these during low traffic periods. 

# SQL Queries:

* **[Find Empty Teams](queries/find_empty_teams/query.sql)** - 
* **[Get All Deactivated Users](queries/get_all_deactivated_users/query.sql)** - This query retrieves all deactivated users in Mattermost.
* **[Get Last Login Time of Users](queries/get_last_login_time/query.sql)** - This query retrieves the last login time for all users in Mattermost.
* **[Get Number of Posts in Channels](queries/get_number_of_posts_in_channels/query.sql)** - This query retrieves the total number of posts in the database for Public ('O') and Private ('P') channels. This includes posts that are marked as deleted or edited so the number will be larger than the total number of posts visible to users in Mattermost.
* **[Get Posts by Team and Channel](queries/get_posts_by_team_and_channel/query.sql)** - The query retrieves a list of active channels by team and the total number of posts in each channel ordered by Team and Channel. This query returns only Public ('O') and Private ('P') channels and posts that are visible (not deleted or past revisions of edited posts).
* **[Get User Last Activity](queries/get_user_last_activity/query.sql)** - This query retrieves a list of all users and their last session activity at date and time. Important Note: If the time that the the user was last active at exceeded the configured session length in days, or the user has never logged in, the LastActivityAt field will be null.
* **[Get Users in Channels](queries/get_users_in_channels/query.sql)** - The following SQL query retrieves a list of active channels and the active users that are members of the channel ordered by Team, Channel, LastName and Username fields. Returns only Public ('O') and Private ('P') channels.
* **[Get Users in Teams](queries/get_users_in_teams/query.sql)** - The following SQL query retrieves a list of users who are members of active teams ordered by Team, LastName, and then Username.
* **[Post Growth](queries/post_growth/query.sql)** - Increase of posts on Mattermost over time.
* **[Channel Growth](queries/channel_growth/query.sql)** - Increase of channels on Mattermost over time.
* **[Running Count of New Users](queries/running_count_of_new_users/query.sql)** - Understanding global adoption and increase within Mattermost.


