-- val_start_ts,      --obrain_start_ts
-- val_end_ts,        --obrain_end_ts
-- val_wall_start_ts  --wall_start_ts_round

insert into agg_camera_app_hourly
SELECT {val_start_ts} as 'start_ts', {val_end_ts} as 'end_ts', {val_wall_start_ts} as 'timestamp',
	camera_id as 'camera_id', camera_app as 'name',
	sum(case when ground_mode = 1 then duration else 0 end) as 'foreground_duration',
	sum(case when ground_mode = 1 then camera_eg + motor_eg + laser_eg + osi_eg else 0 end) as 'foreground_energy',
	sum(case when ground_mode = 0 then duration else 0 end) as 'background_duration',
	sum(case when ground_mode = 0 then camera_eg + motor_eg + laser_eg + osi_eg else 0 end) as 'background_energy',
	sum(case when screen_mode = 1 then duration else 0 end) as 'screen_on_duration',
	sum(case when screen_mode = 1 then camera_eg + motor_eg + laser_eg + osi_eg else 0 end) as 'screen_on_energy',
	sum(case when screen_mode = 0 then duration else 0 end) as 'screen_off_duration',
	sum(case when screen_mode = 0 then camera_eg + motor_eg + laser_eg + osi_eg else 0 end) as 'screen_off_energy'
from comp_cameraAgent_appPower_intv
where start_ts >= {val_start_ts} and end_ts <= {val_end_ts}
group by camera_id, camera_app;
