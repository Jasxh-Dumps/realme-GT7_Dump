-- val_start_ts,      --obrain_start_ts
-- val_end_ts,        --obrain_end_ts
-- val_wall_start_ts  --wall_start_ts_round

insert into agg_modem_app_hourly
SELECT {val_start_ts} as 'start_ts', {val_end_ts} as 'end_ts', {val_wall_start_ts} as 'timestamp', name
    , sum(case when ground_mode = 1 then rx_time + rx_5g_time + SumVectorI('lvl$0_duration', CellularTxLevelDurationList) + SumVectorI('lvl$0_5g_duration', CellularTx5gLevelDurationList) else 0 end) as 'foreground_duration'
    , sum(case when ground_mode = 1 then tx_trans_byte else 0 end) as 'foreground_tx_bytes'
    , sum(case when ground_mode = 1 then rx_trans_byte else 0 end) as 'foreground_rx_bytes'
    , sum(case when ground_mode = 1 then total_eg else 0 end) as 'foreground_energy'
    , sum(case when ground_mode = 0 then rx_time + rx_5g_time + SumVectorI('lvl$0_duration', CellularTxLevelDurationList) + SumVectorI('lvl$0_5g_duration', CellularTx5gLevelDurationList) else 0 end) as 'background_duration'
    , sum(case when ground_mode = 0 then tx_trans_byte else 0 end) as 'background_tx_bytes'
    , sum(case when ground_mode = 0 then rx_trans_byte else 0 end) as 'background_rx_bytes'
    , sum(case when ground_mode = 0 then total_eg else 0 end) as 'background_energy'
    , sum(case when screen_mode = 1 then rx_time + rx_5g_time + SumVectorI('lvl$0_duration', CellularTxLevelDurationList) + SumVectorI('lvl$0_5g_duration', CellularTx5gLevelDurationList) else 0 end) as 'screen_on_duration'
    , sum(case when screen_mode = 1 then tx_trans_byte else 0 end) as 'screen_on_tx_bytes'
    , sum(case when screen_mode = 1 then rx_trans_byte else 0 end) as 'screen_on_rx_bytes'
    , sum(case when screen_mode = 1 then total_eg else 0 end) as 'screen_on_energy'
    , sum(case when screen_mode = 0 then rx_time + rx_5g_time + SumVectorI('lvl$0_duration', CellularTxLevelDurationList) + SumVectorI('lvl$0_5g_duration', CellularTx5gLevelDurationList) else 0 end) as 'screen_off_duration'
    , sum(case when screen_mode = 0 then tx_trans_byte else 0 end) as 'screen_off_tx_bytes'
    , sum(case when screen_mode = 0 then rx_trans_byte else 0 end) as 'screen_off_rx_bytes'
    , sum(case when screen_mode = 0 then total_eg else 0 end) as 'screen_off_energy'
from comp_cellularUidState_backward
where start_ts >= {val_start_ts} and end_ts <= {val_end_ts}
group by name;

insert into agg_modem_state_device_hourly
SELECT {val_start_ts} as 'start_ts', {val_end_ts} as 'end_ts', {val_wall_start_ts} as 'timestamp'
    , power_mode as 'charge', screen_mode as 'screen', ground_mode as 'ground'
    , networkType as 'network_type ', signalLevel as 'signal_level', bands as 'band'
    , sum(incall_du) as 'incall_duration', sum(rx_trans_byte) as 'rx_bytes'
    , sum(tx_trans_byte) as tx_bytes, round(sum(sleep_time), 2) as 'sleep_time'
    , round(sum(rx_time), 2) as 'rx_4g_time', round(sum(rx_5g_time), 2) as 'rx_5g_time'
    , round(SumVectorI('sum(lvl$0_duration)', CellularTxLevelDurationList), 2) as 'tx_4g_time'
    , round(SumVectorI('sum(lvl$0_5g_duration)', CellularTx5gLevelDurationList), 2) as 'tx_5g_time'
    , duplexMode as 'duplex_mode', dataActivity as 'data_activity'
    , sum(transceiver_eg) as 'transceiver_eg', sum(pa_eg) as 'pa_eg'
    , sum(modem_eg) as 'modem_eg', sum(total_eg) as energy
    , VectorI('sum(lvl$0_duration) as lvl$0_duration', CellularTxLevelDurationList)
    , VectorI('sum(lvl$0_5g_duration) as lvl$0_5g_duration', CellularTx5gLevelDurationList)
from comp_cellularUidState_backward
where start_ts >= {val_start_ts} and end_ts <= {val_end_ts}
    and screen_mode != -1
    and power_mode != -1
    and ground_mode != -1
group by power_mode, screen_mode, ground_mode, networkType, signalLevel, bands, duplexMode, dataActivity;
