WITH
TOP_UID_TMP as (
    select null as pid_name, null as tgid_name, uid_name, power_mode, screen_mode, thermal_mode, ground_mode
        , VectorSuffixSumVectorII('as c$0_duration', 'sum(c$0_$1_du)', CpuClusterList, CpuFreqListList)
        , VectorVectorII('sum(c$0_$1_du) as c$0_$1_du', CpuClusterList, CpuFreqListList)
        , sum(pmu_total_eg) as pmu_total_eg
        , sum(total_eg) as total_eg
        , sum(wall_du) as wall_du
        , row_number() over (partition by screen_mode, ground_mode order by sum(total_eg) desc) as idx
    from agg_uidstate_cpuagent_hourly
    where type = 0 and start_ts >= {val_start_ts} AND end_ts <= {val_end_ts} AND power_mode = 0
    group by power_mode, screen_mode, thermal_mode, ground_mode, uid_name
),
TOP_UID as (
    select 'uid' as type, obfuscate(uid_name) as name, null as parent, null as grand_parent, TOP_UID_TMP.*
    from TOP_UID_TMP
    where idx <= 10
),
-- TOP_TGID ---------------------------------------
T2 as (
    select tgid_name, uid_name, power_mode, screen_mode, thermal_mode, ground_mode
        , VectorSuffixSumVectorII('  as c$0_duration', 'sum(c$0_$1_du)', CpuClusterList, CpuFreqListList)
        , VectorVectorII('sum(c$0_$1_du) as c$0_$1_du', CpuClusterList, CpuFreqListList)
        , sum(pmu_total_eg) as pmu_total_eg
        , sum(total_eg) as total_eg
        , 0 as wall_du
    from agg_uidstate_cpuagent_hourly
    where type = 1 and start_ts >= {val_start_ts} AND end_ts <= {val_end_ts} AND power_mode = 0
    group by tgid_name, uid_name, power_mode, screen_mode, thermal_mode, ground_mode
),
TOP_TGID_TMP as (
    select null as pid_name, T2.tgid_name, T1.uid_name, T1.power_mode, T1.screen_mode, T1.thermal_mode, T1.ground_mode
        , VectorI('T2.c$0_duration', CpuClusterList)
        , VectorVectorII('T2.c$0_$1_du', CpuClusterList, CpuFreqListList)
        , T2.pmu_total_eg as pmu_total_eg
        , T2.total_eg as total_eg
        , T2.wall_du as wall_du
        , row_number() over (partition by T1.screen_mode, T1.ground_mode, T1.uid_name order by T2.total_eg desc) as idx
    from TOP_UID T1 inner join T2
    on T1.power_mode = T2.power_mode
        and T1.screen_mode = T2.screen_mode
        and T1.thermal_mode = T2.thermal_mode
        and T1.ground_mode = T2.ground_mode
        and T1.uid_name = T2.uid_name
),
TOP_TGID as (
    select 'process' as type, tgid_name as name, obfuscate(uid_name) as parent, null as grand_parent, TOP_TGID_TMP.*
    from TOP_TGID_TMP
    where idx <= 10
),
-- TOP_T3T4 --------------------------------------
T4 as (
    select pid_name, tgid_name, uid_name, power_mode, screen_mode, thermal_mode, ground_mode
        , VectorSuffixSumVectorII('  as c$0_duration', 'sum(c$0_$1_du)', CpuClusterList, CpuFreqListList)
        , VectorVectorII('sum(c$0_$1_du) as c$0_$1_du', CpuClusterList, CpuFreqListList)
        , sum(pmu_total_eg) as pmu_total_eg
        , sum(total_eg) as total_eg
        , sum(wall_du) as wall_du
    from agg_uidstate_cpuagent_hourly
    where type = 1 and start_ts >= {val_start_ts} AND end_ts <= {val_end_ts} AND power_mode = 0
    group by power_mode, screen_mode, thermal_mode, ground_mode, uid_name, tgid_name, pid_name
),
T3T4 as (
    select T4.pid_name, T3.tgid_name, T3.uid_name, T3.power_mode, T3.screen_mode, T3.thermal_mode, T3.ground_mode
        , VectorI('T4.c$0_duration', CpuClusterList)
        , VectorVectorII('T4.c$0_$1_du', CpuClusterList, CpuFreqListList)
        , T4.pmu_total_eg as pmu_total_eg
        , T4.total_eg as total_eg
        , T4.wall_du as wall_du
        , row_number() over (partition by T3.screen_mode, T3.ground_mode, T3.uid_name, T3.tgid_name order by T4.total_eg desc) as idx
    from TOP_TGID T3 inner join T4
    on T3.power_mode = T4.power_mode
        and T3.screen_mode = T4.screen_mode
        and T3.thermal_mode = T4.thermal_mode
        and T3.ground_mode = T4.ground_mode
        and T3.tgid_name = T4.tgid_name
        and T3.uid_name = T4.uid_name
),
TOP_T3T4 as (
    select 'thread' as type, pid_name as name, tgid_name as parent, obfuscate(uid_name) as grand_parent, pid_name, tgid_name, uid_name, power_mode, screen_mode, thermal_mode, ground_mode
        , VectorI('c$0_duration', CpuClusterList)
        , VectorVectorII('c$0_$1_du', CpuClusterList, CpuFreqListList)
        , pmu_total_eg
        , total_eg
        , wall_du
        , idx
    from T3T4
    where idx <= 10
),
-----------------------------------------------------
ALL_TOP as (
    select * from TOP_UID
    union
    select * from TOP_TGID
    union
    select * from TOP_T3T4
),
TOP_TBL_TMP as (
select '{{' || '"name":' || '"' || name || '",'
            || '"mode":' || '"' || ground_mode || screen_mode || '",'
            || MapJsonFormatI('"c$0_du"', 'c$0_duration', CpuClusterList) || ','
            || MapVectorJsonFormatII('"c$0_fdu"', "c$0_$1_du", CpuClusterList, CpuFreqListList) || ","
            || '"typ":"' || type || '",'
            || '"parent":"' || ifnull(parent, '') || '",'
            || '"grand_parent":"' || ifnull(grand_parent, '') || '",'
            || '"wall_du":"' || wall_du || '",'
            || '"pmu_total_eg":"' || pmu_total_eg || '",'
            || '"total_eg":"' || total_eg || '"}}' as oneline
        from ALL_TOP
),
TOP_TBL as (
    select '[' || group_concat(oneline) || ']' as energy
    from TOP_TBL_TMP
),
CPU_FREQUENCY_FG_TBL_TMP as (
    select '[' || group_concat(by_category, ', ') || ']' as cluster_freq_du
    from (
        select "{{" || '"mode":' || '"' || screen_mode || thermal_mode || power_mode || '",'
        || MapSumVectorJsonFormatII('"c$0_fdu_total"', 'sum(c$0_$1_du)', CpuClusterList, CpuFreqListList) || ","
        || MapVectorJsonFormatII('"c$0_fdu"', 'sum(c$0_$1_du)', CpuClusterList, CpuFreqListList) || ","
        || '"pmu":' || '"' || sum(pmu_total_eg) || '",'
        || '"w_du":' || '"' ||({val_end_ts} - {val_start_ts}) || '",'
        || '"eg":' || '"' || sum(total_eg) || '"' || "}}" as by_category
        from agg_uidstate_cpuagent_hourly
        WHERE ground_mode = 1 and start_ts >= {val_start_ts} AND end_ts <= {val_end_ts} AND power_mode = 0
        group by screen_mode, thermal_mode, power_mode
    )
),
CPU_FREQUENCY_BG_TBL_TMP as (
    select '[' || group_concat(by_category, ', ') || ']' as cluster_freq_du
    from (
        select "{{" || '"mode":' || '"' || screen_mode || thermal_mode || power_mode || '",'
        || MapSumVectorJsonFormatII('"c$0_bdu_total"', 'sum(c$0_$1_du)', CpuClusterList, CpuFreqListList) || ","
        || MapVectorJsonFormatII('"c$0_bdu"', 'sum(c$0_$1_du)', CpuClusterList, CpuFreqListList) || ","
        || '"pmu":' || '"' || sum(pmu_total_eg) || '",'
        || '"w_du":' || '"' ||({val_end_ts} - {val_start_ts}) || '",'
        || '"eg":' || '"' || sum(total_eg) || '"' || "}}" as by_category
        from agg_uidstate_cpuagent_hourly
        WHERE ground_mode = 0 and start_ts >= {val_start_ts} AND end_ts <= {val_end_ts} AND power_mode = 0
        group by screen_mode, thermal_mode, power_mode
    )
),
PWR_TBL as (
    select '{{' ||
        MapVectorJsonFormatID('"c$0_fc"', '$1', CpuClusterList, CpuFreqFactorListList) || ','
        || MapVectorJsonFormatII('"c$0_v"', '$1', CpuClusterList, CpuCoreVoltListList) || ','
        || '"lkg":' || {var_leakage} || ','
        || '"rvs":' || {var_revision} ||'}}' as power_table
)
INSERT INTO agg_cpu_frequency_app_daily
SELECT (SELECT {val_start_ts} AS start_ts), (SELECT {val_end_ts} AS end_ts), (SELECT {val_wall_start_ts} AS timestamp),
       (SELECT energy FROM TOP_TBL AS top_app),
       (SELECT cluster_freq_du FROM CPU_FREQUENCY_FG_TBL_TMP AS cluster_fg_du),
       (SELECT cluster_freq_du FROM CPU_FREQUENCY_BG_TBL_TMP AS cluster_bg_du),
       (SELECT power_table FROM PWR_TBL AS power_table);

SELECT upload_dcs('{upload_dcs_key}', '{log_tag_app}', '{config_frequency_app}', {version}, '{type}', {agent_type},
                  '{id}', '{start_wall_time}', '{end_wall_time}', '{meta_data}', by_app)
FROM (
    SELECT json_insert(json_set('{{}}', '$.column_key', json(column_key)), '$.row_value', json(row_value)) AS 'by_app'
    FROM (
        SELECT
        json_set('{{}}', '$', json_array('timestamp','top_app', 'cluster_fg_du','cluster_bg_du','power_table')) AS column_key,
        json_set('{{}}', '$', json_group_array(json_array(timestamp, top_app, cluster_fg_du, cluster_bg_du,
        power_table))) AS row_value
        FROM agg_cpu_frequency_app_daily
        WHERE start_ts >= {val_start_ts} AND end_ts <= {val_end_ts}
    )
);

INSERT INTO agg_cpu_app_daily
SELECT
    {val_start_ts} AS start_ts,
    {val_end_ts} AS end_ts,
    {val_wall_start_ts} AS timestamp,
    uid,
    name,
    sum(foreground_duration) AS foreground_duration,
    sum(foreground_energy) AS foreground_energy,
    sum(background_duration) AS background_duration,
    sum(background_energy) AS background_energy,
    sum(screen_on_duration) AS screen_on_duration,
    sum(screen_on_energy) AS screen_on_energy,
    sum(screen_off_duration) AS screen_off_duration,
    sum(screen_off_energy) AS screen_off_energy
FROM agg_cpu_app_hourly
WHERE start_ts >= {val_start_ts} AND end_ts <= {val_end_ts}
GROUP BY uid, name;

INSERT INTO agg_cpu_device_daily
SELECT
    start_ts, end_ts, timestamp,
    sum(foreground_duration) AS foreground_duration,
    sum(foreground_energy) AS foreground_energy,
    sum(background_duration) AS background_duration,
    sum(background_energy) AS background_energy,
    sum(screen_on_duration) AS screen_on_duration,
    sum(screen_on_energy) AS screen_on_energy,
    sum(screen_off_duration) AS screen_off_duration,
    sum(screen_off_energy) AS screen_off_energy
FROM agg_cpu_app_daily
WHERE start_ts >= {val_start_ts} AND end_ts <= {val_end_ts}
GROUP BY start_ts, end_ts, timestamp;

--by_app  upload dcs-------------------------------------------------------------------------
-- obfuscate: Only applications within the range of AID_APP_START to AID_APP_END require encryption
-- #define AID_APP_START 10000;  #define AID_APP_END 19999
SELECT upload_dcs('{upload_dcs_key}', '{log_tag_app}', '{config_id_app}', {version}, '{type}', {agent_type},
                  '{id}', '{start_wall_time}', '{end_wall_time}', '{meta_data}', by_app)
FROM (
    SELECT json_insert(json_set('{{}}', '$.column_key', json(column_key)), '$.row_value', json(row_value)) AS 'by_app'
    FROM (
        SELECT
            json_set('{{}}', '$', json_array('timestamp', 'uid', 'name', 'foreground_duration',
                'foreground_energy', 'background_duration', 'background_energy', 'screen_on_duration',
                'screen_on_energy', 'screen_off_duration', 'screen_off_energy')) AS column_key,
            json_set('{{}}', '$', json_group_array(json_array(timestamp, uid,
                CASE WHEN ((uid >= 10000) AND (uid <= 19999)) THEN obfuscate(name) ELSE name END,
                foreground_duration, foreground_energy, background_duration, background_energy,
                screen_on_duration, screen_on_energy, screen_off_duration, screen_off_energy))) AS row_value
        FROM (
            SELECT *
            FROM agg_cpu_app_daily
            WHERE start_ts >= {val_start_ts} AND end_ts <= {val_end_ts}
            ORDER BY (screen_on_energy + screen_off_energy) DESC
            LIMIT 100  -- TOP100-> 95%*tatol_eg
        )
    )
);

--by_device  upload dcs-------------------------------------------------------------------------
SELECT upload_dcs('{upload_dcs_key}', '{log_tag_device}', '{config_id_device}', {version}, '{type}', {agent_type},
                  '{id}', '{start_wall_time}', '{end_wall_time}', '{meta_data}', by_device)
FROM (
    SELECT json_insert(json_set('{{}}', '$.column_key', json(column_key)), '$.row_value', json(row_value)) AS 'by_device'
    FROM (
        SELECT
            json_set('{{}}', '$', json_array('timestamp', 'foreground_duration',
                'foreground_energy', 'background_duration', 'background_energy', 'screen_on_duration',
                'screen_on_energy', 'screen_off_duration', 'screen_off_energy')) AS column_key,
            json_set('{{}}', '$', json_group_array(json_array(timestamp,
                foreground_duration, foreground_energy, background_duration, background_energy,
                screen_on_duration, screen_on_energy, screen_off_duration, screen_off_energy))) AS row_value
        FROM agg_cpu_device_daily
        WHERE start_ts >= {val_start_ts} AND end_ts <= {val_end_ts}
    )
);

--by_app
--|start_ts     |end_ts       |timesptamp---|----uid-----|----name----|foreground_duration| foreground_energy|background_duration|background_energy|screen_on_duration  |screen_on_energy|screen_off_duration|screen_off_energy
--|1676359917975|1676359958037|1676358000000|1056        |Binder:horae|24067             |630372              |1477               |33888           |25430              |661645             |114                |       2615
--|1676359917975|1676359958037|1676358000000|1006        |Kworker     |27214             |648866              |0                 |0                |27214              |648866             |0                     |       0

--by_device
--|start_ts     |end_ts       |timesptamp---|foreground_duration|foreground_energy|background_duration|background_energy|screen_on_duration|screen_on_energy|screen_off_duration|screen_off_energy
--|1676359917975|1676359958037|1676358000000|24067              |630372              |1477               |33888          |25430           |661645          |114                |       2615
