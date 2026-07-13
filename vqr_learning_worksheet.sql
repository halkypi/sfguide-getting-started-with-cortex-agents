-- =============================================================================
-- VQR (Verified Query Representations) Learning Worksheet
-- Run each section one at a time in Snowsight to learn how VQRs work
-- =============================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE SALES_INTELLIGENCE_WH;
USE DATABASE SALES_INTELLIGENCE;
USE SCHEMA DATA;

-- =============================================================================
-- SECTION 1: Understand the data we're working with
-- =============================================================================

SELECT * FROM SALES_METRICS;

-- =============================================================================
-- SECTION 2: Create a Semantic View (the modern approach to semantic models)
-- A semantic view is like the YAML model but lives as a Snowflake object.
-- VQRs are embedded directly in the definition.
-- =============================================================================

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

-- =============================================================================
-- SECTION 3: Add column descriptions and metadata
-- These help Cortex Analyst understand what each column means
-- =============================================================================

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

-- =============================================================================
-- SECTION 4: Test Cortex Analyst WITHOUT VQRs first
-- This gives you a baseline to see how Analyst interprets questions on its own
-- =============================================================================

-- Ask a question - Analyst generates SQL from the semantic view definition alone
SELECT SNOWFLAKE.CORTEX.ANALYST(
  'How many deals did Sarah Johnson win?',
  SEMANTIC_VIEW_OBJECT => 'SALES_INTELLIGENCE.DATA.SALES_METRICS_SV'
);

-- Try another question
SELECT SNOWFLAKE.CORTEX.ANALYST(
  'What is the total deal value by product line?',
  SEMANTIC_VIEW_OBJECT => 'SALES_INTELLIGENCE.DATA.SALES_METRICS_SV'
);

-- =============================================================================
-- SECTION 5: Add VQRs (Verified Queries)
-- VQRs are known-good question/SQL pairs. When a user asks something similar,
-- Analyst uses the verified SQL as a template instead of generating from scratch.
-- =============================================================================

-- VQR 1: Deals won by a specific rep
ALTER SEMANTIC VIEW SALES_METRICS_SV
  ADD VERIFIED QUERY 'deals_won_by_rep'
    QUESTION = 'How many deals did Sarah Johnson win?'
    SQL = '
      SELECT COUNT(*) AS deals_won
      FROM SALES_INTELLIGENCE.DATA.SALES_METRICS
      WHERE SALES_REP = ''Sarah Johnson''
        AND WIN_STATUS = TRUE
    ';

-- VQR 2: Total deal value by product line
ALTER SEMANTIC VIEW SALES_METRICS_SV
  ADD VERIFIED QUERY 'value_by_product'
    QUESTION = 'What is the total deal value by product line?'
    SQL = '
      SELECT PRODUCT_LINE, SUM(DEAL_VALUE) AS total_deal_value
      FROM SALES_INTELLIGENCE.DATA.SALES_METRICS
      GROUP BY PRODUCT_LINE
      ORDER BY total_deal_value DESC
    ';

-- VQR 3: Win rate by sales rep
ALTER SEMANTIC VIEW SALES_METRICS_SV
  ADD VERIFIED QUERY 'win_rate_by_rep'
    QUESTION = 'What is the win rate for each sales rep?'
    SQL = '
      SELECT
        SALES_REP,
        COUNT(*) AS total_deals,
        SUM(CASE WHEN WIN_STATUS = TRUE THEN 1 ELSE 0 END) AS deals_won,
        ROUND(SUM(CASE WHEN WIN_STATUS = TRUE THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS win_rate_pct
      FROM SALES_INTELLIGENCE.DATA.SALES_METRICS
      GROUP BY SALES_REP
      ORDER BY win_rate_pct DESC
    ';

-- VQR 4: Lost deals with high value
ALTER SEMANTIC VIEW SALES_METRICS_SV
  ADD VERIFIED QUERY 'high_value_lost_deals'
    QUESTION = 'Which deals were lost that had a value over 50000?'
    SQL = '
      SELECT DEAL_ID, CUSTOMER_NAME, SALES_REP, DEAL_VALUE, CLOSE_DATE
      FROM SALES_INTELLIGENCE.DATA.SALES_METRICS
      WHERE WIN_STATUS = FALSE
        AND DEAL_VALUE > 50000
      ORDER BY DEAL_VALUE DESC
    ';

-- =============================================================================
-- SECTION 6: Verify the VQRs were added
-- =============================================================================

SHOW VERIFIED QUERIES IN SEMANTIC VIEW SALES_METRICS_SV;

-- =============================================================================
-- SECTION 7: Test Analyst again WITH VQRs
-- Now ask the same questions - Analyst should use the verified SQL
-- =============================================================================

-- This should match VQR 'deals_won_by_rep' exactly
SELECT SNOWFLAKE.CORTEX.ANALYST(
  'How many deals did Sarah Johnson win?',
  SEMANTIC_VIEW_OBJECT => 'SALES_INTELLIGENCE.DATA.SALES_METRICS_SV'
);

-- This is a variation - Analyst should recognize it's similar to the VQR
-- and adapt the verified SQL (changing the rep name)
SELECT SNOWFLAKE.CORTEX.ANALYST(
  'How many deals did Mike Chen win?',
  SEMANTIC_VIEW_OBJECT => 'SALES_INTELLIGENCE.DATA.SALES_METRICS_SV'
);

-- This should match 'win_rate_by_rep'
SELECT SNOWFLAKE.CORTEX.ANALYST(
  'Show me each reps win rate',
  SEMANTIC_VIEW_OBJECT => 'SALES_INTELLIGENCE.DATA.SALES_METRICS_SV'
);

-- =============================================================================
-- SECTION 8: Run a VQR Evaluation
-- This tests whether Analyst generates SQL that produces equivalent results
-- to your verified queries. It's how you measure accuracy.
-- =============================================================================

SELECT SNOWFLAKE.CORTEX.ANALYST_EVALUATE(
  SEMANTIC_VIEW_OBJECT => 'SALES_INTELLIGENCE.DATA.SALES_METRICS_SV',
  METRIC => 'sql_correctness'
);

-- =============================================================================
-- SECTION 9: Manage VQRs
-- You can remove or replace VQRs as your model evolves
-- =============================================================================

-- Remove a VQR
-- ALTER SEMANTIC VIEW SALES_METRICS_SV DROP VERIFIED QUERY 'high_value_lost_deals';

-- View the semantic view definition (includes VQRs)
-- DESCRIBE SEMANTIC VIEW SALES_METRICS_SV;

-- =============================================================================
-- KEY TAKEAWAYS:
-- 1. VQRs live in semantic views (or YAML models) as question/SQL pairs
-- 2. They act as "golden examples" that Analyst uses when questions are similar
-- 3. Analyst can adapt VQR SQL to new parameters (e.g., different rep names)
-- 4. ANALYST_EVALUATE lets you measure how well Analyst matches your VQRs
-- 5. You don't need an agent - VQRs improve Cortex Analyst directly
-- 6. When you later add Analyst as a tool to an agent, the VQRs benefit it too
-- =============================================================================
