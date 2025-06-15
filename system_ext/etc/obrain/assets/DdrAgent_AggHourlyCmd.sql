INSERT INTO agg_ddr_app_hourly
SELECT 	{val_start_ts} AS start_ts,
        {val_end_ts} AS end_ts,
        {val_wall_start_ts} AS timestamp,
        app AS name,
        SUM(case when screen_mode = 1 then value else 0 end) AS screen_on_energy,
        SUM(case when screen_mode = 0 then value else 0 end) AS screen_off_energy
FROM comp_ddrAgent_whole_energy, json_each(json_extract(app_eg, '$'))
WHERE start_ts >= {val_start_ts} and end_ts <= {val_end_ts}
group by app;
