-- val_start_ts,      --obrain_start_ts
-- val_end_ts,        --obrain_end_ts
-- val_wall_start_ts  --wall_start_ts_round

insert into agg_gpu_app_hourly
SELECT {val_start_ts} as 'start_ts', {val_end_ts} as 'end_ts', {val_wall_start_ts} as 'timestamp',
    app as 'name',
    sum(busy_time) as 'duration',
    avg(fmax_utilize_rate) as 'usage',
    sum(whole_eg) as 'energy'
from comp_gpuPower_gpuAgent_intv
where start_ts >= {val_start_ts} and end_ts <= {val_end_ts}
group by app;
