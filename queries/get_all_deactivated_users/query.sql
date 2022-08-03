# The following SQL query retrieves all deactivated
# users in Mattermost
SELECT 
   COUNT (*) 
FROM 
   Users 
WHERE 
   DeleteAt = 0;