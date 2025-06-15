attach DATABASE '/data/misc/ostats/database/out.db' as export_db;
CREATE TABLE if not exists export_db.stats(
  name TEXT,
  idx INT,
  severity TEXT,
  source TEXT,
  value INT,
  description TEXT
);
CREATE TABLE if not exists export_db.ostats_event_args(
  id INT,
  type TEXT,
  eid INT,
  field_name TEXT,
  trig_id INT,
  flat_key TEXT,
  int_value INT,
  string_value TEXT,
  real_value REAL
);
CREATE TABLE if not exists export_db.ostats_events(
  id INT,
  type TEXT,
  eid INT,
  event_name TEXT,
  wtime INT,
  btime INT
);

CREATE TABLE if not exists export_db.metric_event_sensor_app_ten_minutes(
    wall_time INT,
    start_time INT,
    end_time INT,
    name TEXT,
    charge INT,
    foreground_duration INT,
    foreground_energy INT,
    background_duration INT,
    background_energy INT,
    screen_on_duration INT,
    screen_on_energy INT,
    screen_off_duration INT,
    screen_off_energy INT
);

CREATE TABLE if not exists export_db.metric_event_vibrator_app_ten_minutes(
    wall_time INT,
    start_time INT,
    end_time INT,
    name TEXT,
    charge INT,
    foreground_duration INT,
    foreground_energy INT,
    background_duration INT,
    background_energy INT,
    screen_on_duration INT,
    screen_on_energy INT,
    screen_off_duration INT,
    screen_off_energy INT
);

CREATE TABLE if not exists export_db.metric_event_Bluetooth_app_ten_minutes(
    wall_time INT,
    start_time INT,
    end_time INT,
    name TEXT,
    charge INT,
    foreground_duration INT,
    foreground_energy INT,
    background_duration INT,
    background_energy INT,
    screen_on_duration INT,
    screen_on_energy INT,
    screen_off_duration INT,
    screen_off_energy INT
);

CREATE TABLE if not exists export_db.metric_event_gnss_app_ten_minutes(
    wall_time INT,
    start_time INT,
    end_time INT,
    name TEXT,
    charge INT,
    foreground_duration INT,
    foreground_energy INT,
    background_duration INT,
    background_energy INT,
    screen_on_duration INT,
    screen_on_energy INT,
    screen_off_duration INT,
    screen_off_energy INT
);

CREATE TABLE if not exists export_db.agg_wakelock_partial_daily(
    wall_time INT,
    start_time INT,
    end_time INT,
    tag TEXT,
    uid INT,
    name TEXT,
    count INT,
    duration INT,
    charge INT,
    screen INT
);

CREATE TABLE if not exists export_db.agg_wakelock_kernel_daily(
    wall_time INT,
    start_time INT,
    end_time INT,
    name TEXT,
    count INT,
    duration INT,
     charge INT,
    screen INT
);

CREATE TABLE if not exists export_db.metric_wakelock_kernel_ten_minutes(
    start_time INT,
    end_time INT,
    screen_state INT,
    charger_state INT,
    name TEXT,
    count INT,
    duration INT
);

CREATE TABLE if not exists export_db.metric_cpu_freq_ten_minutes(
    start_time INT,
    end_time INT,
    screen_state INT,
    charger_state INT,
    cluster INT,
    cpu_hz INT,
    cpu_time INT
);

CREATE TABLE if not exists export_db.metric_cpu_busytime_ten_minutes(
    start_time INT,
    end_time INT,
    screen_state INT,
    charger_state INT,
    uid INT,
    total_time INT
);

CREATE TABLE if not exists export_db.metric_cpu_idle_ten_minutes(
    start_time INT,
    end_time INT,
    screen_state INT,
    charger_state INT,
    cpu INT,
    duration INT
);

CREATE TABLE if not exists export_db.metric_ddr_freq_ten_minutes(
    start_time INT,
    end_time INT,
    screen_state INT,
    charger_state INT,
    frequency INT,
    duration INT
);

CREATE TABLE if not exists export_db.metric_gpu_freq_ten_minutes(
    start_time INT,
    end_time INT,
    screen_state INT,
    charger_state INT,
    frequency INT,
    duration INT
);

CREATE TABLE if not exists export_db.metric_wakelock_partial_ten_minutes(
    start_time INT,
    end_time INT,
    screen_state INT,
    charger_state INT,
    uid INT,
    tag TEXT,
    duration INT
);

CREATE TABLE if not exists export_db.metric_wifi_data_app_ten_minutes(
    start_time INT,
    end_time INT,
    screen_state INT,
    charger_state INT,
    ground_state INT,
    uid INT,
    rx_bytes INT,
    rx_packets INT,
    tx_bytes INT,
    tx_packets INT
);

CREATE TABLE if not exists export_db.metric_ufs_app_ten_minutes(
    start_time INT,
    end_time INT,
    screen_state INT,
    charger_state INT,
    active_du INT,
    sleep_du INT
);

CREATE TABLE if not exists export_db.metric_modem_data_app_ten_minutes(
    start_time INT,
    end_time INT,
    screen_state INT,
    charger_state INT,
    ground_state INT,
    uid INT,
    rx_bytes INT,
    rx_packets INT,
    tx_bytes INT,
    tx_packets INT
);

CREATE TABLE if not exists export_db.metric_cpu_loading_ten_minutes(
    start_time INT,
    end_time INT,
    screen_state INT,
    charger_state INT,
    uid INT,
    cluster INT,
    mcycles INT,
    time INT
);

CREATE TABLE if not exists export_db.metric_modem_data_time_ten_minutes(
    start_time INT,
    end_time INT,
    screen_state INT,
    charger_state INT,
    energy INT,
    sleep_time INT,
    idle_time INT,
    act_time INT,
    tx_time_pl0 INT,
    tx_time_pl1 INT,
    tx_time_pl2 INT,
    tx_time_pl3 INT,
    tx_time_pl4 INT,
    rx_time INT
);

CREATE TABLE if not exists export_db.metric_wifi_data_time_ten_minutes(
    start_time INT,
    end_time INT,
    screen_state INT,
    charger_state INT,
    stack_state INT,
    act_time INT,
    tx_time INT,
    rx_time INT,
    idle_time INT,
    energy INT
);

CREATE TABLE if not exists export_db.event_alert_daily(
    start_time INT,
    end_time INT,
    sub_id INT,
    alert_value INT,
    tag TEXT,
    uid TEXT
);

CREATE TABLE if not exists export_db.clock_snapshot(
  id INT,
  type TEXT,
  ts INT,
  clock_id INT,
  clock_name TEXT,
  clock_value INT,
  snapshot_id INT
);

CREATE TABLE if not exists export_db.package_list(
  id INT,
  package_name TEXT,
  uid INT,
  debuggable INT,
  profileable_from_shell INT,
  version_code INT,
  real_time INT
);

insert into export_db.ostats_events
select id_new + a.id, type, eid, event_name
  , wtime, btime
from ostats_events a, (
    select ifnull(max(id) + 1,0) as id_new
    from export_db.ostats_events
  ) b;

insert into export_db.ostats_event_args
select id_new + a.id, type, eid, field_name
  , trig_id_new + ifnull(a.trig_id,0), flat_key, int_value
  , string_value, real_value
from ostats_event_args a, (
    select ifnull(max(id) + 1,0) as id_new, ifnull(max(trig_id),0) as trig_id_new
    from export_db.ostats_event_args
  ) b;

insert into export_db.stats select * from stats;

insert into export_db.metric_event_gnss_app_ten_minutes select wall_time,start_time,end_time,name,charge,foreground_duration,foreground_energy,background_duration,background_energy,screen_on_duration,screen_on_energy,screen_off_duration,screen_off_energy  from event_gnss_app_ten_minutes;

insert into export_db.metric_event_sensor_app_ten_minutes select wall_time,start_time,end_time,name,charge,foreground_duration,foreground_energy,background_duration,background_energy,screen_on_duration,screen_on_energy,screen_off_duration,screen_off_energy  from event_sensor_app_ten_minutes;

insert into export_db.metric_event_vibrator_app_ten_minutes select wall_time,start_time,end_time,name,charge,foreground_duration,foreground_energy,background_duration,background_energy,screen_on_duration,screen_on_energy,screen_off_duration,screen_off_energy  from event_vibrator_app_ten_minutes;

insert into export_db.metric_event_Bluetooth_app_ten_minutes select wall_time,start_time,end_time,name,charge,foreground_duration,foreground_energy,background_duration,background_energy,screen_on_duration,screen_on_energy,screen_off_duration,screen_off_energy  from event_Bluetooth_app_ten_minutes;

insert into export_db.agg_wakelock_kernel_daily select wall_time,start_time,end_time,name,count,duration,charge,screen from agg_wakelock_kernel_daily;

insert into export_db.agg_wakelock_partial_daily select wall_time,start_time,end_time,tag,uid,name,count,duration,charge,screen from agg_wakelock_partial_daily;

insert into export_db.metric_wakelock_kernel_ten_minutes select start_time,end_time,screen_state,charger_state,name,count,duration from event_wakelock_kernel_daily;

insert into export_db.metric_cpu_freq_ten_minutes select start_time,end_time,screen_state,charger_state,cluster,cpu_hz,cpu_time from event_cpu_freq_daily;

insert into export_db.metric_cpu_busytime_ten_minutes select start_time,end_time,screen_state,charger_state,uid,total_time from event_cpu_busytime_daily;

insert into export_db.metric_cpu_idle_ten_minutes select start_time,end_time,screen_state,charger_state,cpu,duration from metric_cpu_idle_ten_minutes;

insert into export_db.metric_ddr_freq_ten_minutes select start_time,end_time,screen_state,charger_state,frequency,duration from event_ddr_freq_daily;

insert into export_db.metric_gpu_freq_ten_minutes select start_time,end_time,screen_state,charger_state,frequency,duration from event_gpu_freq_daily;

insert into export_db.metric_wakelock_partial_ten_minutes select start_time,end_time,screen_state,charger_state,uid,tag,duration from event_wakelock_partial_daily;

insert into export_db.metric_wifi_data_app_ten_minutes select start_time,end_time,screen_state,charger_state,ground_state,uid,rx_bytes,rx_packets,tx_bytes,tx_packets from event_wifi_data_app_daily;

insert into export_db.metric_ufs_app_ten_minutes select start_time,end_time,screen_state,charger_state,active_du,sleep_du from event_ufs_app_daily;

insert into export_db.metric_modem_data_app_ten_minutes select start_time,end_time,screen_state,charger_state,ground_state,uid,rx_bytes,rx_packets,tx_bytes,tx_packets from event_modem_data_app_daily;

insert into export_db.metric_cpu_loading_ten_minutes select start_time,end_time,screen_state,charger_state,uid,cluster,mcycles,time from metric_cpu_loading_ten_minutes;

insert into export_db.metric_wifi_data_time_ten_minutes select start_time,end_time,screen_state,charger_state,stack_state,act_time,tx_time,rx_time,idle_time,energy from metric_wifi_data_time_ten_minutes;

insert into export_db.metric_modem_data_time_ten_minutes select start_time,end_time,screen_state,charger_state,energy,sleep_time,idle_time,act_time,tx_time_pl0,tx_time_pl1,tx_time_pl2,tx_time_pl3,tx_time_pl4,rx_time from metric_modem_data_time_ten_minutes;



insert into export_db.event_alert_daily select start_time,end_time,sub_id,alert_value,tag,uid from event_alert_daily;

insert into export_db.clock_snapshot
select id_new + a.id, type,ts,clock_id,clock_name,clock_value,snapshot_id
from clock_snapshot a, (
    select ifnull(max(id) + 1,0) as id_new
    from export_db.clock_snapshot
  ) b;

insert into export_db.package_list
select id_new + a.id,package_name,uid,debuggable,profileable_from_shell,version_code,real_time
from package_list a, (
    select ifnull(max(id) + 1,0) as id_new
    from export_db.package_list
  ) b;

DETACH DATABASE export_db;
