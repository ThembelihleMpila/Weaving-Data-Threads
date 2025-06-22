USE md_water_services;
-- Create a table 
DROP TABLE IF EXISTS `auditor_report`;
CREATE TABLE `auditor_report` (
`location_id` VARCHAR(32),
`type_of_water_source` VARCHAR(64),
`true_water_source_score` int DEFAULT NULL,
`statements` VARCHAR(255)
);

SELECT * FROM md_water_services.auditor_report;

SELECT location_id, true_water_source_score
FROM auditor_report;

-- we join the visits table to the auditor_report table. Make sure to grab subjective_quality_score, record_id and location_id
SELECT
auditor_report.location_id AS audit_location,
auditor_report.true_water_source_score,
visits.location_id AS visit_location,
visits.record_id
FROM auditor_report
JOIN
visits ON auditor_report.location_id = visits.location_id;

/*  our next step is to retrieve the corresponding scores from the water_quality table. We
are particularly interested in the subjective_quality_score. To do this, we'll JOIN the visits table and the water_quality table, using the
record_id as the connecting key*/
SELECT 
    auditor_report.location_id AS audit_location,
    auditor_report.true_water_source_score,
    visits.location_id AS visit_location,
    visits.record_id,
    water_quality.subjective_quality_score
FROM auditor_report
JOIN visits 
ON auditor_report.location_id = visits.location_id
JOIN water_quality 
ON visits.record_id = water_quality.record_id;

    /*. Since it is a duplicate, we can drop one of
the location_id columns. Let's leave record_id and rename the scores to surveyor_score and auditor_score to make it clear which scores
we're looking at in the results set.*/
    SELECT 
    auditor_report.location_id AS audit_location,
    visits.record_id,
    water_quality.subjective_quality_score AS surveyor_score,
    auditor_report.true_water_source_score AS auditor_score
FROM 
    auditor_report
JOIN 
    visits 
    ON auditor_report.location_id = visits.location_id
JOIN 
    water_quality 
    ON visits.record_id = water_quality.record_id;
    
        /*Since were joining 1620 rows of data, we want to keep track of the number of rows we get each time we run a query. We can force SQL to give us all of the results, using
LIMIT 10000.*/

    SELECT 
    auditor_report.location_id AS audit_location,
    visits.record_id,
    water_quality.subjective_quality_score AS surveyor_score,
    auditor_report.true_water_source_score AS auditor_score
FROM 
    auditor_report
JOIN 
    visits 
    ON auditor_report.location_id = visits.location_id
JOIN 
    water_quality 
    ON visits.record_id = water_quality.record_id
WHERE 
    visits.visit_count = 1
LIMIT 10000;

-- Linking records to employees 
with Incorrect_records AS (
select 
	visits.location_id,
    visits.record_id,
    employee.employee_name,
    auditor_report.true_water_source_score as auditor_score,
    water_quality.subjective_quality_score as employee_score
from
	auditor_report
join
	visits
on 
	auditor_report.location_id = visits.location_id
join 
	water_quality
on 
	visits.record_id = water_quality.record_id
join 
	employee
on visits.assigned_employee_id = employee.assigned_employee_id
where
	auditor_report.true_water_source_score != water_quality.subjective_quality_score
    and 
    visits.visit_count = 1
) SELECT
	distinct employee_name,
    count(employee_name) as error_count
    FROM Incorrect_records
    group by employee_name
    order by count(employee_name) desc;
    
    -- Create a view
CREATE VIEW Incorrect_records AS (
SELECT
auditor_report.location_id,
visits.record_id,
employee.employee_name,
auditor_report.true_water_source_score AS auditor_score,
wq.subjective_quality_score AS employee_score,
auditor_report.statements AS statements
FROM auditor_report
JOIN visits
ON auditor_report.location_id = visits.location_id
JOIN water_quality AS wq
ON visits.record_id = wq.record_id
JOIN employee
ON employee.assigned_employee_id = visits.assigned_employee_id
WHERE visits.visit_count =1
AND auditor_report.true_water_source_score != wq.subjective_quality_score);

select * from Incorrect_records;

-- Convert query error_count into a CTE
WITH error_count AS ( -- This CTE calculates the number of mistakes each employee made
SELECT employee_name,
COUNT(employee_name) AS number_of_mistakes
FROM Incorrect_records
/*
Incorrect_records is a view that joins the audit report to the database
for records where the auditor and
employees scores are different*/
GROUP BY employee_name)
-- Query
SELECT *
FROM error_count
order by number_of_mistakes desc;

WITH suspect_list AS ( 
SELECT *
FROM Incorrect_records
WHERE 
statements = "“Suspicion coloured villagers\' descriptions of an official's aloof demeanour and apparent laziness. 
The reference to cash transactions casts doubt on their motives.”"
) 
SELECT * 
FROM suspect_list;

-- This CTE calculates the number of mistakes each employee made
WITH error_count AS ( 
SELECT employee_name,
COUNT(employee_name) AS number_of_mistakes
FROM Incorrect_records
/*
Incorrect_records is a view that joins the audit report to the database
for records where the auditor and
employees scores are different*/
GROUP BY employee_name),
suspect_list AS (                     -- This CTE SELECTS the employees with above−average mistakes
SELECT
employee_name,
number_of_mistakes
FROM error_count
WHERE
number_of_mistakes > (SELECT AVG(number_of_mistakes) FROM error_count))
-- This query filters all of the records where the "corrupt" employees gathered data.
SELECT
employee_name,
location_id,
statements
FROM Incorrect_records
WHERE employee_name in (SELECT employee_name FROM suspect_list);

