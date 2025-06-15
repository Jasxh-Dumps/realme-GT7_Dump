-- val_start_ts,      --obrain_start_ts
-- val_end_ts,        --obrain_end_ts
-- val_wall_start_ts  --wall_start_ts_round

insert into agg_camera_app_daily
SELECT {val_start_ts} as 'start_ts', {val_end_ts} as 'end_ts', {val_wall_start_ts} as 'timestamp',
      camera_id as 'camera_id', name as 'name', sum(foreground_duration) as 'foreground_duration', sum(foreground_energy) as 'foreground_energy',
      sum(background_duration) as 'background_duration', sum(background_energy) as 'background_energy',
      sum(screen_on_duration) as 'screen_on_duration', sum(screen_on_energy) as 'screen_on_energy',
      sum(screen_off_duration) as 'screen_off_duration', sum(screen_off_energy) as 'screen_off_energy'
from agg_camera_app_hourly
where start_ts >= {val_start_ts} and end_ts <= {val_end_ts}
group by camera_id, name;

insert into agg_camera_device_daily
SELECT {val_start_ts} as 'start_ts', {val_end_ts} as 'end_ts', {val_wall_start_ts} as 'timestamp', camera_id as 'camera_id',
      sum(foreground_duration) as 'foreground_duration', sum(foreground_energy) as 'foreground_energy',
      sum(background_duration) as 'background_duration', sum(background_energy) as 'background_energy',
      sum(screen_on_duration) as 'screen_on_duration', sum(screen_on_energy) as 'screen_on_energy',
      sum(screen_off_duration) as 'screen_off_duration', sum(screen_off_energy) as 'screen_off_energy'
from agg_camera_app_daily
where start_ts >= {val_start_ts} and end_ts <= {val_end_ts}
group by camera_id;

--by_app  upload dcs-------------------------------------------------------------------------
select upload_dcs('{upload_dcs_key}', '{log_tag_app}', '{config_id_app}', {version}, '{type}', {agent_type},
				  '{id}', '{start_wall_time}', '{end_wall_time}', '{meta_data}', by_app)
from (
	select json_insert(json_set('{{}}', '$.column_key', json(column_key)), '$.row_value', json(row_value)) as 'by_app'
	from (
		select
			json_set('{{}}', '$', json_array('timestamp', 'camera_id', 'name', 'foreground_duration',
				'foreground_energy', 'background_duration', 'background_energy', 'screen_on_duration',
				'screen_on_energy', 'screen_off_duration', 'screen_off_energy')) as column_key,
			json_set('{{}}', '$', json_group_array(json_array(timestamp, camera_id, obfuscate(name),
				foreground_duration,foreground_energy,background_duration, background_energy,
				screen_on_duration,screen_on_energy, screen_off_duration, screen_off_energy)))  as row_value
		from agg_camera_app_daily
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
			json_set('{{}}', '$', json_array('timestamp',  'camera_id', 'foreground_duration',
				'foreground_energy', 'background_duration', 'background_energy', 'screen_on_duration',
				'screen_on_energy', 'screen_off_duration', 'screen_off_energy')) as column_key,
			json_set('{{}}', '$', json_group_array(json_array(timestamp, camera_id,
				foreground_duration,foreground_energy,background_duration, background_energy,
				screen_on_duration,screen_on_energy, screen_off_duration, screen_off_energy)))  as row_value
		from  agg_camera_device_daily
		where start_ts >= {val_start_ts} and end_ts <= {val_end_ts}
	)
);
