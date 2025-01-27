WITH ap AS
(
SELECT *,
ROW_NUMBER() OVER (PARTITION BY POL_ID ORDER BY POL_EFF_DT DESC) AS auto_rn,
FROM "DSC_PLBI_DB"."APP_AUTO_PRD"."AUTO_PERSISTENCY_COMBINED"
),

inforce_auto AS
(
SELECT * FROM ap
WHERE auto_rn = 1 AND CANCEL_FLAG = 0 
AND NEWCO_IND = 'Y' AND POL_EFF_DT >= DATE(DATEADD(MONTH, -6, GETDATE()))
AND POL_QTE_STAT_DESC = 'InForce'
),

billing_data AS
(
SELECT ACCOUNT.BILL_ACCT_ID
      ,TERM.POL_TERM_ID
      ,TERM.POL_ID
      ,TERM.POL_TERM_EFF_DT POL_EFF_DT
      ,TERM.POL_TERM_EXP_DT POL_EXP_DT
      ,ACCOUNT.BILL_ACCT_PLAN_TYP_CD
      ,ACCOUNT.BILL_ACCT_PLAN_TYP_DESC
      ,TERM_DATA.BILL_INSTAL_TYP_DESC
FROM  PRD_PL_DB.APP_DCPA_BILL_CURATE.DC_BIL_ACCOUNT_LTST_VW ACCOUNT,
      PRD_PL_DB.APP_DCPA_BILL_CURATE.DC_BIL_POLICYTERM_LTST_VW TERM,
      PRD_PL_DB.APP_DCPA_BILL_CURATE.DC_BIL_POLICYTERMDATA_LTST_VW TERM_DATA
WHERE ACCOUNT.BILL_ACCT_ID = TERM.ORIG_BILL_ACCT_ID
AND   TERM.POL_TERM_ID = TERM_DATA.POL_TERM_ID
),

joined AS
(
SELECT 
ia.POL_ID,
ia.POL_EFF_DT,
bd.BILL_ACCT_PLAN_TYP_CD,
bd.BILL_INSTAL_TYP_DESC
FROM inforce_auto ia
JOIN billing_data bd 
ON ia.POL_ID = bd.POL_ID AND ia.POL_EFF_DT = bd.POL_EFF_DT
),

drips_window AS
(
SELECT * 
FROM joined
WHERE (POL_EFF_DT >= '2024-12-12' AND POL_EFF_DT <= '2025-01-27' AND BILL_INSTAL_TYP_DESC = 'Full Pay')
OR (BILL_INSTAL_TYP_DESC = 'Monthly Installments' AND POL_EFF_DT >= '2024-07-27')
)

SELECT CASE
WHEN BILL_INSTAL_TYP_DESC = 'Full Pay' 
AND BILL_ACCT_PLAN_TYP_CD IN ('HIG_ACT_A1','HIG_ACT_A2','HIG_ACT_A3','HIG_ACT_A4') THEN 'Auto Full Pay'
WHEN BILL_INSTAL_TYP_DESC = 'Full Pay' 
AND BILL_ACCT_PLAN_TYP_CD IN ('HIG_ACT_A6','HIG_ACT_A7') THEN 'On Demand Full Pay'
WHEN BILL_INSTAL_TYP_DESC = 'Monthly Installments' 
AND BILL_ACCT_PLAN_TYP_CD IN ('HIG_ACT_A1','HIG_ACT_A2','HIG_ACT_A3','HIG_ACT_A4') THEN 'Auto Monthly Pay'
WHEN BILL_INSTAL_TYP_DESC = 'Monthly Installments' 
AND BILL_ACCT_PLAN_TYP_CD IN ('HIG_ACT_A6','HIG_ACT_A7') THEN 'On Demand Monthly Pay'
ELSE 'N/A' END AS BUCKET,
COUNT(DISTINCT POL_ID) AS CNT
FROM drips_window
GROUP BY BUCKET