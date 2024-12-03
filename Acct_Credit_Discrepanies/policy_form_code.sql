-- This query is meant to track changes in policy form codes for InForce Auto policies

WITH filtered_auto AS -- Gets all inforce auto policies in the last 6 months (filters initial dataset)
(
SELECT *
FROM "DSC_PLBI_DB"."APP_AUTO_PRD"."AUTO_INFORCE_MONTHEND"
WHERE ME_DT > '2024-05-31'
AND POL_STATUS_CD = 'InForce'
), 

inforce_auto AS -- Gets all inforce auto policies as of today (for cancel flag logic)
(
SELECT POLICY_ID
FROM "DSC_PLBI_DB"."APP_AUTO_PRD"."AUTO_INFORCE_MONTHEND"
WHERE ME_DT = (SELECT MAX(ME_DT) FROM "DSC_PLBI_DB"."APP_AUTO_PRD"."AUTO_INFORCE_MONTHEND")
AND POL_STATUS_CD = 'InForce'
), 

policy_changes AS -- Tracks how policy form codes change month over month
(
SELECT 
POLICY_ID,
POL_FORM_CD,
FIRST_VALUE(POL_FORM_CD) OVER (PARTITION BY POLICY_ID ORDER BY ME_DT) AS INITIAL_POL_FORM_CD,
LAST_VALUE(POL_FORM_CD) OVER (PARTITION BY POLICY_ID ORDER BY ME_DT ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS CURRENT_POL_FORM_CD,
LAG(POL_FORM_CD) OVER (PARTITION BY POLICY_ID ORDER BY ME_DT) AS PREV_POL_FORM_CD,
ME_DT
FROM filtered_auto
),

change_month AS -- Creates logic for tracking month of policy form change
(
SELECT 
POLICY_ID,
INITIAL_POL_FORM_CD,
CURRENT_POL_FORM_CD,
CASE WHEN POL_FORM_CD <> PREV_POL_FORM_CD THEN TO_CHAR(ME_DT, 'Mon') ELSE NULL END AS CHANGE_MONTH
FROM policy_changes
),

final_table AS
(
SELECT -- Returns policy ID and all information related to changes in policy form codes
FA.POLICY_ID,
MAX(CM.INITIAL_POL_FORM_CD) AS INITIAL_POL_FORM_CD,
MAX(CM.CURRENT_POL_FORM_CD) AS CURRENT_POL_FORM_CD,
MAX(CM.CHANGE_MONTH) AS CHANGE_MONTH,
CASE WHEN FA.POLICY_ID NOT IN (SELECT POLICY_ID FROM inforce_auto) THEN 1 ELSE 0 END AS CANCEL_FLAG
FROM filtered_auto AS FA
JOIN change_month AS CM
ON FA.POLICY_ID = CM.POLICY_ID
WHERE CHANGE_MONTH IS NOT NULL
GROUP BY FA.POLICY_ID
ORDER BY FA.POLICY_ID
)

SELECT final_table.*, CASE
WHEN INITIAL_POL_FORM_CD = 'HO3' AND CURRENT_POL_FORM_CD <> '0' THEN 'HO3 to Other'
WHEN INITIAL_POL_FORM_CD = 'HO3' AND CURRENT_POL_FORM_CD = '0' THEN 'HO3 to Nothing'
WHEN CURRENT_POL_FORM_CD = 'HO3' AND INITIAL_POL_FORM_CD <> '0' THEN 'Other to HO3'
WHEN CURRENT_POL_FORM_CD = 'HO3' AND INITIAL_POL_FORM_CD = '0' THEN 'Nothing to HO3'
WHEN CURRENT_POL_FORM_CD = INITIAL_POL_FORM_CD THEN 'Multiple Code Changes'
ELSE 'No HO3 in Transition' END AS BUCKET
FROM final_table