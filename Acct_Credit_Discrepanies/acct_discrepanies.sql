-- Note: These queries are designed for continuous monitoring of acct credit discrepanies
-- The CARINA_DATA and TED_DATA queries were designed by Ted Shumaker and Carina Di Chello

CREATE OR REPLACE TRANSIENT TABLE USER_DB.AD1_PA08042.CARINA_DATA
AS
SELECT DISTINCT POL_ACCT_CR_IND AS HOME_ACCT_IND, 
POL_ID AS HOME_POL_ID, 
ORIG_QTE_CNTCT_METH_CD 
FROM 
(select
      pol_eff_dt
    , orig_qte_cntct_meth_cd
    , risk_st_abbr 
    , pol_id
    ,  atr_e_flat as Starting_Cnt
    ,   POL_ANNL_TTL_BILL_PREM_AMT as Pol_Premium
    ,   PREV_TERM_LATEST_PREM_AMT
    , Case when ACCT_CR_IND = 'Y' then 1 
           when ACCT_CR_IND = 'N' then 0 
           else 'null' 
           END as POL_ACCT_CR_IND
    ,   POL_ACCT_CR_IND as Current_Acct_Cr_Status
    ,   Case when (lag(POL_ACCT_CR_IND, 1)
            over (partition by pol_id
            order by pol_eff_dt)) - POL_ACCT_CR_IND = 1 THEN 1 Else 0 END as disc_rem
    from DSC_PLBI_DB.APP_HOME_PRD.HOME_PERSISTENCY_COMBINED
    where   newco_ind = 'Y' and trans_typ_desc in ('New', 'Renew','Endorse') and atr_e_flat = 1 )
    Where disc_rem = 1

SELECT * FROM USER_DB.AD1_PA08042.CARINA_DATA
DROP TABLE USER_DB.AD1_PA08042.CARINA_DATA

------------------------------------------------------------------------------------------------------------------------------------------------------------------

CREATE OR REPLACE TRANSIENT TABLE USER_DB.AD1_PA08042.ACCT_CR_DISCREPANCIES
AS
SELECT 'Home' AS POL_START, CARINA.*, 'Auto' AS POL_END
FROM (
WITH CARINA_FILTERED AS
(
SELECT * FROM USER_DB.AD1_PA08042.CARINA_DATA WHERE HOME_ACCT_IND = 0               -- Gets all policies with no account credit (no bundling discount)
),
INFORCE_AUTO AS
(
SELECT TRY_TO_DECIMAL(POLICY_ID) AS POL_ID                                          -- Gets all numeric Auto Policy IDs that are currently inforce
FROM "DSC_PLBI_DB"."APP_AUTO_PRD"."AUTO_INFORCE_MONTHEND" 
WHERE POL_ID IS NOT NULL 
AND ME_DT = (SELECT MAX(ME_DT) FROM "DSC_PLBI_DB"."APP_AUTO_PRD"."AUTO_INFORCE_MONTHEND")
)
SELECT DISTINCT
CARINA_FILTERED.HOME_POL_ID AS START_POL_ID,
CARINA_FILTERED.ORIG_QTE_CNTCT_METH_CD,
HOME_Q.COMPL_QTE_DT AS START_ORIG_QTE_DT,
HOME_Q.QCN AS START_QCN,
CROSSWALK.AUTO_QCN AS END_QCN,
CAST(ORIG_QTE_TMSP AS DATE) AS END_ORIG_QTE_DT,
AUTO_Q.POL_ID AS END_POL_ID,
FROM CARINA_FILTERED
JOIN "PRD_PL_DB"."APP_DCPA_DM"."PROP_QUOTE_DWELL_LATST_VW" AS HOME_Q                -- Joins to Home Quote on Home Pol ID
ON CARINA_FILTERED.HOME_POL_ID = HOME_Q.POL_ID
JOIN "DSC_PLBI_DB"."APP_AUTO_PRD"."PLBI_PARTY_LINKING_VW" AS CROSSWALK              -- Joins to Crosswalk table on Home QCN
ON HOME_Q.QCN = CROSSWALK.HOME_QCN
JOIN "PRD_PL_DB"."APP_DCPA_DM"."AUTO_QUOTE_LATST_VW" AS AUTO_Q                      -- Joins to Auto Quote on Auto QCN
ON CROSSWALK.AUTO_QCN = AUTO_Q.QCN
WHERE END_POL_ID IN (SELECT POL_ID FROM INFORCE_AUTO) AND END_POL_ID IS NOT NULL    -- Only returns Home Policies that have an inforce Auto policy
) AS CARINA

SELECT * FROM USER_DB.AD1_PA08042.ACCT_CR_DISCREPANCIES
FROM USER_DB.AD1_PA08042.ACCT_CR_DISCREPANCIES
DROP TABLE USER_DB.AD1_PA08042.ACCT_CR_DISCREPANCIES

------------------------------------------------------------------------------------------------------------------------------------------------------------------

CREATE OR REPLACE TRANSIENT TABLE USER_DB.AD1_PA08042.TED_DATA
AS
select DISTINCT CURRENT_ACCT_CR_STATUS AS AUTO_ACCT_IND, POL_ID AS AUTO_POL_ID, ORIG_QTE_CNTCT_METH_CD
FROM
(select
      pol_eff_dt
    , orig_qte_cntct_meth_cd
    , risk_st_abbr 
    , pol_id
    ,  atr_e_flat as Starting_Cnt
    ,   POL_TTL_BILL_PREM_AMT as Pol_Premium
    ,   PREV_POL_TTL_BILL_PREM_AMT
    ,   POL_ACCT_CR_IND as Current_Acct_Cr_Status
    ,   Case when (lag(POL_ACCT_CR_IND, 1)
            over (partition by pol_id
            order by pol_eff_dt)) - POL_ACCT_CR_IND = 1 THEN 1 Else 0 END as disc_rem
    from DSC_PLBI_DB.APP_AUTO_PRD.AUTO_PERSISTENCY_COMBINED
    where   newco_ind = 'Y' and trans_typ_desc in ('New', 'Renew','Endorse') and atr_e_flat = 1 )
    Where disc_rem = 1

SELECT * FROM USER_DB.AD1_PA08042.TED_DATA
DROP TABLE USER_DB.AD1_PA08042.TED_DATA

------------------------------------------------------------------------------------------------------------------------------------------------------------------

INSERT INTO USER_DB.AD1_PA08042.ACCT_CR_DISCREPANCIES
SELECT 'Auto' AS POL_START, TED.*, 'Home' AS POL_END
FROM (
WITH TED_FILTERED AS
(
SELECT * FROM USER_DB.AD1_PA08042.TED_DATA WHERE AUTO_ACCT_IND = 0               -- Gets all policies with no account credit (no bundling discount)
),
INFORCE_HOME AS
(
SELECT TRY_TO_DECIMAL(POLICY_ID) AS POL_ID                                       -- Gets all numeric Home Policy IDs that are currently inforce 
FROM "DSC_PLBI_DB"."APP_HOME_PRD"."HOME_INFORCE_MONTHEND" 
WHERE POL_ID IS NOT NULL 
AND ME_DT = (SELECT MAX(ME_DT) FROM "DSC_PLBI_DB"."APP_HOME_PRD"."HOME_INFORCE_MONTHEND")
)
SELECT DISTINCT
TED_FILTERED.AUTO_POL_ID AS START_POL_ID,
TED_FILTERED.ORIG_QTE_CNTCT_METH_CD,
CAST(ORIG_QTE_TMSP AS DATE) AS START_ORIG_QTE_DT,
AUTO_Q.QCN AS START_QCN,
CROSSWALK.HOME_QCN AS END_QCN,
HOME_Q.COMPL_QTE_DT AS END_ORIG_QTE_DT,
HOME_Q.POL_ID AS END_POL_ID
FROM TED_FILTERED
JOIN "PRD_PL_DB"."APP_DCPA_DM"."AUTO_QUOTE_LATST_VW" AS AUTO_Q                      -- Joins to Auto Quote on Auto Pol ID
ON TED_FILTERED.AUTO_POL_ID = AUTO_Q.POL_ID
JOIN "DSC_PLBI_DB"."APP_AUTO_PRD"."PLBI_PARTY_LINKING_VW" AS CROSSWALK              -- Joins to Crosswalk table on Auto QCN
ON AUTO_Q.QCN = CROSSWALK.AUTO_QCN
JOIN "PRD_PL_DB"."APP_DCPA_DM"."PROP_QUOTE_DWELL_LATST_VW" AS HOME_Q                -- Joins to Home Quote on Home QCN 
ON CROSSWALK.HOME_QCN = HOME_Q.QCN
WHERE END_POL_ID IN (SELECT POL_ID FROM INFORCE_HOME) AND END_POL_ID IS NOT NULL    -- Only returns Auto Policies that have an inforce Home policy
) AS TED