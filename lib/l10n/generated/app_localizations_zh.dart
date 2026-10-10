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
  String get languageDescription => '立即切换界面语言，保留当前草稿和连接。';

  @override
  String get languageSystem => '跟随系统';

  @override
  String get languageSystemDescription => '支持简体中文和 English；其他系统语言使用 English。';

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
  String get toolsDescription => '计算费用、连接服务器或管理常用命令。';

  @override
  String get remainingValueCalculator => '剩余价值计算器';

  @override
  String get calculatorDescription => '独立试算或引用服务器资料 · 可导出图片';

  @override
  String get connectionsTroubleshooting => '连接与排障';

  @override
  String get sshQuickConnect => 'SSH 快速连接';

  @override
  String get sshQuickConnectDescription => '选择服务器或临时目标 · 核验主机后登录';

  @override
  String get tcpConnectionTest => 'TCP 连接测试';

  @override
  String get tcpConnectionDescription => '从当前设备检查单个地址和端口';

  @override
  String get commandSnippets => '命令片段';

  @override
  String get commandSnippetsDescription => '保存常用命令 · 插入终端草稿后发送';

  @override
  String get singleServerMaintenance => '单机维护';

  @override
  String get powerControl => '电源控制';

  @override
  String get powerControlDescription => '通过 SSH 重启或关机 · 操作前核对目标';

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
  String get reminderEnableHelp =>
      '需同时开启系统通知和服务器提醒。各服务器的提前天数、时间和使用计划可在详情中编辑；未允许通知时仍可保存规则。';

  @override
  String get requestingPermission => '正在申请…';

  @override
  String get requestNotificationPermission => '申请系统通知权限';

  @override
  String get notificationPermissionHelp =>
      '已拒绝或关闭通知渠道时，请到设备系统设置中调整；修改后返回应用，重新核对提醒状态。';

  @override
  String get checkReminderStatus => '重新核对提醒状态';

  @override
  String get reminderCoverage => '提醒范围';

  @override
  String get reminderHorizonHelp =>
      '只提交未来 366 天内已知的到期提醒；过去的提醒时间不补发。iOS 最多排入最近 64 条，Android 最多 256 条，其余显示为未安排。请定期打开应用更新提醒。';

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
  String get reminderSaveHelp =>
      '修改后点“保存提醒规则”生效。若启用提醒并选择“到期不再使用”，仍会提醒核对厂商的续费设置。';

  @override
  String get uiTabsReminderSaveHelp =>
      '修改后点右上角“保存”生效。若启用提醒并选择“到期不再使用”，仍会提醒核对厂商的续费设置。';

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
  String get selectReminderTime => '选择提醒时间';

  @override
  String get cancel => '取消';

  @override
  String get confirm => '确定';

  @override
  String get hour => '时';

  @override
  String get minute => '分';

  @override
  String get invalidTime => '请输入有效时间';

  @override
  String get reminderDstHelp => '随设备当前时区。夏令时缺失时间向后顺延，重复时间仅提醒一次；整天被跳过的日期不排程。';

  @override
  String get myUsagePlan => '我的使用计划';

  @override
  String get usagePlanWarning => '使用计划只是本地记录。计划到期停用不会停止厂商扣费，请另行向厂商确认取消续费。';

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
  String get saveReminderRules => '保存提醒规则';

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
      '读取或校验失败。请选择格式 v1、10 MiB 以内的完整 JSON 台账备份；现有数据未改动。';

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
  String get plainJsonVersion => '明文 JSON · 格式 v1';

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
  String get restoreContentsHelp =>
      '将导入上述台账记录与手动汇率。上方列出的安全资料、备注、提醒和应用偏好均不在备份内。';

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
  String get appDescription => '个人 VPS 台账 · 本地优先';

  @override
  String get organizationData => '组织与数据';

  @override
  String get manageGroups => '分组管理';

  @override
  String groupCountHelp(String p0) {
    return '$p0 个分组 · 删除分组保留记录';
  }

  @override
  String get archivedRecords => '已归档记录';

  @override
  String archiveCountHelp(String p0) {
    return '$p0 条 · 可恢复到服务器列表';
  }

  @override
  String get accountsPreferences => '账户与偏好';

  @override
  String get panelAccounts => '面板账户';

  @override
  String panelConnectionCount(String p0) {
    return '已保存 $p0 个面板连接';
  }

  @override
  String get keysSecurity => '密钥与安全';

  @override
  String get keysSecurityDescription => '凭据、SSH 配置与主机信任';

  @override
  String get currenciesReferenceRates => '币种与参考汇率';

  @override
  String currencyRateSummary(String p0, String p1) {
    return '$p0 · 手动汇率 $p1';
  }

  @override
  String get notSet => '未设置';

  @override
  String get notificationAccess => '通知权限';

  @override
  String get backupExclusionsSummary => '不含凭据与主机信任 · 未加密 JSON';

  @override
  String get about => '关于';

  @override
  String get developmentVersion => '开发测试版 · 0.1.0';

  @override
  String get appLocalDataHelp => '数据保存在当前设备，无需应用账号。\n归档记录不会取消服务器服务或停止扣费。';

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
  String get groupsHelp => '按用途整理服务器。分组变更仅影响本地台账。';

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
  String get archiveHelp => '归档保留服务器资料和 ID。恢复不会连接云主机，也不会启动或续费服务。';

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
  String get financeValuationAndDue => '估值日 / 服务到期日';

  @override
  String get financeRemainingDays => '剩余服务天数';

  @override
  String get financeRenewalCycle => '续费 / 周期';

  @override
  String get financeDailyShown => '所示周期日均';

  @override
  String get financeInferredPeriods => '部分服务起点由到期日与日历周期反推；不代表历史付款证明。';

  @override
  String get financeValueDisclaimer => '仅表示服务时长的价格折算，不是退款承诺或成交价。';

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
  String get financeFxScope => '仅改变参考折算，原币续费价与历史实付保持不变。不会请求实时汇率。留空表示该汇率未知。';

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
  String get financeFxBasis =>
      'CNY 为基准，1 CNY = 1 CNY。同币种换算不需要汇率；跨币种缺汇率时只展示可转换部分及覆盖率。';

  @override
  String get financeSaveFx => '保存参考汇率';

  @override
  String get financeReferenceTitle => '引用服务器资料';

  @override
  String get financeReferenceNote => '只复制此刻的续费资料和已知期间。不会修改原服务器。';

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
  String get financeIndependentRebuilt =>
      '已切换为独立试算：按当前到期日和周期重新推算服务期，假设到期日前服务连续有效。';

  @override
  String get financeIndependentNote => '独立试算，无需添加服务器。假设到期日前服务连续有效。';

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
  String get financeAlgorithmTitle => '周期与算法说明';

  @override
  String get financeAlgorithmNote =>
      '剩余价值 = Σ（每周期续费金额 × 该周期未用天数比例）。\n日历周期按真实天数计算，不固定每月 30 天；月底由原到期日锚点倒推，年度处理闰年。估值早于已知开始日不会超过该期整价。\n独立模式向前倒推至覆盖估值日，限制 100 年。到期当天为 0，不检查服务能否转让或退款。';

  @override
  String get financeCalculateValue => '计算剩余价值';

  @override
  String get financeEstimateNoWrite => '试算与记账分离，修改输入不会更改任何服务器或付款。';

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
  String get financeQuoteNote =>
      '仅按报价和下方填写的转移手续费试算，不执行交易。其他费用未计入；请自行确认厂商是否允许转让及相关条款。';

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
  String get financeSplitFeeNote =>
      '手续费先折算到显示币种的分，再分摊；不足均分的 0.01 由买方承担。双方手续费之和等于总手续费。';

  @override
  String get financeCalculateQuote => '计算报价与费用';

  @override
  String get financePremiumLabel => '报价与参考价值差额（溢价 / 折价）';

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
  String get financeNoRenewalDate => '当前记录没有可用的续期日期。请核对预付类型、到期日与支持的日期范围。';

  @override
  String get financeRecordAccountBill => '记录账户账单';

  @override
  String get financeLocalPaymentOnly => '仅本地记账，不向厂商发起支付。';

  @override
  String get financeAccountBillNote =>
      '独立记录整份账户账单，仅计一次。不要求连接面板账户，不分摊到实例，也不产生服务期或剩余价值。';

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
  String get financePaymentRenewalNote =>
      '本次实付独立保存，不覆盖续费金额。目前仅支持整周期续费；厂商含赠送期或到期日不同的，请先核对，不要填写虚构周期。';

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
  String get financeRecent30 => '近 30 天';

  @override
  String get financeShowVoided => '显示已撤销';

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
  String get financeVoidTitle => '撤销此次本地记录？';

  @override
  String get financeVoidAccountNote => '将此账单标记为已撤销，不向厂商申请退款。';

  @override
  String get financeVoidServerNote =>
      '仅还原本次增加的服务期间与到期日，并将实付标记为已撤销。不会向厂商退款或取消服务。';

  @override
  String get financeVoidRecord => '撤销记录';

  @override
  String get financePaymentVoided => '本次本地付款记录已撤销';

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
  String get financeVoidedStatus => '已撤销，不计入实付统计';

  @override
  String get financeRecordedStatus => '已记录';

  @override
  String get financePaymentHistoryNote =>
      '这是原币历史实付，不随续费价或参考汇率重写。如需更正，可撤销后重新录入；后续资料已改变时可能无法撤销。';

  @override
  String get financeVoidThisRecord => '撤销此次记录';

  @override
  String get financeVoidBlocked => '资料已改变，请核对。后续编辑、付款或归档后不能用旧记录覆盖现有资料。';

  @override
  String get financeRulesTitle => '这些数字如何计算';

  @override
  String get financeTitle => '费用';

  @override
  String get financeOverview => '查看月费用参考、剩余价值和已记录付款。';

  @override
  String get financeScope => '统计范围';

  @override
  String get financeMonthlyReference => '月费用参考';

  @override
  String get financeTotalRemaining => '总体剩余价值  ›';

  @override
  String get financeMonthlyNotPaid => '预付续费价摊月 + 按量月估算，不等于本月实付';

  @override
  String get financeUpcomingRenewals => '未来 30 天预计续费';

  @override
  String get financeRecentPayments => '近 30 天已记录实付';

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
  String get financeDistributionNote => '点击分布查看同一口径的服务器明细。费用资料与续费记录均从服务器详情维护。';

  @override
  String get financeGroupDistributionNote => '当前分组不分摊账户级实付。点击分布查看明细。';

  @override
  String get financeSixMonthTitle => '本月起六个月 · 预付续费';

  @override
  String get financeForecastNote =>
      '按当前续费价和周期预测本月剩余日期及后五个自然月。假设继续续费，使用计划不改变预测；不包含按量账单或已过期项目。';

  @override
  String get financeMonthlyDetail => '月费用明细';

  @override
  String get financeValueDetail => '剩余价值明细';

  @override
  String get financeInventoryDetail => '服务器构成';

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
  String get financeUnknownZeroNote => '“—”表示未知或不适用，不代表免费。已知金额为 0 时会显示 0.00。';

  @override
  String get financeRenewals30Title => '未来 30 天续费安排';

  @override
  String get financeNoKnownRenewals => '此范围没有已知的预付续费。';

  @override
  String get financeExpiredCheck => '已过期 · 先核实';

  @override
  String get financeMeteredRenewalNote => '按量费用在服务器资料中维护月估算，不产生预付续费事件。';

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
  String get financePngPrivacy => '仅含金额、日期、周期和参考汇率。图片不含服务器名称、地址、账户、备注或转让报价试算。';

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
  String get financePngLocationNote =>
      '保存位置可能是应用私有目录，不等于相册或公开下载目录。移动端可使用系统分享另存；取消分享不会关闭预览。';

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
    return '剩余价值含 $count 个尚未开始的周期；进度条仅显示上述周期。';
  }

  @override
  String financeReferenceServerSubtitle(String billing, String due) {
    return '$billing · 至 $due';
  }

  @override
  String financeReferenceBasis(String name) {
    return '引用 $name 的已知期间。修改估值日、金额或币种不会改变已知服务期，也不会修改原服务器。';
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
  String financeRoundingNote(String rate, String source) {
    return '$rate\n$source。先精确计算，再四舍五入到分；折算结果仅供参考。';
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
    return '从原到期日 $date 延长，保留当前未用时长。按原续费日推算，并保留月底日期规则。';
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
    return '$count 笔有效记录，不代表完整历史账单。已撤销记录不计入。';
  }

  @override
  String financePaymentGroupNote(String group) {
    return '当前分组：$group。不分摊账户账单；历史记录保留归档付款。';
  }

  @override
  String financeVoidedName(String name, String voided) {
    String _temp0 = intl.Intl.selectLogic(voided, {
      'yes': '$name · 已撤销',
      'other': '$name',
    });
    return '$_temp0';
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
  String financeManagedCount(int count) {
    return '在管服务器：$count 台  ›';
  }

  @override
  String financeRenewalEventNote(int count) {
    return '$count 笔预付续费 · 今天及后 29 天';
  }

  @override
  String financeRecentPaymentNote(int count) {
    return '$count 笔 · 今天及前 29 天';
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
  String uiFinanceServerCount(int count) {
    return '$count 台';
  }

  @override
  String get uiFinanceFootnote => '金额按当前续费价和手动参考汇率折算，仅供参考，不代表厂商实际账单。';

  @override
  String get uiFinanceVoidedPill => '已撤销';

  @override
  String get uiFinanceArchivedPill => '已归档';

  @override
  String get uiFinanceAccountPill => '账户账单';

  @override
  String financeForecastMonth(int year, int month, int count) {
    return '$year 年 $month 月 · $count 笔';
  }

  @override
  String financeForecastTotal(
    String amount,
    String currency,
    int missing,
    int unknown,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      missing,
      locale: localeName,
      other: ' · 缺汇率 $missing 项',
      zero: '',
    );
    String _temp1 = intl.Intl.pluralLogic(
      unknown,
      locale: localeName,
      other: ' · 金额未知 $unknown 项',
      zero: '',
    );
    return '$amount $currency$_temp0$_temp1';
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
  String get financeExportHeading => 'vps tell you · 试算 · 不入账';

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
  String financeExportDue(String date) {
    return '服务到期日：$date';
  }

  @override
  String financeExportRemainingDays(int days) {
    return '剩余服务天数：$days 天';
  }

  @override
  String financeExportRenewal(String renewal) {
    return '续费 / 周期：$renewal';
  }

  @override
  String financeExportDaily(String daily) {
    return '所示周期日均：$daily';
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
  String get backupExcludedConnections => 'SSH 配置、主机信任、面板账户、实例关联与 API 返回信息';

  @override
  String get backupExcludedNotes => '命令片段、服务器备注和付款备注';

  @override
  String get backupExcludedPreferences => '提醒规则、通知排程及应用偏好（格式 v1）';

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
  String get invalidServerName => '服务器名称需为 1–80 个字符';

  @override
  String get completeLocalResources => '请先补全并确认六项本地资源配置';

  @override
  String get securityOperationIncomplete => '安全操作未完成，请重试';

  @override
  String get cloudAccounts => '适配器实例';

  @override
  String get cloudAddAccount => '添加适配器实例';

  @override
  String get cloudPanelReadBadge => '面板只读接入';

  @override
  String get cloudManageConnections => '管理适配器实例与设备关联';

  @override
  String get cloudConnectionsInfo =>
      '每个适配器实例拥有独立授权与读取范围。\n同一提供商下可添加多个单设备或账户级适配器实例。';

  @override
  String get cloudMetadataIncomplete => '适配器实例资料未能完整载入，请重新载入后继续。';

  @override
  String get cloudReloadMetadata => '重新载入适配器实例资料';

  @override
  String get cloudCleanupNotice => '待清理的旧授权仍可能留在设备安全存储中。请重试清理；远端授权需到面板撤销。';

  @override
  String get cloudRetryCleanup => '重试清理旧授权';

  @override
  String get cloudFirstAccount => '添加首个适配器实例';

  @override
  String get cloudFirstAccountInfo => '选择适配器类型并验证授权，再核对设备与资源，添加到台账。';

  @override
  String get cloudChooseTemplate => '选择适配器类型';

  @override
  String get cloudReadOnlyBoundary =>
      '本 App 仅使用读取能力，不代表 API 凭据本身只有读取权限。\n适配器实例授权与 SSH 凭据分开管理。解除关联保留台账、费用、付款与 SSH。';

  @override
  String get cloudTemplateInfo => '选择与面板匹配的适配器类型。适配器负责读取技术信息，提供商是供应服务器的商家。';

  @override
  String get cloudV1TemplateInfo => 'Client API Key + Hash\n每组凭据只对应单台 VPS';

  @override
  String get cloudV2TemplateInfo => '用户 API Token\n读取当前用户的项目与设备';

  @override
  String get cloudRackNerdTemplateInfo =>
      'ctrl 面板 Client API Key + Hash\n通过兼容客户端接口读取单台 VPS';

  @override
  String get cloudSupportedPanels =>
      '支持 SolusVM 1、SolusVM 2 和 RackNerd ctrl 读取。不提供 API 电源控制，也不会修改远端资源或停止服务商计费。';

  @override
  String get cloudReauthorize => '重新授权';

  @override
  String get cloudSingleVpsApi => '单台 VPS / Client API';

  @override
  String get cloudUserAccountApi => '用户账户 / API Token';

  @override
  String get cloudWebPreviewNotice => 'Web 预览不接受真实 API 凭据，请在原生应用中连接。';

  @override
  String get cloudAliasLabel => '适配器实例名称';

  @override
  String get cloudAliasRequired => '请输入适配器实例名称';

  @override
  String get cloudEndpointLabel => 'HTTPS 面板地址';

  @override
  String get cloudEndpointValidation => '请输入 HTTPS 面板首页地址，不含凭据、参数或 API 路径';

  @override
  String get cloudEndpointInfo => '使用面板首页 HTTPS 地址，可以保留服务商指定端口。不会忽略证书错误或跟随重定向。';

  @override
  String get cloudRackNerdEndpointValidation =>
      '请输入 HTTPS 面板首页地址，或精确的 /api/client/command.php 地址，不含凭据、参数或其他路径';

  @override
  String get cloudRackNerdEndpointInfo =>
      '使用面板首页 HTTPS 地址，可以保留服务商指定端口。仅 RackNerd ctrl 可移除精确的 /api/client/command.php 路径；请核对下方最终地址。不会忽略证书错误或跟随重定向。';

  @override
  String get cloudEndpointIdentityInfo => '面板地址与连接身份绑定。不同面板请另建连接，旧授权不会显示在此处。';

  @override
  String get cloudV1CredentialsInfo =>
      '填写该 VPS 的 Client API Key / Hash。不是管理员 API 凭据或登录密码；需服务商开放 Client API。每组凭据只读取单台 VPS 的状态。';

  @override
  String get cloudRackNerdCredentialsInfo =>
      '填写 RackNerd ctrl 面板中该 VPS 的 Client API Key / Hash，不是登录密码或管理员凭据。此连接仅通过兼容客户端接口读取单台 VPS，不据此认定底层面板产品。';

  @override
  String get cloudV2CredentialsInfo =>
      '使用 SolusVM 2 用户区 Account → API Tokens 的 Token。不要使用管理员 Token；可读取范围取决于服务商设置。';

  @override
  String get cloudV1ReauthorizationInfo =>
      '此 API 无法证明新凭据仍属于原 VPS。验证后，必须明确确认解除旧关联，再决定是否导入新记录。旧台账、费用和 SSH 会保留。';

  @override
  String get cloudV2ReauthorizationInfo => '重新授权必须验证为同一远端用户账户，否则保留原授权与关联。';

  @override
  String get cloudVerifyScopeInfo =>
      '本 App 仅使用读取能力，不代表凭据本身只有读取权限。验证会读取状态或项目与设备；只有下一步保存后，授权才进入设备安全存储。';

  @override
  String get cloudVerifyingInfo => '正在验证并读取完整列表。请求有超时限制；返回或取消会停止本次读取。';

  @override
  String get cloudCancelVerification => '取消验证';

  @override
  String get cloudVerifyRead => '验证并读取';

  @override
  String get cloudCredentialMemoryInfo =>
      '凭据输入在验证后或离开时清空，不写入台账、日志或导出。Dart 不保证内存安全擦除。';

  @override
  String get cloudChooseInstances => '选择导入的设备';

  @override
  String get cloudEmptyVerification => '本次授权未返回可导入的设备。可以仅保存适配器实例，稍后再读取。';

  @override
  String get cloudEmptyInventory => '本次完整读取未返回可导入的设备。适配器实例已保存，可稍后重新读取。';

  @override
  String get cloudV1Instance => '该凭据对应的单台 VPS';

  @override
  String get cloudAlreadyLinked => '已关联 · 不重复导入';

  @override
  String get cloudV1Identity => '无稳定设备 ID · 按此独立授权识别';

  @override
  String get cloudIpNotProvided => 'IP 未提供';

  @override
  String get cloudSelectBeforeComplete => '请先勾选上方设备，再补全下方资料。仅填写资料不会导入设备。';

  @override
  String get cloudLocalDisplayName => '本地显示名称（可选）';

  @override
  String get cloudLocalNameInfo => '仅用于新建本地记录，不作为远端设备标识';

  @override
  String get cloudV1ResourcesInfo =>
      'SolusVM 1 不提供稳定设备 ID，可读取的资源字段取决于提供商。填写内容仅保存本地，不会触发 SSH、TCP 或远端配置更改。';

  @override
  String get cloudRackNerdResourcesInfo =>
      'RackNerd ctrl 不提供稳定设备 ID。导入前需补齐六项硬件信息，API 未返回的 CPU 核数不能猜测。已填资料只存本机，不会触发 SSH、TCP 或远端配置修改。';

  @override
  String get cloudRebindWarning =>
      '保存新授权将解除此适配器实例的全部旧设备关联。原有资料、财务与 SSH 设置保留；导入会创建新本地记录，不会覆盖或自动重新关联旧设备。';

  @override
  String get cloudConfirmRebind => '我确认保存新授权将解除旧设备关联';

  @override
  String get cloudReturnSelect => '返回勾选设备';

  @override
  String get cloudSaving => '正在保存…';

  @override
  String get cloudNoneSelected => '尚未勾选新设备';

  @override
  String get cloudSaveOnly => '仅保存适配器实例';

  @override
  String get cloudUpdateUnlink => '更新授权并解除旧设备关联';

  @override
  String get cloudUpdateOnly => '仅更新授权';

  @override
  String get cloudReturnVerify => '返回重新验证';

  @override
  String get cloudSavingInfo => '正在提交到本机，请等待完成后再返回。';

  @override
  String get cloudReadImportable => '读取可导入的设备';

  @override
  String get cloudRefreshAccount => '刷新适配器实例状态';

  @override
  String get cloudReadingInfo =>
      '正在读取完整列表与状态，有超时限制。取消或返回会停止本次读取，不改变台账、费用或 SSH。';

  @override
  String get cloudCancelRead => '取消读取';

  @override
  String get cloudReadAgain => '重新读取';

  @override
  String get cloudReadCompleteInfo =>
      '仅更新本适配器实例的 API 观测信息，未覆盖本地资料、费用、付款或 SSH 设置。';

  @override
  String get cloudDone => '完成';

  @override
  String get cloudViewDetails => '查看适配器实例详情';

  @override
  String get cloudRenameAccount => '编辑适配器实例名称';

  @override
  String get cloudContinueImport => '继续导入设备';

  @override
  String get cloudLinkedServers => '关联服务器';

  @override
  String get cloudUnlinkAccount => '删除适配器实例';

  @override
  String get cloudUnlinkAccountTitle => '删除此适配器实例？';

  @override
  String get cloudUnlinkLocal => '仅删除本地适配器实例';

  @override
  String get cloudAccountDetails => '适配器实例详情';

  @override
  String get cloudAccountRemovedNotice => '适配器实例已删除，全部本地设备记录保留。';

  @override
  String get cloudTemplateLabel => '适配器类型';

  @override
  String get cloudPanelAddress => '面板地址';

  @override
  String get cloudReadStatus => '读取状态';

  @override
  String get cloudLastAttempt => '最近读取尝试';

  @override
  String get cloudNoAttempts => '尚无记录';

  @override
  String get cloudVerifiedScope => '已验证的读取范围';

  @override
  String get cloudV1Scope => '单设备 · Client API，无稳定设备标识';

  @override
  String get cloudAppCapabilities => 'App 能力';

  @override
  String get cloudReadCapabilities => '仅使用读取能力；无 API 电源控制';

  @override
  String get cloudAuthorizationStorage => '授权存储';

  @override
  String get cloudSecureStorageInfo => '设备安全存储；不显示或导出 API 凭据';

  @override
  String get cloudScopeNotice =>
      'API 凭据本身可能拥有更多权限，请在服务商面板核对。没有后台持续监控，读取结果只代表读取时刻。';

  @override
  String get cloudNoLinkedInstances => '暂无关联设备，可从适配器实例菜单继续导入。';

  @override
  String get cloudLocalRecord => '本地记录';

  @override
  String get cloudCancel => '取消';

  @override
  String get cloudSaveName => '保存名称';

  @override
  String get cloudLinkPanelAccount => '关联适配器实例';

  @override
  String get cloudLocalBindingInfo =>
      '此页仅使用已保存的 API 观测信息，不连接面板。没有可选设备或上次读取失败时，请先在适配器实例中手动刷新，再返回重新载入本地列表。';

  @override
  String get cloudBindingCommitted => '关联改动已保存，请先重新读取资料；不要重复提交。';

  @override
  String get cloudLedgerNotUpdated => '台账显示内容尚未更新，请先重新读取。';

  @override
  String get cloudReloadLocal => '重新读取本地列表';

  @override
  String get cloudBindingReadOnly => '已归档或演示记录不能修改面板关联。';

  @override
  String get cloudCurrentLink => '当前关联';

  @override
  String get cloudUnlinkThis => '解除这台关联';

  @override
  String get cloudSelectAccount => '选择适配器实例';

  @override
  String get cloudNoSavedAccounts => '此提供商下暂无已确认归属的适配器实例，请先添加并验证。';

  @override
  String get cloudSelectReadInstance => '选择已读取的设备';

  @override
  String get cloudNoSavedInstances => '此适配器实例暂无已保存的设备信息，请先手动刷新。';

  @override
  String get cloudOtherServer => '其他服务器';

  @override
  String get cloudMissingRefresh => '本次未返回 · 请在适配器实例中手动刷新';

  @override
  String get cloudFailedRefresh => '上次读取失败 · 请在适配器实例中手动刷新';

  @override
  String get cloudSaveLink => '保存关联';

  @override
  String get cloudChangeLink => '更换关联';

  @override
  String get cloudLocalLinkBoundary => '只修改本地关联；服务器资料、硬件、账务及 SSH 保持原样。';

  @override
  String get cloudSingleAccountInstance => '此授权对应的单台设备';

  @override
  String get cloudUnlinkServerTitle => '解除这台服务器的面板关联？';

  @override
  String get cloudChangeServerTitle => '更换这台服务器的面板关联？';

  @override
  String get cloudOnlyUnlinkThis => '仅解除这台关联';

  @override
  String get cloudConfirmChangeLink => '确认更换关联';

  @override
  String get cloudMetadataReadFailed => '无法读取适配器实例资料，请重试。';

  @override
  String get cloudSavedReloadFailed => '已保存，但资料重读失败；请重读后再修改';

  @override
  String get cloudAccountConflict => '适配器实例资料已改变，请重新载入后重试。';

  @override
  String get cloudOperationFailed => '适配器实例操作未完成，请重试。';

  @override
  String get cloudCompleteResources => '请补齐六项硬件信息后导入；未知项目请先向厂商确认';

  @override
  String get cloudCleanupIncomplete => '秘密清理尚未完成，可稍后重试';

  @override
  String get cloudCleanupStatusFailed => '无法读取清理状态，请重试';

  @override
  String get cloudVerifyCancelled => '验证已取消，未保存授权';

  @override
  String get cloudAliasInvalid => '适配器实例名称须为 1–80 字。';

  @override
  String get cloudVerifyFailed => '验证未完成，请检查面板地址、凭据和网络后重试';

  @override
  String get cloudVerifyNotSaved => '验证未完成，未保存授权';

  @override
  String get cloudVerifyAgainRequired => '未保存授权。需要重新验证后再导入。';

  @override
  String get cloudAuthorizationExpired => '离开应用后已清除本次授权，请返回重新验证。尚未提交的保存已取消。';

  @override
  String get cloudResourcesIncomplete => '请核对并补齐六项硬件信息；未知项目请先向厂商确认，补齐后再导入。';

  @override
  String get cloudSaveFailed => '保存未完成，请重试';

  @override
  String get cloudAccountSavedOnly => '适配器实例已保存，未导入新设备。';

  @override
  String get cloudInstancesSaved => '已保存，所选设备已添加到本地台账。';

  @override
  String get cloudReadCancelled => '读取已取消，保留上次读取的信息';

  @override
  String get cloudAccountUnlinkedReturn => '适配器实例已删除，请返回后继续。';

  @override
  String get cloudReadIncomplete => '读取未完成，保留上次读取的信息';

  @override
  String get cloudAliasSaved => '适配器实例名称已保存。';

  @override
  String get cloudNameSaveFailed => '名称未保存，请重试';

  @override
  String get cloudAccountUnlinked => '适配器实例已删除。本地资料、财务与 SSH 设置保留。';

  @override
  String get cloudUnlinkFailed => '删除适配器实例未完成，请重试。';

  @override
  String get cloudAliasRange => '请输入 1–80 字的适配器实例名称。';

  @override
  String get cloudBindingReadFailed => '无法读取本地关联资料，请重试';

  @override
  String get cloudServerUnlinked => '已解除这台服务器的面板关联';

  @override
  String get cloudBindingSaved => '适配器实例关联已保存。';

  @override
  String get cloudFailureInvalidEndpoint =>
      '请输入 HTTPS 面板首页地址，不含登录信息、查询参数或 API 路径';

  @override
  String get cloudFailureInvalidCredentials => '请填写该模板对应的有效 API 凭据';

  @override
  String get cloudFailureUnauthorized => 'API 凭据未通过验证，请检查凭据或重新授权';

  @override
  String get cloudFailureApiRejected => '面板拒绝 API 读取，请检查凭据、API 开放情况与服务状态';

  @override
  String get cloudFailureForbidden => '面板拒绝读取，请检查 API 权限与服务商设置';

  @override
  String get cloudFailureRateLimited => '面板请求过于频繁，请稍后手动重试';

  @override
  String get cloudFailureUnavailable => '面板暂时无法提供 API 读取服务';

  @override
  String get cloudFailureConnection => '连接失败，请检查网络、面板地址与 HTTPS 证书';

  @override
  String get cloudFailureTimeout => '读取超时，保留上次读取的信息；请稍后重试';

  @override
  String get cloudFailureCancelled => '读取已取消';

  @override
  String get cloudFailureRedirect => '面板返回重定向，已停止以保护凭据；请核对面板地址';

  @override
  String get cloudFailureInvalidResponse => '面板响应不符合读取协议，未更新本地资料';

  @override
  String get cloudFailureResponseTooLarge => '面板响应超过安全大小限制';

  @override
  String get cloudFailureInventoryTooLarge => '设备或分页数量超过本次读取限制，未导入不完整列表';

  @override
  String get cloudFailureUnsupportedPlatform => '此预览平台不接受真实 API 凭据，请使用原生应用';

  @override
  String get cloudAccountFailureIdentity =>
      '远端账户或设备标识发生变化，原有关联未改动。请建立独立的适配器实例。';

  @override
  String get cloudAccountFailureV1Rebind =>
      '此客户端 API 无法证明新凭据仍对应原设备。请明确确认解除旧关联，再选择导入的设备。原有本地记录保留。';

  @override
  String get cloudAccountFailureSelection => '导入列表已变化或选择无效，请重新读取';

  @override
  String get cloudAccountFailureAlias => '适配器实例名称须为 1–80 字。';

  @override
  String get cloudAccountFailureSecret => 'API 凭据未能保存到设备安全存储，原授权保持不变；请解锁设备后重试';

  @override
  String get cloudAccountFailureSecretRead =>
      '无法读取此适配器实例保存的 API 凭据。请解锁设备后重试；仍失败时可从菜单重新授权。';

  @override
  String get cloudAccountFailureBindingTaken => '此设备已关联其他本地服务器，不能覆盖。请重新载入本地列表。';

  @override
  String get cloudAccountFailureBindingUnavailable =>
      '设备信息暂不可用于关联，请先手动刷新适配器实例后重新选择。';

  @override
  String get cloudReadLimitPositive => '读取限制必须大于 0';

  @override
  String cloudProviderLinks(String provider, int count) {
    return '$provider · $count 台关联';
  }

  @override
  String cloudRequiredField(String label) {
    return '请填写 $label';
  }

  @override
  String cloudConnectProvider(String provider) {
    return '连接 $provider';
  }

  @override
  String cloudVerifyTarget(String normalization, String origin) {
    return '$normalization验证将连接：$origin';
  }

  @override
  String cloudInventoryComplete(int count, String time, String authorization) {
    return '完整读取完成 · $count 台设备\n读取时间：$time$authorization';
  }

  @override
  String cloudInstanceFallback(String id) {
    return '设备 $id';
  }

  @override
  String cloudProjectInstance(String project, String id) {
    return '项目 $project · 设备 ID $id';
  }

  @override
  String cloudPowerLastRead(String power) {
    return '电源$power · 上次读取';
  }

  @override
  String cloudImportBoundary(String deduplication) {
    return '导入不会覆盖已有本地名称、费用、付款、备注或 SSH 配置。$deduplication已归档的关联也不会重复导入。';
  }

  @override
  String cloudV2Scope(String id) {
    return '已验证用户账户 $id · 项目与设备';
  }

  @override
  String cloudLinkedCount(int count) {
    return '已关联 $count 台';
  }

  @override
  String cloudRecordWithState(String name, String state) {
    return '$name$state';
  }

  @override
  String cloudBindingWithTime(String summary, String time) {
    return '$summary\n读取时间：$time';
  }

  @override
  String get cloudConsolePathRemoved => '已移除 /home.php。\n';

  @override
  String get cloudRackNerdApiPathRemoved =>
      '已为 RackNerd ctrl 移除 /api/client/command.php。\n';

  @override
  String get cloudAuthorizationUnsaved => '\n尚未保存这次授权';

  @override
  String get cloudV1Deduplication => '此授权已固定的设备不会再次创建；解除关联不会解除固定。独立授权之间不会自动合并。';

  @override
  String get cloudV2Deduplication =>
      '以适配器类型、面板地址、远端账户、项目与设备 ID 确认重复。IP 或主机名相同仅作核对提示。';

  @override
  String get cloudArchivedSuffix => ' · 已归档';

  @override
  String cloudImportCount(int count) {
    return '导入 $count 台设备';
  }

  @override
  String cloudSaveImportCount(int count) {
    return '保存适配器实例并导入 $count 台设备';
  }

  @override
  String cloudUnlinkAccountMessage(String alias, String remoteAction) {
    return '$alias\n\n删除此本地适配器实例及其设备关联。重新添加需要再次输入 API 凭据。不会删除远端设备或停止计费。\n\n$remoteAction';
  }

  @override
  String get cloudRevokeV1 => '还需到面板禁用该 VPS 的 Client API 或重置 Key / Hash。';

  @override
  String get cloudRevokeV2 => '还需到面板撤销已签发的 Token。';

  @override
  String cloudSuggestedAlias(String provider) {
    return '我的 $provider 适配器';
  }

  @override
  String cloudReadAt(String time) {
    return '读取时间：$time';
  }

  @override
  String cloudAlreadyLinkedTo(String name) {
    return '已关联：$name · 不可覆盖';
  }

  @override
  String cloudChangeLinkMessage(
    String server,
    String account,
    String instance,
    String replacement,
  ) {
    return '$server\n当前：$account · $instance$replacement\n\n仅修改本地关联，保留服务器资料、硬件、费用、付款、SSH、适配器实例及授权。不会操作远端设备或停止扣费。';
  }

  @override
  String cloudReplacementLink(String account, String instance) {
    return '\n更换为：$account · $instance';
  }

  @override
  String get cloudPowerRunning => '运行中';

  @override
  String get cloudPowerStopped => '已停止';

  @override
  String get cloudPowerUnknown => '未知';

  @override
  String get cloudMissingKept => '本次未返回 · 保留上次信息';

  @override
  String get cloudFailedKept => '读取失败 · 保留上次信息';

  @override
  String get cloudLastRead => '上次读取';

  @override
  String get cloudAuthorizationFailedKept => '授权验证失败 · 原台账保留';

  @override
  String get cloudVerifiedManual => '已验证 · 手动读取';

  @override
  String get cloudStepTemplate => '适配器类型';

  @override
  String get cloudStepCredentials => '填授权';

  @override
  String get cloudStepInstances => '设备';

  @override
  String get cloudApiUnknown => '未知（API 未提供）';

  @override
  String cloudBindingSummary(String freshness, String power) {
    return '$freshness · 电源$power';
  }

  @override
  String cloudStepLabel(int number, String label) {
    return '0$number $label';
  }

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
  String get resourceValidIp => '请填写有效的 IPv4 或 IPv6 地址，不能使用未指定地址';

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
  String get resourceInvalidSources => '资源来源字段无效';

  @override
  String get resourceUnknownApiSource => '未知资源不能标记为 API 来源';

  @override
  String get resourceTooLarge => '本地资源配置过大';

  @override
  String get resourceInvalidFields => '本地资源配置字段无效';

  @override
  String get resourceInvalidSourceFields => '本地资源来源字段无效';

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
  String get resourceSourceManual => '来源：手动填写';

  @override
  String get resourceSourceApi => '来源：API';

  @override
  String get resourceSourceUnlimited => '来源：手动确认不限量';

  @override
  String get resourceSourceMissing => '待补填：API 未提供有效值';

  @override
  String get resourceSourceCompleted => '来源：手动补填';

  @override
  String get resourceSourceEditedApi => '来源：手动修改 API 预填值';

  @override
  String get resourceFieldValidIp => '请填写有效 IPv4 或 IPv6，不能为全零地址';

  @override
  String get resourceFieldValidVcpu => '请填写 1–65536 的整数核数';

  @override
  String get resourceFieldValidBytes => '请填写大于 0 的容量，精确到整字节';

  @override
  String get resourceCapacity => '容量';

  @override
  String resourceUnitSemantics(String p0) {
    return '$p0单位，1024 进制';
  }

  @override
  String get resourceUnit => '单位';

  @override
  String get resourceTrafficPeriod => '流量周期';

  @override
  String get resourcePeriod => '周期';

  @override
  String get resourceNewPeriodHelp => '新建默认按月，可改。';

  @override
  String get resourcePeriodHelp => '周期独立于容量单位；未知选“未设置”。';

  @override
  String get resourceSixRequired => '硬件信息 · 六项必填';

  @override
  String get resourceHardware => '硬件信息';

  @override
  String get resourceImportHelp =>
      '核对并补齐六项后导入；容量按 1024 进制，0 不代表不限量。资料不全时可暂不选择此实例，待补齐后再导入。';

  @override
  String get resourceLocalHelp => '容量按 1024 进制；面板刷新不会覆盖手动资料。';

  @override
  String get resourceIpAddress => 'IP 地址';

  @override
  String get resourceHostname => '主机名';

  @override
  String get resourceDiskCapacity => '磁盘容量';

  @override
  String get resourceTrafficQuotaLabel => '流量额度';

  @override
  String get resourceUnlimitedHelp => '仅套餐明确不限量时开启。';

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
  String get serverApplyFilters => '应用筛选';

  @override
  String serverLedgerCount(String p0) {
    return '$p0 台服务器 · 本地台账';
  }

  @override
  String get serverReloadLocal => '重新读取本地台账';

  @override
  String get serverReloadedLocal => '已重新读取本地台账，未查询远端状态';

  @override
  String get serverAdd => '添加服务器';

  @override
  String get serverImportPanel => '从面板账户导入';

  @override
  String get serverFirstTitle => '你的第一台 VPS，\n从这里开始';

  @override
  String get serverFirstDescription => '把机器、费用和连接放在一起。\n无需安装监控程序，也可直接手动记录。';

  @override
  String get serverAddFirst => '添加第一台服务器';

  @override
  String get serverLoadDemoQuestion => '载入演示数据？';

  @override
  String get serverLoadDemoHelp =>
      '将写入 4 条带“演示”标记的本地记录，地址均为保留地址。不会连接服务器。可在各服务器详情中归档这些记录。';

  @override
  String get serverLoadDemo => '载入演示';

  @override
  String get serverViewDemo => '先看看演示数据';

  @override
  String get serverManualStartHelp => '已经有机器？手动记录就能开始。';

  @override
  String get serverSearchHint => '搜索名称、地址、厂商、用途或地区';

  @override
  String get serverClearSearch => '清除搜索';

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
  String serverExpiryCounts(String p0, String p1) {
    return '$p0 台已过期 · $p1 台 30 天内到期';
  }

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
  String get uiServersRowHint => '左滑或长按服务器查看快捷操作';

  @override
  String get serverClearFilters => '清除筛选';

  @override
  String get serverListObservationHelp =>
      '显示本地资料和最近一次面板查询结果，不持续监控。\n到期天数按设备日期计算；未来 30 天包含今天及后 29 天。';

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
  String get serverLocalUnqueried => '本地记录 · 未查询运行状态';

  @override
  String get serverNotEntered => '未填写';

  @override
  String get resourceUnlimitedConfirmed => '不限量（已确认）';

  @override
  String get resourceCardHelp => '仅本地资料，面板刷新不会覆盖。';

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
  String get serverMissingDetails => '待补充';

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
  String get serverCopyHost => '复制主机地址';

  @override
  String get serverHostCopied => '主机地址已复制';

  @override
  String get serverCopyHostFailed => '未能复制主机地址，请重试。';

  @override
  String get serverOperatingSystem => '操作系统';

  @override
  String get serverGroupPurpose => '分组 / 用途';

  @override
  String get serverSpecifications => '规格';

  @override
  String get serverLocalInfoHelp => '以上是本地资料，面板刷新不会覆盖。连接测试结果不代表服务持续可用。';

  @override
  String get serverEditHardware => '编辑硬件';

  @override
  String get serverPanelLink => '面板关联';

  @override
  String get serverNoPanelLink => '未关联面板账户';

  @override
  String get serverPanelLinkHelp => '关联已保存的面板账户与实例。关联或刷新均不会更改本地硬件信息，请在上方手动编辑。';

  @override
  String get serverLinkPanel => '关联面板账户';

  @override
  String get serverManageLink => '管理关联';

  @override
  String get serverReloadPanelDetails => '重新读取面板账户资料';

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
  String get serverServiceStart => '服务开始日';

  @override
  String get serverUnknown => '未知';

  @override
  String get serverServiceDue => '服务到期日';

  @override
  String get serverUnknownCostHelp => '未知金额不会按 0 计算。可在“基本信息 / 编辑”中补充费用资料。';

  @override
  String get serverMeteredValueHelp => '按量费用作为月估算，不产生剩余价值。可在编辑服务器时维护费用资料。';

  @override
  String get serverRenewalValueHelp => '按当前续费价折算已知服务期；历史实付另计，不覆盖续费价。';

  @override
  String get serverReminderPlan => '到期提醒与使用计划';

  @override
  String get serverRemindersOff => '提醒已关闭';

  @override
  String get serverRemainingValue => '剩余价值';

  @override
  String get serverUnknownValueHelp => '日期或费用资料不足，剩余价值未知，不按 0 计算。';

  @override
  String get serverRecordPayment => '记录已付款';

  @override
  String get serverUseForCalculation => '引用资料试算';

  @override
  String get serverViewPayments => '查看付款记录';

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
  String get serverPower => '单机电源';

  @override
  String get serverConnectionSafety =>
      '首次连接需核对主机指纹；指纹变化会暂停登录。重启或关机需再次核对目标，且不会停止厂商计费。';

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
  String uiDetailConverted(String currency) {
    return '折合 $currency';
  }

  @override
  String get uiDetailDaily => '日均';

  @override
  String get uiDetailRemainingDays => '剩余天数';

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
  String serverRequiredField(String p0) {
    return '请填写$p0';
  }

  @override
  String get serverAmountPrecision => '请输入有效金额，最多两位小数';

  @override
  String get serverDateExample => '请使用有效日期，例如 2026-10-06';

  @override
  String get serverPlainHost => '请输入纯 IP 或域名，不含协议、端口或路径';

  @override
  String get serverBillingType => '计费方式';

  @override
  String get serverEveryYear => '每年';

  @override
  String serverEveryMonths(int p0) {
    return '每 $p0 个月';
  }

  @override
  String get serverHalfYear => '半年';

  @override
  String get serverTwoYears => '2年';

  @override
  String get serverThreeYears => '3年';

  @override
  String get serverAmount => '金额';

  @override
  String get serverOriginalCurrency => '原币种';

  @override
  String get serverCurrency => '币种';

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
  String get serverManualAdd => '手动添加';

  @override
  String get serverEditTitle => '编辑服务器';

  @override
  String get serverFormHelp => '仅保存在本机，不会修改远端。';

  @override
  String get serverBasicData => '基本资料';

  @override
  String get serverName => '服务器名称';

  @override
  String get serverProvider => '厂商';

  @override
  String get serverProviderExample => '例如：搬瓦工 / 自定义厂商';

  @override
  String get serverOptionalHost => '主机地址（选填）';

  @override
  String get serverHostExample => 'IPv4、IPv6 或域名，不含协议或端口';

  @override
  String get serverNewHostHelp => '新建时留空会采用硬件信息中的 IP 或主机名；SSH 连接地址另行设置。';

  @override
  String get serverSavedHostHelp => '此地址独立保存，修改硬件不会更改它；SSH 连接地址另行设置。';

  @override
  String get serverOptionalPurpose => '用途（选填）';

  @override
  String get serverOptionalRegion => '地区（选填）';

  @override
  String get serverOptionalOs => '操作系统（选填）';

  @override
  String get serverOptionalSpec => '规格补充（选填）';

  @override
  String get serverSpecExample => '例如：CPU 型号、网络带宽';

  @override
  String get serverCostDetails => '费用资料';

  @override
  String get serverPaymentLockHelp => '已有续费付款：计费方式、周期和日期不可改；续费价与币种仍可改。';

  @override
  String get serverCostUnknownOption => '费用未知 · 稍后补充';

  @override
  String get serverPrepaidOption => '预付费 · 按周期续费';

  @override
  String get serverMeteredOption => '按量付费 · 月估算';

  @override
  String get serverPrepaid => '预付费';

  @override
  String get serverMetered => '按量付费';

  @override
  String get serverDatesHelp => '到期日默认按开始日加周期计算，可手动修改。';

  @override
  String get serverAmountHelp => '0 表示免费；未知请选“未知”。不会记录付款。';

  @override
  String get serverOptionalNotes => '备注（选填）';

  @override
  String get serverNotesSafety => '请勿在备注保存密码、私钥或令牌。';

  @override
  String get serverSave => '保存服务器';

  @override
  String get uiFormProvider => '提供商';

  @override
  String get uiFormPurpose => '用途';

  @override
  String get uiFormRegion => '地区';

  @override
  String get uiFormSpec => '规格补充';

  @override
  String get uiFormOptional => '选填';

  @override
  String get uiFormNameHint => '例如 HK-01';

  @override
  String get uiFormDone => '完成';

  @override
  String get uiFormSetUnknown => '设为未知';

  @override
  String get uiFormPickDate => '选择日期';

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
  String get r2FormAddressHelp => '地址留空时取硬件 IP 或主机名；SSH 地址另设。';

  @override
  String get r2FormProviderLocked => '提供商请在详情页更改。';

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
  String get tcpTestExplanation =>
      '从当前设备测试一个地址和端口，仅建立并关闭 TCP 连接，不发送应用数据。成功不代表 SSH 可登录、服务器开机状态或业务健康。';

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
  String tcpTarget(String p0) {
    return '目标：$p0';
  }

  @override
  String tcpActualAddress(String p0) {
    return '实际地址：$p0';
  }

  @override
  String tcpResultSource(String p0) {
    return '来源：$p0';
  }

  @override
  String tcpFinished(String p0) {
    return '结束时间：$p0（本机时间）';
  }

  @override
  String tcpElapsed(String p0) {
    return '耗时：$p0 ms';
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
      '本页改动只用于本次连接。密码或私钥从已保存的凭据中读取，不在这里输入或另存。进入后台会断开连接；长任务建议在远端使用 tmux / screen。';

  @override
  String get connectionSnippetDraftOnly => '片段将放入独立待发送区。连接、核验、认证都不会发送片段。';

  @override
  String get connectionPowerAfterConnect =>
      '连接后才能选择重启 / 关机，并再次完成两次确认。没有 SSH 开机或 API 电源功能。';

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
  String get snippetSelectPreviewHelp => '选择后先预览完整内容，只插入待发送草稿。不会自动发送或回车。';

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
  String get snippetCancelEdit => '取消片段编辑';

  @override
  String get snippetSaveSafety => '本地普通文本，不加密保存。请勿填写密码、私钥或令牌。保存不会执行或发送内容。';

  @override
  String get snippetName => '片段名称';

  @override
  String get snippetFullContent => '完整内容（保留原始换行与控制字符）';

  @override
  String get snippetContentRange => '内容不能为空，最多 16384 个字符';

  @override
  String get snippetExactContentHelp =>
      '保存会原样保留内容，包括前后空白、多行、回车及控制字符。请使用完整预览核对。';

  @override
  String get connectionSaving => '保存中…';

  @override
  String get snippetSave => '保存片段';

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
      '离开或进入后台会断开会话；不会自动重连或重放输入。长任务建议在远端使用 tmux / screen。';

  @override
  String get terminalOfflineFont => '离线字体：DejaVu Sans Mono · 中文使用设备字体回退';

  @override
  String get terminalLicenses => '开源许可';

  @override
  String get terminalDisconnectQuestion => '断开 SSH 会话？';

  @override
  String get terminalDiscardExitQuestion => '丢弃草稿并退出？';

  @override
  String terminalDisconnectHelp(String p0, String p1) {
    return '$p0\n未放入 tmux / screen 的远端任务可能中断。$p1';
  }

  @override
  String get terminalDraftKeptUntilReconnect => '草稿暂时保留，重连时清空。';

  @override
  String get terminalDraftWillClear => '未发送草稿将清空。';

  @override
  String get terminalUnsentDraftExit => '当前草稿尚未发送，退出后将清空。';

  @override
  String get terminalDisconnect => '断开连接';

  @override
  String get terminalDisconnectExit => '断开并退出';

  @override
  String get terminalDiscardExit => '丢弃并退出';

  @override
  String get terminalBackgroundDisconnected => '应用进入后台，连接已清理。需要手动重连，不会重放输入。';

  @override
  String get terminalTargetChanged => '目标已变化，连接和草稿已清空。请手动连接新目标。';

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
  String get terminalReconnectClear => '重新连接并清空草稿';

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
  String get terminalReconnectShort => '重连 · 清空草稿';

  @override
  String get terminalBrowserUnsupported => '浏览器不支持原生 SSH，请使用原生应用。';

  @override
  String get terminalConnectedInputHelp => '连接后点按终端输入，按键会直接发送到服务器。';

  @override
  String get terminalRetainedOutputHelp => '输出已保留。重连会清空终端和草稿，不重放输入。';

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
  String get terminalPassphraseHelp =>
      '这是私钥解密口令，不是服务器登录密码。仅用于本次连接，不会保存；下次连接需重新输入。';

  @override
  String get terminalKeyPassphrase => '本次私钥口令';

  @override
  String get terminalPassphraseCleared => '连接已取消或页面进入后台，口令已清空。请取消并重新连接。';

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
  String get securityCredentialStorageNotice => '凭据独立管理，连接只引用凭据。秘密仅保存在系统安全存储中。';

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
      '密码、私钥和密钥口令不进入台账数据库、导出或日志。密码查看需系统设备验证，20 秒后或离开页面即隐藏。Linux 不支持本应用的设备验证，无法查看秘密。\n\n设备认证是应用显示门禁，不代表秘密被生物识别硬件单独加密。iOS / Android 真机安全行为仍需验证。Dart 不保证内存安全擦除；当前不提供秘密复制或导出。';

  @override
  String get securityLocalCredentialNotice =>
      '修改本地凭据不会修改远端密码或 authorized_keys。只有明确发起连接才会使用所选凭据。';

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
      '支持 OpenSSH / PEM 私钥。只读取所选文件，不保存文件路径。也可用“粘贴完整私钥”保留换行；内容始终隐藏。';

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
  String get securityPrivateKeyPassphraseHelp =>
      '用于解密所选私钥，不是服务器登录密码。本页不会更改私钥的加密口令';

  @override
  String get securityStoreKeyPassphrase => '在设备安全存储中保存私钥口令';

  @override
  String get securityStoreKeyPassphraseHelp =>
      '默认不保存。加密私钥未保存口令时，每次连接都需输入。取消或口令错误会停止连接。仅在导入私钥时应用此选项。';

  @override
  String get securityCredentialEditNotice =>
      '用户名只作为新连接的候选值，不覆盖已有连接。更新凭据只影响以后登录，不修改服务器端密码或密钥。离开到后台会清空未保存秘密。';

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
      '这里不展示或导出私钥。公钥指纹用于辨认登录密钥，与服务器主机指纹不同。';

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
  String get securityPasswordHiddenNotice =>
      '验证成功后仅短时显示。无设备认证能力时保持隐藏；Linux 暂不可查看。';

  @override
  String get securityHidePassword => '隐藏密码';

  @override
  String get securityVerifyViewPassword => '设备验证后查看密码';

  @override
  String get securityCancelVerifyHide => '取消验证并隐藏';

  @override
  String securityCredentialReferenceCount(int count) {
    return '$count 台引用此凭据，包含已归档记录。连接用户名分别保存。';
  }

  @override
  String get securityNoCredentialReferences => '尚未关联。可在服务器详情的 SSH 配置中选择。';

  @override
  String securityCredentialDeleteImpact(int count) {
    return '$count 台服务器将受影响，包含归档记录。请核对下面的每一项。';
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
  String get securityDeleteLocalCredentialNotice =>
      '仅删除本机凭据，不能从本页面恢复。不修改远端密码或 authorized_keys，不取消云服务。';

  @override
  String get securityConfirmCredentialImpact => '我已确认关联影响，删除本地凭据';

  @override
  String get securityLocalCredentialDeleted => '本地凭据已删除，远端认证资料未改变';

  @override
  String get securityConfirmDelete => '确认删除';

  @override
  String get securityVerifyHostKey => '核验主机公钥';

  @override
  String get securityHostTrustNotice =>
      '信任绑定主机地址和端口，并记录算法及完整公钥。登录凭据与服务器主机公钥是两件事。';

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
      '输入从厂商控制台或管理员等独立可信渠道取得的主机公钥。此页面只校验输入内容并保存本机信任，不会连接服务器。';

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
      'rsa-sha2-256 / rsa-sha2-512 是签名算法，其 RSA 公钥类型选择 ssh-rsa。只支持结构完整的受支持主机公钥。';

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
      '请通过独立渠道核对完整指纹和目标地址。变化可能来自重装，也可能是错误主机或中间人攻击。无法确认时应拒绝。';

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
  String get securityLocalHostTrustOnly =>
      '只记录本机信任，当前不会连接服务器。拒绝、取消和返回均不保存，也不发送认证资料。';

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
  String get securityCancelSshConfiguration => '取消连接配置';

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
  String get securityConfigurationOnlyNotice =>
      '此页只保存连接配置。建立连接时先核验主机身份，再进行登录认证；主机公钥变化时会暂停认证，等待重新核实。';

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
  String get securityAuthBiometricNotRecognized => '未能识别，请重试。';

  @override
  String get securityAuthBiometricSuccess => '验证成功';

  @override
  String get securityAuthRequiredTitle => '需要生物识别验证';

  @override
  String get securityAuthSetupDescription => '请在设备设置中启用生物识别验证。';

  @override
  String get securityAuthGoToSettings => '前往设置';

  @override
  String get securityAuthDeviceSetupDescription => '请在设备设置中启用设备验证。';

  @override
  String get securityAuthDeviceRequiredTitle => '需要设备验证';

  @override
  String get securityAuthIosLockout => '生物识别验证已锁定。请锁定并解锁设备，再重新尝试。';

  @override
  String get securityAuthIosSetupDescription => '请在设备设置中启用 Face ID 或 Touch ID。';

  @override
  String serverCompactMonths(int months) {
    return '$months个月';
  }

  @override
  String get resourceTrafficPeriodUnsetShort => '未设置';

  @override
  String get resourceTrafficPeriodMonthShort => '月';

  @override
  String get resourceTrafficPeriodQuarterShort => '季';

  @override
  String get resourceTrafficPeriodYearShort => '年';

  @override
  String get providerReviewRequired => '请先确认此实例的提供商归属，再添加授权、导入或关联服务器。';

  @override
  String get providerNameRange => '提供商名称需为 1–80 个字符。';

  @override
  String get providerAlreadyExists => '这个提供商已存在，请直接选择。';

  @override
  String get providerChangeNeedsUnlink => '更改提供商前，请确认解除原适配器关联。';

  @override
  String get adapterProviderMismatch => '服务器与适配器实例必须属于同一提供商。';

  @override
  String get adapterScopeUnavailable => '此实例的授权范围尚未确认，不能新增关联。';

  @override
  String get adapterSingletonPinned =>
      '这组单机凭据已确认用于另一条服务器记录；解绑不会释放其授权范围。请回到原记录，或单独重新授权。';

  @override
  String get providerUiTitle => '提供商管理';

  @override
  String get uiCloudProvidersTitle => '提供商';

  @override
  String get uiCloudNeedsReviewPill => '归属待确认';

  @override
  String get uiCloudOwnerSection => '归属提供商';

  @override
  String get uiCloudMethodSection => '添加方式';

  @override
  String get uiCloudAddFooter => '面板密钥只存入设备安全存储，读取不会修改远端。';

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
  String get providerUiUnspecifiedHelp => '仅手动添加，可稍后在服务器详情中指定归属。';

  @override
  String get providerUiHierarchyHelp =>
      '提供商是服务器的业务归属；适配器实例保存一份独立授权，只能读取该授权范围内的设备。';

  @override
  String providerUiSummary(int instances, int devices) {
    return '$instances 个适配器实例 · $devices 台服务器';
  }

  @override
  String get providerUiEmpty => '还没有提供商';

  @override
  String get providerUiEmptyHelp => '先记录提供商名称，再手动添加服务器或配置只读适配器。';

  @override
  String get providerUiNeedsReview => '归属待确认，暂不能新增授权或关联';

  @override
  String providerUiUnspecifiedCount(int count) {
    return '$count 台服务器尚未指定提供商。';
  }

  @override
  String get providerUiChoose => '选择提供商';

  @override
  String get providerUiChooseHelp => '选择业务提供商。面板类型与授权将在后续步骤选择。';

  @override
  String get providerUiSelected => '服务器归属';

  @override
  String get providerUiChooseAnother => '重新选择提供商';

  @override
  String get providerUiChooseMethod => '选择添加方式';

  @override
  String get providerUiManualHelp => '手动填写资料。六项硬件和费用未知时可以留空。';

  @override
  String get providerUiAutomatic => '通过适配器读取';

  @override
  String get providerUiAutomaticHelp => '选择现有授权或新增适配器，读取后确认导入。';

  @override
  String get providerUiAutoNeedsProvider => '自动读取前，需要选择已确认的提供商。';

  @override
  String get providerUiInstances => '适配器实例';

  @override
  String get providerUiNoInstances => '尚未配置适配器；仍可手动添加服务器。';

  @override
  String get providerUiAddInstance => '新增适配器实例';

  @override
  String get providerUiDevices => '名下服务器';

  @override
  String get providerUiNoDevices => '这个提供商下还没有服务器。';

  @override
  String get providerUiManualDevice => '无适配器关联';

  @override
  String get providerUiLinkedDevice => '已关联适配器';

  @override
  String providerUiLinkedCount(int count) {
    return '已关联 $count 台服务器';
  }

  @override
  String get providerUiSingleScope => '单台设备授权';

  @override
  String get providerUiAccountScope => '账户范围授权';

  @override
  String get providerUiUnknownScope => '授权范围未确认';

  @override
  String providerUiPinnedHelp(String name) {
    return '这份单台授权已固定到「$name」。即使解除关联，也不能给另一台设备使用；请回到原记录或明确重新授权。';
  }

  @override
  String get providerUiChooseInstance => '选择适配器实例';

  @override
  String get providerUiInstanceChoiceHelp => '只列出当前提供商的实例。授权范围由适配器类型与验证结果决定。';

  @override
  String get providerUiReviewHelp =>
      '旧资料无法确定业务归属。请为每个实例确认提供商及所有受影响的服务器。确认前只允许刷新已有关联。';

  @override
  String get providerUiRenameReviewHelp => '重命名不会确认归属；仍须在实例上执行归属确认。';

  @override
  String get providerUiConfirmOwnership => '确认实例归属';

  @override
  String providerUiConfirmOwnershipMessage(
    String alias,
    String provider,
    String devices,
  ) {
    return '将「$alias」归属到「$provider」。下列已关联服务器会一起调整归属：\n$devices\n\n保留原授权、服务器资料、费用和 SSH。此操作不会扩大授权范围。';
  }

  @override
  String get providerUiNoAffectedDevices => '没有已关联服务器。';

  @override
  String get providerUiUnavailable => '此提供商已变更或不可用，请返回重新选择。';

  @override
  String get providerUiChange => '更改提供商';

  @override
  String providerUiChangeMessage(
    String server,
    String oldProvider,
    String newProvider,
    String linkEffect,
  ) {
    return '将「$server」从「$oldProvider」改为「$newProvider」。\n\n$linkEffect\n\n保留服务器 ID、手动资料、费用和 SSH。更改归属不会自动添加新授权或关联。';
  }

  @override
  String get providerUiChangeNoLink => '这台服务器没有适配器关联。';

  @override
  String providerUiChangeUnlink(String alias) {
    return '必须先解除与「$alias」的本地关联；旧适配器授权仍保留，单台授权的固定目标不会被清除。';
  }

  @override
  String get providerUiUnlinkAndChange => '解除关联并更改归属';

  @override
  String get providerUiChangeFromDetails =>
      '更改已有服务器归属，请返回详情选择“更改提供商”；有关联时须先确认解除。';

  @override
  String get providerUiProviderAndAdapter => '提供商与适配器';

  @override
  String get providerUiOpenProvider => '查看提供商';

  @override
  String get providerUiOpenInstance => '查看适配器实例';

  @override
  String providerPendingName(String name) {
    return '$name · 归属待确认';
  }

  @override
  String get providerBindingAssignFirst => '请先在服务器详情中指定提供商，再选择适配器实例关联。';

  @override
  String get cloudImportSaved => '适配器实例已保存。授权与本次设备导入结果分别保留。';

  @override
  String get cloudImportReady => '资源完整';

  @override
  String get cloudImportNeedsCompletion => '待补填资源';

  @override
  String get cloudImportImported => '导入成功';

  @override
  String get cloudImportExisting => '已存在';

  @override
  String get cloudImportFailed => '导入失败';

  @override
  String get cloudImportUnprocessed => '未处理';

  @override
  String get cloudImportCompleteResources => '补填资源';

  @override
  String get cloudImportReviewResources => '核对资源';

  @override
  String get cloudImportCompleteAndSelect => '保存草稿并勾选';

  @override
  String get cloudImportCompletionInfo =>
      '导入前需核对完整的六项资源。API 未提供的值保持未知；只有明确确认后才选择不限流量。补填或修改仅用于本地配置，不会改写 API 观测信息。';

  @override
  String get cloudImportFinanceLater => '本次仅添加设备与资源配置。财务信息可稍后填写，不会自动创建费用或付款。';

  @override
  String cloudImportSummary(
    int imported,
    int existing,
    int failed,
    int unprocessed,
  ) {
    return '成功 $imported · 已存在 $existing · 失败 $failed · 未处理 $unprocessed';
  }

  @override
  String cloudImportRetryCount(int count) {
    return '仅重试未完成的 $count 台设备';
  }

  @override
  String get cloudImportCancel => '停止后续导入';

  @override
  String get cloudImportCancelling => '正在停止…';

  @override
  String get cloudImportCancelled => '已停止后续导入。已提交的设备保留，可核对结果后重试未完成项。';

  @override
  String get cloudImportResultsTitle => '本次导入结果';

  @override
  String cloudImportExistingConflict(int count) {
    return '发现 $count 条相同远端标识的本地记录，请逐条核对；不会自动选择或合并。';
  }

  @override
  String cloudImportAddressHint(String names) {
    return 'IP 或主机名与这些本地设备相同：$names。这只是核对提示，不能据此确认是同一设备。';
  }

  @override
  String cloudInstanceDeleteImpact(int count, String names) {
    return '将解除 $count 台本地服务器的关联：\n$names\n\n全部本地资料、资源配置、财务与 SSH 设置保留。';
  }

  @override
  String get cloudImportIdentityConflict => '设备标识冲突';
}
