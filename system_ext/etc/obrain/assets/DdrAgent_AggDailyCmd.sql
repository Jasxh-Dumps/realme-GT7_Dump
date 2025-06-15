-- val_start_ts,      --obrain_start_ts
-- val_end_ts,        --obrain_end_ts
-- val_wall_start_ts  --wall_start_ts_round

INSERT INTO agg_ddr_app_daily
SELECT
    {val_start_ts} AS start_ts,
    {val_end_ts} AS end_ts,
    {val_wall_start_ts} AS timestamp,
    name,
    sum(screen_on_energy) AS screen_on_energy,
    sum(screen_off_energy) AS screen_off_energy
FROM agg_ddr_app_hourly
WHERE start_ts >= {val_start_ts} AND end_ts <= {val_end_ts}
GROUP BY name;

INSERT INTO agg_ddr_device_daily
SELECT
    start_ts,
	end_ts,
	timestamp,
    sum(screen_on_energy) AS screen_on_energy,
    sum(screen_off_energy) AS screen_off_energy
FROM agg_ddr_app_daily
WHERE start_ts >= {val_start_ts} AND end_ts <= {val_end_ts}
GROUP BY start_ts, end_ts, timestamp;

--by_app  upload dcs-------------------------------------------------------------------------
SELECT upload_dcs('{upload_dcs_key}', '{log_tag_app}', '{config_id_app}', {version}, '{type}', {agent_type},
                  '{id}', '{start_wall_time}', '{end_wall_time}', '{meta_data}', by_app)
FROM (
    SELECT json_insert(json_set('{{}}', '$.column_key', json(column_key)), '$.row_value', json(row_value)) AS 'by_app'
    FROM (
        SELECT
            json_set('{{}}', '$', json_array('timestamp', 'name',
                'screen_on_energy', 'screen_off_energy')) AS column_key,
            json_set('{{}}', '$', json_group_array(json_array(timestamp, obfuscate(name),
                screen_on_energy, screen_off_energy))) AS row_value
        FROM agg_ddr_app_daily
        WHERE start_ts >= {val_start_ts} AND end_ts <= {val_end_ts}
    )
);

--by_device  upload dcs-------------------------------------------------------------------------
SELECT upload_dcs('{upload_dcs_key}', '{log_tag_device}', '{config_id_device}', {version}, '{type}', {agent_type},
                  '{id}', '{start_wall_time}', '{end_wall_time}', '{meta_data}', by_device)
FROM (
    SELECT json_insert(json_set('{{}}', '$.column_key', json(column_key)), '$.row_value', json(row_value)) AS 'by_device'
    FROM (
        SELECT
            json_set('{{}}', '$', json_array('timestamp',
                'screen_on_energy', 'screen_off_energy')) AS column_key,
            json_set('{{}}', '$', json_group_array(json_array(timestamp,
                screen_on_energy, screen_off_energy))) AS row_value
        FROM agg_ddr_device_daily
        WHERE start_ts >= {val_start_ts} AND end_ts <= {val_end_ts}
    )
);


--by_app
--|start_ts     |end_ts       |timesptamp---|----name----|foreground_duration| foreground_energy|background_duration|background_energy|screen_on_duration  |screen_on_energy|screen_off_duration|screen_off_energy
--|1676359917975|1676359958037|1676358000000|Binder:horae|24067             |630372              |1477               |33888           |25430              |661645             |114                |       2615
--|1676359917975|1676359958037|1676358000000|Kworker     |27214             |648866              |0                 |0                |27214              |648866             |0                     |       0

--by_device
--|start_ts     |end_ts       |timesptamp---|foreground_duration|foreground_energy|background_duration|background_energy|screen_on_duration|screen_on_energy|screen_off_duration|screen_off_energy
--|1676359917975|1676359958037|1676358000000|24067              |630372              |1477               |33888          |25430           |661645          |114                |       2615
