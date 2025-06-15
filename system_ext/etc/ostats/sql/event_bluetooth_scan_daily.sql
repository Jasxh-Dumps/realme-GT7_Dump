drop table if exists event_bluetooth_scan_daily;
create table if not exists event_bluetooth_scan_daily as
with deafult_data as (
		select -1 as trig_id, 'unknown' as state, 'unknown' as bt_uid, 'unknown' as device, 'unknown' as type
			, 'unknown' as screen_state, 'unknown' as charge
	),
	flat_ostats_event_args as (
		select row_number() over () as id, trig_id, group_concat(state) as state
			, group_concat(bt_uid) as bt_uid, group_concat(device) as device
			, group_concat(type) as type, group_concat(screen_state) as screen_state
			, group_concat(charge) as charge
		from (
			select *
			from deafult_data
			union all
			select trig_id
				, case
					when flat_key = 'audio_state_changed.state' then string_value
					else null
				end as state
				, case
					when flat_key = 'audio_state_changed.attribution_node.uid' then int_value
					else null
				end as bt_uid
				, case
					when flat_key = 'audio_power_usage_data_reported.audio_device' then string_value
					else null
				end as device
				, case
					when flat_key = 'bluetooth_connection_state_changed.bt_profile' then int_value
					else null
				end as type
				, case
					when flat_key = 'screen_state_changed.state' then string_value
					else null
				end as screen_state
				, case
					when flat_key = 'plugged_state_changed.state' then string_value
					else null
				end as charge
			from ostats_event_args
		)
		group by trig_id
	),
	fill_state as (
		select t.id, t.state
		from flat_ostats_event_args t
		where state is not null
		union all
		select t.id, tt.state
		from fill_state tt
			inner join flat_ostats_event_args t on tt.id + 1 = t.id
		where t.state is null
		order by id
	),
	fill_bt_uid as (
		select t.id, t.bt_uid
		from flat_ostats_event_args t
		where bt_uid is not null
		union all
		select t.id, tt.bt_uid
		from fill_bt_uid tt
			inner join flat_ostats_event_args t on tt.id + 1 = t.id
		where t.bt_uid is null
		order by id
	),
	fill_device as (
		select t.id, t.device
		from flat_ostats_event_args t
		where device is not null
		union all
		select t.id, tt.device
		from fill_device tt
			inner join flat_ostats_event_args t on tt.id + 1 = t.id
		where t.device is null
		order by id
	),
	fill_type as (
		select t.id, t.type
		from flat_ostats_event_args t
		where type is not null
		union all
		select t.id, tt.type
		from fill_type tt
			inner join flat_ostats_event_args t on tt.id + 1 = t.id
		where t.type is null
		order by id
	),
	fill_screen_state as (
		select t.id, t.screen_state
		from flat_ostats_event_args t
		where screen_state is not null
		union all
		select t.id, tt.screen_state
		from fill_screen_state tt
			inner join flat_ostats_event_args t on tt.id + 1 = t.id
		where t.screen_state is null
		order by id
	),
	fill_charge as (
		select t.id, t.charge
		from flat_ostats_event_args t
		where charge is not null
		union all
		select t.id, tt.charge
		from fill_charge tt
			inner join flat_ostats_event_args t on tt.id + 1 = t.id
		where t.charge is null
		order by id
	),
	id_and_trig_id as (
		select id, trig_id
		from flat_ostats_event_args
	),
	full_fill_ostats_event as (
		select trig_id, state, bt_uid, device, type
			, screen_state, charge
		from id_and_trig_id a
			inner join fill_state l on a.id = l.id
			inner join fill_bt_uid k on a.id = k.id
			inner join fill_device b on a.id = b.id
			inner join fill_type d on a.id = d.id
			inner join fill_screen_state i on a.id = i.id
			inner join fill_charge j on a.id = j.id
	),
	result_tab as (
		select b.wtime as start_time
			, lead(wtime, 1, wtime) over (order by id) as end_time
			, a.*
		from full_fill_ostats_event a
			join ostats_events b on a.trig_id = b.id + 1
	),
	a as (
		select *
			, state || ',' || device || ',' || type || ',' || bt_uid || ',' || screen_state || ',' || charge as new
			, row_number() over () as id
		from result_tab
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
	)
select a.start_time, a.end_time, a.type, package_name, a.charge
	, a.screen_state
from (
	select start_time, end_time, type, bt_uid, charge
		, screen_state
	from d
	where device = 'OUTPUT_BLUETOOTH_A2DP'
		and state = 'ON'
	group by group_id
) a
	left join package_list b on a.bt_uid = b.uid
