// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get language => '语言';

  @override
  String get languageSystem => '跟随系统';

  @override
  String get languageSystemDescription => '其他系统语言使用 English。';

  @override
  String get languageChinese => '简体中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSaveFailed => '未能保存语言设置。当前语言未更改，请重试。';

  @override
  String get ledgerOpenFailed => '无法打开本地台账';

  @override
  String get ledgerOpenHelp => '原有数据仍保留。请检查设备存储空间和文件权限；如果曾使用较新版本，请用相同或更新版本重试。';

  @override
  String get retryOpen => '重试打开';

  @override
  String get ledgerDoNotErase => '请勿清除应用数据或卸载重装来尝试修复。';

  @override
  String get servers => '服务器';

  @override
  String get costs => '费用';

  @override
  String get tools => '工具';

  @override
  String get settings => '设置';

  @override
  String get remainingValueCalculator => '剩余价值计算器';

  @override
  String get calculatorDescription => '独立试算或引用服务器资料 · 可导出图片';

  @override
  String get sshQuickConnect => 'SSH 快速连接';

  @override
  String get tcpConnectionTest => 'TCP 连接测试';

  @override
  String get commandSnippets => '命令片段';

  @override
  String get powerControl => '电源控制';

  @override
  String get powerControlWarning => '关机后无法通过 SSH 开机，需使用厂商面板。重启或关机不会停止厂商计费。';

  @override
  String get uiTabsCalculatorTile => '独立试算或引用服务器，可导出不含隐私的图片';

  @override
  String get uiTabsSshTile => '选择已配置的服务器';

  @override
  String get uiTabsTcpTile => '单目标端口探测';

  @override
  String get uiTabsSnippetsTile => '常用命令，插入草稿后发送';

  @override
  String get uiTabsPowerTile => '经 SSH 重启或关机';

  @override
  String get uiTabsLedgerSection => '台账';

  @override
  String get uiTabsSecuritySection => '安全';

  @override
  String get uiTabsPreferencesSection => '偏好';

  @override
  String get uiTabsDataSection => '数据';

  @override
  String get uiTabsNotifyAllowed => '已允许';

  @override
  String get uiTabsNotifyDenied => '未允许';

  @override
  String get uiTabsNotifyUnsupported => '不支持';

  @override
  String get uiTabsNotifyUnchecked => '未检查';

  @override
  String get uiTabsNotifyChecking => '检查中';

  @override
  String get uiTabsNotifyFailed => '检查失败';

  @override
  String get usageContinue => '继续使用';

  @override
  String get usageUndecided => '待决定';

  @override
  String get usageStop => '到期不再使用';

  @override
  String get reminderNoDays => '未选择提醒日期';

  @override
  String get reminderOnDueDate => '到期当天';

  @override
  String reminderDaysBefore(int p0) {
    return '提前 $p0 天';
  }

  @override
  String get notificationStatus => '通知权限与提醒状态';

  @override
  String reminderLastTimezone(String p0) {
    return '最近安排提醒时使用的时区：$p0';
  }

  @override
  String get requestingPermission => '正在申请…';

  @override
  String get requestNotificationPermission => '申请系统通知权限';

  @override
  String get checkReminderStatus => '重新核对提醒状态';

  @override
  String get reminderCoverage => '提醒范围';

  @override
  String get r2TabsMetricScheduled => '已安排';

  @override
  String get r2TabsMetricNotCovered => '未覆盖';

  @override
  String get r2TabsMetricNoReminder => '未提醒';

  @override
  String get r2TabsUpcoming => '即将提醒';

  @override
  String r2TabsShowAll(String n) {
    return '显示全部（$n）';
  }

  @override
  String get r2TabsToday => '今天';

  @override
  String get r2TabsTomorrow => '明天';

  @override
  String get r2TabsWithinWeek => '7 天内';

  @override
  String r2TabsMonth(String year, String month) {
    return '$year 年 $month 月';
  }

  @override
  String r2TabsRowSub(String lead, String due) {
    return '$lead · 到期 $due';
  }

  @override
  String get r2TabsNotCoveredPill => '未覆盖';

  @override
  String get r2TabsCoverageNote => '系统对待发送的提醒数量有上限，超过上限或 366 天以后的提醒不会安排。';

  @override
  String get r2TabsNoReminderServers => '未提醒的服务器';

  @override
  String get r2TabsReasonArchived => '已归档';

  @override
  String get r2TabsReasonDemo => '演示数据';

  @override
  String get r2TabsReasonNoDate => '未填到期日';

  @override
  String get r2TabsReasonNotPrepaid => '非预付费';

  @override
  String get r2TabsReasonOff => '提醒已关闭';

  @override
  String get r2TabsReasonNoUpcoming => '暂无待发提醒';

  @override
  String get r2TabsAllReminders => '全部提醒';

  @override
  String get r2TabsFilterAll => '全部';

  @override
  String get r2TabsSearchHint => '搜索服务器名称';

  @override
  String get r2TabsEmpty => '没有符合条件的项目';

  @override
  String get r2TabsNoUpcoming => '暂无即将提醒';

  @override
  String get r2TabsEnableHelp => '需同时开启系统通知和各服务器的提醒。';

  @override
  String get r2TabsPermissionHelp => '已拒绝时，请到系统设置中开启通知。';

  @override
  String r2TabsNotifyScheduled(String n) {
    return '已安排 $n 条';
  }

  @override
  String get reminderHorizonHelp =>
      '只提交未来 366 天内已知的到期提醒；过去的提醒时间不补发。系统限制可同时排队的提醒数量（iOS 最多 64 条），其余显示为未安排。请定期打开应用更新提醒。';

  @override
  String get reminderDeliveryHelp =>
      '应用回到前台会重新读取权限和设备时区。旅行后请打开应用核对；未打开时已提交的提醒可能仍按旧时区投递。系统节电、专注模式及厂商限制可能延迟或阻止提醒，已安排不代表已经送达。';

  @override
  String get reminderPrivacyHelp =>
      '提醒内容只包含到期日期和核对提示，不包含服务器名称、地址、账户或金额。不自动付款、不修改厂商续费设置。';

  @override
  String get reminderRulesSaved => '提醒规则已保存。请在“设置 / 通知权限”查看系统提醒状态。';

  @override
  String get localExpiryReminders => '本机到期提醒';

  @override
  String get back => '返回';

  @override
  String get recordMissingReload => '记录不存在，请返回重新读取。';

  @override
  String get dueDateNotEntered => '未填写到期日';

  @override
  String uiTabsReminderDue(String name, String date) {
    return '$name 将于 $date 到期。';
  }

  @override
  String uiTabsReminderPreview(String dates, String time) {
    return '将在 $dates $time 提醒（设备时区）。通知不包含名称、IP 或金额。';
  }

  @override
  String get uiTabsReminderPreviewNone => '按当前设置没有未来的提醒时间。通知不包含名称、IP 或金额。';

  @override
  String get uiTabsUsageContinueHint => '到期前提醒续费';

  @override
  String get uiTabsUsageUndecidedHint => '提醒你做出决定';

  @override
  String get uiTabsUsageStopHint => '仍提醒核对并取消自动续费';

  @override
  String get demoNoNotifications => '演示数据不会提交真实系统通知。';

  @override
  String get archivedNoReminders => '已归档记录不会排程提醒。';

  @override
  String get enableServerReminders => '启用此服务器的提醒';

  @override
  String get reminderOnlyHelp => '仅提醒，不自动续费或取消服务';

  @override
  String get daysBefore => '提前几天';

  @override
  String get sameDay => '当天';

  @override
  String dayCount(int p0) {
    return '$p0 天';
  }

  @override
  String get reminderTime => '提醒时间';

  @override
  String get cancel => '取消';

  @override
  String get confirm => '确定';

  @override
  String get hour => '时';

  @override
  String get minute => '分';

  @override
  String get reminderDstHelp => '按设备当前时区；夏令时缺失的时间顺延，重复的只提醒一次。';

  @override
  String get myUsagePlan => '我的使用计划';

  @override
  String get usagePlanWarning => '使用计划仅为本地记录，不会停止厂商扣费；请另行向厂商取消续费。';

  @override
  String get savedRuleSchedule => '已保存规则的提醒安排';

  @override
  String serverScheduledCount(String p0) {
    return '本服务器已安排 $p0 条';
  }

  @override
  String get viewReminderCoverage => '查看通知权限与覆盖范围';

  @override
  String get saving => '正在保存…';

  @override
  String get expiryNotificationTitle => 'VPS 到期核对';

  @override
  String notificationDueDate(String p0) {
    return '到期日为 $p0';
  }

  @override
  String notificationStopBody(String p0) {
    return '有服务$p0，请核对厂商是否已取消续费。本地计划不会停止扣费。';
  }

  @override
  String notificationContinueBody(String p0) {
    return '有服务$p0，请核对厂商账单与使用计划。本提醒不会自动付款。';
  }

  @override
  String get expiryChecks => '到期核对';

  @override
  String get expiryChannelDescription => '本地到期提醒，不自动续费或付款';

  @override
  String get reminderNotChecked => '尚未检查系统通知';

  @override
  String get reminderChecking => '正在核对系统提醒…';

  @override
  String reminderScheduleCounts(String p0, String p1) {
    return '已安排 $p0 条提醒 · 未安排 $p1 条';
  }

  @override
  String get reminderPermissionDenied => '系统通知未获允许或通知渠道已关闭；已保存规则仍保留';

  @override
  String get reminderUnsupported => '此平台不支持定时通知；已保存规则不会在此设备触发提醒';

  @override
  String get reminderCheckFailed => '提醒状态核对失败，可能仍有旧提醒；请重试或检查系统设置';

  @override
  String get jsonLedgerBackup => 'JSON 台账备份';

  @override
  String get backupTooLarge => '备份超过 10 MiB 上限';

  @override
  String get backupExportInvalid => '导出校验失败，未保存或分享备份。台账未改动。';

  @override
  String get backupShareSelected => '已选择系统分享操作，请在目标应用核对文件是否保存或送达。';

  @override
  String get backupShareCancelled => '已取消分享，备份预览仍保留。';

  @override
  String get backupShareUnknown => '未收到系统分享结果，备份预览仍保留。';

  @override
  String get systemShareUnsupported => '此平台不支持系统分享。';

  @override
  String get completeCurrentShare => '请先完成当前分享操作。';

  @override
  String get backupShareFailed => '分享未完成，备份预览仍保留。';

  @override
  String get backupSaveCancelled => '已取消保存，备份预览仍保留。';

  @override
  String backupSavedPath(String p0) {
    return '备份已保存：\n$p0';
  }

  @override
  String get backupSaveFailed => '备份保存未完成，请检查空间与权限后重试。';

  @override
  String get backupSelectionCancelled => '已取消选择备份。';

  @override
  String get backupReadInvalid =>
      '读取或校验失败。请选择格式 v1 或 v2、10 MiB 以内的完整 JSON 台账备份；现有数据未改动。';

  @override
  String get restoreEmptyLedgerQuestion => '恢复到当前空台账？';

  @override
  String restoreConfirmation(String p0) {
    return '$p0\n保留原始 ID、金额和付款撤销状态；替换手动参考汇率。备注、连接、安全资料和提醒规则不恢复，导入服务器的提醒保持关闭。恢复不会连接或续费服务器。';
  }

  @override
  String get confirmRestore => '确认恢复';

  @override
  String get ledgerRestored => '台账已恢复。请重新配置连接与提醒；本次未连接任何服务器。';

  @override
  String get restoreFailed => '恢复未完成，现有数据未改动。恢复仅支持空台账，请重新选择备份并核对。';

  @override
  String deviceTime(String p0) {
    return '$p0（设备时间）';
  }

  @override
  String backupCounts(String p0, String p1, String p2, String p3) {
    return '$p0 台服务器 · $p1 个分组\n$p2 笔付款（含撤销） · $p3 个服务期';
  }

  @override
  String get ledgerBackupRestore => '台账备份与恢复';

  @override
  String get plainJsonVersion => '明文 JSON · 格式 v2';

  @override
  String get backupContentsWarning =>
      '包含服务器名称、厂商、地址、地区、用途、系统、规格、硬件信息、分组、金额、日期、付款和手动汇率。文件未加密，请妥善保管，只分享到可信位置。上述字段若填写了敏感内容，也会随文件导出。';

  @override
  String get notIncluded => '不包含：';

  @override
  String get generateBackupPreview => '生成导出预览';

  @override
  String get exportPreview => '导出预览';

  @override
  String backupGeneratedTime(String p0) {
    return '备份生成时间：$p0';
  }

  @override
  String get shareUnencryptedBackup => '分享未加密备份';

  @override
  String get saveJsonBackup => '保存 JSON 备份';

  @override
  String get restoreEmptyOnlyHelp =>
      '仅支持恢复到没有服务器、分组、付款和服务期的空台账。不会覆盖或合并现有数据。导入服务器的提醒默认关闭，应用偏好保持不变。';

  @override
  String get chooseJsonPreviewRestore => '选择 JSON 并预览恢复';

  @override
  String get restorePreview => '恢复预览';

  @override
  String backupTime(String p0) {
    return '备份时间：$p0';
  }

  @override
  String get restoreContentsHelp => '仅导入台账记录和手动汇率；上方所列内容不在备份内。';

  @override
  String get restoreToEmptyLedger => '恢复到空台账';

  @override
  String get appearance => '外观';

  @override
  String get followSystem => '跟随系统';

  @override
  String get lightTheme => '浅色';

  @override
  String get darkTheme => '深色';

  @override
  String get appDescription => '到期、费用、连接，都在本机';

  @override
  String get r11AppSlogan => '每台 VPS，心里有数';

  @override
  String get manageGroups => '分组管理';

  @override
  String get archivedRecords => '已归档记录';

  @override
  String get keysSecurity => '密钥与安全';

  @override
  String get keysSecurityDescription => '凭据、SSH 配置与主机信任';

  @override
  String get currenciesReferenceRates => '币种与参考汇率';

  @override
  String get notSet => '未设置';

  @override
  String get notificationAccess => '通知权限';

  @override
  String get backupExclusionsSummary => '不含凭据与主机信任 · 未加密 JSON';

  @override
  String get about => '关于';

  @override
  String developmentVersion(String version) {
    return '版本 $version';
  }

  @override
  String get appLocalDataHelp => '数据仅保存在本机，无需账号。归档不会取消服务或停止扣费。';

  @override
  String get groupSaveFailed => '未能保存分组。请检查名称是否重复，再重试。';

  @override
  String deleteGroupQuestion(String p0) {
    return '删除“$p0”？';
  }

  @override
  String get deleteGroupHelp => '组内所有服务器（含已归档）将移到“未分组”，服务器资料和历史付款保留。不会修改远端服务器。';

  @override
  String get deleteGroup => '删除分组';

  @override
  String get addGroup => '新增分组';

  @override
  String get groupsHelp => '按用途整理服务器。';

  @override
  String get noGroupsHelp => '还没有自定义分组，点右上角 + 新建。';

  @override
  String unarchivedServerCount(String p0) {
    return '$p0 台未归档服务器';
  }

  @override
  String actionsForGroup(String p0) {
    return '$p0的操作';
  }

  @override
  String get rename => '重命名';

  @override
  String get moveUp => '上移';

  @override
  String get moveDown => '下移';

  @override
  String get ungrouped => '未分组';

  @override
  String ungroupedCountHelp(String p0) {
    return '$p0 台未归档服务器 · 默认分组，不可删除';
  }

  @override
  String get archiveHelp => '归档保留资料；恢复不会启动或续费服务。';

  @override
  String get noArchivedRecords => '没有已归档记录';

  @override
  String get restoreRecord => '恢复记录';

  @override
  String get renameGroup => '重命名分组';

  @override
  String get groupName => '分组名称';

  @override
  String get save => '保存';

  @override
  String get operationFailed => '操作未完成，请重试。已保存的资料仍保留。';

  @override
  String get recordChanged => '记录已发生变化，请返回后重试';

  @override
  String get gotIt => '知道了';

  @override
  String get financeCancel => '取消';

  @override
  String get financeSaving => '正在保存…';

  @override
  String get financeUnknown => '未知';

  @override
  String get financeNotSet => '未设置';

  @override
  String get financeDateNotSet => '未设置日期';

  @override
  String get financePayments => '付款记录';

  @override
  String get financeCalculationRules => '统计口径';

  @override
  String get financeAllGroups => '全部分组';

  @override
  String get financeUngrouped => '未分组';

  @override
  String get financeNotEntered => '未填写';

  @override
  String get financeNote => '备注';

  @override
  String get financeStatus => '状态';

  @override
  String get financeEstimatedOnly => '试算 · 不入账';

  @override
  String get financeValueTitle => '剩余价值 · 按当前续费价折算';

  @override
  String get financeNotApplicable => '不适用 / 未纳入';

  @override
  String get financeDataUnknown => '资料未知';

  @override
  String get financeMissingFxPreserved => '缺少汇率 · 原币仍保留';

  @override
  String get financeMissingFxExcluded => '仅合计有汇率的部分，缺失部分未按 0 计算';

  @override
  String get financeRemainingDays => '剩余服务天数';

  @override
  String get financeRenewalCycle => '续费 / 周期';

  @override
  String get financeDailyShown => '所示周期日均';

  @override
  String get r2CopyMetricDaysLeft => '剩余天数';

  @override
  String get r2CopyMetricDaily => '日均';

  @override
  String get financeInferredPeriods => '服务起点由到期日反推，不代表付款证明。';

  @override
  String get financeValueDisclaimer => '按剩余时长折算，不是退款承诺或成交价。';

  @override
  String get financeShownPeriod => '所示周期';

  @override
  String get financeFuturePeriod => '尚未开始的周期';

  @override
  String get financeEndedPeriod => '已结束的周期';

  @override
  String get financeCurrentPeriod => '当前周期';

  @override
  String get financeFxTitle => '币种与参考汇率';

  @override
  String get financeFxScope => '仅影响参考折算，不联网取汇率；留空表示未知。';

  @override
  String get financeDisplayCurrency => '合计显示币种';

  @override
  String get financeUsdRate => '1 USD = 多少 CNY';

  @override
  String get financeEurRate => '1 EUR = 多少 CNY';

  @override
  String get financeUnknownRateHint => '留空表示汇率未知';

  @override
  String get financeRateError => '请输入大于 0 的汇率，最多 8 位小数';

  @override
  String get financeRateDate => '汇率参考日期';

  @override
  String get financePastDateError => '请输入不晚于今天的有效日期';

  @override
  String get financeFxBasis => '以 CNY 为基准；缺少汇率的币种不计入合计。';

  @override
  String get financeSaveFx => '保存参考汇率';

  @override
  String get financeReferenceTitle => '引用服务器资料';

  @override
  String get financeReferenceNote => '仅复制当前续费资料，不会修改原服务器。';

  @override
  String get financeNoPrepaid => '暂无预付费服务器，可使用独立试算。';

  @override
  String get financeDateRangeError => '请核对日期，试算范围限制为 100 年';

  @override
  String get financeMissingPeriodsError =>
      '引用资料缺少有效服务期。请先补充服务器日期，或修改到期日、周期后使用独立试算。';

  @override
  String get financeCalculatorTitle => '剩余价值计算器';

  @override
  String get financeReferenceServer => '引用服务器';

  @override
  String get financeIndependentRebuilt => '已切换为独立试算，按到期日和周期重新推算服务期。';

  @override
  String get financeIndependentNote => '独立试算，无需添加服务器；假设到期日前服务连续。';

  @override
  String get financeRenewalAmount => '每周期续费金额';

  @override
  String get financeAmountError => '请填写有效金额，明确免费可填 0';

  @override
  String get financeOriginalCurrency => '原币种';

  @override
  String get financeCycle => '续费周期';

  @override
  String get financeValuationDate => '估值日期';

  @override
  String get financeValuationDateError => '请输入有效估值日';

  @override
  String get financeServiceDue => '服务到期日';

  @override
  String get financeDueError => '请输入有效到期日';

  @override
  String get r6CalcServiceStart => '服务开始日期';

  @override
  String get r6CalcDueAutoNote => '到期日按开始日期和周期自动推算；手动选择其他日期后不再自动更新。';

  @override
  String get financeAlgorithmTitle => '周期与算法说明';

  @override
  String get financeAlgorithmNote =>
      '剩余价值 = Σ（每周期续费金额 × 该周期未用天数比例）。\n日历周期按真实天数计算，不固定每月 30 天；月底由原到期日锚点倒推，年度处理闰年。估值早于已知开始日不会超过该期整价。\n独立模式向前倒推至覆盖估值日，限制 100 年。到期当天为 0，不检查服务能否转让或退款。';

  @override
  String get financeCalculateValue => '计算剩余价值';

  @override
  String get financeEstimateNoWrite => '试算不会改动任何服务器或付款。';

  @override
  String get financeReferenceRateMissing => '参考汇率缺失';

  @override
  String get financeIndependentBasis => '独立假设：到期日前服务连续有效，期间按到期日倒推。';

  @override
  String get financeQuoteFxError => '缺少对应汇率，不能计算参考价值与结算金额。';

  @override
  String get financeCopied => '计算结果已复制，仅包含计算信息';

  @override
  String get financeCopyError => '未能写入剪贴板，请重试';

  @override
  String get financeResultTitle => '计算结果';

  @override
  String get financeEditInputs => '修改条件';

  @override
  String get financeCopyResult => '复制结果';

  @override
  String get financePreviewPng => '预览 / 保存 PNG';

  @override
  String get financeQuoteTitle => '转让报价试算 · 可选';

  @override
  String get financeQuoteNote => '仅按报价和手续费试算，不执行交易；请自行确认厂商是否允许转让。';

  @override
  String get financeQuoteAmountError => '请输入 0 或正数报价';

  @override
  String get financeTransferFee => '转移手续费（Push）';

  @override
  String get financeQuoteFeeError => '请输入 0 或正数手续费';

  @override
  String get financeFeeCurrency => '手续费币种';

  @override
  String get financeFeePayer => '手续费承担';

  @override
  String get financeBuyerPays => '买家承担';

  @override
  String get financeSellerPays => '卖家承担';

  @override
  String get financeSplitFee => '各承担一半';

  @override
  String get financeSplitFeeNote => '手续费先折算到分再均摊，不能均分的 0.01 由买方承担。';

  @override
  String get financeCalculateQuote => '计算报价与费用';

  @override
  String get financeBuyerSellerFee => '买方 / 卖方手续费';

  @override
  String get financeBuyerEstimate => '买方预计支出';

  @override
  String get financeSellerEstimate => '卖方预计净收款';

  @override
  String get financeAccountNameError => '请填写账户显示名称';

  @override
  String get financePaidAmountError => '请输入有效实付金额，0 表示免费';

  @override
  String get financeDateError => '请输入有效日期，例如 2026-10-06';

  @override
  String get financePaymentFutureError => '付款日期不能晚于今天';

  @override
  String get financePaymentConfirmError => '请确认已完成厂商付款并核对资料';

  @override
  String get financeBillPeriodError => '账期起止需同时填写，且结束日应晚于开始日';

  @override
  String get financePaymentSavedRefresh => '付款已保存，显示暂未更新，请重新读取。';

  @override
  String get financeAccountPaymentSaved => '账户账单已记录一次，实例期限未改变';

  @override
  String get financePaymentSaved => '付款已记录，服务期与统计已更新';

  @override
  String get financeRecordPayment => '记录已付款';

  @override
  String get financeNoRenewalDate => '没有可用的预付到期日，请先在服务器资料中核对。';

  @override
  String get financeRecordAccountBill => '记录账户账单';

  @override
  String get financeLocalPaymentOnly => '仅本地记账，不向厂商发起支付。';

  @override
  String get financeAccountBillNote => '独立账单，仅计一次；不分摊，不产生服务期。';

  @override
  String get financeAccountName => '账户显示名称';

  @override
  String get financeAccountNameHint => '例如：厂商 · 个人账户';

  @override
  String get financePaidAmount => '本次实付金额';

  @override
  String get financePaidCurrency => '实付币种';

  @override
  String get financePaidDate => '实际付款日期';

  @override
  String get financeRenewalCount => '本次续费周期数';

  @override
  String get financeNewDue => '新到期日';

  @override
  String get financeNewDueHint => '须与所选周期推算的日期一致';

  @override
  String get financePaymentRenewalNote => '实付单独保存，不改续费价。仅支持整周期续费。';

  @override
  String get financeBillStart => '账期开始日（选填）';

  @override
  String get financeBillEnd => '账期结束日（选填）';

  @override
  String get financeOptionalNote => '备注（选填）';

  @override
  String get financeConfirmAccountPaid => '我已在厂商完成付款，并核对账单金额与日期。';

  @override
  String get financeConfirmServerPaid => '我已在厂商完成付款，并核对实付金额与新到期日。';

  @override
  String get financeSavePayment => '保存付款记录';

  @override
  String get financeNotReceipt => '这不是厂商支付回执，不改变自动续费设置。';

  @override
  String get financePaymentTarget => '付款对象';

  @override
  String get financeAllPayments => '全部付款记录';

  @override
  String get financeShowVoided => '显示已删除';

  @override
  String get financeRecordedPaidTotal => '已记录实付合计';

  @override
  String get financeNoPayments => '— 尚无付款记录';

  @override
  String get financePaymentDetails => '付款明细';

  @override
  String get financeArchivedPayment => '服务器已归档 · 历史实付保留';

  @override
  String get financeNoPaymentsInRange => '此范围暂无付款记录。可从服务器详情记录已完成的续费付款。';

  @override
  String get financePaymentDetail => '付款详情';

  @override
  String get financePaymentUnavailable => '记录暂不可用，请返回重新读取';

  @override
  String get financePaymentDateLabel => '付款日';

  @override
  String get financeType => '类型';

  @override
  String get financeAccountBill => '账户账单';

  @override
  String get financeBillServicePeriod => '对应账期 / 服务期';

  @override
  String get financeVoidedStatus => '已删除，不计入实付统计';

  @override
  String get financeRecordedStatus => '已记录';

  @override
  String get financePaymentHistoryNote => '原币历史实付，不随续费价或汇率变化。';

  @override
  String get r2FinanceEdit => '编辑';

  @override
  String get r2FinanceEditTitle => '编辑付款记录';

  @override
  String get r2FinanceEditHint => '只修改记账信息，不改变服务期、到期日或周期数。';

  @override
  String get r2FinanceDelete => '删除记录';

  @override
  String get r2FinanceDeleteTitle => '删除此付款记录？';

  @override
  String get r2FinanceDeleteAccountMsg =>
      '仅在本地删除这条账单记录，不影响任何服务器，也不会向厂商退款。删除后不计入实付统计。';

  @override
  String get r2FinanceDeleteKeepMsg => '仅删除付款记录。服务期与到期日保持不变，也不会向厂商退款。';

  @override
  String get r2FinanceDeleteKeep => '仅删除记录，保留服务期';

  @override
  String r4PayDeleteRollbackTo(String date) {
    return '删除并回退到期日（→ $date）';
  }

  @override
  String r4PayDeleteChoiceMsg(String until) {
    return '仅删除记录会保留服务期，到期日仍为 $until。不会向厂商退款。';
  }

  @override
  String r4PayDeleteLaterMsg(String dates) {
    return '之后还有续费记录（$dates），需先删除它们才能回退到期日。此处仅删除记录，服务期与到期日不变，也不会向厂商退款。';
  }

  @override
  String r4PayOrphanBanner(String from, String until) {
    return '$from → $until 的付款已删除。回退到期日到 $from？';
  }

  @override
  String get r4PayOrphanTitle => '回退到期日？';

  @override
  String r4PayOrphanMsg(String from, String until) {
    return '移除已删除付款留下的服务期（$from → $until），到期日恢复为 $from。不影响其他付款记录。';
  }

  @override
  String get r4PayOrphanAction => '回退';

  @override
  String r4PayOrphanDone(String date) {
    return '到期日已回退到 $date';
  }

  @override
  String get r2FinanceDeleted => '付款记录已删除';

  @override
  String get r2FinanceUpdated => '付款记录已更新';

  @override
  String get financeRulesTitle => '这些数字如何计算';

  @override
  String get financeTitle => '费用';

  @override
  String get financeScope => '统计范围';

  @override
  String get financeMonthlyReference => '月费用参考';

  @override
  String get financeMonthlyNotPaid => '续费价摊月 + 按量估算，不等于本月实付。';

  @override
  String get financeUpcomingRenewals => '未来 30 天预计续费';

  @override
  String get financeRecentPayments => '付款记录';

  @override
  String get financeUnrecordedNotZero => '尚无已记录付款，不代表没有支出';

  @override
  String get financeMonthlyDistribution => '月费用分布';

  @override
  String get financeByVendor => '按厂商';

  @override
  String get financeByGroup => '按分组';

  @override
  String get financeDistributionEmpty => '添加费用资料后显示分布。';

  @override
  String get financeDistributionNote => '点击分类查看服务器明细。';

  @override
  String get financeGroupDistributionNote => '账户级实付不分摊到分组；点击分类查看明细。';

  @override
  String get financeSixMonthTitle => '本月起六个月 · 预付续费';

  @override
  String get financeForecastNote => '按当前续费价预测，假设继续续费；不含按量账单和已过期项目。';

  @override
  String get financeMonthlyDetail => '月费用明细';

  @override
  String get financeValueDetail => '剩余价值明细';

  @override
  String get financeIncompleteDetail => '费用与到期核对';

  @override
  String get financeMeteredValueNa => '按量计费 · 剩余价值不适用';

  @override
  String get financeExpiredMonthlyExcluded => '已到期，未计入月费用参考';

  @override
  String get financeUnknownAmount => '日期或费用资料不足，金额未知';

  @override
  String get financeNoServersInRange => '此范围没有服务器。';

  @override
  String get financeUnknownZeroNote => '“—”表示未知或不适用，不是免费。';

  @override
  String get financeRenewals30Title => '未来 30 天续费安排';

  @override
  String get financeNoKnownRenewals => '此范围没有已知的预付续费。';

  @override
  String get financeExpiredCheck => '已过期 · 先核实';

  @override
  String get financeMeteredRenewalNote => '按量计费不产生续费事件，月估算在服务器资料中维护。';

  @override
  String get financePngRenderFailed => '图片生成失败，原计算结果已保留。';

  @override
  String get financePngSaveFailed => '保存未完成。预览仍保留，请检查空间与权限后重试。';

  @override
  String get financePngShareSelected => '已选择系统分享操作，请在目标应用核对是否送达。';

  @override
  String get financePngShareDismissed => '已取消分享，预览仍保留。';

  @override
  String get financePngShareUnknown => '未收到系统分享结果，预览仍保留。';

  @override
  String get financePngShareUnsupported => '此平台不支持 PNG 系统分享，可保存到本地。';

  @override
  String get financePngShareBusy => '请先完成当前系统分享操作。';

  @override
  String get financePngShareFailed => '分享未完成，预览仍保留，请重试。';

  @override
  String get financePngPreview => '图片预览';

  @override
  String get financePngPrivacy => '图片仅含金额、日期、周期和参考汇率，不含服务器名称、地址或备注。';

  @override
  String get financePngSemantic => '剩余价值计算结果 PNG';

  @override
  String get financeRegenerate => '重新生成';

  @override
  String get financeSavePng => '保存 PNG';

  @override
  String get financeSharing => '正在分享…';

  @override
  String get financeSharePng => '系统分享 PNG';

  @override
  String get financePngLocationNote => '文件可能在应用私有目录；可用系统分享另存。';

  @override
  String get financeRulesBody =>
      '月费用参考：未到期的预付续费价 ÷ 周期月数，加上按量月估算。到期当天及已过期的预付服务不计入；缺少日期或费用时标记为未知。\n\n剩余价值：按各个已知服务期的未用天数折算当前续费价，包含开始日、不含结束日。尚未开始的整期计整价，已结束的期间计 0；按量付费不适用，资料不足时为未知。它不是可退款金额或成交价。\n\n续费预测：假设继续按当前周期和价格续费。未来 30 天含今天及后 29 天；六个月指本月剩余日期和后五个自然月。已过期项目不补推，不包含按量账单；本地使用计划不会改变预测。\n\n近 30 天实付：包含今天及前 29 天已记录的付款。全部范围保留归档服务器的付款，独立账户账单只计一次；按分组查看时不分摊账户账单。\n\n跨币种缺少汇率时，仅合计可折算的部分，并保留原币小计。先精确求和，再四舍五入到分；参考折算不等于实际扣款。';

  @override
  String financeApproxAmount(String amount, String currency) {
    return '约 $amount $currency';
  }

  @override
  String financeTotalAmount(String covered, String amount, String currency) {
    String _temp0 = intl.Intl.selectLogic(covered, {
      'yes': '约 $amount $currency',
      'other': '$amount $currency',
    });
    return '$_temp0';
  }

  @override
  String financeCoverage(int covered, int total, int missing) {
    String _temp0 = intl.Intl.pluralLogic(
      missing,
      locale: localeName,
      other: ' · $missing 项缺汇率',
      zero: '',
    );
    return '折算覆盖 $covered / $total$_temp0';
  }

  @override
  String financeUnknownExcluded(int unknown, int excluded) {
    return '$unknown 项未知 · $excluded 项不适用 / 未纳入';
  }

  @override
  String financeOriginalSubtotals(String amounts) {
    return '原币小计：$amounts';
  }

  @override
  String financePeriodProgress(
    String period,
    String percent,
    int remaining,
    int days,
  ) {
    return '$period剩余 $percent% · $remaining / $days 天';
  }

  @override
  String financePeriodDates(String start, String end) {
    return '$start 至 $end（不含结束日）';
  }

  @override
  String financeDaysValue(int days) {
    return '$days 天';
  }

  @override
  String financeRenewalValue(String amount, String currency, int months) {
    return '$amount $currency / $months 个月';
  }

  @override
  String financeFuturePeriodsNote(int count) {
    return '含 $count 个尚未开始的周期。';
  }

  @override
  String financeReferenceServerSubtitle(String billing, String due) {
    return '$billing · 至 $due';
  }

  @override
  String financeReferenceBasis(String name) {
    return '引用 $name 的已知服务期；修改输入不会改动原服务器。';
  }

  @override
  String financeEveryMonths(int months) {
    return '每 $months 个月';
  }

  @override
  String financeFxSource(String date) {
    return '手动汇率 · $date · 非实时报价';
  }

  @override
  String financeKnownPeriodsBasis(String inferred) {
    String _temp0 = intl.Intl.selectLogic(inferred, {
      'yes': '引用时复制的已知服务期；部分起点为推算，未回写台账。',
      'other': '引用时复制的已知服务期，未回写台账。',
    });
    return '$_temp0';
  }

  @override
  String financeSellerQuote(String currency) {
    return '卖家报价 · $currency';
  }

  @override
  String get r3FinancePeriodWeek => '近一周';

  @override
  String get r3FinancePeriodMonth => '近一个月';

  @override
  String get r3FinancePeriodQuarter => '近三个月';

  @override
  String get r3FinancePeriodHalfYear => '近六个月';

  @override
  String get r3FinancePeriodYear => '近一年';

  @override
  String get r3FinancePeriodAll => '全部';

  @override
  String r3FinanceRecentSub(int count) {
    return '近 30 天 · $count 笔';
  }

  @override
  String get r3FinanceTimelineStart => '周期开始';

  @override
  String get r3FinanceTimelineAsOf => '估值日';

  @override
  String get r3FinanceTimelineDue => '到期日';

  @override
  String get r3FinanceQuoteMode => '输入方式';

  @override
  String get r3FinanceQuoteModeOffer => '直接输入报价';

  @override
  String get r3FinanceQuoteModePremium => '输入溢价金额';

  @override
  String get r3FinanceQuoteModePercent => '输入溢价比例';

  @override
  String get r3FinanceQuoteDirection => '方向';

  @override
  String get r3FinanceQuotePremium => '溢价';

  @override
  String get r3FinanceQuoteDiscount => '折价';

  @override
  String r3FinanceQuotePremiumField(String currency) {
    return '金额 · $currency';
  }

  @override
  String get r3FinanceQuotePercentField => '占剩余价值 (%)';

  @override
  String get r3FinanceQuotePercentError => '请输入 0–1000 的比例，最多 2 位小数';

  @override
  String get r3FinanceQuoteRangeError => '折价不能超过剩余价值，成交价需在支持范围内';

  @override
  String get r3FinanceQuoteSettlement => '结算明细';

  @override
  String get r3FinanceQuoteRef => '剩余价值';

  @override
  String get r3FinanceQuoteDeal => '建议成交价';

  @override
  String financeRoundingNote(String rate, String source) {
    return '$rate\n$source。折算结果仅供参考。';
  }

  @override
  String financeCycleEndError(String date) {
    return '所选周期应至 $date';
  }

  @override
  String financeCycleCountOption(int count, int months) {
    return '$count 个周期 · 每周期 $months 个月';
  }

  @override
  String financeExtendFromDue(String date) {
    return '从原到期日 $date 起延长。';
  }

  @override
  String financeNextRenewalPrice(String billing, String currency) {
    return '下次续费价：$billing $currency';
  }

  @override
  String financeArchivedName(String name, String archived) {
    String _temp0 = intl.Intl.selectLogic(archived, {
      'yes': '$name · 已归档',
      'other': '$name',
    });
    return '$_temp0';
  }

  @override
  String financeValidPaymentsNote(int count) {
    return '$count 笔有效记录，已删除的不计入。';
  }

  @override
  String financePaymentGroupNote(String group) {
    return '当前分组：$group，不含账户账单。';
  }

  @override
  String financePaymentSummary(String date, String account, String due) {
    String _temp0 = intl.Intl.selectLogic(account, {
      'yes': '$date · 历史账户账单，只计一次',
      'other': '$date · 到期日：$due',
    });
    return '$_temp0';
  }

  @override
  String financePrepaidRenewalType(int count) {
    return '预付续期 · $count 个周期';
  }

  @override
  String financePaymentPeriodRange(String start, String end) {
    return '$start 至 $end';
  }

  @override
  String financeFxOverview(String currency, String date) {
    return '$currency 参考 · 手动汇率 $date';
  }

  @override
  String financeRenewalEventNote(int count) {
    return '$count 笔预付续费 · 今天及后 29 天';
  }

  @override
  String financeIncompleteCount(int count) {
    return '$count 台费用资料待完善 / 已到期';
  }

  @override
  String financeSliceLabel(String label, int count) {
    return '$label · $count 台';
  }

  @override
  String uiFinanceDisplayChip(String currency) {
    return '显示 $currency';
  }

  @override
  String get uiFinanceCurrencyNote => '只换算显示，不改变原币记录。';

  @override
  String get uiFinanceTileRemaining => '剩余价值';

  @override
  String get uiFinanceTileRenewals => '30 天内续费';

  @override
  String uiFinanceBannerMissingFx(int count) {
    return '$count 项金额缺少汇率，未计入合计';
  }

  @override
  String uiFinanceGapMissingFx(int count) {
    return '缺汇率 $count 项';
  }

  @override
  String uiFinanceGapUnknown(int count) {
    return '金额未知 $count 项';
  }

  @override
  String uiFinanceMonthShort(String month) {
    return '$month 月';
  }

  @override
  String get uiFinanceForecastBasis => '按当前续费价';

  @override
  String get uiFinanceToolsHeader => '记录与工具';

  @override
  String get uiFinanceFootnote => '按续费价和手动汇率折算，仅供参考，非实际账单。';

  @override
  String get uiFinanceVoidedPill => '已删除';

  @override
  String get uiFinanceArchivedPill => '已归档';

  @override
  String get uiFinanceAccountPill => '账户账单';

  @override
  String financeForecastMonth(int year, int month, int count) {
    return '$year 年 $month 月 · $count 笔';
  }

  @override
  String financeDetailScope(String label, int count) {
    return '$label · $count 台未归档服务器';
  }

  @override
  String financeAmountMetric(String amount, String currency, String metric) {
    String _temp0 = intl.Intl.selectLogic(metric, {
      'value': '$amount $currency 剩余价值',
      'other': '$amount $currency / 月参考',
    });
    return '$_temp0';
  }

  @override
  String financeDueDateValue(String date) {
    return '到期日：$date';
  }

  @override
  String financeRenewalsMonthTitle(int year, int month) {
    return '$year 年 $month 月续费';
  }

  @override
  String financeRenewalsScopeNote(int count, String group) {
    return '$count 笔 · $group · 按当前续费价预测，不代表已付款。';
  }

  @override
  String financeRenewalEventDate(String date, int months) {
    return '$date · $months 个月周期';
  }

  @override
  String financeExpiredDate(String date) {
    return '$date 已过期，不推断停机';
  }

  @override
  String financePngSavedPath(String path) {
    return 'PNG 已保存：\n$path';
  }

  @override
  String get financeRenewalDateError => '续费需要有效的周期与原到期日';

  @override
  String get financeAnchorMismatch => '服务期锚点与到期日不一致，请核对资料';

  @override
  String get financeDueRangeError => '到期日超出支持范围';

  @override
  String get financeTrialInputError => '请选择有效日期与周期，试算范围限制为 100 年';

  @override
  String get financePeriodRangeError => '服务期超出支持范围';

  @override
  String get financeTrialRangeError => '试算范围限制为 100 年';

  @override
  String get financeUnsupportedCurrency => '不支持的展示币种';

  @override
  String get financeInvalidRate => '汇率需为正数，最多 9 位整数和 8 位小数';

  @override
  String get financeMissingRateDate => '请填写手动汇率日期';

  @override
  String get financeExportDisclaimer => '仅表示服务时长的价格折算，不代表退款承诺或成交价。';

  @override
  String get financeExportHeading => 'VPS Tell You · 试算 · 不入账';

  @override
  String get financeExportFooter => '独立试算 · 图片仅含计算信息';

  @override
  String financeExportValue(String amount, String currency) {
    return '剩余价值：$amount $currency';
  }

  @override
  String financeExportValuationDate(String date) {
    return '估值日期：$date';
  }

  @override
  String financeExportPeriod(String period, String start, String end) {
    return '$period：$start 至 $end（不含结束日）';
  }

  @override
  String financeExportPeriodRemaining(
    String period,
    int remaining,
    int days,
    String percent,
  ) {
    return '$period剩余：$remaining / $days 天 · $percent';
  }

  @override
  String financeExportServiceRemaining(String due, int days) {
    return '服务到期日：$due；剩余服务天数：$days 天';
  }

  @override
  String financeExportRenewalDaily(String renewal, String daily) {
    return '续费 / 周期：$renewal；所示周期日均：$daily';
  }

  @override
  String financeExportFuturePeriods(int count) {
    return '含 $count 个尚未开始的周期，进度仅显示上述周期。';
  }

  @override
  String get billingCostUnknown => '费用未知';

  @override
  String billingMeteredAmount(String amount) {
    return '$amount/月估';
  }

  @override
  String billingAnnualAmount(String amount) {
    return '$amount/年';
  }

  @override
  String billingMonthlyAmount(String amount, int months) {
    return '$amount/$months个月';
  }

  @override
  String get backupExcludedSecrets => '密码、私钥、口令、Token、凭据元数据及安全存储引用';

  @override
  String get backupExcludedConnections => 'SSH 配置、已保存代理与主机信任';

  @override
  String get backupExcludedNotes => '命令片段、服务器备注和付款备注';

  @override
  String get backupExcludedPreferences => '提醒规则、通知排程及应用偏好';

  @override
  String get backupInvalidJson => '备份不是有效 JSON';

  @override
  String get backupUnsupportedFormat => '不支持的台账备份格式或版本';

  @override
  String get backupInvalidCollections => '备份集合类型或数量无效';

  @override
  String get backupDuplicateIds => '备份包含重复记录标识';

  @override
  String get backupGroupNameConflict => '备份分组名称冲突';

  @override
  String get backupMissingGroup => '服务器引用不存在的分组';

  @override
  String get backupInvalidServer => '服务器字段校验失败';

  @override
  String get backupAnchorMismatch => '续费锚点与到期日不一致';

  @override
  String get backupInvalidPaymentPeriod => '付款服务期无效';

  @override
  String get backupAccountBillMismatch => '独立账户账单字段不一致';

  @override
  String get backupInvalidServerPayment => '服务器付款关联无效';

  @override
  String get backupPaymentDateConflict => '有效付款与服务器期限冲突';

  @override
  String get backupServiceDateMismatch => '服务期与服务器期限不一致';

  @override
  String get backupDuplicateInitialPeriod => '同一服务器包含重复初始服务期';

  @override
  String get backupInvalidPeriodPayment => '服务期付款关联无效';

  @override
  String get backupOverlappingPeriods => '同一服务器存在重叠服务期';

  @override
  String get backupIncompletePaymentPeriod => '有效付款缺少完整服务期';

  @override
  String get backupPaymentCycleMismatch => '付款服务期与续费周期不一致';

  @override
  String get backupInitialPeriodMismatch => '初始服务期缺失或与原始期限不一致';

  @override
  String get backupInitialPeriodOutOfRange => '初始服务期超出有效日期范围';

  @override
  String get backupPeriodsNotContinuous => '有效服务期必须连续';

  @override
  String get backupPeriodsDoNotCoverDue => '有效服务期未覆盖当前到期日';

  @override
  String get backupInvalidRates => '参考汇率无效';

  @override
  String get restoreRequiresEmptyLedger => '仅支持恢复到空台账；现有数据未改动';

  @override
  String get restoreMissingRateSettings => '参考汇率设置缺失；恢复已回滚';

  @override
  String get backupGroups => '分组';

  @override
  String get backupServersIncludingArchived => '服务器（含归档）';

  @override
  String get backupPaymentsIncludingVoided => '付款（含撤销）';

  @override
  String get backupServicePeriods => '服务期';

  @override
  String restoreExistingRecords(String p0) {
    return '目标台账已有$p0';
  }

  @override
  String get backupInvalidFields => '备份字段缺失、未知或类型错误';

  @override
  String get backupInvalidText => '备份文字字段无效';

  @override
  String get backupNumberOutOfRange => '备份整数或金额超出范围';

  @override
  String get backupInvalidEnum => '备份枚举字段无效';

  @override
  String get backupInvalidDate => '备份日期无效';

  @override
  String get backupTimeRequiresUtc => '备份时间需为规范 UTC 时间';

  @override
  String get backupInvalidTime => '备份时间无效';

  @override
  String get paymentPeriodsLockFields => '已有付款服务期，不能直接修改日期、周期或计费方式；请先核对并安全撤销付款';

  @override
  String get invalidGroupName => '请输入 1–40 字的分组名，不能使用“未分组”';

  @override
  String get demoRequiresEmptyLedger => '演示数据仅能载入空台账';

  @override
  String get futureRateDate => '汇率日期不能晚于今天';

  @override
  String get invalidPaymentId => '付款标识无效';

  @override
  String get invalidPaidAmount => '请输入有效实付金额，0 表示免费';

  @override
  String get futurePaymentDate => '付款日期不能晚于今天';

  @override
  String get notesTooLong => '备注最多 4000 个字符';

  @override
  String get paymentAlreadyVoided => '此付款已撤销，请重新核对后创建新记录';

  @override
  String get paymentIdContentMismatch => '相同付款标识的内容不同，请勿重复录入';

  @override
  String get confirmProviderPayment => '请确认已在厂商付款并核对金额与期限';

  @override
  String get invalidRenewalCycleCount => '请选择 1–3 个有效续费周期';

  @override
  String get renewalNeedsPrepaidDate => '仅有明确到期日的预付服务可以续期';

  @override
  String get renewalDateMismatch => '新到期日与所选周期及原续费锚点不一致';

  @override
  String get duplicateExpiryPayment => '该服务到期日已有付款记录，请勿重复录入';

  @override
  String get invalidAccountName => '账户名称需为 1–80 个字符';

  @override
  String get invalidOptionalBillingPeriod => '可选账期需填写有效起止日期，结束日必须晚于开始日';

  @override
  String get invalidCredentialDetails => '凭据资料无效';

  @override
  String get secretWriteNotPrepared => '秘密写入未准备完成';

  @override
  String get chooseOtherCredential => '请选择另一份凭据';

  @override
  String get invalidSshConfiguration => '请填写有效主机、端口和明确用户名';

  @override
  String get verificationCancelled => '核验已取消';

  @override
  String get securityOperationIncomplete => '安全操作未完成，请重试';

  @override
  String get serverNameRange => '名称需为 1–80 个字符';

  @override
  String get serverVendorRange => '厂商需为 1–80 个字符';

  @override
  String get serverHostFormat => '请输入 IP 或域名，不含协议、端口、路径或用户名';

  @override
  String get serverUnsupportedCurrency => '不支持的币种';

  @override
  String get serverValidAmount => '请填写有效金额，0 表示免费';

  @override
  String get serverValidCycle => '请选择有效周期';

  @override
  String get serverInvalidDate => '日期无效';

  @override
  String get serverDueAfterStart => '到期日必须晚于开始日';

  @override
  String get resourceMonth => '月';

  @override
  String get resourceQuarter => '季';

  @override
  String get resourceYear => '年';

  @override
  String get resourceValidHostname => '请填写有效主机名，不含协议、端口或路径';

  @override
  String get resourceValidVcpu => 'vCPU 需为 1–65536 的整数';

  @override
  String get resourceValidRam => '内存配额需为有效正数';

  @override
  String get resourceValidDisk => '硬盘配额需为有效正数';

  @override
  String get resourceValidTraffic => '流量需填写有效正数配额，或明确选择不限量';

  @override
  String get resourceValidPeriod => '流量周期需选择月、季、年或未设置';

  @override
  String get resourceTooLarge => '本地资源配置过大';

  @override
  String get resourceInvalidFields => '本地资源配置字段无效';

  @override
  String get resourceUnlimitedTraffic => '流量不限量';

  @override
  String get resourceUnknownTraffic => '流量未知';

  @override
  String resourceTrafficQuota(String p0) {
    return '$p0 流量';
  }

  @override
  String get resourcePeriodNotSet => '周期未设置';

  @override
  String resourceEveryPeriod(String p0) {
    return '每$p0';
  }

  @override
  String resourceDiskQuota(String p0) {
    return '$p0 硬盘';
  }

  @override
  String get r6IpValidIpv4 => '请填写有效的 IPv4 地址，如 192.0.2.1，不能为全零地址';

  @override
  String get r6IpValidIpv6 => '请填写有效的 IPv6 地址，如 2001:db8::1，不含方括号或区域标识';

  @override
  String get resourceFieldValidVcpu => '请填写 1–65536 的整数核数';

  @override
  String get resourceFieldValidBytes => '请填写大于 0 的容量，精确到整字节';

  @override
  String resourceUnitSemantics(String p0) {
    return '$p0单位，1024 进制';
  }

  @override
  String get resourceTrafficPeriod => '流量周期';

  @override
  String get resourceNewPeriodHelp => '新建默认按月，可改。';

  @override
  String get resourcePeriodHelp => '周期独立于容量单位；未知选“未设置”。';

  @override
  String get resourceHardware => '硬件信息';

  @override
  String get resourceLocalHelp => '容量按 1024 进制，可选单位。';

  @override
  String get r6IpIpv4 => 'IPv4';

  @override
  String get r6IpIpv6 => 'IPv6';

  @override
  String get resourceHostname => '主机名';

  @override
  String get resourceDiskCapacity => '磁盘容量';

  @override
  String get resourceTrafficQuotaLabel => '流量额度';

  @override
  String get resourceUnlimitedHelp => '仅在商家明确不限流量时开启。';

  @override
  String get resourceMemoryCapacity => '内存容量';

  @override
  String get resourceVcpuCount => 'vCPU 核数';

  @override
  String get serverFilterTitle => '筛选服务器';

  @override
  String get serverGroup => '分组';

  @override
  String get serverAllGroups => '全部分组';

  @override
  String get serverDueStatus => '到期状态';

  @override
  String get serverAllStatuses => '全部状态';

  @override
  String get serverExpired => '已过期';

  @override
  String get serverDueNext30 => '未来 30 天到期';

  @override
  String get serverCostDateUnknown => '费用 / 到期日未知';

  @override
  String serverLedgerCount(String p0) {
    return '$p0 台服务器 · 本地台账';
  }

  @override
  String get serverAdd => '添加服务器';

  @override
  String get serverFirstTitle => '你的第一台 VPS，\n从这里开始';

  @override
  String get serverFirstDescription => '到期、费用和连接，一处记录。';

  @override
  String get serverAddFirst => '添加第一台服务器';

  @override
  String get serverLoadDemoQuestion => '载入演示数据？';

  @override
  String get serverLoadDemoHelp => '将写入 4 条“演示”记录，使用保留地址，不会连接服务器；可随时归档。';

  @override
  String get serverLoadDemo => '载入演示';

  @override
  String get serverViewDemo => '先看看演示数据';

  @override
  String get serverManualStartHelp => '已经有机器？手动记录就能开始。';

  @override
  String get serverSearchHint => '搜索名称、地址、厂商、用途或地区';

  @override
  String get serverAll => '全部';

  @override
  String get serverFavorites => '常用';

  @override
  String serverFilterLabel(String p0) {
    return '筛选$p0';
  }

  @override
  String get serverFilterSelectedSuffix => ' · 已选';

  @override
  String get serverExpiryNeedsCheck => '到期待核对';

  @override
  String get serverFavoriteServers => '常用服务器';

  @override
  String get serverAllServers => '所有服务器';

  @override
  String get serverSort => '排序';

  @override
  String get serverSortFavorites => '按常用排序';

  @override
  String get serverSortDue => '按到期排序';

  @override
  String get serverSortName => '按名称排序';

  @override
  String get serverSortUpdated => '按更新时间';

  @override
  String get serverNoUnarchived => '没有未归档服务器';

  @override
  String get serverNoMatches => '没有符合条件的记录';

  @override
  String get serverNoMatchesHelp => '试试调整筛选；已归档记录可在设置中恢复。';

  @override
  String get uiServersDueSoon => '30 天内到期';

  @override
  String get uiServersArchive => '归档';

  @override
  String get uiServersReset => '重置';

  @override
  String uiServersShowCount(int count) {
    return '显示 $count 台';
  }

  @override
  String get uiServersRowHint => '左右滑动或长按服务器查看快捷操作';

  @override
  String get serverClearFilters => '清除筛选';

  @override
  String get serverCostsMissing => '费用待补充';

  @override
  String get serverMeteredBilling => '按量计费';

  @override
  String get serverDueUnknown => '到期日未知';

  @override
  String serverExpiredDays(int p0) {
    return '已过期 $p0 天 · 待核实';
  }

  @override
  String get serverDueToday => '今天到期';

  @override
  String serverDueInDays(int p0) {
    return '$p0 天后到期';
  }

  @override
  String get serverDemo => '演示';

  @override
  String get serverNotEntered => '未填写';

  @override
  String get resourceUnlimitedConfirmed => '不限量（已确认）';

  @override
  String get resourceCardHelp => '仅本地资料，不会从商家读取。';

  @override
  String get serverSavedDisplayStale => '写入已保存，显示内容暂未更新';

  @override
  String get serverReloadBeforeEditing => '请先重新读取本地台账，再继续修改。不要重复提交，原数据不会被清除。';

  @override
  String get serverReloadStillFailed => '读取仍未完成，已保存的改动保留。请稍后重新读取。';

  @override
  String get serverReload => '重新读取';

  @override
  String get serverArchiveQuestion => '归档这台服务器？';

  @override
  String serverArchiveHelp(String p0) {
    return '$p0\n\n归档后将从服务器列表和当前费用统计中隐藏，历史付款保留。可在“设置 / 已归档记录”中恢复。不会关闭或销毁服务器，也不会停止厂商扣费。';
  }

  @override
  String get serverArchiveLocal => '归档本地记录';

  @override
  String get serverArchived => '已归档，云端资源和扣费未改变';

  @override
  String get serverUndo => '撤销';

  @override
  String get serverUndoArchiveFailed => '无法撤销，请在设置的归档记录中检查';

  @override
  String get serverDetails => '服务器详情';

  @override
  String get serverRecordUnavailable => '记录暂不可用，请返回重试';

  @override
  String get serverRemoveFavorite => '取消常用';

  @override
  String get serverSetFavorite => '设为常用';

  @override
  String get serverMoreActions => '更多操作';

  @override
  String get serverDemoWarning => '演示记录 · 保留地址，不连接真实服务器';

  @override
  String get serverBasicInfo => '基本信息';

  @override
  String get serverEdit => '编辑';

  @override
  String get serverHostAddress => '主机地址';

  @override
  String get r7DetailSavedAddress => '原有地址';

  @override
  String get serverCopyHost => '复制地址';

  @override
  String get serverHostCopied => '地址已复制';

  @override
  String get serverCopyHostFailed => '未能复制地址，请重试。';

  @override
  String get serverOperatingSystem => '操作系统';

  @override
  String get serverSpecifications => '规格';

  @override
  String get serverEditHardware => '编辑硬件';

  @override
  String get serverCostExpiry => '费用与到期';

  @override
  String get serverMonthlyEstimate => '月费用估算';

  @override
  String get serverRenewalAmount => '续费金额';

  @override
  String get serverRenewalCycle => '续费周期';

  @override
  String serverMonths(int p0) {
    return '$p0 个月';
  }

  @override
  String get serverUnknown => '未知';

  @override
  String get serverUnknownCostHelp => '未填写的金额不会按 0 计算。';

  @override
  String get serverMeteredValueHelp => '按量计费只作月估算，不计算剩余价值。';

  @override
  String get serverRenewalValueHelp => '剩余价值仅为按续费价折算的参考，不是退款或成交价。';

  @override
  String get serverReminderPlan => '到期提醒与使用计划';

  @override
  String get serverRemindersOff => '提醒已关闭';

  @override
  String get serverUnknownValueHelp => '日期或费用资料不足，剩余价值未知，不按 0 计算。';

  @override
  String get serverRecordPayment => '记录已付款';

  @override
  String get serverConnectionsControl => '连接与控制';

  @override
  String get serverSshSettings => 'SSH 连接配置';

  @override
  String get serverSshSettingsDescription => '连接地址、端口、用户名和登录凭据';

  @override
  String get serverConnectSsh => '连接 SSH';

  @override
  String get serverTcpTest => 'TCP 测试';

  @override
  String get serverConnectionSafety => '首次连接需核对主机指纹；关机或重启不会停止计费。';

  @override
  String get serverNotes => '备注';

  @override
  String serverSavedMetadata(String p0, String p1) {
    return '本地保存于 $p0\n服务器 ID：$p1';
  }

  @override
  String get uiDetailCopy => '复制';

  @override
  String get uiDetailMenuValuation => '用于剩余价值试算';

  @override
  String get uiDetailPurpose => '用途';

  @override
  String get uiDetailRegion => '地区';

  @override
  String uiDetailDueOn(String date) {
    return '到期 $date';
  }

  @override
  String get uiDetailPayments => '付款记录';

  @override
  String get uiDetailValuation => '价值试算';

  @override
  String get uiDetailFillIn => '补填';

  @override
  String get uiDetailHostKey => '主机公钥';

  @override
  String get uiDetailHostKeyTrusted => '已核验';

  @override
  String get uiDetailHostKeyFirstUse => '首次连接时核验';

  @override
  String get uiDetailNotConfigured => '未配置';

  @override
  String get uiDetailNeedSshTitle => '尚未配置 SSH';

  @override
  String uiDetailNeedSshMessage(String name) {
    return '为 $name 设置地址、端口、用户名和登录凭据后，才能连接或执行电源操作。';
  }

  @override
  String get uiDetailGoConfigure => '去配置';

  @override
  String get uiDetailArchivedUnavailable => '已归档的服务器不能进行此操作。';

  @override
  String get uiDetailNotPrepaid => '只有预付服务器可以记录续费付款。';

  @override
  String get uiDetailCannotRenew => '到期日或续费周期资料不完整，暂时无法记录续费付款。请先补充费用资料。';

  @override
  String get uiDetailReadOnly => '本地数据读取未完成或正在处理，暂时不能记录付款。请先重新读取。';

  @override
  String get uiDetailQuickSsh => 'SSH 连接';

  @override
  String get uiDetailQuickPayment => '记录付款';

  @override
  String get uiDetailQuickPower => '电源';

  @override
  String get r2DetailMetricValue => '剩余价值';

  @override
  String get r2DetailMetricDays => '剩余天数';

  @override
  String get r2DetailMetricDaily => '日均';

  @override
  String serverRequiredField(String p0) {
    return '请填写$p0';
  }

  @override
  String get serverAmountPrecision => '请输入有效金额，最多两位小数';

  @override
  String get serverDateExample => '请使用有效日期，例如 2026-10-06';

  @override
  String get serverBillingType => '计费方式';

  @override
  String get serverEveryYear => '每年';

  @override
  String serverEveryMonths(int p0) {
    return '每 $p0 个月';
  }

  @override
  String get serverOriginalCurrency => '原币种';

  @override
  String get serverMonthlyCostEstimate => '每月费用估算';

  @override
  String serverRenewalPriceHelp(String p0) {
    return '$p0续费金额，实付另记';
  }

  @override
  String get serverStartDate => '开始日期';

  @override
  String get serverDueDate => '到期日期';

  @override
  String get serverOptionalStart => '服务开始日（选填）';

  @override
  String get serverOptionalDue => '服务到期日（选填）';

  @override
  String get serverEditTitle => '编辑服务器';

  @override
  String get serverBasicData => '基本资料';

  @override
  String get serverName => '服务器名称';

  @override
  String get serverOptionalPurpose => '用途（选填）';

  @override
  String get serverOptionalRegion => '地区（选填）';

  @override
  String get serverOptionalOs => '操作系统（选填）';

  @override
  String get serverCostDetails => '费用资料';

  @override
  String get serverPaymentLockHelp => '已有续费付款：计费方式、周期和日期已锁定。';

  @override
  String get serverDatesHelp => '到期日默认按开始日加周期计算，可手动修改。';

  @override
  String get serverAmountHelp => '0 表示免费；未知请选“未知”。不会记录付款。';

  @override
  String get serverOptionalNotes => '备注（选填）';

  @override
  String get serverNotesSafety => '备注不加密，请勿存放密码、私钥或令牌。';

  @override
  String get uiFormProvider => '提供商';

  @override
  String get r7FormProviderNone => '不指定';

  @override
  String get r7FormProviderNew => '新建提供商…';

  @override
  String get uiFormPurpose => '用途';

  @override
  String get uiFormRegion => '地区';

  @override
  String get uiFormOptional => '选填';

  @override
  String get uiFormNameHint => '例如 HK-01';

  @override
  String get uiFormDone => '完成';

  @override
  String get uiFormSetUnknown => '设为未知';

  @override
  String get uiFormUnknownCostFootnote => '费用未知时不计入合计。';

  @override
  String get uiFormVcpuDecrease => '减少 vCPU';

  @override
  String get uiFormVcpuIncrease => '增加 vCPU';

  @override
  String get uiFormCollapse => '收起硬件信息';

  @override
  String get uiFormExpand => '展开硬件信息';

  @override
  String get uiFormMemory => '内存';

  @override
  String get uiFormDisk => '磁盘';

  @override
  String get uiFormTraffic => '流量';

  @override
  String get uiFormBillingPrepaid => '预付';

  @override
  String get uiFormBillingMetered => '按量';

  @override
  String get serverWaitForOperation => '请等待当前操作完成';

  @override
  String get serverReloadSavedFirst => '请先重新读取已保存的台账';

  @override
  String get connectionBrowserTcpUnsupported => '浏览器没有原生 TCP；请使用原生应用';

  @override
  String get connectionHostKeyUnverified => '无法核实完整主机公钥，连接已阻止';

  @override
  String get connectionHandshakeUnsupported => 'SSH 握手格式或大小不受支持';

  @override
  String get tcpValidIpv6 => '请输入有效的 IPv6 地址';

  @override
  String get tcpValidHost => '请输入 IP 或域名，不含协议、端口或路径';

  @override
  String get tcpValidPort => '端口需为 1–65535';

  @override
  String get tcpSource => '本机 TCP 连接测试';

  @override
  String get tcpConnected => 'TCP 连接成功';

  @override
  String get tcpRefused => '连接被拒绝';

  @override
  String get tcpTimedOut => '连接超时';

  @override
  String get tcpCancelled => '测试已取消';

  @override
  String get tcpFailed => '连接失败（网络或地址不可用）';

  @override
  String get tcpTimeoutPositive => '超时必须大于 0';

  @override
  String get tcpSingleTarget => '单目标 TCP 测试';

  @override
  String get tcpTestExplanation => '仅测试能否建立 TCP 连接，不发送数据。成功不代表 SSH 可登录或服务正常。';

  @override
  String get tcpAddress => 'IP / 域名';

  @override
  String get connectionPort => '端口';

  @override
  String tcpTestingTarget(String p0) {
    return '正在测试 $p0';
  }

  @override
  String get tcpCancel => '取消测试';

  @override
  String get tcpStart => '开始测试';

  @override
  String tcpTimeoutHelp(int p0) {
    return '单次最多 $p0 秒；修改目标、离开页面或进入后台会取消测试。';
  }

  @override
  String get tcpOneObservation => '此结果仅反映当次观察，不是持续状态。';

  @override
  String get terminalCurrentDirectory => '当前目录';

  @override
  String get terminalListFiles => '列出文件';

  @override
  String get terminalUptime => '运行时间';

  @override
  String get terminalDiskUsage => '磁盘用量';

  @override
  String get terminalMemoryUsage => '内存用量';

  @override
  String get terminalCommandsWithDraft => '命令与片段 · 有未发送草稿';

  @override
  String get terminalCommandsSnippets => '命令与片段';

  @override
  String get terminalCommands => '命令';

  @override
  String get terminalControlHelp => 'Ctrl，作用于下一个按键，再点取消';

  @override
  String get terminalControlPaste => 'Ctrl V · 粘贴到草稿，不自动发送';

  @override
  String get terminalArrowUp => '向上方向键';

  @override
  String get terminalArrowDown => '向下方向键';

  @override
  String get terminalArrowLeft => '向左方向键';

  @override
  String get terminalArrowRight => '向右方向键';

  @override
  String get terminalSendUnconfirmed => '发送未确认，草稿仍保留。请先核实远端状态，避免重复执行。';

  @override
  String get terminalSend => '发送';

  @override
  String get terminalSendExecute => '发送并执行';

  @override
  String get terminalBack => '返回终端';

  @override
  String get terminalQuickCommands => '常用命令';

  @override
  String get terminalInsertSnippet => '插入片段';

  @override
  String get terminalDraft => '待发送草稿';

  @override
  String get terminalDraftHint => '在此编辑要发送的内容';

  @override
  String get terminalPaste => '粘贴';

  @override
  String get terminalSendTo => '发送到';

  @override
  String get terminalControlCharacterWarning => '正文含换行、回车或控制字符，不追加回车也可能立即执行。';

  @override
  String get terminalSessionChanged => '会话已变化，请返回终端后重新打开。草稿不会自动发送。';

  @override
  String get terminalCannotSend => '当前不可发送。重连会清空草稿，不重放输入。';

  @override
  String get terminalSendMeaning => '“发送”不追加回车；“发送并执行”追加回车，由当前终端程序处理。';

  @override
  String get connectionReadFailed => '无法读取连接资料，请重试';

  @override
  String get connectionTemporary => '临时连接';

  @override
  String get connectionInvalidDetails => '连接资料无效，请检查地址、端口和凭据';

  @override
  String get connectionChoosePowerTarget => '选择单机电源目标';

  @override
  String get connectionIdentityFirst => '一次只连接一台。核对主机身份后，才向服务器发送所选凭据的认证信息。';

  @override
  String get connectionWebPreviewWarning =>
      'Web 预览不支持原生 SSH / TCP，也不接受真实登录凭据。请使用原生应用。';

  @override
  String get connectionReloadDetails => '重新读取连接资料';

  @override
  String get connectionTargetServer => '目标服务器';

  @override
  String get connectionTemporaryTarget => '临时目标 · 不保存配置';

  @override
  String get connectionDemoSuffix => ' · 演示，不连接';

  @override
  String get connectionDemoBlocked => '演示服务器使用保留地址，不允许建立网络连接。';

  @override
  String get connectionAddressHint => 'IPv4 / IPv6 / 域名';

  @override
  String get connectionValidHost => '请输入有效主机，不含协议、用户名或端口';

  @override
  String get connectionPortRange => '端口应为 1–65535';

  @override
  String get connectionUsername => '登录用户名';

  @override
  String get connectionValidUsername => '请填写有效的登录用户名';

  @override
  String get connectionSavedCredentials => '已保存的登录凭据';

  @override
  String get connectionChooseCredentials => '请选择登录凭据';

  @override
  String connectionUseDefaultUsername(String p0) {
    return '使用默认用户名：$p0';
  }

  @override
  String get connectionManageCredentials => '管理凭据';

  @override
  String get connectionEditSavedSettings => '编辑并保存此服务器的 SSH 配置';

  @override
  String get connectionTemporaryChangesHelp =>
      '本页改动只用于本次连接。密码或私钥从已保存的凭据中读取，不在这里输入或另存。进入后台后会话只保留系统允许的短暂时间（通常约 30 秒）；长任务建议在远端使用 tmux / screen。';

  @override
  String get connectionSnippetDraftOnly => '片段将放入独立待发送区。连接、核验、认证都不会发送片段。';

  @override
  String get connectionPowerAfterConnect => '连接后选择重启 / 关机，需完成两次确认；不支持开机。';

  @override
  String get connectionReviewConnect => '核对并连接';

  @override
  String get uiConnTarget => '目标';

  @override
  String get uiConnCredential => '凭据';

  @override
  String get uiConnStatus => '状态';

  @override
  String get uiConnHostKey => '主机公钥';

  @override
  String get uiConnHostKeyVerified => '已核验';

  @override
  String get uiConnHostKeyFirstUse => '首次连接需核验';

  @override
  String get uiConnResult => '结果';

  @override
  String get uiConnSource => '来源';

  @override
  String get uiConnFinished => '结束时间（本机）';

  @override
  String get uiConnElapsed => '耗时';

  @override
  String get uiConnActualAddress => '实际地址';

  @override
  String get uiConnMoreActions => '更多操作';

  @override
  String get snippetFullEscapedPreview => '完整内容预览（转义显示）';

  @override
  String get snippetEscapeLegend =>
      '换行显示为 \\n；回车为 \\r；制表为 \\t；其他控制字符显示为 \\u{…}。反斜线也已转义。';

  @override
  String get snippetPreviewNoSend =>
      '预览和插入都不会发送内容。请在终端核对目标与完整草稿，再选择“发送”或“发送并执行”。';

  @override
  String get connectionClose => '关闭';

  @override
  String get snippetInsertDraftOnly => '仅插入待发送草稿';

  @override
  String get snippetChanged => '片段已被修改或删除，请重新打开列表后重试。';

  @override
  String get snippetOperationFailed => '片段操作未完成，请重试。已保存的内容仍保留。';

  @override
  String get snippetDeleteQuestion => '删除本地片段？';

  @override
  String snippetDeleteHelp(String p0) {
    return '将删除“$p0”的本地模板，不影响服务器或已插入的草稿。';
  }

  @override
  String get snippetDelete => '删除片段';

  @override
  String get snippetChoose => '选择片段插入草稿';

  @override
  String get snippetReadFailed => '片段读取失败，未修改本地数据';

  @override
  String get snippetSelectPreviewHelp => '选择后先预览，只插入草稿，不会自动发送。';

  @override
  String get snippetPlaintextHelp =>
      '片段是本地普通文本，请勿保存密码、私钥或令牌。从终端“插入片段”可选入待发送草稿。';

  @override
  String get snippetAdd => '新增片段';

  @override
  String get snippetEmptyHelp => '还没有片段。新增自己的常用命令模板。';

  @override
  String snippetCharacterCount(String p0) {
    return '$p0 个字符 · 本地模板';
  }

  @override
  String get snippetPreviewInsert => '预览并插入草稿';

  @override
  String get snippetFullPreview => '完整预览';

  @override
  String get connectionDelete => '删除';

  @override
  String get snippetDiscardQuestion => '放弃片段修改？';

  @override
  String get snippetDiscardHelp => '未保存的内容不会写入本地片段。';

  @override
  String get connectionDiscardChanges => '放弃修改';

  @override
  String get snippetEdit => '编辑片段';

  @override
  String get snippetSaveSafety => '片段以明文保存，请勿填写密码、私钥或令牌。';

  @override
  String get snippetName => '片段名称';

  @override
  String get snippetFullContent => '完整内容（保留原始换行与控制字符）';

  @override
  String get snippetContentRange => '内容不能为空，最多 16384 个字符';

  @override
  String get snippetExactContentHelp => '内容原样保存，含空白和控制字符；请用完整预览核对。';

  @override
  String get terminalCopyFailed => '未能复制终端内容，请重试。';

  @override
  String get terminalSelectionCopied => '已复制所选终端内容';

  @override
  String get terminalDraftChangedPaste => '草稿已变化，请再次点击粘贴。';

  @override
  String get terminalClipboardEmpty => '剪贴板中没有可粘贴的文本。';

  @override
  String get terminalPasteTooLong => '粘贴后超过 16384 个字符，草稿未修改。';

  @override
  String get terminalClipboardReadFailed => '剪贴板读取失败，草稿未修改。请重新点击粘贴。';

  @override
  String get terminalReplaceDraftQuestion => '替换当前草稿？';

  @override
  String get terminalReplaceDraftHelp => '当前未发送的草稿会被替换。不会向 SSH 发送任何内容。';

  @override
  String get terminalReplaceDraft => '替换草稿';

  @override
  String get terminalCurrentSession => '当前 SSH 会话';

  @override
  String terminalDimensions(String p0, String p1, String p2) {
    return '$p0 · $p1 列 × $p2 行';
  }

  @override
  String get terminalSelectionHelp =>
      '点按终端输入；长按并拖动选择，使用“复制”复制。向上滚动查看历史，向下箭头回到最新输出。';

  @override
  String get terminalInputHelp =>
      '键盘和特殊键直接发送到 SSH。常用命令、片段和粘贴先进入独立草稿；“发送”不追加回车，“发送并执行”追加回车，由当前终端程序处理。正文原有换行仍可能执行。Ctrl 作用于下一个按键，再点可取消。';

  @override
  String get terminalBackgroundHelp =>
      '会话结束或离开会关闭此页。进入后台后会话只保留系统允许的短暂时间（通常约 30 秒），超时即断开，不会自动重连或重放输入。长任务建议在远端使用 tmux / screen。';

  @override
  String r2ConnDisconnectHelp(String p0) {
    return '$p0\n未放入 tmux / screen 的远端任务可能中断；未发送的草稿将丢弃。';
  }

  @override
  String get terminalOfflineFont => '离线字体：DejaVu Sans Mono · 中文使用设备字体回退';

  @override
  String get terminalLicenses => '开源许可';

  @override
  String get terminalDisconnectQuestion => '断开 SSH 会话？';

  @override
  String get terminalDisconnectExit => '断开并退出';

  @override
  String get terminalBackgroundDisconnected => '应用进入后台，连接已断开';

  @override
  String get terminalTargetChanged => '目标已变化，连接已断开';

  @override
  String get terminalPowerMenuHelp => '连接后在“终端菜单”选择 SSH 重启或关机，并完成两次确认。';

  @override
  String get terminalHostChanged => '主机密钥变化 · 已阻断认证';

  @override
  String get terminalHostChangedHelp =>
      '这可能是重装或中间人攻击。尚未发送登录凭据。请通过厂商控制台等独立渠道核实原因与新公钥。';

  @override
  String get terminalPreviousFingerprint => '此前指纹';

  @override
  String get terminalNoRecord => '无记录';

  @override
  String get terminalCurrentFingerprint => '本次指纹';

  @override
  String get terminalRejectConnection => '拒绝连接';

  @override
  String get terminalReverify => '开始独立重新核实';

  @override
  String get terminalPowerFailed =>
      '电源指令未能确认成功。请核实连接、远端权限及厂商控制台状态，避免重复执行；不会自动重发。';

  @override
  String get terminalPowerUnknown =>
      '电源指令已尝试提交，结果未知。连接断开不证明操作完成；请到厂商控制台核实，不会自动重发。';

  @override
  String get terminalNotConnected => '未连接';

  @override
  String get terminalConnecting => '连接中';

  @override
  String get terminalVerifying => '核验主机身份中';

  @override
  String get terminalAuthenticating => '认证中';

  @override
  String get terminalConnected => '已连接 · SSH PTY';

  @override
  String get terminalDisconnected => '已断开';

  @override
  String get terminalFailed => '连接失败';

  @override
  String get terminalExit => '退出终端';

  @override
  String terminalSessionSemantics(String p0, String p1) {
    return '会话详情，$p0，$p1';
  }

  @override
  String get terminalHideKeyboard => '收起键盘';

  @override
  String get terminalOpenKeyboard => '打开键盘';

  @override
  String get terminalMenu => '终端菜单';

  @override
  String get terminalSessionDetails => '会话详情与使用说明';

  @override
  String get terminalPasteIntoDraft => '粘贴到草稿';

  @override
  String get r3TermColorScheme => '配色与高亮';

  @override
  String get r3TermSchemeDark => '深色';

  @override
  String get r3TermSchemeLight => '浅色';

  @override
  String get r3TermSchemeFootnote => '仅改变显示，不向服务器发送任何内容。重启应用后恢复默认。';

  @override
  String get r4HlSmart => '智能高亮';

  @override
  String get r4HlSmartNote => '给默认颜色的输出着色（路径、IP、数字、错误等）。仅本地显示，不改变收发内容。';

  @override
  String get r4HlLanguage => '语法高亮';

  @override
  String get r4HlAuto => '自动识别';

  @override
  String get r4HlPlain => '关闭（纯文本）';

  @override
  String get r4HlGeneric => '通用';

  @override
  String get r4HlTooLarge => '文件超过 256 KiB，未做语法高亮';

  @override
  String get terminalCancelConnection => '取消连接';

  @override
  String get terminalSshRestart => 'SSH 重启';

  @override
  String get terminalSshShutdown => 'SSH 关机';

  @override
  String get terminalTypeDirectly => '点按终端输入，按键直接发送';

  @override
  String get terminalCopy => '复制';

  @override
  String get terminalClearSelection => '取消选择';

  @override
  String get terminalLatestOutput => '回到最新输出';

  @override
  String get terminalEstablishingSecure => '正在建立安全连接…';

  @override
  String get terminalOffline => '终端未连接';

  @override
  String get terminalConnect => '连接';

  @override
  String get terminalBrowserUnsupported => '浏览器不支持原生 SSH，请使用原生应用。';

  @override
  String get terminalDismissNotice => '关闭提示';

  @override
  String get terminalVerifyNewHost => '重新核实新的主机公钥';

  @override
  String get terminalFirstHostVerification => '首次连接 · 核对主机身份';

  @override
  String terminalHostIdentity(String p0, String p1, String p2) {
    return '主机：$p0\n端口：$p1\n算法：$p2';
  }

  @override
  String get terminalSha256Fingerprint => 'SHA-256 指纹';

  @override
  String get terminalFullHostKey => '完整主机公钥';

  @override
  String get terminalIndependentVerificationHelp =>
      '请从厂商控制台或其他独立可信渠道核对。仅看见这个弹窗不代表身份可信。';

  @override
  String get terminalConfirmedChangedHost => '我已独立重新核实变化原因与完整新公钥';

  @override
  String get terminalConfirmedHost => '我已通过独立渠道核实本次完整主机身份';

  @override
  String get terminalVerificationExpired => '连接已取消或超时，此核验已失效。';

  @override
  String get terminalUpdateTrustAuthenticate => '更新信任并继续认证';

  @override
  String get terminalTrustAuthenticate => '确认信任并认证';

  @override
  String get terminalUnlockKey => '解锁本次 SSH 私钥';

  @override
  String terminalCredentialName(String p0) {
    return '凭据：$p0';
  }

  @override
  String get terminalPassphraseHelp => '私钥解密口令，不是登录密码；仅用于本次连接，不保存。';

  @override
  String get terminalKeyPassphrase => '本次私钥口令';

  @override
  String get terminalPassphraseCleared => '口令已清空，请取消后重新连接。';

  @override
  String get terminalUnlockOnce => '仅解锁本次连接';

  @override
  String get powerRestart => '重启';

  @override
  String get powerShutdown => '关机';

  @override
  String powerImpactTitle(String p0) {
    return '$p0影响确认（1/2）';
  }

  @override
  String powerImpactHelp(String p0, String p1, String p2) {
    return '$p0\n$p1\n\n通过当前单台 SSH 连接执行：\n$p2\n\n可能立即中断业务及 SSH 会话，需要远端相应权限。关机不会取消厂商计费，SSH 无法再次开机。连接中断或超时后结果未知，请到厂商控制台核实，勿盲目重试。';
  }

  @override
  String get powerUnderstandContinue => '了解影响，继续核对';

  @override
  String powerFinalTitle(String p0) {
    return '最终确认$p0（2/2）';
  }

  @override
  String get powerEnterTarget => '请完整输入本次目标，确认只下发一次：';

  @override
  String get powerTargetFormat => '用户名@主机:端口';

  @override
  String get powerConfirmationInvalidated => '连接已变化。本次确认已作废，未下发指令。';

  @override
  String powerExecuteOnce(String p0) {
    return '仅执行一次$p0';
  }

  @override
  String get snippetInvalidId => '片段标识无效';

  @override
  String get sshCheckTarget => '请检查 SSH 端口、用户名与凭据';

  @override
  String get sshConnectionCancelled => 'SSH 连接已取消';

  @override
  String get sshBrowserUnsupported => '浏览器不支持原生 SSH，请使用原生应用';

  @override
  String get sshCredentialReadTimeout => '读取 SSH 凭据超时';

  @override
  String get sshKeyNeedsPassphrase => '此私钥需要解密口令，请重新连接并输入';

  @override
  String get sshPassphraseInputTimeout => '输入私钥口令超时，未进行连接';

  @override
  String get sshPassphraseCancelled => '已取消私钥口令输入，未进行连接';

  @override
  String get sshPassphraseTooLong => '私钥口令超出长度限制';

  @override
  String get sshKeyDecryptionTimeout => '私钥解密超时，未进行连接';

  @override
  String get sshTcpTimeout => 'SSH TCP 连接超时';

  @override
  String get sshHandshakeTimeout => 'SSH 握手超时';

  @override
  String get sshIdentityChanged => '主机核验或凭据已变化，认证已阻止';

  @override
  String get sshVerificationCancelled => 'SSH 核验已取消';

  @override
  String get sshVerificationTimeout => '主机核验超时，未进行认证';

  @override
  String get sshCredentialChanged => '凭据已变化，请重新连接';

  @override
  String get sshAuthenticationTimeout => 'SSH 认证超时';

  @override
  String get sshTerminalOpenTimeout => 'SSH 终端开启超时';

  @override
  String get r3SftpOpenTimeout => 'SFTP 开启超时';

  @override
  String get r3SftpUnavailable => '服务器未开启 SFTP，可能已对该账户禁用';

  @override
  String get r3SftpTitle => 'SFTP 文件';

  @override
  String get r3SftpUp => '上级目录';

  @override
  String get r3SftpRoot => '根目录';

  @override
  String get r3SftpNewFolder => '新建文件夹';

  @override
  String get r3SftpNewFile => '新建空文件';

  @override
  String get r3SftpUpload => '从手机上传';

  @override
  String get r3SftpSort => '排序方式';

  @override
  String get r3SftpSortName => '名称';

  @override
  String get r3SftpSortSize => '大小';

  @override
  String get r3SftpSortTime => '修改时间';

  @override
  String get r3SftpShowHidden => '显示隐藏文件';

  @override
  String get r3SftpSearch => '搜索当前文件夹';

  @override
  String get r3SftpEmpty => '此文件夹为空';

  @override
  String get r3SftpNoMatch => '没有匹配项';

  @override
  String r3SftpShowMore(int count) {
    return '显示更多（$count）';
  }

  @override
  String get r3SftpMore => '更多';

  @override
  String get r3SftpAdd => '新建';

  @override
  String get r3SftpOpen => '打开';

  @override
  String get r3SftpView => '查看 / 编辑';

  @override
  String get r3SftpDownload => '下载';

  @override
  String get r3SftpRename => '重命名 / 移动';

  @override
  String get r3SftpCopyPath => '复制路径';

  @override
  String get r3SftpDelete => '删除';

  @override
  String get r3SftpPathCopied => '已复制路径';

  @override
  String get r3SftpNameLabel => '名称';

  @override
  String get r3SftpFolderLabel => '所在文件夹';

  @override
  String get r3SftpCreate => '创建';

  @override
  String get r3SftpRenameTitle => '重命名或移动';

  @override
  String get r3SftpRenameHint => '改名称即重命名，改文件夹即移动。';

  @override
  String get r3SftpInvalidName => '名称不能为空或包含“/”';

  @override
  String get r3SftpInvalidFolder => '文件夹须为以 / 开头的绝对路径';

  @override
  String r3SftpDeleteTitle(String name) {
    return '删除“$name”？';
  }

  @override
  String get r3SftpDeleteFileMessage => '将在服务器上永久删除该文件。';

  @override
  String get r3SftpDeleteFolderMessage => '将在服务器上永久删除这个空文件夹。';

  @override
  String get r3SftpDeleteRecursiveTitle => '删除文件夹及其全部内容？';

  @override
  String r3SftpDeleteRecursiveMessage(String name, int max) {
    return '“$name”不为空，其中所有内容将被永久递归删除（不跟随链接）。超过 $max 项的文件夹会被拒绝，且不会删除任何内容。';
  }

  @override
  String get r3SftpDeleteRecursiveAction => '全部删除';

  @override
  String get r3SftpDeleted => '已删除';

  @override
  String r3SftpDeletedCount(int count) {
    return '已删除 $count 项';
  }

  @override
  String get r3SftpErrPermission => '没有权限';

  @override
  String get r3SftpErrNotFound => '未找到，可能已被移动或删除';

  @override
  String get r3SftpErrExists => '已存在同名项目';

  @override
  String get r3SftpErrNotEmpty => '文件夹不为空';

  @override
  String get r3SftpErrWrongType => '该项目类型不适用于此操作';

  @override
  String get r3SftpErrCancelled => '已取消';

  @override
  String get r3SftpErrTooLarge => '文件过大，无法作为文本打开（上限 512 KiB）';

  @override
  String get r3SftpErrNotText => '不是 UTF-8 文本文件';

  @override
  String r3SftpErrTooMany(int max) {
    return '项目过多（上限 $max），未删除任何内容';
  }

  @override
  String get r3SftpErrInvalidPath => '路径无效';

  @override
  String get r3SftpErrTimeout => '服务器响应超时';

  @override
  String get r3SftpErrConnectionLost => 'SFTP 连接已断开';

  @override
  String get r3SftpErrUnavailable => '此连接无法使用 SFTP';

  @override
  String get r3SftpErrLocalFile => '无法读写本地文件';

  @override
  String get r3SftpErrFailed => '操作失败';

  @override
  String r3SftpEditorSize(String size) {
    return '$size · UTF-8';
  }

  @override
  String get r3SftpSaved => '已保存';

  @override
  String get r3SftpUnsavedTitle => '放弃未保存的修改？';

  @override
  String get r3SftpUnsavedMessage => '修改尚未写入服务器。';

  @override
  String get r3SftpDiscard => '放弃';

  @override
  String get r3SftpConflictTitle => '服务器上的文件已变化';

  @override
  String get r3SftpConflictMessage => '它在你打开后被修改过。要用你的版本覆盖服务器上的版本吗？';

  @override
  String get r3SftpOverwrite => '覆盖';

  @override
  String r3SftpExistsTitle(String name) {
    return '“$name”已存在';
  }

  @override
  String get r3SftpExistsMessage => '覆盖服务器上的文件，还是跳过这次上传？';

  @override
  String get r3SftpLargeTitle => '大文件';

  @override
  String r3SftpLargeMessage(String name, String size) {
    return '“$name”大小为 $size，可能耗时较长并消耗大量流量。继续吗？';
  }

  @override
  String get r3SftpContinue => '继续';

  @override
  String get r3SftpTransfers => '传输';

  @override
  String r3SftpTransferUp(String name) {
    return '正在上传 $name';
  }

  @override
  String r3SftpTransferDown(String name) {
    return '正在下载 $name';
  }

  @override
  String r3SftpTransferCount(int index, int total) {
    return '第 $index / $total 项';
  }

  @override
  String get r3SftpStateQueued => '等待中';

  @override
  String get r3SftpStateDone => '完成';

  @override
  String get r3SftpStateCancelled => '已取消';

  @override
  String get r3SftpStateSkipped => '已跳过';

  @override
  String get r3SftpCancelAll => '全部取消';

  @override
  String get r3SftpClearFinished => '清除已完成';

  @override
  String get r3SftpShare => '分享';

  @override
  String r3SftpSavedTo(String path) {
    return '已保存到 $path';
  }

  @override
  String get r3SftpDownloadsWhere =>
      '下载的文件保存在应用文件夹“SFTP Downloads”中。可用“分享”另存到其他位置，例如“文件”。';

  @override
  String get r3SftpCloseBusyTitle => '传输进行中';

  @override
  String get r3SftpCloseBusyMessage => '关闭将取消进行中和等待中的传输。';

  @override
  String get r3SftpCloseBusyAction => '取消传输并关闭';

  @override
  String get r3SftpBackgroundClosed => '应用进入后台，SFTP 已关闭';

  @override
  String get r3SftpConnecting => '正在连接 SFTP…';

  @override
  String get r3SftpConnectFailed => '无法打开 SFTP';

  @override
  String get r3SftpRetry => '重试';

  @override
  String get r3SftpChooseCredential => '请先在 SSH 设置中选择凭据。';

  @override
  String get r3SftpSshSettings => 'SSH 设置';

  @override
  String get r3SftpLoadFailed => '无法加载此文件夹';

  @override
  String get r3SftpClose => '关闭';

  @override
  String r3SftpUploadsQueued(int count) {
    return '已加入上传队列：$count 个';
  }

  @override
  String get sshAuthenticationFailed => 'SSH 认证失败，请检查用户名和凭据';

  @override
  String get sshHostNotTrusted => '主机未获信任，未进行认证';

  @override
  String get sshConnectionIncomplete => 'SSH 连接未完成，请检查地址、网络与服务';

  @override
  String get sshSessionEnded => 'SSH 会话已结束；命令是否完成请在重连后核实';

  @override
  String get sshInputUnconfirmed => 'SSH 输入发送未确认；请重连后核实，避免重复执行';

  @override
  String get sshResizeFailed => 'SSH 终端大小调整失败，请重连';

  @override
  String get sshPrivatePublicMismatch => '私钥与已保存的公钥信息不一致，请重新导入私钥后再连接';

  @override
  String get securityReadFailed => '无法读取安全资料，请重试';

  @override
  String get securitySavedReloadFailed => '已保存，但资料重读失败；请重读后再修改';

  @override
  String get securityDataChanged => '资料已变化，请重读后重试';

  @override
  String get securityMutationFailed => '安全操作未完成，原资料未更改；请重试';

  @override
  String get securityInvalidCredentialIdentity => '请输入 1–80 字名称及有效默认用户名';

  @override
  String get securitySecretRequired => '请提供秘密内容';

  @override
  String get securityReimportForPassphrase => '更新已保存的口令时，请同时重新导入对应私钥';

  @override
  String get securityPasswordNoPassphrase => '密码凭据不使用私钥口令';

  @override
  String get securitySecretSizeInvalid => '秘密内容为空或超出大小限制';

  @override
  String get securitySecretWriteUnverified => '秘密写入未能校验，原凭据保持不变';

  @override
  String get securityCleanupIncomplete => '秘密清理尚未完成，可稍后重试';

  @override
  String get securityCleanupReadFailed => '无法读取待清理资料，请重试';

  @override
  String get securitySshCancelled => 'SSH 连接已取消或资料需重读';

  @override
  String get securityChooseAvailableCredential => '请选择可用凭据';

  @override
  String get securityCredentialSecretMissing =>
      '未找到此凭据的密码或私钥，请到“管理凭据”重新保存密码或导入私钥';

  @override
  String get securityStoredSecretUnreadable => '安全存储资料无法读取';

  @override
  String get securityCredentialChanged => '凭据已变化，请重读后重试';

  @override
  String get securitySshCredentialReadFailed => '无法读取 SSH 凭据，请重试';

  @override
  String get securityAuthenticationHidden => '设备认证未完成，秘密仍隐藏';

  @override
  String get securitySavedPasswordMissing => '未找到已保存的密码，请编辑此凭据并重新保存密码';

  @override
  String get securityRevealFailed => '无法显示秘密，请重试';

  @override
  String get securityHostTargetMismatch => '主机核验目标不一致';

  @override
  String get securityHostAuthenticationIncomplete => '主机核验或认证未完成';

  @override
  String get securityInvalidHost => '主机地址无效，请填写 IP 或域名，不含协议、用户名、端口或路径';

  @override
  String get securityInvalidSshPort => 'SSH 端口应为 1–65535';

  @override
  String get securityHostKeyUnreadable => '无法识别主机公钥，请检查完整公钥内容及所选类型';

  @override
  String get securityPrivateKeyUnreadable => '无法读取私钥，请检查完整内容、支持格式和解密口令';

  @override
  String get securityNativeStorageUnsupported => '此平台没有原生安全存储';

  @override
  String get securityNativeStorageUnavailable => '原生安全存储不可用或未完成，请检查设备后重试';

  @override
  String get securityDeviceAuthUnsupported => '此平台不支持设备认证，无法显示秘密';

  @override
  String get securityDeviceAuthReason => '验证你的身份以查看已保存的密码';

  @override
  String get securityDeviceAuthIncomplete => '设备认证未完成';

  @override
  String get securityPasswordKind => '用户名与密码';

  @override
  String get securityPrivateKeyKind => 'SSH 密钥';

  @override
  String get securityReloadSaved => '重新读取已保存的资料';

  @override
  String get securityCleanupNotice =>
      '有未完成的安全存储清理。当前连接引用已保留；请在系统安全存储可用后重试。不会删除仍在使用的秘密。';

  @override
  String get securityRetryCleanup => '重试清理未引用秘密';

  @override
  String get securityAddLoginCredential => '新增登录凭据';

  @override
  String get securityImportKey => '导入 SSH 密钥';

  @override
  String get securityImportKeySubtitle => '系统文件选择器或粘贴 · 校验格式与口令';

  @override
  String get securitySaveUsernamePassword => '保存用户名与密码';

  @override
  String get securityReusableCredential => '可供多台服务器引用';

  @override
  String get securityTitle => '密钥与安全';

  @override
  String get securityAddCredential => '新增凭据';

  @override
  String get securityCredentialStorageNotice => '秘密仅保存在系统安全存储中，服务器只引用凭据。';

  @override
  String get securitySearchCredentials => '搜索名称、默认用户名';

  @override
  String get securityAll => '全部';

  @override
  String securityCredentialCount(int count) {
    return '已保存的登录凭据 · $count 条';
  }

  @override
  String get securityNoMatchingCredentials => '没有匹配的凭据。可切换筛选或新增。';

  @override
  String securityLinkedServerCount(int count) {
    return '$count 台关联';
  }

  @override
  String get securityDeviceConnectionSecurity => '设备与连接安全';

  @override
  String get securityTrustedHosts => '已信任的主机';

  @override
  String get securityTrustedHostsSubtitle => '主机、端口、算法与完整主机公钥';

  @override
  String get securityCredentialProtection => '凭据保护';

  @override
  String get securityCredentialProtectionSubtitle => '设备验证、短时显示与平台限制';

  @override
  String get securityCredentialProtectionDetail =>
      '密码、私钥和密钥口令保存在本机的安全存储中（iOS 上为钥匙串），不进入台账数据库、导出或日志。查看已保存的密码需通过设备验证（Face ID、Touch ID 或锁屏密码），20 秒后或离开页面即隐藏。\n\n设备验证只控制应用是否显示已保存的密码，不代表每个秘密被生物识别硬件单独加密；连接时会直接使用已保存的凭据，不再询问。应用运行期间，秘密可能在内存中短暂停留。当前不提供秘密复制或导出。';

  @override
  String get securityLocalCredentialNotice =>
      '只修改本机凭据，不会改动服务器端密码或 authorized_keys。';

  @override
  String get securityViewDetails => '查看详情';

  @override
  String get securityPrivateKeyDetailsSubtitle => '公钥指纹与元数据，不显示私钥';

  @override
  String get securityPasswordDetailsSubtitle => '默认隐藏密码，查看需设备验证';

  @override
  String get securityEditCredential => '编辑凭据';

  @override
  String get securityKeepSecret => '留空保留已保存的秘密';

  @override
  String get securityLinkedServers => '关联服务器';

  @override
  String get securityIndependentUsernames => '连接用户名独立保存';

  @override
  String get securityDeleteCredential => '删除凭据';

  @override
  String get securityReviewDeleteImpact => '先确认替换或解除关联影响';

  @override
  String get securityDiscardCredentialTitle => '放弃本次编辑？';

  @override
  String get securityDiscardCredentialMessage => '尚未保存的凭据内容会被清除。';

  @override
  String get securityDiscardChanges => '放弃修改';

  @override
  String get securityKeyImported => '已导入待保存的私钥；保存时校验格式与口令';

  @override
  String get securityKeyFileReadFailed =>
      '无法读取私钥文件。请选择不超过 128 KB 的 UTF-8 私钥文件。';

  @override
  String get securityKeyPasted => '已粘贴待保存的私钥；内容保持隐藏，保存时校验';

  @override
  String get securityKeyPasteFailed => '无法粘贴私钥。请复制不超过 128 KB 的完整私钥内容。';

  @override
  String get securityCredentialSaved => '凭据已保存，远端认证资料未改变';

  @override
  String get securityCancelCredentialEdit => '取消编辑凭据';

  @override
  String get securityCredentialName => '凭据名称';

  @override
  String get securityCredentialNameRequired => '请填写凭据名称';

  @override
  String get securityDefaultLoginUsername => '默认登录用户名';

  @override
  String get securityOptionalDefaultUsername => '默认用户名（可选）';

  @override
  String get securityDefaultUsernameRequired => '请填写默认用户名';

  @override
  String get securityChoosingFile => '选择文件中…';

  @override
  String get securityChoosePrivateKeyFile => '选择私钥文件';

  @override
  String get securityPasteCompleteKey => '粘贴完整私钥';

  @override
  String get securityPrivateKeyImportNotice =>
      '支持 OpenSSH / PEM 私钥；不保存文件路径，内容始终隐藏。';

  @override
  String get securityLoginPassword => '登录密码';

  @override
  String get securityPrivateKeyContent => '私钥内容';

  @override
  String get securityKeepSecretHidden => '留空保留已保存内容，旧秘密不会回显';

  @override
  String get securityLoginPasswordRequired => '请填写登录密码';

  @override
  String get securityPrivateKeyRequired => '请选择私钥文件或粘贴完整私钥';

  @override
  String get securityPrivateKeyPassphrase => '私钥加密口令（如有）';

  @override
  String get securityPrivateKeyPassphraseHelp => '用于解密私钥，不是登录密码。';

  @override
  String get securityStoreKeyPassphrase => '在设备安全存储中保存私钥口令';

  @override
  String get securityStoreKeyPassphraseHelp =>
      '默认不保存。加密私钥未保存口令时，每次连接都需输入。取消或口令错误会停止连接。仅在导入私钥时应用此选项。';

  @override
  String get securityCredentialEditNotice =>
      '用户名仅作新连接的候选值。更新凭据只影响以后登录，不修改服务器端；退到后台会清空未保存内容。';

  @override
  String get securityCurrentLinkImpact => '当前关联影响';

  @override
  String get securityServerFallback => '服务器';

  @override
  String get securitySaving => '保存中…';

  @override
  String get securitySaveCredential => '保存凭据';

  @override
  String get securityCredentialDetails => '凭据详情';

  @override
  String get securityCredentialDeleted => '凭据已删除';

  @override
  String securityCredentialDefaultUsername(String kind, String username) {
    return '$kind\n默认用户名：$username';
  }

  @override
  String get securityUsernamePerConnection => '由连接单独指定';

  @override
  String get securityPublicKeyFingerprint => '公钥指纹';

  @override
  String get securityPublicKeyFingerprintNotice =>
      '公钥指纹用于辨认登录密钥，不同于服务器主机指纹；这里不展示私钥。';

  @override
  String get securityFingerprintCopied => '公钥指纹已复制';

  @override
  String get securityCopyFailed => '复制未完成，请重试';

  @override
  String get securityCopyFingerprint => '复制公钥指纹';

  @override
  String get securityProtectedPassword => '受保护的密码';

  @override
  String get securityPasswordRevealNotice => '20 秒后隐藏；离开页面或转入后台立即隐藏。';

  @override
  String get securityPasswordHiddenNotice => '验证成功后仅短时显示。设备验证不可用时保持隐藏。';

  @override
  String get securityHidePassword => '隐藏密码';

  @override
  String get securityVerifyViewPassword => '设备验证后查看密码';

  @override
  String get securityCancelVerifyHide => '取消验证并隐藏';

  @override
  String securityCredentialReferenceCount(int count) {
    return '$count 台服务器引用此凭据（含已归档）。';
  }

  @override
  String get securityNoCredentialReferences => '尚未关联。可在服务器详情的 SSH 配置中选择。';

  @override
  String securityCredentialDeleteImpact(int count) {
    return '$count 台服务器将受影响（含已归档）。';
  }

  @override
  String get securityManageLinks => '如何处理关联';

  @override
  String get securityReplaceOrUnlink => '替换或解除';

  @override
  String get securityUnlinkAll => '解除所有关联';

  @override
  String securityReplaceWith(String name) {
    return '替换为 $name';
  }

  @override
  String get securityUnlinkCredentialNotice => '解除后服务器、用户名和付款保留，下次连接需重新选择凭据。';

  @override
  String get securityReplaceCredentialNotice => '仅替换凭据引用，所有服务器当前用户名保持不变。';

  @override
  String get securityDeleteLocalCredentialNotice => '仅删除本机凭据，无法恢复；不影响服务器端或云服务。';

  @override
  String get securityConfirmCredentialImpact => '我已确认关联影响，删除本地凭据';

  @override
  String get securityLocalCredentialDeleted => '本地凭据已删除，远端认证资料未改变';

  @override
  String get securityConfirmDelete => '确认删除';

  @override
  String get securityVerifyHostKey => '核验主机公钥';

  @override
  String get securityHostTrustNotice => '信任绑定主机地址、端口和完整公钥，与登录凭据无关。';

  @override
  String get securityNoTrustedHosts =>
      '尚无已信任主机。可在此录入从厂商控制台或管理员等独立可信渠道取得的公钥，也可在首次 SSH 连接时核对。此页面不会连接服务器。';

  @override
  String securityHostVerifiedAt(String algorithm, String date) {
    return '$algorithm\n核验于 $date';
  }

  @override
  String get securityCompleteHostKey => '完整主机公钥';

  @override
  String get securityReverifyHost => '重新核实主机';

  @override
  String get securityRemoveHostTrustTitle => '移除主机信任？';

  @override
  String securityRemoveHostTrustMessage(
    String host,
    int port,
    String fingerprint,
  ) {
    return '$host:$port\n$fingerprint\n\n下次连接必须重新核验身份。不会删除服务器或登录凭据。';
  }

  @override
  String get securityRemoveHostTrust => '移除信任';

  @override
  String get securityHostChangedNotice =>
      '若主机密钥变化，必须停止认证并通过独立渠道重新核实。没有“忽略并连接”入口。';

  @override
  String get securityHostTrustReadFailed => '无法读取主机信任资料，请重试';

  @override
  String get securityHostTrustInputNotice =>
      '请输入从厂商控制台等独立可信渠道取得的主机公钥。本页只保存本机信任，不连接服务器。';

  @override
  String get securityHostAddress => '主机地址';

  @override
  String get securityPort => '端口';

  @override
  String get securityHostKeyType => '主机公钥类型';

  @override
  String get securityHostKeyHelp => '公钥行或完整 Base64；不是私钥，也不只是指纹';

  @override
  String get securityRsaHostKeyNotice =>
      'rsa-sha2-256 / 512 是签名算法，公钥类型请选 ssh-rsa。';

  @override
  String get r2CopyInfoRsaKey => '关于 RSA 主机公钥';

  @override
  String get securityChecking => '校验中…';

  @override
  String get securityCheckFingerprint => '检查并核对指纹';

  @override
  String get securityHostKeyMismatch => '主机公钥与记录不一致';

  @override
  String get securityFirstHostVerification => '首次主机核验';

  @override
  String get securityHostMismatchBadge => '公钥不一致 · 请独立重新核实';

  @override
  String get securityHostVerifyBeforeSave => '请先核实主机身份，再保存信任';

  @override
  String get securitySavedHostFingerprint => '已保存的主机指纹';

  @override
  String get securityCandidateHostFingerprint => '待核验的主机指纹';

  @override
  String get securityHostVerificationWarning =>
      '请通过独立渠道核对指纹和地址。变化可能是重装，也可能是中间人攻击；无法确认请拒绝。';

  @override
  String get securityBeginHostReverification => '开始独立重新核实';

  @override
  String get securityConfirmHostVerified => '我已通过独立渠道核对主机、端口和完整指纹';

  @override
  String get securityHostTrustSaved => '主机信任已保存；没有发起连接或认证';

  @override
  String get securityReverifyReplaceTrust => '重新核实并替换信任';

  @override
  String get securitySaveVerifiedHostTrust => '保存已核验的主机信任';

  @override
  String get securityRejectBack => '拒绝并返回';

  @override
  String get uiSecurityVerified => '已核验';

  @override
  String get uiSecurityUnverified => '未核验';

  @override
  String get uiSecurityKeyChanged => '公钥已变化';

  @override
  String get securitySavingHostTrust => '正在保存已确认的信任。完成前暂时不能返回。';

  @override
  String get securityLocalHostTrustOnly => '只记录本机信任；拒绝、取消或返回均不保存。';

  @override
  String get securityDiscardSshTitle => '放弃连接配置？';

  @override
  String get securityDiscardSshMessage => '未保存的地址、用户名与凭据选择不会生效。';

  @override
  String get securityChooseCredential => '选择登录凭据';

  @override
  String get securityUnlinkCurrentCredential => '解除当前凭据关联';

  @override
  String get securityChooseCredentialLater => '保留连接配置，之后再选择';

  @override
  String securityCredentialChoiceSubtitle(String kind, String username) {
    return '$kind · 默认 $username';
  }

  @override
  String get securityNotSet => '未设置';

  @override
  String get securityNoCredentialsToChoose => '尚无凭据。先返回，使用“管理凭据”新增。';

  @override
  String get securityAdoptUsernameTitle => '使用凭据的默认用户名？';

  @override
  String securityAdoptUsernameMessage(String current, String suggested) {
    return '当前连接用户名：$current\n凭据默认用户名：$suggested\n\n只影响本台连接；取消将保留当前用户名。';
  }

  @override
  String get securityNotEntered => '未填写';

  @override
  String get securityAdoptUsername => '采用默认用户名';

  @override
  String get securitySshConfigurationSaved => 'SSH 配置已保存，未建立网络连接';

  @override
  String get securitySshConfiguration => 'SSH 连接配置';

  @override
  String get securitySshConfigurationNotice => '连接配置和台账地址分别保存。不会修改云主机设置。';

  @override
  String get securityHostHint => 'IPv4 / IPv6 / 域名，不含协议';

  @override
  String get securityHostRequired => '请填写主机地址';

  @override
  String get securityPortRequired => '端口应为 1–65535';

  @override
  String get securityConnectionUsername => '当前连接用户名';

  @override
  String get securityConnectionUsernameRequired => '请填写登录用户名，或使用凭据的默认用户名';

  @override
  String get securityLoginCredential => '登录凭据';

  @override
  String get securityManageCredentials => '管理凭据';

  @override
  String get securityCredentialNotConfigured => '凭据待配置';

  @override
  String get securityCredentialRequiredBeforeConnect => '可先保存配置，连接前必须选择凭据';

  @override
  String securityChangeCredentialSubtitle(String kind) {
    return '$kind · 点击更换或解除';
  }

  @override
  String get securityConnectionUsernameNotice =>
      '用户名属于本台连接。换凭据时只有明确选择“采用默认用户名”才更改它，取消和相同用户名都不会修改其他连接。';

  @override
  String get securityConfigurationOnlyNotice => '仅保存连接配置。连接时先核验主机公钥，公钥变化会暂停认证。';

  @override
  String get securitySaveSshConfiguration => '保存 SSH 配置';

  @override
  String get securityOpenKeyFile => '导入';

  @override
  String get securityAuthCancel => '取消';

  @override
  String get securityAuthSignInTitle => '身份验证';

  @override
  String get securityAuthBiometricHint => '验证身份';

  @override
  String get providerNameRange => '提供商名称需为 1–80 个字符。';

  @override
  String get providerAlreadyExists => '这个提供商已存在，请直接选择。';

  @override
  String get providerUiTitle => '提供商管理';

  @override
  String get uiCloudProvidersTitle => '提供商';

  @override
  String get providerUiDetails => '提供商详情';

  @override
  String get providerUiAdd => '新增提供商';

  @override
  String get providerUiRename => '重命名提供商';

  @override
  String get providerUiName => '提供商名称';

  @override
  String get providerUiUnspecified => '未指定提供商';

  @override
  String get providerUiHierarchyHelp => '提供商是服务器的业务归属。可以从目录里添加，也可以自己新建。';

  @override
  String r6CatProviderSummary(int count) {
    return '$count 台服务器';
  }

  @override
  String get r6CatCatalogSection => '目录';

  @override
  String get r6CatMineSection => '我的提供商';

  @override
  String get r8ProvidersInUse => '使用中的提供商';

  @override
  String get r8NoProvidersInUse => '还没有提供商关联服务器。';

  @override
  String get r8AllProviders => '全部提供商';

  @override
  String get r8SearchProviders => '搜索提供商';

  @override
  String get r8NoMatches => '没有匹配的结果。';

  @override
  String get r8BadgeCatalog => '目录';

  @override
  String get r8BadgeCustom => '自建';

  @override
  String get r8SectionInUse => '使用中';

  @override
  String r8NewProviderNamed(String name) {
    return '新建提供商“$name”';
  }

  @override
  String get r8PickProvider => '选择提供商';

  @override
  String get r6CatCatalogFooter => '目录里的提供商可以直接添加；没有找到时，可以新建自己的提供商。';

  @override
  String get r6CatServerSection => '提供商';

  @override
  String get r6CatServerFooter => '服务器保留自己的硬件与费用。如需更换提供商，请编辑服务器。';

  @override
  String get r6CatCatalogProviderHelp => '尚未添加。添加后即可把服务器关联到它。';

  @override
  String get r6CatBackupProviders => '提供商';

  @override
  String r6CatBackupProviderCount(int count) {
    return '提供商：$count';
  }

  @override
  String get providerUiEmpty => '还没有提供商';

  @override
  String providerUiUnspecifiedCount(int count) {
    return '$count 台服务器尚未指定提供商。';
  }

  @override
  String get providerUiDevices => '名下服务器';

  @override
  String get providerUiUnavailable => '此提供商已变更或不可用，请返回重新选择。';

  @override
  String get providerUiOpenProvider => '查看提供商';

  @override
  String get r9DirSection => '提供商目录';

  @override
  String get r9DirNone => '尚未下载';

  @override
  String r9DirSummary(int version, int count) {
    return '版本 $version · $count 个提供商';
  }

  @override
  String get r9DirUpToDate => '已是最新';

  @override
  String get r9DirUpdated => '已更新';

  @override
  String get r9DirUnreachable => '无法连接 GitHub';

  @override
  String r9DirChecked(String when) {
    return '检查于 $when';
  }

  @override
  String get r9DirNeverChecked => '尚未检查';

  @override
  String get r9DirCheck => '检查更新';

  @override
  String get r9DirAuto => '启动时更新';

  @override
  String get r9DirAutoFooter => '只下载公开的提供商列表；你的台账不会离开设备。';

  @override
  String get r9TimeJustNow => '刚刚';

  @override
  String r9TimeMinutesAgo(int count) {
    return '$count 分钟前';
  }

  @override
  String r9TimeHoursAgo(int count) {
    return '$count 小时前';
  }

  @override
  String r9TimeDaysAgo(int count) {
    return '$count 天前';
  }

  @override
  String get r9DirEmptyHint => '提供商目录尚未下载。联网后，到“设置 → 提供商”检查更新。';

  @override
  String get r9Website => '官网';

  @override
  String get r9WebsiteCopied => '已复制网址';

  @override
  String get r9ProviderDelete => '删除提供商';

  @override
  String r9ProviderDeleteTitle(String name) {
    return '删除“$name”？';
  }

  @override
  String r9ProviderDeleteMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '将从你的台账中移除这个提供商。它的 $count 台服务器会保留，显示为未指定提供商。',
      zero: '将从你的台账中移除这个提供商。',
    );
    return '$_temp0';
  }

  @override
  String get r11AboutWhatsNew => '更新记录';

  @override
  String get r11AboutSourceCode => '源代码';

  @override
  String get r11AboutLicense => '许可证';

  @override
  String get r11AboutOpenSource => '开源组件';

  @override
  String get r11AboutRepoCopied => '已复制源代码地址';

  @override
  String get r11AboutFootnote =>
      '免费开源：无广告、无内购、无需账号。台账只保存在本机；应用会下载公开的提供商目录，只有在你发起 SSH、SFTP 或 TCP 连接时才会联网连接到你指定的地址。';

  @override
  String get r11AboutTrademark => '提供商的名称和 Logo 归各自所有者所有，仅用于识别。';

  @override
  String get r11ChangelogUnavailable => '无法读取更新记录。';

  @override
  String get r11LicenseUnavailable => '无法读取许可证文本。';

  @override
  String get r11OssBuiltWith => '构建于';

  @override
  String get r11OssBuiltWithFootnote => '点按组件查看许可证全文。';

  @override
  String get r11OssAllLicensesTitle => '全部许可证';

  @override
  String r11OssAllLicenses(String n) {
    return '全部许可证（$n）';
  }

  @override
  String get r11OssSearch => '搜索组件';

  @override
  String get r11OssNoMatch => '没有匹配的组件。';

  @override
  String get r11OssLicenseMissing => '没有找到这个组件的许可证文本，请在“全部许可证”中查看。';

  @override
  String get r11OssLoadFailed => '无法读取许可证列表。';

  @override
  String get r11OssAboutFlutter => '跨平台界面框架';

  @override
  String get r11OssAboutLocalizations => '系统控件的本地化文字';

  @override
  String get r11OssAboutIntl => '日期、数字和消息格式化';

  @override
  String get r11OssAboutSqflite => '本地 SQLite 数据库';

  @override
  String get r11OssAboutSqfliteFfi => '桌面端和测试用的 SQLite';

  @override
  String get r11OssAboutPath => '文件路径处理';

  @override
  String get r11OssAboutPathProvider => '查找应用的存储目录';

  @override
  String get r11OssAboutSecureStorage => '钥匙串 / Keystore 安全存储';

  @override
  String get r11OssAboutLocalAuth => 'Face ID、指纹和设备密码验证';

  @override
  String get r11OssAboutDartssh2 => 'SSH 与 SFTP 客户端';

  @override
  String get r11OssAboutXterm => '终端界面';

  @override
  String get r11OssAboutCrypto => '哈希与摘要';

  @override
  String get r11OssAboutFileSelector => '系统文件选择与保存';

  @override
  String get r11OssAboutTimezone => '时区数据库';

  @override
  String get r11OssAboutFlutterTimezone => '读取设备时区';

  @override
  String get r11OssAboutSharePlus => '系统分享面板';

  @override
  String get r11OssAboutHttp => '下载提供商目录';

  @override
  String get r11OssAboutXml => '解析 XML';

  @override
  String get r11OssAboutLocalNotifications => '到期提醒的本地通知';

  @override
  String get r11OssAboutDejaVu => '终端等宽字体';

  @override
  String r13BackgroundSshEnded(String p0) {
    return '应用在后台停留过久，与 $p0 的 SSH 会话已结束';
  }

  @override
  String r13BackgroundSftpEnded(String p0) {
    return '应用在后台停留过久，与 $p0 的 SFTP 会话已结束';
  }

  @override
  String get r13ProxyUnreachable => '无法连接代理服务器';

  @override
  String get r13ProxyTlsFailed => '无法验证代理的 TLS 证书，或 TLS 握手失败';

  @override
  String get r13ProxyTimeout => '通过代理连接超时';

  @override
  String get r13ProxyClosed => '代理服务器中途关闭了连接';

  @override
  String get r13ProxyProtocol => '代理返回了无法识别的响应';

  @override
  String get r13ProxyAuthRequired => '代理要求用户名和密码';

  @override
  String get r13ProxyAuthRejected => '代理拒绝了用户名或密码';

  @override
  String get r13ProxyInvalidTarget => '该目标地址无法通过代理连接';

  @override
  String get r13ProxyInvalidSettings => '代理设置无效';

  @override
  String get r13ProxySocksGeneral => 'SOCKS5 代理报告一般性失败';

  @override
  String get r13ProxySocksNotAllowed => '代理规则不允许连接该目标';

  @override
  String get r13ProxySocksNetwork => '代理无法到达目标所在网络';

  @override
  String get r13ProxySocksHost => '代理无法到达目标主机';

  @override
  String get r13ProxySocksRefused => '目标拒绝了来自代理的连接';

  @override
  String get r13ProxySocksTtl => '代理连接目标时 TTL 已过期';

  @override
  String get r13ProxySocksCommand => '代理不支持 CONNECT 命令';

  @override
  String get r13ProxySocksAddress => '代理不支持该类型的目标地址';

  @override
  String r13ProxyHttpStatus(int code) {
    return '代理拒绝了 CONNECT 请求（HTTP $code）';
  }

  @override
  String get r13ProxyInvalid => '请填写名称，以及有效的代理主机和端口';

  @override
  String get r13ProxyInUse => '仍有 SSH 配置在使用此代理。请先改用其他代理或直连。';

  @override
  String get r13ProxyPasswordRequired => '设置用户名时必须填写代理密码';

  @override
  String get r13ProxyUsernameRequired => '填写密码前请先填写用户名';

  @override
  String get r13ProxyCredentialInvalid =>
      '用户名和密码需为 1–255 字节且不含控制字符；HTTP/HTTPS 代理的用户名不能含冒号。';

  @override
  String get r13ProxyMissing => '所选代理已不存在，请重新选择';

  @override
  String get r13ProxyPasswordMissing => '未找到已保存的代理密码，请重新输入';

  @override
  String get r13ProxyChanged => '代理在连接前被修改，请重试';

  @override
  String get r13ProxyReadFailed => '无法读取代理设置';

  @override
  String get r13ProxiesTitle => '代理';

  @override
  String get r13ProxiesSubtitle => 'SOCKS5、HTTP、HTTPS';

  @override
  String r13ProxyCount(int count) {
    return '已保存的代理 · $count';
  }

  @override
  String get r13ProxyListFooter =>
      '代理只用于您主动发起的 SSH、SFTP 和 TCP 测试，不是系统代理。SOCKS5 由代理解析目标域名（远程 DNS）；HTTP/HTTPS 通过 CONNECT 向代理发送“主机:端口”。密码只保存在设备安全存储中，不会导出或备份。';

  @override
  String get r13ProxyEmpty => '还没有代理';

  @override
  String get r13ProxyAdd => '添加代理';

  @override
  String get r13ProxyEdit => '编辑代理';

  @override
  String get r13ProxyName => '名称';

  @override
  String get r13ProxyNameHint => '例如：办公室出口';

  @override
  String get r13ProxyType => '类型';

  @override
  String get r13ProxyHost => '主机';

  @override
  String get r13ProxyUsername => '用户名（可选）';

  @override
  String get r13ProxyPassword => '密码';

  @override
  String get r13ProxyKeepPassword => '留空则保留已保存的密码。清空用户名会同时删除已保存的密码。';

  @override
  String get r13ProxyNameRequired => '请填写名称';

  @override
  String get r13ProxySave => '保存代理';

  @override
  String get r13ProxySaved => '代理已保存';

  @override
  String get r13ProxyDelete => '删除代理';

  @override
  String get r13ProxyDeleteTitle => '删除此代理？';

  @override
  String get r13ProxyDeleteMessage => '代理及其已保存的密码将被删除。';

  @override
  String get r13ProxyDeleted => '代理已删除';

  @override
  String r13ProxyDeleteBlocked(int count) {
    return '$count 台服务器的 SSH 配置正在使用此代理。请先改用其他代理或直连，才能删除。';
  }

  @override
  String get r13ProxyDiscardTitle => '放弃代理修改？';

  @override
  String get r13ProxyDiscardMessage => '未保存的内容将丢失。';

  @override
  String get r13ProxyShowPassword => '设备验证后查看已保存的密码';

  @override
  String get r13ProxyDirect => '直连';

  @override
  String get r13ProxyDirectSubtitle => '不使用代理';

  @override
  String get r13ProxyNew => '新建代理…';

  @override
  String get r13ProxyChoose => '选择代理';

  @override
  String get r13ProxyRow => '代理';

  @override
  String get r13ProxyRowFooter =>
      '终端和 SFTP 共用同一条 SSH 连接，因此都会经过所选代理。主机公钥仍按目标主机和端口核对。';

  @override
  String r13ProxyVia(String name) {
    return '经 $name';
  }

  @override
  String get r13TcpEnterProxy => '输入代理…';

  @override
  String get r13TcpProxyFooter => '临时代理只用于本次测试，不会保存，密码也不会写入存储。';

  @override
  String get r13ProxyTemporaryTitle => '临时代理';

  @override
  String get r13ProxyUse => '使用此代理';

  @override
  String get r13TcpRoute => '路径';

  @override
  String r13TcpRouteVia(String name) {
    return '经代理 $name';
  }

  @override
  String get r13TcpProxyAddress => '代理地址';

  @override
  String get r13TcpProxyReason => '原因';

  @override
  String get r13TcpProxiedNote => '代理已连接到目标。这只说明代理能到达目标，不说明本机能直接到达。';

  @override
  String get r13TcpSourceProxy => '本机经代理发起的 TCP 连接测试';

  @override
  String get r14ServerDuplicate => '复制';

  @override
  String r14ServerCopyName(String name) {
    return '$name 副本';
  }

  @override
  String get r14ErrorDetails => '错误详情';

  @override
  String get r15Details => '详情';

  @override
  String r17ChangelogCount(int count) {
    return '$count 项更新';
  }

  @override
  String get r17CurrentVersion => '当前版本';

  @override
  String get r17GithubRelease => 'GitHub 发布';

  @override
  String get r17ReleaseLinkCopied => '已复制发布页链接';

  @override
  String get r17ChangelogFooter => '每个版本的内容与 GitHub 上同名标签的发布说明一致。';

  @override
  String get r17SessionExited => '已退出 SSH 会话';

  @override
  String r17SessionExitedStatus(int status) {
    return '已退出 SSH 会话（退出码 $status）';
  }

  @override
  String get r14ErrorStage => '失败环节';

  @override
  String get r14ErrorTarget => '目标';

  @override
  String get r14ErrorProxy => '代理';

  @override
  String get r14ErrorTime => '时间';

  @override
  String get r14ErrorTechnical => '技术详情';

  @override
  String get r14ErrorFootnote =>
      '已移除密码、口令、私钥和代理凭据。这些内容只保存在内存中，不会写入数据库、日志或导出文件。';

  @override
  String get r14ErrorCopy => '复制详情';

  @override
  String get r14ErrorCopied => '已复制';

  @override
  String get r14StageSetup => '准备连接（读取凭据 / 检查目标）';

  @override
  String get r14StageConnect => 'DNS 解析 / TCP 连接';

  @override
  String get r14StageProxy => '代理';

  @override
  String get r14StageProxyTls => '与代理的 TLS 握手';

  @override
  String get r14StageHandshake => 'SSH 握手';

  @override
  String get r14StageHostKey => '主机公钥校验';

  @override
  String get r14StageAuthentication => '身份验证';

  @override
  String get r14StageShell => '打开终端通道';

  @override
  String get r14StageSftp => 'SFTP 子系统';

  @override
  String get r14StageSession => '会话进行中';

  @override
  String get r18PrivacyPolicy => '隐私政策';

  @override
  String get r18AboutSupport => '支持';

  @override
  String get r18SupportLinkCopied => '已复制支持页地址';

  @override
  String get r18PrivacyCopyLink => '复制公开链接';

  @override
  String get r18PrivacyLinkCopied => '已复制隐私政策地址';

  @override
  String get r18PrivacyUnavailable => '无法加载隐私政策。';

  @override
  String get r18PrivacyPublicFooter => '同样的内容也公开发布在上面的地址。';
}
