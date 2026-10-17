import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @language.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get language;

  /// No description provided for @languageDescription.
  ///
  /// In zh, this message translates to:
  /// **'立即切换界面语言，保留当前草稿和连接。'**
  String get languageDescription;

  /// No description provided for @languageSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get languageSystem;

  /// No description provided for @languageSystemDescription.
  ///
  /// In zh, this message translates to:
  /// **'其他系统语言使用 English。'**
  String get languageSystemDescription;

  /// No description provided for @languageChinese.
  ///
  /// In zh, this message translates to:
  /// **'简体中文'**
  String get languageChinese;

  /// No description provided for @languageEnglish.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageSaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'未能保存语言设置。当前语言未更改，请重试。'**
  String get languageSaveFailed;

  /// No description provided for @ledgerOpenFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法打开本地台账'**
  String get ledgerOpenFailed;

  /// No description provided for @ledgerOpenHelp.
  ///
  /// In zh, this message translates to:
  /// **'原有数据仍保留。请检查设备存储空间和文件权限；如果曾使用较新版本，请用相同或更新版本重试。'**
  String get ledgerOpenHelp;

  /// No description provided for @retryOpen.
  ///
  /// In zh, this message translates to:
  /// **'重试打开'**
  String get retryOpen;

  /// No description provided for @ledgerDoNotErase.
  ///
  /// In zh, this message translates to:
  /// **'请勿清除应用数据或卸载重装来尝试修复。'**
  String get ledgerDoNotErase;

  /// No description provided for @servers.
  ///
  /// In zh, this message translates to:
  /// **'服务器'**
  String get servers;

  /// No description provided for @costs.
  ///
  /// In zh, this message translates to:
  /// **'费用'**
  String get costs;

  /// No description provided for @tools.
  ///
  /// In zh, this message translates to:
  /// **'工具'**
  String get tools;

  /// No description provided for @settings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settings;

  /// No description provided for @toolsDescription.
  ///
  /// In zh, this message translates to:
  /// **'计算费用、连接服务器或管理常用命令。'**
  String get toolsDescription;

  /// No description provided for @remainingValueCalculator.
  ///
  /// In zh, this message translates to:
  /// **'剩余价值计算器'**
  String get remainingValueCalculator;

  /// No description provided for @calculatorDescription.
  ///
  /// In zh, this message translates to:
  /// **'独立试算或引用服务器资料 · 可导出图片'**
  String get calculatorDescription;

  /// No description provided for @connectionsTroubleshooting.
  ///
  /// In zh, this message translates to:
  /// **'连接与排障'**
  String get connectionsTroubleshooting;

  /// No description provided for @sshQuickConnect.
  ///
  /// In zh, this message translates to:
  /// **'SSH 快速连接'**
  String get sshQuickConnect;

  /// No description provided for @sshQuickConnectDescription.
  ///
  /// In zh, this message translates to:
  /// **'选择服务器或临时目标 · 核验主机后登录'**
  String get sshQuickConnectDescription;

  /// No description provided for @tcpConnectionTest.
  ///
  /// In zh, this message translates to:
  /// **'TCP 连接测试'**
  String get tcpConnectionTest;

  /// No description provided for @tcpConnectionDescription.
  ///
  /// In zh, this message translates to:
  /// **'从当前设备检查单个地址和端口'**
  String get tcpConnectionDescription;

  /// No description provided for @commandSnippets.
  ///
  /// In zh, this message translates to:
  /// **'命令片段'**
  String get commandSnippets;

  /// No description provided for @commandSnippetsDescription.
  ///
  /// In zh, this message translates to:
  /// **'保存常用命令 · 插入终端草稿后发送'**
  String get commandSnippetsDescription;

  /// No description provided for @singleServerMaintenance.
  ///
  /// In zh, this message translates to:
  /// **'单机维护'**
  String get singleServerMaintenance;

  /// No description provided for @powerControl.
  ///
  /// In zh, this message translates to:
  /// **'电源控制'**
  String get powerControl;

  /// No description provided for @powerControlDescription.
  ///
  /// In zh, this message translates to:
  /// **'通过 SSH 重启或关机 · 操作前核对目标'**
  String get powerControlDescription;

  /// No description provided for @powerControlWarning.
  ///
  /// In zh, this message translates to:
  /// **'关机后无法通过 SSH 开机，需使用厂商面板。重启或关机不会停止厂商计费。'**
  String get powerControlWarning;

  /// No description provided for @uiTabsCalculatorTile.
  ///
  /// In zh, this message translates to:
  /// **'独立试算或引用服务器，可导出不含隐私的图片'**
  String get uiTabsCalculatorTile;

  /// No description provided for @uiTabsSshTile.
  ///
  /// In zh, this message translates to:
  /// **'选择已配置的服务器'**
  String get uiTabsSshTile;

  /// No description provided for @uiTabsTcpTile.
  ///
  /// In zh, this message translates to:
  /// **'单目标端口探测'**
  String get uiTabsTcpTile;

  /// No description provided for @uiTabsSnippetsTile.
  ///
  /// In zh, this message translates to:
  /// **'常用命令，插入草稿后发送'**
  String get uiTabsSnippetsTile;

  /// No description provided for @uiTabsPowerTile.
  ///
  /// In zh, this message translates to:
  /// **'经 SSH 重启或关机'**
  String get uiTabsPowerTile;

  /// No description provided for @uiTabsLedgerSection.
  ///
  /// In zh, this message translates to:
  /// **'台账'**
  String get uiTabsLedgerSection;

  /// No description provided for @uiTabsSecuritySection.
  ///
  /// In zh, this message translates to:
  /// **'安全'**
  String get uiTabsSecuritySection;

  /// No description provided for @uiTabsPreferencesSection.
  ///
  /// In zh, this message translates to:
  /// **'偏好'**
  String get uiTabsPreferencesSection;

  /// No description provided for @uiTabsDataSection.
  ///
  /// In zh, this message translates to:
  /// **'数据'**
  String get uiTabsDataSection;

  /// No description provided for @uiTabsNotifyAllowed.
  ///
  /// In zh, this message translates to:
  /// **'已允许'**
  String get uiTabsNotifyAllowed;

  /// No description provided for @uiTabsNotifyDenied.
  ///
  /// In zh, this message translates to:
  /// **'未允许'**
  String get uiTabsNotifyDenied;

  /// No description provided for @uiTabsNotifyUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'不支持'**
  String get uiTabsNotifyUnsupported;

  /// No description provided for @uiTabsNotifyUnchecked.
  ///
  /// In zh, this message translates to:
  /// **'未检查'**
  String get uiTabsNotifyUnchecked;

  /// No description provided for @uiTabsNotifyChecking.
  ///
  /// In zh, this message translates to:
  /// **'检查中'**
  String get uiTabsNotifyChecking;

  /// No description provided for @uiTabsNotifyFailed.
  ///
  /// In zh, this message translates to:
  /// **'检查失败'**
  String get uiTabsNotifyFailed;

  /// No description provided for @usageContinue.
  ///
  /// In zh, this message translates to:
  /// **'继续使用'**
  String get usageContinue;

  /// No description provided for @usageUndecided.
  ///
  /// In zh, this message translates to:
  /// **'待决定'**
  String get usageUndecided;

  /// No description provided for @usageStop.
  ///
  /// In zh, this message translates to:
  /// **'到期不再使用'**
  String get usageStop;

  /// No description provided for @reminderNoDays.
  ///
  /// In zh, this message translates to:
  /// **'未选择提醒日期'**
  String get reminderNoDays;

  /// No description provided for @reminderOnDueDate.
  ///
  /// In zh, this message translates to:
  /// **'到期当天'**
  String get reminderOnDueDate;

  /// No description provided for @reminderDaysBefore.
  ///
  /// In zh, this message translates to:
  /// **'提前 {p0} 天'**
  String reminderDaysBefore(int p0);

  /// No description provided for @notificationStatus.
  ///
  /// In zh, this message translates to:
  /// **'通知权限与提醒状态'**
  String get notificationStatus;

  /// No description provided for @reminderLastTimezone.
  ///
  /// In zh, this message translates to:
  /// **'最近安排提醒时使用的时区：{p0}'**
  String reminderLastTimezone(String p0);

  /// No description provided for @reminderEnableHelp.
  ///
  /// In zh, this message translates to:
  /// **'需同时开启系统通知和服务器提醒。各服务器的提前天数、时间和使用计划可在详情中编辑；未允许通知时仍可保存规则。'**
  String get reminderEnableHelp;

  /// No description provided for @requestingPermission.
  ///
  /// In zh, this message translates to:
  /// **'正在申请…'**
  String get requestingPermission;

  /// No description provided for @requestNotificationPermission.
  ///
  /// In zh, this message translates to:
  /// **'申请系统通知权限'**
  String get requestNotificationPermission;

  /// No description provided for @notificationPermissionHelp.
  ///
  /// In zh, this message translates to:
  /// **'已拒绝或关闭通知渠道时，请到设备系统设置中调整；修改后返回应用，重新核对提醒状态。'**
  String get notificationPermissionHelp;

  /// No description provided for @checkReminderStatus.
  ///
  /// In zh, this message translates to:
  /// **'重新核对提醒状态'**
  String get checkReminderStatus;

  /// No description provided for @reminderCoverage.
  ///
  /// In zh, this message translates to:
  /// **'提醒范围'**
  String get reminderCoverage;

  /// No description provided for @r2TabsMetricScheduled.
  ///
  /// In zh, this message translates to:
  /// **'已安排'**
  String get r2TabsMetricScheduled;

  /// No description provided for @r2TabsMetricNotCovered.
  ///
  /// In zh, this message translates to:
  /// **'未覆盖'**
  String get r2TabsMetricNotCovered;

  /// No description provided for @r2TabsMetricNoReminder.
  ///
  /// In zh, this message translates to:
  /// **'未提醒'**
  String get r2TabsMetricNoReminder;

  /// No description provided for @r2TabsUpcoming.
  ///
  /// In zh, this message translates to:
  /// **'即将提醒'**
  String get r2TabsUpcoming;

  /// No description provided for @r2TabsShowAll.
  ///
  /// In zh, this message translates to:
  /// **'显示全部（{n}）'**
  String r2TabsShowAll(String n);

  /// No description provided for @r2TabsToday.
  ///
  /// In zh, this message translates to:
  /// **'今天'**
  String get r2TabsToday;

  /// No description provided for @r2TabsTomorrow.
  ///
  /// In zh, this message translates to:
  /// **'明天'**
  String get r2TabsTomorrow;

  /// No description provided for @r2TabsWithinWeek.
  ///
  /// In zh, this message translates to:
  /// **'7 天内'**
  String get r2TabsWithinWeek;

  /// No description provided for @r2TabsMonth.
  ///
  /// In zh, this message translates to:
  /// **'{year} 年 {month} 月'**
  String r2TabsMonth(String year, String month);

  /// No description provided for @r2TabsRowSub.
  ///
  /// In zh, this message translates to:
  /// **'{lead} · 到期 {due}'**
  String r2TabsRowSub(String lead, String due);

  /// No description provided for @r2TabsNotCoveredPill.
  ///
  /// In zh, this message translates to:
  /// **'未覆盖'**
  String get r2TabsNotCoveredPill;

  /// No description provided for @r2TabsCoverageNote.
  ///
  /// In zh, this message translates to:
  /// **'超出系统上限（iOS 64 / Android 256）或 366 天以后的提醒不会安排。'**
  String get r2TabsCoverageNote;

  /// No description provided for @r2TabsNoReminderServers.
  ///
  /// In zh, this message translates to:
  /// **'未提醒的服务器'**
  String get r2TabsNoReminderServers;

  /// No description provided for @r2TabsReasonArchived.
  ///
  /// In zh, this message translates to:
  /// **'已归档'**
  String get r2TabsReasonArchived;

  /// No description provided for @r2TabsReasonDemo.
  ///
  /// In zh, this message translates to:
  /// **'演示数据'**
  String get r2TabsReasonDemo;

  /// No description provided for @r2TabsReasonNoDate.
  ///
  /// In zh, this message translates to:
  /// **'未填到期日'**
  String get r2TabsReasonNoDate;

  /// No description provided for @r2TabsReasonNotPrepaid.
  ///
  /// In zh, this message translates to:
  /// **'非预付费'**
  String get r2TabsReasonNotPrepaid;

  /// No description provided for @r2TabsReasonOff.
  ///
  /// In zh, this message translates to:
  /// **'提醒已关闭'**
  String get r2TabsReasonOff;

  /// No description provided for @r2TabsReasonNoUpcoming.
  ///
  /// In zh, this message translates to:
  /// **'暂无待发提醒'**
  String get r2TabsReasonNoUpcoming;

  /// No description provided for @r2TabsAllReminders.
  ///
  /// In zh, this message translates to:
  /// **'全部提醒'**
  String get r2TabsAllReminders;

  /// No description provided for @r2TabsFilterAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get r2TabsFilterAll;

  /// No description provided for @r2TabsSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索服务器名称'**
  String get r2TabsSearchHint;

  /// No description provided for @r2TabsEmpty.
  ///
  /// In zh, this message translates to:
  /// **'没有符合条件的项目'**
  String get r2TabsEmpty;

  /// No description provided for @r2TabsNoUpcoming.
  ///
  /// In zh, this message translates to:
  /// **'暂无即将提醒'**
  String get r2TabsNoUpcoming;

  /// No description provided for @r2TabsEnableHelp.
  ///
  /// In zh, this message translates to:
  /// **'需同时开启系统通知和各服务器的提醒。'**
  String get r2TabsEnableHelp;

  /// No description provided for @r2TabsPermissionHelp.
  ///
  /// In zh, this message translates to:
  /// **'已拒绝时，请到系统设置中开启通知。'**
  String get r2TabsPermissionHelp;

  /// No description provided for @r2TabsNotifyScheduled.
  ///
  /// In zh, this message translates to:
  /// **'已安排 {n} 条'**
  String r2TabsNotifyScheduled(String n);

  /// No description provided for @reminderHorizonHelp.
  ///
  /// In zh, this message translates to:
  /// **'只提交未来 366 天内已知的到期提醒；过去的提醒时间不补发。iOS 最多排入最近 64 条，Android 最多 256 条，其余显示为未安排。请定期打开应用更新提醒。'**
  String get reminderHorizonHelp;

  /// No description provided for @reminderDeliveryHelp.
  ///
  /// In zh, this message translates to:
  /// **'应用回到前台会重新读取权限和设备时区。旅行后请打开应用核对；未打开时已提交的提醒可能仍按旧时区投递。系统节电、专注模式及厂商限制可能延迟或阻止提醒，已安排不代表已经送达。'**
  String get reminderDeliveryHelp;

  /// No description provided for @reminderPrivacyHelp.
  ///
  /// In zh, this message translates to:
  /// **'提醒内容只包含到期日期和核对提示，不包含服务器名称、地址、账户或金额。不自动付款、不修改厂商续费设置。'**
  String get reminderPrivacyHelp;

  /// No description provided for @reminderRulesSaved.
  ///
  /// In zh, this message translates to:
  /// **'提醒规则已保存。请在“设置 / 通知权限”查看系统提醒状态。'**
  String get reminderRulesSaved;

  /// No description provided for @localExpiryReminders.
  ///
  /// In zh, this message translates to:
  /// **'本机到期提醒'**
  String get localExpiryReminders;

  /// No description provided for @back.
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get back;

  /// No description provided for @recordMissingReload.
  ///
  /// In zh, this message translates to:
  /// **'记录不存在，请返回重新读取。'**
  String get recordMissingReload;

  /// No description provided for @dueDateNotEntered.
  ///
  /// In zh, this message translates to:
  /// **'未填写到期日'**
  String get dueDateNotEntered;

  /// No description provided for @reminderSaveHelp.
  ///
  /// In zh, this message translates to:
  /// **'修改后点“保存提醒规则”生效。若启用提醒并选择“到期不再使用”，仍会提醒核对厂商的续费设置。'**
  String get reminderSaveHelp;

  /// No description provided for @uiTabsReminderSaveHelp.
  ///
  /// In zh, this message translates to:
  /// **'点右上角“保存”后生效。'**
  String get uiTabsReminderSaveHelp;

  /// No description provided for @uiTabsReminderDue.
  ///
  /// In zh, this message translates to:
  /// **'{name} 将于 {date} 到期。'**
  String uiTabsReminderDue(String name, String date);

  /// No description provided for @uiTabsReminderPreview.
  ///
  /// In zh, this message translates to:
  /// **'将在 {dates} {time} 提醒（设备时区）。通知不包含名称、IP 或金额。'**
  String uiTabsReminderPreview(String dates, String time);

  /// No description provided for @uiTabsReminderPreviewNone.
  ///
  /// In zh, this message translates to:
  /// **'按当前设置没有未来的提醒时间。通知不包含名称、IP 或金额。'**
  String get uiTabsReminderPreviewNone;

  /// No description provided for @uiTabsUsageContinueHint.
  ///
  /// In zh, this message translates to:
  /// **'到期前提醒续费'**
  String get uiTabsUsageContinueHint;

  /// No description provided for @uiTabsUsageUndecidedHint.
  ///
  /// In zh, this message translates to:
  /// **'提醒你做出决定'**
  String get uiTabsUsageUndecidedHint;

  /// No description provided for @uiTabsUsageStopHint.
  ///
  /// In zh, this message translates to:
  /// **'仍提醒核对并取消自动续费'**
  String get uiTabsUsageStopHint;

  /// No description provided for @demoNoNotifications.
  ///
  /// In zh, this message translates to:
  /// **'演示数据不会提交真实系统通知。'**
  String get demoNoNotifications;

  /// No description provided for @archivedNoReminders.
  ///
  /// In zh, this message translates to:
  /// **'已归档记录不会排程提醒。'**
  String get archivedNoReminders;

  /// No description provided for @enableServerReminders.
  ///
  /// In zh, this message translates to:
  /// **'启用此服务器的提醒'**
  String get enableServerReminders;

  /// No description provided for @reminderOnlyHelp.
  ///
  /// In zh, this message translates to:
  /// **'仅提醒，不自动续费或取消服务'**
  String get reminderOnlyHelp;

  /// No description provided for @daysBefore.
  ///
  /// In zh, this message translates to:
  /// **'提前几天'**
  String get daysBefore;

  /// No description provided for @sameDay.
  ///
  /// In zh, this message translates to:
  /// **'当天'**
  String get sameDay;

  /// No description provided for @dayCount.
  ///
  /// In zh, this message translates to:
  /// **'{p0} 天'**
  String dayCount(int p0);

  /// No description provided for @reminderTime.
  ///
  /// In zh, this message translates to:
  /// **'提醒时间'**
  String get reminderTime;

  /// No description provided for @selectReminderTime.
  ///
  /// In zh, this message translates to:
  /// **'选择提醒时间'**
  String get selectReminderTime;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get confirm;

  /// No description provided for @hour.
  ///
  /// In zh, this message translates to:
  /// **'时'**
  String get hour;

  /// No description provided for @minute.
  ///
  /// In zh, this message translates to:
  /// **'分'**
  String get minute;

  /// No description provided for @invalidTime.
  ///
  /// In zh, this message translates to:
  /// **'请输入有效时间'**
  String get invalidTime;

  /// No description provided for @reminderDstHelp.
  ///
  /// In zh, this message translates to:
  /// **'按设备当前时区；夏令时缺失的时间顺延，重复的只提醒一次。'**
  String get reminderDstHelp;

  /// No description provided for @myUsagePlan.
  ///
  /// In zh, this message translates to:
  /// **'我的使用计划'**
  String get myUsagePlan;

  /// No description provided for @usagePlanWarning.
  ///
  /// In zh, this message translates to:
  /// **'使用计划仅为本地记录，不会停止厂商扣费；请另行向厂商取消续费。'**
  String get usagePlanWarning;

  /// No description provided for @savedRuleSchedule.
  ///
  /// In zh, this message translates to:
  /// **'已保存规则的提醒安排'**
  String get savedRuleSchedule;

  /// No description provided for @serverScheduledCount.
  ///
  /// In zh, this message translates to:
  /// **'本服务器已安排 {p0} 条'**
  String serverScheduledCount(String p0);

  /// No description provided for @viewReminderCoverage.
  ///
  /// In zh, this message translates to:
  /// **'查看通知权限与覆盖范围'**
  String get viewReminderCoverage;

  /// No description provided for @saving.
  ///
  /// In zh, this message translates to:
  /// **'正在保存…'**
  String get saving;

  /// No description provided for @saveReminderRules.
  ///
  /// In zh, this message translates to:
  /// **'保存提醒规则'**
  String get saveReminderRules;

  /// No description provided for @expiryNotificationTitle.
  ///
  /// In zh, this message translates to:
  /// **'VPS 到期核对'**
  String get expiryNotificationTitle;

  /// No description provided for @notificationDueDate.
  ///
  /// In zh, this message translates to:
  /// **'到期日为 {p0}'**
  String notificationDueDate(String p0);

  /// No description provided for @notificationStopBody.
  ///
  /// In zh, this message translates to:
  /// **'有服务{p0}，请核对厂商是否已取消续费。本地计划不会停止扣费。'**
  String notificationStopBody(String p0);

  /// No description provided for @notificationContinueBody.
  ///
  /// In zh, this message translates to:
  /// **'有服务{p0}，请核对厂商账单与使用计划。本提醒不会自动付款。'**
  String notificationContinueBody(String p0);

  /// No description provided for @expiryChecks.
  ///
  /// In zh, this message translates to:
  /// **'到期核对'**
  String get expiryChecks;

  /// No description provided for @expiryChannelDescription.
  ///
  /// In zh, this message translates to:
  /// **'本地到期提醒，不自动续费或付款'**
  String get expiryChannelDescription;

  /// No description provided for @reminderNotChecked.
  ///
  /// In zh, this message translates to:
  /// **'尚未检查系统通知'**
  String get reminderNotChecked;

  /// No description provided for @reminderChecking.
  ///
  /// In zh, this message translates to:
  /// **'正在核对系统提醒…'**
  String get reminderChecking;

  /// No description provided for @reminderScheduleCounts.
  ///
  /// In zh, this message translates to:
  /// **'已安排 {p0} 条提醒 · 未安排 {p1} 条'**
  String reminderScheduleCounts(String p0, String p1);

  /// No description provided for @reminderPermissionDenied.
  ///
  /// In zh, this message translates to:
  /// **'系统通知未获允许或通知渠道已关闭；已保存规则仍保留'**
  String get reminderPermissionDenied;

  /// No description provided for @reminderUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'此平台不支持定时通知；已保存规则不会在此设备触发提醒'**
  String get reminderUnsupported;

  /// No description provided for @reminderCheckFailed.
  ///
  /// In zh, this message translates to:
  /// **'提醒状态核对失败，可能仍有旧提醒；请重试或检查系统设置'**
  String get reminderCheckFailed;

  /// No description provided for @jsonLedgerBackup.
  ///
  /// In zh, this message translates to:
  /// **'JSON 台账备份'**
  String get jsonLedgerBackup;

  /// No description provided for @backupTooLarge.
  ///
  /// In zh, this message translates to:
  /// **'备份超过 10 MiB 上限'**
  String get backupTooLarge;

  /// No description provided for @backupExportInvalid.
  ///
  /// In zh, this message translates to:
  /// **'导出校验失败，未保存或分享备份。台账未改动。'**
  String get backupExportInvalid;

  /// No description provided for @backupShareSelected.
  ///
  /// In zh, this message translates to:
  /// **'已选择系统分享操作，请在目标应用核对文件是否保存或送达。'**
  String get backupShareSelected;

  /// No description provided for @backupShareCancelled.
  ///
  /// In zh, this message translates to:
  /// **'已取消分享，备份预览仍保留。'**
  String get backupShareCancelled;

  /// No description provided for @backupShareUnknown.
  ///
  /// In zh, this message translates to:
  /// **'未收到系统分享结果，备份预览仍保留。'**
  String get backupShareUnknown;

  /// No description provided for @systemShareUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'此平台不支持系统分享。'**
  String get systemShareUnsupported;

  /// No description provided for @completeCurrentShare.
  ///
  /// In zh, this message translates to:
  /// **'请先完成当前分享操作。'**
  String get completeCurrentShare;

  /// No description provided for @backupShareFailed.
  ///
  /// In zh, this message translates to:
  /// **'分享未完成，备份预览仍保留。'**
  String get backupShareFailed;

  /// No description provided for @backupSaveCancelled.
  ///
  /// In zh, this message translates to:
  /// **'已取消保存，备份预览仍保留。'**
  String get backupSaveCancelled;

  /// No description provided for @backupSavedPath.
  ///
  /// In zh, this message translates to:
  /// **'备份已保存：\n{p0}'**
  String backupSavedPath(String p0);

  /// No description provided for @backupSaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'备份保存未完成，请检查空间与权限后重试。'**
  String get backupSaveFailed;

  /// No description provided for @backupSelectionCancelled.
  ///
  /// In zh, this message translates to:
  /// **'已取消选择备份。'**
  String get backupSelectionCancelled;

  /// No description provided for @backupReadInvalid.
  ///
  /// In zh, this message translates to:
  /// **'读取或校验失败。请选择格式 v1 或 v2、10 MiB 以内的完整 JSON 台账备份；现有数据未改动。'**
  String get backupReadInvalid;

  /// No description provided for @restoreEmptyLedgerQuestion.
  ///
  /// In zh, this message translates to:
  /// **'恢复到当前空台账？'**
  String get restoreEmptyLedgerQuestion;

  /// No description provided for @restoreConfirmation.
  ///
  /// In zh, this message translates to:
  /// **'{p0}\n保留原始 ID、金额和付款撤销状态；替换手动参考汇率。备注、连接、安全资料和提醒规则不恢复，导入服务器的提醒保持关闭。恢复不会连接或续费服务器。'**
  String restoreConfirmation(String p0);

  /// No description provided for @confirmRestore.
  ///
  /// In zh, this message translates to:
  /// **'确认恢复'**
  String get confirmRestore;

  /// No description provided for @ledgerRestored.
  ///
  /// In zh, this message translates to:
  /// **'台账已恢复。请重新配置连接与提醒；本次未连接任何服务器。'**
  String get ledgerRestored;

  /// No description provided for @restoreFailed.
  ///
  /// In zh, this message translates to:
  /// **'恢复未完成，现有数据未改动。恢复仅支持空台账，请重新选择备份并核对。'**
  String get restoreFailed;

  /// No description provided for @deviceTime.
  ///
  /// In zh, this message translates to:
  /// **'{p0}（设备时间）'**
  String deviceTime(String p0);

  /// No description provided for @backupCounts.
  ///
  /// In zh, this message translates to:
  /// **'{p0} 台服务器 · {p1} 个分组\n{p2} 笔付款（含撤销） · {p3} 个服务期'**
  String backupCounts(String p0, String p1, String p2, String p3);

  /// No description provided for @ledgerBackupRestore.
  ///
  /// In zh, this message translates to:
  /// **'台账备份与恢复'**
  String get ledgerBackupRestore;

  /// No description provided for @plainJsonVersion.
  ///
  /// In zh, this message translates to:
  /// **'明文 JSON · 格式 v2'**
  String get plainJsonVersion;

  /// No description provided for @backupContentsWarning.
  ///
  /// In zh, this message translates to:
  /// **'包含服务器名称、厂商、地址、地区、用途、系统、规格、硬件信息、分组、金额、日期、付款和手动汇率。文件未加密，请妥善保管，只分享到可信位置。上述字段若填写了敏感内容，也会随文件导出。'**
  String get backupContentsWarning;

  /// No description provided for @notIncluded.
  ///
  /// In zh, this message translates to:
  /// **'不包含：'**
  String get notIncluded;

  /// No description provided for @generateBackupPreview.
  ///
  /// In zh, this message translates to:
  /// **'生成导出预览'**
  String get generateBackupPreview;

  /// No description provided for @exportPreview.
  ///
  /// In zh, this message translates to:
  /// **'导出预览'**
  String get exportPreview;

  /// No description provided for @backupGeneratedTime.
  ///
  /// In zh, this message translates to:
  /// **'备份生成时间：{p0}'**
  String backupGeneratedTime(String p0);

  /// No description provided for @shareUnencryptedBackup.
  ///
  /// In zh, this message translates to:
  /// **'分享未加密备份'**
  String get shareUnencryptedBackup;

  /// No description provided for @saveJsonBackup.
  ///
  /// In zh, this message translates to:
  /// **'保存 JSON 备份'**
  String get saveJsonBackup;

  /// No description provided for @restoreEmptyOnlyHelp.
  ///
  /// In zh, this message translates to:
  /// **'仅支持恢复到没有服务器、分组、付款和服务期的空台账。不会覆盖或合并现有数据。导入服务器的提醒默认关闭，应用偏好保持不变。'**
  String get restoreEmptyOnlyHelp;

  /// No description provided for @chooseJsonPreviewRestore.
  ///
  /// In zh, this message translates to:
  /// **'选择 JSON 并预览恢复'**
  String get chooseJsonPreviewRestore;

  /// No description provided for @restorePreview.
  ///
  /// In zh, this message translates to:
  /// **'恢复预览'**
  String get restorePreview;

  /// No description provided for @backupTime.
  ///
  /// In zh, this message translates to:
  /// **'备份时间：{p0}'**
  String backupTime(String p0);

  /// No description provided for @restoreContentsHelp.
  ///
  /// In zh, this message translates to:
  /// **'仅导入台账记录和手动汇率；上方所列内容不在备份内。'**
  String get restoreContentsHelp;

  /// No description provided for @restoreToEmptyLedger.
  ///
  /// In zh, this message translates to:
  /// **'恢复到空台账'**
  String get restoreToEmptyLedger;

  /// No description provided for @appearance.
  ///
  /// In zh, this message translates to:
  /// **'外观'**
  String get appearance;

  /// No description provided for @followSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get followSystem;

  /// No description provided for @lightTheme.
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get lightTheme;

  /// No description provided for @darkTheme.
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get darkTheme;

  /// No description provided for @appDescription.
  ///
  /// In zh, this message translates to:
  /// **'到期、费用、连接，都在本机'**
  String get appDescription;

  /// No description provided for @r11AppSlogan.
  ///
  /// In zh, this message translates to:
  /// **'每台 VPS，心里有数'**
  String get r11AppSlogan;

  /// No description provided for @organizationData.
  ///
  /// In zh, this message translates to:
  /// **'组织与数据'**
  String get organizationData;

  /// No description provided for @manageGroups.
  ///
  /// In zh, this message translates to:
  /// **'分组管理'**
  String get manageGroups;

  /// No description provided for @groupCountHelp.
  ///
  /// In zh, this message translates to:
  /// **'{p0} 个分组 · 删除分组保留记录'**
  String groupCountHelp(String p0);

  /// No description provided for @archivedRecords.
  ///
  /// In zh, this message translates to:
  /// **'已归档记录'**
  String get archivedRecords;

  /// No description provided for @archiveCountHelp.
  ///
  /// In zh, this message translates to:
  /// **'{p0} 条 · 可恢复到服务器列表'**
  String archiveCountHelp(String p0);

  /// No description provided for @accountsPreferences.
  ///
  /// In zh, this message translates to:
  /// **'账户与偏好'**
  String get accountsPreferences;

  /// No description provided for @keysSecurity.
  ///
  /// In zh, this message translates to:
  /// **'密钥与安全'**
  String get keysSecurity;

  /// No description provided for @keysSecurityDescription.
  ///
  /// In zh, this message translates to:
  /// **'凭据、SSH 配置与主机信任'**
  String get keysSecurityDescription;

  /// No description provided for @currenciesReferenceRates.
  ///
  /// In zh, this message translates to:
  /// **'币种与参考汇率'**
  String get currenciesReferenceRates;

  /// No description provided for @currencyRateSummary.
  ///
  /// In zh, this message translates to:
  /// **'{p0} · 手动汇率 {p1}'**
  String currencyRateSummary(String p0, String p1);

  /// No description provided for @notSet.
  ///
  /// In zh, this message translates to:
  /// **'未设置'**
  String get notSet;

  /// No description provided for @notificationAccess.
  ///
  /// In zh, this message translates to:
  /// **'通知权限'**
  String get notificationAccess;

  /// No description provided for @backupExclusionsSummary.
  ///
  /// In zh, this message translates to:
  /// **'不含凭据与主机信任 · 未加密 JSON'**
  String get backupExclusionsSummary;

  /// No description provided for @about.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get about;

  /// No description provided for @developmentVersion.
  ///
  /// In zh, this message translates to:
  /// **'版本 {version}'**
  String developmentVersion(String version);

  /// No description provided for @appLocalDataHelp.
  ///
  /// In zh, this message translates to:
  /// **'数据仅保存在本机，无需账号。归档不会取消服务或停止扣费。'**
  String get appLocalDataHelp;

  /// No description provided for @groupSaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'未能保存分组。请检查名称是否重复，再重试。'**
  String get groupSaveFailed;

  /// No description provided for @deleteGroupQuestion.
  ///
  /// In zh, this message translates to:
  /// **'删除“{p0}”？'**
  String deleteGroupQuestion(String p0);

  /// No description provided for @deleteGroupHelp.
  ///
  /// In zh, this message translates to:
  /// **'组内所有服务器（含已归档）将移到“未分组”，服务器资料和历史付款保留。不会修改远端服务器。'**
  String get deleteGroupHelp;

  /// No description provided for @deleteGroup.
  ///
  /// In zh, this message translates to:
  /// **'删除分组'**
  String get deleteGroup;

  /// No description provided for @addGroup.
  ///
  /// In zh, this message translates to:
  /// **'新增分组'**
  String get addGroup;

  /// No description provided for @groupsHelp.
  ///
  /// In zh, this message translates to:
  /// **'按用途整理服务器。'**
  String get groupsHelp;

  /// No description provided for @noGroupsHelp.
  ///
  /// In zh, this message translates to:
  /// **'还没有自定义分组，点右上角 + 新建。'**
  String get noGroupsHelp;

  /// No description provided for @unarchivedServerCount.
  ///
  /// In zh, this message translates to:
  /// **'{p0} 台未归档服务器'**
  String unarchivedServerCount(String p0);

  /// No description provided for @actionsForGroup.
  ///
  /// In zh, this message translates to:
  /// **'{p0}的操作'**
  String actionsForGroup(String p0);

  /// No description provided for @rename.
  ///
  /// In zh, this message translates to:
  /// **'重命名'**
  String get rename;

  /// No description provided for @moveUp.
  ///
  /// In zh, this message translates to:
  /// **'上移'**
  String get moveUp;

  /// No description provided for @moveDown.
  ///
  /// In zh, this message translates to:
  /// **'下移'**
  String get moveDown;

  /// No description provided for @ungrouped.
  ///
  /// In zh, this message translates to:
  /// **'未分组'**
  String get ungrouped;

  /// No description provided for @ungroupedCountHelp.
  ///
  /// In zh, this message translates to:
  /// **'{p0} 台未归档服务器 · 默认分组，不可删除'**
  String ungroupedCountHelp(String p0);

  /// No description provided for @archiveHelp.
  ///
  /// In zh, this message translates to:
  /// **'归档保留资料；恢复不会启动或续费服务。'**
  String get archiveHelp;

  /// No description provided for @noArchivedRecords.
  ///
  /// In zh, this message translates to:
  /// **'没有已归档记录'**
  String get noArchivedRecords;

  /// No description provided for @restoreRecord.
  ///
  /// In zh, this message translates to:
  /// **'恢复记录'**
  String get restoreRecord;

  /// No description provided for @renameGroup.
  ///
  /// In zh, this message translates to:
  /// **'重命名分组'**
  String get renameGroup;

  /// No description provided for @groupName.
  ///
  /// In zh, this message translates to:
  /// **'分组名称'**
  String get groupName;

  /// No description provided for @save.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get save;

  /// No description provided for @operationFailed.
  ///
  /// In zh, this message translates to:
  /// **'操作未完成，请重试。已保存的资料仍保留。'**
  String get operationFailed;

  /// No description provided for @recordChanged.
  ///
  /// In zh, this message translates to:
  /// **'记录已发生变化，请返回后重试'**
  String get recordChanged;

  /// No description provided for @gotIt.
  ///
  /// In zh, this message translates to:
  /// **'知道了'**
  String get gotIt;

  /// No description provided for @financeCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get financeCancel;

  /// No description provided for @financeSaving.
  ///
  /// In zh, this message translates to:
  /// **'正在保存…'**
  String get financeSaving;

  /// No description provided for @financeUnknown.
  ///
  /// In zh, this message translates to:
  /// **'未知'**
  String get financeUnknown;

  /// No description provided for @financeNotSet.
  ///
  /// In zh, this message translates to:
  /// **'未设置'**
  String get financeNotSet;

  /// No description provided for @financeDateNotSet.
  ///
  /// In zh, this message translates to:
  /// **'未设置日期'**
  String get financeDateNotSet;

  /// No description provided for @financePayments.
  ///
  /// In zh, this message translates to:
  /// **'付款记录'**
  String get financePayments;

  /// No description provided for @financeCalculationRules.
  ///
  /// In zh, this message translates to:
  /// **'统计口径'**
  String get financeCalculationRules;

  /// No description provided for @financeAllGroups.
  ///
  /// In zh, this message translates to:
  /// **'全部分组'**
  String get financeAllGroups;

  /// No description provided for @financeUngrouped.
  ///
  /// In zh, this message translates to:
  /// **'未分组'**
  String get financeUngrouped;

  /// No description provided for @financeNotEntered.
  ///
  /// In zh, this message translates to:
  /// **'未填写'**
  String get financeNotEntered;

  /// No description provided for @financeNote.
  ///
  /// In zh, this message translates to:
  /// **'备注'**
  String get financeNote;

  /// No description provided for @financeStatus.
  ///
  /// In zh, this message translates to:
  /// **'状态'**
  String get financeStatus;

  /// No description provided for @financeEstimatedOnly.
  ///
  /// In zh, this message translates to:
  /// **'试算 · 不入账'**
  String get financeEstimatedOnly;

  /// No description provided for @financeValueTitle.
  ///
  /// In zh, this message translates to:
  /// **'剩余价值 · 按当前续费价折算'**
  String get financeValueTitle;

  /// No description provided for @financeNotApplicable.
  ///
  /// In zh, this message translates to:
  /// **'不适用 / 未纳入'**
  String get financeNotApplicable;

  /// No description provided for @financeDataUnknown.
  ///
  /// In zh, this message translates to:
  /// **'资料未知'**
  String get financeDataUnknown;

  /// No description provided for @financeMissingFxPreserved.
  ///
  /// In zh, this message translates to:
  /// **'缺少汇率 · 原币仍保留'**
  String get financeMissingFxPreserved;

  /// No description provided for @financeMissingFxExcluded.
  ///
  /// In zh, this message translates to:
  /// **'仅合计有汇率的部分，缺失部分未按 0 计算'**
  String get financeMissingFxExcluded;

  /// No description provided for @financeValuationAndDue.
  ///
  /// In zh, this message translates to:
  /// **'估值日 / 服务到期日'**
  String get financeValuationAndDue;

  /// No description provided for @financeRemainingDays.
  ///
  /// In zh, this message translates to:
  /// **'剩余服务天数'**
  String get financeRemainingDays;

  /// No description provided for @financeRenewalCycle.
  ///
  /// In zh, this message translates to:
  /// **'续费 / 周期'**
  String get financeRenewalCycle;

  /// No description provided for @financeDailyShown.
  ///
  /// In zh, this message translates to:
  /// **'所示周期日均'**
  String get financeDailyShown;

  /// No description provided for @r2CopyMetricDaysLeft.
  ///
  /// In zh, this message translates to:
  /// **'剩余天数'**
  String get r2CopyMetricDaysLeft;

  /// No description provided for @r2CopyMetricDaily.
  ///
  /// In zh, this message translates to:
  /// **'日均'**
  String get r2CopyMetricDaily;

  /// No description provided for @financeInferredPeriods.
  ///
  /// In zh, this message translates to:
  /// **'服务起点由到期日反推，不代表付款证明。'**
  String get financeInferredPeriods;

  /// No description provided for @financeValueDisclaimer.
  ///
  /// In zh, this message translates to:
  /// **'按剩余时长折算，不是退款承诺或成交价。'**
  String get financeValueDisclaimer;

  /// No description provided for @financeShownPeriod.
  ///
  /// In zh, this message translates to:
  /// **'所示周期'**
  String get financeShownPeriod;

  /// No description provided for @financeFuturePeriod.
  ///
  /// In zh, this message translates to:
  /// **'尚未开始的周期'**
  String get financeFuturePeriod;

  /// No description provided for @financeEndedPeriod.
  ///
  /// In zh, this message translates to:
  /// **'已结束的周期'**
  String get financeEndedPeriod;

  /// No description provided for @financeCurrentPeriod.
  ///
  /// In zh, this message translates to:
  /// **'当前周期'**
  String get financeCurrentPeriod;

  /// No description provided for @financeFxTitle.
  ///
  /// In zh, this message translates to:
  /// **'币种与参考汇率'**
  String get financeFxTitle;

  /// No description provided for @financeFxScope.
  ///
  /// In zh, this message translates to:
  /// **'仅影响参考折算，不联网取汇率；留空表示未知。'**
  String get financeFxScope;

  /// No description provided for @financeDisplayCurrency.
  ///
  /// In zh, this message translates to:
  /// **'合计显示币种'**
  String get financeDisplayCurrency;

  /// No description provided for @financeUsdRate.
  ///
  /// In zh, this message translates to:
  /// **'1 USD = 多少 CNY'**
  String get financeUsdRate;

  /// No description provided for @financeEurRate.
  ///
  /// In zh, this message translates to:
  /// **'1 EUR = 多少 CNY'**
  String get financeEurRate;

  /// No description provided for @financeUnknownRateHint.
  ///
  /// In zh, this message translates to:
  /// **'留空表示汇率未知'**
  String get financeUnknownRateHint;

  /// No description provided for @financeRateError.
  ///
  /// In zh, this message translates to:
  /// **'请输入大于 0 的汇率，最多 8 位小数'**
  String get financeRateError;

  /// No description provided for @financeRateDate.
  ///
  /// In zh, this message translates to:
  /// **'汇率参考日期'**
  String get financeRateDate;

  /// No description provided for @financePastDateError.
  ///
  /// In zh, this message translates to:
  /// **'请输入不晚于今天的有效日期'**
  String get financePastDateError;

  /// No description provided for @financeFxBasis.
  ///
  /// In zh, this message translates to:
  /// **'以 CNY 为基准；缺少汇率的币种不计入合计。'**
  String get financeFxBasis;

  /// No description provided for @financeSaveFx.
  ///
  /// In zh, this message translates to:
  /// **'保存参考汇率'**
  String get financeSaveFx;

  /// No description provided for @financeReferenceTitle.
  ///
  /// In zh, this message translates to:
  /// **'引用服务器资料'**
  String get financeReferenceTitle;

  /// No description provided for @financeReferenceNote.
  ///
  /// In zh, this message translates to:
  /// **'仅复制当前续费资料，不会修改原服务器。'**
  String get financeReferenceNote;

  /// No description provided for @financeNoPrepaid.
  ///
  /// In zh, this message translates to:
  /// **'暂无预付费服务器，可使用独立试算。'**
  String get financeNoPrepaid;

  /// No description provided for @financeDateRangeError.
  ///
  /// In zh, this message translates to:
  /// **'请核对日期，试算范围限制为 100 年'**
  String get financeDateRangeError;

  /// No description provided for @financeMissingPeriodsError.
  ///
  /// In zh, this message translates to:
  /// **'引用资料缺少有效服务期。请先补充服务器日期，或修改到期日、周期后使用独立试算。'**
  String get financeMissingPeriodsError;

  /// No description provided for @financeCalculatorTitle.
  ///
  /// In zh, this message translates to:
  /// **'剩余价值计算器'**
  String get financeCalculatorTitle;

  /// No description provided for @financeReferenceServer.
  ///
  /// In zh, this message translates to:
  /// **'引用服务器'**
  String get financeReferenceServer;

  /// No description provided for @financeIndependentRebuilt.
  ///
  /// In zh, this message translates to:
  /// **'已切换为独立试算，按到期日和周期重新推算服务期。'**
  String get financeIndependentRebuilt;

  /// No description provided for @financeIndependentNote.
  ///
  /// In zh, this message translates to:
  /// **'独立试算，无需添加服务器；假设到期日前服务连续。'**
  String get financeIndependentNote;

  /// No description provided for @financeRenewalAmount.
  ///
  /// In zh, this message translates to:
  /// **'每周期续费金额'**
  String get financeRenewalAmount;

  /// No description provided for @financeAmountError.
  ///
  /// In zh, this message translates to:
  /// **'请填写有效金额，明确免费可填 0'**
  String get financeAmountError;

  /// No description provided for @financeOriginalCurrency.
  ///
  /// In zh, this message translates to:
  /// **'原币种'**
  String get financeOriginalCurrency;

  /// No description provided for @financeCycle.
  ///
  /// In zh, this message translates to:
  /// **'续费周期'**
  String get financeCycle;

  /// No description provided for @financeValuationDate.
  ///
  /// In zh, this message translates to:
  /// **'估值日期'**
  String get financeValuationDate;

  /// No description provided for @financeValuationDateError.
  ///
  /// In zh, this message translates to:
  /// **'请输入有效估值日'**
  String get financeValuationDateError;

  /// No description provided for @financeServiceDue.
  ///
  /// In zh, this message translates to:
  /// **'服务到期日'**
  String get financeServiceDue;

  /// No description provided for @financeDueError.
  ///
  /// In zh, this message translates to:
  /// **'请输入有效到期日'**
  String get financeDueError;

  /// No description provided for @r6CalcServiceStart.
  ///
  /// In zh, this message translates to:
  /// **'服务开始日期'**
  String get r6CalcServiceStart;

  /// No description provided for @r6CalcDueAutoNote.
  ///
  /// In zh, this message translates to:
  /// **'到期日按开始日期和周期自动推算；手动选择其他日期后不再自动更新。'**
  String get r6CalcDueAutoNote;

  /// No description provided for @financeAlgorithmTitle.
  ///
  /// In zh, this message translates to:
  /// **'周期与算法说明'**
  String get financeAlgorithmTitle;

  /// No description provided for @financeAlgorithmNote.
  ///
  /// In zh, this message translates to:
  /// **'剩余价值 = Σ（每周期续费金额 × 该周期未用天数比例）。\n日历周期按真实天数计算，不固定每月 30 天；月底由原到期日锚点倒推，年度处理闰年。估值早于已知开始日不会超过该期整价。\n独立模式向前倒推至覆盖估值日，限制 100 年。到期当天为 0，不检查服务能否转让或退款。'**
  String get financeAlgorithmNote;

  /// No description provided for @financeCalculateValue.
  ///
  /// In zh, this message translates to:
  /// **'计算剩余价值'**
  String get financeCalculateValue;

  /// No description provided for @financeEstimateNoWrite.
  ///
  /// In zh, this message translates to:
  /// **'试算不会改动任何服务器或付款。'**
  String get financeEstimateNoWrite;

  /// No description provided for @financeReferenceRateMissing.
  ///
  /// In zh, this message translates to:
  /// **'参考汇率缺失'**
  String get financeReferenceRateMissing;

  /// No description provided for @financeIndependentBasis.
  ///
  /// In zh, this message translates to:
  /// **'独立假设：到期日前服务连续有效，期间按到期日倒推。'**
  String get financeIndependentBasis;

  /// No description provided for @financeQuoteFxError.
  ///
  /// In zh, this message translates to:
  /// **'缺少对应汇率，不能计算参考价值与结算金额。'**
  String get financeQuoteFxError;

  /// No description provided for @financeCopied.
  ///
  /// In zh, this message translates to:
  /// **'计算结果已复制，仅包含计算信息'**
  String get financeCopied;

  /// No description provided for @financeCopyError.
  ///
  /// In zh, this message translates to:
  /// **'未能写入剪贴板，请重试'**
  String get financeCopyError;

  /// No description provided for @financeResultTitle.
  ///
  /// In zh, this message translates to:
  /// **'计算结果'**
  String get financeResultTitle;

  /// No description provided for @financeEditInputs.
  ///
  /// In zh, this message translates to:
  /// **'修改条件'**
  String get financeEditInputs;

  /// No description provided for @financeCopyResult.
  ///
  /// In zh, this message translates to:
  /// **'复制结果'**
  String get financeCopyResult;

  /// No description provided for @financePreviewPng.
  ///
  /// In zh, this message translates to:
  /// **'预览 / 保存 PNG'**
  String get financePreviewPng;

  /// No description provided for @financeQuoteTitle.
  ///
  /// In zh, this message translates to:
  /// **'转让报价试算 · 可选'**
  String get financeQuoteTitle;

  /// No description provided for @financeQuoteNote.
  ///
  /// In zh, this message translates to:
  /// **'仅按报价和手续费试算，不执行交易；请自行确认厂商是否允许转让。'**
  String get financeQuoteNote;

  /// No description provided for @financeQuoteAmountError.
  ///
  /// In zh, this message translates to:
  /// **'请输入 0 或正数报价'**
  String get financeQuoteAmountError;

  /// No description provided for @financeTransferFee.
  ///
  /// In zh, this message translates to:
  /// **'转移手续费（Push）'**
  String get financeTransferFee;

  /// No description provided for @financeQuoteFeeError.
  ///
  /// In zh, this message translates to:
  /// **'请输入 0 或正数手续费'**
  String get financeQuoteFeeError;

  /// No description provided for @financeFeeCurrency.
  ///
  /// In zh, this message translates to:
  /// **'手续费币种'**
  String get financeFeeCurrency;

  /// No description provided for @financeFeePayer.
  ///
  /// In zh, this message translates to:
  /// **'手续费承担'**
  String get financeFeePayer;

  /// No description provided for @financeBuyerPays.
  ///
  /// In zh, this message translates to:
  /// **'买家承担'**
  String get financeBuyerPays;

  /// No description provided for @financeSellerPays.
  ///
  /// In zh, this message translates to:
  /// **'卖家承担'**
  String get financeSellerPays;

  /// No description provided for @financeSplitFee.
  ///
  /// In zh, this message translates to:
  /// **'各承担一半'**
  String get financeSplitFee;

  /// No description provided for @financeSplitFeeNote.
  ///
  /// In zh, this message translates to:
  /// **'手续费先折算到分再均摊，不能均分的 0.01 由买方承担。'**
  String get financeSplitFeeNote;

  /// No description provided for @financeCalculateQuote.
  ///
  /// In zh, this message translates to:
  /// **'计算报价与费用'**
  String get financeCalculateQuote;

  /// No description provided for @financePremiumLabel.
  ///
  /// In zh, this message translates to:
  /// **'报价与参考价值差额（溢价 / 折价）'**
  String get financePremiumLabel;

  /// No description provided for @financeBuyerSellerFee.
  ///
  /// In zh, this message translates to:
  /// **'买方 / 卖方手续费'**
  String get financeBuyerSellerFee;

  /// No description provided for @financeBuyerEstimate.
  ///
  /// In zh, this message translates to:
  /// **'买方预计支出'**
  String get financeBuyerEstimate;

  /// No description provided for @financeSellerEstimate.
  ///
  /// In zh, this message translates to:
  /// **'卖方预计净收款'**
  String get financeSellerEstimate;

  /// No description provided for @financeAccountNameError.
  ///
  /// In zh, this message translates to:
  /// **'请填写账户显示名称'**
  String get financeAccountNameError;

  /// No description provided for @financePaidAmountError.
  ///
  /// In zh, this message translates to:
  /// **'请输入有效实付金额，0 表示免费'**
  String get financePaidAmountError;

  /// No description provided for @financeDateError.
  ///
  /// In zh, this message translates to:
  /// **'请输入有效日期，例如 2026-10-06'**
  String get financeDateError;

  /// No description provided for @financePaymentFutureError.
  ///
  /// In zh, this message translates to:
  /// **'付款日期不能晚于今天'**
  String get financePaymentFutureError;

  /// No description provided for @financePaymentConfirmError.
  ///
  /// In zh, this message translates to:
  /// **'请确认已完成厂商付款并核对资料'**
  String get financePaymentConfirmError;

  /// No description provided for @financeBillPeriodError.
  ///
  /// In zh, this message translates to:
  /// **'账期起止需同时填写，且结束日应晚于开始日'**
  String get financeBillPeriodError;

  /// No description provided for @financePaymentSavedRefresh.
  ///
  /// In zh, this message translates to:
  /// **'付款已保存，显示暂未更新，请重新读取。'**
  String get financePaymentSavedRefresh;

  /// No description provided for @financeAccountPaymentSaved.
  ///
  /// In zh, this message translates to:
  /// **'账户账单已记录一次，实例期限未改变'**
  String get financeAccountPaymentSaved;

  /// No description provided for @financePaymentSaved.
  ///
  /// In zh, this message translates to:
  /// **'付款已记录，服务期与统计已更新'**
  String get financePaymentSaved;

  /// No description provided for @financeRecordPayment.
  ///
  /// In zh, this message translates to:
  /// **'记录已付款'**
  String get financeRecordPayment;

  /// No description provided for @financeNoRenewalDate.
  ///
  /// In zh, this message translates to:
  /// **'没有可用的预付到期日，请先在服务器资料中核对。'**
  String get financeNoRenewalDate;

  /// No description provided for @financeRecordAccountBill.
  ///
  /// In zh, this message translates to:
  /// **'记录账户账单'**
  String get financeRecordAccountBill;

  /// No description provided for @financeLocalPaymentOnly.
  ///
  /// In zh, this message translates to:
  /// **'仅本地记账，不向厂商发起支付。'**
  String get financeLocalPaymentOnly;

  /// No description provided for @financeAccountBillNote.
  ///
  /// In zh, this message translates to:
  /// **'独立账单，仅计一次；不分摊，不产生服务期。'**
  String get financeAccountBillNote;

  /// No description provided for @financeAccountName.
  ///
  /// In zh, this message translates to:
  /// **'账户显示名称'**
  String get financeAccountName;

  /// No description provided for @financeAccountNameHint.
  ///
  /// In zh, this message translates to:
  /// **'例如：厂商 · 个人账户'**
  String get financeAccountNameHint;

  /// No description provided for @financePaidAmount.
  ///
  /// In zh, this message translates to:
  /// **'本次实付金额'**
  String get financePaidAmount;

  /// No description provided for @financePaidCurrency.
  ///
  /// In zh, this message translates to:
  /// **'实付币种'**
  String get financePaidCurrency;

  /// No description provided for @financePaidDate.
  ///
  /// In zh, this message translates to:
  /// **'实际付款日期'**
  String get financePaidDate;

  /// No description provided for @financeRenewalCount.
  ///
  /// In zh, this message translates to:
  /// **'本次续费周期数'**
  String get financeRenewalCount;

  /// No description provided for @financeNewDue.
  ///
  /// In zh, this message translates to:
  /// **'新到期日'**
  String get financeNewDue;

  /// No description provided for @financeNewDueHint.
  ///
  /// In zh, this message translates to:
  /// **'须与所选周期推算的日期一致'**
  String get financeNewDueHint;

  /// No description provided for @financePaymentRenewalNote.
  ///
  /// In zh, this message translates to:
  /// **'实付单独保存，不改续费价。仅支持整周期续费。'**
  String get financePaymentRenewalNote;

  /// No description provided for @financeBillStart.
  ///
  /// In zh, this message translates to:
  /// **'账期开始日（选填）'**
  String get financeBillStart;

  /// No description provided for @financeBillEnd.
  ///
  /// In zh, this message translates to:
  /// **'账期结束日（选填）'**
  String get financeBillEnd;

  /// No description provided for @financeOptionalNote.
  ///
  /// In zh, this message translates to:
  /// **'备注（选填）'**
  String get financeOptionalNote;

  /// No description provided for @financeConfirmAccountPaid.
  ///
  /// In zh, this message translates to:
  /// **'我已在厂商完成付款，并核对账单金额与日期。'**
  String get financeConfirmAccountPaid;

  /// No description provided for @financeConfirmServerPaid.
  ///
  /// In zh, this message translates to:
  /// **'我已在厂商完成付款，并核对实付金额与新到期日。'**
  String get financeConfirmServerPaid;

  /// No description provided for @financeSavePayment.
  ///
  /// In zh, this message translates to:
  /// **'保存付款记录'**
  String get financeSavePayment;

  /// No description provided for @financeNotReceipt.
  ///
  /// In zh, this message translates to:
  /// **'这不是厂商支付回执，不改变自动续费设置。'**
  String get financeNotReceipt;

  /// No description provided for @financePaymentTarget.
  ///
  /// In zh, this message translates to:
  /// **'付款对象'**
  String get financePaymentTarget;

  /// No description provided for @financeAllPayments.
  ///
  /// In zh, this message translates to:
  /// **'全部付款记录'**
  String get financeAllPayments;

  /// No description provided for @financeRecent30.
  ///
  /// In zh, this message translates to:
  /// **'近 30 天'**
  String get financeRecent30;

  /// No description provided for @financeShowVoided.
  ///
  /// In zh, this message translates to:
  /// **'显示已删除'**
  String get financeShowVoided;

  /// No description provided for @financeRecordedPaidTotal.
  ///
  /// In zh, this message translates to:
  /// **'已记录实付合计'**
  String get financeRecordedPaidTotal;

  /// No description provided for @financeNoPayments.
  ///
  /// In zh, this message translates to:
  /// **'— 尚无付款记录'**
  String get financeNoPayments;

  /// No description provided for @financePaymentDetails.
  ///
  /// In zh, this message translates to:
  /// **'付款明细'**
  String get financePaymentDetails;

  /// No description provided for @financeArchivedPayment.
  ///
  /// In zh, this message translates to:
  /// **'服务器已归档 · 历史实付保留'**
  String get financeArchivedPayment;

  /// No description provided for @financeNoPaymentsInRange.
  ///
  /// In zh, this message translates to:
  /// **'此范围暂无付款记录。可从服务器详情记录已完成的续费付款。'**
  String get financeNoPaymentsInRange;

  /// No description provided for @financeVoidTitle.
  ///
  /// In zh, this message translates to:
  /// **'撤销此次本地记录？'**
  String get financeVoidTitle;

  /// No description provided for @financeVoidAccountNote.
  ///
  /// In zh, this message translates to:
  /// **'将此账单标记为已撤销，不向厂商申请退款。'**
  String get financeVoidAccountNote;

  /// No description provided for @financeVoidServerNote.
  ///
  /// In zh, this message translates to:
  /// **'仅还原本次增加的服务期间与到期日，并将实付标记为已撤销。不会向厂商退款或取消服务。'**
  String get financeVoidServerNote;

  /// No description provided for @financeVoidRecord.
  ///
  /// In zh, this message translates to:
  /// **'撤销记录'**
  String get financeVoidRecord;

  /// No description provided for @financePaymentVoided.
  ///
  /// In zh, this message translates to:
  /// **'本次本地付款记录已撤销'**
  String get financePaymentVoided;

  /// No description provided for @financePaymentDetail.
  ///
  /// In zh, this message translates to:
  /// **'付款详情'**
  String get financePaymentDetail;

  /// No description provided for @financePaymentUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'记录暂不可用，请返回重新读取'**
  String get financePaymentUnavailable;

  /// No description provided for @financePaymentDateLabel.
  ///
  /// In zh, this message translates to:
  /// **'付款日'**
  String get financePaymentDateLabel;

  /// No description provided for @financeType.
  ///
  /// In zh, this message translates to:
  /// **'类型'**
  String get financeType;

  /// No description provided for @financeAccountBill.
  ///
  /// In zh, this message translates to:
  /// **'账户账单'**
  String get financeAccountBill;

  /// No description provided for @financeBillServicePeriod.
  ///
  /// In zh, this message translates to:
  /// **'对应账期 / 服务期'**
  String get financeBillServicePeriod;

  /// No description provided for @financeVoidedStatus.
  ///
  /// In zh, this message translates to:
  /// **'已删除，不计入实付统计'**
  String get financeVoidedStatus;

  /// No description provided for @financeRecordedStatus.
  ///
  /// In zh, this message translates to:
  /// **'已记录'**
  String get financeRecordedStatus;

  /// No description provided for @financePaymentHistoryNote.
  ///
  /// In zh, this message translates to:
  /// **'原币历史实付，不随续费价或汇率变化。'**
  String get financePaymentHistoryNote;

  /// No description provided for @financeVoidThisRecord.
  ///
  /// In zh, this message translates to:
  /// **'撤销此次记录'**
  String get financeVoidThisRecord;

  /// No description provided for @r2FinanceEdit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get r2FinanceEdit;

  /// No description provided for @r2FinanceEditTitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑付款记录'**
  String get r2FinanceEditTitle;

  /// No description provided for @r2FinanceEditHint.
  ///
  /// In zh, this message translates to:
  /// **'只修改记账信息，不改变服务期、到期日或周期数。'**
  String get r2FinanceEditHint;

  /// No description provided for @r2FinanceDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除记录'**
  String get r2FinanceDelete;

  /// No description provided for @r2FinanceDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除此付款记录？'**
  String get r2FinanceDeleteTitle;

  /// No description provided for @r2FinanceDeleteAccountMsg.
  ///
  /// In zh, this message translates to:
  /// **'仅在本地删除这条账单记录，不影响任何服务器，也不会向厂商退款。删除后不计入实付统计。'**
  String get r2FinanceDeleteAccountMsg;

  /// No description provided for @r2FinanceDeleteKeepMsg.
  ///
  /// In zh, this message translates to:
  /// **'仅删除付款记录。服务期与到期日保持不变，也不会向厂商退款。'**
  String get r2FinanceDeleteKeepMsg;

  /// No description provided for @r2FinanceDeleteKeep.
  ///
  /// In zh, this message translates to:
  /// **'仅删除记录，保留服务期'**
  String get r2FinanceDeleteKeep;

  /// No description provided for @r4PayDeleteRollbackTo.
  ///
  /// In zh, this message translates to:
  /// **'删除并回退到期日（→ {date}）'**
  String r4PayDeleteRollbackTo(String date);

  /// No description provided for @r4PayDeleteChoiceMsg.
  ///
  /// In zh, this message translates to:
  /// **'仅删除记录会保留服务期，到期日仍为 {until}。不会向厂商退款。'**
  String r4PayDeleteChoiceMsg(String until);

  /// No description provided for @r4PayDeleteLaterMsg.
  ///
  /// In zh, this message translates to:
  /// **'之后还有续费记录（{dates}），需先删除它们才能回退到期日。此处仅删除记录，服务期与到期日不变，也不会向厂商退款。'**
  String r4PayDeleteLaterMsg(String dates);

  /// No description provided for @r4PayOrphanBanner.
  ///
  /// In zh, this message translates to:
  /// **'{from} → {until} 的付款已删除。回退到期日到 {from}？'**
  String r4PayOrphanBanner(String from, String until);

  /// No description provided for @r4PayOrphanTitle.
  ///
  /// In zh, this message translates to:
  /// **'回退到期日？'**
  String get r4PayOrphanTitle;

  /// No description provided for @r4PayOrphanMsg.
  ///
  /// In zh, this message translates to:
  /// **'移除已删除付款留下的服务期（{from} → {until}），到期日恢复为 {from}。不影响其他付款记录。'**
  String r4PayOrphanMsg(String from, String until);

  /// No description provided for @r4PayOrphanAction.
  ///
  /// In zh, this message translates to:
  /// **'回退'**
  String get r4PayOrphanAction;

  /// No description provided for @r4PayOrphanDone.
  ///
  /// In zh, this message translates to:
  /// **'到期日已回退到 {date}'**
  String r4PayOrphanDone(String date);

  /// No description provided for @r2FinanceDeleted.
  ///
  /// In zh, this message translates to:
  /// **'付款记录已删除'**
  String get r2FinanceDeleted;

  /// No description provided for @r2FinanceUpdated.
  ///
  /// In zh, this message translates to:
  /// **'付款记录已更新'**
  String get r2FinanceUpdated;

  /// No description provided for @financeVoidBlocked.
  ///
  /// In zh, this message translates to:
  /// **'资料已改变，请核对。后续编辑、付款或归档后不能用旧记录覆盖现有资料。'**
  String get financeVoidBlocked;

  /// No description provided for @financeRulesTitle.
  ///
  /// In zh, this message translates to:
  /// **'这些数字如何计算'**
  String get financeRulesTitle;

  /// No description provided for @financeTitle.
  ///
  /// In zh, this message translates to:
  /// **'费用'**
  String get financeTitle;

  /// No description provided for @financeOverview.
  ///
  /// In zh, this message translates to:
  /// **'查看月费用参考、剩余价值和已记录付款。'**
  String get financeOverview;

  /// No description provided for @financeScope.
  ///
  /// In zh, this message translates to:
  /// **'统计范围'**
  String get financeScope;

  /// No description provided for @financeMonthlyReference.
  ///
  /// In zh, this message translates to:
  /// **'月费用参考'**
  String get financeMonthlyReference;

  /// No description provided for @financeTotalRemaining.
  ///
  /// In zh, this message translates to:
  /// **'总体剩余价值  ›'**
  String get financeTotalRemaining;

  /// No description provided for @financeMonthlyNotPaid.
  ///
  /// In zh, this message translates to:
  /// **'续费价摊月 + 按量估算，不等于本月实付。'**
  String get financeMonthlyNotPaid;

  /// No description provided for @financeUpcomingRenewals.
  ///
  /// In zh, this message translates to:
  /// **'未来 30 天预计续费'**
  String get financeUpcomingRenewals;

  /// No description provided for @financeRecentPayments.
  ///
  /// In zh, this message translates to:
  /// **'付款记录'**
  String get financeRecentPayments;

  /// No description provided for @financeUnrecordedNotZero.
  ///
  /// In zh, this message translates to:
  /// **'尚无已记录付款，不代表没有支出'**
  String get financeUnrecordedNotZero;

  /// No description provided for @financeMonthlyDistribution.
  ///
  /// In zh, this message translates to:
  /// **'月费用分布'**
  String get financeMonthlyDistribution;

  /// No description provided for @financeByVendor.
  ///
  /// In zh, this message translates to:
  /// **'按厂商'**
  String get financeByVendor;

  /// No description provided for @financeByGroup.
  ///
  /// In zh, this message translates to:
  /// **'按分组'**
  String get financeByGroup;

  /// No description provided for @financeDistributionEmpty.
  ///
  /// In zh, this message translates to:
  /// **'添加费用资料后显示分布。'**
  String get financeDistributionEmpty;

  /// No description provided for @financeDistributionNote.
  ///
  /// In zh, this message translates to:
  /// **'点击分类查看服务器明细。'**
  String get financeDistributionNote;

  /// No description provided for @financeGroupDistributionNote.
  ///
  /// In zh, this message translates to:
  /// **'账户级实付不分摊到分组；点击分类查看明细。'**
  String get financeGroupDistributionNote;

  /// No description provided for @financeSixMonthTitle.
  ///
  /// In zh, this message translates to:
  /// **'本月起六个月 · 预付续费'**
  String get financeSixMonthTitle;

  /// No description provided for @financeForecastNote.
  ///
  /// In zh, this message translates to:
  /// **'按当前续费价预测，假设继续续费；不含按量账单和已过期项目。'**
  String get financeForecastNote;

  /// No description provided for @financeMonthlyDetail.
  ///
  /// In zh, this message translates to:
  /// **'月费用明细'**
  String get financeMonthlyDetail;

  /// No description provided for @financeValueDetail.
  ///
  /// In zh, this message translates to:
  /// **'剩余价值明细'**
  String get financeValueDetail;

  /// No description provided for @financeInventoryDetail.
  ///
  /// In zh, this message translates to:
  /// **'服务器构成'**
  String get financeInventoryDetail;

  /// No description provided for @financeIncompleteDetail.
  ///
  /// In zh, this message translates to:
  /// **'费用与到期核对'**
  String get financeIncompleteDetail;

  /// No description provided for @financeMeteredValueNa.
  ///
  /// In zh, this message translates to:
  /// **'按量计费 · 剩余价值不适用'**
  String get financeMeteredValueNa;

  /// No description provided for @financeExpiredMonthlyExcluded.
  ///
  /// In zh, this message translates to:
  /// **'已到期，未计入月费用参考'**
  String get financeExpiredMonthlyExcluded;

  /// No description provided for @financeUnknownAmount.
  ///
  /// In zh, this message translates to:
  /// **'日期或费用资料不足，金额未知'**
  String get financeUnknownAmount;

  /// No description provided for @financeNoServersInRange.
  ///
  /// In zh, this message translates to:
  /// **'此范围没有服务器。'**
  String get financeNoServersInRange;

  /// No description provided for @financeUnknownZeroNote.
  ///
  /// In zh, this message translates to:
  /// **'“—”表示未知或不适用，不是免费。'**
  String get financeUnknownZeroNote;

  /// No description provided for @financeRenewals30Title.
  ///
  /// In zh, this message translates to:
  /// **'未来 30 天续费安排'**
  String get financeRenewals30Title;

  /// No description provided for @financeNoKnownRenewals.
  ///
  /// In zh, this message translates to:
  /// **'此范围没有已知的预付续费。'**
  String get financeNoKnownRenewals;

  /// No description provided for @financeExpiredCheck.
  ///
  /// In zh, this message translates to:
  /// **'已过期 · 先核实'**
  String get financeExpiredCheck;

  /// No description provided for @financeMeteredRenewalNote.
  ///
  /// In zh, this message translates to:
  /// **'按量计费不产生续费事件，月估算在服务器资料中维护。'**
  String get financeMeteredRenewalNote;

  /// No description provided for @financePngRenderFailed.
  ///
  /// In zh, this message translates to:
  /// **'图片生成失败，原计算结果已保留。'**
  String get financePngRenderFailed;

  /// No description provided for @financePngSaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存未完成。预览仍保留，请检查空间与权限后重试。'**
  String get financePngSaveFailed;

  /// No description provided for @financePngShareSelected.
  ///
  /// In zh, this message translates to:
  /// **'已选择系统分享操作，请在目标应用核对是否送达。'**
  String get financePngShareSelected;

  /// No description provided for @financePngShareDismissed.
  ///
  /// In zh, this message translates to:
  /// **'已取消分享，预览仍保留。'**
  String get financePngShareDismissed;

  /// No description provided for @financePngShareUnknown.
  ///
  /// In zh, this message translates to:
  /// **'未收到系统分享结果，预览仍保留。'**
  String get financePngShareUnknown;

  /// No description provided for @financePngShareUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'此平台不支持 PNG 系统分享，可保存到本地。'**
  String get financePngShareUnsupported;

  /// No description provided for @financePngShareBusy.
  ///
  /// In zh, this message translates to:
  /// **'请先完成当前系统分享操作。'**
  String get financePngShareBusy;

  /// No description provided for @financePngShareFailed.
  ///
  /// In zh, this message translates to:
  /// **'分享未完成，预览仍保留，请重试。'**
  String get financePngShareFailed;

  /// No description provided for @financePngPreview.
  ///
  /// In zh, this message translates to:
  /// **'图片预览'**
  String get financePngPreview;

  /// No description provided for @financePngPrivacy.
  ///
  /// In zh, this message translates to:
  /// **'图片仅含金额、日期、周期和参考汇率，不含服务器名称、地址或备注。'**
  String get financePngPrivacy;

  /// No description provided for @financePngSemantic.
  ///
  /// In zh, this message translates to:
  /// **'剩余价值计算结果 PNG'**
  String get financePngSemantic;

  /// No description provided for @financeRegenerate.
  ///
  /// In zh, this message translates to:
  /// **'重新生成'**
  String get financeRegenerate;

  /// No description provided for @financeSavePng.
  ///
  /// In zh, this message translates to:
  /// **'保存 PNG'**
  String get financeSavePng;

  /// No description provided for @financeSharing.
  ///
  /// In zh, this message translates to:
  /// **'正在分享…'**
  String get financeSharing;

  /// No description provided for @financeSharePng.
  ///
  /// In zh, this message translates to:
  /// **'系统分享 PNG'**
  String get financeSharePng;

  /// No description provided for @financePngLocationNote.
  ///
  /// In zh, this message translates to:
  /// **'文件可能在应用私有目录；可用系统分享另存。'**
  String get financePngLocationNote;

  /// No description provided for @financeRulesBody.
  ///
  /// In zh, this message translates to:
  /// **'月费用参考：未到期的预付续费价 ÷ 周期月数，加上按量月估算。到期当天及已过期的预付服务不计入；缺少日期或费用时标记为未知。\n\n剩余价值：按各个已知服务期的未用天数折算当前续费价，包含开始日、不含结束日。尚未开始的整期计整价，已结束的期间计 0；按量付费不适用，资料不足时为未知。它不是可退款金额或成交价。\n\n续费预测：假设继续按当前周期和价格续费。未来 30 天含今天及后 29 天；六个月指本月剩余日期和后五个自然月。已过期项目不补推，不包含按量账单；本地使用计划不会改变预测。\n\n近 30 天实付：包含今天及前 29 天已记录的付款。全部范围保留归档服务器的付款，独立账户账单只计一次；按分组查看时不分摊账户账单。\n\n跨币种缺少汇率时，仅合计可折算的部分，并保留原币小计。先精确求和，再四舍五入到分；参考折算不等于实际扣款。'**
  String get financeRulesBody;

  /// No description provided for @financeApproxAmount.
  ///
  /// In zh, this message translates to:
  /// **'约 {amount} {currency}'**
  String financeApproxAmount(String amount, String currency);

  /// No description provided for @financeTotalAmount.
  ///
  /// In zh, this message translates to:
  /// **'{covered, select, yes{约 {amount} {currency}} other{{amount} {currency}}}'**
  String financeTotalAmount(String covered, String amount, String currency);

  /// No description provided for @financeCoverage.
  ///
  /// In zh, this message translates to:
  /// **'折算覆盖 {covered} / {total}{missing, plural, =0{} other{ · {missing} 项缺汇率}}'**
  String financeCoverage(int covered, int total, int missing);

  /// No description provided for @financeUnknownExcluded.
  ///
  /// In zh, this message translates to:
  /// **'{unknown} 项未知 · {excluded} 项不适用 / 未纳入'**
  String financeUnknownExcluded(int unknown, int excluded);

  /// No description provided for @financeOriginalSubtotals.
  ///
  /// In zh, this message translates to:
  /// **'原币小计：{amounts}'**
  String financeOriginalSubtotals(String amounts);

  /// No description provided for @financePeriodProgress.
  ///
  /// In zh, this message translates to:
  /// **'{period}剩余 {percent}% · {remaining} / {days} 天'**
  String financePeriodProgress(
    String period,
    String percent,
    int remaining,
    int days,
  );

  /// No description provided for @financePeriodDates.
  ///
  /// In zh, this message translates to:
  /// **'{start} 至 {end}（不含结束日）'**
  String financePeriodDates(String start, String end);

  /// No description provided for @financeDaysValue.
  ///
  /// In zh, this message translates to:
  /// **'{days} 天'**
  String financeDaysValue(int days);

  /// No description provided for @financeRenewalValue.
  ///
  /// In zh, this message translates to:
  /// **'{amount} {currency} / {months} 个月'**
  String financeRenewalValue(String amount, String currency, int months);

  /// No description provided for @financeFuturePeriodsNote.
  ///
  /// In zh, this message translates to:
  /// **'含 {count} 个尚未开始的周期。'**
  String financeFuturePeriodsNote(int count);

  /// No description provided for @financeReferenceServerSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'{billing} · 至 {due}'**
  String financeReferenceServerSubtitle(String billing, String due);

  /// No description provided for @financeReferenceBasis.
  ///
  /// In zh, this message translates to:
  /// **'引用 {name} 的已知服务期；修改输入不会改动原服务器。'**
  String financeReferenceBasis(String name);

  /// No description provided for @financeEveryMonths.
  ///
  /// In zh, this message translates to:
  /// **'每 {months} 个月'**
  String financeEveryMonths(int months);

  /// No description provided for @financeFxSource.
  ///
  /// In zh, this message translates to:
  /// **'手动汇率 · {date} · 非实时报价'**
  String financeFxSource(String date);

  /// No description provided for @financeKnownPeriodsBasis.
  ///
  /// In zh, this message translates to:
  /// **'{inferred, select, yes{引用时复制的已知服务期；部分起点为推算，未回写台账。} other{引用时复制的已知服务期，未回写台账。}}'**
  String financeKnownPeriodsBasis(String inferred);

  /// No description provided for @financeSellerQuote.
  ///
  /// In zh, this message translates to:
  /// **'卖家报价 · {currency}'**
  String financeSellerQuote(String currency);

  /// No description provided for @r3FinancePeriodWeek.
  ///
  /// In zh, this message translates to:
  /// **'近一周'**
  String get r3FinancePeriodWeek;

  /// No description provided for @r3FinancePeriodMonth.
  ///
  /// In zh, this message translates to:
  /// **'近一个月'**
  String get r3FinancePeriodMonth;

  /// No description provided for @r3FinancePeriodQuarter.
  ///
  /// In zh, this message translates to:
  /// **'近三个月'**
  String get r3FinancePeriodQuarter;

  /// No description provided for @r3FinancePeriodHalfYear.
  ///
  /// In zh, this message translates to:
  /// **'近六个月'**
  String get r3FinancePeriodHalfYear;

  /// No description provided for @r3FinancePeriodYear.
  ///
  /// In zh, this message translates to:
  /// **'近一年'**
  String get r3FinancePeriodYear;

  /// No description provided for @r3FinancePeriodAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get r3FinancePeriodAll;

  /// No description provided for @r3FinanceRecentSub.
  ///
  /// In zh, this message translates to:
  /// **'近 30 天 · {count} 笔'**
  String r3FinanceRecentSub(int count);

  /// No description provided for @r3FinanceTimelineStart.
  ///
  /// In zh, this message translates to:
  /// **'周期开始'**
  String get r3FinanceTimelineStart;

  /// No description provided for @r3FinanceTimelineAsOf.
  ///
  /// In zh, this message translates to:
  /// **'估值日'**
  String get r3FinanceTimelineAsOf;

  /// No description provided for @r3FinanceTimelineDue.
  ///
  /// In zh, this message translates to:
  /// **'到期日'**
  String get r3FinanceTimelineDue;

  /// No description provided for @r3FinanceQuoteMode.
  ///
  /// In zh, this message translates to:
  /// **'输入方式'**
  String get r3FinanceQuoteMode;

  /// No description provided for @r3FinanceQuoteModeOffer.
  ///
  /// In zh, this message translates to:
  /// **'直接输入报价'**
  String get r3FinanceQuoteModeOffer;

  /// No description provided for @r3FinanceQuoteModePremium.
  ///
  /// In zh, this message translates to:
  /// **'输入溢价金额'**
  String get r3FinanceQuoteModePremium;

  /// No description provided for @r3FinanceQuoteModePercent.
  ///
  /// In zh, this message translates to:
  /// **'输入溢价比例'**
  String get r3FinanceQuoteModePercent;

  /// No description provided for @r3FinanceQuoteDirection.
  ///
  /// In zh, this message translates to:
  /// **'方向'**
  String get r3FinanceQuoteDirection;

  /// No description provided for @r3FinanceQuotePremium.
  ///
  /// In zh, this message translates to:
  /// **'溢价'**
  String get r3FinanceQuotePremium;

  /// No description provided for @r3FinanceQuoteDiscount.
  ///
  /// In zh, this message translates to:
  /// **'折价'**
  String get r3FinanceQuoteDiscount;

  /// No description provided for @r3FinanceQuotePremiumField.
  ///
  /// In zh, this message translates to:
  /// **'金额 · {currency}'**
  String r3FinanceQuotePremiumField(String currency);

  /// No description provided for @r3FinanceQuotePercentField.
  ///
  /// In zh, this message translates to:
  /// **'占剩余价值 (%)'**
  String get r3FinanceQuotePercentField;

  /// No description provided for @r3FinanceQuotePercentError.
  ///
  /// In zh, this message translates to:
  /// **'请输入 0–1000 的比例，最多 2 位小数'**
  String get r3FinanceQuotePercentError;

  /// No description provided for @r3FinanceQuoteRangeError.
  ///
  /// In zh, this message translates to:
  /// **'折价不能超过剩余价值，成交价需在支持范围内'**
  String get r3FinanceQuoteRangeError;

  /// No description provided for @r3FinanceQuoteSettlement.
  ///
  /// In zh, this message translates to:
  /// **'结算明细'**
  String get r3FinanceQuoteSettlement;

  /// No description provided for @r3FinanceQuoteRef.
  ///
  /// In zh, this message translates to:
  /// **'剩余价值'**
  String get r3FinanceQuoteRef;

  /// No description provided for @r3FinanceQuoteDeal.
  ///
  /// In zh, this message translates to:
  /// **'建议成交价'**
  String get r3FinanceQuoteDeal;

  /// No description provided for @r3FinanceQuoteFeesRow.
  ///
  /// In zh, this message translates to:
  /// **'手续费合计'**
  String get r3FinanceQuoteFeesRow;

  /// No description provided for @financeRoundingNote.
  ///
  /// In zh, this message translates to:
  /// **'{rate}\n{source}。折算结果仅供参考。'**
  String financeRoundingNote(String rate, String source);

  /// No description provided for @financeCycleEndError.
  ///
  /// In zh, this message translates to:
  /// **'所选周期应至 {date}'**
  String financeCycleEndError(String date);

  /// No description provided for @financeCycleCountOption.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个周期 · 每周期 {months} 个月'**
  String financeCycleCountOption(int count, int months);

  /// No description provided for @financeExtendFromDue.
  ///
  /// In zh, this message translates to:
  /// **'从原到期日 {date} 起延长。'**
  String financeExtendFromDue(String date);

  /// No description provided for @financeNextRenewalPrice.
  ///
  /// In zh, this message translates to:
  /// **'下次续费价：{billing} {currency}'**
  String financeNextRenewalPrice(String billing, String currency);

  /// No description provided for @financeArchivedName.
  ///
  /// In zh, this message translates to:
  /// **'{archived, select, yes{{name} · 已归档} other{{name}}}'**
  String financeArchivedName(String name, String archived);

  /// No description provided for @financeValidPaymentsNote.
  ///
  /// In zh, this message translates to:
  /// **'{count} 笔有效记录，已删除的不计入。'**
  String financeValidPaymentsNote(int count);

  /// No description provided for @financePaymentGroupNote.
  ///
  /// In zh, this message translates to:
  /// **'当前分组：{group}，不含账户账单。'**
  String financePaymentGroupNote(String group);

  /// No description provided for @financeVoidedName.
  ///
  /// In zh, this message translates to:
  /// **'{voided, select, yes{{name} · 已撤销} other{{name}}}'**
  String financeVoidedName(String name, String voided);

  /// No description provided for @financePaymentSummary.
  ///
  /// In zh, this message translates to:
  /// **'{account, select, yes{{date} · 历史账户账单，只计一次} other{{date} · 到期日：{due}}}'**
  String financePaymentSummary(String date, String account, String due);

  /// No description provided for @financePrepaidRenewalType.
  ///
  /// In zh, this message translates to:
  /// **'预付续期 · {count} 个周期'**
  String financePrepaidRenewalType(int count);

  /// No description provided for @financePaymentPeriodRange.
  ///
  /// In zh, this message translates to:
  /// **'{start} 至 {end}'**
  String financePaymentPeriodRange(String start, String end);

  /// No description provided for @financeFxOverview.
  ///
  /// In zh, this message translates to:
  /// **'{currency} 参考 · 手动汇率 {date}'**
  String financeFxOverview(String currency, String date);

  /// No description provided for @financeManagedCount.
  ///
  /// In zh, this message translates to:
  /// **'在管服务器：{count} 台  ›'**
  String financeManagedCount(int count);

  /// No description provided for @financeRenewalEventNote.
  ///
  /// In zh, this message translates to:
  /// **'{count} 笔预付续费 · 今天及后 29 天'**
  String financeRenewalEventNote(int count);

  /// No description provided for @financeRecentPaymentNote.
  ///
  /// In zh, this message translates to:
  /// **'{count} 笔 · 今天及前 29 天'**
  String financeRecentPaymentNote(int count);

  /// No description provided for @financeIncompleteCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 台费用资料待完善 / 已到期'**
  String financeIncompleteCount(int count);

  /// No description provided for @financeSliceLabel.
  ///
  /// In zh, this message translates to:
  /// **'{label} · {count} 台'**
  String financeSliceLabel(String label, int count);

  /// No description provided for @uiFinanceDisplayChip.
  ///
  /// In zh, this message translates to:
  /// **'显示 {currency}'**
  String uiFinanceDisplayChip(String currency);

  /// No description provided for @uiFinanceCurrencyNote.
  ///
  /// In zh, this message translates to:
  /// **'只换算显示，不改变原币记录。'**
  String get uiFinanceCurrencyNote;

  /// No description provided for @uiFinanceTileRemaining.
  ///
  /// In zh, this message translates to:
  /// **'剩余价值'**
  String get uiFinanceTileRemaining;

  /// No description provided for @uiFinanceTileRenewals.
  ///
  /// In zh, this message translates to:
  /// **'30 天内续费'**
  String get uiFinanceTileRenewals;

  /// No description provided for @uiFinanceBannerMissingFx.
  ///
  /// In zh, this message translates to:
  /// **'{count} 项金额缺少汇率，未计入合计'**
  String uiFinanceBannerMissingFx(int count);

  /// No description provided for @uiFinanceGapMissingFx.
  ///
  /// In zh, this message translates to:
  /// **'缺汇率 {count} 项'**
  String uiFinanceGapMissingFx(int count);

  /// No description provided for @uiFinanceGapUnknown.
  ///
  /// In zh, this message translates to:
  /// **'金额未知 {count} 项'**
  String uiFinanceGapUnknown(int count);

  /// No description provided for @uiFinanceMonthShort.
  ///
  /// In zh, this message translates to:
  /// **'{month} 月'**
  String uiFinanceMonthShort(String month);

  /// No description provided for @uiFinanceForecastBasis.
  ///
  /// In zh, this message translates to:
  /// **'按当前续费价'**
  String get uiFinanceForecastBasis;

  /// No description provided for @uiFinanceToolsHeader.
  ///
  /// In zh, this message translates to:
  /// **'记录与工具'**
  String get uiFinanceToolsHeader;

  /// No description provided for @uiFinanceServerCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 台'**
  String uiFinanceServerCount(int count);

  /// No description provided for @uiFinanceFootnote.
  ///
  /// In zh, this message translates to:
  /// **'按续费价和手动汇率折算，仅供参考，非实际账单。'**
  String get uiFinanceFootnote;

  /// No description provided for @uiFinanceVoidedPill.
  ///
  /// In zh, this message translates to:
  /// **'已删除'**
  String get uiFinanceVoidedPill;

  /// No description provided for @uiFinanceArchivedPill.
  ///
  /// In zh, this message translates to:
  /// **'已归档'**
  String get uiFinanceArchivedPill;

  /// No description provided for @uiFinanceAccountPill.
  ///
  /// In zh, this message translates to:
  /// **'账户账单'**
  String get uiFinanceAccountPill;

  /// No description provided for @financeForecastMonth.
  ///
  /// In zh, this message translates to:
  /// **'{year} 年 {month} 月 · {count} 笔'**
  String financeForecastMonth(int year, int month, int count);

  /// No description provided for @financeForecastTotal.
  ///
  /// In zh, this message translates to:
  /// **'{amount} {currency}{missing, plural, =0{} other{ · 缺汇率 {missing} 项}}{unknown, plural, =0{} other{ · 金额未知 {unknown} 项}}'**
  String financeForecastTotal(
    String amount,
    String currency,
    int missing,
    int unknown,
  );

  /// No description provided for @financeDetailScope.
  ///
  /// In zh, this message translates to:
  /// **'{label} · {count} 台未归档服务器'**
  String financeDetailScope(String label, int count);

  /// No description provided for @financeAmountMetric.
  ///
  /// In zh, this message translates to:
  /// **'{metric, select, value{{amount} {currency} 剩余价值} other{{amount} {currency} / 月参考}}'**
  String financeAmountMetric(String amount, String currency, String metric);

  /// No description provided for @financeDueDateValue.
  ///
  /// In zh, this message translates to:
  /// **'到期日：{date}'**
  String financeDueDateValue(String date);

  /// No description provided for @financeRenewalsMonthTitle.
  ///
  /// In zh, this message translates to:
  /// **'{year} 年 {month} 月续费'**
  String financeRenewalsMonthTitle(int year, int month);

  /// No description provided for @financeRenewalsScopeNote.
  ///
  /// In zh, this message translates to:
  /// **'{count} 笔 · {group} · 按当前续费价预测，不代表已付款。'**
  String financeRenewalsScopeNote(int count, String group);

  /// No description provided for @financeRenewalEventDate.
  ///
  /// In zh, this message translates to:
  /// **'{date} · {months} 个月周期'**
  String financeRenewalEventDate(String date, int months);

  /// No description provided for @financeExpiredDate.
  ///
  /// In zh, this message translates to:
  /// **'{date} 已过期，不推断停机'**
  String financeExpiredDate(String date);

  /// No description provided for @financePngSavedPath.
  ///
  /// In zh, this message translates to:
  /// **'PNG 已保存：\n{path}'**
  String financePngSavedPath(String path);

  /// No description provided for @financeRenewalDateError.
  ///
  /// In zh, this message translates to:
  /// **'续费需要有效的周期与原到期日'**
  String get financeRenewalDateError;

  /// No description provided for @financeAnchorMismatch.
  ///
  /// In zh, this message translates to:
  /// **'服务期锚点与到期日不一致，请核对资料'**
  String get financeAnchorMismatch;

  /// No description provided for @financeDueRangeError.
  ///
  /// In zh, this message translates to:
  /// **'到期日超出支持范围'**
  String get financeDueRangeError;

  /// No description provided for @financeTrialInputError.
  ///
  /// In zh, this message translates to:
  /// **'请选择有效日期与周期，试算范围限制为 100 年'**
  String get financeTrialInputError;

  /// No description provided for @financePeriodRangeError.
  ///
  /// In zh, this message translates to:
  /// **'服务期超出支持范围'**
  String get financePeriodRangeError;

  /// No description provided for @financeTrialRangeError.
  ///
  /// In zh, this message translates to:
  /// **'试算范围限制为 100 年'**
  String get financeTrialRangeError;

  /// No description provided for @financeUnsupportedCurrency.
  ///
  /// In zh, this message translates to:
  /// **'不支持的展示币种'**
  String get financeUnsupportedCurrency;

  /// No description provided for @financeInvalidRate.
  ///
  /// In zh, this message translates to:
  /// **'汇率需为正数，最多 9 位整数和 8 位小数'**
  String get financeInvalidRate;

  /// No description provided for @financeMissingRateDate.
  ///
  /// In zh, this message translates to:
  /// **'请填写手动汇率日期'**
  String get financeMissingRateDate;

  /// No description provided for @financeExportDisclaimer.
  ///
  /// In zh, this message translates to:
  /// **'仅表示服务时长的价格折算，不代表退款承诺或成交价。'**
  String get financeExportDisclaimer;

  /// No description provided for @financeExportHeading.
  ///
  /// In zh, this message translates to:
  /// **'VPS Tell You · 试算 · 不入账'**
  String get financeExportHeading;

  /// No description provided for @financeExportFooter.
  ///
  /// In zh, this message translates to:
  /// **'独立试算 · 图片仅含计算信息'**
  String get financeExportFooter;

  /// No description provided for @financeExportValue.
  ///
  /// In zh, this message translates to:
  /// **'剩余价值：{amount} {currency}'**
  String financeExportValue(String amount, String currency);

  /// No description provided for @financeExportValuationDate.
  ///
  /// In zh, this message translates to:
  /// **'估值日期：{date}'**
  String financeExportValuationDate(String date);

  /// No description provided for @financeExportPeriod.
  ///
  /// In zh, this message translates to:
  /// **'{period}：{start} 至 {end}（不含结束日）'**
  String financeExportPeriod(String period, String start, String end);

  /// No description provided for @financeExportPeriodRemaining.
  ///
  /// In zh, this message translates to:
  /// **'{period}剩余：{remaining} / {days} 天 · {percent}'**
  String financeExportPeriodRemaining(
    String period,
    int remaining,
    int days,
    String percent,
  );

  /// No description provided for @financeExportServiceRemaining.
  ///
  /// In zh, this message translates to:
  /// **'服务到期日：{due}；剩余服务天数：{days} 天'**
  String financeExportServiceRemaining(String due, int days);

  /// No description provided for @financeExportRenewalDaily.
  ///
  /// In zh, this message translates to:
  /// **'续费 / 周期：{renewal}；所示周期日均：{daily}'**
  String financeExportRenewalDaily(String renewal, String daily);

  /// No description provided for @financeExportFuturePeriods.
  ///
  /// In zh, this message translates to:
  /// **'含 {count} 个尚未开始的周期，进度仅显示上述周期。'**
  String financeExportFuturePeriods(int count);

  /// No description provided for @financeExportDue.
  ///
  /// In zh, this message translates to:
  /// **'服务到期日：{date}'**
  String financeExportDue(String date);

  /// No description provided for @financeExportRemainingDays.
  ///
  /// In zh, this message translates to:
  /// **'剩余服务天数：{days} 天'**
  String financeExportRemainingDays(int days);

  /// No description provided for @financeExportRenewal.
  ///
  /// In zh, this message translates to:
  /// **'续费 / 周期：{renewal}'**
  String financeExportRenewal(String renewal);

  /// No description provided for @financeExportDaily.
  ///
  /// In zh, this message translates to:
  /// **'所示周期日均：{daily}'**
  String financeExportDaily(String daily);

  /// No description provided for @billingCostUnknown.
  ///
  /// In zh, this message translates to:
  /// **'费用未知'**
  String get billingCostUnknown;

  /// No description provided for @billingMeteredAmount.
  ///
  /// In zh, this message translates to:
  /// **'{amount}/月估'**
  String billingMeteredAmount(String amount);

  /// No description provided for @billingAnnualAmount.
  ///
  /// In zh, this message translates to:
  /// **'{amount}/年'**
  String billingAnnualAmount(String amount);

  /// No description provided for @billingMonthlyAmount.
  ///
  /// In zh, this message translates to:
  /// **'{amount}/{months}个月'**
  String billingMonthlyAmount(String amount, int months);

  /// No description provided for @backupExcludedSecrets.
  ///
  /// In zh, this message translates to:
  /// **'密码、私钥、口令、Token、凭据元数据及安全存储引用'**
  String get backupExcludedSecrets;

  /// No description provided for @backupExcludedConnections.
  ///
  /// In zh, this message translates to:
  /// **'SSH 配置、已保存代理与主机信任'**
  String get backupExcludedConnections;

  /// No description provided for @backupExcludedNotes.
  ///
  /// In zh, this message translates to:
  /// **'命令片段、服务器备注和付款备注'**
  String get backupExcludedNotes;

  /// No description provided for @backupExcludedPreferences.
  ///
  /// In zh, this message translates to:
  /// **'提醒规则、通知排程及应用偏好'**
  String get backupExcludedPreferences;

  /// No description provided for @backupInvalidJson.
  ///
  /// In zh, this message translates to:
  /// **'备份不是有效 JSON'**
  String get backupInvalidJson;

  /// No description provided for @backupUnsupportedFormat.
  ///
  /// In zh, this message translates to:
  /// **'不支持的台账备份格式或版本'**
  String get backupUnsupportedFormat;

  /// No description provided for @backupInvalidCollections.
  ///
  /// In zh, this message translates to:
  /// **'备份集合类型或数量无效'**
  String get backupInvalidCollections;

  /// No description provided for @backupDuplicateIds.
  ///
  /// In zh, this message translates to:
  /// **'备份包含重复记录标识'**
  String get backupDuplicateIds;

  /// No description provided for @backupGroupNameConflict.
  ///
  /// In zh, this message translates to:
  /// **'备份分组名称冲突'**
  String get backupGroupNameConflict;

  /// No description provided for @backupMissingGroup.
  ///
  /// In zh, this message translates to:
  /// **'服务器引用不存在的分组'**
  String get backupMissingGroup;

  /// No description provided for @backupInvalidServer.
  ///
  /// In zh, this message translates to:
  /// **'服务器字段校验失败'**
  String get backupInvalidServer;

  /// No description provided for @backupAnchorMismatch.
  ///
  /// In zh, this message translates to:
  /// **'续费锚点与到期日不一致'**
  String get backupAnchorMismatch;

  /// No description provided for @backupInvalidPaymentPeriod.
  ///
  /// In zh, this message translates to:
  /// **'付款服务期无效'**
  String get backupInvalidPaymentPeriod;

  /// No description provided for @backupAccountBillMismatch.
  ///
  /// In zh, this message translates to:
  /// **'独立账户账单字段不一致'**
  String get backupAccountBillMismatch;

  /// No description provided for @backupInvalidServerPayment.
  ///
  /// In zh, this message translates to:
  /// **'服务器付款关联无效'**
  String get backupInvalidServerPayment;

  /// No description provided for @backupPaymentDateConflict.
  ///
  /// In zh, this message translates to:
  /// **'有效付款与服务器期限冲突'**
  String get backupPaymentDateConflict;

  /// No description provided for @backupServiceDateMismatch.
  ///
  /// In zh, this message translates to:
  /// **'服务期与服务器期限不一致'**
  String get backupServiceDateMismatch;

  /// No description provided for @backupDuplicateInitialPeriod.
  ///
  /// In zh, this message translates to:
  /// **'同一服务器包含重复初始服务期'**
  String get backupDuplicateInitialPeriod;

  /// No description provided for @backupInvalidPeriodPayment.
  ///
  /// In zh, this message translates to:
  /// **'服务期付款关联无效'**
  String get backupInvalidPeriodPayment;

  /// No description provided for @backupOverlappingPeriods.
  ///
  /// In zh, this message translates to:
  /// **'同一服务器存在重叠服务期'**
  String get backupOverlappingPeriods;

  /// No description provided for @backupIncompletePaymentPeriod.
  ///
  /// In zh, this message translates to:
  /// **'有效付款缺少完整服务期'**
  String get backupIncompletePaymentPeriod;

  /// No description provided for @backupPaymentCycleMismatch.
  ///
  /// In zh, this message translates to:
  /// **'付款服务期与续费周期不一致'**
  String get backupPaymentCycleMismatch;

  /// No description provided for @backupInitialPeriodMismatch.
  ///
  /// In zh, this message translates to:
  /// **'初始服务期缺失或与原始期限不一致'**
  String get backupInitialPeriodMismatch;

  /// No description provided for @backupInitialPeriodOutOfRange.
  ///
  /// In zh, this message translates to:
  /// **'初始服务期超出有效日期范围'**
  String get backupInitialPeriodOutOfRange;

  /// No description provided for @backupPeriodsNotContinuous.
  ///
  /// In zh, this message translates to:
  /// **'有效服务期必须连续'**
  String get backupPeriodsNotContinuous;

  /// No description provided for @backupPeriodsDoNotCoverDue.
  ///
  /// In zh, this message translates to:
  /// **'有效服务期未覆盖当前到期日'**
  String get backupPeriodsDoNotCoverDue;

  /// No description provided for @backupInvalidRates.
  ///
  /// In zh, this message translates to:
  /// **'参考汇率无效'**
  String get backupInvalidRates;

  /// No description provided for @restoreRequiresEmptyLedger.
  ///
  /// In zh, this message translates to:
  /// **'仅支持恢复到空台账；现有数据未改动'**
  String get restoreRequiresEmptyLedger;

  /// No description provided for @restoreMissingRateSettings.
  ///
  /// In zh, this message translates to:
  /// **'参考汇率设置缺失；恢复已回滚'**
  String get restoreMissingRateSettings;

  /// No description provided for @backupGroups.
  ///
  /// In zh, this message translates to:
  /// **'分组'**
  String get backupGroups;

  /// No description provided for @backupServersIncludingArchived.
  ///
  /// In zh, this message translates to:
  /// **'服务器（含归档）'**
  String get backupServersIncludingArchived;

  /// No description provided for @backupPaymentsIncludingVoided.
  ///
  /// In zh, this message translates to:
  /// **'付款（含撤销）'**
  String get backupPaymentsIncludingVoided;

  /// No description provided for @backupServicePeriods.
  ///
  /// In zh, this message translates to:
  /// **'服务期'**
  String get backupServicePeriods;

  /// No description provided for @restoreExistingRecords.
  ///
  /// In zh, this message translates to:
  /// **'目标台账已有{p0}'**
  String restoreExistingRecords(String p0);

  /// No description provided for @backupInvalidFields.
  ///
  /// In zh, this message translates to:
  /// **'备份字段缺失、未知或类型错误'**
  String get backupInvalidFields;

  /// No description provided for @backupInvalidText.
  ///
  /// In zh, this message translates to:
  /// **'备份文字字段无效'**
  String get backupInvalidText;

  /// No description provided for @backupNumberOutOfRange.
  ///
  /// In zh, this message translates to:
  /// **'备份整数或金额超出范围'**
  String get backupNumberOutOfRange;

  /// No description provided for @backupInvalidEnum.
  ///
  /// In zh, this message translates to:
  /// **'备份枚举字段无效'**
  String get backupInvalidEnum;

  /// No description provided for @backupInvalidDate.
  ///
  /// In zh, this message translates to:
  /// **'备份日期无效'**
  String get backupInvalidDate;

  /// No description provided for @backupTimeRequiresUtc.
  ///
  /// In zh, this message translates to:
  /// **'备份时间需为规范 UTC 时间'**
  String get backupTimeRequiresUtc;

  /// No description provided for @backupInvalidTime.
  ///
  /// In zh, this message translates to:
  /// **'备份时间无效'**
  String get backupInvalidTime;

  /// No description provided for @paymentPeriodsLockFields.
  ///
  /// In zh, this message translates to:
  /// **'已有付款服务期，不能直接修改日期、周期或计费方式；请先核对并安全撤销付款'**
  String get paymentPeriodsLockFields;

  /// No description provided for @invalidGroupName.
  ///
  /// In zh, this message translates to:
  /// **'请输入 1–40 字的分组名，不能使用“未分组”'**
  String get invalidGroupName;

  /// No description provided for @demoRequiresEmptyLedger.
  ///
  /// In zh, this message translates to:
  /// **'演示数据仅能载入空台账'**
  String get demoRequiresEmptyLedger;

  /// No description provided for @futureRateDate.
  ///
  /// In zh, this message translates to:
  /// **'汇率日期不能晚于今天'**
  String get futureRateDate;

  /// No description provided for @invalidPaymentId.
  ///
  /// In zh, this message translates to:
  /// **'付款标识无效'**
  String get invalidPaymentId;

  /// No description provided for @invalidPaidAmount.
  ///
  /// In zh, this message translates to:
  /// **'请输入有效实付金额，0 表示免费'**
  String get invalidPaidAmount;

  /// No description provided for @futurePaymentDate.
  ///
  /// In zh, this message translates to:
  /// **'付款日期不能晚于今天'**
  String get futurePaymentDate;

  /// No description provided for @notesTooLong.
  ///
  /// In zh, this message translates to:
  /// **'备注最多 4000 个字符'**
  String get notesTooLong;

  /// No description provided for @paymentAlreadyVoided.
  ///
  /// In zh, this message translates to:
  /// **'此付款已撤销，请重新核对后创建新记录'**
  String get paymentAlreadyVoided;

  /// No description provided for @paymentIdContentMismatch.
  ///
  /// In zh, this message translates to:
  /// **'相同付款标识的内容不同，请勿重复录入'**
  String get paymentIdContentMismatch;

  /// No description provided for @confirmProviderPayment.
  ///
  /// In zh, this message translates to:
  /// **'请确认已在厂商付款并核对金额与期限'**
  String get confirmProviderPayment;

  /// No description provided for @invalidRenewalCycleCount.
  ///
  /// In zh, this message translates to:
  /// **'请选择 1–3 个有效续费周期'**
  String get invalidRenewalCycleCount;

  /// No description provided for @renewalNeedsPrepaidDate.
  ///
  /// In zh, this message translates to:
  /// **'仅有明确到期日的预付服务可以续期'**
  String get renewalNeedsPrepaidDate;

  /// No description provided for @renewalDateMismatch.
  ///
  /// In zh, this message translates to:
  /// **'新到期日与所选周期及原续费锚点不一致'**
  String get renewalDateMismatch;

  /// No description provided for @duplicateExpiryPayment.
  ///
  /// In zh, this message translates to:
  /// **'该服务到期日已有付款记录，请勿重复录入'**
  String get duplicateExpiryPayment;

  /// No description provided for @invalidAccountName.
  ///
  /// In zh, this message translates to:
  /// **'账户名称需为 1–80 个字符'**
  String get invalidAccountName;

  /// No description provided for @invalidOptionalBillingPeriod.
  ///
  /// In zh, this message translates to:
  /// **'可选账期需填写有效起止日期，结束日必须晚于开始日'**
  String get invalidOptionalBillingPeriod;

  /// No description provided for @invalidCredentialDetails.
  ///
  /// In zh, this message translates to:
  /// **'凭据资料无效'**
  String get invalidCredentialDetails;

  /// No description provided for @secretWriteNotPrepared.
  ///
  /// In zh, this message translates to:
  /// **'秘密写入未准备完成'**
  String get secretWriteNotPrepared;

  /// No description provided for @chooseOtherCredential.
  ///
  /// In zh, this message translates to:
  /// **'请选择另一份凭据'**
  String get chooseOtherCredential;

  /// No description provided for @invalidSshConfiguration.
  ///
  /// In zh, this message translates to:
  /// **'请填写有效主机、端口和明确用户名'**
  String get invalidSshConfiguration;

  /// No description provided for @verificationCancelled.
  ///
  /// In zh, this message translates to:
  /// **'核验已取消'**
  String get verificationCancelled;

  /// No description provided for @completeLocalResources.
  ///
  /// In zh, this message translates to:
  /// **'请先补全并确认六项本地资源配置'**
  String get completeLocalResources;

  /// No description provided for @securityOperationIncomplete.
  ///
  /// In zh, this message translates to:
  /// **'安全操作未完成，请重试'**
  String get securityOperationIncomplete;

  /// No description provided for @serverNameRange.
  ///
  /// In zh, this message translates to:
  /// **'名称需为 1–80 个字符'**
  String get serverNameRange;

  /// No description provided for @serverVendorRange.
  ///
  /// In zh, this message translates to:
  /// **'厂商需为 1–80 个字符'**
  String get serverVendorRange;

  /// No description provided for @serverHostFormat.
  ///
  /// In zh, this message translates to:
  /// **'请输入 IP 或域名，不含协议、端口、路径或用户名'**
  String get serverHostFormat;

  /// No description provided for @serverUnsupportedCurrency.
  ///
  /// In zh, this message translates to:
  /// **'不支持的币种'**
  String get serverUnsupportedCurrency;

  /// No description provided for @serverValidAmount.
  ///
  /// In zh, this message translates to:
  /// **'请填写有效金额，0 表示免费'**
  String get serverValidAmount;

  /// No description provided for @serverValidCycle.
  ///
  /// In zh, this message translates to:
  /// **'请选择有效周期'**
  String get serverValidCycle;

  /// No description provided for @serverInvalidDate.
  ///
  /// In zh, this message translates to:
  /// **'日期无效'**
  String get serverInvalidDate;

  /// No description provided for @serverDueAfterStart.
  ///
  /// In zh, this message translates to:
  /// **'到期日必须晚于开始日'**
  String get serverDueAfterStart;

  /// No description provided for @resourceMonth.
  ///
  /// In zh, this message translates to:
  /// **'月'**
  String get resourceMonth;

  /// No description provided for @resourceQuarter.
  ///
  /// In zh, this message translates to:
  /// **'季'**
  String get resourceQuarter;

  /// No description provided for @resourceYear.
  ///
  /// In zh, this message translates to:
  /// **'年'**
  String get resourceYear;

  /// No description provided for @resourceValidIp.
  ///
  /// In zh, this message translates to:
  /// **'请填写有效的 IPv4 或 IPv6 地址，不能使用未指定地址'**
  String get resourceValidIp;

  /// No description provided for @resourceValidHostname.
  ///
  /// In zh, this message translates to:
  /// **'请填写有效主机名，不含协议、端口或路径'**
  String get resourceValidHostname;

  /// No description provided for @resourceValidVcpu.
  ///
  /// In zh, this message translates to:
  /// **'vCPU 需为 1–65536 的整数'**
  String get resourceValidVcpu;

  /// No description provided for @resourceValidRam.
  ///
  /// In zh, this message translates to:
  /// **'内存配额需为有效正数'**
  String get resourceValidRam;

  /// No description provided for @resourceValidDisk.
  ///
  /// In zh, this message translates to:
  /// **'硬盘配额需为有效正数'**
  String get resourceValidDisk;

  /// No description provided for @resourceValidTraffic.
  ///
  /// In zh, this message translates to:
  /// **'流量需填写有效正数配额，或明确选择不限量'**
  String get resourceValidTraffic;

  /// No description provided for @resourceValidPeriod.
  ///
  /// In zh, this message translates to:
  /// **'流量周期需选择月、季、年或未设置'**
  String get resourceValidPeriod;

  /// No description provided for @resourceTooLarge.
  ///
  /// In zh, this message translates to:
  /// **'本地资源配置过大'**
  String get resourceTooLarge;

  /// No description provided for @resourceInvalidFields.
  ///
  /// In zh, this message translates to:
  /// **'本地资源配置字段无效'**
  String get resourceInvalidFields;

  /// No description provided for @resourceUnlimitedTraffic.
  ///
  /// In zh, this message translates to:
  /// **'流量不限量'**
  String get resourceUnlimitedTraffic;

  /// No description provided for @resourceUnknownTraffic.
  ///
  /// In zh, this message translates to:
  /// **'流量未知'**
  String get resourceUnknownTraffic;

  /// No description provided for @resourceTrafficQuota.
  ///
  /// In zh, this message translates to:
  /// **'{p0} 流量'**
  String resourceTrafficQuota(String p0);

  /// No description provided for @resourcePeriodNotSet.
  ///
  /// In zh, this message translates to:
  /// **'周期未设置'**
  String get resourcePeriodNotSet;

  /// No description provided for @resourceEveryPeriod.
  ///
  /// In zh, this message translates to:
  /// **'每{p0}'**
  String resourceEveryPeriod(String p0);

  /// No description provided for @resourceDiskQuota.
  ///
  /// In zh, this message translates to:
  /// **'{p0} 硬盘'**
  String resourceDiskQuota(String p0);

  /// No description provided for @resourceFieldValidIp.
  ///
  /// In zh, this message translates to:
  /// **'请填写有效 IPv4 或 IPv6，不能为全零地址'**
  String get resourceFieldValidIp;

  /// No description provided for @r6IpValidIpv4.
  ///
  /// In zh, this message translates to:
  /// **'请填写有效的 IPv4 地址，如 192.0.2.1，不能为全零地址'**
  String get r6IpValidIpv4;

  /// No description provided for @r6IpValidIpv6.
  ///
  /// In zh, this message translates to:
  /// **'请填写有效的 IPv6 地址，如 2001:db8::1，不含方括号或区域标识'**
  String get r6IpValidIpv6;

  /// No description provided for @resourceFieldValidVcpu.
  ///
  /// In zh, this message translates to:
  /// **'请填写 1–65536 的整数核数'**
  String get resourceFieldValidVcpu;

  /// No description provided for @resourceFieldValidBytes.
  ///
  /// In zh, this message translates to:
  /// **'请填写大于 0 的容量，精确到整字节'**
  String get resourceFieldValidBytes;

  /// No description provided for @resourceCapacity.
  ///
  /// In zh, this message translates to:
  /// **'容量'**
  String get resourceCapacity;

  /// No description provided for @resourceUnitSemantics.
  ///
  /// In zh, this message translates to:
  /// **'{p0}单位，1024 进制'**
  String resourceUnitSemantics(String p0);

  /// No description provided for @resourceUnit.
  ///
  /// In zh, this message translates to:
  /// **'单位'**
  String get resourceUnit;

  /// No description provided for @resourceTrafficPeriod.
  ///
  /// In zh, this message translates to:
  /// **'流量周期'**
  String get resourceTrafficPeriod;

  /// No description provided for @resourcePeriod.
  ///
  /// In zh, this message translates to:
  /// **'周期'**
  String get resourcePeriod;

  /// No description provided for @resourceNewPeriodHelp.
  ///
  /// In zh, this message translates to:
  /// **'新建默认按月，可改。'**
  String get resourceNewPeriodHelp;

  /// No description provided for @resourcePeriodHelp.
  ///
  /// In zh, this message translates to:
  /// **'周期独立于容量单位；未知选“未设置”。'**
  String get resourcePeriodHelp;

  /// No description provided for @resourceHardware.
  ///
  /// In zh, this message translates to:
  /// **'硬件信息'**
  String get resourceHardware;

  /// No description provided for @resourceLocalHelp.
  ///
  /// In zh, this message translates to:
  /// **'容量按 1024 进制，可选单位。'**
  String get resourceLocalHelp;

  /// No description provided for @resourceIpAddress.
  ///
  /// In zh, this message translates to:
  /// **'IP 地址'**
  String get resourceIpAddress;

  /// No description provided for @r6IpIpv4.
  ///
  /// In zh, this message translates to:
  /// **'IPv4'**
  String get r6IpIpv4;

  /// No description provided for @r6IpIpv6.
  ///
  /// In zh, this message translates to:
  /// **'IPv6'**
  String get r6IpIpv6;

  /// No description provided for @resourceHostname.
  ///
  /// In zh, this message translates to:
  /// **'主机名'**
  String get resourceHostname;

  /// No description provided for @resourceDiskCapacity.
  ///
  /// In zh, this message translates to:
  /// **'磁盘容量'**
  String get resourceDiskCapacity;

  /// No description provided for @resourceTrafficQuotaLabel.
  ///
  /// In zh, this message translates to:
  /// **'流量额度'**
  String get resourceTrafficQuotaLabel;

  /// No description provided for @resourceUnlimitedHelp.
  ///
  /// In zh, this message translates to:
  /// **'仅在商家明确不限流量时开启。'**
  String get resourceUnlimitedHelp;

  /// No description provided for @resourceMemoryCapacity.
  ///
  /// In zh, this message translates to:
  /// **'内存容量'**
  String get resourceMemoryCapacity;

  /// No description provided for @resourceVcpuCount.
  ///
  /// In zh, this message translates to:
  /// **'vCPU 核数'**
  String get resourceVcpuCount;

  /// No description provided for @serverFilterTitle.
  ///
  /// In zh, this message translates to:
  /// **'筛选服务器'**
  String get serverFilterTitle;

  /// No description provided for @serverGroup.
  ///
  /// In zh, this message translates to:
  /// **'分组'**
  String get serverGroup;

  /// No description provided for @serverAllGroups.
  ///
  /// In zh, this message translates to:
  /// **'全部分组'**
  String get serverAllGroups;

  /// No description provided for @serverDueStatus.
  ///
  /// In zh, this message translates to:
  /// **'到期状态'**
  String get serverDueStatus;

  /// No description provided for @serverAllStatuses.
  ///
  /// In zh, this message translates to:
  /// **'全部状态'**
  String get serverAllStatuses;

  /// No description provided for @serverExpired.
  ///
  /// In zh, this message translates to:
  /// **'已过期'**
  String get serverExpired;

  /// No description provided for @serverDueNext30.
  ///
  /// In zh, this message translates to:
  /// **'未来 30 天到期'**
  String get serverDueNext30;

  /// No description provided for @serverCostDateUnknown.
  ///
  /// In zh, this message translates to:
  /// **'费用 / 到期日未知'**
  String get serverCostDateUnknown;

  /// No description provided for @serverApplyFilters.
  ///
  /// In zh, this message translates to:
  /// **'应用筛选'**
  String get serverApplyFilters;

  /// No description provided for @serverLedgerCount.
  ///
  /// In zh, this message translates to:
  /// **'{p0} 台服务器 · 本地台账'**
  String serverLedgerCount(String p0);

  /// No description provided for @serverReloadLocal.
  ///
  /// In zh, this message translates to:
  /// **'重新读取本地台账'**
  String get serverReloadLocal;

  /// No description provided for @serverReloadedLocal.
  ///
  /// In zh, this message translates to:
  /// **'已重新读取本地台账，未查询远端状态'**
  String get serverReloadedLocal;

  /// No description provided for @serverAdd.
  ///
  /// In zh, this message translates to:
  /// **'添加服务器'**
  String get serverAdd;

  /// No description provided for @serverFirstTitle.
  ///
  /// In zh, this message translates to:
  /// **'你的第一台 VPS，\n从这里开始'**
  String get serverFirstTitle;

  /// No description provided for @serverFirstDescription.
  ///
  /// In zh, this message translates to:
  /// **'到期、费用和连接，一处记录。'**
  String get serverFirstDescription;

  /// No description provided for @serverAddFirst.
  ///
  /// In zh, this message translates to:
  /// **'添加第一台服务器'**
  String get serverAddFirst;

  /// No description provided for @serverLoadDemoQuestion.
  ///
  /// In zh, this message translates to:
  /// **'载入演示数据？'**
  String get serverLoadDemoQuestion;

  /// No description provided for @serverLoadDemoHelp.
  ///
  /// In zh, this message translates to:
  /// **'将写入 4 条“演示”记录，使用保留地址，不会连接服务器；可随时归档。'**
  String get serverLoadDemoHelp;

  /// No description provided for @serverLoadDemo.
  ///
  /// In zh, this message translates to:
  /// **'载入演示'**
  String get serverLoadDemo;

  /// No description provided for @serverViewDemo.
  ///
  /// In zh, this message translates to:
  /// **'先看看演示数据'**
  String get serverViewDemo;

  /// No description provided for @serverManualStartHelp.
  ///
  /// In zh, this message translates to:
  /// **'已经有机器？手动记录就能开始。'**
  String get serverManualStartHelp;

  /// No description provided for @serverSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索名称、地址、厂商、用途或地区'**
  String get serverSearchHint;

  /// No description provided for @serverClearSearch.
  ///
  /// In zh, this message translates to:
  /// **'清除搜索'**
  String get serverClearSearch;

  /// No description provided for @serverAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get serverAll;

  /// No description provided for @serverFavorites.
  ///
  /// In zh, this message translates to:
  /// **'常用'**
  String get serverFavorites;

  /// No description provided for @serverFilterLabel.
  ///
  /// In zh, this message translates to:
  /// **'筛选{p0}'**
  String serverFilterLabel(String p0);

  /// No description provided for @serverFilterSelectedSuffix.
  ///
  /// In zh, this message translates to:
  /// **' · 已选'**
  String get serverFilterSelectedSuffix;

  /// No description provided for @serverExpiryNeedsCheck.
  ///
  /// In zh, this message translates to:
  /// **'到期待核对'**
  String get serverExpiryNeedsCheck;

  /// No description provided for @serverExpiryCounts.
  ///
  /// In zh, this message translates to:
  /// **'{p0} 台已过期 · {p1} 台 30 天内到期'**
  String serverExpiryCounts(String p0, String p1);

  /// No description provided for @serverFavoriteServers.
  ///
  /// In zh, this message translates to:
  /// **'常用服务器'**
  String get serverFavoriteServers;

  /// No description provided for @serverAllServers.
  ///
  /// In zh, this message translates to:
  /// **'所有服务器'**
  String get serverAllServers;

  /// No description provided for @serverSort.
  ///
  /// In zh, this message translates to:
  /// **'排序'**
  String get serverSort;

  /// No description provided for @serverSortFavorites.
  ///
  /// In zh, this message translates to:
  /// **'按常用排序'**
  String get serverSortFavorites;

  /// No description provided for @serverSortDue.
  ///
  /// In zh, this message translates to:
  /// **'按到期排序'**
  String get serverSortDue;

  /// No description provided for @serverSortName.
  ///
  /// In zh, this message translates to:
  /// **'按名称排序'**
  String get serverSortName;

  /// No description provided for @serverSortUpdated.
  ///
  /// In zh, this message translates to:
  /// **'按更新时间'**
  String get serverSortUpdated;

  /// No description provided for @serverNoUnarchived.
  ///
  /// In zh, this message translates to:
  /// **'没有未归档服务器'**
  String get serverNoUnarchived;

  /// No description provided for @serverNoMatches.
  ///
  /// In zh, this message translates to:
  /// **'没有符合条件的记录'**
  String get serverNoMatches;

  /// No description provided for @serverNoMatchesHelp.
  ///
  /// In zh, this message translates to:
  /// **'试试调整筛选；已归档记录可在设置中恢复。'**
  String get serverNoMatchesHelp;

  /// No description provided for @uiServersDueSoon.
  ///
  /// In zh, this message translates to:
  /// **'30 天内到期'**
  String get uiServersDueSoon;

  /// No description provided for @uiServersArchive.
  ///
  /// In zh, this message translates to:
  /// **'归档'**
  String get uiServersArchive;

  /// No description provided for @uiServersReset.
  ///
  /// In zh, this message translates to:
  /// **'重置'**
  String get uiServersReset;

  /// No description provided for @uiServersShowCount.
  ///
  /// In zh, this message translates to:
  /// **'显示 {count} 台'**
  String uiServersShowCount(int count);

  /// No description provided for @uiServersRowHint.
  ///
  /// In zh, this message translates to:
  /// **'左滑或长按服务器查看快捷操作'**
  String get uiServersRowHint;

  /// No description provided for @serverClearFilters.
  ///
  /// In zh, this message translates to:
  /// **'清除筛选'**
  String get serverClearFilters;

  /// No description provided for @serverListObservationHelp.
  ///
  /// In zh, this message translates to:
  /// **'不持续监控运行状态；到期天数按设备日期计算。'**
  String get serverListObservationHelp;

  /// No description provided for @serverCostsMissing.
  ///
  /// In zh, this message translates to:
  /// **'费用待补充'**
  String get serverCostsMissing;

  /// No description provided for @serverMeteredBilling.
  ///
  /// In zh, this message translates to:
  /// **'按量计费'**
  String get serverMeteredBilling;

  /// No description provided for @serverDueUnknown.
  ///
  /// In zh, this message translates to:
  /// **'到期日未知'**
  String get serverDueUnknown;

  /// No description provided for @serverExpiredDays.
  ///
  /// In zh, this message translates to:
  /// **'已过期 {p0} 天 · 待核实'**
  String serverExpiredDays(int p0);

  /// No description provided for @serverDueToday.
  ///
  /// In zh, this message translates to:
  /// **'今天到期'**
  String get serverDueToday;

  /// No description provided for @serverDueInDays.
  ///
  /// In zh, this message translates to:
  /// **'{p0} 天后到期'**
  String serverDueInDays(int p0);

  /// No description provided for @serverDemo.
  ///
  /// In zh, this message translates to:
  /// **'演示'**
  String get serverDemo;

  /// No description provided for @serverLocalUnqueried.
  ///
  /// In zh, this message translates to:
  /// **'本地记录 · 未查询运行状态'**
  String get serverLocalUnqueried;

  /// No description provided for @serverNotEntered.
  ///
  /// In zh, this message translates to:
  /// **'未填写'**
  String get serverNotEntered;

  /// No description provided for @resourceUnlimitedConfirmed.
  ///
  /// In zh, this message translates to:
  /// **'不限量（已确认）'**
  String get resourceUnlimitedConfirmed;

  /// No description provided for @resourceCardHelp.
  ///
  /// In zh, this message translates to:
  /// **'仅本地资料，不会从商家读取。'**
  String get resourceCardHelp;

  /// No description provided for @serverSavedDisplayStale.
  ///
  /// In zh, this message translates to:
  /// **'写入已保存，显示内容暂未更新'**
  String get serverSavedDisplayStale;

  /// No description provided for @serverReloadBeforeEditing.
  ///
  /// In zh, this message translates to:
  /// **'请先重新读取本地台账，再继续修改。不要重复提交，原数据不会被清除。'**
  String get serverReloadBeforeEditing;

  /// No description provided for @serverReloadStillFailed.
  ///
  /// In zh, this message translates to:
  /// **'读取仍未完成，已保存的改动保留。请稍后重新读取。'**
  String get serverReloadStillFailed;

  /// No description provided for @serverReload.
  ///
  /// In zh, this message translates to:
  /// **'重新读取'**
  String get serverReload;

  /// No description provided for @serverArchiveQuestion.
  ///
  /// In zh, this message translates to:
  /// **'归档这台服务器？'**
  String get serverArchiveQuestion;

  /// No description provided for @serverArchiveHelp.
  ///
  /// In zh, this message translates to:
  /// **'{p0}\n\n归档后将从服务器列表和当前费用统计中隐藏，历史付款保留。可在“设置 / 已归档记录”中恢复。不会关闭或销毁服务器，也不会停止厂商扣费。'**
  String serverArchiveHelp(String p0);

  /// No description provided for @serverArchiveLocal.
  ///
  /// In zh, this message translates to:
  /// **'归档本地记录'**
  String get serverArchiveLocal;

  /// No description provided for @serverArchived.
  ///
  /// In zh, this message translates to:
  /// **'已归档，云端资源和扣费未改变'**
  String get serverArchived;

  /// No description provided for @serverUndo.
  ///
  /// In zh, this message translates to:
  /// **'撤销'**
  String get serverUndo;

  /// No description provided for @serverUndoArchiveFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法撤销，请在设置的归档记录中检查'**
  String get serverUndoArchiveFailed;

  /// No description provided for @serverMissingDetails.
  ///
  /// In zh, this message translates to:
  /// **'待补充'**
  String get serverMissingDetails;

  /// No description provided for @serverDetails.
  ///
  /// In zh, this message translates to:
  /// **'服务器详情'**
  String get serverDetails;

  /// No description provided for @serverRecordUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'记录暂不可用，请返回重试'**
  String get serverRecordUnavailable;

  /// No description provided for @serverRemoveFavorite.
  ///
  /// In zh, this message translates to:
  /// **'取消常用'**
  String get serverRemoveFavorite;

  /// No description provided for @serverSetFavorite.
  ///
  /// In zh, this message translates to:
  /// **'设为常用'**
  String get serverSetFavorite;

  /// No description provided for @serverMoreActions.
  ///
  /// In zh, this message translates to:
  /// **'更多操作'**
  String get serverMoreActions;

  /// No description provided for @serverDemoWarning.
  ///
  /// In zh, this message translates to:
  /// **'演示记录 · 保留地址，不连接真实服务器'**
  String get serverDemoWarning;

  /// No description provided for @serverBasicInfo.
  ///
  /// In zh, this message translates to:
  /// **'基本信息'**
  String get serverBasicInfo;

  /// No description provided for @serverEdit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get serverEdit;

  /// No description provided for @serverHostAddress.
  ///
  /// In zh, this message translates to:
  /// **'主机地址'**
  String get serverHostAddress;

  /// Server form and detail.
  ///
  /// In zh, this message translates to:
  /// **'原有地址'**
  String get r7DetailSavedAddress;

  /// No description provided for @serverCopyHost.
  ///
  /// In zh, this message translates to:
  /// **'复制地址'**
  String get serverCopyHost;

  /// No description provided for @serverHostCopied.
  ///
  /// In zh, this message translates to:
  /// **'地址已复制'**
  String get serverHostCopied;

  /// No description provided for @serverCopyHostFailed.
  ///
  /// In zh, this message translates to:
  /// **'未能复制地址，请重试。'**
  String get serverCopyHostFailed;

  /// No description provided for @serverOperatingSystem.
  ///
  /// In zh, this message translates to:
  /// **'操作系统'**
  String get serverOperatingSystem;

  /// No description provided for @serverGroupPurpose.
  ///
  /// In zh, this message translates to:
  /// **'分组 / 用途'**
  String get serverGroupPurpose;

  /// No description provided for @serverSpecifications.
  ///
  /// In zh, this message translates to:
  /// **'规格'**
  String get serverSpecifications;

  /// No description provided for @serverEditHardware.
  ///
  /// In zh, this message translates to:
  /// **'编辑硬件'**
  String get serverEditHardware;

  /// No description provided for @serverCostExpiry.
  ///
  /// In zh, this message translates to:
  /// **'费用与到期'**
  String get serverCostExpiry;

  /// No description provided for @serverMonthlyEstimate.
  ///
  /// In zh, this message translates to:
  /// **'月费用估算'**
  String get serverMonthlyEstimate;

  /// No description provided for @serverRenewalAmount.
  ///
  /// In zh, this message translates to:
  /// **'续费金额'**
  String get serverRenewalAmount;

  /// No description provided for @serverRenewalCycle.
  ///
  /// In zh, this message translates to:
  /// **'续费周期'**
  String get serverRenewalCycle;

  /// No description provided for @serverMonths.
  ///
  /// In zh, this message translates to:
  /// **'{p0} 个月'**
  String serverMonths(int p0);

  /// No description provided for @serverServiceStart.
  ///
  /// In zh, this message translates to:
  /// **'服务开始日'**
  String get serverServiceStart;

  /// No description provided for @serverUnknown.
  ///
  /// In zh, this message translates to:
  /// **'未知'**
  String get serverUnknown;

  /// No description provided for @serverServiceDue.
  ///
  /// In zh, this message translates to:
  /// **'服务到期日'**
  String get serverServiceDue;

  /// No description provided for @serverUnknownCostHelp.
  ///
  /// In zh, this message translates to:
  /// **'未填写的金额不会按 0 计算。'**
  String get serverUnknownCostHelp;

  /// No description provided for @serverMeteredValueHelp.
  ///
  /// In zh, this message translates to:
  /// **'按量计费只作月估算，不计算剩余价值。'**
  String get serverMeteredValueHelp;

  /// No description provided for @serverRenewalValueHelp.
  ///
  /// In zh, this message translates to:
  /// **'剩余价值仅为按续费价折算的参考，不是退款或成交价。'**
  String get serverRenewalValueHelp;

  /// No description provided for @serverReminderPlan.
  ///
  /// In zh, this message translates to:
  /// **'到期提醒与使用计划'**
  String get serverReminderPlan;

  /// No description provided for @serverRemindersOff.
  ///
  /// In zh, this message translates to:
  /// **'提醒已关闭'**
  String get serverRemindersOff;

  /// No description provided for @serverRemainingValue.
  ///
  /// In zh, this message translates to:
  /// **'剩余价值'**
  String get serverRemainingValue;

  /// No description provided for @serverUnknownValueHelp.
  ///
  /// In zh, this message translates to:
  /// **'日期或费用资料不足，剩余价值未知，不按 0 计算。'**
  String get serverUnknownValueHelp;

  /// No description provided for @serverRecordPayment.
  ///
  /// In zh, this message translates to:
  /// **'记录已付款'**
  String get serverRecordPayment;

  /// No description provided for @serverUseForCalculation.
  ///
  /// In zh, this message translates to:
  /// **'引用资料试算'**
  String get serverUseForCalculation;

  /// No description provided for @serverViewPayments.
  ///
  /// In zh, this message translates to:
  /// **'查看付款记录'**
  String get serverViewPayments;

  /// No description provided for @serverConnectionsControl.
  ///
  /// In zh, this message translates to:
  /// **'连接与控制'**
  String get serverConnectionsControl;

  /// No description provided for @serverSshSettings.
  ///
  /// In zh, this message translates to:
  /// **'SSH 连接配置'**
  String get serverSshSettings;

  /// No description provided for @serverSshSettingsDescription.
  ///
  /// In zh, this message translates to:
  /// **'连接地址、端口、用户名和登录凭据'**
  String get serverSshSettingsDescription;

  /// No description provided for @serverConnectSsh.
  ///
  /// In zh, this message translates to:
  /// **'连接 SSH'**
  String get serverConnectSsh;

  /// No description provided for @serverTcpTest.
  ///
  /// In zh, this message translates to:
  /// **'TCP 测试'**
  String get serverTcpTest;

  /// No description provided for @serverPower.
  ///
  /// In zh, this message translates to:
  /// **'单机电源'**
  String get serverPower;

  /// No description provided for @serverConnectionSafety.
  ///
  /// In zh, this message translates to:
  /// **'首次连接需核对主机指纹；关机或重启不会停止计费。'**
  String get serverConnectionSafety;

  /// No description provided for @serverNotes.
  ///
  /// In zh, this message translates to:
  /// **'备注'**
  String get serverNotes;

  /// No description provided for @serverSavedMetadata.
  ///
  /// In zh, this message translates to:
  /// **'本地保存于 {p0}\n服务器 ID：{p1}'**
  String serverSavedMetadata(String p0, String p1);

  /// No description provided for @uiDetailCopy.
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get uiDetailCopy;

  /// No description provided for @uiDetailMenuValuation.
  ///
  /// In zh, this message translates to:
  /// **'用于剩余价值试算'**
  String get uiDetailMenuValuation;

  /// No description provided for @uiDetailPurpose.
  ///
  /// In zh, this message translates to:
  /// **'用途'**
  String get uiDetailPurpose;

  /// No description provided for @uiDetailRegion.
  ///
  /// In zh, this message translates to:
  /// **'地区'**
  String get uiDetailRegion;

  /// No description provided for @uiDetailDueOn.
  ///
  /// In zh, this message translates to:
  /// **'到期 {date}'**
  String uiDetailDueOn(String date);

  /// No description provided for @uiDetailConverted.
  ///
  /// In zh, this message translates to:
  /// **'折合 {currency}'**
  String uiDetailConverted(String currency);

  /// No description provided for @uiDetailDaily.
  ///
  /// In zh, this message translates to:
  /// **'日均'**
  String get uiDetailDaily;

  /// No description provided for @uiDetailRemainingDays.
  ///
  /// In zh, this message translates to:
  /// **'剩余天数'**
  String get uiDetailRemainingDays;

  /// No description provided for @uiDetailPayments.
  ///
  /// In zh, this message translates to:
  /// **'付款记录'**
  String get uiDetailPayments;

  /// No description provided for @uiDetailValuation.
  ///
  /// In zh, this message translates to:
  /// **'价值试算'**
  String get uiDetailValuation;

  /// No description provided for @uiDetailFillIn.
  ///
  /// In zh, this message translates to:
  /// **'补填'**
  String get uiDetailFillIn;

  /// No description provided for @uiDetailHostKey.
  ///
  /// In zh, this message translates to:
  /// **'主机公钥'**
  String get uiDetailHostKey;

  /// No description provided for @uiDetailHostKeyTrusted.
  ///
  /// In zh, this message translates to:
  /// **'已核验'**
  String get uiDetailHostKeyTrusted;

  /// No description provided for @uiDetailHostKeyFirstUse.
  ///
  /// In zh, this message translates to:
  /// **'首次连接时核验'**
  String get uiDetailHostKeyFirstUse;

  /// No description provided for @uiDetailNotConfigured.
  ///
  /// In zh, this message translates to:
  /// **'未配置'**
  String get uiDetailNotConfigured;

  /// No description provided for @uiDetailNeedSshTitle.
  ///
  /// In zh, this message translates to:
  /// **'尚未配置 SSH'**
  String get uiDetailNeedSshTitle;

  /// No description provided for @uiDetailNeedSshMessage.
  ///
  /// In zh, this message translates to:
  /// **'为 {name} 设置地址、端口、用户名和登录凭据后，才能连接或执行电源操作。'**
  String uiDetailNeedSshMessage(String name);

  /// No description provided for @uiDetailGoConfigure.
  ///
  /// In zh, this message translates to:
  /// **'去配置'**
  String get uiDetailGoConfigure;

  /// No description provided for @uiDetailArchivedUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'已归档的服务器不能进行此操作。'**
  String get uiDetailArchivedUnavailable;

  /// No description provided for @uiDetailNotPrepaid.
  ///
  /// In zh, this message translates to:
  /// **'只有预付服务器可以记录续费付款。'**
  String get uiDetailNotPrepaid;

  /// No description provided for @uiDetailCannotRenew.
  ///
  /// In zh, this message translates to:
  /// **'到期日或续费周期资料不完整，暂时无法记录续费付款。请先补充费用资料。'**
  String get uiDetailCannotRenew;

  /// No description provided for @uiDetailReadOnly.
  ///
  /// In zh, this message translates to:
  /// **'本地数据读取未完成或正在处理，暂时不能记录付款。请先重新读取。'**
  String get uiDetailReadOnly;

  /// No description provided for @uiDetailQuickSsh.
  ///
  /// In zh, this message translates to:
  /// **'SSH 连接'**
  String get uiDetailQuickSsh;

  /// No description provided for @uiDetailQuickPayment.
  ///
  /// In zh, this message translates to:
  /// **'记录付款'**
  String get uiDetailQuickPayment;

  /// No description provided for @uiDetailQuickPower.
  ///
  /// In zh, this message translates to:
  /// **'电源'**
  String get uiDetailQuickPower;

  /// No description provided for @r2DetailMetricValue.
  ///
  /// In zh, this message translates to:
  /// **'剩余价值'**
  String get r2DetailMetricValue;

  /// No description provided for @r2DetailMetricDays.
  ///
  /// In zh, this message translates to:
  /// **'剩余天数'**
  String get r2DetailMetricDays;

  /// No description provided for @r2DetailMetricDaily.
  ///
  /// In zh, this message translates to:
  /// **'日均'**
  String get r2DetailMetricDaily;

  /// No description provided for @serverRequiredField.
  ///
  /// In zh, this message translates to:
  /// **'请填写{p0}'**
  String serverRequiredField(String p0);

  /// No description provided for @serverAmountPrecision.
  ///
  /// In zh, this message translates to:
  /// **'请输入有效金额，最多两位小数'**
  String get serverAmountPrecision;

  /// No description provided for @serverDateExample.
  ///
  /// In zh, this message translates to:
  /// **'请使用有效日期，例如 2026-10-06'**
  String get serverDateExample;

  /// No description provided for @serverBillingType.
  ///
  /// In zh, this message translates to:
  /// **'计费方式'**
  String get serverBillingType;

  /// No description provided for @serverEveryYear.
  ///
  /// In zh, this message translates to:
  /// **'每年'**
  String get serverEveryYear;

  /// No description provided for @serverEveryMonths.
  ///
  /// In zh, this message translates to:
  /// **'每 {p0} 个月'**
  String serverEveryMonths(int p0);

  /// No description provided for @serverHalfYear.
  ///
  /// In zh, this message translates to:
  /// **'半年'**
  String get serverHalfYear;

  /// No description provided for @serverTwoYears.
  ///
  /// In zh, this message translates to:
  /// **'2年'**
  String get serverTwoYears;

  /// No description provided for @serverThreeYears.
  ///
  /// In zh, this message translates to:
  /// **'3年'**
  String get serverThreeYears;

  /// No description provided for @serverAmount.
  ///
  /// In zh, this message translates to:
  /// **'金额'**
  String get serverAmount;

  /// No description provided for @serverOriginalCurrency.
  ///
  /// In zh, this message translates to:
  /// **'原币种'**
  String get serverOriginalCurrency;

  /// No description provided for @serverCurrency.
  ///
  /// In zh, this message translates to:
  /// **'币种'**
  String get serverCurrency;

  /// No description provided for @serverMonthlyCostEstimate.
  ///
  /// In zh, this message translates to:
  /// **'每月费用估算'**
  String get serverMonthlyCostEstimate;

  /// No description provided for @serverRenewalPriceHelp.
  ///
  /// In zh, this message translates to:
  /// **'{p0}续费金额，实付另记'**
  String serverRenewalPriceHelp(String p0);

  /// No description provided for @serverStartDate.
  ///
  /// In zh, this message translates to:
  /// **'开始日期'**
  String get serverStartDate;

  /// No description provided for @serverDueDate.
  ///
  /// In zh, this message translates to:
  /// **'到期日期'**
  String get serverDueDate;

  /// No description provided for @serverOptionalStart.
  ///
  /// In zh, this message translates to:
  /// **'服务开始日（选填）'**
  String get serverOptionalStart;

  /// No description provided for @serverOptionalDue.
  ///
  /// In zh, this message translates to:
  /// **'服务到期日（选填）'**
  String get serverOptionalDue;

  /// No description provided for @serverEditTitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑服务器'**
  String get serverEditTitle;

  /// No description provided for @serverFormHelp.
  ///
  /// In zh, this message translates to:
  /// **'仅保存在本机，不会修改远端。'**
  String get serverFormHelp;

  /// No description provided for @serverBasicData.
  ///
  /// In zh, this message translates to:
  /// **'基本资料'**
  String get serverBasicData;

  /// No description provided for @serverName.
  ///
  /// In zh, this message translates to:
  /// **'服务器名称'**
  String get serverName;

  /// No description provided for @serverProvider.
  ///
  /// In zh, this message translates to:
  /// **'厂商'**
  String get serverProvider;

  /// No description provided for @serverProviderExample.
  ///
  /// In zh, this message translates to:
  /// **'例如：搬瓦工 / 自定义厂商'**
  String get serverProviderExample;

  /// No description provided for @serverNewHostHelp.
  ///
  /// In zh, this message translates to:
  /// **'新建时留空会采用硬件信息中的 IP 或主机名；SSH 连接地址另行设置。'**
  String get serverNewHostHelp;

  /// No description provided for @serverSavedHostHelp.
  ///
  /// In zh, this message translates to:
  /// **'此地址独立保存，修改硬件不会更改它；SSH 连接地址另行设置。'**
  String get serverSavedHostHelp;

  /// No description provided for @serverOptionalPurpose.
  ///
  /// In zh, this message translates to:
  /// **'用途（选填）'**
  String get serverOptionalPurpose;

  /// No description provided for @serverOptionalRegion.
  ///
  /// In zh, this message translates to:
  /// **'地区（选填）'**
  String get serverOptionalRegion;

  /// No description provided for @serverOptionalOs.
  ///
  /// In zh, this message translates to:
  /// **'操作系统（选填）'**
  String get serverOptionalOs;

  /// No description provided for @serverOptionalSpec.
  ///
  /// In zh, this message translates to:
  /// **'规格补充（选填）'**
  String get serverOptionalSpec;

  /// No description provided for @serverSpecExample.
  ///
  /// In zh, this message translates to:
  /// **'例如：CPU 型号、网络带宽'**
  String get serverSpecExample;

  /// No description provided for @serverCostDetails.
  ///
  /// In zh, this message translates to:
  /// **'费用资料'**
  String get serverCostDetails;

  /// No description provided for @serverPaymentLockHelp.
  ///
  /// In zh, this message translates to:
  /// **'已有续费付款：计费方式、周期和日期已锁定。'**
  String get serverPaymentLockHelp;

  /// No description provided for @serverCostUnknownOption.
  ///
  /// In zh, this message translates to:
  /// **'费用未知 · 稍后补充'**
  String get serverCostUnknownOption;

  /// No description provided for @serverPrepaidOption.
  ///
  /// In zh, this message translates to:
  /// **'预付费 · 按周期续费'**
  String get serverPrepaidOption;

  /// No description provided for @serverMeteredOption.
  ///
  /// In zh, this message translates to:
  /// **'按量付费 · 月估算'**
  String get serverMeteredOption;

  /// No description provided for @serverPrepaid.
  ///
  /// In zh, this message translates to:
  /// **'预付费'**
  String get serverPrepaid;

  /// No description provided for @serverMetered.
  ///
  /// In zh, this message translates to:
  /// **'按量付费'**
  String get serverMetered;

  /// No description provided for @serverDatesHelp.
  ///
  /// In zh, this message translates to:
  /// **'到期日默认按开始日加周期计算，可手动修改。'**
  String get serverDatesHelp;

  /// No description provided for @serverAmountHelp.
  ///
  /// In zh, this message translates to:
  /// **'0 表示免费；未知请选“未知”。不会记录付款。'**
  String get serverAmountHelp;

  /// No description provided for @serverOptionalNotes.
  ///
  /// In zh, this message translates to:
  /// **'备注（选填）'**
  String get serverOptionalNotes;

  /// No description provided for @serverNotesSafety.
  ///
  /// In zh, this message translates to:
  /// **'备注不加密，请勿存放密码、私钥或令牌。'**
  String get serverNotesSafety;

  /// No description provided for @serverSave.
  ///
  /// In zh, this message translates to:
  /// **'保存服务器'**
  String get serverSave;

  /// No description provided for @uiFormProvider.
  ///
  /// In zh, this message translates to:
  /// **'提供商'**
  String get uiFormProvider;

  /// Server form and detail.
  ///
  /// In zh, this message translates to:
  /// **'不指定'**
  String get r7FormProviderNone;

  /// Server form and detail.
  ///
  /// In zh, this message translates to:
  /// **'新建提供商…'**
  String get r7FormProviderNew;

  /// No description provided for @uiFormPurpose.
  ///
  /// In zh, this message translates to:
  /// **'用途'**
  String get uiFormPurpose;

  /// No description provided for @uiFormRegion.
  ///
  /// In zh, this message translates to:
  /// **'地区'**
  String get uiFormRegion;

  /// No description provided for @uiFormSpec.
  ///
  /// In zh, this message translates to:
  /// **'规格补充'**
  String get uiFormSpec;

  /// No description provided for @uiFormOptional.
  ///
  /// In zh, this message translates to:
  /// **'选填'**
  String get uiFormOptional;

  /// No description provided for @uiFormNameHint.
  ///
  /// In zh, this message translates to:
  /// **'例如 HK-01'**
  String get uiFormNameHint;

  /// No description provided for @uiFormDone.
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get uiFormDone;

  /// No description provided for @uiFormSetUnknown.
  ///
  /// In zh, this message translates to:
  /// **'设为未知'**
  String get uiFormSetUnknown;

  /// No description provided for @uiFormPickDate.
  ///
  /// In zh, this message translates to:
  /// **'选择日期'**
  String get uiFormPickDate;

  /// No description provided for @uiFormUnknownCostFootnote.
  ///
  /// In zh, this message translates to:
  /// **'费用未知时不计入合计。'**
  String get uiFormUnknownCostFootnote;

  /// No description provided for @uiFormVcpuDecrease.
  ///
  /// In zh, this message translates to:
  /// **'减少 vCPU'**
  String get uiFormVcpuDecrease;

  /// No description provided for @uiFormVcpuIncrease.
  ///
  /// In zh, this message translates to:
  /// **'增加 vCPU'**
  String get uiFormVcpuIncrease;

  /// No description provided for @uiFormCollapse.
  ///
  /// In zh, this message translates to:
  /// **'收起硬件信息'**
  String get uiFormCollapse;

  /// No description provided for @uiFormExpand.
  ///
  /// In zh, this message translates to:
  /// **'展开硬件信息'**
  String get uiFormExpand;

  /// No description provided for @uiFormMemory.
  ///
  /// In zh, this message translates to:
  /// **'内存'**
  String get uiFormMemory;

  /// No description provided for @uiFormDisk.
  ///
  /// In zh, this message translates to:
  /// **'磁盘'**
  String get uiFormDisk;

  /// No description provided for @uiFormTraffic.
  ///
  /// In zh, this message translates to:
  /// **'流量'**
  String get uiFormTraffic;

  /// No description provided for @uiFormBillingPrepaid.
  ///
  /// In zh, this message translates to:
  /// **'预付'**
  String get uiFormBillingPrepaid;

  /// No description provided for @uiFormBillingMetered.
  ///
  /// In zh, this message translates to:
  /// **'按量'**
  String get uiFormBillingMetered;

  /// No description provided for @serverWaitForOperation.
  ///
  /// In zh, this message translates to:
  /// **'请等待当前操作完成'**
  String get serverWaitForOperation;

  /// No description provided for @serverReloadSavedFirst.
  ///
  /// In zh, this message translates to:
  /// **'请先重新读取已保存的台账'**
  String get serverReloadSavedFirst;

  /// No description provided for @connectionBrowserTcpUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'浏览器没有原生 TCP；请使用原生应用'**
  String get connectionBrowserTcpUnsupported;

  /// No description provided for @connectionHostKeyUnverified.
  ///
  /// In zh, this message translates to:
  /// **'无法核实完整主机公钥，连接已阻止'**
  String get connectionHostKeyUnverified;

  /// No description provided for @connectionHandshakeUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'SSH 握手格式或大小不受支持'**
  String get connectionHandshakeUnsupported;

  /// No description provided for @tcpValidIpv6.
  ///
  /// In zh, this message translates to:
  /// **'请输入有效的 IPv6 地址'**
  String get tcpValidIpv6;

  /// No description provided for @tcpValidHost.
  ///
  /// In zh, this message translates to:
  /// **'请输入 IP 或域名，不含协议、端口或路径'**
  String get tcpValidHost;

  /// No description provided for @tcpValidPort.
  ///
  /// In zh, this message translates to:
  /// **'端口需为 1–65535'**
  String get tcpValidPort;

  /// No description provided for @tcpSource.
  ///
  /// In zh, this message translates to:
  /// **'本机 TCP 连接测试'**
  String get tcpSource;

  /// No description provided for @tcpConnected.
  ///
  /// In zh, this message translates to:
  /// **'TCP 连接成功'**
  String get tcpConnected;

  /// No description provided for @tcpRefused.
  ///
  /// In zh, this message translates to:
  /// **'连接被拒绝'**
  String get tcpRefused;

  /// No description provided for @tcpTimedOut.
  ///
  /// In zh, this message translates to:
  /// **'连接超时'**
  String get tcpTimedOut;

  /// No description provided for @tcpCancelled.
  ///
  /// In zh, this message translates to:
  /// **'测试已取消'**
  String get tcpCancelled;

  /// No description provided for @tcpFailed.
  ///
  /// In zh, this message translates to:
  /// **'连接失败（网络或地址不可用）'**
  String get tcpFailed;

  /// No description provided for @tcpTimeoutPositive.
  ///
  /// In zh, this message translates to:
  /// **'超时必须大于 0'**
  String get tcpTimeoutPositive;

  /// No description provided for @tcpSingleTarget.
  ///
  /// In zh, this message translates to:
  /// **'单目标 TCP 测试'**
  String get tcpSingleTarget;

  /// No description provided for @tcpTestExplanation.
  ///
  /// In zh, this message translates to:
  /// **'仅测试能否建立 TCP 连接，不发送数据。成功不代表 SSH 可登录或服务正常。'**
  String get tcpTestExplanation;

  /// No description provided for @tcpAddress.
  ///
  /// In zh, this message translates to:
  /// **'IP / 域名'**
  String get tcpAddress;

  /// No description provided for @connectionPort.
  ///
  /// In zh, this message translates to:
  /// **'端口'**
  String get connectionPort;

  /// No description provided for @tcpTestingTarget.
  ///
  /// In zh, this message translates to:
  /// **'正在测试 {p0}'**
  String tcpTestingTarget(String p0);

  /// No description provided for @tcpCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消测试'**
  String get tcpCancel;

  /// No description provided for @tcpStart.
  ///
  /// In zh, this message translates to:
  /// **'开始测试'**
  String get tcpStart;

  /// No description provided for @tcpTimeoutHelp.
  ///
  /// In zh, this message translates to:
  /// **'单次最多 {p0} 秒；修改目标、离开页面或进入后台会取消测试。'**
  String tcpTimeoutHelp(int p0);

  /// No description provided for @tcpTarget.
  ///
  /// In zh, this message translates to:
  /// **'目标：{p0}'**
  String tcpTarget(String p0);

  /// No description provided for @tcpActualAddress.
  ///
  /// In zh, this message translates to:
  /// **'实际地址：{p0}'**
  String tcpActualAddress(String p0);

  /// No description provided for @tcpResultSource.
  ///
  /// In zh, this message translates to:
  /// **'来源：{p0}'**
  String tcpResultSource(String p0);

  /// No description provided for @tcpFinished.
  ///
  /// In zh, this message translates to:
  /// **'结束时间：{p0}（本机时间）'**
  String tcpFinished(String p0);

  /// No description provided for @tcpElapsed.
  ///
  /// In zh, this message translates to:
  /// **'耗时：{p0} ms'**
  String tcpElapsed(String p0);

  /// No description provided for @tcpOneObservation.
  ///
  /// In zh, this message translates to:
  /// **'此结果仅反映当次观察，不是持续状态。'**
  String get tcpOneObservation;

  /// No description provided for @terminalCurrentDirectory.
  ///
  /// In zh, this message translates to:
  /// **'当前目录'**
  String get terminalCurrentDirectory;

  /// No description provided for @terminalListFiles.
  ///
  /// In zh, this message translates to:
  /// **'列出文件'**
  String get terminalListFiles;

  /// No description provided for @terminalUptime.
  ///
  /// In zh, this message translates to:
  /// **'运行时间'**
  String get terminalUptime;

  /// No description provided for @terminalDiskUsage.
  ///
  /// In zh, this message translates to:
  /// **'磁盘用量'**
  String get terminalDiskUsage;

  /// No description provided for @terminalMemoryUsage.
  ///
  /// In zh, this message translates to:
  /// **'内存用量'**
  String get terminalMemoryUsage;

  /// No description provided for @terminalCommandsWithDraft.
  ///
  /// In zh, this message translates to:
  /// **'命令与片段 · 有未发送草稿'**
  String get terminalCommandsWithDraft;

  /// No description provided for @terminalCommandsSnippets.
  ///
  /// In zh, this message translates to:
  /// **'命令与片段'**
  String get terminalCommandsSnippets;

  /// No description provided for @terminalCommands.
  ///
  /// In zh, this message translates to:
  /// **'命令'**
  String get terminalCommands;

  /// No description provided for @terminalControlHelp.
  ///
  /// In zh, this message translates to:
  /// **'Ctrl，作用于下一个按键，再点取消'**
  String get terminalControlHelp;

  /// No description provided for @terminalControlPaste.
  ///
  /// In zh, this message translates to:
  /// **'Ctrl V · 粘贴到草稿，不自动发送'**
  String get terminalControlPaste;

  /// No description provided for @terminalArrowUp.
  ///
  /// In zh, this message translates to:
  /// **'向上方向键'**
  String get terminalArrowUp;

  /// No description provided for @terminalArrowDown.
  ///
  /// In zh, this message translates to:
  /// **'向下方向键'**
  String get terminalArrowDown;

  /// No description provided for @terminalArrowLeft.
  ///
  /// In zh, this message translates to:
  /// **'向左方向键'**
  String get terminalArrowLeft;

  /// No description provided for @terminalArrowRight.
  ///
  /// In zh, this message translates to:
  /// **'向右方向键'**
  String get terminalArrowRight;

  /// No description provided for @terminalSendUnconfirmed.
  ///
  /// In zh, this message translates to:
  /// **'发送未确认，草稿仍保留。请先核实远端状态，避免重复执行。'**
  String get terminalSendUnconfirmed;

  /// No description provided for @terminalSend.
  ///
  /// In zh, this message translates to:
  /// **'发送'**
  String get terminalSend;

  /// No description provided for @terminalSendExecute.
  ///
  /// In zh, this message translates to:
  /// **'发送并执行'**
  String get terminalSendExecute;

  /// No description provided for @terminalBack.
  ///
  /// In zh, this message translates to:
  /// **'返回终端'**
  String get terminalBack;

  /// No description provided for @terminalQuickCommands.
  ///
  /// In zh, this message translates to:
  /// **'常用命令'**
  String get terminalQuickCommands;

  /// No description provided for @terminalInsertSnippet.
  ///
  /// In zh, this message translates to:
  /// **'插入片段'**
  String get terminalInsertSnippet;

  /// No description provided for @terminalDraft.
  ///
  /// In zh, this message translates to:
  /// **'待发送草稿'**
  String get terminalDraft;

  /// No description provided for @terminalDraftHint.
  ///
  /// In zh, this message translates to:
  /// **'在此编辑要发送的内容'**
  String get terminalDraftHint;

  /// No description provided for @terminalPaste.
  ///
  /// In zh, this message translates to:
  /// **'粘贴'**
  String get terminalPaste;

  /// No description provided for @terminalSendTo.
  ///
  /// In zh, this message translates to:
  /// **'发送到'**
  String get terminalSendTo;

  /// No description provided for @terminalControlCharacterWarning.
  ///
  /// In zh, this message translates to:
  /// **'正文含换行、回车或控制字符，不追加回车也可能立即执行。'**
  String get terminalControlCharacterWarning;

  /// No description provided for @terminalSessionChanged.
  ///
  /// In zh, this message translates to:
  /// **'会话已变化，请返回终端后重新打开。草稿不会自动发送。'**
  String get terminalSessionChanged;

  /// No description provided for @terminalCannotSend.
  ///
  /// In zh, this message translates to:
  /// **'当前不可发送。重连会清空草稿，不重放输入。'**
  String get terminalCannotSend;

  /// No description provided for @terminalSendMeaning.
  ///
  /// In zh, this message translates to:
  /// **'“发送”不追加回车；“发送并执行”追加回车，由当前终端程序处理。'**
  String get terminalSendMeaning;

  /// No description provided for @connectionReadFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法读取连接资料，请重试'**
  String get connectionReadFailed;

  /// No description provided for @connectionTemporary.
  ///
  /// In zh, this message translates to:
  /// **'临时连接'**
  String get connectionTemporary;

  /// No description provided for @connectionInvalidDetails.
  ///
  /// In zh, this message translates to:
  /// **'连接资料无效，请检查地址、端口和凭据'**
  String get connectionInvalidDetails;

  /// No description provided for @connectionChoosePowerTarget.
  ///
  /// In zh, this message translates to:
  /// **'选择单机电源目标'**
  String get connectionChoosePowerTarget;

  /// No description provided for @connectionIdentityFirst.
  ///
  /// In zh, this message translates to:
  /// **'一次只连接一台。核对主机身份后，才向服务器发送所选凭据的认证信息。'**
  String get connectionIdentityFirst;

  /// No description provided for @connectionWebPreviewWarning.
  ///
  /// In zh, this message translates to:
  /// **'Web 预览不支持原生 SSH / TCP，也不接受真实登录凭据。请使用原生应用。'**
  String get connectionWebPreviewWarning;

  /// No description provided for @connectionReloadDetails.
  ///
  /// In zh, this message translates to:
  /// **'重新读取连接资料'**
  String get connectionReloadDetails;

  /// No description provided for @connectionTargetServer.
  ///
  /// In zh, this message translates to:
  /// **'目标服务器'**
  String get connectionTargetServer;

  /// No description provided for @connectionTemporaryTarget.
  ///
  /// In zh, this message translates to:
  /// **'临时目标 · 不保存配置'**
  String get connectionTemporaryTarget;

  /// No description provided for @connectionDemoSuffix.
  ///
  /// In zh, this message translates to:
  /// **' · 演示，不连接'**
  String get connectionDemoSuffix;

  /// No description provided for @connectionDemoBlocked.
  ///
  /// In zh, this message translates to:
  /// **'演示服务器使用保留地址，不允许建立网络连接。'**
  String get connectionDemoBlocked;

  /// No description provided for @connectionAddressHint.
  ///
  /// In zh, this message translates to:
  /// **'IPv4 / IPv6 / 域名'**
  String get connectionAddressHint;

  /// No description provided for @connectionValidHost.
  ///
  /// In zh, this message translates to:
  /// **'请输入有效主机，不含协议、用户名或端口'**
  String get connectionValidHost;

  /// No description provided for @connectionPortRange.
  ///
  /// In zh, this message translates to:
  /// **'端口应为 1–65535'**
  String get connectionPortRange;

  /// No description provided for @connectionUsername.
  ///
  /// In zh, this message translates to:
  /// **'登录用户名'**
  String get connectionUsername;

  /// No description provided for @connectionValidUsername.
  ///
  /// In zh, this message translates to:
  /// **'请填写有效的登录用户名'**
  String get connectionValidUsername;

  /// No description provided for @connectionSavedCredentials.
  ///
  /// In zh, this message translates to:
  /// **'已保存的登录凭据'**
  String get connectionSavedCredentials;

  /// No description provided for @connectionChooseCredentials.
  ///
  /// In zh, this message translates to:
  /// **'请选择登录凭据'**
  String get connectionChooseCredentials;

  /// No description provided for @connectionUseDefaultUsername.
  ///
  /// In zh, this message translates to:
  /// **'使用默认用户名：{p0}'**
  String connectionUseDefaultUsername(String p0);

  /// No description provided for @connectionManageCredentials.
  ///
  /// In zh, this message translates to:
  /// **'管理凭据'**
  String get connectionManageCredentials;

  /// No description provided for @connectionEditSavedSettings.
  ///
  /// In zh, this message translates to:
  /// **'编辑并保存此服务器的 SSH 配置'**
  String get connectionEditSavedSettings;

  /// No description provided for @connectionTemporaryChangesHelp.
  ///
  /// In zh, this message translates to:
  /// **'本页改动只用于本次连接。密码或私钥从已保存的凭据中读取，不在这里输入或另存。进入后台会断开连接；长任务建议在远端使用 tmux / screen。'**
  String get connectionTemporaryChangesHelp;

  /// No description provided for @connectionSnippetDraftOnly.
  ///
  /// In zh, this message translates to:
  /// **'片段将放入独立待发送区。连接、核验、认证都不会发送片段。'**
  String get connectionSnippetDraftOnly;

  /// No description provided for @connectionPowerAfterConnect.
  ///
  /// In zh, this message translates to:
  /// **'连接后选择重启 / 关机，需完成两次确认；不支持开机。'**
  String get connectionPowerAfterConnect;

  /// No description provided for @connectionReviewConnect.
  ///
  /// In zh, this message translates to:
  /// **'核对并连接'**
  String get connectionReviewConnect;

  /// No description provided for @uiConnTarget.
  ///
  /// In zh, this message translates to:
  /// **'目标'**
  String get uiConnTarget;

  /// No description provided for @uiConnCredential.
  ///
  /// In zh, this message translates to:
  /// **'凭据'**
  String get uiConnCredential;

  /// No description provided for @uiConnStatus.
  ///
  /// In zh, this message translates to:
  /// **'状态'**
  String get uiConnStatus;

  /// No description provided for @uiConnHostKey.
  ///
  /// In zh, this message translates to:
  /// **'主机公钥'**
  String get uiConnHostKey;

  /// No description provided for @uiConnHostKeyVerified.
  ///
  /// In zh, this message translates to:
  /// **'已核验'**
  String get uiConnHostKeyVerified;

  /// No description provided for @uiConnHostKeyFirstUse.
  ///
  /// In zh, this message translates to:
  /// **'首次连接需核验'**
  String get uiConnHostKeyFirstUse;

  /// No description provided for @uiConnResult.
  ///
  /// In zh, this message translates to:
  /// **'结果'**
  String get uiConnResult;

  /// No description provided for @uiConnSource.
  ///
  /// In zh, this message translates to:
  /// **'来源'**
  String get uiConnSource;

  /// No description provided for @uiConnFinished.
  ///
  /// In zh, this message translates to:
  /// **'结束时间（本机）'**
  String get uiConnFinished;

  /// No description provided for @uiConnElapsed.
  ///
  /// In zh, this message translates to:
  /// **'耗时'**
  String get uiConnElapsed;

  /// No description provided for @uiConnActualAddress.
  ///
  /// In zh, this message translates to:
  /// **'实际地址'**
  String get uiConnActualAddress;

  /// No description provided for @uiConnMoreActions.
  ///
  /// In zh, this message translates to:
  /// **'更多操作'**
  String get uiConnMoreActions;

  /// No description provided for @snippetFullEscapedPreview.
  ///
  /// In zh, this message translates to:
  /// **'完整内容预览（转义显示）'**
  String get snippetFullEscapedPreview;

  /// No description provided for @snippetEscapeLegend.
  ///
  /// In zh, this message translates to:
  /// **'换行显示为 \\n；回车为 \\r；制表为 \\t；其他控制字符显示为 \\u\'{\'…\'}\'。反斜线也已转义。'**
  String get snippetEscapeLegend;

  /// No description provided for @snippetPreviewNoSend.
  ///
  /// In zh, this message translates to:
  /// **'预览和插入都不会发送内容。请在终端核对目标与完整草稿，再选择“发送”或“发送并执行”。'**
  String get snippetPreviewNoSend;

  /// No description provided for @connectionClose.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get connectionClose;

  /// No description provided for @snippetInsertDraftOnly.
  ///
  /// In zh, this message translates to:
  /// **'仅插入待发送草稿'**
  String get snippetInsertDraftOnly;

  /// No description provided for @snippetChanged.
  ///
  /// In zh, this message translates to:
  /// **'片段已被修改或删除，请重新打开列表后重试。'**
  String get snippetChanged;

  /// No description provided for @snippetOperationFailed.
  ///
  /// In zh, this message translates to:
  /// **'片段操作未完成，请重试。已保存的内容仍保留。'**
  String get snippetOperationFailed;

  /// No description provided for @snippetDeleteQuestion.
  ///
  /// In zh, this message translates to:
  /// **'删除本地片段？'**
  String get snippetDeleteQuestion;

  /// No description provided for @snippetDeleteHelp.
  ///
  /// In zh, this message translates to:
  /// **'将删除“{p0}”的本地模板，不影响服务器或已插入的草稿。'**
  String snippetDeleteHelp(String p0);

  /// No description provided for @snippetDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除片段'**
  String get snippetDelete;

  /// No description provided for @snippetChoose.
  ///
  /// In zh, this message translates to:
  /// **'选择片段插入草稿'**
  String get snippetChoose;

  /// No description provided for @snippetReadFailed.
  ///
  /// In zh, this message translates to:
  /// **'片段读取失败，未修改本地数据'**
  String get snippetReadFailed;

  /// No description provided for @snippetSelectPreviewHelp.
  ///
  /// In zh, this message translates to:
  /// **'选择后先预览，只插入草稿，不会自动发送。'**
  String get snippetSelectPreviewHelp;

  /// No description provided for @snippetPlaintextHelp.
  ///
  /// In zh, this message translates to:
  /// **'片段是本地普通文本，请勿保存密码、私钥或令牌。从终端“插入片段”可选入待发送草稿。'**
  String get snippetPlaintextHelp;

  /// No description provided for @snippetAdd.
  ///
  /// In zh, this message translates to:
  /// **'新增片段'**
  String get snippetAdd;

  /// No description provided for @snippetEmptyHelp.
  ///
  /// In zh, this message translates to:
  /// **'还没有片段。新增自己的常用命令模板。'**
  String get snippetEmptyHelp;

  /// No description provided for @snippetCharacterCount.
  ///
  /// In zh, this message translates to:
  /// **'{p0} 个字符 · 本地模板'**
  String snippetCharacterCount(String p0);

  /// No description provided for @snippetPreviewInsert.
  ///
  /// In zh, this message translates to:
  /// **'预览并插入草稿'**
  String get snippetPreviewInsert;

  /// No description provided for @snippetFullPreview.
  ///
  /// In zh, this message translates to:
  /// **'完整预览'**
  String get snippetFullPreview;

  /// No description provided for @connectionDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get connectionDelete;

  /// No description provided for @snippetDiscardQuestion.
  ///
  /// In zh, this message translates to:
  /// **'放弃片段修改？'**
  String get snippetDiscardQuestion;

  /// No description provided for @snippetDiscardHelp.
  ///
  /// In zh, this message translates to:
  /// **'未保存的内容不会写入本地片段。'**
  String get snippetDiscardHelp;

  /// No description provided for @connectionDiscardChanges.
  ///
  /// In zh, this message translates to:
  /// **'放弃修改'**
  String get connectionDiscardChanges;

  /// No description provided for @snippetEdit.
  ///
  /// In zh, this message translates to:
  /// **'编辑片段'**
  String get snippetEdit;

  /// No description provided for @snippetCancelEdit.
  ///
  /// In zh, this message translates to:
  /// **'取消片段编辑'**
  String get snippetCancelEdit;

  /// No description provided for @snippetSaveSafety.
  ///
  /// In zh, this message translates to:
  /// **'片段以明文保存，请勿填写密码、私钥或令牌。'**
  String get snippetSaveSafety;

  /// No description provided for @snippetName.
  ///
  /// In zh, this message translates to:
  /// **'片段名称'**
  String get snippetName;

  /// No description provided for @snippetFullContent.
  ///
  /// In zh, this message translates to:
  /// **'完整内容（保留原始换行与控制字符）'**
  String get snippetFullContent;

  /// No description provided for @snippetContentRange.
  ///
  /// In zh, this message translates to:
  /// **'内容不能为空，最多 16384 个字符'**
  String get snippetContentRange;

  /// No description provided for @snippetExactContentHelp.
  ///
  /// In zh, this message translates to:
  /// **'内容原样保存，含空白和控制字符；请用完整预览核对。'**
  String get snippetExactContentHelp;

  /// No description provided for @connectionSaving.
  ///
  /// In zh, this message translates to:
  /// **'保存中…'**
  String get connectionSaving;

  /// No description provided for @snippetSave.
  ///
  /// In zh, this message translates to:
  /// **'保存片段'**
  String get snippetSave;

  /// No description provided for @terminalCopyFailed.
  ///
  /// In zh, this message translates to:
  /// **'未能复制终端内容，请重试。'**
  String get terminalCopyFailed;

  /// No description provided for @terminalSelectionCopied.
  ///
  /// In zh, this message translates to:
  /// **'已复制所选终端内容'**
  String get terminalSelectionCopied;

  /// No description provided for @terminalDraftChangedPaste.
  ///
  /// In zh, this message translates to:
  /// **'草稿已变化，请再次点击粘贴。'**
  String get terminalDraftChangedPaste;

  /// No description provided for @terminalClipboardEmpty.
  ///
  /// In zh, this message translates to:
  /// **'剪贴板中没有可粘贴的文本。'**
  String get terminalClipboardEmpty;

  /// No description provided for @terminalPasteTooLong.
  ///
  /// In zh, this message translates to:
  /// **'粘贴后超过 16384 个字符，草稿未修改。'**
  String get terminalPasteTooLong;

  /// No description provided for @terminalClipboardReadFailed.
  ///
  /// In zh, this message translates to:
  /// **'剪贴板读取失败，草稿未修改。请重新点击粘贴。'**
  String get terminalClipboardReadFailed;

  /// No description provided for @terminalReplaceDraftQuestion.
  ///
  /// In zh, this message translates to:
  /// **'替换当前草稿？'**
  String get terminalReplaceDraftQuestion;

  /// No description provided for @terminalReplaceDraftHelp.
  ///
  /// In zh, this message translates to:
  /// **'当前未发送的草稿会被替换。不会向 SSH 发送任何内容。'**
  String get terminalReplaceDraftHelp;

  /// No description provided for @terminalReplaceDraft.
  ///
  /// In zh, this message translates to:
  /// **'替换草稿'**
  String get terminalReplaceDraft;

  /// No description provided for @terminalCurrentSession.
  ///
  /// In zh, this message translates to:
  /// **'当前 SSH 会话'**
  String get terminalCurrentSession;

  /// No description provided for @terminalDimensions.
  ///
  /// In zh, this message translates to:
  /// **'{p0} · {p1} 列 × {p2} 行'**
  String terminalDimensions(String p0, String p1, String p2);

  /// No description provided for @terminalSelectionHelp.
  ///
  /// In zh, this message translates to:
  /// **'点按终端输入；长按并拖动选择，使用“复制”复制。向上滚动查看历史，向下箭头回到最新输出。'**
  String get terminalSelectionHelp;

  /// No description provided for @terminalInputHelp.
  ///
  /// In zh, this message translates to:
  /// **'键盘和特殊键直接发送到 SSH。常用命令、片段和粘贴先进入独立草稿；“发送”不追加回车，“发送并执行”追加回车，由当前终端程序处理。正文原有换行仍可能执行。Ctrl 作用于下一个按键，再点可取消。'**
  String get terminalInputHelp;

  /// No description provided for @terminalBackgroundHelp.
  ///
  /// In zh, this message translates to:
  /// **'会话结束、离开或进入后台都会关闭此页，不会自动重连或重放输入。长任务建议在远端使用 tmux / screen。'**
  String get terminalBackgroundHelp;

  /// No description provided for @r2ConnDisconnectHelp.
  ///
  /// In zh, this message translates to:
  /// **'{p0}\n未放入 tmux / screen 的远端任务可能中断；未发送的草稿将丢弃。'**
  String r2ConnDisconnectHelp(String p0);

  /// No description provided for @terminalOfflineFont.
  ///
  /// In zh, this message translates to:
  /// **'离线字体：DejaVu Sans Mono · 中文使用设备字体回退'**
  String get terminalOfflineFont;

  /// No description provided for @terminalLicenses.
  ///
  /// In zh, this message translates to:
  /// **'开源许可'**
  String get terminalLicenses;

  /// No description provided for @terminalDisconnectQuestion.
  ///
  /// In zh, this message translates to:
  /// **'断开 SSH 会话？'**
  String get terminalDisconnectQuestion;

  /// No description provided for @terminalDiscardExitQuestion.
  ///
  /// In zh, this message translates to:
  /// **'丢弃草稿并退出？'**
  String get terminalDiscardExitQuestion;

  /// No description provided for @terminalDisconnectHelp.
  ///
  /// In zh, this message translates to:
  /// **'{p0}\n未放入 tmux / screen 的远端任务可能中断。{p1}'**
  String terminalDisconnectHelp(String p0, String p1);

  /// No description provided for @terminalDraftKeptUntilReconnect.
  ///
  /// In zh, this message translates to:
  /// **'草稿暂时保留，重连时清空。'**
  String get terminalDraftKeptUntilReconnect;

  /// No description provided for @terminalDraftWillClear.
  ///
  /// In zh, this message translates to:
  /// **'未发送草稿将清空。'**
  String get terminalDraftWillClear;

  /// No description provided for @terminalUnsentDraftExit.
  ///
  /// In zh, this message translates to:
  /// **'当前草稿尚未发送，退出后将清空。'**
  String get terminalUnsentDraftExit;

  /// No description provided for @terminalDisconnect.
  ///
  /// In zh, this message translates to:
  /// **'断开连接'**
  String get terminalDisconnect;

  /// No description provided for @terminalDisconnectExit.
  ///
  /// In zh, this message translates to:
  /// **'断开并退出'**
  String get terminalDisconnectExit;

  /// No description provided for @terminalDiscardExit.
  ///
  /// In zh, this message translates to:
  /// **'丢弃并退出'**
  String get terminalDiscardExit;

  /// No description provided for @terminalBackgroundDisconnected.
  ///
  /// In zh, this message translates to:
  /// **'应用进入后台，连接已断开'**
  String get terminalBackgroundDisconnected;

  /// No description provided for @terminalTargetChanged.
  ///
  /// In zh, this message translates to:
  /// **'目标已变化，连接已断开'**
  String get terminalTargetChanged;

  /// No description provided for @terminalPowerMenuHelp.
  ///
  /// In zh, this message translates to:
  /// **'连接后在“终端菜单”选择 SSH 重启或关机，并完成两次确认。'**
  String get terminalPowerMenuHelp;

  /// No description provided for @terminalHostChanged.
  ///
  /// In zh, this message translates to:
  /// **'主机密钥变化 · 已阻断认证'**
  String get terminalHostChanged;

  /// No description provided for @terminalHostChangedHelp.
  ///
  /// In zh, this message translates to:
  /// **'这可能是重装或中间人攻击。尚未发送登录凭据。请通过厂商控制台等独立渠道核实原因与新公钥。'**
  String get terminalHostChangedHelp;

  /// No description provided for @terminalPreviousFingerprint.
  ///
  /// In zh, this message translates to:
  /// **'此前指纹'**
  String get terminalPreviousFingerprint;

  /// No description provided for @terminalNoRecord.
  ///
  /// In zh, this message translates to:
  /// **'无记录'**
  String get terminalNoRecord;

  /// No description provided for @terminalCurrentFingerprint.
  ///
  /// In zh, this message translates to:
  /// **'本次指纹'**
  String get terminalCurrentFingerprint;

  /// No description provided for @terminalRejectConnection.
  ///
  /// In zh, this message translates to:
  /// **'拒绝连接'**
  String get terminalRejectConnection;

  /// No description provided for @terminalReverify.
  ///
  /// In zh, this message translates to:
  /// **'开始独立重新核实'**
  String get terminalReverify;

  /// No description provided for @terminalPowerFailed.
  ///
  /// In zh, this message translates to:
  /// **'电源指令未能确认成功。请核实连接、远端权限及厂商控制台状态，避免重复执行；不会自动重发。'**
  String get terminalPowerFailed;

  /// No description provided for @terminalPowerUnknown.
  ///
  /// In zh, this message translates to:
  /// **'电源指令已尝试提交，结果未知。连接断开不证明操作完成；请到厂商控制台核实，不会自动重发。'**
  String get terminalPowerUnknown;

  /// No description provided for @terminalNotConnected.
  ///
  /// In zh, this message translates to:
  /// **'未连接'**
  String get terminalNotConnected;

  /// No description provided for @terminalConnecting.
  ///
  /// In zh, this message translates to:
  /// **'连接中'**
  String get terminalConnecting;

  /// No description provided for @terminalVerifying.
  ///
  /// In zh, this message translates to:
  /// **'核验主机身份中'**
  String get terminalVerifying;

  /// No description provided for @terminalAuthenticating.
  ///
  /// In zh, this message translates to:
  /// **'认证中'**
  String get terminalAuthenticating;

  /// No description provided for @terminalConnected.
  ///
  /// In zh, this message translates to:
  /// **'已连接 · SSH PTY'**
  String get terminalConnected;

  /// No description provided for @terminalDisconnected.
  ///
  /// In zh, this message translates to:
  /// **'已断开'**
  String get terminalDisconnected;

  /// No description provided for @terminalFailed.
  ///
  /// In zh, this message translates to:
  /// **'连接失败'**
  String get terminalFailed;

  /// No description provided for @terminalExit.
  ///
  /// In zh, this message translates to:
  /// **'退出终端'**
  String get terminalExit;

  /// No description provided for @terminalSessionSemantics.
  ///
  /// In zh, this message translates to:
  /// **'会话详情，{p0}，{p1}'**
  String terminalSessionSemantics(String p0, String p1);

  /// No description provided for @terminalHideKeyboard.
  ///
  /// In zh, this message translates to:
  /// **'收起键盘'**
  String get terminalHideKeyboard;

  /// No description provided for @terminalOpenKeyboard.
  ///
  /// In zh, this message translates to:
  /// **'打开键盘'**
  String get terminalOpenKeyboard;

  /// No description provided for @terminalMenu.
  ///
  /// In zh, this message translates to:
  /// **'终端菜单'**
  String get terminalMenu;

  /// No description provided for @terminalSessionDetails.
  ///
  /// In zh, this message translates to:
  /// **'会话详情与使用说明'**
  String get terminalSessionDetails;

  /// No description provided for @terminalPasteIntoDraft.
  ///
  /// In zh, this message translates to:
  /// **'粘贴到草稿'**
  String get terminalPasteIntoDraft;

  /// No description provided for @r3TermColorScheme.
  ///
  /// In zh, this message translates to:
  /// **'配色与高亮'**
  String get r3TermColorScheme;

  /// No description provided for @r3TermSchemeDark.
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get r3TermSchemeDark;

  /// No description provided for @r3TermSchemeLight.
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get r3TermSchemeLight;

  /// No description provided for @r3TermSchemeFootnote.
  ///
  /// In zh, this message translates to:
  /// **'仅改变显示，不向服务器发送任何内容。重启应用后恢复默认。'**
  String get r3TermSchemeFootnote;

  /// No description provided for @r4HlSmart.
  ///
  /// In zh, this message translates to:
  /// **'智能高亮'**
  String get r4HlSmart;

  /// No description provided for @r4HlSmartNote.
  ///
  /// In zh, this message translates to:
  /// **'给默认颜色的输出着色（路径、IP、数字、错误等）。仅本地显示，不改变收发内容。'**
  String get r4HlSmartNote;

  /// No description provided for @r4HlLanguage.
  ///
  /// In zh, this message translates to:
  /// **'语法高亮'**
  String get r4HlLanguage;

  /// No description provided for @r4HlAuto.
  ///
  /// In zh, this message translates to:
  /// **'自动识别'**
  String get r4HlAuto;

  /// No description provided for @r4HlPlain.
  ///
  /// In zh, this message translates to:
  /// **'关闭（纯文本）'**
  String get r4HlPlain;

  /// No description provided for @r4HlGeneric.
  ///
  /// In zh, this message translates to:
  /// **'通用'**
  String get r4HlGeneric;

  /// No description provided for @r4HlTooLarge.
  ///
  /// In zh, this message translates to:
  /// **'文件超过 256 KiB，未做语法高亮'**
  String get r4HlTooLarge;

  /// No description provided for @terminalReconnectClear.
  ///
  /// In zh, this message translates to:
  /// **'重新连接并清空草稿'**
  String get terminalReconnectClear;

  /// No description provided for @terminalCancelConnection.
  ///
  /// In zh, this message translates to:
  /// **'取消连接'**
  String get terminalCancelConnection;

  /// No description provided for @terminalSshRestart.
  ///
  /// In zh, this message translates to:
  /// **'SSH 重启'**
  String get terminalSshRestart;

  /// No description provided for @terminalSshShutdown.
  ///
  /// In zh, this message translates to:
  /// **'SSH 关机'**
  String get terminalSshShutdown;

  /// No description provided for @terminalTypeDirectly.
  ///
  /// In zh, this message translates to:
  /// **'点按终端输入，按键直接发送'**
  String get terminalTypeDirectly;

  /// No description provided for @terminalCopy.
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get terminalCopy;

  /// No description provided for @terminalClearSelection.
  ///
  /// In zh, this message translates to:
  /// **'取消选择'**
  String get terminalClearSelection;

  /// No description provided for @terminalLatestOutput.
  ///
  /// In zh, this message translates to:
  /// **'回到最新输出'**
  String get terminalLatestOutput;

  /// No description provided for @terminalEstablishingSecure.
  ///
  /// In zh, this message translates to:
  /// **'正在建立安全连接…'**
  String get terminalEstablishingSecure;

  /// No description provided for @terminalOffline.
  ///
  /// In zh, this message translates to:
  /// **'终端未连接'**
  String get terminalOffline;

  /// No description provided for @terminalConnect.
  ///
  /// In zh, this message translates to:
  /// **'连接'**
  String get terminalConnect;

  /// No description provided for @terminalReconnectShort.
  ///
  /// In zh, this message translates to:
  /// **'重连 · 清空草稿'**
  String get terminalReconnectShort;

  /// No description provided for @terminalBrowserUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'浏览器不支持原生 SSH，请使用原生应用。'**
  String get terminalBrowserUnsupported;

  /// No description provided for @terminalConnectedInputHelp.
  ///
  /// In zh, this message translates to:
  /// **'连接后点按终端输入，按键会直接发送到服务器。'**
  String get terminalConnectedInputHelp;

  /// No description provided for @terminalRetainedOutputHelp.
  ///
  /// In zh, this message translates to:
  /// **'输出已保留。重连会清空终端和草稿，不重放输入。'**
  String get terminalRetainedOutputHelp;

  /// No description provided for @terminalDismissNotice.
  ///
  /// In zh, this message translates to:
  /// **'关闭提示'**
  String get terminalDismissNotice;

  /// No description provided for @terminalVerifyNewHost.
  ///
  /// In zh, this message translates to:
  /// **'重新核实新的主机公钥'**
  String get terminalVerifyNewHost;

  /// No description provided for @terminalFirstHostVerification.
  ///
  /// In zh, this message translates to:
  /// **'首次连接 · 核对主机身份'**
  String get terminalFirstHostVerification;

  /// No description provided for @terminalHostIdentity.
  ///
  /// In zh, this message translates to:
  /// **'主机：{p0}\n端口：{p1}\n算法：{p2}'**
  String terminalHostIdentity(String p0, String p1, String p2);

  /// No description provided for @terminalSha256Fingerprint.
  ///
  /// In zh, this message translates to:
  /// **'SHA-256 指纹'**
  String get terminalSha256Fingerprint;

  /// No description provided for @terminalFullHostKey.
  ///
  /// In zh, this message translates to:
  /// **'完整主机公钥'**
  String get terminalFullHostKey;

  /// No description provided for @terminalIndependentVerificationHelp.
  ///
  /// In zh, this message translates to:
  /// **'请从厂商控制台或其他独立可信渠道核对。仅看见这个弹窗不代表身份可信。'**
  String get terminalIndependentVerificationHelp;

  /// No description provided for @terminalConfirmedChangedHost.
  ///
  /// In zh, this message translates to:
  /// **'我已独立重新核实变化原因与完整新公钥'**
  String get terminalConfirmedChangedHost;

  /// No description provided for @terminalConfirmedHost.
  ///
  /// In zh, this message translates to:
  /// **'我已通过独立渠道核实本次完整主机身份'**
  String get terminalConfirmedHost;

  /// No description provided for @terminalVerificationExpired.
  ///
  /// In zh, this message translates to:
  /// **'连接已取消或超时，此核验已失效。'**
  String get terminalVerificationExpired;

  /// No description provided for @terminalUpdateTrustAuthenticate.
  ///
  /// In zh, this message translates to:
  /// **'更新信任并继续认证'**
  String get terminalUpdateTrustAuthenticate;

  /// No description provided for @terminalTrustAuthenticate.
  ///
  /// In zh, this message translates to:
  /// **'确认信任并认证'**
  String get terminalTrustAuthenticate;

  /// No description provided for @terminalUnlockKey.
  ///
  /// In zh, this message translates to:
  /// **'解锁本次 SSH 私钥'**
  String get terminalUnlockKey;

  /// No description provided for @terminalCredentialName.
  ///
  /// In zh, this message translates to:
  /// **'凭据：{p0}'**
  String terminalCredentialName(String p0);

  /// No description provided for @terminalPassphraseHelp.
  ///
  /// In zh, this message translates to:
  /// **'私钥解密口令，不是登录密码；仅用于本次连接，不保存。'**
  String get terminalPassphraseHelp;

  /// No description provided for @terminalKeyPassphrase.
  ///
  /// In zh, this message translates to:
  /// **'本次私钥口令'**
  String get terminalKeyPassphrase;

  /// No description provided for @terminalPassphraseCleared.
  ///
  /// In zh, this message translates to:
  /// **'口令已清空，请取消后重新连接。'**
  String get terminalPassphraseCleared;

  /// No description provided for @terminalUnlockOnce.
  ///
  /// In zh, this message translates to:
  /// **'仅解锁本次连接'**
  String get terminalUnlockOnce;

  /// No description provided for @powerRestart.
  ///
  /// In zh, this message translates to:
  /// **'重启'**
  String get powerRestart;

  /// No description provided for @powerShutdown.
  ///
  /// In zh, this message translates to:
  /// **'关机'**
  String get powerShutdown;

  /// No description provided for @powerImpactTitle.
  ///
  /// In zh, this message translates to:
  /// **'{p0}影响确认（1/2）'**
  String powerImpactTitle(String p0);

  /// No description provided for @powerImpactHelp.
  ///
  /// In zh, this message translates to:
  /// **'{p0}\n{p1}\n\n通过当前单台 SSH 连接执行：\n{p2}\n\n可能立即中断业务及 SSH 会话，需要远端相应权限。关机不会取消厂商计费，SSH 无法再次开机。连接中断或超时后结果未知，请到厂商控制台核实，勿盲目重试。'**
  String powerImpactHelp(String p0, String p1, String p2);

  /// No description provided for @powerUnderstandContinue.
  ///
  /// In zh, this message translates to:
  /// **'了解影响，继续核对'**
  String get powerUnderstandContinue;

  /// No description provided for @powerFinalTitle.
  ///
  /// In zh, this message translates to:
  /// **'最终确认{p0}（2/2）'**
  String powerFinalTitle(String p0);

  /// No description provided for @powerEnterTarget.
  ///
  /// In zh, this message translates to:
  /// **'请完整输入本次目标，确认只下发一次：'**
  String get powerEnterTarget;

  /// No description provided for @powerTargetFormat.
  ///
  /// In zh, this message translates to:
  /// **'用户名@主机:端口'**
  String get powerTargetFormat;

  /// No description provided for @powerConfirmationInvalidated.
  ///
  /// In zh, this message translates to:
  /// **'连接已变化。本次确认已作废，未下发指令。'**
  String get powerConfirmationInvalidated;

  /// No description provided for @powerExecuteOnce.
  ///
  /// In zh, this message translates to:
  /// **'仅执行一次{p0}'**
  String powerExecuteOnce(String p0);

  /// No description provided for @snippetInvalidId.
  ///
  /// In zh, this message translates to:
  /// **'片段标识无效'**
  String get snippetInvalidId;

  /// No description provided for @sshCheckTarget.
  ///
  /// In zh, this message translates to:
  /// **'请检查 SSH 端口、用户名与凭据'**
  String get sshCheckTarget;

  /// No description provided for @sshConnectionCancelled.
  ///
  /// In zh, this message translates to:
  /// **'SSH 连接已取消'**
  String get sshConnectionCancelled;

  /// No description provided for @sshBrowserUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'浏览器不支持原生 SSH，请使用原生应用'**
  String get sshBrowserUnsupported;

  /// No description provided for @sshCredentialReadTimeout.
  ///
  /// In zh, this message translates to:
  /// **'读取 SSH 凭据超时'**
  String get sshCredentialReadTimeout;

  /// No description provided for @sshKeyNeedsPassphrase.
  ///
  /// In zh, this message translates to:
  /// **'此私钥需要解密口令，请重新连接并输入'**
  String get sshKeyNeedsPassphrase;

  /// No description provided for @sshPassphraseInputTimeout.
  ///
  /// In zh, this message translates to:
  /// **'输入私钥口令超时，未进行连接'**
  String get sshPassphraseInputTimeout;

  /// No description provided for @sshPassphraseCancelled.
  ///
  /// In zh, this message translates to:
  /// **'已取消私钥口令输入，未进行连接'**
  String get sshPassphraseCancelled;

  /// No description provided for @sshPassphraseTooLong.
  ///
  /// In zh, this message translates to:
  /// **'私钥口令超出长度限制'**
  String get sshPassphraseTooLong;

  /// No description provided for @sshKeyDecryptionTimeout.
  ///
  /// In zh, this message translates to:
  /// **'私钥解密超时，未进行连接'**
  String get sshKeyDecryptionTimeout;

  /// No description provided for @sshTcpTimeout.
  ///
  /// In zh, this message translates to:
  /// **'SSH TCP 连接超时'**
  String get sshTcpTimeout;

  /// No description provided for @sshHandshakeTimeout.
  ///
  /// In zh, this message translates to:
  /// **'SSH 握手超时'**
  String get sshHandshakeTimeout;

  /// No description provided for @sshIdentityChanged.
  ///
  /// In zh, this message translates to:
  /// **'主机核验或凭据已变化，认证已阻止'**
  String get sshIdentityChanged;

  /// No description provided for @sshVerificationCancelled.
  ///
  /// In zh, this message translates to:
  /// **'SSH 核验已取消'**
  String get sshVerificationCancelled;

  /// No description provided for @sshVerificationTimeout.
  ///
  /// In zh, this message translates to:
  /// **'主机核验超时，未进行认证'**
  String get sshVerificationTimeout;

  /// No description provided for @sshCredentialChanged.
  ///
  /// In zh, this message translates to:
  /// **'凭据已变化，请重新连接'**
  String get sshCredentialChanged;

  /// No description provided for @sshAuthenticationTimeout.
  ///
  /// In zh, this message translates to:
  /// **'SSH 认证超时'**
  String get sshAuthenticationTimeout;

  /// No description provided for @sshTerminalOpenTimeout.
  ///
  /// In zh, this message translates to:
  /// **'SSH 终端开启超时'**
  String get sshTerminalOpenTimeout;

  /// No description provided for @r3SftpOpenTimeout.
  ///
  /// In zh, this message translates to:
  /// **'SFTP 开启超时'**
  String get r3SftpOpenTimeout;

  /// No description provided for @r3SftpUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'服务器未开启 SFTP，可能已对该账户禁用'**
  String get r3SftpUnavailable;

  /// No description provided for @r3SftpTitle.
  ///
  /// In zh, this message translates to:
  /// **'SFTP 文件'**
  String get r3SftpTitle;

  /// No description provided for @r3SftpRowSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'浏览与传输文件'**
  String get r3SftpRowSubtitle;

  /// No description provided for @r3SftpUp.
  ///
  /// In zh, this message translates to:
  /// **'上级目录'**
  String get r3SftpUp;

  /// No description provided for @r3SftpRoot.
  ///
  /// In zh, this message translates to:
  /// **'根目录'**
  String get r3SftpRoot;

  /// No description provided for @r3SftpNewFolder.
  ///
  /// In zh, this message translates to:
  /// **'新建文件夹'**
  String get r3SftpNewFolder;

  /// No description provided for @r3SftpNewFile.
  ///
  /// In zh, this message translates to:
  /// **'新建空文件'**
  String get r3SftpNewFile;

  /// No description provided for @r3SftpUpload.
  ///
  /// In zh, this message translates to:
  /// **'从手机上传'**
  String get r3SftpUpload;

  /// No description provided for @r3SftpSort.
  ///
  /// In zh, this message translates to:
  /// **'排序方式'**
  String get r3SftpSort;

  /// No description provided for @r3SftpSortName.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get r3SftpSortName;

  /// No description provided for @r3SftpSortSize.
  ///
  /// In zh, this message translates to:
  /// **'大小'**
  String get r3SftpSortSize;

  /// No description provided for @r3SftpSortTime.
  ///
  /// In zh, this message translates to:
  /// **'修改时间'**
  String get r3SftpSortTime;

  /// No description provided for @r3SftpShowHidden.
  ///
  /// In zh, this message translates to:
  /// **'显示隐藏文件'**
  String get r3SftpShowHidden;

  /// No description provided for @r3SftpSearch.
  ///
  /// In zh, this message translates to:
  /// **'搜索当前文件夹'**
  String get r3SftpSearch;

  /// No description provided for @r3SftpEmpty.
  ///
  /// In zh, this message translates to:
  /// **'此文件夹为空'**
  String get r3SftpEmpty;

  /// No description provided for @r3SftpNoMatch.
  ///
  /// In zh, this message translates to:
  /// **'没有匹配项'**
  String get r3SftpNoMatch;

  /// No description provided for @r3SftpShowMore.
  ///
  /// In zh, this message translates to:
  /// **'显示更多（{count}）'**
  String r3SftpShowMore(int count);

  /// No description provided for @r3SftpMore.
  ///
  /// In zh, this message translates to:
  /// **'更多'**
  String get r3SftpMore;

  /// No description provided for @r3SftpAdd.
  ///
  /// In zh, this message translates to:
  /// **'新建'**
  String get r3SftpAdd;

  /// No description provided for @r3SftpOpen.
  ///
  /// In zh, this message translates to:
  /// **'打开'**
  String get r3SftpOpen;

  /// No description provided for @r3SftpView.
  ///
  /// In zh, this message translates to:
  /// **'查看 / 编辑'**
  String get r3SftpView;

  /// No description provided for @r3SftpDownload.
  ///
  /// In zh, this message translates to:
  /// **'下载'**
  String get r3SftpDownload;

  /// No description provided for @r3SftpRename.
  ///
  /// In zh, this message translates to:
  /// **'重命名 / 移动'**
  String get r3SftpRename;

  /// No description provided for @r3SftpCopyPath.
  ///
  /// In zh, this message translates to:
  /// **'复制路径'**
  String get r3SftpCopyPath;

  /// No description provided for @r3SftpDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get r3SftpDelete;

  /// No description provided for @r3SftpPathCopied.
  ///
  /// In zh, this message translates to:
  /// **'已复制路径'**
  String get r3SftpPathCopied;

  /// No description provided for @r3SftpNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get r3SftpNameLabel;

  /// No description provided for @r3SftpFolderLabel.
  ///
  /// In zh, this message translates to:
  /// **'所在文件夹'**
  String get r3SftpFolderLabel;

  /// No description provided for @r3SftpCreate.
  ///
  /// In zh, this message translates to:
  /// **'创建'**
  String get r3SftpCreate;

  /// No description provided for @r3SftpRenameTitle.
  ///
  /// In zh, this message translates to:
  /// **'重命名或移动'**
  String get r3SftpRenameTitle;

  /// No description provided for @r3SftpRenameHint.
  ///
  /// In zh, this message translates to:
  /// **'改名称即重命名，改文件夹即移动。'**
  String get r3SftpRenameHint;

  /// No description provided for @r3SftpInvalidName.
  ///
  /// In zh, this message translates to:
  /// **'名称不能为空或包含“/”'**
  String get r3SftpInvalidName;

  /// No description provided for @r3SftpInvalidFolder.
  ///
  /// In zh, this message translates to:
  /// **'文件夹须为以 / 开头的绝对路径'**
  String get r3SftpInvalidFolder;

  /// No description provided for @r3SftpDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除“{name}”？'**
  String r3SftpDeleteTitle(String name);

  /// No description provided for @r3SftpDeleteFileMessage.
  ///
  /// In zh, this message translates to:
  /// **'将在服务器上永久删除该文件。'**
  String get r3SftpDeleteFileMessage;

  /// No description provided for @r3SftpDeleteFolderMessage.
  ///
  /// In zh, this message translates to:
  /// **'将在服务器上永久删除这个空文件夹。'**
  String get r3SftpDeleteFolderMessage;

  /// No description provided for @r3SftpDeleteRecursiveTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除文件夹及其全部内容？'**
  String get r3SftpDeleteRecursiveTitle;

  /// No description provided for @r3SftpDeleteRecursiveMessage.
  ///
  /// In zh, this message translates to:
  /// **'“{name}”不为空，其中所有内容将被永久递归删除（不跟随链接）。超过 {max} 项的文件夹会被拒绝，且不会删除任何内容。'**
  String r3SftpDeleteRecursiveMessage(String name, int max);

  /// No description provided for @r3SftpDeleteRecursiveAction.
  ///
  /// In zh, this message translates to:
  /// **'全部删除'**
  String get r3SftpDeleteRecursiveAction;

  /// No description provided for @r3SftpDeleted.
  ///
  /// In zh, this message translates to:
  /// **'已删除'**
  String get r3SftpDeleted;

  /// No description provided for @r3SftpDeletedCount.
  ///
  /// In zh, this message translates to:
  /// **'已删除 {count} 项'**
  String r3SftpDeletedCount(int count);

  /// No description provided for @r3SftpCreated.
  ///
  /// In zh, this message translates to:
  /// **'已创建'**
  String get r3SftpCreated;

  /// No description provided for @r3SftpRenamed.
  ///
  /// In zh, this message translates to:
  /// **'已重命名'**
  String get r3SftpRenamed;

  /// No description provided for @r3SftpErrPermission.
  ///
  /// In zh, this message translates to:
  /// **'没有权限'**
  String get r3SftpErrPermission;

  /// No description provided for @r3SftpErrNotFound.
  ///
  /// In zh, this message translates to:
  /// **'未找到，可能已被移动或删除'**
  String get r3SftpErrNotFound;

  /// No description provided for @r3SftpErrExists.
  ///
  /// In zh, this message translates to:
  /// **'已存在同名项目'**
  String get r3SftpErrExists;

  /// No description provided for @r3SftpErrNotEmpty.
  ///
  /// In zh, this message translates to:
  /// **'文件夹不为空'**
  String get r3SftpErrNotEmpty;

  /// No description provided for @r3SftpErrWrongType.
  ///
  /// In zh, this message translates to:
  /// **'该项目类型不适用于此操作'**
  String get r3SftpErrWrongType;

  /// No description provided for @r3SftpErrCancelled.
  ///
  /// In zh, this message translates to:
  /// **'已取消'**
  String get r3SftpErrCancelled;

  /// No description provided for @r3SftpErrTooLarge.
  ///
  /// In zh, this message translates to:
  /// **'文件过大，无法作为文本打开（上限 512 KiB）'**
  String get r3SftpErrTooLarge;

  /// No description provided for @r3SftpErrNotText.
  ///
  /// In zh, this message translates to:
  /// **'不是 UTF-8 文本文件'**
  String get r3SftpErrNotText;

  /// No description provided for @r3SftpErrTooMany.
  ///
  /// In zh, this message translates to:
  /// **'项目过多（上限 {max}），未删除任何内容'**
  String r3SftpErrTooMany(int max);

  /// No description provided for @r3SftpErrInvalidPath.
  ///
  /// In zh, this message translates to:
  /// **'路径无效'**
  String get r3SftpErrInvalidPath;

  /// No description provided for @r3SftpErrTimeout.
  ///
  /// In zh, this message translates to:
  /// **'服务器响应超时'**
  String get r3SftpErrTimeout;

  /// No description provided for @r3SftpErrConnectionLost.
  ///
  /// In zh, this message translates to:
  /// **'SFTP 连接已断开'**
  String get r3SftpErrConnectionLost;

  /// No description provided for @r3SftpErrUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'此连接无法使用 SFTP'**
  String get r3SftpErrUnavailable;

  /// No description provided for @r3SftpErrLocalFile.
  ///
  /// In zh, this message translates to:
  /// **'无法读写本地文件'**
  String get r3SftpErrLocalFile;

  /// No description provided for @r3SftpErrFailed.
  ///
  /// In zh, this message translates to:
  /// **'操作失败'**
  String get r3SftpErrFailed;

  /// No description provided for @r3SftpEditorSize.
  ///
  /// In zh, this message translates to:
  /// **'{size} · UTF-8'**
  String r3SftpEditorSize(String size);

  /// No description provided for @r3SftpSaved.
  ///
  /// In zh, this message translates to:
  /// **'已保存'**
  String get r3SftpSaved;

  /// No description provided for @r3SftpUnsavedTitle.
  ///
  /// In zh, this message translates to:
  /// **'放弃未保存的修改？'**
  String get r3SftpUnsavedTitle;

  /// No description provided for @r3SftpUnsavedMessage.
  ///
  /// In zh, this message translates to:
  /// **'修改尚未写入服务器。'**
  String get r3SftpUnsavedMessage;

  /// No description provided for @r3SftpDiscard.
  ///
  /// In zh, this message translates to:
  /// **'放弃'**
  String get r3SftpDiscard;

  /// No description provided for @r3SftpConflictTitle.
  ///
  /// In zh, this message translates to:
  /// **'服务器上的文件已变化'**
  String get r3SftpConflictTitle;

  /// No description provided for @r3SftpConflictMessage.
  ///
  /// In zh, this message translates to:
  /// **'它在你打开后被修改过。要用你的版本覆盖服务器上的版本吗？'**
  String get r3SftpConflictMessage;

  /// No description provided for @r3SftpOverwrite.
  ///
  /// In zh, this message translates to:
  /// **'覆盖'**
  String get r3SftpOverwrite;

  /// No description provided for @r3SftpSkip.
  ///
  /// In zh, this message translates to:
  /// **'跳过'**
  String get r3SftpSkip;

  /// No description provided for @r3SftpExistsTitle.
  ///
  /// In zh, this message translates to:
  /// **'“{name}”已存在'**
  String r3SftpExistsTitle(String name);

  /// No description provided for @r3SftpExistsMessage.
  ///
  /// In zh, this message translates to:
  /// **'覆盖服务器上的文件，还是跳过这次上传？'**
  String get r3SftpExistsMessage;

  /// No description provided for @r3SftpLargeTitle.
  ///
  /// In zh, this message translates to:
  /// **'大文件'**
  String get r3SftpLargeTitle;

  /// No description provided for @r3SftpLargeMessage.
  ///
  /// In zh, this message translates to:
  /// **'“{name}”大小为 {size}，可能耗时较长并消耗大量流量。继续吗？'**
  String r3SftpLargeMessage(String name, String size);

  /// No description provided for @r3SftpContinue.
  ///
  /// In zh, this message translates to:
  /// **'继续'**
  String get r3SftpContinue;

  /// No description provided for @r3SftpTransfers.
  ///
  /// In zh, this message translates to:
  /// **'传输'**
  String get r3SftpTransfers;

  /// No description provided for @r3SftpTransferUp.
  ///
  /// In zh, this message translates to:
  /// **'正在上传 {name}'**
  String r3SftpTransferUp(String name);

  /// No description provided for @r3SftpTransferDown.
  ///
  /// In zh, this message translates to:
  /// **'正在下载 {name}'**
  String r3SftpTransferDown(String name);

  /// No description provided for @r3SftpTransferCount.
  ///
  /// In zh, this message translates to:
  /// **'第 {index} / {total} 项'**
  String r3SftpTransferCount(int index, int total);

  /// No description provided for @r3SftpStateQueued.
  ///
  /// In zh, this message translates to:
  /// **'等待中'**
  String get r3SftpStateQueued;

  /// No description provided for @r3SftpStateDone.
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get r3SftpStateDone;

  /// No description provided for @r3SftpStateFailed.
  ///
  /// In zh, this message translates to:
  /// **'失败'**
  String get r3SftpStateFailed;

  /// No description provided for @r3SftpStateCancelled.
  ///
  /// In zh, this message translates to:
  /// **'已取消'**
  String get r3SftpStateCancelled;

  /// No description provided for @r3SftpStateSkipped.
  ///
  /// In zh, this message translates to:
  /// **'已跳过'**
  String get r3SftpStateSkipped;

  /// No description provided for @r3SftpCancelAll.
  ///
  /// In zh, this message translates to:
  /// **'全部取消'**
  String get r3SftpCancelAll;

  /// No description provided for @r3SftpClearFinished.
  ///
  /// In zh, this message translates to:
  /// **'清除已完成'**
  String get r3SftpClearFinished;

  /// No description provided for @r3SftpShare.
  ///
  /// In zh, this message translates to:
  /// **'分享'**
  String get r3SftpShare;

  /// No description provided for @r3SftpSavedTo.
  ///
  /// In zh, this message translates to:
  /// **'已保存到 {path}'**
  String r3SftpSavedTo(String path);

  /// No description provided for @r3SftpDownloadsWhere.
  ///
  /// In zh, this message translates to:
  /// **'下载的文件保存在应用文件夹“SFTP Downloads”中。可用“分享”另存到其他位置，例如“文件”。'**
  String get r3SftpDownloadsWhere;

  /// No description provided for @r3SftpCloseBusyTitle.
  ///
  /// In zh, this message translates to:
  /// **'传输进行中'**
  String get r3SftpCloseBusyTitle;

  /// No description provided for @r3SftpCloseBusyMessage.
  ///
  /// In zh, this message translates to:
  /// **'关闭将取消进行中和等待中的传输。'**
  String get r3SftpCloseBusyMessage;

  /// No description provided for @r3SftpCloseBusyAction.
  ///
  /// In zh, this message translates to:
  /// **'取消传输并关闭'**
  String get r3SftpCloseBusyAction;

  /// No description provided for @r3SftpBackgroundClosed.
  ///
  /// In zh, this message translates to:
  /// **'应用进入后台，SFTP 已关闭'**
  String get r3SftpBackgroundClosed;

  /// No description provided for @r3SftpConnecting.
  ///
  /// In zh, this message translates to:
  /// **'正在连接 SFTP…'**
  String get r3SftpConnecting;

  /// No description provided for @r3SftpConnectFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法打开 SFTP'**
  String get r3SftpConnectFailed;

  /// No description provided for @r3SftpRetry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get r3SftpRetry;

  /// No description provided for @r3SftpChooseCredential.
  ///
  /// In zh, this message translates to:
  /// **'请先在 SSH 设置中选择凭据。'**
  String get r3SftpChooseCredential;

  /// No description provided for @r3SftpSshSettings.
  ///
  /// In zh, this message translates to:
  /// **'SSH 设置'**
  String get r3SftpSshSettings;

  /// No description provided for @r3SftpLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法加载此文件夹'**
  String get r3SftpLoadFailed;

  /// No description provided for @r3SftpClose.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get r3SftpClose;

  /// No description provided for @r3SftpUploadsQueued.
  ///
  /// In zh, this message translates to:
  /// **'已加入上传队列：{count} 个'**
  String r3SftpUploadsQueued(int count);

  /// No description provided for @sshAuthenticationFailed.
  ///
  /// In zh, this message translates to:
  /// **'SSH 认证失败，请检查用户名和凭据'**
  String get sshAuthenticationFailed;

  /// No description provided for @sshHostNotTrusted.
  ///
  /// In zh, this message translates to:
  /// **'主机未获信任，未进行认证'**
  String get sshHostNotTrusted;

  /// No description provided for @sshConnectionIncomplete.
  ///
  /// In zh, this message translates to:
  /// **'SSH 连接未完成，请检查地址、网络与服务'**
  String get sshConnectionIncomplete;

  /// No description provided for @sshSessionEnded.
  ///
  /// In zh, this message translates to:
  /// **'SSH 会话已结束；命令是否完成请在重连后核实'**
  String get sshSessionEnded;

  /// No description provided for @sshInputUnconfirmed.
  ///
  /// In zh, this message translates to:
  /// **'SSH 输入发送未确认；请重连后核实，避免重复执行'**
  String get sshInputUnconfirmed;

  /// No description provided for @sshResizeFailed.
  ///
  /// In zh, this message translates to:
  /// **'SSH 终端大小调整失败，请重连'**
  String get sshResizeFailed;

  /// No description provided for @sshPrivatePublicMismatch.
  ///
  /// In zh, this message translates to:
  /// **'私钥与已保存的公钥信息不一致，请重新导入私钥后再连接'**
  String get sshPrivatePublicMismatch;

  /// Security: ReadFailed. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'无法读取安全资料，请重试'**
  String get securityReadFailed;

  /// Security: SavedReloadFailed. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'已保存，但资料重读失败；请重读后再修改'**
  String get securitySavedReloadFailed;

  /// Security: DataChanged. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'资料已变化，请重读后重试'**
  String get securityDataChanged;

  /// Security: MutationFailed. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'安全操作未完成，原资料未更改；请重试'**
  String get securityMutationFailed;

  /// Security: InvalidCredentialIdentity. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'请输入 1–80 字名称及有效默认用户名'**
  String get securityInvalidCredentialIdentity;

  /// Security: SecretRequired. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'请提供秘密内容'**
  String get securitySecretRequired;

  /// Security: ReimportForPassphrase. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'更新已保存的口令时，请同时重新导入对应私钥'**
  String get securityReimportForPassphrase;

  /// Security: PasswordNoPassphrase. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'密码凭据不使用私钥口令'**
  String get securityPasswordNoPassphrase;

  /// Security: SecretSizeInvalid. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'秘密内容为空或超出大小限制'**
  String get securitySecretSizeInvalid;

  /// Security: SecretWriteUnverified. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'秘密写入未能校验，原凭据保持不变'**
  String get securitySecretWriteUnverified;

  /// Security: CleanupIncomplete. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'秘密清理尚未完成，可稍后重试'**
  String get securityCleanupIncomplete;

  /// Security: CleanupReadFailed. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'无法读取待清理资料，请重试'**
  String get securityCleanupReadFailed;

  /// Security: SshCancelled. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'SSH 连接已取消或资料需重读'**
  String get securitySshCancelled;

  /// Security: ChooseAvailableCredential. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'请选择可用凭据'**
  String get securityChooseAvailableCredential;

  /// Security: CredentialSecretMissing. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'未找到此凭据的密码或私钥，请到“管理凭据”重新保存密码或导入私钥'**
  String get securityCredentialSecretMissing;

  /// Security: StoredSecretUnreadable. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'安全存储资料无法读取'**
  String get securityStoredSecretUnreadable;

  /// Security: CredentialChanged. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'凭据已变化，请重读后重试'**
  String get securityCredentialChanged;

  /// Security: SshCredentialReadFailed. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'无法读取 SSH 凭据，请重试'**
  String get securitySshCredentialReadFailed;

  /// Security: AuthenticationHidden. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'设备认证未完成，秘密仍隐藏'**
  String get securityAuthenticationHidden;

  /// Security: SavedPasswordMissing. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'未找到已保存的密码，请编辑此凭据并重新保存密码'**
  String get securitySavedPasswordMissing;

  /// Security: RevealFailed. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'无法显示秘密，请重试'**
  String get securityRevealFailed;

  /// Security: HostTargetMismatch. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'主机核验目标不一致'**
  String get securityHostTargetMismatch;

  /// Security: HostAuthenticationIncomplete. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'主机核验或认证未完成'**
  String get securityHostAuthenticationIncomplete;

  /// Security: InvalidHost. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'主机地址无效，请填写 IP 或域名，不含协议、用户名、端口或路径'**
  String get securityInvalidHost;

  /// Security: InvalidSshPort. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'SSH 端口应为 1–65535'**
  String get securityInvalidSshPort;

  /// Security: HostKeyUnreadable. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'无法识别主机公钥，请检查完整公钥内容及所选类型'**
  String get securityHostKeyUnreadable;

  /// Security: PrivateKeyUnreadable. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'无法读取私钥，请检查完整内容、支持格式和解密口令'**
  String get securityPrivateKeyUnreadable;

  /// Security: NativeStorageUnsupported. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'此平台没有原生安全存储'**
  String get securityNativeStorageUnsupported;

  /// Security: NativeStorageUnavailable. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'原生安全存储不可用或未完成，请检查设备后重试'**
  String get securityNativeStorageUnavailable;

  /// Security: DeviceAuthUnsupported. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'此平台不支持设备认证，无法显示秘密'**
  String get securityDeviceAuthUnsupported;

  /// Security: DeviceAuthReason. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'验证你的身份以查看已保存的密码'**
  String get securityDeviceAuthReason;

  /// Security: DeviceAuthIncomplete. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'设备认证未完成'**
  String get securityDeviceAuthIncomplete;

  /// Security: PasswordKind. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'用户名与密码'**
  String get securityPasswordKind;

  /// Security: PrivateKeyKind. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'SSH 密钥'**
  String get securityPrivateKeyKind;

  /// Security: ReloadSaved. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'重新读取已保存的资料'**
  String get securityReloadSaved;

  /// Security: CleanupNotice. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'有未完成的安全存储清理。当前连接引用已保留；请在系统安全存储可用后重试。不会删除仍在使用的秘密。'**
  String get securityCleanupNotice;

  /// Security: RetryCleanup. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'重试清理未引用秘密'**
  String get securityRetryCleanup;

  /// Security: AddLoginCredential. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'新增登录凭据'**
  String get securityAddLoginCredential;

  /// Security: ImportKey. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'导入 SSH 密钥'**
  String get securityImportKey;

  /// Security: ImportKeySubtitle. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'系统文件选择器或粘贴 · 校验格式与口令'**
  String get securityImportKeySubtitle;

  /// Security: SaveUsernamePassword. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'保存用户名与密码'**
  String get securitySaveUsernamePassword;

  /// Security: ReusableCredential. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'可供多台服务器引用'**
  String get securityReusableCredential;

  /// Security: Title. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'密钥与安全'**
  String get securityTitle;

  /// Security: AddCredential. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'新增凭据'**
  String get securityAddCredential;

  /// Security: CredentialStorageNotice. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'秘密仅保存在系统安全存储中，服务器只引用凭据。'**
  String get securityCredentialStorageNotice;

  /// Security: SearchCredentials. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'搜索名称、默认用户名'**
  String get securitySearchCredentials;

  /// Security: All. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get securityAll;

  /// Security: CredentialCount. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'已保存的登录凭据 · {count} 条'**
  String securityCredentialCount(int count);

  /// Security: NoMatchingCredentials. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'没有匹配的凭据。可切换筛选或新增。'**
  String get securityNoMatchingCredentials;

  /// Security: LinkedServerCount. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'{count} 台关联'**
  String securityLinkedServerCount(int count);

  /// Security: DeviceConnectionSecurity. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'设备与连接安全'**
  String get securityDeviceConnectionSecurity;

  /// Security: TrustedHosts. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'已信任的主机'**
  String get securityTrustedHosts;

  /// Security: TrustedHostsSubtitle. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'主机、端口、算法与完整主机公钥'**
  String get securityTrustedHostsSubtitle;

  /// Security: CredentialProtection. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'凭据保护'**
  String get securityCredentialProtection;

  /// Security: CredentialProtectionSubtitle. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'设备验证、短时显示与平台限制'**
  String get securityCredentialProtectionSubtitle;

  /// Security: CredentialProtectionDetail. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'密码、私钥和密钥口令不进入台账数据库、导出或日志。密码查看需系统设备验证，20 秒后或离开页面即隐藏。Linux 不支持本应用的设备验证，无法查看秘密。\n\n设备认证是应用显示门禁，不代表秘密被生物识别硬件单独加密。iOS / Android 真机安全行为仍需验证。Dart 不保证内存安全擦除；当前不提供秘密复制或导出。'**
  String get securityCredentialProtectionDetail;

  /// Security: LocalCredentialNotice. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'只修改本机凭据，不会改动服务器端密码或 authorized_keys。'**
  String get securityLocalCredentialNotice;

  /// Security: ViewDetails. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'查看详情'**
  String get securityViewDetails;

  /// Security: PrivateKeyDetailsSubtitle. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'公钥指纹与元数据，不显示私钥'**
  String get securityPrivateKeyDetailsSubtitle;

  /// Security: PasswordDetailsSubtitle. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'默认隐藏密码，查看需设备验证'**
  String get securityPasswordDetailsSubtitle;

  /// Security: EditCredential. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'编辑凭据'**
  String get securityEditCredential;

  /// Security: KeepSecret. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'留空保留已保存的秘密'**
  String get securityKeepSecret;

  /// Security: LinkedServers. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'关联服务器'**
  String get securityLinkedServers;

  /// Security: IndependentUsernames. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'连接用户名独立保存'**
  String get securityIndependentUsernames;

  /// Security: DeleteCredential. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'删除凭据'**
  String get securityDeleteCredential;

  /// Security: ReviewDeleteImpact. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'先确认替换或解除关联影响'**
  String get securityReviewDeleteImpact;

  /// Security: DiscardCredentialTitle. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'放弃本次编辑？'**
  String get securityDiscardCredentialTitle;

  /// Security: DiscardCredentialMessage. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'尚未保存的凭据内容会被清除。'**
  String get securityDiscardCredentialMessage;

  /// Security: DiscardChanges. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'放弃修改'**
  String get securityDiscardChanges;

  /// Security: KeyImported. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'已导入待保存的私钥；保存时校验格式与口令'**
  String get securityKeyImported;

  /// Security: KeyFileReadFailed. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'无法读取私钥文件。请选择不超过 128 KB 的 UTF-8 私钥文件。'**
  String get securityKeyFileReadFailed;

  /// Security: KeyPasted. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'已粘贴待保存的私钥；内容保持隐藏，保存时校验'**
  String get securityKeyPasted;

  /// Security: KeyPasteFailed. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'无法粘贴私钥。请复制不超过 128 KB 的完整私钥内容。'**
  String get securityKeyPasteFailed;

  /// Security: CredentialSaved. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'凭据已保存，远端认证资料未改变'**
  String get securityCredentialSaved;

  /// Security: CancelCredentialEdit. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'取消编辑凭据'**
  String get securityCancelCredentialEdit;

  /// Security: CredentialName. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'凭据名称'**
  String get securityCredentialName;

  /// Security: CredentialNameRequired. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'请填写凭据名称'**
  String get securityCredentialNameRequired;

  /// Security: DefaultLoginUsername. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'默认登录用户名'**
  String get securityDefaultLoginUsername;

  /// Security: OptionalDefaultUsername. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'默认用户名（可选）'**
  String get securityOptionalDefaultUsername;

  /// Security: DefaultUsernameRequired. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'请填写默认用户名'**
  String get securityDefaultUsernameRequired;

  /// Security: ChoosingFile. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'选择文件中…'**
  String get securityChoosingFile;

  /// Security: ChoosePrivateKeyFile. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'选择私钥文件'**
  String get securityChoosePrivateKeyFile;

  /// Security: PasteCompleteKey. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'粘贴完整私钥'**
  String get securityPasteCompleteKey;

  /// Security: PrivateKeyImportNotice. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'支持 OpenSSH / PEM 私钥；不保存文件路径，内容始终隐藏。'**
  String get securityPrivateKeyImportNotice;

  /// Security: LoginPassword. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'登录密码'**
  String get securityLoginPassword;

  /// Security: PrivateKeyContent. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'私钥内容'**
  String get securityPrivateKeyContent;

  /// Security: KeepSecretHidden. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'留空保留已保存内容，旧秘密不会回显'**
  String get securityKeepSecretHidden;

  /// Security: LoginPasswordRequired. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'请填写登录密码'**
  String get securityLoginPasswordRequired;

  /// Security: PrivateKeyRequired. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'请选择私钥文件或粘贴完整私钥'**
  String get securityPrivateKeyRequired;

  /// Security: PrivateKeyPassphrase. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'私钥加密口令（如有）'**
  String get securityPrivateKeyPassphrase;

  /// Security: PrivateKeyPassphraseHelp. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'用于解密私钥，不是登录密码。'**
  String get securityPrivateKeyPassphraseHelp;

  /// Security: StoreKeyPassphrase. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'在设备安全存储中保存私钥口令'**
  String get securityStoreKeyPassphrase;

  /// Security: StoreKeyPassphraseHelp. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'默认不保存。加密私钥未保存口令时，每次连接都需输入。取消或口令错误会停止连接。仅在导入私钥时应用此选项。'**
  String get securityStoreKeyPassphraseHelp;

  /// Security: CredentialEditNotice. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'用户名仅作新连接的候选值。更新凭据只影响以后登录，不修改服务器端；退到后台会清空未保存内容。'**
  String get securityCredentialEditNotice;

  /// Security: CurrentLinkImpact. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'当前关联影响'**
  String get securityCurrentLinkImpact;

  /// Security: ServerFallback. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'服务器'**
  String get securityServerFallback;

  /// Security: Saving. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'保存中…'**
  String get securitySaving;

  /// Security: SaveCredential. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'保存凭据'**
  String get securitySaveCredential;

  /// Security: CredentialDetails. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'凭据详情'**
  String get securityCredentialDetails;

  /// Security: CredentialDeleted. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'凭据已删除'**
  String get securityCredentialDeleted;

  /// Security: CredentialDefaultUsername. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'{kind}\n默认用户名：{username}'**
  String securityCredentialDefaultUsername(String kind, String username);

  /// Security: UsernamePerConnection. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'由连接单独指定'**
  String get securityUsernamePerConnection;

  /// Security: PublicKeyFingerprint. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'公钥指纹'**
  String get securityPublicKeyFingerprint;

  /// Security: PublicKeyFingerprintNotice. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'公钥指纹用于辨认登录密钥，不同于服务器主机指纹；这里不展示私钥。'**
  String get securityPublicKeyFingerprintNotice;

  /// Security: FingerprintCopied. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'公钥指纹已复制'**
  String get securityFingerprintCopied;

  /// Security: CopyFailed. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'复制未完成，请重试'**
  String get securityCopyFailed;

  /// Security: CopyFingerprint. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'复制公钥指纹'**
  String get securityCopyFingerprint;

  /// Security: ProtectedPassword. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'受保护的密码'**
  String get securityProtectedPassword;

  /// Security: PasswordRevealNotice. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'20 秒后隐藏；离开页面或转入后台立即隐藏。'**
  String get securityPasswordRevealNotice;

  /// Security: PasswordHiddenNotice. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'验证成功后仅短时显示。无设备认证能力时保持隐藏；Linux 暂不可查看。'**
  String get securityPasswordHiddenNotice;

  /// Security: HidePassword. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'隐藏密码'**
  String get securityHidePassword;

  /// Security: VerifyViewPassword. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'设备验证后查看密码'**
  String get securityVerifyViewPassword;

  /// Security: CancelVerifyHide. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'取消验证并隐藏'**
  String get securityCancelVerifyHide;

  /// Security: CredentialReferenceCount. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'{count} 台服务器引用此凭据（含已归档）。'**
  String securityCredentialReferenceCount(int count);

  /// Security: NoCredentialReferences. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'尚未关联。可在服务器详情的 SSH 配置中选择。'**
  String get securityNoCredentialReferences;

  /// Security: CredentialDeleteImpact. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'{count} 台服务器将受影响（含已归档）。'**
  String securityCredentialDeleteImpact(int count);

  /// Security: ManageLinks. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'如何处理关联'**
  String get securityManageLinks;

  /// Security: ReplaceOrUnlink. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'替换或解除'**
  String get securityReplaceOrUnlink;

  /// Security: UnlinkAll. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'解除所有关联'**
  String get securityUnlinkAll;

  /// Security: ReplaceWith. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'替换为 {name}'**
  String securityReplaceWith(String name);

  /// Security: UnlinkCredentialNotice. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'解除后服务器、用户名和付款保留，下次连接需重新选择凭据。'**
  String get securityUnlinkCredentialNotice;

  /// Security: ReplaceCredentialNotice. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'仅替换凭据引用，所有服务器当前用户名保持不变。'**
  String get securityReplaceCredentialNotice;

  /// Security: DeleteLocalCredentialNotice. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'仅删除本机凭据，无法恢复；不影响服务器端或云服务。'**
  String get securityDeleteLocalCredentialNotice;

  /// Security: ConfirmCredentialImpact. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'我已确认关联影响，删除本地凭据'**
  String get securityConfirmCredentialImpact;

  /// Security: LocalCredentialDeleted. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'本地凭据已删除，远端认证资料未改变'**
  String get securityLocalCredentialDeleted;

  /// Security: ConfirmDelete. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'确认删除'**
  String get securityConfirmDelete;

  /// Security: VerifyHostKey. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'核验主机公钥'**
  String get securityVerifyHostKey;

  /// Security: HostTrustNotice. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'信任绑定主机地址、端口和完整公钥，与登录凭据无关。'**
  String get securityHostTrustNotice;

  /// Security: NoTrustedHosts. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'尚无已信任主机。可在此录入从厂商控制台或管理员等独立可信渠道取得的公钥，也可在首次 SSH 连接时核对。此页面不会连接服务器。'**
  String get securityNoTrustedHosts;

  /// Security: HostVerifiedAt. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'{algorithm}\n核验于 {date}'**
  String securityHostVerifiedAt(String algorithm, String date);

  /// Security: CompleteHostKey. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'完整主机公钥'**
  String get securityCompleteHostKey;

  /// Security: ReverifyHost. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'重新核实主机'**
  String get securityReverifyHost;

  /// Security: RemoveHostTrustTitle. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'移除主机信任？'**
  String get securityRemoveHostTrustTitle;

  /// Security: RemoveHostTrustMessage. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'{host}:{port}\n{fingerprint}\n\n下次连接必须重新核验身份。不会删除服务器或登录凭据。'**
  String securityRemoveHostTrustMessage(
    String host,
    int port,
    String fingerprint,
  );

  /// Security: RemoveHostTrust. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'移除信任'**
  String get securityRemoveHostTrust;

  /// Security: HostChangedNotice. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'若主机密钥变化，必须停止认证并通过独立渠道重新核实。没有“忽略并连接”入口。'**
  String get securityHostChangedNotice;

  /// Security: HostTrustReadFailed. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'无法读取主机信任资料，请重试'**
  String get securityHostTrustReadFailed;

  /// Security: HostTrustInputNotice. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'请输入从厂商控制台等独立可信渠道取得的主机公钥。本页只保存本机信任，不连接服务器。'**
  String get securityHostTrustInputNotice;

  /// Security: HostAddress. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'主机地址'**
  String get securityHostAddress;

  /// Security: Port. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'端口'**
  String get securityPort;

  /// Security: HostKeyType. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'主机公钥类型'**
  String get securityHostKeyType;

  /// Security: HostKeyHelp. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'公钥行或完整 Base64；不是私钥，也不只是指纹'**
  String get securityHostKeyHelp;

  /// Security: RsaHostKeyNotice. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'rsa-sha2-256 / 512 是签名算法，公钥类型请选 ssh-rsa。'**
  String get securityRsaHostKeyNotice;

  /// No description provided for @r2CopyInfoRsaKey.
  ///
  /// In zh, this message translates to:
  /// **'关于 RSA 主机公钥'**
  String get r2CopyInfoRsaKey;

  /// Security: Checking. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'校验中…'**
  String get securityChecking;

  /// Security: CheckFingerprint. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'检查并核对指纹'**
  String get securityCheckFingerprint;

  /// Security: HostKeyMismatch. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'主机公钥与记录不一致'**
  String get securityHostKeyMismatch;

  /// Security: FirstHostVerification. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'首次主机核验'**
  String get securityFirstHostVerification;

  /// Security: HostMismatchBadge. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'公钥不一致 · 请独立重新核实'**
  String get securityHostMismatchBadge;

  /// Security: HostVerifyBeforeSave. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'请先核实主机身份，再保存信任'**
  String get securityHostVerifyBeforeSave;

  /// Security: SavedHostFingerprint. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'已保存的主机指纹'**
  String get securitySavedHostFingerprint;

  /// Security: CandidateHostFingerprint. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'待核验的主机指纹'**
  String get securityCandidateHostFingerprint;

  /// Security: HostVerificationWarning. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'请通过独立渠道核对指纹和地址。变化可能是重装，也可能是中间人攻击；无法确认请拒绝。'**
  String get securityHostVerificationWarning;

  /// Security: BeginHostReverification. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'开始独立重新核实'**
  String get securityBeginHostReverification;

  /// Security: ConfirmHostVerified. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'我已通过独立渠道核对主机、端口和完整指纹'**
  String get securityConfirmHostVerified;

  /// Security: HostTrustSaved. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'主机信任已保存；没有发起连接或认证'**
  String get securityHostTrustSaved;

  /// Security: ReverifyReplaceTrust. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'重新核实并替换信任'**
  String get securityReverifyReplaceTrust;

  /// Security: SaveVerifiedHostTrust. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'保存已核验的主机信任'**
  String get securitySaveVerifiedHostTrust;

  /// Security: RejectBack. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'拒绝并返回'**
  String get securityRejectBack;

  /// Security: status pill text for host key state.
  ///
  /// In zh, this message translates to:
  /// **'已核验'**
  String get uiSecurityVerified;

  /// Security: status pill text for host key state.
  ///
  /// In zh, this message translates to:
  /// **'未核验'**
  String get uiSecurityUnverified;

  /// Security: status pill text for host key state.
  ///
  /// In zh, this message translates to:
  /// **'公钥已变化'**
  String get uiSecurityKeyChanged;

  /// Security: SavingHostTrust. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'正在保存已确认的信任。完成前暂时不能返回。'**
  String get securitySavingHostTrust;

  /// Security: LocalHostTrustOnly. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'只记录本机信任；拒绝、取消或返回均不保存。'**
  String get securityLocalHostTrustOnly;

  /// Security: DiscardSshTitle. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'放弃连接配置？'**
  String get securityDiscardSshTitle;

  /// Security: DiscardSshMessage. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'未保存的地址、用户名与凭据选择不会生效。'**
  String get securityDiscardSshMessage;

  /// Security: ChooseCredential. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'选择登录凭据'**
  String get securityChooseCredential;

  /// Security: UnlinkCurrentCredential. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'解除当前凭据关联'**
  String get securityUnlinkCurrentCredential;

  /// Security: ChooseCredentialLater. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'保留连接配置，之后再选择'**
  String get securityChooseCredentialLater;

  /// Security: CredentialChoiceSubtitle. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'{kind} · 默认 {username}'**
  String securityCredentialChoiceSubtitle(String kind, String username);

  /// Security: NotSet. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'未设置'**
  String get securityNotSet;

  /// Security: NoCredentialsToChoose. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'尚无凭据。先返回，使用“管理凭据”新增。'**
  String get securityNoCredentialsToChoose;

  /// Security: AdoptUsernameTitle. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'使用凭据的默认用户名？'**
  String get securityAdoptUsernameTitle;

  /// Security: AdoptUsernameMessage. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'当前连接用户名：{current}\n凭据默认用户名：{suggested}\n\n只影响本台连接；取消将保留当前用户名。'**
  String securityAdoptUsernameMessage(String current, String suggested);

  /// Security: NotEntered. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'未填写'**
  String get securityNotEntered;

  /// Security: AdoptUsername. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'采用默认用户名'**
  String get securityAdoptUsername;

  /// Security: SshConfigurationSaved. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'SSH 配置已保存，未建立网络连接'**
  String get securitySshConfigurationSaved;

  /// Security: SshConfiguration. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'SSH 连接配置'**
  String get securitySshConfiguration;

  /// Security: CancelSshConfiguration. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'取消连接配置'**
  String get securityCancelSshConfiguration;

  /// Security: SshConfigurationNotice. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'连接配置和台账地址分别保存。不会修改云主机设置。'**
  String get securitySshConfigurationNotice;

  /// Security: HostHint. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'IPv4 / IPv6 / 域名，不含协议'**
  String get securityHostHint;

  /// Security: HostRequired. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'请填写主机地址'**
  String get securityHostRequired;

  /// Security: PortRequired. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'端口应为 1–65535'**
  String get securityPortRequired;

  /// Security: ConnectionUsername. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'当前连接用户名'**
  String get securityConnectionUsername;

  /// Security: ConnectionUsernameRequired. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'请填写登录用户名，或使用凭据的默认用户名'**
  String get securityConnectionUsernameRequired;

  /// Security: LoginCredential. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'登录凭据'**
  String get securityLoginCredential;

  /// Security: ManageCredentials. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'管理凭据'**
  String get securityManageCredentials;

  /// Security: CredentialNotConfigured. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'凭据待配置'**
  String get securityCredentialNotConfigured;

  /// Security: CredentialRequiredBeforeConnect. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'可先保存配置，连接前必须选择凭据'**
  String get securityCredentialRequiredBeforeConnect;

  /// Security: ChangeCredentialSubtitle. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'{kind} · 点击更换或解除'**
  String securityChangeCredentialSubtitle(String kind);

  /// Security: ConnectionUsernameNotice. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'用户名属于本台连接。换凭据时只有明确选择“采用默认用户名”才更改它，取消和相同用户名都不会修改其他连接。'**
  String get securityConnectionUsernameNotice;

  /// Security: ConfigurationOnlyNotice. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'仅保存连接配置。连接时先核验主机公钥，公钥变化会暂停认证。'**
  String get securityConfigurationOnlyNotice;

  /// Security: SaveSshConfiguration. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'保存 SSH 配置'**
  String get securitySaveSshConfiguration;

  /// Security: OpenKeyFile. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'导入'**
  String get securityOpenKeyFile;

  /// Security: AuthCancel. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get securityAuthCancel;

  /// Security: AuthSignInTitle. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'身份验证'**
  String get securityAuthSignInTitle;

  /// Security: AuthBiometricHint. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'验证身份'**
  String get securityAuthBiometricHint;

  /// Security: AuthBiometricNotRecognized. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'未能识别，请重试。'**
  String get securityAuthBiometricNotRecognized;

  /// Security: AuthBiometricSuccess. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'验证成功'**
  String get securityAuthBiometricSuccess;

  /// Security: AuthRequiredTitle. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'需要生物识别验证'**
  String get securityAuthRequiredTitle;

  /// Security: AuthSetupDescription. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'请在设备设置中启用生物识别验证。'**
  String get securityAuthSetupDescription;

  /// Security: AuthGoToSettings. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'前往设置'**
  String get securityAuthGoToSettings;

  /// Security: AuthDeviceSetupDescription. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'请在设备设置中启用设备验证。'**
  String get securityAuthDeviceSetupDescription;

  /// Security: AuthDeviceRequiredTitle. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'需要设备验证'**
  String get securityAuthDeviceRequiredTitle;

  /// Security: AuthIosLockout. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'生物识别验证已锁定。请锁定并解锁设备，再重新尝试。'**
  String get securityAuthIosLockout;

  /// Security: AuthIosSetupDescription. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'请在设备设置中启用 Face ID 或 Touch ID。'**
  String get securityAuthIosSetupDescription;

  /// No description provided for @serverCompactMonths.
  ///
  /// In zh, this message translates to:
  /// **'{months}个月'**
  String serverCompactMonths(int months);

  /// No description provided for @resourceTrafficPeriodUnsetShort.
  ///
  /// In zh, this message translates to:
  /// **'未设置'**
  String get resourceTrafficPeriodUnsetShort;

  /// No description provided for @resourceTrafficPeriodMonthShort.
  ///
  /// In zh, this message translates to:
  /// **'月'**
  String get resourceTrafficPeriodMonthShort;

  /// No description provided for @resourceTrafficPeriodQuarterShort.
  ///
  /// In zh, this message translates to:
  /// **'季'**
  String get resourceTrafficPeriodQuarterShort;

  /// No description provided for @resourceTrafficPeriodYearShort.
  ///
  /// In zh, this message translates to:
  /// **'年'**
  String get resourceTrafficPeriodYearShort;

  /// Provider and adapter relationship validation.
  ///
  /// In zh, this message translates to:
  /// **'提供商名称需为 1–80 个字符。'**
  String get providerNameRange;

  /// Provider and adapter relationship validation.
  ///
  /// In zh, this message translates to:
  /// **'这个提供商已存在，请直接选择。'**
  String get providerAlreadyExists;

  /// Provider navigation and ownership UI.
  ///
  /// In zh, this message translates to:
  /// **'提供商管理'**
  String get providerUiTitle;

  /// Cloud / provider UI.
  ///
  /// In zh, this message translates to:
  /// **'提供商'**
  String get uiCloudProvidersTitle;

  /// Provider navigation and ownership UI.
  ///
  /// In zh, this message translates to:
  /// **'提供商详情'**
  String get providerUiDetails;

  /// Provider navigation and ownership UI.
  ///
  /// In zh, this message translates to:
  /// **'新增提供商'**
  String get providerUiAdd;

  /// Provider navigation and ownership UI.
  ///
  /// In zh, this message translates to:
  /// **'重命名提供商'**
  String get providerUiRename;

  /// Provider navigation and ownership UI.
  ///
  /// In zh, this message translates to:
  /// **'提供商名称'**
  String get providerUiName;

  /// Provider navigation and ownership UI.
  ///
  /// In zh, this message translates to:
  /// **'未指定提供商'**
  String get providerUiUnspecified;

  /// Provider navigation and ownership UI.
  ///
  /// In zh, this message translates to:
  /// **'提供商是服务器的业务归属。可以从目录里添加，也可以自己新建。'**
  String get providerUiHierarchyHelp;

  /// Provider catalog and packages.
  ///
  /// In zh, this message translates to:
  /// **'{count} 台服务器'**
  String r6CatProviderSummary(int count);

  /// Provider catalog and packages.
  ///
  /// In zh, this message translates to:
  /// **'目录'**
  String get r6CatCatalogSection;

  /// Provider catalog and packages.
  ///
  /// In zh, this message translates to:
  /// **'我的提供商'**
  String get r6CatMineSection;

  /// Providers and packages UI (r8).
  ///
  /// In zh, this message translates to:
  /// **'使用中的提供商'**
  String get r8ProvidersInUse;

  /// Providers and packages UI (r8).
  ///
  /// In zh, this message translates to:
  /// **'还没有提供商关联服务器。'**
  String get r8NoProvidersInUse;

  /// Providers and packages UI (r8).
  ///
  /// In zh, this message translates to:
  /// **'全部提供商'**
  String get r8AllProviders;

  /// Providers and packages UI (r8).
  ///
  /// In zh, this message translates to:
  /// **'搜索提供商'**
  String get r8SearchProviders;

  /// Providers and packages UI (r8).
  ///
  /// In zh, this message translates to:
  /// **'没有匹配的结果。'**
  String get r8NoMatches;

  /// Providers and packages UI (r8).
  ///
  /// In zh, this message translates to:
  /// **'目录'**
  String get r8BadgeCatalog;

  /// Providers and packages UI (r8).
  ///
  /// In zh, this message translates to:
  /// **'自建'**
  String get r8BadgeCustom;

  /// Providers and packages UI (r8).
  ///
  /// In zh, this message translates to:
  /// **'使用中'**
  String get r8SectionInUse;

  /// Providers and packages UI (r8).
  ///
  /// In zh, this message translates to:
  /// **'新建提供商“{name}”'**
  String r8NewProviderNamed(String name);

  /// Providers and packages UI (r8).
  ///
  /// In zh, this message translates to:
  /// **'选择提供商'**
  String get r8PickProvider;

  /// Provider catalog and packages.
  ///
  /// In zh, this message translates to:
  /// **'目录里的提供商可以直接添加；没有找到时，可以新建自己的提供商。'**
  String get r6CatCatalogFooter;

  /// Provider catalog and packages.
  ///
  /// In zh, this message translates to:
  /// **'提供商'**
  String get r6CatServerSection;

  /// Provider catalog and packages.
  ///
  /// In zh, this message translates to:
  /// **'服务器保留自己的硬件与费用。如需更换提供商，请编辑服务器。'**
  String get r6CatServerFooter;

  /// Provider catalog and packages.
  ///
  /// In zh, this message translates to:
  /// **'尚未添加。添加后即可把服务器关联到它。'**
  String get r6CatCatalogProviderHelp;

  /// Provider catalog and packages.
  ///
  /// In zh, this message translates to:
  /// **'提供商'**
  String get r6CatBackupProviders;

  /// Provider catalog and packages.
  ///
  /// In zh, this message translates to:
  /// **'提供商：{count}'**
  String r6CatBackupProviderCount(int count);

  /// Provider navigation and ownership UI.
  ///
  /// In zh, this message translates to:
  /// **'还没有提供商'**
  String get providerUiEmpty;

  /// Provider navigation and ownership UI.
  ///
  /// In zh, this message translates to:
  /// **'{count} 台服务器尚未指定提供商。'**
  String providerUiUnspecifiedCount(int count);

  /// Provider navigation and ownership UI.
  ///
  /// In zh, this message translates to:
  /// **'名下服务器'**
  String get providerUiDevices;

  /// Provider navigation and ownership UI.
  ///
  /// In zh, this message translates to:
  /// **'此提供商已变更或不可用，请返回重新选择。'**
  String get providerUiUnavailable;

  /// Provider navigation and ownership UI.
  ///
  /// In zh, this message translates to:
  /// **'查看提供商'**
  String get providerUiOpenProvider;

  /// No description provided for @r9DirSection.
  ///
  /// In zh, this message translates to:
  /// **'提供商目录'**
  String get r9DirSection;

  /// No description provided for @r9DirNone.
  ///
  /// In zh, this message translates to:
  /// **'尚未下载'**
  String get r9DirNone;

  /// Provider directory status: version and number of providers.
  ///
  /// In zh, this message translates to:
  /// **'版本 {version} · {count} 个提供商'**
  String r9DirSummary(int version, int count);

  /// No description provided for @r9DirUpToDate.
  ///
  /// In zh, this message translates to:
  /// **'已是最新'**
  String get r9DirUpToDate;

  /// No description provided for @r9DirUpdated.
  ///
  /// In zh, this message translates to:
  /// **'已更新'**
  String get r9DirUpdated;

  /// No description provided for @r9DirUnreachable.
  ///
  /// In zh, this message translates to:
  /// **'无法连接 GitHub'**
  String get r9DirUnreachable;

  /// When the provider directory was last checked, e.g. 3 hours ago.
  ///
  /// In zh, this message translates to:
  /// **'检查于 {when}'**
  String r9DirChecked(String when);

  /// No description provided for @r9DirNeverChecked.
  ///
  /// In zh, this message translates to:
  /// **'尚未检查'**
  String get r9DirNeverChecked;

  /// No description provided for @r9DirCheck.
  ///
  /// In zh, this message translates to:
  /// **'检查更新'**
  String get r9DirCheck;

  /// No description provided for @r9DirAuto.
  ///
  /// In zh, this message translates to:
  /// **'启动时更新'**
  String get r9DirAuto;

  /// No description provided for @r9DirAutoFooter.
  ///
  /// In zh, this message translates to:
  /// **'只下载公开的提供商列表；你的台账不会离开设备。'**
  String get r9DirAutoFooter;

  /// No description provided for @r9TimeJustNow.
  ///
  /// In zh, this message translates to:
  /// **'刚刚'**
  String get r9TimeJustNow;

  /// Relative time.
  ///
  /// In zh, this message translates to:
  /// **'{count} 分钟前'**
  String r9TimeMinutesAgo(int count);

  /// Relative time.
  ///
  /// In zh, this message translates to:
  /// **'{count} 小时前'**
  String r9TimeHoursAgo(int count);

  /// Relative time.
  ///
  /// In zh, this message translates to:
  /// **'{count} 天前'**
  String r9TimeDaysAgo(int count);

  /// No description provided for @r9DirEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'提供商目录尚未下载。联网后，到“设置 → 提供商”检查更新。'**
  String get r9DirEmptyHint;

  /// No description provided for @r9Website.
  ///
  /// In zh, this message translates to:
  /// **'官网'**
  String get r9Website;

  /// No description provided for @r9WebsiteCopied.
  ///
  /// In zh, this message translates to:
  /// **'已复制网址'**
  String get r9WebsiteCopied;

  /// No description provided for @r9ProviderDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除提供商'**
  String get r9ProviderDelete;

  /// Delete provider confirmation title.
  ///
  /// In zh, this message translates to:
  /// **'删除“{name}”？'**
  String r9ProviderDeleteTitle(String name);

  /// Delete provider confirmation message.
  ///
  /// In zh, this message translates to:
  /// **'{count, plural, =0{将从你的台账中移除这个提供商。} other{将从你的台账中移除这个提供商。它的 {count} 台服务器会保留，显示为未指定提供商。}}'**
  String r9ProviderDeleteMessage(int count);

  /// No description provided for @r11AboutWhatsNew.
  ///
  /// In zh, this message translates to:
  /// **'更新记录'**
  String get r11AboutWhatsNew;

  /// No description provided for @r11AboutSourceCode.
  ///
  /// In zh, this message translates to:
  /// **'源代码'**
  String get r11AboutSourceCode;

  /// No description provided for @r11AboutLicense.
  ///
  /// In zh, this message translates to:
  /// **'许可证'**
  String get r11AboutLicense;

  /// No description provided for @r11AboutOpenSource.
  ///
  /// In zh, this message translates to:
  /// **'开源组件'**
  String get r11AboutOpenSource;

  /// No description provided for @r11AboutRepoCopied.
  ///
  /// In zh, this message translates to:
  /// **'已复制源代码地址'**
  String get r11AboutRepoCopied;

  /// No description provided for @r11AboutFootnote.
  ///
  /// In zh, this message translates to:
  /// **'免费开源，仅靠自愿捐赠维持。没有广告，无需账号；台账只保存在本机，应用只会下载公开的提供商目录。'**
  String get r11AboutFootnote;

  /// No description provided for @r11AboutTrademark.
  ///
  /// In zh, this message translates to:
  /// **'提供商的名称和 Logo 归各自所有者所有，仅用于识别。'**
  String get r11AboutTrademark;

  /// No description provided for @r11ChangelogUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'无法读取更新记录。'**
  String get r11ChangelogUnavailable;

  /// No description provided for @r11LicenseUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'无法读取许可证文本。'**
  String get r11LicenseUnavailable;

  /// No description provided for @r11OssBuiltWith.
  ///
  /// In zh, this message translates to:
  /// **'构建于'**
  String get r11OssBuiltWith;

  /// No description provided for @r11OssBuiltWithFootnote.
  ///
  /// In zh, this message translates to:
  /// **'点按组件查看许可证全文。'**
  String get r11OssBuiltWithFootnote;

  /// No description provided for @r11OssAllLicensesTitle.
  ///
  /// In zh, this message translates to:
  /// **'全部许可证'**
  String get r11OssAllLicensesTitle;

  /// No description provided for @r11OssAllLicenses.
  ///
  /// In zh, this message translates to:
  /// **'全部许可证（{n}）'**
  String r11OssAllLicenses(String n);

  /// No description provided for @r11OssSearch.
  ///
  /// In zh, this message translates to:
  /// **'搜索组件'**
  String get r11OssSearch;

  /// No description provided for @r11OssNoMatch.
  ///
  /// In zh, this message translates to:
  /// **'没有匹配的组件。'**
  String get r11OssNoMatch;

  /// No description provided for @r11OssLicenseMissing.
  ///
  /// In zh, this message translates to:
  /// **'没有找到这个组件的许可证文本，请在“全部许可证”中查看。'**
  String get r11OssLicenseMissing;

  /// No description provided for @r11OssLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法读取许可证列表。'**
  String get r11OssLoadFailed;

  /// No description provided for @r11OssAboutFlutter.
  ///
  /// In zh, this message translates to:
  /// **'跨平台界面框架'**
  String get r11OssAboutFlutter;

  /// No description provided for @r11OssAboutLocalizations.
  ///
  /// In zh, this message translates to:
  /// **'系统控件的本地化文字'**
  String get r11OssAboutLocalizations;

  /// No description provided for @r11OssAboutIntl.
  ///
  /// In zh, this message translates to:
  /// **'日期、数字和消息格式化'**
  String get r11OssAboutIntl;

  /// No description provided for @r11OssAboutSqflite.
  ///
  /// In zh, this message translates to:
  /// **'本地 SQLite 数据库'**
  String get r11OssAboutSqflite;

  /// No description provided for @r11OssAboutSqfliteFfi.
  ///
  /// In zh, this message translates to:
  /// **'桌面端和测试用的 SQLite'**
  String get r11OssAboutSqfliteFfi;

  /// No description provided for @r11OssAboutPath.
  ///
  /// In zh, this message translates to:
  /// **'文件路径处理'**
  String get r11OssAboutPath;

  /// No description provided for @r11OssAboutPathProvider.
  ///
  /// In zh, this message translates to:
  /// **'查找应用的存储目录'**
  String get r11OssAboutPathProvider;

  /// No description provided for @r11OssAboutSecureStorage.
  ///
  /// In zh, this message translates to:
  /// **'钥匙串 / Keystore 安全存储'**
  String get r11OssAboutSecureStorage;

  /// No description provided for @r11OssAboutLocalAuth.
  ///
  /// In zh, this message translates to:
  /// **'Face ID、指纹和设备密码验证'**
  String get r11OssAboutLocalAuth;

  /// No description provided for @r11OssAboutDartssh2.
  ///
  /// In zh, this message translates to:
  /// **'SSH 与 SFTP 客户端'**
  String get r11OssAboutDartssh2;

  /// No description provided for @r11OssAboutXterm.
  ///
  /// In zh, this message translates to:
  /// **'终端界面'**
  String get r11OssAboutXterm;

  /// No description provided for @r11OssAboutCrypto.
  ///
  /// In zh, this message translates to:
  /// **'哈希与摘要'**
  String get r11OssAboutCrypto;

  /// No description provided for @r11OssAboutFileSelector.
  ///
  /// In zh, this message translates to:
  /// **'系统文件选择与保存'**
  String get r11OssAboutFileSelector;

  /// No description provided for @r11OssAboutTimezone.
  ///
  /// In zh, this message translates to:
  /// **'时区数据库'**
  String get r11OssAboutTimezone;

  /// No description provided for @r11OssAboutFlutterTimezone.
  ///
  /// In zh, this message translates to:
  /// **'读取设备时区'**
  String get r11OssAboutFlutterTimezone;

  /// No description provided for @r11OssAboutSharePlus.
  ///
  /// In zh, this message translates to:
  /// **'系统分享面板'**
  String get r11OssAboutSharePlus;

  /// No description provided for @r11OssAboutHttp.
  ///
  /// In zh, this message translates to:
  /// **'下载提供商目录'**
  String get r11OssAboutHttp;

  /// No description provided for @r11OssAboutXml.
  ///
  /// In zh, this message translates to:
  /// **'解析 XML'**
  String get r11OssAboutXml;

  /// No description provided for @r11OssAboutLocalNotifications.
  ///
  /// In zh, this message translates to:
  /// **'到期提醒的本地通知'**
  String get r11OssAboutLocalNotifications;

  /// No description provided for @r11OssAboutDejaVu.
  ///
  /// In zh, this message translates to:
  /// **'终端等宽字体'**
  String get r11OssAboutDejaVu;

  /// No description provided for @r13ProxyUnreachable.
  ///
  /// In zh, this message translates to:
  /// **'无法连接代理服务器'**
  String get r13ProxyUnreachable;

  /// No description provided for @r13ProxyTlsFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法验证代理的 TLS 证书，或 TLS 握手失败'**
  String get r13ProxyTlsFailed;

  /// No description provided for @r13ProxyTimeout.
  ///
  /// In zh, this message translates to:
  /// **'通过代理连接超时'**
  String get r13ProxyTimeout;

  /// No description provided for @r13ProxyClosed.
  ///
  /// In zh, this message translates to:
  /// **'代理服务器中途关闭了连接'**
  String get r13ProxyClosed;

  /// No description provided for @r13ProxyProtocol.
  ///
  /// In zh, this message translates to:
  /// **'代理返回了无法识别的响应'**
  String get r13ProxyProtocol;

  /// No description provided for @r13ProxyAuthRequired.
  ///
  /// In zh, this message translates to:
  /// **'代理要求用户名和密码'**
  String get r13ProxyAuthRequired;

  /// No description provided for @r13ProxyAuthRejected.
  ///
  /// In zh, this message translates to:
  /// **'代理拒绝了用户名或密码'**
  String get r13ProxyAuthRejected;

  /// No description provided for @r13ProxyInvalidTarget.
  ///
  /// In zh, this message translates to:
  /// **'该目标地址无法通过代理连接'**
  String get r13ProxyInvalidTarget;

  /// No description provided for @r13ProxyInvalidSettings.
  ///
  /// In zh, this message translates to:
  /// **'代理设置无效'**
  String get r13ProxyInvalidSettings;

  /// No description provided for @r13ProxySocksGeneral.
  ///
  /// In zh, this message translates to:
  /// **'SOCKS5 代理报告一般性失败'**
  String get r13ProxySocksGeneral;

  /// No description provided for @r13ProxySocksNotAllowed.
  ///
  /// In zh, this message translates to:
  /// **'代理规则不允许连接该目标'**
  String get r13ProxySocksNotAllowed;

  /// No description provided for @r13ProxySocksNetwork.
  ///
  /// In zh, this message translates to:
  /// **'代理无法到达目标所在网络'**
  String get r13ProxySocksNetwork;

  /// No description provided for @r13ProxySocksHost.
  ///
  /// In zh, this message translates to:
  /// **'代理无法到达目标主机'**
  String get r13ProxySocksHost;

  /// No description provided for @r13ProxySocksRefused.
  ///
  /// In zh, this message translates to:
  /// **'目标拒绝了来自代理的连接'**
  String get r13ProxySocksRefused;

  /// No description provided for @r13ProxySocksTtl.
  ///
  /// In zh, this message translates to:
  /// **'代理连接目标时 TTL 已过期'**
  String get r13ProxySocksTtl;

  /// No description provided for @r13ProxySocksCommand.
  ///
  /// In zh, this message translates to:
  /// **'代理不支持 CONNECT 命令'**
  String get r13ProxySocksCommand;

  /// No description provided for @r13ProxySocksAddress.
  ///
  /// In zh, this message translates to:
  /// **'代理不支持该类型的目标地址'**
  String get r13ProxySocksAddress;

  /// No description provided for @r13ProxyHttpStatus.
  ///
  /// In zh, this message translates to:
  /// **'代理拒绝了 CONNECT 请求（HTTP {code}）'**
  String r13ProxyHttpStatus(int code);

  /// No description provided for @r13ProxyInvalid.
  ///
  /// In zh, this message translates to:
  /// **'请填写名称，以及有效的代理主机和端口'**
  String get r13ProxyInvalid;

  /// No description provided for @r13ProxyInUse.
  ///
  /// In zh, this message translates to:
  /// **'仍有 SSH 配置在使用此代理。请先改用其他代理或直连。'**
  String get r13ProxyInUse;

  /// No description provided for @r13ProxyPasswordRequired.
  ///
  /// In zh, this message translates to:
  /// **'设置用户名时必须填写代理密码'**
  String get r13ProxyPasswordRequired;

  /// No description provided for @r13ProxyUsernameRequired.
  ///
  /// In zh, this message translates to:
  /// **'填写密码前请先填写用户名'**
  String get r13ProxyUsernameRequired;

  /// No description provided for @r13ProxyCredentialInvalid.
  ///
  /// In zh, this message translates to:
  /// **'用户名和密码需为 1–255 字节且不含控制字符；HTTP/HTTPS 代理的用户名不能含冒号。'**
  String get r13ProxyCredentialInvalid;

  /// No description provided for @r13ProxyMissing.
  ///
  /// In zh, this message translates to:
  /// **'所选代理已不存在，请重新选择'**
  String get r13ProxyMissing;

  /// No description provided for @r13ProxyPasswordMissing.
  ///
  /// In zh, this message translates to:
  /// **'未找到已保存的代理密码，请重新输入'**
  String get r13ProxyPasswordMissing;

  /// No description provided for @r13ProxyChanged.
  ///
  /// In zh, this message translates to:
  /// **'代理在连接前被修改，请重试'**
  String get r13ProxyChanged;

  /// No description provided for @r13ProxyReadFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法读取代理设置'**
  String get r13ProxyReadFailed;

  /// No description provided for @r13ProxiesTitle.
  ///
  /// In zh, this message translates to:
  /// **'代理'**
  String get r13ProxiesTitle;

  /// No description provided for @r13ProxiesSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'SOCKS5、HTTP、HTTPS'**
  String get r13ProxiesSubtitle;

  /// No description provided for @r13ProxyCount.
  ///
  /// In zh, this message translates to:
  /// **'已保存的代理 · {count}'**
  String r13ProxyCount(int count);

  /// No description provided for @r13ProxyListFooter.
  ///
  /// In zh, this message translates to:
  /// **'代理只用于您主动发起的 SSH、SFTP 和 TCP 测试，不是系统代理。SOCKS5 由代理解析目标域名（远程 DNS）；HTTP/HTTPS 通过 CONNECT 向代理发送“主机:端口”。密码只保存在设备安全存储中，不会导出或备份。'**
  String get r13ProxyListFooter;

  /// No description provided for @r13ProxyEmpty.
  ///
  /// In zh, this message translates to:
  /// **'还没有代理'**
  String get r13ProxyEmpty;

  /// No description provided for @r13ProxyAdd.
  ///
  /// In zh, this message translates to:
  /// **'添加代理'**
  String get r13ProxyAdd;

  /// No description provided for @r13ProxyEdit.
  ///
  /// In zh, this message translates to:
  /// **'编辑代理'**
  String get r13ProxyEdit;

  /// No description provided for @r13ProxyName.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get r13ProxyName;

  /// No description provided for @r13ProxyNameHint.
  ///
  /// In zh, this message translates to:
  /// **'例如：办公室出口'**
  String get r13ProxyNameHint;

  /// No description provided for @r13ProxyType.
  ///
  /// In zh, this message translates to:
  /// **'类型'**
  String get r13ProxyType;

  /// No description provided for @r13ProxyHost.
  ///
  /// In zh, this message translates to:
  /// **'主机'**
  String get r13ProxyHost;

  /// No description provided for @r13ProxyUsername.
  ///
  /// In zh, this message translates to:
  /// **'用户名（可选）'**
  String get r13ProxyUsername;

  /// No description provided for @r13ProxyPassword.
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get r13ProxyPassword;

  /// No description provided for @r13ProxyKeepPassword.
  ///
  /// In zh, this message translates to:
  /// **'留空则保留已保存的密码。清空用户名会同时删除已保存的密码。'**
  String get r13ProxyKeepPassword;

  /// No description provided for @r13ProxyNameRequired.
  ///
  /// In zh, this message translates to:
  /// **'请填写名称'**
  String get r13ProxyNameRequired;

  /// No description provided for @r13ProxySave.
  ///
  /// In zh, this message translates to:
  /// **'保存代理'**
  String get r13ProxySave;

  /// No description provided for @r13ProxySaved.
  ///
  /// In zh, this message translates to:
  /// **'代理已保存'**
  String get r13ProxySaved;

  /// No description provided for @r13ProxyDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除代理'**
  String get r13ProxyDelete;

  /// No description provided for @r13ProxyDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除此代理？'**
  String get r13ProxyDeleteTitle;

  /// No description provided for @r13ProxyDeleteMessage.
  ///
  /// In zh, this message translates to:
  /// **'代理及其已保存的密码将被删除。'**
  String get r13ProxyDeleteMessage;

  /// No description provided for @r13ProxyDeleted.
  ///
  /// In zh, this message translates to:
  /// **'代理已删除'**
  String get r13ProxyDeleted;

  /// No description provided for @r13ProxyDeleteBlocked.
  ///
  /// In zh, this message translates to:
  /// **'{count} 台服务器的 SSH 配置正在使用此代理。请先改用其他代理或直连，才能删除。'**
  String r13ProxyDeleteBlocked(int count);

  /// No description provided for @r13ProxyDiscardTitle.
  ///
  /// In zh, this message translates to:
  /// **'放弃代理修改？'**
  String get r13ProxyDiscardTitle;

  /// No description provided for @r13ProxyDiscardMessage.
  ///
  /// In zh, this message translates to:
  /// **'未保存的内容将丢失。'**
  String get r13ProxyDiscardMessage;

  /// No description provided for @r13ProxyShowPassword.
  ///
  /// In zh, this message translates to:
  /// **'设备验证后查看已保存的密码'**
  String get r13ProxyShowPassword;

  /// No description provided for @r13ProxyDirect.
  ///
  /// In zh, this message translates to:
  /// **'直连'**
  String get r13ProxyDirect;

  /// No description provided for @r13ProxyDirectSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'不使用代理'**
  String get r13ProxyDirectSubtitle;

  /// No description provided for @r13ProxyNew.
  ///
  /// In zh, this message translates to:
  /// **'新建代理…'**
  String get r13ProxyNew;

  /// No description provided for @r13ProxyChoose.
  ///
  /// In zh, this message translates to:
  /// **'选择代理'**
  String get r13ProxyChoose;

  /// No description provided for @r13ProxyRow.
  ///
  /// In zh, this message translates to:
  /// **'代理'**
  String get r13ProxyRow;

  /// No description provided for @r13ProxyRowFooter.
  ///
  /// In zh, this message translates to:
  /// **'终端和 SFTP 共用同一条 SSH 连接，因此都会经过所选代理。主机公钥仍按目标主机和端口核对。'**
  String get r13ProxyRowFooter;

  /// No description provided for @r13ProxyVia.
  ///
  /// In zh, this message translates to:
  /// **'经 {name}'**
  String r13ProxyVia(String name);

  /// No description provided for @r13TcpEnterProxy.
  ///
  /// In zh, this message translates to:
  /// **'输入代理…'**
  String get r13TcpEnterProxy;

  /// No description provided for @r13TcpProxyFooter.
  ///
  /// In zh, this message translates to:
  /// **'临时代理只用于本次测试，不会保存，密码也不会写入存储。'**
  String get r13TcpProxyFooter;

  /// No description provided for @r13ProxyTemporaryTitle.
  ///
  /// In zh, this message translates to:
  /// **'临时代理'**
  String get r13ProxyTemporaryTitle;

  /// No description provided for @r13ProxyUse.
  ///
  /// In zh, this message translates to:
  /// **'使用此代理'**
  String get r13ProxyUse;

  /// No description provided for @r13TcpRoute.
  ///
  /// In zh, this message translates to:
  /// **'路径'**
  String get r13TcpRoute;

  /// No description provided for @r13TcpRouteVia.
  ///
  /// In zh, this message translates to:
  /// **'经代理 {name}'**
  String r13TcpRouteVia(String name);

  /// No description provided for @r13TcpProxyAddress.
  ///
  /// In zh, this message translates to:
  /// **'代理地址'**
  String get r13TcpProxyAddress;

  /// No description provided for @r13TcpProxyReason.
  ///
  /// In zh, this message translates to:
  /// **'原因'**
  String get r13TcpProxyReason;

  /// No description provided for @r13TcpProxiedNote.
  ///
  /// In zh, this message translates to:
  /// **'代理已连接到目标。这只说明代理能到达目标，不说明本机能直接到达。'**
  String get r13TcpProxiedNote;

  /// No description provided for @r13TcpSourceProxy.
  ///
  /// In zh, this message translates to:
  /// **'本机经代理发起的 TCP 连接测试'**
  String get r13TcpSourceProxy;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
