-- val_start_ts,      --obrain_start_ts
-- val_end_ts,        --obrain_end_ts
-- val_wall_start_ts  --wall_start_ts_round

insert into agg_gpu_app_daily
SELECT {val_start_ts} as 'start_ts', {val_end_ts} as 'end_ts', {val_wall_start_ts} as 'timestamp', name,
    sum(duration) as 'duration',
    avg(usage) as 'usage',
    sum(energy) as 'energy'
from agg_gpu_app_hourly
where start_ts >= {val_start_ts} and end_ts <= {val_end_ts}
group by name;

insert into agg_gpu_device_daily
SELECT {val_start_ts} as 'start_ts', {val_end_ts} as 'end_ts', {val_wall_start_ts} as 'timestamp',
    sum(duration) as 'duration',
    avg(usage) as 'usage',
    sum(energy) as 'energy'
from agg_gpu_app_daily
where start_ts >= {val_start_ts} and end_ts <= {val_end_ts};

--by_app  upload dcs-------------------------------------------------------------------------
select upload_dcs('{upload_dcs_key}', '{log_tag_app}', '{config_id_app}', {version}, '{type}', {agent_type},
                  '{id}', '{start_wall_time}', '{end_wall_time}', '{meta_data}', by_app)
from (
    select json_insert(json_set('{{}}', '$.column_key', json(column_key)), '$.row_value', json(row_value)) as 'by_app'
    from (
        select
            json_set('{{}}', '$', json_array('timestamp', 'name', 'duration', 'usage', 'energy')) as column_key,
            json_set('{{}}', '$', json_group_array(
                json_array(timestamp, obfuscate(name), duration, usage, energy)
            ))  as row_value
        from agg_gpu_app_daily
        where start_ts >= {val_start_ts} and end_ts <= {val_end_ts}
    )
);

--by_device  upload dcs-------------------------------------------------------------------------
select upload_dcs('{upload_dcs_key}', '{log_tag_device}', '{config_id_device}', {version}, '{type}', {agent_type},
                  '{id}', '{start_wall_time}', '{end_wall_time}', '{meta_data}', by_device)
from (
    select json_insert(json_set('{{}}', '$.column_key', json(column_key)), '$.row_value', json(row_value)) as 'by_device'
    from (
        select
            json_set('{{}}', '$', json_array('timestamp', 'duration', 'usage', 'energy')) as column_key,
            json_set('{{}}', '$', json_group_array(
                json_array(timestamp, duration, usage, energy)
            ))  as row_value
        from agg_gpu_device_daily
        where start_ts >= {val_start_ts} and end_ts <= {val_end_ts}
    )
);
