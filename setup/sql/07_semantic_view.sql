-- ============================================================
-- OpsMind AI — 07_semantic_view.sql
-- Deploy semantic view from YAML specification
-- Target schema: OPSMIND.APP
-- ============================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE OPSMIND_WH;
USE DATABASE OPSMIND;

-- Grant CREATE SEMANTIC VIEW on APP schema to ACCOUNTADMIN (idempotent)
-- ACCOUNTADMIN already owns the schema, so this is a no-op but explicit.

-- Deploy the semantic view from the YAML specification.
-- The YAML is inlined here for reproducibility.
-- To regenerate: read semantic/opsmind_operations.yaml
CALL SYSTEM$CREATE_SEMANTIC_VIEW_FROM_YAML(
  'OPSMIND.APP',
  $$
name: OPSMIND_OPERATIONS
description: >
  Manufacturing operations intelligence semantic model.
  Covers plant hierarchy, equipment telemetry, OEE metrics,
  maintenance history, failure records, work orders, and
  anomaly signals. Designed for natural-language investigation
  of operational problems across any plant, line, or machine.

module_custom_instructions:
  sql_generation: >
    When comparing machines, always include machine_id and machine_name
    in the output. When analyzing trends over time, order results
    chronologically. Sensor readings use a long format with sensor_type
    as a discriminator — filter on sensor_type to get specific
    measurements (e.g. sensor_type = 'vibration' for vibration data,
    sensor_type = 'bearing_temp' for bearing temperature). OEE is
    recorded per machine per date per shift — aggregate across shifts
    to get daily values. Maintenance status values include 'completed',
    'scheduled', 'overdue', and 'cancelled'. Work order priority values
    are 'critical', 'high', 'medium', 'low'. Anomaly severity values
    are 'critical', 'warning', 'info'.

tables:
  - name: PLANTS
    description: Manufacturing facilities (plants).
    synonyms:
      - factories
      - sites
      - facilities
    base_table:
      database: OPSMIND
      schema: CORE
      table: PLANTS
    primary_key:
      columns:
        - PLANT_ID
    dimensions:
      - name: PLANT_ID
        description: Unique plant identifier
        expr: PLANT_ID
        data_type: VARCHAR
      - name: PLANT_NAME
        synonyms:
          - factory name
          - site name
        description: Human-readable plant name
        expr: PLANT_NAME
        data_type: VARCHAR
      - name: REGION
        description: Geographic region of the plant
        expr: REGION
        data_type: VARCHAR
        is_enum: true
        sample_values:
          - Midwest
          - Southeast
          - West Coast
      - name: PLANT_TYPE
        description: Type of manufacturing facility
        expr: PLANT_TYPE
        data_type: VARCHAR
        is_enum: true
        sample_values:
          - Heavy Manufacturing
          - Precision Manufacturing
          - Assembly & Integration
    metrics:
      - name: PLANT_COUNT
        description: Number of plants
        expr: COUNT(DISTINCT PLANT_ID)

  - name: PRODUCTION_LINES
    description: Production lines within plants.
    synonyms:
      - lines
      - manufacturing lines
    base_table:
      database: OPSMIND
      schema: CORE
      table: PRODUCTION_LINES
    primary_key:
      columns:
        - LINE_ID
    dimensions:
      - name: LINE_ID
        description: Unique production line identifier
        expr: LINE_ID
        data_type: VARCHAR
      - name: LINE_NAME
        synonyms:
          - production line name
        description: Human-readable line name
        expr: LINE_NAME
        data_type: VARCHAR
      - name: PRODUCT_TYPE
        synonyms:
          - product
          - what the line produces
        description: Type of product manufactured on this line
        expr: PRODUCT_TYPE
        data_type: VARCHAR
    facts:
      - name: DESIGN_CAPACITY_UNITS_HR
        synonyms:
          - capacity
          - throughput capacity
          - design capacity
        description: Nameplate throughput in units per hour
        expr: DESIGN_CAPACITY_UNITS_HR
        data_type: NUMBER
    metrics:
      - name: LINE_COUNT
        description: Number of production lines
        expr: COUNT(DISTINCT LINE_ID)
      - name: TOTAL_DESIGN_CAPACITY
        synonyms:
          - total capacity
        description: Sum of design capacity across lines
        expr: SUM(DESIGN_CAPACITY_UNITS_HR)

  - name: MACHINES
    description: Individual equipment assets on production lines.
    synonyms:
      - equipment
      - assets
      - machines
    base_table:
      database: OPSMIND
      schema: CORE
      table: MACHINES
    primary_key:
      columns:
        - MACHINE_ID
    dimensions:
      - name: MACHINE_ID
        description: Unique machine identifier (e.g. M-301, M-302)
        expr: MACHINE_ID
        data_type: VARCHAR
      - name: MACHINE_NAME
        synonyms:
          - equipment name
        description: Descriptive name of the machine
        expr: MACHINE_NAME
        data_type: VARCHAR
      - name: MACHINE_TYPE
        synonyms:
          - equipment type
          - type of machine
        description: Equipment category
        expr: MACHINE_TYPE
        data_type: VARCHAR
        is_enum: true
        sample_values:
          - CNC Milling Center
          - CNC Lathe
          - Hydraulic Press
          - Assembly Robot
          - Welding Station
      - name: MANUFACTURER
        description: Equipment manufacturer / OEM
        expr: MANUFACTURER
        data_type: VARCHAR
      - name: MODEL
        description: Equipment model identifier
        expr: MODEL
        data_type: VARCHAR
      - name: STATUS
        synonyms:
          - machine status
          - equipment status
          - current status
        description: Current operational status of the machine
        expr: STATUS
        data_type: VARCHAR
        is_enum: true
        sample_values:
          - operational
          - degraded
          - down
          - maintenance
    time_dimensions:
      - name: INSTALL_DATE
        description: Date the machine was installed
        expr: INSTALL_DATE
        data_type: DATE
      - name: LAST_OVERHAUL_DATE
        description: Date of the most recent major overhaul (null if never overhauled)
        expr: LAST_OVERHAUL_DATE
        data_type: DATE
    facts:
      - name: CRITICALITY_RATING
        synonyms:
          - criticality
          - importance rating
        description: Criticality rating from 1 (lowest) to 5 (highest)
        expr: CRITICALITY_RATING
        data_type: NUMBER
    metrics:
      - name: MACHINE_COUNT
        synonyms:
          - number of machines
          - equipment count
        description: Number of machines
        expr: COUNT(DISTINCT MACHINE_ID)

  - name: SENSOR_READINGS
    description: >
      High-frequency equipment telemetry readings. Each row is one
      sensor measurement. The sensor_type column discriminates the
      type of reading: vibration, bearing_temp, spindle_speed,
      power_consumption, coolant_pressure.
    synonyms:
      - telemetry
      - sensor data
      - readings
    base_table:
      database: OPSMIND
      schema: CORE
      table: SENSOR_READINGS
    primary_key:
      columns:
        - READING_ID
    dimensions:
      - name: READING_ID
        description: Unique reading identifier
        expr: READING_ID
        data_type: VARCHAR
      - name: SENSOR_TYPE
        synonyms:
          - measurement type
          - sensor
          - type of sensor
        description: >
          Type of sensor measurement. Values: vibration, bearing_temp,
          spindle_speed, power_consumption, coolant_pressure.
        expr: SENSOR_TYPE
        data_type: VARCHAR
        is_enum: true
        sample_values:
          - vibration
          - bearing_temp
          - spindle_speed
          - power_consumption
          - coolant_pressure
      - name: UNIT
        description: Unit of measurement (mm/s, degrees C, RPM, kW, bar)
        expr: UNIT
        data_type: VARCHAR
        is_enum: true
        sample_values:
          - mm/s
          - RPM
          - kW
          - bar
    time_dimensions:
      - name: READING_TS
        synonyms:
          - reading time
          - measurement time
          - reading timestamp
        description: Timestamp of the sensor reading
        expr: READING_TS
        data_type: TIMESTAMP_NTZ
    facts:
      - name: VALUE
        synonyms:
          - sensor value
          - reading value
          - measurement
        description: The measured sensor value
        expr: VALUE
        data_type: FLOAT
    metrics:
      - name: AVG_SENSOR_VALUE
        synonyms:
          - average sensor value
          - average reading
          - mean sensor value
        description: Average sensor reading value
        expr: AVG(VALUE)
      - name: MAX_SENSOR_VALUE
        synonyms:
          - maximum sensor value
          - peak reading
          - max reading
        description: Maximum sensor reading value
        expr: MAX(VALUE)
      - name: MIN_SENSOR_VALUE
        synonyms:
          - minimum sensor value
          - min reading
        description: Minimum sensor reading value
        expr: MIN(VALUE)
      - name: READING_COUNT
        synonyms:
          - number of readings
          - measurement count
        description: Count of sensor readings
        expr: COUNT(READING_ID)

  - name: OEE_METRICS
    description: >
      Overall Equipment Effectiveness metrics per machine per date
      per shift. OEE = availability x performance x quality / 10000.
      Values are percentages (0-100).
    synonyms:
      - OEE
      - equipment effectiveness
      - OEE data
    base_table:
      database: OPSMIND
      schema: CORE
      table: OEE_METRICS
    primary_key:
      columns:
        - OEE_ID
    dimensions:
      - name: OEE_ID
        description: Unique OEE record identifier
        expr: OEE_ID
        data_type: VARCHAR
      - name: SHIFT
        synonyms:
          - work shift
        description: Shift when OEE was measured (day, swing, night)
        expr: SHIFT
        data_type: VARCHAR
        is_enum: true
        sample_values:
          - day
          - swing
          - night
    time_dimensions:
      - name: METRIC_DATE
        synonyms:
          - OEE date
          - date
          - measurement date
        description: Date of the OEE measurement
        expr: METRIC_DATE
        data_type: DATE
    facts:
      - name: AVAILABILITY_PCT
        synonyms:
          - availability
          - uptime percentage
        description: Availability component of OEE (0-100%)
        expr: AVAILABILITY_PCT
        data_type: FLOAT
      - name: PERFORMANCE_PCT
        synonyms:
          - performance
          - speed efficiency
        description: Performance component of OEE (0-100%)
        expr: PERFORMANCE_PCT
        data_type: FLOAT
      - name: QUALITY_PCT
        synonyms:
          - quality
          - quality rate
        description: Quality component of OEE (0-100%)
        expr: QUALITY_PCT
        data_type: FLOAT
      - name: OEE_PCT
        synonyms:
          - OEE
          - overall equipment effectiveness
          - OEE percentage
        description: Overall Equipment Effectiveness percentage (0-100%)
        expr: OEE_PCT
        data_type: FLOAT
      - name: PLANNED_PRODUCTION_HRS
        synonyms:
          - planned hours
        description: Scheduled production hours
        expr: PLANNED_PRODUCTION_HRS
        data_type: FLOAT
      - name: ACTUAL_PRODUCTION_HRS
        synonyms:
          - actual hours
          - runtime hours
        description: Actual production runtime hours
        expr: ACTUAL_PRODUCTION_HRS
        data_type: FLOAT
      - name: UNITS_PRODUCED
        synonyms:
          - production count
          - parts produced
        description: Number of units produced
        expr: UNITS_PRODUCED
        data_type: NUMBER
      - name: UNITS_DEFECTIVE
        synonyms:
          - defects
          - defective units
          - rejected units
        description: Number of defective units
        expr: UNITS_DEFECTIVE
        data_type: NUMBER
      - name: DOWNTIME_MINUTES
        synonyms:
          - downtime
          - unplanned downtime
        description: Unplanned downtime in minutes
        expr: DOWNTIME_MINUTES
        data_type: NUMBER
    metrics:
      - name: AVG_OEE
        synonyms:
          - average OEE
          - mean OEE
        description: Average OEE percentage across records
        expr: AVG(OEE_PCT)
      - name: AVG_AVAILABILITY
        synonyms:
          - average availability
        description: Average availability percentage
        expr: AVG(AVAILABILITY_PCT)
      - name: AVG_PERFORMANCE
        synonyms:
          - average performance
        description: Average performance percentage
        expr: AVG(PERFORMANCE_PCT)
      - name: AVG_QUALITY
        synonyms:
          - average quality
        description: Average quality percentage
        expr: AVG(QUALITY_PCT)
      - name: TOTAL_DOWNTIME_MINUTES
        synonyms:
          - total downtime
          - cumulative downtime
        description: Total unplanned downtime in minutes
        expr: SUM(DOWNTIME_MINUTES)
      - name: TOTAL_UNITS_PRODUCED
        synonyms:
          - total production
          - total units
        description: Total units produced
        expr: SUM(UNITS_PRODUCED)
      - name: TOTAL_DEFECTIVE_UNITS
        synonyms:
          - total defects
        description: Total defective units
        expr: SUM(UNITS_DEFECTIVE)

  - name: MAINTENANCE_HISTORY
    description: >
      Completed and scheduled maintenance activities for machines.
      Includes preventive, corrective, predictive, and inspection types.
    synonyms:
      - maintenance
      - maintenance records
      - service history
    base_table:
      database: OPSMIND
      schema: CORE
      table: MAINTENANCE_HISTORY
    primary_key:
      columns:
        - MAINTENANCE_ID
    dimensions:
      - name: MAINTENANCE_ID
        description: Unique maintenance record identifier
        expr: MAINTENANCE_ID
        data_type: VARCHAR
      - name: MAINTENANCE_TYPE
        synonyms:
          - type of maintenance
          - service type
        description: Type of maintenance activity
        expr: MAINTENANCE_TYPE
        data_type: VARCHAR
        is_enum: true
        sample_values:
          - preventive
          - corrective
          - predictive
          - inspection
      - name: DESCRIPTION
        synonyms:
          - maintenance description
          - work description
        description: Description of the maintenance work
        expr: DESCRIPTION
        data_type: VARCHAR
      - name: COMPONENT
        synonyms:
          - part
          - equipment component
          - maintained component
        description: Component targeted by maintenance (bearing, spindle, motor, etc.)
        expr: COMPONENT
        data_type: VARCHAR
      - name: TECHNICIAN
        synonyms:
          - maintenance worker
          - service technician
        description: Technician assigned to the maintenance
        expr: TECHNICIAN
        data_type: VARCHAR
      - name: MAINTENANCE_STATUS
        synonyms:
          - maintenance status
          - status
        description: Current status of the maintenance task
        expr: STATUS
        data_type: VARCHAR
        is_enum: true
        sample_values:
          - completed
          - scheduled
          - overdue
          - cancelled
    time_dimensions:
      - name: SCHEDULED_DATE
        synonyms:
          - planned date
          - scheduled maintenance date
        description: When the maintenance was originally scheduled
        expr: SCHEDULED_DATE
        data_type: TIMESTAMP_NTZ
      - name: COMPLETED_DATE
        synonyms:
          - completion date
          - finished date
        description: When maintenance was completed (null if pending or overdue)
        expr: COMPLETED_DATE
        data_type: TIMESTAMP_NTZ
    facts:
      - name: COST_USD
        synonyms:
          - maintenance cost
          - service cost
        description: Cost of the maintenance in USD
        expr: COST_USD
        data_type: FLOAT
    metrics:
      - name: MAINTENANCE_COUNT
        synonyms:
          - number of maintenance activities
        description: Count of maintenance records
        expr: COUNT(MAINTENANCE_ID)
      - name: TOTAL_MAINTENANCE_COST
        synonyms:
          - total service cost
        description: Total maintenance cost in USD
        expr: SUM(COST_USD)
      - name: AVG_MAINTENANCE_COST
        synonyms:
          - average service cost
        description: Average maintenance cost in USD
        expr: AVG(COST_USD)

  - name: FAILURE_HISTORY
    description: >
      Historical equipment failure records. Each row represents a
      failure event with root cause, severity, downtime, and repair details.
    synonyms:
      - failures
      - breakdowns
      - failure records
    base_table:
      database: OPSMIND
      schema: CORE
      table: FAILURE_HISTORY
    primary_key:
      columns:
        - FAILURE_ID
    dimensions:
      - name: FAILURE_ID
        description: Unique failure record identifier
        expr: FAILURE_ID
        data_type: VARCHAR
      - name: FAILURE_MODE
        synonyms:
          - failure type
          - type of failure
          - failure category
        description: Category of the failure
        expr: FAILURE_MODE
        data_type: VARCHAR
      - name: ROOT_CAUSE
        synonyms:
          - cause
          - reason for failure
        description: Determined root cause of the failure
        expr: ROOT_CAUSE
        data_type: VARCHAR
      - name: FAILURE_SEVERITY
        synonyms:
          - severity
          - failure severity
        description: Severity level of the failure
        expr: SEVERITY
        data_type: VARCHAR
        is_enum: true
        sample_values:
          - critical
          - major
          - minor
      - name: CORRECTIVE_ACTION
        synonyms:
          - repair action
          - fix applied
        description: Action taken to resolve the failure
        expr: CORRECTIVE_ACTION
        data_type: VARCHAR
    time_dimensions:
      - name: FAILURE_START
        synonyms:
          - failure date
          - when it failed
          - failure onset
        description: Timestamp when the failure began
        expr: FAILURE_START
        data_type: TIMESTAMP_NTZ
      - name: FAILURE_END
        synonyms:
          - repair date
          - resolution time
        description: Timestamp when the failure was resolved
        expr: FAILURE_END
        data_type: TIMESTAMP_NTZ
    facts:
      - name: FAILURE_DOWNTIME_MINUTES
        synonyms:
          - failure downtime
          - downtime from failure
        description: Total downtime caused by the failure in minutes
        expr: DOWNTIME_MINUTES
        data_type: NUMBER
      - name: REPAIR_COST_USD
        synonyms:
          - repair cost
          - failure cost
        description: Cost to repair the failure in USD
        expr: REPAIR_COST_USD
        data_type: FLOAT
    metrics:
      - name: FAILURE_COUNT
        synonyms:
          - number of failures
          - breakdown count
        description: Count of failure events
        expr: COUNT(FAILURE_ID)
      - name: TOTAL_FAILURE_DOWNTIME
        synonyms:
          - total failure downtime
        description: Total downtime from failures in minutes
        expr: SUM(DOWNTIME_MINUTES)
      - name: TOTAL_REPAIR_COST
        synonyms:
          - total failure cost
        description: Total repair cost in USD
        expr: SUM(REPAIR_COST_USD)
      - name: AVG_REPAIR_COST
        synonyms:
          - average repair cost
        description: Average repair cost per failure in USD
        expr: AVG(REPAIR_COST_USD)

  - name: WORK_ORDERS
    description: >
      Maintenance work order lifecycle. Tracks creation, assignment,
      due dates, completion, and costs.
    synonyms:
      - work orders
      - WOs
      - service orders
    base_table:
      database: OPSMIND
      schema: CORE
      table: WORK_ORDERS
    primary_key:
      columns:
        - WO_ID
    dimensions:
      - name: WO_ID
        synonyms:
          - work order ID
          - work order number
        description: Unique work order identifier
        expr: WO_ID
        data_type: VARCHAR
      - name: WO_TYPE
        synonyms:
          - work order type
          - order type
        description: Type of work order
        expr: WO_TYPE
        data_type: VARCHAR
        is_enum: true
        sample_values:
          - preventive
          - corrective
          - emergency
          - inspection
      - name: PRIORITY
        synonyms:
          - work order priority
          - urgency
        description: Priority level of the work order
        expr: PRIORITY
        data_type: VARCHAR
        is_enum: true
        sample_values:
          - critical
          - high
          - medium
          - low
      - name: WO_STATUS
        synonyms:
          - work order status
          - order status
        description: Current status of the work order
        expr: STATUS
        data_type: VARCHAR
        is_enum: true
        sample_values:
          - open
          - in_progress
          - completed
          - cancelled
      - name: WO_DESCRIPTION
        synonyms:
          - work description
        description: Description of the work to be performed
        expr: DESCRIPTION
        data_type: VARCHAR
      - name: ASSIGNED_TO
        synonyms:
          - assignee
          - technician
        description: Person or team assigned to the work order
        expr: ASSIGNED_TO
        data_type: VARCHAR
    time_dimensions:
      - name: CREATED_DATE
        synonyms:
          - work order created date
          - creation date
        description: When the work order was created
        expr: CREATED_DATE
        data_type: TIMESTAMP_NTZ
      - name: DUE_DATE
        synonyms:
          - target date
          - deadline
        description: Target completion date for the work order
        expr: DUE_DATE
        data_type: TIMESTAMP_NTZ
      - name: WO_COMPLETED_DATE
        synonyms:
          - work order completion date
        description: When the work order was actually completed
        expr: COMPLETED_DATE
        data_type: TIMESTAMP_NTZ
    facts:
      - name: ESTIMATED_COST_USD
        synonyms:
          - estimated cost
          - budget
        description: Budget estimate for the work order in USD
        expr: ESTIMATED_COST_USD
        data_type: FLOAT
      - name: ACTUAL_COST_USD
        synonyms:
          - actual cost
          - final cost
        description: Actual cost of completed work in USD
        expr: ACTUAL_COST_USD
        data_type: FLOAT
    metrics:
      - name: WORK_ORDER_COUNT
        synonyms:
          - number of work orders
          - WO count
        description: Count of work orders
        expr: COUNT(WO_ID)
      - name: TOTAL_ESTIMATED_COST
        description: Total estimated cost across work orders
        expr: SUM(ESTIMATED_COST_USD)
      - name: TOTAL_ACTUAL_COST
        description: Total actual cost across work orders
        expr: SUM(ACTUAL_COST_USD)

  - name: ANOMALY_SIGNALS
    description: >
      System-detected anomaly indicators. Each row is an anomaly
      signal detected for a machine, with signal type, severity,
      confidence, and deviation from baseline.
    synonyms:
      - anomalies
      - alerts
      - anomaly alerts
    base_table:
      database: OPSMIND
      schema: AI
      table: ANOMALY_SIGNALS
    primary_key:
      columns:
        - ANOMALY_ID
    dimensions:
      - name: ANOMALY_ID
        description: Unique anomaly signal identifier
        expr: ANOMALY_ID
        data_type: VARCHAR
      - name: SIGNAL_TYPE
        synonyms:
          - anomaly type
          - alert type
        description: Type of anomaly detected
        expr: SIGNAL_TYPE
        data_type: VARCHAR
        is_enum: true
        sample_values:
          - vibration_anomaly
          - thermal_anomaly
          - oee_decline
          - performance_loss
      - name: ANOMALY_SEVERITY
        synonyms:
          - severity
          - alert severity
        description: Severity level of the anomaly
        expr: SEVERITY
        data_type: VARCHAR
        is_enum: true
        sample_values:
          - critical
          - warning
          - info
      - name: ANOMALY_DESCRIPTION
        synonyms:
          - anomaly description
        description: Human-readable description of the anomaly
        expr: DESCRIPTION
        data_type: VARCHAR
      - name: SOURCE_METRIC
        description: The metric that triggered the anomaly detection
        expr: SOURCE_METRIC
        data_type: VARCHAR
    time_dimensions:
      - name: DETECTED_AT
        synonyms:
          - detection time
          - anomaly date
          - when detected
        description: Timestamp when the anomaly was detected
        expr: DETECTED_AT
        data_type: TIMESTAMP_NTZ
    facts:
      - name: CONFIDENCE_SCORE
        synonyms:
          - confidence
        description: Confidence score of the anomaly detection (0.0 to 1.0)
        expr: CONFIDENCE_SCORE
        data_type: FLOAT
      - name: BASELINE_VALUE
        description: Expected normal value for the metric
        expr: BASELINE_VALUE
        data_type: FLOAT
      - name: OBSERVED_VALUE
        description: Actual observed value that triggered the anomaly
        expr: OBSERVED_VALUE
        data_type: FLOAT
      - name: DEVIATION_PCT
        synonyms:
          - deviation
          - deviation percentage
        description: Percentage deviation from baseline
        expr: DEVIATION_PCT
        data_type: FLOAT
    metrics:
      - name: ANOMALY_COUNT
        synonyms:
          - number of anomalies
          - alert count
        description: Count of anomaly signals
        expr: COUNT(ANOMALY_ID)
      - name: AVG_DEVIATION
        synonyms:
          - average deviation
        description: Average deviation percentage from baseline
        expr: AVG(DEVIATION_PCT)
      - name: MAX_DEVIATION
        synonyms:
          - maximum deviation
          - worst deviation
        description: Maximum deviation percentage from baseline
        expr: MAX(DEVIATION_PCT)

relationships:
  - name: LINES_TO_PLANTS
    left_table: PRODUCTION_LINES
    right_table: PLANTS
    relationship_columns:
      - left_column: PLANT_ID
        right_column: PLANT_ID

  - name: MACHINES_TO_LINES
    left_table: MACHINES
    right_table: PRODUCTION_LINES
    relationship_columns:
      - left_column: LINE_ID
        right_column: LINE_ID

  - name: SENSOR_READINGS_TO_MACHINES
    left_table: SENSOR_READINGS
    right_table: MACHINES
    relationship_columns:
      - left_column: MACHINE_ID
        right_column: MACHINE_ID

  - name: OEE_TO_MACHINES
    left_table: OEE_METRICS
    right_table: MACHINES
    relationship_columns:
      - left_column: MACHINE_ID
        right_column: MACHINE_ID

  - name: MAINTENANCE_TO_MACHINES
    left_table: MAINTENANCE_HISTORY
    right_table: MACHINES
    relationship_columns:
      - left_column: MACHINE_ID
        right_column: MACHINE_ID

  - name: FAILURES_TO_MACHINES
    left_table: FAILURE_HISTORY
    right_table: MACHINES
    relationship_columns:
      - left_column: MACHINE_ID
        right_column: MACHINE_ID

  - name: WORK_ORDERS_TO_MACHINES
    left_table: WORK_ORDERS
    right_table: MACHINES
    relationship_columns:
      - left_column: MACHINE_ID
        right_column: MACHINE_ID

  - name: ANOMALIES_TO_MACHINES
    left_table: ANOMALY_SIGNALS
    right_table: MACHINES
    relationship_columns:
      - left_column: MACHINE_ID
        right_column: MACHINE_ID
  $$
);
