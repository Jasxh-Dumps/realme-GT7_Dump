-- val_start_ts,      --obrain_start_ts
-- val_end_ts,        --obrain_end_ts
-- val_wall_start_ts  --wall_start_ts_round

insert into agg_modem_app_daily
SELECT {val_start_ts} as 'start_ts', {val_end_ts} as 'end_ts', {val_wall_start_ts} as 'timestamp', name
    , round(sum(foreground_duration), 2) as foreground_duration
    , sum(foreground_tx_bytes) as foreground_tx_bytes
    , sum(foreground_rx_bytes) as foreground_rx_bytes
    , sum(foreground_energy) as foreground_energy
    , round(sum(background_duration), 2) as background_duration
    , sum(background_tx_bytes) as background_tx_bytes
    , sum(background_rx_bytes) as background_rx_bytes
    , sum(background_energy) as background_energy
    , round(sum(screen_on_duration), 2) as screen_on_duration
    , sum(screen_on_tx_bytes) as screen_on_tx_bytes
    , sum(screen_on_rx_bytes) as screen_on_rx_bytes
    , sum(screen_on_energy) as screen_on_energy
    , round(sum(screen_off_duration), 2) as screen_off_duration
    , sum(screen_off_tx_bytes) as screen_off_tx_bytes
    , sum(screen_off_rx_bytes) as screen_off_rx_bytes
    , sum(screen_off_energy) as screen_off_energy
from agg_modem_app_hourly
where start_ts >= {val_start_ts} and end_ts <= {val_end_ts}
group by name;

insert into agg_modem_state_device_daily
SELECT {val_start_ts} as 'start_ts', {val_end_ts} as 'end_ts', {val_wall_start_ts} as 'timestamp',
    charge, screen, ground, network_type, signal_level, band, sum(incall_duration),
    sum(rx_bytes), sum(tx_bytes), sum(sleep_time), sum(rx_4g_time), sum(rx_5g_time),
    sum(tx_4g_time), sum(tx_5g_time), duplex_mode, data_activity,
    sum(transceiver_eg), sum(pa_eg), sum(modem_eg), sum(energy)
    , VectorI('sum(lvl$0_duration) as lvl$0_duration', CellularTxLevelDurationList)
    , VectorI('sum(lvl$0_5g_duration) as lvl$0_5g_duration', CellularTx5gLevelDurationList)
from agg_modem_state_device_hourly
where start_ts >= {val_start_ts} and end_ts <= {val_end_ts}
group by charge, screen, ground, network_type, signal_level, band, duplex_mode, data_activity;

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
        from agg_modem_app_daily
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
                    'charge', 'screen', 'ground', 'network_type',
                    'signal_level', 'band', 'incall_duration',
                    'rx_bytes', 'tx_bytes', 'sleep_time',
                    'rx_4g_time', 'rx_5g_time', 'tx_4g_time',
                    'tx_5g_time', 'duplex_mode', 'data_activity',
                    'transceiver_eg', 'pa_eg', 'modem_eg', 'energy',
                    'tx_4g_level', 'tx_5g_level'
            )) as column_key,
            json_set('{{}}', '$', json_group_array(
                json_array(timestamp,
                    charge, screen, ground, network_type,
                    signal_level, band, incall_duration,
                    rx_bytes, tx_bytes, sleep_time,
                    rx_4g_time, rx_5g_time, tx_4g_time,
                    tx_5g_time, duplex_mode, data_activity,
                    transceiver_eg, pa_eg, modem_eg, energy
                    , json_array(VectorI('round(lvl$0_duration, 2)', CellularTxLevelDurationList))
                    , json_array(VectorI('round(lvl$0_5g_duration, 2)', CellularTx5gLevelDurationList))
                )
            ))  as row_value
        from agg_modem_state_device_daily
        where start_ts >= {val_start_ts} and end_ts <= {val_end_ts}
    )
);
