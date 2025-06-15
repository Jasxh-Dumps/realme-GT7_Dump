-- val_start_ts,      --obrain_start_ts
-- val_end_ts,        --obrain_end_ts
-- val_wall_start_ts  --wall_start_ts_round

insert into agg_audio_app_hourly
SELECT {val_start_ts} as 'start_ts', {val_end_ts} as 'end_ts', {val_wall_start_ts} as 'timestamp',
       player_app as 'name',
       sum(case when ground_mode = 1 then duration else 0 end) as 'foreground_duration',
       sum(case when ground_mode = 1 then whole_eg else 0 end) as 'foreground_energy',
       sum(case when ground_mode = 0 then duration else 0 end) as 'background_duration',
       sum(case when ground_mode = 0 then whole_eg else 0 end) as 'background_energy',
       sum(case when screen_mode = 1 then duration else 0 end) as 'screen_on_duration',
       sum(case when screen_mode = 1 then whole_eg else 0 end) as 'screen_on_energy',
       sum(case when screen_mode = 0 then duration else 0 end) as 'screen_off_duration',
       sum(case when screen_mode = 0 then whole_eg else 0 end) as 'screen_off_energy'
from comp_audioPower_audioAgent_intv
where start_ts >= {val_start_ts} and end_ts <= {val_end_ts}
group by player_app;

insert into agg_audio_volume_app_hourly
SELECT {val_start_ts} as 'start_ts', {val_end_ts} as 'end_ts', {val_wall_start_ts} as 'timestamp',
       screen_mode as 'screen_mode',
       power_mode as 'charger_mode',
       app as 'name',
       channel as 'device',
       volume as 'volume',
       sum(duration) as 'total_du'
from comp_audioPower_audioAgent_intv
where start_ts >= {val_start_ts} and end_ts <= {val_end_ts}
group by screen_mode, power_mode, app, channel, volume;