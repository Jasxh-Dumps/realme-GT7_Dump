-- val_start_ts,      --obrain_start_ts
-- val_end_ts,        --obrain_end_ts
-- val_wall_start_ts  --wall_start_ts_round

insert into agg_wifi_app_hourly
SELECT {val_start_ts} as 'start_ts', {val_end_ts} as 'end_ts', {val_wall_start_ts} as 'timestamp'
    , package_name as 'name'
    , sum(case when ground_mode = 1 then tx_time + rx_time + idle_time else 0 end) as 'foreground_duration'
    , sum(case when ground_mode = 1 then tx_byte else 0 end) as 'foreground_tx_bytes'
    , sum(case when ground_mode = 1 then rx_byte else 0 end) as 'foreground_rx_bytes'
    , sum(case when ground_mode = 1 then total_eg else 0 end) as 'foreground_energy'
    , sum(case when ground_mode = 0 then tx_time + rx_time + idle_time else 0 end) as 'background_duration'
    , sum(case when ground_mode = 0 then tx_byte else 0 end) as 'background_tx_bytes'
    , sum(case when ground_mode = 0 then rx_byte else 0 end) as 'background_rx_bytes'
    , sum(case when ground_mode = 0 then total_eg else 0 end) as 'background_energy'
    , sum(case when screen_mode = 1 then tx_time + rx_time + idle_time else 0 end) as 'screen_on_duration'
    , sum(case when screen_mode = 1 then tx_byte else 0 end) as 'screen_on_tx_bytes'
    , sum(case when screen_mode = 1 then rx_byte else 0 end) as 'screen_on_rx_bytes'
    , sum(case when screen_mode = 1 then total_eg else 0 end) as 'screen_on_energy'
    , sum(case when screen_mode = 0 then tx_time + rx_time + idle_time else 0 end) as 'screen_off_duration'
    , sum(case when screen_mode = 0 then tx_byte else 0 end) as 'screen_off_tx_bytes'
    , sum(case when screen_mode = 0 then rx_byte else 0 end) as 'screen_off_rx_bytes'
    , sum(case when screen_mode = 0 then total_eg else 0 end) as 'screen_off_energy'
from comp_wifi_agent_intv
where start_ts >= {val_start_ts} and end_ts <= {val_end_ts}
group by package_name;

insert into agg_wifi_state_device_hourly
SELECT {val_start_ts} as 'start_ts', {val_end_ts} as 'end_ts', {val_wall_start_ts} as 'timestamp'
    , power_mode as 'charge', screen_mode as 'screen', ground_mode as 'ground', enable as 'enable'
    , sum(tx_byte) as 'tx_bytes', sum(rx_byte) as 'rx_bytes', sum(tx_packet) as 'tx_packet', sum(rx_packet) as 'rx_packet'
    , sum(tx_time) as 'tx_time', sum(rx_time) as 'rx_time', sum(idle_time) as 'idle_time'
    , hotspot as 'hotspot', frequency_band as 'band', band_width as 'band_width', standard as 'standard', antenna as 'antenna'
    , avg(rssi) as 'rssi', sum(total_eg) as 'energy'
from comp_wifi_agent_intv
where start_ts >= {val_start_ts} and end_ts <= {val_end_ts}
    and screen_mode != -1
    and power_mode != -1
    and ground_mode != -1
group by power_mode, screen_mode, ground_mode, enable, hotspot, frequency_band, standard, band_width, antenna;
