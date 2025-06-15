with
uidstate_tmp as (
    select  power_mode, screen_mode, thermal_mode, ground_mode
                    , case when pid = -1 and tgid = -1 then 0 else 1 end as type
                    , pid_name, tgid_name, uid_name
                    , VectorVectorII('sum(c$0_$1_du) as c$0_$1_du', CpuClusterList, CpuFreqListList)
                    , VectorSuffixSumVectorII(' as c$0_duration', 'sum(c$0_$1_du)', CpuClusterList, CpuFreqListList)
                    , case when ground_mode = 1 then sum(end_ts - start_ts) else 0 end as wall_du
                    , sum(total_eg) as total_eg, sum(pmu_total_eg) as pmu_total_eg
    from comp_uidstate_cpuagent_backward
    WHERE (start_ts >= {val_start_ts} AND end_ts <= {val_end_ts})
        and power_mode = 0 and screen_mode != -1 and thermal_mode != -1 and ground_mode != -1
    group by power_mode, screen_mode, thermal_mode, ground_mode, pid_name, tgid_name, uid_name
)
insert into agg_uidstate_cpuagent_hourly
(
start_ts,
end_ts,
power_mode,
screen_mode,
thermal_mode,
ground_mode,
type,
pid_name,
tgid_name,
uid_name,
VectorVectorII('c$0_$1_du', CpuClusterList, CpuFreqListList),
VectorI('c$0_duration', CpuClusterList),
total_duration,
wall_du,
total_eg,
pmu_total_eg
)
select {val_start_ts} AS 'start_ts', {val_end_ts} AS 'end_ts', power_mode, screen_mode, thermal_mode, ground_mode, type, pid_name, tgid_name, uid_name,
    VectorVectorII('sum(c$0_$1_du) as c$0_$1_du', CpuClusterList, CpuFreqListList),
    VectorSuffixSumVectorII(' as c$0_duration', 'sum(c$0_$1_du)', CpuClusterList, CpuFreqListList),
    SumVectorI('sum(c$0_duration)', CpuClusterList) as total_du,
    sum(wall_du) as wall_du,
    sum(total_eg) as total_eg,
    sum(pmu_total_eg) as pmu_total_eg
from uidstate_tmp
group by power_mode, screen_mode, thermal_mode, ground_mode, type, pid_name, tgid_name, uid_name;

-- val_start_ts,      -- obrain_start_ts
-- val_end_ts,        -- obrain_end_ts
-- val_wall_start_ts  -- wall_start_ts_round

WITH
-- temporary table HOURLY_DATA
-- A. SELECT the event data of corresponding an hourly interval between var_obrain_start_ts and var_obrain_end_ts
-- B. compute c%d_du power consumption duration: eg, c0_du = sum(c0_%d_du), c1_du = sum(c1_%d_du)...
HOURLY_DATA AS (
    SELECT uid,
        CASE WHEN tgid_name != '' THEN tgid_name ELSE uid_name END AS name,
        ground_mode, screen_mode, sum(total_eg) AS total_energy,
        VectorVectorII('sum(c$0_$1_du) AS c$0_$1_du', CpuClusterList, CpuFreqListList),
        VectorSuffixSumVectorII(' AS c$0_duration', 'sum(c$0_$1_du)', CpuClusterList, CpuFreqListList)
    FROM comp_uidstate_cpuagent_backward
    WHERE (start_ts >= {val_start_ts} AND end_ts <= {val_end_ts})
        AND (uid != -1)
        AND NOT (((pid = -1) AND (tgid = -1)) AND ((uid_name LIKE 'root@%') OR (uid_name LIKE 'system@%')))
        AND power_mode = 0
    GROUP BY uid, CASE WHEN tgid_name != '' THEN tgid_name ELSE uid_name END, ground_mode, screen_mode
),
-- temporary table HOURLY_DATA: total_duration = c0_du + c1_du +...
HOURLY_DATA_EG_DU AS (
    SELECT uid, name, ground_mode, screen_mode, total_energy,
                SumVectorI('sum(c$0_duration)', CpuClusterList) AS total_duration
    FROM HOURLY_DATA
    GROUP BY uid, name, ground_mode, screen_mode, total_energy
)

INSERT INTO agg_cpu_app_hourly
SELECT
    {val_start_ts} AS 'start_ts',
    {val_end_ts} AS 'end_ts',
    {val_wall_start_ts} AS 'timestamp',
    uid,
    name,
    sum(case when ground_mode = 1 then total_duration else 0 end) AS foreground_duration,
    sum(case when ground_mode = 1 then total_energy else 0 end) AS foreground_energy,
    sum(case when ground_mode = 0 then total_duration else 0 end) AS background_duration,
    sum(case when ground_mode = 0 then total_energy else 0 end) AS background_energy,
    sum(case when screen_mode = 1 then total_duration else 0 end) AS screen_on_duration,
    sum(case when screen_mode = 1 then total_energy else 0 end) AS screen_on_energy,
    sum(case when screen_mode = 0 then total_duration else 0 end) AS screen_off_duration,
    sum(case when screen_mode = 0 then total_energy else 0 end) AS screen_off_energy
FROM HOURLY_DATA_EG_DU
GROUP BY uid, name;

