-- val_start_ts,      --obrain_start_ts
-- val_end_ts,        --obrain_end_ts
-- val_wall_start_ts  --wall_start_ts_round

insert into agg_battery_device_hourly
select
    {val_start_ts} as 'start_ts',
    {val_end_ts} as 'end_ts',
    {val_wall_start_ts} as 'timestamp',
    case when screen_id = 2 then 1 else 0 end as screen_id,
    sum(case when power_mode = 0 and screen_mode = 1 then time_delta else 0 end) as discharge_screen_on_duration,
    sum(case when power_mode = 0 and screen_mode = 1 then (-rm_delta) else 0 end) as discharge_screen_on_fuel_gauge,
    sum(case when power_mode = 0 and screen_mode = 1 then (-battery_level_delta) else 0 end) as discharge_screen_on_level,
    sum(case when power_mode = 0 and screen_mode = 0 then time_delta else 0 end) as discharge_screen_off_duration,
    sum(case when power_mode = 0 and screen_mode = 0 then (-rm_delta) else 0 end) as discharge_screen_off_fuel_gauge,
    sum(case when power_mode = 0 and screen_mode = 0 then (-battery_level_delta) else 0 end) as discharge_screen_off_level,
    sum(case when power_mode = 1 and screen_mode = 1 then time_delta else 0 end) as charge_screen_on_duration,
    sum(case when power_mode = 1 and screen_mode = 1 then whole_eg else 0 end) as charge_screen_on_fuel_gauge,
    sum(case when power_mode = 1 and screen_mode = 1 then battery_level_delta else 0 end) as charge_screen_on_level,
    sum(case when power_mode = 1 and screen_mode = 0 then time_delta else 0 end) as charge_screen_off_duration,
    sum(case when power_mode = 1 and screen_mode = 0 then whole_eg else 0 end) as charge_screen_off_fuel_gauge,
    sum(case when power_mode = 1 and screen_mode = 0 then battery_level_delta else 0 end) as charge_screen_off_level
from comp_batteryAgent_appPower_intv
where (start_ts >= {val_start_ts} and end_ts <= {val_end_ts})
group by screen_id;

insert into agg_battery_app_hourly
select
    {val_start_ts} as 'start_ts',
    {val_end_ts} as 'end_ts',
    {val_wall_start_ts} as 'timestamp',
    app as name,
    screen_mode as screen_mode,
    power_mode as power_mode,
    case when screen_id = 2 then 1 else 0 end as screen_id,
    sum(time_delta) as foreground_duration,
    sum(case when power_mode = 1 then whole_eg else abs(rm_delta) end) as foreground_energy
from comp_batteryAgent_appPower_intv
where (start_ts >= {val_start_ts} and end_ts <= {val_end_ts})
and power_mode != -1
and screen_mode != -1
group by app, screen_mode, power_mode, screen_id;

WITH
washed AS (
    SELECT start_ts, end_ts, time_delta, whole_eg, rm_delta, power_mode,
           CASE WHEN screen_mode = 0 THEN 0 ELSE 1 END as screen_mode
    FROM comp_batteryAgent_appPower_intv
    where (start_ts >= {val_start_ts} and end_ts <= {val_end_ts})
),
a as (
  select *, screen_mode as new, row_number() over () as id
  from washed
),
b as (
  select *, lag(new) over (order by id) as lag_new
  from a
),
c as (
  select *
    , case
      when new = lag_new then 0
      else 1
    end as is_first
  from b
),
d as (
  select *, sum(is_first) over (order by id) as group_id
  from c
  order by id
),
grp as (
	select min(start_ts) as start_ts, max(end_ts) as end_ts, sum(time_delta) as time_delta, sum(abs(rm_delta)) as energy, group_id from d where screen_mode = 0 and power_mode = 0
	group by group_id
),
cnt as (
select sum(case when time_delta <= 300000 then 1 else 0 end) as cnt_5min,
	sum(case when (time_delta > 300000 and time_delta <= 1800000) then 1 else 0 end) as cnt_30min,
	sum(case when (time_delta > 1800000 and time_delta <= 3600000) then 1 else 0 end) as cnt_60min,
	sum(case when (time_delta > 3600000 and time_delta <= 7200000) then 1 else 0 end) as cnt_120min,
	sum(case when (time_delta > 3600000 and time_delta <= 7200000) then energy else 0 end) as energy_120min,
	sum(case when (time_delta > 3600000 and time_delta <= 7200000) then time_delta else 0 end) as duration_120min,
	sum(case when (time_delta > 7200000 and time_delta <= 18000000) then 1 else 0 end) as cnt_300min,
	sum(case when (time_delta > 7200000 and time_delta <= 18000000) then energy else 0 end) as energy_300min,
	sum(case when (time_delta > 7200000 and time_delta <= 18000000) then time_delta else 0 end) as duration_300min
from grp
)
insert into agg_battery_sleep_hourly
select
    {val_start_ts} as 'start_ts',
    {val_end_ts} as 'end_ts',
    {val_wall_start_ts} as 'timestamp',
    cnt_5min, cnt_30min, cnt_60min, cnt_120min, energy_120min, duration_120min, cnt_300min, energy_300min, duration_300min
from cnt;