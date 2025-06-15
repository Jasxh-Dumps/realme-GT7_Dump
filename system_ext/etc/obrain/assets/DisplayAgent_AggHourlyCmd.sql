-- val_start_ts,      -- obrain_start_ts
-- val_end_ts,        -- obrain_end_ts
-- val_wall_start_ts  -- wall_start_ts_round

with
APP as (
    select
        case
            when screen_mode <> 0 then app else 'screen_off' end as name,
        screen_id,
        sum(time_delta) as duration,
        sum(whole_eg) as energy,
        case
            when app = 'doze' then 1
            when app like 'com.oplus.aod%' then 2
            when parallel_mode = 1 then 10
            when split_mode = 1 then 11
            when screen_id = 1 and screen_mode <> 0 then 12
            else 0 end as mode
    from comp_displayAgent_appPower_intv
    where (start_ts >= {val_start_ts} and end_ts <= {val_end_ts})
    group by name, mode, screen_id
)
insert into agg_display_app_hourly
select
    {val_start_ts} as 'start_ts',
    {val_end_ts} as 'end_ts',
    {val_wall_start_ts} as 'timestamp',
    screen_id,
    name,
    duration,
    energy,
    mode
from APP;

with
BRIGHTNESS_FPS as (
    select
        screen_mode, power_mode, app as name, brightness, FPS as fps, renderFps as render_fps,
        sum(time_delta) as total_du
        from comp_displayAgent_appPower_intv
    where (start_ts >= {val_start_ts} and end_ts <= {val_end_ts})
    group by screen_mode, power_mode, name, brightness, FPS, renderFps
)
insert into agg_screen_brightness_fps_app_hourly
select
    {val_start_ts} as 'start_ts',
    {val_end_ts} as 'end_ts',
    {val_wall_start_ts} as 'timestamp',
    screen_mode, power_mode, name, brightness, fps, render_fps, total_du
from BRIGHTNESS_FPS;
