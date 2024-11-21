-- Note: The UNDERWRITING_AUTO_POLICIES was created from the excel file in this folder
-- Some column names may need to be changed when converting this file to a Snowflake table

CREATE OR REPLACE TRANSIENT TABLE USER_DB.AD1_PA08042.DATA_JULY
AS
(
SELECT 
UW_AUTO.POL_ID,        -- Grouping Attribute 1: Policy ID
EARNED_MONTH,          -- Grouping Attribute 2: Earned Month

-- Rest of Karen's Dataset
MIN(UW_AUTO.RISK_ST_ABBR) AS RISK_ST_ABBR,
MIN(UW_AUTO.ORIG_POL_EFF_DT) AS ORIG_POL_EFF_DT,
MIN(UW_AUTO.POL_EFF_DT) AS LATEST_POL_EFF_DT,
MIN(UW_AUTO.TRANS_STAT_DESC) AS TRANS_STAT_DESC,
MIN(UW_AUTO.CLEAN_DIRTY_CD) AS CLEAN_DIRTY_CD,
MIN(UW_AUTO.POL_TTL_SPEED_MNR_VIO_CNT) AS POL_TTL_SPEED_MNR_VIO_CNT,
MIN(UW_AUTO.POL_TTL_NSPD_MNR_VIO_CNT) AS POL_TTL_NSPD_MNR_VIO_CNT,
MIN(UW_AUTO.TTL_UW_ELIG_POL_AFA_CNT) AS TTL_UW_ELIG_POL_AFA_CNT,
MIN(UW_AUTO.TTL_UW_ELIG_POL_NAF_ACCID_CNT) AS TTL_UW_ELIG_POL_NAF_ACCID_CNT,
MIN(UW_AUTO.TTL_UW_ELIG_POL_COMP_CLM_CNT) AS TTL_UW_ELIG_POL_COMP_CLM_CNT,
MIN(UW_AUTO.TTL_UW_ELIG_POL_MLTY_PRMT_CNT) AS TTL_UW_ELIG_POL_MLTY_PRMT_CNT,
MIN(UW_AUTO.TTL_UW_ELIG_POL_PERM_USE_ACCID_CNT) AS TTL_UW_ELIG_POL_PERM_USE_ACCID_CNT,
MIN(UW_AUTO.TTL_UW_ELIG_RENTL_TOW_GLASS_CNT) AS TTL_UW_ELIG_RENTL_TOW_GLASS_CNT,
MIN(UW_AUTO.DERIVED_TTL_ACCID_VIO_COMP_CNT) AS DERIVED_TTL_ACCID_VIO_COMP_CNT,
MIN(UW_AUTO.DERIVED_YES_NO_FLAG) AS DERIVED_YES_NO_FLAG,

-- Aggregates from Auto Operational Loss
SUM(AUTO_OP_LOSS.INCUR_CLM_CNT_XCAT) AS INCUR_CLM_CNT_XCAT,
SUM(AUTO_OP_LOSS.DERIV_INCUR_LOSS_AMT_XCAT) AS DERIV_INCUR_LOSS_AMT_XCAT,
SUM(AUTO_OP_LOSS.GLASS_TOW_INCUR_CLM_CNT) AS GLASS_TOW_INCUR_CLM_CNT,
SUM(AUTO_OP_LOSS.GLASS_TOW_INCUR_LOSS_AMT) AS GLASS_TOW_INCUR_LOSS_AMT,

SUM(AUTO_OP_LOSS.DERIV_ADJ_EP_AMT) AS EP,                    -- Earned Premium
SUM(AUTO_OP_LOSS.RERATED_EP_EPAPR_AMT) AS EPAPR,             -- Earned Premium At Present Rates
DAY(LAST_DAY(TO_DATE(EARNED_MONTH || '01', 'YYYYMMDD'))) /   -- Calculates # of days in Month
IFF(MOD(SUBSTR('202407', 1, 4), 4) = 0 AND (MOD(SUBSTR('202407', 1, 4), 100) != 0 OR MOD(SUBSTR('202407', 1, 4), 400) = 0), 366, 365) -- Calculates # of days in years
AS EE                                                        -- Earned Exposure calculation
FROM "DSC_PLBI_DB"."APP_AUTO_PRD"."AUTO_OPERATIONAL_LOSS" AS AUTO_OP_LOSS
JOIN USER_DB.AD1_PA08042.UNDERWRITING_AUTO_POLICIES AS UW_AUTO
ON AUTO_OP_LOSS.POL_ID = UW_AUTO.POL_ID
WHERE COV_TYPE_ABBR != 'PUP'
AND EARNED_MONTH >= '202407'                  -- Filter for only showing data past July 2024
GROUP BY UW_AUTO.POL_ID, EARNED_MONTH         -- Grouped by Policy ID and Earned Month
ORDER BY UW_AUTO.POL_ID, EARNED_MONTH         -- Ordered by Policy ID and Earned Month
)
