-- sql/create_tables.sql
-- Creates staging, dimension and analytics tables

-- 1) Staging table for CRM CSV
IF OBJECT_ID('stg.crm_companies') IS NOT NULL DROP TABLE stg.crm_companies;
CREATE SCHEMA IF NOT EXISTS stg;
GO
CREATE TABLE stg.crm_companies (
  company_id VARCHAR(100) NOT NULL,
  name VARCHAR(255),
  country VARCHAR(100),
  industry_tag VARCHAR(100),
  last_contact_at DATETIME2,
  file_date DATE,
  src_file_name VARCHAR(255),
  ingested_at DATETIME2 DEFAULT SYSUTCDATETIME()
);
CREATE INDEX ix_stg_crm_company_id ON stg.crm_companies(company_id);

-- 2) Staging table for product usage
IF OBJECT_ID('stg.product_usage') IS NOT NULL DROP TABLE stg.product_usage;
CREATE TABLE stg.product_usage (
  company_id VARCHAR(100) NOT NULL,
  date DATE NOT NULL,
  active_users INT,
  events INT,
  src_ingested_at DATETIME2,
  src_file_name VARCHAR(255),
  raw_json NVARCHAR(MAX)
);
CREATE INDEX ix_stg_usage_company_date ON stg.product_usage(company_id, date);

-- 3) Dimension companies
IF OBJECT_ID('dim.companies') IS NOT NULL DROP TABLE dim.companies;
CREATE SCHEMA IF NOT EXISTS dim;
CREATE TABLE dim.companies (
  company_id VARCHAR(100) PRIMARY KEY,
  name VARCHAR(255),
  country VARCHAR(100),
  industry_tag VARCHAR(100),
  last_contact_at DATETIME2,
  created_at DATETIME2 DEFAULT SYSUTCDATETIME(),
  updated_at DATETIME2 DEFAULT SYSUTCDATETIME()
);

-- 4) Analytics table
IF OBJECT_ID('analytics.company_activity_daily') IS NOT NULL DROP TABLE analytics.company_activity_daily;
CREATE SCHEMA IF NOT EXISTS analytics;
CREATE TABLE analytics.company_activity_daily (
  company_id VARCHAR(100) NOT NULL,
  activity_date DATE NOT NULL,
  company_name VARCHAR(255),
  country VARCHAR(100),
  industry_tag VARCHAR(100),
  last_contact_at DATETIME2,
  active_users INT,
  events INT,
  engagement_score FLOAT,
  activity_consistency_30d FLOAT,
  rolling_7d_active_users INT,
  rolling_30d_events INT,
  active_users_mom_pct FLOAT,
  usage_density FLOAT,
  is_churn_risk BIT,
  est_monthly_active_users INT,
  source VARCHAR(50),
  data_quality_flag VARCHAR(50),
  created_at DATETIME2 DEFAULT SYSUTCDATETIME(),
  updated_at DATETIME2 DEFAULT SYSUTCDATETIME(),
  CONSTRAINT pk_company_activity PRIMARY KEY (company_id, activity_date)
);
CREATE INDEX ix_analytics_date_company ON analytics.company_activity_daily(activity_date, company_id);
