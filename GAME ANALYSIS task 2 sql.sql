select * from ld;

select * from pd;
  
  # 1. Extract `P_ID`, `Dev_ID`, `PName`, and `Difficulty_level` of all players at Level 0 --
SELECT a.P_ID, b.Dev_ID, a.PName, b.Difficulty, b.Level
FROM ld as b, pd as a
WHERE b.Level = 0;

# 2. Find `Level1_code`wise average `Kill_Count` where `lives_earned` is 2, and at least 3 stages are crossed.--
SELECT a.L1_Code, AVG(b.Kill_Count) AS Average_Kill_Count
FROM pd as a
JOIN ld as b
ON a.P_ID = b.P_ID
WHERE b.Lives_Earned = 2
GROUP BY a.L1_Code
HAVING COUNT(DISTINCT b.Stages_crossed) >= 3;

# 3. Find the total number of stages crossed at each difficulty level for Level 2 with players using `zm_series` devices. Arrange the result in decreasing order of the total number of stages crossed.--
SELECT difficulty, 
	sum(stages_crossed) AS total_stages_crossed, 
	count(stages_crossed) AS totalcount_stages_crossed
FROM ld
WHERE level = 2
AND Dev_ID Like 'zm_%'
GROUP BY difficulty
ORDER BY total_stages_crossed DESC;

# 4.Extract `P_ID` and the total number of unique dates for those players who have played games on multiple days.--
SELECT P_ID, COUNT(DISTINCT date (start_datetime)) AS unique_dates
FROM ld
GROUP BY P_ID
HAVING COUNT(DISTINCT date (start_datetime)) > 1;

# 5. Find `P_ID` and levelwise sum of `kill_counts` where `kill_count` is greater than the average kill count for Medium difficulty.--
SELECT P_ID, level, SUM(kill_count) AS total_kills
FROM ld
WHERE difficulty = 'Medium'
GROUP BY P_ID, level
HAVING SUM(kill_count) > (SELECT AVG(kill_count) FROM ld WHERE difficulty = 'Medium');

# 6. Find `Level` and its corresponding `Level_code`wise sum of lives earned, excluding Level 0. Arrange in ascending order of level.--
SELECT a.Level, b.L1_code, b.L2_code, sum(Lives_Earned) AS total_lives
FROM ld AS a
JOIN pd as b
ON a.P_id = b.P_id
WHERE a.Level Not in (0)
GROUP BY a.Level,b.L1_code, b.L2_code
ORDER BY a.Level ASC;

# 7. Find the top 3 scores based on each `Dev_ID` and rank them in increasing order using `Row_Number`. Display the difficulty as well.--
WITH Top3 AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY Dev_ID ORDER BY score DESC) AS ranks
    FROM ld
)
SELECT Dev_ID, difficulty, score, ranks
FROM Top3
WHERE ranks <= 3
ORDER BY Dev_ID, ranks;

# 8. Find the `first_login` datetime for each device ID.--
SELECT Dev_ID, MIN(start_datetime) AS Firstlogin
FROM ld
GROUP BY Dev_ID
ORDER BY Dev_ID,Firstlogin;

# 9. Find the top 5 scores based on each difficulty level and rank them in increasing order using `Rank`. Display `Dev_ID` as well.--
WITH TOP5 AS
(SELECT *,
	RANK() OVER (PARTITION BY Difficulty ORDER BY SCORE ASC) AS RANKS
FROM ld)
SELECT Dev_ID, Difficulty, Score,RANKS
FROM TOP5
WHERE RANKS <= 5
ORDER BY Difficulty,RANKS;

# 10. Find the device ID that is first logged in (based on `start_datetime`) for each player (`P_ID`). Output should contain player ID, device ID, and first login datetime.--
SELECT P_ID, Dev_ID, MIN(start_datetime) AS FIRSTLOGIN
FROM ld
GROUP BY P_ID ,Dev_ID
ORDER BY P_ID;

# 11. For each player and date, determine how many `kill_counts` were played by the player so far.--
# a) Using window functions--
SELECT P_ID, start_datetime, kill_count,
    SUM(kill_count) OVER (PARTITION BY P_ID ORDER BY START_DATETIME) AS total_kill_count_so_far
FROM ld 
ORDER BY P_ID, start_datetime;

# b) Without window functions--
SELECT P_ID, start_datetime, kill_count,
    (SELECT SUM(ld2.kill_count)
     FROM ld AS ld2
     WHERE ld2.P_ID = P_ID
        AND ld2.start_datetime <= start_datetime) AS total_kill_count_so_far
FROM ld 
ORDER BY P_ID, start_datetime;

# 12. Find the cumulative sum of stages crossed over `start_datetime` for each `P_ID`, excluding the most recent `start_datetime`.--
WITH StageCounts AS (
    SELECT P_ID, start_datetime, stages_crossed,
        ROW_NUMBER() OVER (PARTITION BY P_ID ORDER BY start_datetime DESC) AS row_num
    FROM ld)
SELECT sc1.P_ID,
    SUM(sc2.stages_crossed) AS cumulative_sum
FROM 
    StageCounts sc1
JOIN 
    StageCounts sc2 ON sc1.P_ID = sc2.P_ID 
AND sc1.row_num > sc2.row_num
GROUP BY sc1.P_ID;

# 13. Extract the top 3 highest sums of scores for each `Dev_ID` and the corresponding `P_ID`.--
WITH TOP3 AS (
	SELECT P_ID, Dev_ID, SUM(Score) as Totalscore,
		ROW_NUMBER() OVER (PARTITION BY Dev_ID ORDER BY SUM(Score) DESC) AS ScoreRank
	FROM ld
	GROUP BY P_ID, Dev_ID)
SELECT P_ID, Dev_ID, totalscore
FROM TOP3
WHERE ScoreRank <= 3;

# 14. Find players who scored more than 50% of the average score, scored by the sum of scores for each `P_ID`.--
WITH PlayerScores AS (
    SELECT P_ID, SUM(score) AS total_score
    FROM ld
    GROUP BY P_ID),
AvgPlayerScore AS (
    SELECT AVG(total_score) AS average_score
    FROM PlayerScores)
SELECT ld.P_ID,
    ps.total_score AS player_total_score
FROM ld
JOIN 
    PlayerScores AS ps ON ld.P_ID = ps.P_ID
JOIN 
    AvgPlayerScore AS aps ON 1=1
WHERE 
    ps.total_score > aps.average_score * 0.5;

# 15. Create a stored procedure to find the top `n` `headshots_count` based on each `Dev_ID` and rank them in increasing order using `Row_Number`. Display the difficulty as well.

        DELIMITER //

CREATE PROCEDURE GetTopNHeadshots(
    IN n INT
)
BEGIN
    DROP TEMPORARY TABLE IF EXISTS TempRankedHeadshots;
    CREATE TEMPORARY TABLE TempRankedHeadshots (
        Dev_ID VARCHAR(255),
        difficulty VARCHAR(255),
        headshots_count INT,
        ranks INT
    );

    SET @sql = CONCAT('
        INSERT INTO TempRankedHeadshots
        SELECT 
            Dev_ID,
            difficulty,
            headshots_count,
            ROW_NUMBER() OVER (PARTITION BY Dev_ID ORDER BY headshots_count ASC) AS ranks
        FROM Level_Details
    ');

    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SELECT 
        Dev_ID,
        difficulty,
        headshots_count,
        ranks
    FROM 
        TempRankedHeadshots
    WHERE 
        ranks <= n;
END //

DELIMITER ;



