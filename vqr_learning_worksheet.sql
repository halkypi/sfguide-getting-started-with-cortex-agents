-- VQR (Verified Query Representations) Learning Worksheet
-- Run each section one at a time in Snowsight to learn how VQRs work

-- SETUP
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE SALES_INTELLIGENCE_WH;
USE DATABASE SALES_INTELLIGENCE;
USE SCHEMA DATA;

-- SECTION 1: Look at the data
SELECT * FROM SALES_METRICS;

-- SECTION 2: Create a Semantic View
CREATE OR REPLACE SEMANTIC VIEW SALES_METRICS_SV
  COMMENT = 'Semantic view for sales metrics with verified queries'
AS
  SELECT
    DEAL_ID,
    CUSTOMER_NAME,
    SALES_STAGE,
    WIN_STATUS,
    SALES_REP,
    PRODUCT_LINE,
    CLOSE_DATE,
    DEAL_VALUE
  FROM SALES_METRICS;

-- SECTION 3: Add column descriptions and metadata
ALTER SEMANTIC VIEW SALES_METRICS_SV
  SET COLUMN DEAL_ID
    COMMENT = 'Unique identifier for a sales deal'
    SYNONYMS = ('Transaction ID', 'Agreement ID', 'Deal Number');

ALTER SEMANTIC VIEW SALES_METRICS_SV
  SET COLUMN CUSTOMER_NAME
    COMMENT = 'The name of the customer associated with the sale'
    SYNONYMS = ('client', 'buyer', 'account name');

ALTER SEMANTIC VIEW SALES_METRICS_SV
  SET COLUMN SALES_STAGE
    COMMENT = 'Current stage: Closed, Lost, or Pending'
    SYNONYMS = ('deal status', 'opportunity state', 'pipeline position');

ALTER SEMANTIC VIEW SALES_METRICS_SV
  SET COLUMN WIN_STATUS
    COMMENT = 'Whether the deal was won (TRUE) or lost (FALSE)'
    SYNONYMS = ('won', 'success', 'converted');

ALTER SEMANTIC VIEW SALES_METRICS_SV
  SET COLUMN SALES_REP
    COMMENT = 'The sales representative responsible for the deal'
    SYNONYMS = ('salesperson', 'account manager', 'rep');

ALTER SEMANTIC VIEW SALES_METRICS_SV
  SET COLUMN PRODUCT_LINE
    COMMENT = 'Product category: Enterprise Suite, Basic Package, or Premium Security'
    SYNONYMS = ('product family', 'product type');

ALTER SEMANTIC VIEW SALES_METRICS_SV
  SET COLUMN CLOSE_DATE
    COMMENT = 'The date the deal was closed or finalized'
    DATA_TYPE = DATE
    SYNONYMS = ('sale date', 'deal close date');

ALTER SEMANTIC VIEW SALES_METRICS_SV
  SET COLUMN DEAL_VALUE
    COMMENT = 'Total monetary value of the deal in dollars'
    DATA_TYPE = NUMBER
    SYNONYMS = ('revenue', 'sale amount', 'deal amount');

-- SECTION 4: Test Cortex Analyst WITHOUT VQRs (baseline)
SELECT SNOWFLAKE.CORTEX.ANALYST(
  'How many deals did Sarah Johnson win?',
  SEMANTIC_VIEW_OBJECT => 'SALES_INTELLIGENCE.DATA.SALES_METRICS_SV'
);

SELECT SNOWFLAKE.CORTEX.ANALYST(
  'What is the total deal value by product line?',
  SEMANTIC_VIEW_OBJECT => 'SALES_INTELLIGENCE.DATA.SALES_METRICS_SV'
);

-- SECTION 5: Add VQRs (known-good question/SQL pairs)
ALTER SEMANTIC VIEW SALES_METRICS_SV
  ADD VERIFIED QUERY 'deals_won_by_rep'
    QUESTION = 'How many deals did Sarah Johnson win?'
    SQL = 'SELECT COUNT(*) AS deals_won FROM SALES_INTELLIGENCE.DATA.SALES_METRICS WHERE SALES_REP = ''Sarah Johnson'' AND WIN_STATUS = TRUE';

ALTER SEMANTIC VIEW SALES_METRICS_SV
  ADD VERIFIED QUERY 'value_by_product'
    QUESTION = 'What is the total deal value by product line?'
    SQL = 'SELECT PRODUCT_LINE, SUM(DEAL_VALUE) AS total_deal_value FROM SALES_INTELLIGENCE.DATA.SALES_METRICS GROUP BY PRODUCT_LINE ORDER BY total_deal_value DESC';

ALTER SEMANTIC VIEW SALES_METRICS_SV
  ADD VERIFIED QUERY 'win_rate_by_rep'
    QUESTION = 'What is the win rate for each sales rep?'
    SQL = 'SELECT SALES_REP, COUNT(*) AS total_deals, SUM(CASE WHEN WIN_STATUS = TRUE THEN 1 ELSE 0 END) AS deals_won, ROUND(SUM(CASE WHEN WIN_STATUS = TRUE THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS win_rate_pct FROM SALES_INTELLIGENCE.DATA.SALES_METRICS GROUP BY SALES_REP ORDER BY win_rate_pct DESC';

ALTER SEMANTIC VIEW SALES_METRICS_SV
  ADD VERIFIED QUERY 'high_value_lost_deals'
    QUESTION = 'Which deals were lost that had a value over 50000?'
    SQL = 'SELECT DEAL_ID, CUSTOMER_NAME, SALES_REP, DEAL_VALUE, CLOSE_DATE FROM SALES_INTELLIGENCE.DATA.SALES_METRICS WHERE WIN_STATUS = FALSE AND DEAL_VALUE > 50000 ORDER BY DEAL_VALUE DESC';

-- SECTION 6: Verify VQRs were added
SHOW VERIFIED QUERIES IN SEMANTIC VIEW SALES_METRICS_SV;

-- SECTION 7: Test Analyst WITH VQRs (should use verified SQL as template)
SELECT SNOWFLAKE.CORTEX.ANALYST(
  'How many deals did Sarah Johnson win?',
  SEMANTIC_VIEW_OBJECT => 'SALES_INTELLIGENCE.DATA.SALES_METRICS_SV'
);

-- Variation: Analyst adapts the VQR SQL for a different rep name
SELECT SNOWFLAKE.CORTEX.ANALYST(
  'How many deals did Mike Chen win?',
  SEMANTIC_VIEW_OBJECT => 'SALES_INTELLIGENCE.DATA.SALES_METRICS_SV'
);

SELECT SNOWFLAKE.CORTEX.ANALYST(
  'Show me each reps win rate',
  SEMANTIC_VIEW_OBJECT => 'SALES_INTELLIGENCE.DATA.SALES_METRICS_SV'
);

-- SECTION 8: Run VQR Evaluation (scores Analyst accuracy against your VQRs)
SELECT SNOWFLAKE.CORTEX.ANALYST_EVALUATE(
  SEMANTIC_VIEW_OBJECT => 'SALES_INTELLIGENCE.DATA.SALES_METRICS_SV',
  METRIC => 'sql_correctness'
);

-- SECTION 9: Managing VQRs (uncomment to use)
-- ALTER SEMANTIC VIEW SALES_METRICS_SV DROP VERIFIED QUERY 'high_value_lost_deals';
-- DESCRIBE SEMANTIC VIEW SALES_METRICS_SV;
