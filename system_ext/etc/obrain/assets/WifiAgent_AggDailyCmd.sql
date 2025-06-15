-- val_start_ts,      --obrain_start_ts
-- val_end_ts,        --obrain_end_ts
-- val_wall_start_ts  --wall_start_ts_round

insert into agg_wifi_app_daily
SELECT {val_start_ts} as 'start_ts', {val_end_ts} as 'end_ts', {val_wall_start_ts} as 'timestamp',
     name as 'name'
    , sum(foreground_duration) as foreground_duration
    , sum(foreground_tx_bytes) as foreground_tx_bytes
    , sum(foreground_rx_bytes) as foreground_rx_bytes
    , sum(foreground_energy) as foreground_energy
    , sum(background_duration) as background_duration
    , sum(background_tx_bytes) as background_tx_bytes
    , sum(background_rx_bytes) as background_rx_bytes
    , sum(background_energy) as background_energy
    , sum(screen_on_duration) as screen_on_duration
    , sum(screen_on_tx_bytes) as screen_on_tx_bytes
    , sum(screen_on_rx_bytes) as screen_on_rx_bytes
    , sum(screen_on_energy) as screen_on_energy
    , sum(screen_off_duration) as screen_off_duration
    , sum(screen_off_tx_bytes) as screen_off_tx_bytes
    , sum(screen_off_rx_bytes) as screen_off_rx_bytes
    , sum(screen_off_energy) as screen_off_energy
from agg_wifi_app_hourly
where start_ts >= {val_start_ts} and end_ts <= {val_end_ts}
group by name;

insert into agg_wifi_state_device_daily
SELECT {val_start_ts} as 'start_ts', {val_end_ts} as 'end_ts', {val_wall_start_ts} as 'timestamp'
    , charge as 'charge', screen as 'screen', ground as 'ground', enable as 'enable'
    , sum(tx_bytes) as 'tx_bytes', sum(rx_bytes) as 'rx_bytes', sum(tx_packet) as 'tx_packet', sum(rx_packet) as 'rx_packet'
    , sum(tx_time) as 'tx_time', sum(rx_time) as 'rx_time', sum(idle_time) as 'idle_time'
    , hotspot as 'hotspot', band as 'band', band_width as 'band_width', standard as 'standard', antenna as 'antenna'
    , avg(rssi) as 'rssi', sum(energy) as 'energy'
from agg_wifi_state_device_hourly
where start_ts >= {val_start_ts} and end_ts <= {val_end_ts}
group by charge, screen, ground, enable, hotspot, band, standard, band_width, antenna;

--by_app  upload dcs-------------------------------------------------------------------------
select upload_dcs('{upload_dcs_key}', '{log_tag_app}', '{config_id_app}', {version}, '{type}', {agent_type},
                  '{id}', '{start_wall_time}', '{end_wall_time}', '{meta_data}', by_app)
from (
    select json_insert(json_set('{{}}', '$.column_key', json(column_key)), '$.row_value', json(row_value)) as 'by_app'
    from (
        select
            json_set('{{}}', '$', json_array('timestamp', 'name',
                'foreground_duration', 'foreground_tx_bytes', 'foreground_rx_bytes', 'foreground_energy',
                'background_duration', 'background_tx_bytes', 'background_rx_bytes', 'background_energy',
                'screen_on_duration', 'screen_on_tx_bytes', 'screen_on_rx_bytes', 'screen_on_energy',
                'screen_off_duration', 'screen_off_tx_bytes', 'screen_off_rx_bytes', 'screen_off_energy'
            )) as column_key,
            json_set('{{}}', '$', json_group_array(
                json_array(timestamp, obfuscate(name),
                    foreground_duration, foreground_tx_bytes, foreground_rx_bytes, foreground_energy,
                    background_duration, background_tx_bytes, background_rx_bytes, background_energy,
                    screen_on_duration, screen_on_tx_bytes, screen_on_rx_bytes, screen_on_energy,
                    screen_off_duration, screen_off_tx_bytes, screen_off_rx_bytes, screen_off_energy
                )
            ))  as row_value
        from agg_wifi_app_daily
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
            json_set('{{}}', '$', json_array('timestamp',
                'charge', 'screen', 'ground', 'enable',
                'tx_bytes', 'rx_bytes', 'tx_packet', 'rx_packet',
                'tx_time', 'rx_time', 'idle_time',
                'hotspot', 'band', 'band_width', 'standard',
                'antenna', 'rssi', 'energy'
            )) as column_key,
            json_set('{{}}', '$', json_group_array(
                json_array(timestamp,
                    charge, screen, ground, enable,
                    tx_bytes, rx_bytes, tx_packet, rx_packet,
                    tx_time, rx_time, idle_time,
                    hotspot, band, band_width, standard,
                    antenna, rssi, energy
                )
            ))  as row_value
        from agg_wifi_state_device_daily
        where start_ts >= {val_start_ts} and end_ts <= {val_end_ts}
    )
);
