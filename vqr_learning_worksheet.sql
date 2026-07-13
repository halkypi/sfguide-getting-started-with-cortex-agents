-- VQR (Verified Query Representations) Learning Worksheet
-- Run each section one at a time in Snowsight

-- SETUP
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE SALES_INTELLIGENCE_WH;
USE DATABASE SALES_INTELLIGENCE;
USE SCHEMA DATA;

-- SECTION 1: Look at the data
SELECT * FROM SALES_METRICS;

-- SECTION 2: Create a Semantic View (without VQRs first as a baseline)
CREATE OR REPLACE SEMANTIC VIEW SALES_METRICS_SV

  TABLES (
    sales_metrics AS SALES_INTELLIGENCE.DATA.SALES_METRICS
      PRIMARY KEY (DEAL_ID)
      COMMENT = 'Sales deal metrics table'
  )

  DIMENSIONS (
    sales_metrics.customer_name AS CUSTOMER_NAME
      WITH SYNONYMS = ('client', 'buyer', 'account name')
      COMMENT = 'The name of the customer associated with the sale',
    sales_metrics.sales_stage AS SALES_STAGE
      WITH SYNONYMS = ('deal status', 'opportunity state')
      SAMPLE_VALUES ('Closed', 'Lost', 'Pending')
      IS_ENUM
      COMMENT = 'Current stage: Closed, Lost, or Pending',
    sales_metrics.win_status AS WIN_STATUS
      COMMENT = 'Whether the deal was won (TRUE) or lost (FALSE)',
    sales_metrics.sales_rep AS SALES_REP
      WITH SYNONYMS = ('salesperson', 'account manager', 'rep')
      SAMPLE_VALUES ('Sarah Johnson', 'Mike Chen', 'Rachel Torres')
      COMMENT = 'The sales representative responsible for the deal',
    sales_metrics.product_line AS PRODUCT_LINE
      WITH SYNONYMS = ('product family', 'product type')
      SAMPLE_VALUES ('Enterprise Suite', 'Basic Package', 'Premium Security')
      IS_ENUM
      COMMENT = 'Product category',
    sales_metrics.close_date AS CLOSE_DATE
      WITH SYNONYMS = ('sale date', 'deal close date')
      COMMENT = 'The date the deal was closed or finalized'
  )

  METRICS (
    sales_metrics.total_deal_value AS SUM(DEAL_VALUE)
      WITH SYNONYMS = ('total revenue', 'total sales')
      COMMENT = 'Sum of deal values',
    sales_metrics.deal_count AS COUNT(DEAL_ID)
      COMMENT = 'Number of deals',
    sales_metrics.avg_deal_value AS AVG(DEAL_VALUE)
      COMMENT = 'Average deal value'
  )

  COMMENT = 'Semantic view for sales metrics - no VQRs yet';

-- SECTION 3: Test Cortex Analyst WITHOUT VQRs (baseline)
SELECT SNOWFLAKE.CORTEX.ANALYST(
  'How many deals did Sarah Johnson win?',
  SEMANTIC_VIEW_OBJECT => 'SALES_INTELLIGENCE.DATA.SALES_METRICS_SV'
);

SELECT SNOWFLAKE.CORTEX.ANALYST(
  'What is the total deal value by product line?',
  SEMANTIC_VIEW_OBJECT => 'SALES_INTELLIGENCE.DATA.SALES_METRICS_SV'
);

-- SECTION 4: Recreate the semantic view WITH VQRs
-- VQRs are added via the AI_VERIFIED_QUERIES clause
CREATE OR REPLACE SEMANTIC VIEW SALES_METRICS_SV

  TABLES (
    sales_metrics AS SALES_INTELLIGENCE.DATA.SALES_METRICS
      PRIMARY KEY (DEAL_ID)
      COMMENT = 'Sales deal metrics table'
  )

  DIMENSIONS (
    sales_metrics.customer_name AS CUSTOMER_NAME
      WITH SYNONYMS = ('client', 'buyer', 'account name')
      COMMENT = 'The name of the customer associated with the sale',
    sales_metrics.sales_stage AS SALES_STAGE
      WITH SYNONYMS = ('deal status', 'opportunity state')
      SAMPLE_VALUES ('Closed', 'Lost', 'Pending')
      IS_ENUM
      COMMENT = 'Current stage: Closed, Lost, or Pending',
    sales_metrics.win_status AS WIN_STATUS
      COMMENT = 'Whether the deal was won (TRUE) or lost (FALSE)',
    sales_metrics.sales_rep AS SALES_REP
      WITH SYNONYMS = ('salesperson', 'account manager', 'rep')
      SAMPLE_VALUES ('Sarah Johnson', 'Mike Chen', 'Rachel Torres')
      COMMENT = 'The sales representative responsible for the deal',
    sales_metrics.product_line AS PRODUCT_LINE
      WITH SYNONYMS = ('product family', 'product type')
      SAMPLE_VALUES ('Enterprise Suite', 'Basic Package', 'Premium Security')
      IS_ENUM
      COMMENT = 'Product category',
    sales_metrics.close_date AS CLOSE_DATE
      WITH SYNONYMS = ('sale date', 'deal close date')
      COMMENT = 'The date the deal was closed or finalized'
  )

  METRICS (
    sales_metrics.total_deal_value AS SUM(DEAL_VALUE)
      WITH SYNONYMS = ('total revenue', 'total sales')
      COMMENT = 'Sum of deal values',
    sales_metrics.deal_count AS COUNT(DEAL_ID)
      COMMENT = 'Number of deals',
    sales_metrics.avg_deal_value AS AVG(DEAL_VALUE)
      COMMENT = 'Average deal value'
  )

  COMMENT = 'Semantic view for sales metrics with verified queries'

  AI_VERIFIED_QUERIES (
    deals_won_by_rep AS (
      QUESTION 'How many deals did Sarah Johnson win?'
      VERIFIED_AT 1752451200
      ONBOARDING_QUESTION TRUE
      VERIFIED_BY '(STEWARD = data_team)'
      SQL 'SELECT COUNT(*) AS deals_won FROM SALES_INTELLIGENCE.DATA.SALES_METRICS WHERE SALES_REP = ''Sarah Johnson'' AND WIN_STATUS = TRUE'
    ),
    value_by_product AS (
      QUESTION 'What is the total deal value by product line?'
      VERIFIED_AT 1752451200
      ONBOARDING_QUESTION TRUE
      VERIFIED_BY '(STEWARD = data_team)'
      SQL 'SELECT PRODUCT_LINE, SUM(DEAL_VALUE) AS total_deal_value FROM SALES_INTELLIGENCE.DATA.SALES_METRICS GROUP BY PRODUCT_LINE ORDER BY total_deal_value DESC'
    ),
    win_rate_by_rep AS (
      QUESTION 'What is the win rate for each sales rep?'
      VERIFIED_AT 1752451200
      ONBOARDING_QUESTION FALSE
      VERIFIED_BY '(STEWARD = data_team)'
      SQL 'SELECT SALES_REP, COUNT(*) AS total_deals, SUM(CASE WHEN WIN_STATUS = TRUE THEN 1 ELSE 0 END) AS deals_won, ROUND(SUM(CASE WHEN WIN_STATUS = TRUE THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS win_rate_pct FROM SALES_INTELLIGENCE.DATA.SALES_METRICS GROUP BY SALES_REP ORDER BY win_rate_pct DESC'
    ),
    high_value_lost_deals AS (
      QUESTION 'Which deals were lost that had a value over 50000?'
      VERIFIED_AT 1752451200
      ONBOARDING_QUESTION FALSE
      VERIFIED_BY '(STEWARD = data_team)'
      SQL 'SELECT DEAL_ID, CUSTOMER_NAME, SALES_REP, DEAL_VALUE, CLOSE_DATE FROM SALES_INTELLIGENCE.DATA.SALES_METRICS WHERE WIN_STATUS = FALSE AND DEAL_VALUE > 50000 ORDER BY DEAL_VALUE DESC'
    )
  );

-- SECTION 5: Verify the semantic view was created with VQRs
DESCRIBE SEMANTIC VIEW SALES_METRICS_SV;

-- SECTION 6: Test Analyst WITH VQRs
-- This should match the 'deals_won_by_rep' VQR exactly
SELECT SNOWFLAKE.CORTEX.ANALYST(
  'How many deals did Sarah Johnson win?',
  SEMANTIC_VIEW_OBJECT => 'SALES_INTELLIGENCE.DATA.SALES_METRICS_SV'
);

-- Variation: Analyst adapts the VQR SQL for a different rep name
SELECT SNOWFLAKE.CORTEX.ANALYST(
  'How many deals did Mike Chen win?',
  SEMANTIC_VIEW_OBJECT => 'SALES_INTELLIGENCE.DATA.SALES_METRICS_SV'
);

-- This should match 'win_rate_by_rep'
SELECT SNOWFLAKE.CORTEX.ANALYST(
  'Show me each reps win rate',
  SEMANTIC_VIEW_OBJECT => 'SALES_INTELLIGENCE.DATA.SALES_METRICS_SV'
);

-- SECTION 7: Run a VQR Evaluation (scores Analyst accuracy against your VQRs)
SELECT SNOWFLAKE.CORTEX.ANALYST_EVALUATE(
  SEMANTIC_VIEW_OBJECT => 'SALES_INTELLIGENCE.DATA.SALES_METRICS_SV',
  METRIC => 'sql_correctness'
);

-- SECTION 8: Cleanup (optional)
-- DROP SEMANTIC VIEW SALES_METRICS_SV;
