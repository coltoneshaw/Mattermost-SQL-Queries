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