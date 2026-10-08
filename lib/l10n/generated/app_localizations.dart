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
  /// **'支持简体中文和 English；其他系统语言使用 English。'**
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
  /// **'随设备当前时区。夏令时缺失时间向后顺延，重复时间仅提醒一次；整天被跳过的日期不排程。'**
  String get reminderDstHelp;

  /// No description provided for @myUsagePlan.
  ///
  /// In zh, this message translates to:
  /// **'我的使用计划'**
  String get myUsagePlan;

  /// No description provided for @usagePlanWarning.
  ///
  /// In zh, this message translates to:
  /// **'使用计划只是本地记录。计划到期停用不会停止厂商扣费，请另行向厂商确认取消续费。'**
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
  /// **'读取或校验失败。请选择格式 v1、10 MiB 以内的完整 JSON 台账备份；现有数据未改动。'**
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
  /// **'明文 JSON · 格式 v1'**
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
  /// **'将导入上述台账记录与手动汇率。上方列出的安全资料、备注、提醒和应用偏好均不在备份内。'**
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
  /// **'个人 VPS 台账 · 本地优先'**
  String get appDescription;

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

  /// No description provided for @panelAccounts.
  ///
  /// In zh, this message translates to:
  /// **'面板账户'**
  String get panelAccounts;

  /// No description provided for @panelConnectionCount.
  ///
  /// In zh, this message translates to:
  /// **'SolusVM 1 / 2 · {p0} 个连接'**
  String panelConnectionCount(String p0);

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
  /// **'开发测试版 · 0.1.0'**
  String get developmentVersion;

  /// No description provided for @appLocalDataHelp.
  ///
  /// In zh, this message translates to:
  /// **'数据保存在当前设备，无需应用账号。\n归档记录不会取消服务器服务或停止扣费。'**
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
  /// **'按用途整理服务器。分组变更仅影响本地台账。'**
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
  /// **'归档保留服务器资料和 ID。恢复不会连接云主机，也不会启动或续费服务。'**
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

  /// No description provided for @financeInferredPeriods.
  ///
  /// In zh, this message translates to:
  /// **'部分服务起点由到期日与日历周期反推；不代表历史付款证明。'**
  String get financeInferredPeriods;

  /// No description provided for @financeValueDisclaimer.
  ///
  /// In zh, this message translates to:
  /// **'仅表示服务时长的价格折算，不是退款承诺或成交价。'**
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
  /// **'仅改变参考折算，原币续费价与历史实付保持不变。不会请求实时汇率。留空表示该汇率未知。'**
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
  /// **'CNY 为基准，1 CNY = 1 CNY。同币种换算不需要汇率；跨币种缺汇率时只展示可转换部分及覆盖率。'**
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
  /// **'只复制此刻的续费资料和已知期间。不会修改原服务器。'**
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
  /// **'已切换为独立试算：按当前到期日和周期重新推算服务期，假设到期日前服务连续有效。'**
  String get financeIndependentRebuilt;

  /// No description provided for @financeIndependentNote.
  ///
  /// In zh, this message translates to:
  /// **'独立试算，无需添加服务器。假设到期日前服务连续有效。'**
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
  /// **'试算与记账分离，修改输入不会更改任何服务器或付款。'**
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
  /// **'仅按报价和下方填写的转移手续费试算，不执行交易。其他费用未计入；请自行确认厂商是否允许转让及相关条款。'**
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
  /// **'手续费先折算到显示币种的分，再分摊；不足均分的 0.01 由买方承担。双方手续费之和等于总手续费。'**
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
  /// **'当前记录没有可用的续期日期。请核对预付类型、到期日与支持的日期范围。'**
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
  /// **'独立记录整份账户账单，仅计一次。不要求连接面板账户，不分摊到实例，也不产生服务期或剩余价值。'**
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
  /// **'本次实付独立保存，不覆盖续费金额。目前仅支持整周期续费；厂商含赠送期或到期日不同的，请先核对，不要填写虚构周期。'**
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
  /// **'显示已撤销'**
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
  /// **'已撤销，不计入实付统计'**
  String get financeVoidedStatus;

  /// No description provided for @financeRecordedStatus.
  ///
  /// In zh, this message translates to:
  /// **'已记录'**
  String get financeRecordedStatus;

  /// No description provided for @financePaymentHistoryNote.
  ///
  /// In zh, this message translates to:
  /// **'这是原币历史实付，不随续费价或参考汇率重写。如需更正，可撤销后重新录入；后续资料已改变时可能无法撤销。'**
  String get financePaymentHistoryNote;

  /// No description provided for @financeVoidThisRecord.
  ///
  /// In zh, this message translates to:
  /// **'撤销此次记录'**
  String get financeVoidThisRecord;

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
  /// **'预付续费价摊月 + 按量月估算，不等于本月实付'**
  String get financeMonthlyNotPaid;

  /// No description provided for @financeUpcomingRenewals.
  ///
  /// In zh, this message translates to:
  /// **'未来 30 天预计续费'**
  String get financeUpcomingRenewals;

  /// No description provided for @financeRecentPayments.
  ///
  /// In zh, this message translates to:
  /// **'近 30 天已记录实付'**
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
  /// **'点击分布查看同一口径的服务器明细。费用资料与续费记录均从服务器详情维护。'**
  String get financeDistributionNote;

  /// No description provided for @financeGroupDistributionNote.
  ///
  /// In zh, this message translates to:
  /// **'当前分组不分摊账户级实付。点击分布查看明细。'**
  String get financeGroupDistributionNote;

  /// No description provided for @financeSixMonthTitle.
  ///
  /// In zh, this message translates to:
  /// **'本月起六个月 · 预付续费'**
  String get financeSixMonthTitle;

  /// No description provided for @financeForecastNote.
  ///
  /// In zh, this message translates to:
  /// **'按当前续费价和周期预测本月剩余日期及后五个自然月。假设继续续费，使用计划不改变预测；不包含按量账单或已过期项目。'**
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
  /// **'“—”表示未知或不适用，不代表免费。已知金额为 0 时会显示 0.00。'**
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
  /// **'按量费用在服务器资料中维护月估算，不产生预付续费事件。'**
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
  /// **'仅含金额、日期、周期和参考汇率。图片不含服务器名称、地址、账户、备注或转让报价试算。'**
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
  /// **'保存位置可能是应用私有目录，不等于相册或公开下载目录。移动端可使用系统分享另存；取消分享不会关闭预览。'**
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
  /// **'剩余价值含 {count} 个尚未开始的周期；进度条仅显示上述周期。'**
  String financeFuturePeriodsNote(int count);

  /// No description provided for @financeReferenceServerSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'{billing} · 至 {due}'**
  String financeReferenceServerSubtitle(String billing, String due);

  /// No description provided for @financeReferenceBasis.
  ///
  /// In zh, this message translates to:
  /// **'引用 {name} 的已知期间。修改估值日、金额或币种不会改变已知服务期，也不会修改原服务器。'**
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

  /// No description provided for @financeRoundingNote.
  ///
  /// In zh, this message translates to:
  /// **'{rate}\n{source}。先精确计算，再四舍五入到分；折算结果仅供参考。'**
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
  /// **'从原到期日 {date} 延长，保留当前未用时长。按原续费日推算，并保留月底日期规则。'**
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
  /// **'{count} 笔有效记录，不代表完整历史账单。已撤销记录不计入。'**
  String financeValidPaymentsNote(int count);

  /// No description provided for @financePaymentGroupNote.
  ///
  /// In zh, this message translates to:
  /// **'当前分组：{group}。不分摊账户账单；历史记录保留归档付款。'**
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
  /// **'vps tell you · 试算 · 不入账'**
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
  /// **'SSH 配置、主机信任、面板账户、实例关联与 API 返回信息'**
  String get backupExcludedConnections;

  /// No description provided for @backupExcludedNotes.
  ///
  /// In zh, this message translates to:
  /// **'命令片段、服务器备注和付款备注'**
  String get backupExcludedNotes;

  /// No description provided for @backupExcludedPreferences.
  ///
  /// In zh, this message translates to:
  /// **'提醒规则、通知排程及应用偏好（格式 v1）'**
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

  /// No description provided for @invalidServerName.
  ///
  /// In zh, this message translates to:
  /// **'服务器名称需为 1–80 个字符'**
  String get invalidServerName;

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

  /// Panel accounts: accounts
  ///
  /// In zh, this message translates to:
  /// **'适配器实例'**
  String get cloudAccounts;

  /// Panel accounts: add account
  ///
  /// In zh, this message translates to:
  /// **'添加适配器实例'**
  String get cloudAddAccount;

  /// Panel accounts: panel read badge
  ///
  /// In zh, this message translates to:
  /// **'SolusVM 1 / 2 · 面板读取'**
  String get cloudPanelReadBadge;

  /// Panel accounts: manage connections
  ///
  /// In zh, this message translates to:
  /// **'管理适配器实例与设备关联'**
  String get cloudManageConnections;

  /// Panel accounts: connections info
  ///
  /// In zh, this message translates to:
  /// **'每个适配器实例拥有独立授权与读取范围。\n同一提供商下可添加多个单设备或账户级适配器实例。'**
  String get cloudConnectionsInfo;

  /// Panel accounts: metadata incomplete
  ///
  /// In zh, this message translates to:
  /// **'适配器实例资料未能完整载入，请重新载入后继续。'**
  String get cloudMetadataIncomplete;

  /// Panel accounts: reload metadata
  ///
  /// In zh, this message translates to:
  /// **'重新载入适配器实例资料'**
  String get cloudReloadMetadata;

  /// Panel accounts: cleanup notice
  ///
  /// In zh, this message translates to:
  /// **'待清理的旧授权仍可能留在设备安全存储中。请重试清理；远端授权需到面板撤销。'**
  String get cloudCleanupNotice;

  /// Panel accounts: retry cleanup
  ///
  /// In zh, this message translates to:
  /// **'重试清理旧授权'**
  String get cloudRetryCleanup;

  /// Panel accounts: first account
  ///
  /// In zh, this message translates to:
  /// **'添加首个适配器实例'**
  String get cloudFirstAccount;

  /// Panel accounts: first account info
  ///
  /// In zh, this message translates to:
  /// **'选择适配器类型并验证授权，再核对设备与资源，添加到台账。'**
  String get cloudFirstAccountInfo;

  /// Panel accounts: choose template
  ///
  /// In zh, this message translates to:
  /// **'选择适配器类型'**
  String get cloudChooseTemplate;

  /// Panel accounts: read only boundary
  ///
  /// In zh, this message translates to:
  /// **'本 App 仅使用读取能力，不代表 API 凭据本身只有读取权限。\n适配器实例授权与 SSH 凭据分开管理。解除关联保留台账、费用、付款与 SSH。'**
  String get cloudReadOnlyBoundary;

  /// Panel accounts: template info
  ///
  /// In zh, this message translates to:
  /// **'选择与面板版本匹配的适配器类型。适配器负责读取技术信息，提供商是供应服务器的商家。'**
  String get cloudTemplateInfo;

  /// Panel accounts: v1 template info
  ///
  /// In zh, this message translates to:
  /// **'Client API Key + Hash\n每组凭据只对应单台 VPS'**
  String get cloudV1TemplateInfo;

  /// Panel accounts: v2 template info
  ///
  /// In zh, this message translates to:
  /// **'用户 API Token\n读取当前用户的项目与设备'**
  String get cloudV2TemplateInfo;

  /// Panel accounts: supported panels
  ///
  /// In zh, this message translates to:
  /// **'支持 SolusVM 1 和 SolusVM 2 面板读取。不提供 API 电源控制，也不会修改远端资源或停止服务商计费。'**
  String get cloudSupportedPanels;

  /// Panel accounts: reauthorize
  ///
  /// In zh, this message translates to:
  /// **'重新授权'**
  String get cloudReauthorize;

  /// Panel accounts: single vps api
  ///
  /// In zh, this message translates to:
  /// **'单台 VPS / Client API'**
  String get cloudSingleVpsApi;

  /// Panel accounts: user account api
  ///
  /// In zh, this message translates to:
  /// **'用户账户 / API Token'**
  String get cloudUserAccountApi;

  /// Panel accounts: web preview notice
  ///
  /// In zh, this message translates to:
  /// **'Web 预览不接受真实 API 凭据，请在原生应用中连接。'**
  String get cloudWebPreviewNotice;

  /// Panel accounts: alias label
  ///
  /// In zh, this message translates to:
  /// **'适配器实例名称'**
  String get cloudAliasLabel;

  /// Panel accounts: alias required
  ///
  /// In zh, this message translates to:
  /// **'请输入适配器实例名称'**
  String get cloudAliasRequired;

  /// Panel accounts: endpoint label
  ///
  /// In zh, this message translates to:
  /// **'HTTPS 面板地址'**
  String get cloudEndpointLabel;

  /// Panel accounts: endpoint validation
  ///
  /// In zh, this message translates to:
  /// **'请输入 HTTPS 面板首页地址，不含凭据、参数或 API 路径'**
  String get cloudEndpointValidation;

  /// Panel accounts: endpoint info
  ///
  /// In zh, this message translates to:
  /// **'使用面板首页 HTTPS 地址，可以保留服务商指定端口。不会忽略证书错误或跟随重定向。'**
  String get cloudEndpointInfo;

  /// Panel accounts: endpoint identity info
  ///
  /// In zh, this message translates to:
  /// **'面板地址与连接身份绑定。不同面板请另建连接，旧授权不会显示在此处。'**
  String get cloudEndpointIdentityInfo;

  /// Panel accounts: v1 credentials info
  ///
  /// In zh, this message translates to:
  /// **'填写该 VPS 的 Client API Key / Hash。不是管理员 API 凭据或登录密码；需服务商开放 Client API。每组凭据只读取单台 VPS 的状态。'**
  String get cloudV1CredentialsInfo;

  /// Panel accounts: v2 credentials info
  ///
  /// In zh, this message translates to:
  /// **'使用 SolusVM 2 用户区 Account → API Tokens 的 Token。不要使用管理员 Token；可读取范围取决于服务商设置。'**
  String get cloudV2CredentialsInfo;

  /// Panel accounts: v1 reauthorization info
  ///
  /// In zh, this message translates to:
  /// **'此 API 无法证明新凭据仍属于原 VPS。验证后，必须明确确认解除旧关联，再决定是否导入新记录。旧台账、费用和 SSH 会保留。'**
  String get cloudV1ReauthorizationInfo;

  /// Panel accounts: v2 reauthorization info
  ///
  /// In zh, this message translates to:
  /// **'重新授权必须验证为同一远端用户账户，否则保留原授权与关联。'**
  String get cloudV2ReauthorizationInfo;

  /// Panel accounts: verify scope info
  ///
  /// In zh, this message translates to:
  /// **'本 App 仅使用读取能力，不代表凭据本身只有读取权限。验证会读取状态或项目与设备；只有下一步保存后，授权才进入设备安全存储。'**
  String get cloudVerifyScopeInfo;

  /// Panel accounts: verifying info
  ///
  /// In zh, this message translates to:
  /// **'正在验证并读取完整列表。请求有超时限制；返回或取消会停止本次读取。'**
  String get cloudVerifyingInfo;

  /// Panel accounts: cancel verification
  ///
  /// In zh, this message translates to:
  /// **'取消验证'**
  String get cloudCancelVerification;

  /// Panel accounts: verify read
  ///
  /// In zh, this message translates to:
  /// **'验证并读取'**
  String get cloudVerifyRead;

  /// Panel accounts: credential memory info
  ///
  /// In zh, this message translates to:
  /// **'凭据输入在验证后或离开时清空，不写入台账、日志或导出。Dart 不保证内存安全擦除。'**
  String get cloudCredentialMemoryInfo;

  /// Panel accounts: choose instances
  ///
  /// In zh, this message translates to:
  /// **'选择导入的设备'**
  String get cloudChooseInstances;

  /// Panel accounts: empty verification
  ///
  /// In zh, this message translates to:
  /// **'本次授权未返回可导入的设备。可以仅保存适配器实例，稍后再读取。'**
  String get cloudEmptyVerification;

  /// Panel accounts: empty inventory
  ///
  /// In zh, this message translates to:
  /// **'本次完整读取未返回可导入的设备。适配器实例已保存，可稍后重新读取。'**
  String get cloudEmptyInventory;

  /// Panel accounts: v1 instance
  ///
  /// In zh, this message translates to:
  /// **'该凭据对应的单台 VPS'**
  String get cloudV1Instance;

  /// Panel accounts: already linked
  ///
  /// In zh, this message translates to:
  /// **'已关联 · 不重复导入'**
  String get cloudAlreadyLinked;

  /// Panel accounts: v1 identity
  ///
  /// In zh, this message translates to:
  /// **'无稳定设备 ID · 按此独立授权识别'**
  String get cloudV1Identity;

  /// Panel accounts: ip not provided
  ///
  /// In zh, this message translates to:
  /// **'IP 未提供'**
  String get cloudIpNotProvided;

  /// Panel accounts: select before complete
  ///
  /// In zh, this message translates to:
  /// **'请先勾选上方设备，再补全下方资料。仅填写资料不会导入设备。'**
  String get cloudSelectBeforeComplete;

  /// Panel accounts: local display name
  ///
  /// In zh, this message translates to:
  /// **'本地显示名称（可选）'**
  String get cloudLocalDisplayName;

  /// Panel accounts: local name info
  ///
  /// In zh, this message translates to:
  /// **'仅用于新建本地记录，不作为远端设备标识'**
  String get cloudLocalNameInfo;

  /// Panel accounts: v1 resources info
  ///
  /// In zh, this message translates to:
  /// **'SolusVM 1 不提供稳定设备 ID，可读取的资源字段取决于提供商。填写内容仅保存本地，不会触发 SSH、TCP 或远端配置更改。'**
  String get cloudV1ResourcesInfo;

  /// Panel accounts: rebind warning
  ///
  /// In zh, this message translates to:
  /// **'保存新授权将解除此适配器实例的全部旧设备关联。原有资料、财务与 SSH 设置保留；导入会创建新本地记录，不会覆盖或自动重新关联旧设备。'**
  String get cloudRebindWarning;

  /// Panel accounts: confirm rebind
  ///
  /// In zh, this message translates to:
  /// **'我确认保存新授权将解除旧设备关联'**
  String get cloudConfirmRebind;

  /// Panel accounts: return select
  ///
  /// In zh, this message translates to:
  /// **'返回勾选设备'**
  String get cloudReturnSelect;

  /// Panel accounts: saving
  ///
  /// In zh, this message translates to:
  /// **'正在保存…'**
  String get cloudSaving;

  /// Panel accounts: none selected
  ///
  /// In zh, this message translates to:
  /// **'尚未勾选新设备'**
  String get cloudNoneSelected;

  /// Panel accounts: save only
  ///
  /// In zh, this message translates to:
  /// **'仅保存适配器实例'**
  String get cloudSaveOnly;

  /// Panel accounts: update unlink
  ///
  /// In zh, this message translates to:
  /// **'更新授权并解除旧设备关联'**
  String get cloudUpdateUnlink;

  /// Panel accounts: update only
  ///
  /// In zh, this message translates to:
  /// **'仅更新授权'**
  String get cloudUpdateOnly;

  /// Panel accounts: return verify
  ///
  /// In zh, this message translates to:
  /// **'返回重新验证'**
  String get cloudReturnVerify;

  /// Panel accounts: saving info
  ///
  /// In zh, this message translates to:
  /// **'正在提交到本机，请等待完成后再返回。'**
  String get cloudSavingInfo;

  /// Panel accounts: read importable
  ///
  /// In zh, this message translates to:
  /// **'读取可导入的设备'**
  String get cloudReadImportable;

  /// Panel accounts: refresh account
  ///
  /// In zh, this message translates to:
  /// **'刷新适配器实例状态'**
  String get cloudRefreshAccount;

  /// Panel accounts: reading info
  ///
  /// In zh, this message translates to:
  /// **'正在读取完整列表与状态，有超时限制。取消或返回会停止本次读取，不改变台账、费用或 SSH。'**
  String get cloudReadingInfo;

  /// Panel accounts: cancel read
  ///
  /// In zh, this message translates to:
  /// **'取消读取'**
  String get cloudCancelRead;

  /// Panel accounts: read again
  ///
  /// In zh, this message translates to:
  /// **'重新读取'**
  String get cloudReadAgain;

  /// Panel accounts: read complete info
  ///
  /// In zh, this message translates to:
  /// **'仅更新本适配器实例的 API 观测信息，未覆盖本地资料、费用、付款或 SSH 设置。'**
  String get cloudReadCompleteInfo;

  /// Panel accounts: done
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get cloudDone;

  /// Panel accounts: view details
  ///
  /// In zh, this message translates to:
  /// **'查看适配器实例详情'**
  String get cloudViewDetails;

  /// Panel accounts: rename account
  ///
  /// In zh, this message translates to:
  /// **'编辑适配器实例名称'**
  String get cloudRenameAccount;

  /// Panel accounts: continue import
  ///
  /// In zh, this message translates to:
  /// **'继续导入设备'**
  String get cloudContinueImport;

  /// Panel accounts: linked servers
  ///
  /// In zh, this message translates to:
  /// **'关联服务器'**
  String get cloudLinkedServers;

  /// Panel accounts: unlink account
  ///
  /// In zh, this message translates to:
  /// **'删除适配器实例'**
  String get cloudUnlinkAccount;

  /// Panel accounts: unlink account title
  ///
  /// In zh, this message translates to:
  /// **'删除此适配器实例？'**
  String get cloudUnlinkAccountTitle;

  /// Panel accounts: unlink local
  ///
  /// In zh, this message translates to:
  /// **'仅删除本地适配器实例'**
  String get cloudUnlinkLocal;

  /// Panel accounts: account details
  ///
  /// In zh, this message translates to:
  /// **'适配器实例详情'**
  String get cloudAccountDetails;

  /// Panel accounts: account removed notice
  ///
  /// In zh, this message translates to:
  /// **'适配器实例已删除，全部本地设备记录保留。'**
  String get cloudAccountRemovedNotice;

  /// Panel accounts: template label
  ///
  /// In zh, this message translates to:
  /// **'适配器类型'**
  String get cloudTemplateLabel;

  /// Panel accounts: panel address
  ///
  /// In zh, this message translates to:
  /// **'面板地址'**
  String get cloudPanelAddress;

  /// Panel accounts: read status
  ///
  /// In zh, this message translates to:
  /// **'读取状态'**
  String get cloudReadStatus;

  /// Panel accounts: last attempt
  ///
  /// In zh, this message translates to:
  /// **'最近读取尝试'**
  String get cloudLastAttempt;

  /// Panel accounts: no attempts
  ///
  /// In zh, this message translates to:
  /// **'尚无记录'**
  String get cloudNoAttempts;

  /// Panel accounts: verified scope
  ///
  /// In zh, this message translates to:
  /// **'已验证的读取范围'**
  String get cloudVerifiedScope;

  /// Panel accounts: v1 scope
  ///
  /// In zh, this message translates to:
  /// **'单设备 · Client API，无稳定设备标识'**
  String get cloudV1Scope;

  /// Panel accounts: app capabilities
  ///
  /// In zh, this message translates to:
  /// **'App 能力'**
  String get cloudAppCapabilities;

  /// Panel accounts: read capabilities
  ///
  /// In zh, this message translates to:
  /// **'仅使用读取能力；无 API 电源控制'**
  String get cloudReadCapabilities;

  /// Panel accounts: authorization storage
  ///
  /// In zh, this message translates to:
  /// **'授权存储'**
  String get cloudAuthorizationStorage;

  /// Panel accounts: secure storage info
  ///
  /// In zh, this message translates to:
  /// **'设备安全存储；不显示或导出 API 凭据'**
  String get cloudSecureStorageInfo;

  /// Panel accounts: scope notice
  ///
  /// In zh, this message translates to:
  /// **'API 凭据本身可能拥有更多权限，请在服务商面板核对。没有后台持续监控，读取结果只代表读取时刻。'**
  String get cloudScopeNotice;

  /// Panel accounts: no linked instances
  ///
  /// In zh, this message translates to:
  /// **'暂无关联设备，可从适配器实例菜单继续导入。'**
  String get cloudNoLinkedInstances;

  /// Panel accounts: local record
  ///
  /// In zh, this message translates to:
  /// **'本地记录'**
  String get cloudLocalRecord;

  /// Panel accounts: cancel
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cloudCancel;

  /// Panel accounts: save name
  ///
  /// In zh, this message translates to:
  /// **'保存名称'**
  String get cloudSaveName;

  /// Panel accounts: link panel account
  ///
  /// In zh, this message translates to:
  /// **'关联适配器实例'**
  String get cloudLinkPanelAccount;

  /// Panel accounts: local binding info
  ///
  /// In zh, this message translates to:
  /// **'此页仅使用已保存的 API 观测信息，不连接面板。没有可选设备或上次读取失败时，请先在适配器实例中手动刷新，再返回重新载入本地列表。'**
  String get cloudLocalBindingInfo;

  /// Panel accounts: binding committed
  ///
  /// In zh, this message translates to:
  /// **'关联改动已保存，请先重新读取资料；不要重复提交。'**
  String get cloudBindingCommitted;

  /// Panel accounts: ledger not updated
  ///
  /// In zh, this message translates to:
  /// **'台账显示内容尚未更新，请先重新读取。'**
  String get cloudLedgerNotUpdated;

  /// Panel accounts: reload local
  ///
  /// In zh, this message translates to:
  /// **'重新读取本地列表'**
  String get cloudReloadLocal;

  /// Panel accounts: binding read only
  ///
  /// In zh, this message translates to:
  /// **'已归档或演示记录不能修改面板关联。'**
  String get cloudBindingReadOnly;

  /// Panel accounts: current link
  ///
  /// In zh, this message translates to:
  /// **'当前关联'**
  String get cloudCurrentLink;

  /// Panel accounts: unlink this
  ///
  /// In zh, this message translates to:
  /// **'解除这台关联'**
  String get cloudUnlinkThis;

  /// Panel accounts: select account
  ///
  /// In zh, this message translates to:
  /// **'选择适配器实例'**
  String get cloudSelectAccount;

  /// Panel accounts: no saved accounts
  ///
  /// In zh, this message translates to:
  /// **'此提供商下暂无已确认归属的适配器实例，请先添加并验证。'**
  String get cloudNoSavedAccounts;

  /// Panel accounts: select read instance
  ///
  /// In zh, this message translates to:
  /// **'选择已读取的设备'**
  String get cloudSelectReadInstance;

  /// Panel accounts: no saved instances
  ///
  /// In zh, this message translates to:
  /// **'此适配器实例暂无已保存的设备信息，请先手动刷新。'**
  String get cloudNoSavedInstances;

  /// Panel accounts: other server
  ///
  /// In zh, this message translates to:
  /// **'其他服务器'**
  String get cloudOtherServer;

  /// Panel accounts: missing refresh
  ///
  /// In zh, this message translates to:
  /// **'本次未返回 · 请在适配器实例中手动刷新'**
  String get cloudMissingRefresh;

  /// Panel accounts: failed refresh
  ///
  /// In zh, this message translates to:
  /// **'上次读取失败 · 请在适配器实例中手动刷新'**
  String get cloudFailedRefresh;

  /// Panel accounts: save link
  ///
  /// In zh, this message translates to:
  /// **'保存关联'**
  String get cloudSaveLink;

  /// Panel accounts: change link
  ///
  /// In zh, this message translates to:
  /// **'更换关联'**
  String get cloudChangeLink;

  /// Panel accounts: local link boundary
  ///
  /// In zh, this message translates to:
  /// **'只修改本地关联；服务器资料、硬件、账务及 SSH 保持原样。'**
  String get cloudLocalLinkBoundary;

  /// Panel accounts: single account instance
  ///
  /// In zh, this message translates to:
  /// **'此授权对应的单台设备'**
  String get cloudSingleAccountInstance;

  /// Panel accounts: unlink server title
  ///
  /// In zh, this message translates to:
  /// **'解除这台服务器的面板关联？'**
  String get cloudUnlinkServerTitle;

  /// Panel accounts: change server title
  ///
  /// In zh, this message translates to:
  /// **'更换这台服务器的面板关联？'**
  String get cloudChangeServerTitle;

  /// Panel accounts: only unlink this
  ///
  /// In zh, this message translates to:
  /// **'仅解除这台关联'**
  String get cloudOnlyUnlinkThis;

  /// Panel accounts: confirm change link
  ///
  /// In zh, this message translates to:
  /// **'确认更换关联'**
  String get cloudConfirmChangeLink;

  /// Panel accounts: metadata read failed
  ///
  /// In zh, this message translates to:
  /// **'无法读取适配器实例资料，请重试。'**
  String get cloudMetadataReadFailed;

  /// Panel accounts: saved reload failed
  ///
  /// In zh, this message translates to:
  /// **'已保存，但资料重读失败；请重读后再修改'**
  String get cloudSavedReloadFailed;

  /// Panel accounts: account conflict
  ///
  /// In zh, this message translates to:
  /// **'适配器实例资料已改变，请重新载入后重试。'**
  String get cloudAccountConflict;

  /// Panel accounts: operation failed
  ///
  /// In zh, this message translates to:
  /// **'适配器实例操作未完成，请重试。'**
  String get cloudOperationFailed;

  /// Panel accounts: complete resources
  ///
  /// In zh, this message translates to:
  /// **'请补齐六项硬件信息后导入；未知项目请先向厂商确认'**
  String get cloudCompleteResources;

  /// Panel accounts: cleanup incomplete
  ///
  /// In zh, this message translates to:
  /// **'秘密清理尚未完成，可稍后重试'**
  String get cloudCleanupIncomplete;

  /// Panel accounts: cleanup status failed
  ///
  /// In zh, this message translates to:
  /// **'无法读取清理状态，请重试'**
  String get cloudCleanupStatusFailed;

  /// Panel accounts: verify cancelled
  ///
  /// In zh, this message translates to:
  /// **'验证已取消，未保存授权'**
  String get cloudVerifyCancelled;

  /// Panel accounts: alias invalid
  ///
  /// In zh, this message translates to:
  /// **'适配器实例名称须为 1–80 字。'**
  String get cloudAliasInvalid;

  /// Panel accounts: verify failed
  ///
  /// In zh, this message translates to:
  /// **'验证未完成，请检查面板地址、凭据和网络后重试'**
  String get cloudVerifyFailed;

  /// Panel accounts: verify not saved
  ///
  /// In zh, this message translates to:
  /// **'验证未完成，未保存授权'**
  String get cloudVerifyNotSaved;

  /// Panel accounts: verify again required
  ///
  /// In zh, this message translates to:
  /// **'未保存授权。需要重新验证后再导入。'**
  String get cloudVerifyAgainRequired;

  /// Panel accounts: authorization expired
  ///
  /// In zh, this message translates to:
  /// **'离开应用后已清除本次授权，请返回重新验证。尚未提交的保存已取消。'**
  String get cloudAuthorizationExpired;

  /// Panel accounts: resources incomplete
  ///
  /// In zh, this message translates to:
  /// **'请核对并补齐六项硬件信息；未知项目请先向厂商确认，补齐后再导入。'**
  String get cloudResourcesIncomplete;

  /// Panel accounts: save failed
  ///
  /// In zh, this message translates to:
  /// **'保存未完成，请重试'**
  String get cloudSaveFailed;

  /// Panel accounts: account saved only
  ///
  /// In zh, this message translates to:
  /// **'适配器实例已保存，未导入新设备。'**
  String get cloudAccountSavedOnly;

  /// Panel accounts: instances saved
  ///
  /// In zh, this message translates to:
  /// **'已保存，所选设备已添加到本地台账。'**
  String get cloudInstancesSaved;

  /// Panel accounts: read cancelled
  ///
  /// In zh, this message translates to:
  /// **'读取已取消，保留上次读取的信息'**
  String get cloudReadCancelled;

  /// Panel accounts: account unlinked return
  ///
  /// In zh, this message translates to:
  /// **'适配器实例已删除，请返回后继续。'**
  String get cloudAccountUnlinkedReturn;

  /// Panel accounts: read incomplete
  ///
  /// In zh, this message translates to:
  /// **'读取未完成，保留上次读取的信息'**
  String get cloudReadIncomplete;

  /// Panel accounts: alias saved
  ///
  /// In zh, this message translates to:
  /// **'适配器实例名称已保存。'**
  String get cloudAliasSaved;

  /// Panel accounts: name save failed
  ///
  /// In zh, this message translates to:
  /// **'名称未保存，请重试'**
  String get cloudNameSaveFailed;

  /// Panel accounts: account unlinked
  ///
  /// In zh, this message translates to:
  /// **'适配器实例已删除。本地资料、财务与 SSH 设置保留。'**
  String get cloudAccountUnlinked;

  /// Panel accounts: unlink failed
  ///
  /// In zh, this message translates to:
  /// **'删除适配器实例未完成，请重试。'**
  String get cloudUnlinkFailed;

  /// Panel accounts: alias range
  ///
  /// In zh, this message translates to:
  /// **'请输入 1–80 字的适配器实例名称。'**
  String get cloudAliasRange;

  /// Panel accounts: binding read failed
  ///
  /// In zh, this message translates to:
  /// **'无法读取本地关联资料，请重试'**
  String get cloudBindingReadFailed;

  /// Panel accounts: server unlinked
  ///
  /// In zh, this message translates to:
  /// **'已解除这台服务器的面板关联'**
  String get cloudServerUnlinked;

  /// Panel accounts: binding saved
  ///
  /// In zh, this message translates to:
  /// **'适配器实例关联已保存。'**
  String get cloudBindingSaved;

  /// Panel accounts: failure invalid endpoint
  ///
  /// In zh, this message translates to:
  /// **'请输入 HTTPS 面板首页地址，不含登录信息、查询参数或 API 路径'**
  String get cloudFailureInvalidEndpoint;

  /// Panel accounts: failure invalid credentials
  ///
  /// In zh, this message translates to:
  /// **'请填写该模板对应的有效 API 凭据'**
  String get cloudFailureInvalidCredentials;

  /// Panel accounts: failure unauthorized
  ///
  /// In zh, this message translates to:
  /// **'API 凭据未通过验证，请检查凭据或重新授权'**
  String get cloudFailureUnauthorized;

  /// Panel accounts: failure api rejected
  ///
  /// In zh, this message translates to:
  /// **'面板拒绝 API 读取，请检查凭据、API 开放情况与服务状态'**
  String get cloudFailureApiRejected;

  /// Panel accounts: failure forbidden
  ///
  /// In zh, this message translates to:
  /// **'面板拒绝读取，请检查 API 权限与服务商设置'**
  String get cloudFailureForbidden;

  /// Panel accounts: failure rate limited
  ///
  /// In zh, this message translates to:
  /// **'面板请求过于频繁，请稍后手动重试'**
  String get cloudFailureRateLimited;

  /// Panel accounts: failure unavailable
  ///
  /// In zh, this message translates to:
  /// **'面板暂时无法提供 API 读取服务'**
  String get cloudFailureUnavailable;

  /// Panel accounts: failure connection
  ///
  /// In zh, this message translates to:
  /// **'连接失败，请检查网络、面板地址与 HTTPS 证书'**
  String get cloudFailureConnection;

  /// Panel accounts: failure timeout
  ///
  /// In zh, this message translates to:
  /// **'读取超时，保留上次读取的信息；请稍后重试'**
  String get cloudFailureTimeout;

  /// Panel accounts: failure cancelled
  ///
  /// In zh, this message translates to:
  /// **'读取已取消'**
  String get cloudFailureCancelled;

  /// Panel accounts: failure redirect
  ///
  /// In zh, this message translates to:
  /// **'面板返回重定向，已停止以保护凭据；请核对面板地址'**
  String get cloudFailureRedirect;

  /// Panel accounts: failure invalid response
  ///
  /// In zh, this message translates to:
  /// **'面板响应不符合读取协议，未更新本地资料'**
  String get cloudFailureInvalidResponse;

  /// Panel accounts: failure response too large
  ///
  /// In zh, this message translates to:
  /// **'面板响应超过安全大小限制'**
  String get cloudFailureResponseTooLarge;

  /// Panel accounts: failure inventory too large
  ///
  /// In zh, this message translates to:
  /// **'设备或分页数量超过本次读取限制，未导入不完整列表'**
  String get cloudFailureInventoryTooLarge;

  /// Panel accounts: failure unsupported platform
  ///
  /// In zh, this message translates to:
  /// **'此预览平台不接受真实 API 凭据，请使用原生应用'**
  String get cloudFailureUnsupportedPlatform;

  /// Panel accounts: account failure identity
  ///
  /// In zh, this message translates to:
  /// **'远端账户或设备标识发生变化，原有关联未改动。请建立独立的适配器实例。'**
  String get cloudAccountFailureIdentity;

  /// Panel accounts: account failure v1 rebind
  ///
  /// In zh, this message translates to:
  /// **'SolusVM 1 无法证明新凭据仍对应原设备。请明确确认解除旧关联，再选择导入的设备。原有本地记录保留。'**
  String get cloudAccountFailureV1Rebind;

  /// Panel accounts: account failure selection
  ///
  /// In zh, this message translates to:
  /// **'导入列表已变化或选择无效，请重新读取'**
  String get cloudAccountFailureSelection;

  /// Panel accounts: account failure alias
  ///
  /// In zh, this message translates to:
  /// **'适配器实例名称须为 1–80 字。'**
  String get cloudAccountFailureAlias;

  /// Panel accounts: account failure secret
  ///
  /// In zh, this message translates to:
  /// **'API 凭据未能保存到设备安全存储，原授权保持不变；请解锁设备后重试'**
  String get cloudAccountFailureSecret;

  /// Panel accounts: account failure secret read
  ///
  /// In zh, this message translates to:
  /// **'无法读取此适配器实例保存的 API 凭据。请解锁设备后重试；仍失败时可从菜单重新授权。'**
  String get cloudAccountFailureSecretRead;

  /// Panel accounts: account failure binding taken
  ///
  /// In zh, this message translates to:
  /// **'此设备已关联其他本地服务器，不能覆盖。请重新载入本地列表。'**
  String get cloudAccountFailureBindingTaken;

  /// Panel accounts: account failure binding unavailable
  ///
  /// In zh, this message translates to:
  /// **'设备信息暂不可用于关联，请先手动刷新适配器实例后重新选择。'**
  String get cloudAccountFailureBindingUnavailable;

  /// Panel accounts: read limit positive
  ///
  /// In zh, this message translates to:
  /// **'读取限制必须大于 0'**
  String get cloudReadLimitPositive;

  /// Panel accounts: provider links
  ///
  /// In zh, this message translates to:
  /// **'{provider} · {count} 台关联'**
  String cloudProviderLinks(String provider, int count);

  /// Panel accounts: required field
  ///
  /// In zh, this message translates to:
  /// **'请填写 {label}'**
  String cloudRequiredField(String label);

  /// Panel accounts: connect provider
  ///
  /// In zh, this message translates to:
  /// **'连接 {provider}'**
  String cloudConnectProvider(String provider);

  /// Panel accounts: verify target
  ///
  /// In zh, this message translates to:
  /// **'{normalization}验证将连接：{origin}'**
  String cloudVerifyTarget(String normalization, String origin);

  /// Panel accounts: inventory complete
  ///
  /// In zh, this message translates to:
  /// **'完整读取完成 · {count} 台设备\n读取时间：{time}{authorization}'**
  String cloudInventoryComplete(int count, String time, String authorization);

  /// Panel accounts: instance fallback
  ///
  /// In zh, this message translates to:
  /// **'设备 {id}'**
  String cloudInstanceFallback(String id);

  /// Panel accounts: project instance
  ///
  /// In zh, this message translates to:
  /// **'项目 {project} · 设备 ID {id}'**
  String cloudProjectInstance(String project, String id);

  /// Panel accounts: power last read
  ///
  /// In zh, this message translates to:
  /// **'电源{power} · 上次读取'**
  String cloudPowerLastRead(String power);

  /// Panel accounts: import boundary
  ///
  /// In zh, this message translates to:
  /// **'导入不会覆盖已有本地名称、费用、付款、备注或 SSH 配置。{deduplication}已归档的关联也不会重复导入。'**
  String cloudImportBoundary(String deduplication);

  /// Panel accounts: v2 scope
  ///
  /// In zh, this message translates to:
  /// **'已验证用户账户 {id} · 项目与设备'**
  String cloudV2Scope(String id);

  /// Panel accounts: linked count
  ///
  /// In zh, this message translates to:
  /// **'已关联 {count} 台'**
  String cloudLinkedCount(int count);

  /// Panel accounts: record with state
  ///
  /// In zh, this message translates to:
  /// **'{name}{state}'**
  String cloudRecordWithState(String name, String state);

  /// Panel accounts: binding with time
  ///
  /// In zh, this message translates to:
  /// **'{summary}\n读取时间：{time}'**
  String cloudBindingWithTime(String summary, String time);

  /// Panel accounts: console path removed
  ///
  /// In zh, this message translates to:
  /// **'已移除 /home.php。\n'**
  String get cloudConsolePathRemoved;

  /// Panel accounts: authorization unsaved
  ///
  /// In zh, this message translates to:
  /// **'\n尚未保存这次授权'**
  String get cloudAuthorizationUnsaved;

  /// Panel accounts: v1 deduplication
  ///
  /// In zh, this message translates to:
  /// **'此授权已固定的设备不会再次创建；解除关联不会解除固定。独立授权之间不会自动合并。'**
  String get cloudV1Deduplication;

  /// Panel accounts: v2 deduplication
  ///
  /// In zh, this message translates to:
  /// **'以适配器类型、面板地址、远端账户、项目与设备 ID 确认重复。IP 或主机名相同仅作核对提示。'**
  String get cloudV2Deduplication;

  /// Panel accounts: archived suffix
  ///
  /// In zh, this message translates to:
  /// **' · 已归档'**
  String get cloudArchivedSuffix;

  /// Panel accounts: import count
  ///
  /// In zh, this message translates to:
  /// **'导入 {count} 台设备'**
  String cloudImportCount(int count);

  /// Panel accounts: save import count
  ///
  /// In zh, this message translates to:
  /// **'保存适配器实例并导入 {count} 台设备'**
  String cloudSaveImportCount(int count);

  /// Panel accounts: unlink account message
  ///
  /// In zh, this message translates to:
  /// **'{alias}\n\n删除此本地适配器实例及其设备关联。重新添加需要再次输入 API 凭据。不会删除远端设备或停止计费。\n\n{remoteAction}'**
  String cloudUnlinkAccountMessage(String alias, String remoteAction);

  /// Panel accounts: revoke v1
  ///
  /// In zh, this message translates to:
  /// **'还需到面板禁用该 VPS 的 Client API 或重置 Key / Hash。'**
  String get cloudRevokeV1;

  /// Panel accounts: revoke v2
  ///
  /// In zh, this message translates to:
  /// **'还需到面板撤销已签发的 Token。'**
  String get cloudRevokeV2;

  /// Panel accounts: suggested alias
  ///
  /// In zh, this message translates to:
  /// **'我的 {provider} 适配器'**
  String cloudSuggestedAlias(String provider);

  /// Panel accounts: read at
  ///
  /// In zh, this message translates to:
  /// **'读取时间：{time}'**
  String cloudReadAt(String time);

  /// Panel accounts: already linked to
  ///
  /// In zh, this message translates to:
  /// **'已关联：{name} · 不可覆盖'**
  String cloudAlreadyLinkedTo(String name);

  /// Panel accounts: change link message
  ///
  /// In zh, this message translates to:
  /// **'{server}\n当前：{account} · {instance}{replacement}\n\n仅修改本地关联，保留服务器资料、硬件、费用、付款、SSH、适配器实例及授权。不会操作远端设备或停止扣费。'**
  String cloudChangeLinkMessage(
    String server,
    String account,
    String instance,
    String replacement,
  );

  /// Panel accounts: replacement link
  ///
  /// In zh, this message translates to:
  /// **'\n更换为：{account} · {instance}'**
  String cloudReplacementLink(String account, String instance);

  /// Panel accounts: power running
  ///
  /// In zh, this message translates to:
  /// **'运行中'**
  String get cloudPowerRunning;

  /// Panel accounts: power stopped
  ///
  /// In zh, this message translates to:
  /// **'已停止'**
  String get cloudPowerStopped;

  /// Panel accounts: power unknown
  ///
  /// In zh, this message translates to:
  /// **'未知'**
  String get cloudPowerUnknown;

  /// Panel accounts: missing kept
  ///
  /// In zh, this message translates to:
  /// **'本次未返回 · 保留上次信息'**
  String get cloudMissingKept;

  /// Panel accounts: failed kept
  ///
  /// In zh, this message translates to:
  /// **'读取失败 · 保留上次信息'**
  String get cloudFailedKept;

  /// Panel accounts: last read
  ///
  /// In zh, this message translates to:
  /// **'上次读取'**
  String get cloudLastRead;

  /// Panel accounts: authorization failed kept
  ///
  /// In zh, this message translates to:
  /// **'授权验证失败 · 原台账保留'**
  String get cloudAuthorizationFailedKept;

  /// Panel accounts: verified manual
  ///
  /// In zh, this message translates to:
  /// **'已验证 · 手动读取'**
  String get cloudVerifiedManual;

  /// Panel accounts: step template
  ///
  /// In zh, this message translates to:
  /// **'适配器类型'**
  String get cloudStepTemplate;

  /// Panel accounts: step credentials
  ///
  /// In zh, this message translates to:
  /// **'填授权'**
  String get cloudStepCredentials;

  /// Panel accounts: step instances
  ///
  /// In zh, this message translates to:
  /// **'设备'**
  String get cloudStepInstances;

  /// Panel accounts: api unknown
  ///
  /// In zh, this message translates to:
  /// **'未知（API 未提供）'**
  String get cloudApiUnknown;

  /// Panel accounts: binding summary
  ///
  /// In zh, this message translates to:
  /// **'{freshness} · 电源{power}'**
  String cloudBindingSummary(String freshness, String power);

  /// Panel accounts: step label
  ///
  /// In zh, this message translates to:
  /// **'0{number} {label}'**
  String cloudStepLabel(int number, String label);

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

  /// No description provided for @resourceInvalidSources.
  ///
  /// In zh, this message translates to:
  /// **'资源来源字段无效'**
  String get resourceInvalidSources;

  /// No description provided for @resourceUnknownApiSource.
  ///
  /// In zh, this message translates to:
  /// **'未知资源不能标记为 API 来源'**
  String get resourceUnknownApiSource;

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

  /// No description provided for @resourceInvalidSourceFields.
  ///
  /// In zh, this message translates to:
  /// **'本地资源来源字段无效'**
  String get resourceInvalidSourceFields;

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

  /// No description provided for @resourceSourceManual.
  ///
  /// In zh, this message translates to:
  /// **'来源：手动填写'**
  String get resourceSourceManual;

  /// No description provided for @resourceSourceApi.
  ///
  /// In zh, this message translates to:
  /// **'来源：API'**
  String get resourceSourceApi;

  /// No description provided for @resourceSourceUnlimited.
  ///
  /// In zh, this message translates to:
  /// **'来源：手动确认不限量'**
  String get resourceSourceUnlimited;

  /// No description provided for @resourceSourceMissing.
  ///
  /// In zh, this message translates to:
  /// **'待补填：API 未提供有效值'**
  String get resourceSourceMissing;

  /// No description provided for @resourceSourceCompleted.
  ///
  /// In zh, this message translates to:
  /// **'来源：手动补填'**
  String get resourceSourceCompleted;

  /// No description provided for @resourceSourceEditedApi.
  ///
  /// In zh, this message translates to:
  /// **'来源：手动修改 API 预填值'**
  String get resourceSourceEditedApi;

  /// No description provided for @resourceFieldValidIp.
  ///
  /// In zh, this message translates to:
  /// **'请填写有效 IPv4 或 IPv6，不能为全零地址'**
  String get resourceFieldValidIp;

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
  /// **'新建默认按月，请按套餐确认；也可选“未设置”。'**
  String get resourceNewPeriodHelp;

  /// No description provided for @resourcePeriodHelp.
  ///
  /// In zh, this message translates to:
  /// **'周期独立于容量单位；未知选“未设置”。'**
  String get resourcePeriodHelp;

  /// No description provided for @resourceSixRequired.
  ///
  /// In zh, this message translates to:
  /// **'硬件信息 · 六项必填'**
  String get resourceSixRequired;

  /// No description provided for @resourceHardware.
  ///
  /// In zh, this message translates to:
  /// **'硬件信息'**
  String get resourceHardware;

  /// No description provided for @resourceImportHelp.
  ///
  /// In zh, this message translates to:
  /// **'核对并补齐六项后导入；容量按 1024 进制，0 不代表不限量。资料不全时可暂不选择此实例，待补齐后再导入。'**
  String get resourceImportHelp;

  /// No description provided for @resourceLocalHelp.
  ///
  /// In zh, this message translates to:
  /// **'未知可留空，容量按 1024 进制。仅维护本地硬件，API 刷新不会覆盖，也不更改远端配置或 SSH 地址。'**
  String get resourceLocalHelp;

  /// No description provided for @resourceIpAddress.
  ///
  /// In zh, this message translates to:
  /// **'IP 地址'**
  String get resourceIpAddress;

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
  /// **'仅在套餐明确不限量时开启；未知或 API 返回 0 请保持关闭。'**
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

  /// No description provided for @serverImportPanel.
  ///
  /// In zh, this message translates to:
  /// **'从面板账户导入'**
  String get serverImportPanel;

  /// No description provided for @serverFirstTitle.
  ///
  /// In zh, this message translates to:
  /// **'你的第一台 VPS，\n从这里开始'**
  String get serverFirstTitle;

  /// No description provided for @serverFirstDescription.
  ///
  /// In zh, this message translates to:
  /// **'把机器、费用和连接放在一起。\n无需安装监控程序，也可直接手动记录。'**
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
  /// **'将写入 4 条带“演示”标记的本地记录，地址均为保留地址。不会连接服务器。可在各服务器详情中归档这些记录。'**
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

  /// No description provided for @serverClearFilters.
  ///
  /// In zh, this message translates to:
  /// **'清除筛选'**
  String get serverClearFilters;

  /// No description provided for @serverListObservationHelp.
  ///
  /// In zh, this message translates to:
  /// **'显示本地资料和最近一次面板查询结果，不持续监控。\n到期天数按设备日期计算；未来 30 天包含今天及后 29 天。'**
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
  /// **'仅保存本地硬件资料，面板刷新不会覆盖。未填写的项目可稍后补充。'**
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

  /// No description provided for @serverCopyHost.
  ///
  /// In zh, this message translates to:
  /// **'复制主机地址'**
  String get serverCopyHost;

  /// No description provided for @serverHostCopied.
  ///
  /// In zh, this message translates to:
  /// **'主机地址已复制'**
  String get serverHostCopied;

  /// No description provided for @serverCopyHostFailed.
  ///
  /// In zh, this message translates to:
  /// **'未能复制主机地址，请重试。'**
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

  /// No description provided for @serverLocalInfoHelp.
  ///
  /// In zh, this message translates to:
  /// **'以上是本地资料，面板刷新不会覆盖。连接测试结果不代表服务持续可用。'**
  String get serverLocalInfoHelp;

  /// No description provided for @serverEditHardware.
  ///
  /// In zh, this message translates to:
  /// **'编辑硬件'**
  String get serverEditHardware;

  /// No description provided for @serverPanelLink.
  ///
  /// In zh, this message translates to:
  /// **'面板关联'**
  String get serverPanelLink;

  /// No description provided for @serverNoPanelLink.
  ///
  /// In zh, this message translates to:
  /// **'未关联面板账户'**
  String get serverNoPanelLink;

  /// No description provided for @serverPanelLinkHelp.
  ///
  /// In zh, this message translates to:
  /// **'关联已保存的面板账户与实例。关联或刷新均不会更改本地硬件信息，请在上方手动编辑。'**
  String get serverPanelLinkHelp;

  /// No description provided for @serverLinkPanel.
  ///
  /// In zh, this message translates to:
  /// **'关联面板账户'**
  String get serverLinkPanel;

  /// No description provided for @serverManageLink.
  ///
  /// In zh, this message translates to:
  /// **'管理关联'**
  String get serverManageLink;

  /// No description provided for @serverReloadPanelDetails.
  ///
  /// In zh, this message translates to:
  /// **'重新读取面板账户资料'**
  String get serverReloadPanelDetails;

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
  /// **'未知金额不会按 0 计算。可在“基本信息 / 编辑”中补充费用资料。'**
  String get serverUnknownCostHelp;

  /// No description provided for @serverMeteredValueHelp.
  ///
  /// In zh, this message translates to:
  /// **'按量费用作为月估算，不产生剩余价值。可在编辑服务器时维护费用资料。'**
  String get serverMeteredValueHelp;

  /// No description provided for @serverRenewalValueHelp.
  ///
  /// In zh, this message translates to:
  /// **'按当前续费价折算已知服务期；历史实付另计，不覆盖续费价。'**
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
  /// **'首次连接需核对主机指纹；指纹变化会暂停登录。重启或关机需再次核对目标，且不会停止厂商计费。'**
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

  /// No description provided for @serverPlainHost.
  ///
  /// In zh, this message translates to:
  /// **'请输入纯 IP 或域名，不含协议、端口或路径'**
  String get serverPlainHost;

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

  /// No description provided for @serverManualAdd.
  ///
  /// In zh, this message translates to:
  /// **'手动添加'**
  String get serverManualAdd;

  /// No description provided for @serverEditTitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑服务器'**
  String get serverEditTitle;

  /// No description provided for @serverFormHelp.
  ///
  /// In zh, this message translates to:
  /// **'名称和厂商必填；硬件和费用可稍后补充。仅保存本地台账，不修改远端。'**
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

  /// No description provided for @serverOptionalHost.
  ///
  /// In zh, this message translates to:
  /// **'主机地址（选填）'**
  String get serverOptionalHost;

  /// No description provided for @serverHostExample.
  ///
  /// In zh, this message translates to:
  /// **'IPv4、IPv6 或域名，不含协议或端口'**
  String get serverHostExample;

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
  /// **'存在续费生成的服务期时，计费方式、周期和日期不可直接修改。请在付款详情核对可撤销范围；后续资料已改变时可能无法撤销。续费价和币种仍可调整，历史实付不变。'**
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
  /// **'日期选填，到期当天不计入服务期。只填到期日期时，会按续费周期推算开始日期；未填到期日期则无法计算剩余价值。'**
  String get serverDatesHelp;

  /// No description provided for @serverAmountHelp.
  ///
  /// In zh, this message translates to:
  /// **'金额填 0 表示免费；金额未知请选择“费用未知”。按所选币种保存，参考汇率仅用于折算。保存费用不会记录付款。'**
  String get serverAmountHelp;

  /// No description provided for @serverOptionalNotes.
  ///
  /// In zh, this message translates to:
  /// **'备注（选填）'**
  String get serverOptionalNotes;

  /// No description provided for @serverNotesSafety.
  ///
  /// In zh, this message translates to:
  /// **'不要在备注中保存密码、私钥或令牌；登录凭据请在“密钥与安全”管理。'**
  String get serverNotesSafety;

  /// No description provided for @serverSave.
  ///
  /// In zh, this message translates to:
  /// **'保存服务器'**
  String get serverSave;

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
  /// **'从当前设备测试一个地址和端口，仅建立并关闭 TCP 连接，不发送应用数据。成功不代表 SSH 可登录、服务器开机状态或业务健康。'**
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
  /// **'连接后才能选择重启 / 关机，并再次完成两次确认。没有 SSH 开机或 API 电源功能。'**
  String get connectionPowerAfterConnect;

  /// No description provided for @connectionReviewConnect.
  ///
  /// In zh, this message translates to:
  /// **'核对并连接'**
  String get connectionReviewConnect;

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
  /// **'选择后先预览完整内容，只插入待发送草稿。不会自动发送或回车。'**
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
  /// **'本地普通文本，不加密保存。请勿填写密码、私钥或令牌。保存不会执行或发送内容。'**
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
  /// **'保存会原样保留内容，包括前后空白、多行、回车及控制字符。请使用完整预览核对。'**
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
  /// **'离开或进入后台会断开会话；不会自动重连或重放输入。长任务建议在远端使用 tmux / screen。'**
  String get terminalBackgroundHelp;

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
  /// **'应用进入后台，连接已清理。需要手动重连，不会重放输入。'**
  String get terminalBackgroundDisconnected;

  /// No description provided for @terminalTargetChanged.
  ///
  /// In zh, this message translates to:
  /// **'目标已变化，连接和草稿已清空。请手动连接新目标。'**
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
  /// **'这是私钥解密口令，不是服务器登录密码。仅用于本次连接，不会保存；下次连接需重新输入。'**
  String get terminalPassphraseHelp;

  /// No description provided for @terminalKeyPassphrase.
  ///
  /// In zh, this message translates to:
  /// **'本次私钥口令'**
  String get terminalKeyPassphrase;

  /// No description provided for @terminalPassphraseCleared.
  ///
  /// In zh, this message translates to:
  /// **'连接已取消或页面进入后台，口令已清空。请取消并重新连接。'**
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
  /// **'凭据独立管理，连接只引用凭据。秘密仅保存在系统安全存储中。'**
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
  /// **'修改本地凭据不会修改远端密码或 authorized_keys。只有明确发起连接才会使用所选凭据。'**
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
  /// **'支持 OpenSSH / PEM 私钥。只读取所选文件，不保存文件路径。也可用“粘贴完整私钥”保留换行；内容始终隐藏。'**
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
  /// **'用于解密所选私钥，不是服务器登录密码。本页不会更改私钥的加密口令'**
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
  /// **'用户名只作为新连接的候选值，不覆盖已有连接。更新凭据只影响以后登录，不修改服务器端密码或密钥。离开到后台会清空未保存秘密。'**
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
  /// **'这里不展示或导出私钥。公钥指纹用于辨认登录密钥，与服务器主机指纹不同。'**
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
  /// **'{count} 台引用此凭据，包含已归档记录。连接用户名分别保存。'**
  String securityCredentialReferenceCount(int count);

  /// Security: NoCredentialReferences. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'尚未关联。可在服务器详情的 SSH 配置中选择。'**
  String get securityNoCredentialReferences;

  /// Security: CredentialDeleteImpact. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'{count} 台服务器将受影响，包含归档记录。请核对下面的每一项。'**
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
  /// **'仅删除本机凭据，不能从本页面恢复。不修改远端密码或 authorized_keys，不取消云服务。'**
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
  /// **'信任绑定主机地址和端口，并记录算法及完整公钥。登录凭据与服务器主机公钥是两件事。'**
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
  /// **'输入从厂商控制台或管理员等独立可信渠道取得的主机公钥。此页面只校验输入内容并保存本机信任，不会连接服务器。'**
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
  /// **'rsa-sha2-256 / rsa-sha2-512 是签名算法，其 RSA 公钥类型选择 ssh-rsa。只支持结构完整的受支持主机公钥。'**
  String get securityRsaHostKeyNotice;

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
  /// **'请通过独立渠道核对完整指纹和目标地址。变化可能来自重装，也可能是错误主机或中间人攻击。无法确认时应拒绝。'**
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

  /// Security: SavingHostTrust. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'正在保存已确认的信任。完成前暂时不能返回。'**
  String get securitySavingHostTrust;

  /// Security: LocalHostTrustOnly. App-authored UI text; do not translate user data or protocol tokens.
  ///
  /// In zh, this message translates to:
  /// **'只记录本机信任，当前不会连接服务器。拒绝、取消和返回均不保存，也不发送认证资料。'**
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
  /// **'此页只保存连接配置。建立连接时先核验主机身份，再进行登录认证；主机公钥变化时会暂停认证，等待重新核实。'**
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
  /// **'请先确认此实例的提供商归属，再添加授权、导入或关联服务器。'**
  String get providerReviewRequired;

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

  /// Provider and adapter relationship validation.
  ///
  /// In zh, this message translates to:
  /// **'更改提供商前，请确认解除原适配器关联。'**
  String get providerChangeNeedsUnlink;

  /// Provider and adapter relationship validation.
  ///
  /// In zh, this message translates to:
  /// **'服务器与适配器实例必须属于同一提供商。'**
  String get adapterProviderMismatch;

  /// Provider and adapter relationship validation.
  ///
  /// In zh, this message translates to:
  /// **'此实例的授权范围尚未确认，不能新增关联。'**
  String get adapterScopeUnavailable;

  /// Provider and adapter relationship validation.
  ///
  /// In zh, this message translates to:
  /// **'这组单机凭据已确认用于另一条服务器记录；解绑不会释放其授权范围。请回到原记录，或单独重新授权。'**
  String get adapterSingletonPinned;

  /// Provider navigation and ownership UI.
  ///
  /// In zh, this message translates to:
  /// **'提供商管理'**
  String get providerUiTitle;

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
  /// **'仅手动添加，可稍后在服务器详情中指定归属。'**
  String get providerUiUnspecifiedHelp;

  /// Provider navigation and ownership UI.
  ///
  /// In zh, this message translates to:
  /// **'提供商是服务器的业务归属；适配器实例保存一份独立授权，只能读取该授权范围内的设备。'**
  String get providerUiHierarchyHelp;

  /// Provider navigation and ownership UI.
  ///
  /// In zh, this message translates to:
  /// **'{instances} 个适配器实例 · {devices} 台服务器'**
  String providerUiSummary(int instances, int devices);

  /// Provider navigation and ownership UI.
  ///
  /// In zh, this message translates to:
  /// **'还没有提供商'**
  String get providerUiEmpty;

  /// Provider navigation and ownership UI.
  ///
  /// In zh, this message translates to:
  /// **'先记录提供商名称，再手动添加服务器或配置只读适配器。'**
  String get providerUiEmptyHelp;

  /// Provider navigation and ownership UI.
  ///
  /// In zh, this message translates to:
  /// **'归属待确认，暂不能新增授权或关联'**
  String get providerUiNeedsReview;

  /// Provider navigation and ownership UI.
  ///
  /// In zh, this message translates to:
  /// **'{count} 台服务器尚未指定提供商。'**
  String providerUiUnspecifiedCount(int count);

  /// Provider navigation and ownership UI.
  ///
  /// In zh, this message translates to:
  /// **'选择提供商'**
  String get providerUiChoose;

  /// Provider navigation and ownership UI.
  ///
  /// In zh, this message translates to:
  /// **'选择业务提供商。面板类型与授权将在后续步骤选择。'**
  String get providerUiChooseHelp;

  /// Provider navigation and ownership UI.
  ///
  /// In zh, this message translates to:
  /// **'服务器归属'**
  String get providerUiSelected;

  /// Provider navigation and ownership UI.
  ///
  /// In zh, this message translates to:
  /// **'重新选择提供商'**
  String get providerUiChooseAnother;

  /// Provider navigation and ownership UI.
  ///
  /// In zh, this message translates to:
  /// **'选择添加方式'**
  String get providerUiChooseMethod;

  /// Provider navigation and ownership UI.
  ///
  /// In zh, this message translates to:
  /// **'手动填写资料。六项硬件和费用未知时可以留空。'**
  String get providerUiManualHelp;

  /// Provider navigation and ownership UI.
  ///
  /// In zh, this message translates to:
  /// **'通过适配器读取'**
  String get providerUiAutomatic;

  /// Provider navigation and ownership UI.
  ///
  /// In zh, this message translates to:
  /// **'选择现有授权或新增适配器，读取后确认导入。'**
  String get providerUiAutomaticHelp;

  /// Provider navigation and ownership UI.
  ///
  /// In zh, this message translates to:
  /// **'自动读取前，需要选择已确认的提供商。'**
  String get providerUiAutoNeedsProvider;

  /// Provider navigation and ownership UI.
  ///
  /// In zh, this message translates to:
  /// **'适配器实例'**
  String get providerUiInstances;

  /// Provider navigation and ownership UI.
  ///
  /// In zh, this message translates to:
  /// **'尚未配置适配器；仍可手动添加服务器。'**
  String get providerUiNoInstances;

  /// Provider navigation and ownership UI.
  ///
  /// In zh, this message translates to:
  /// **'新增适配器实例'**
  String get providerUiAddInstance;

  /// Provider navigation and ownership UI.
  ///
  /// In zh, this message translates to:
  /// **'名下服务器'**
  String get providerUiDevices;

  /// Provider navigation and ownership UI.
  ///
  /// In zh, this message translates to:
  /// **'这个提供商下还没有服务器。'**
  String get providerUiNoDevices;

  /// Provider navigation and ownership UI.
  ///
  /// In zh, this message translates to:
  /// **'无适配器关联'**
  String get providerUiManualDevice;

  /// Provider navigation and ownership UI.
  ///
  /// In zh, this message translates to:
  /// **'已关联适配器'**
  String get providerUiLinkedDevice;

  /// Provider navigation and ownership UI.
  ///
  /// In zh, this message translates to:
  /// **'已关联 {count} 台服务器'**
  String providerUiLinkedCount(int count);

  /// Provider navigation and ownership UI.
  ///
  /// In zh, this message translates to:
  /// **'单台设备授权'**
  String get providerUiSingleScope;

  /// Provider navigation and ownership UI.
  ///
  /// In zh, this message translates to:
  /// **'账户范围授权'**
  String get providerUiAccountScope;

  /// Provider navigation and ownership UI.
  ///
  /// In zh, this message translates to:
  /// **'授权范围未确认'**
  String get providerUiUnknownScope;

  /// Provider navigation and ownership UI.
  ///
  /// In zh, this message translates to:
  /// **'这份单台授权已固定到「{name}」。即使解除关联，也不能给另一台设备使用；请回到原记录或明确重新授权。'**
  String providerUiPinnedHelp(String name);

  /// Provider navigation and ownership UI.
  ///
  /// In zh, this message translates to:
  /// **'选择适配器实例'**
  String get providerUiChooseInstance;

  /// Provider navigation and ownership UI.
  ///
  /// In zh, this message translates to:
  /// **'只列出当前提供商的实例。授权范围由适配器类型与验证结果决定。'**
  String get providerUiInstanceChoiceHelp;

  /// Provider navigation and ownership UI.
  ///
  /// In zh, this message translates to:
  /// **'旧资料无法确定业务归属。请为每个实例确认提供商及所有受影响的服务器。确认前只允许刷新已有关联。'**
  String get providerUiReviewHelp;

  /// Provider navigation and ownership UI.
  ///
  /// In zh, this message translates to:
  /// **'重命名不会确认归属；仍须在实例上执行归属确认。'**
  String get providerUiRenameReviewHelp;

  /// Provider navigation and ownership UI.
  ///
  /// In zh, this message translates to:
  /// **'确认实例归属'**
  String get providerUiConfirmOwnership;

  /// Provider navigation and ownership UI.
  ///
  /// In zh, this message translates to:
  /// **'将「{alias}」归属到「{provider}」。下列已关联服务器会一起调整归属：\n{devices}\n\n保留原授权、服务器资料、费用和 SSH。此操作不会扩大授权范围。'**
  String providerUiConfirmOwnershipMessage(
    String alias,
    String provider,
    String devices,
  );

  /// Provider navigation and ownership UI.
  ///
  /// In zh, this message translates to:
  /// **'没有已关联服务器。'**
  String get providerUiNoAffectedDevices;

  /// Provider navigation and ownership UI.
  ///
  /// In zh, this message translates to:
  /// **'此提供商已变更或不可用，请返回重新选择。'**
  String get providerUiUnavailable;

  /// Provider navigation and ownership UI.
  ///
  /// In zh, this message translates to:
  /// **'更改提供商'**
  String get providerUiChange;

  /// Provider navigation and ownership UI.
  ///
  /// In zh, this message translates to:
  /// **'将「{server}」从「{oldProvider}」改为「{newProvider}」。\n\n{linkEffect}\n\n保留服务器 ID、手动资料、费用和 SSH。更改归属不会自动添加新授权或关联。'**
  String providerUiChangeMessage(
    String server,
    String oldProvider,
    String newProvider,
    String linkEffect,
  );

  /// Provider navigation and ownership UI.
  ///
  /// In zh, this message translates to:
  /// **'这台服务器没有适配器关联。'**
  String get providerUiChangeNoLink;

  /// Provider navigation and ownership UI.
  ///
  /// In zh, this message translates to:
  /// **'必须先解除与「{alias}」的本地关联；旧适配器授权仍保留，单台授权的固定目标不会被清除。'**
  String providerUiChangeUnlink(String alias);

  /// Provider navigation and ownership UI.
  ///
  /// In zh, this message translates to:
  /// **'解除关联并更改归属'**
  String get providerUiUnlinkAndChange;

  /// Provider navigation and ownership UI.
  ///
  /// In zh, this message translates to:
  /// **'更改已有服务器归属，请返回详情选择“更改提供商”；有关联时须先确认解除。'**
  String get providerUiChangeFromDetails;

  /// Provider navigation and ownership UI.
  ///
  /// In zh, this message translates to:
  /// **'提供商与适配器'**
  String get providerUiProviderAndAdapter;

  /// Provider navigation and ownership UI.
  ///
  /// In zh, this message translates to:
  /// **'查看提供商'**
  String get providerUiOpenProvider;

  /// Provider navigation and ownership UI.
  ///
  /// In zh, this message translates to:
  /// **'查看适配器实例'**
  String get providerUiOpenInstance;

  /// Label for an ambiguous migrated provider.
  ///
  /// In zh, this message translates to:
  /// **'{name} · 归属待确认'**
  String providerPendingName(String name);

  /// Adapter instance import and local linking
  ///
  /// In zh, this message translates to:
  /// **'请先在服务器详情中指定提供商，再选择适配器实例关联。'**
  String get providerBindingAssignFirst;

  /// Adapter instance import and local linking
  ///
  /// In zh, this message translates to:
  /// **'适配器实例已保存。授权与本次设备导入结果分别保留。'**
  String get cloudImportSaved;

  /// Adapter instance import and local linking
  ///
  /// In zh, this message translates to:
  /// **'资源完整'**
  String get cloudImportReady;

  /// Adapter instance import and local linking
  ///
  /// In zh, this message translates to:
  /// **'待补填资源'**
  String get cloudImportNeedsCompletion;

  /// Adapter instance import and local linking
  ///
  /// In zh, this message translates to:
  /// **'导入成功'**
  String get cloudImportImported;

  /// Adapter instance import and local linking
  ///
  /// In zh, this message translates to:
  /// **'已存在'**
  String get cloudImportExisting;

  /// Adapter instance import and local linking
  ///
  /// In zh, this message translates to:
  /// **'导入失败'**
  String get cloudImportFailed;

  /// Adapter instance import and local linking
  ///
  /// In zh, this message translates to:
  /// **'未处理'**
  String get cloudImportUnprocessed;

  /// Adapter instance import and local linking
  ///
  /// In zh, this message translates to:
  /// **'补填资源'**
  String get cloudImportCompleteResources;

  /// Adapter instance import and local linking
  ///
  /// In zh, this message translates to:
  /// **'核对资源'**
  String get cloudImportReviewResources;

  /// Adapter instance import and local linking
  ///
  /// In zh, this message translates to:
  /// **'保存草稿并勾选'**
  String get cloudImportCompleteAndSelect;

  /// Adapter instance import and local linking
  ///
  /// In zh, this message translates to:
  /// **'导入前需核对完整的六项资源。API 未提供的值保持未知；只有明确确认后才选择不限流量。补填或修改仅用于本地配置，不会改写 API 观测信息。'**
  String get cloudImportCompletionInfo;

  /// Adapter instance import and local linking
  ///
  /// In zh, this message translates to:
  /// **'本次仅添加设备与资源配置。财务信息可稍后填写，不会自动创建费用或付款。'**
  String get cloudImportFinanceLater;

  /// Adapter instance import and local linking
  ///
  /// In zh, this message translates to:
  /// **'成功 {imported} · 已存在 {existing} · 失败 {failed} · 未处理 {unprocessed}'**
  String cloudImportSummary(
    int imported,
    int existing,
    int failed,
    int unprocessed,
  );

  /// Adapter instance import and local linking
  ///
  /// In zh, this message translates to:
  /// **'仅重试未完成的 {count} 台设备'**
  String cloudImportRetryCount(int count);

  /// Adapter instance import and local linking
  ///
  /// In zh, this message translates to:
  /// **'停止后续导入'**
  String get cloudImportCancel;

  /// Adapter instance import and local linking
  ///
  /// In zh, this message translates to:
  /// **'正在停止…'**
  String get cloudImportCancelling;

  /// Adapter instance import and local linking
  ///
  /// In zh, this message translates to:
  /// **'已停止后续导入。已提交的设备保留，可核对结果后重试未完成项。'**
  String get cloudImportCancelled;

  /// Adapter instance import and local linking
  ///
  /// In zh, this message translates to:
  /// **'本次导入结果'**
  String get cloudImportResultsTitle;

  /// Adapter instance import and local linking
  ///
  /// In zh, this message translates to:
  /// **'发现 {count} 条相同远端标识的本地记录，请逐条核对；不会自动选择或合并。'**
  String cloudImportExistingConflict(int count);

  /// Adapter instance import and local linking
  ///
  /// In zh, this message translates to:
  /// **'IP 或主机名与这些本地设备相同：{names}。这只是核对提示，不能据此确认是同一设备。'**
  String cloudImportAddressHint(String names);

  /// Adapter instance import and local linking
  ///
  /// In zh, this message translates to:
  /// **'将解除 {count} 台本地服务器的关联：\n{names}\n\n全部本地资料、资源配置、财务与 SSH 设置保留。'**
  String cloudInstanceDeleteImpact(int count, String names);

  /// Read remote UUID conflicts with locked local device identity
  ///
  /// In zh, this message translates to:
  /// **'设备标识冲突'**
  String get cloudImportIdentityConflict;
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
