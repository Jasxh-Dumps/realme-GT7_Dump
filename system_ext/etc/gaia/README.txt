1. 对日志内容、数量和日志工具的使用有疑问，可以通过HIO链接(https://hio.oppo.com/app/rok/362521)阅读《日志工具Q&A》，其中主要包括如下内容：
    a. 日志工具使用相关的问题；
    b. 日志打印限制；
    c. 日志不足问题处理原则；
    d. 日志上传失败的说明；
    e. 日志常开；
    f. 历史日志删除策略；
    g. EAP公共流水日志；
    h. 其他常见问题的介绍和处理方式说明。

2. 日志文件夹子项介绍
    所有日志文件夹都会包括以下3个子项：
    a. common目录下包括了android_log、events_log、kernel_log、radio_log等最常用的日志，放在aplog或minilog目录下。
       dump产生的日志放在SI_stop目录中。还有稳定性问题常用的anr、tombstones等。
    b. LogTool_Log 中是日志工具的日志。
    c. dev_info.txt 是设备信息、系统版本等。
    其他子目录则是根据各业务的配置及用户抓取时的选择生成的。详细介绍见下方HIO链接：
    https://hio.oppo.com/app/rk/578907