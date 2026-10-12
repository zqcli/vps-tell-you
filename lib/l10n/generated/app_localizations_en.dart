// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get language => 'Language';

  @override
  String get languageDescription =>
      'Changes apply right away. Drafts and open connections stay as they are.';

  @override
  String get languageSystem => 'Follow system';

  @override
  String get languageSystemDescription =>
      'If your device language isn’t Chinese or English, the app uses English.';

  @override
  String get languageChinese => '简体中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSaveFailed =>
      'Couldn’t save the language setting. The current language is unchanged. Try again.';

  @override
  String get ledgerOpenFailed => 'Couldn’t open the local ledger';

  @override
  String get ledgerOpenHelp =>
      'Your existing data is still there. Check device storage and file permissions. If you used a newer version before, open the app with that version or later.';

  @override
  String get retryOpen => 'Try Again';

  @override
  String get ledgerDoNotErase =>
      'Don’t clear app data or reinstall the app to try to fix this.';

  @override
  String get servers => 'Servers';

  @override
  String get costs => 'Costs';

  @override
  String get tools => 'Tools';

  @override
  String get settings => 'Settings';

  @override
  String get toolsDescription =>
      'Calculate costs, connect to servers, or manage saved commands.';

  @override
  String get remainingValueCalculator => 'Remaining Value Calculator';

  @override
  String get calculatorDescription =>
      'Start from scratch or use a server’s details. Export as an image.';

  @override
  String get connectionsTroubleshooting => 'Connections and troubleshooting';

  @override
  String get sshQuickConnect => 'SSH Quick Connect';

  @override
  String get sshQuickConnectDescription =>
      'Pick a saved server or a one-off target. Verify the host before signing in.';

  @override
  String get tcpConnectionTest => 'TCP Connection Test';

  @override
  String get tcpConnectionDescription =>
      'Check one address and port from this device.';

  @override
  String get commandSnippets => 'Command Snippets';

  @override
  String get commandSnippetsDescription =>
      'Save commands and add them to the terminal draft before sending.';

  @override
  String get singleServerMaintenance => 'Server maintenance';

  @override
  String get powerControl => 'Power Control';

  @override
  String get powerControlDescription =>
      'Restart or shut down over SSH. Double-check the target first.';

  @override
  String get powerControlWarning =>
      'SSH can’t power a stopped server back on, so use the provider’s panel after a shutdown. Restarting or shutting down doesn’t stop provider billing.';

  @override
  String get uiTabsCalculatorTile =>
      'Estimate on its own or from a server; export a privacy-safe image';

  @override
  String get uiTabsSshTile => 'Choose a saved server';

  @override
  String get uiTabsTcpTile => 'Check one host and port';

  @override
  String get uiTabsSnippetsTile => 'Saved commands, inserted as a draft';

  @override
  String get uiTabsPowerTile => 'Restart or shut down over SSH';

  @override
  String get uiTabsLedgerSection => 'Ledger';

  @override
  String get uiTabsSecuritySection => 'Security';

  @override
  String get uiTabsPreferencesSection => 'Preferences';

  @override
  String get uiTabsDataSection => 'Data';

  @override
  String get uiTabsNotifyAllowed => 'Allowed';

  @override
  String get uiTabsNotifyDenied => 'Not allowed';

  @override
  String get uiTabsNotifyUnsupported => 'Unsupported';

  @override
  String get uiTabsNotifyUnchecked => 'Not checked';

  @override
  String get uiTabsNotifyChecking => 'Checking';

  @override
  String get uiTabsNotifyFailed => 'Check failed';

  @override
  String get usageContinue => 'Keep using';

  @override
  String get usageUndecided => 'Undecided';

  @override
  String get usageStop => 'Stop using at expiry';

  @override
  String get reminderNoDays => 'No reminder days selected';

  @override
  String get reminderOnDueDate => 'On the due date';

  @override
  String reminderDaysBefore(int p0) {
    String _temp0 = intl.Intl.pluralLogic(
      p0,
      locale: localeName,
      other: '$p0 days before',
      one: '1 day before',
    );
    return '$_temp0';
  }

  @override
  String get notificationStatus => 'Notification Access & Reminder Status';

  @override
  String reminderLastTimezone(String p0) {
    return 'Time zone last used to schedule reminders: $p0';
  }

  @override
  String get reminderEnableHelp =>
      'Turn on system notifications and each server’s reminders. Set reminder days, time, and usage plan in server details. You can save rules even without notification permission.';

  @override
  String get requestingPermission => 'Requesting…';

  @override
  String get requestNotificationPermission => 'Allow Notifications';

  @override
  String get notificationPermissionHelp =>
      'If you denied permission or turned notifications off, change it in device settings. Then come back and check reminder status again.';

  @override
  String get checkReminderStatus => 'Check Again';

  @override
  String get reminderCoverage => 'Reminder coverage';

  @override
  String get r2TabsMetricScheduled => 'Scheduled';

  @override
  String get r2TabsMetricNotCovered => 'Not covered';

  @override
  String get r2TabsMetricNoReminder => 'No reminder';

  @override
  String get r2TabsUpcoming => 'Upcoming';

  @override
  String r2TabsShowAll(String n) {
    return 'Show All ($n)';
  }

  @override
  String get r2TabsToday => 'Today';

  @override
  String get r2TabsTomorrow => 'Tomorrow';

  @override
  String get r2TabsWithinWeek => 'Next 7 days';

  @override
  String r2TabsMonth(String year, String month) {
    return '$year-$month';
  }

  @override
  String r2TabsRowSub(String lead, String due) {
    return '$lead · due $due';
  }

  @override
  String get r2TabsNotCoveredPill => 'Not covered';

  @override
  String get r2TabsCoverageNote =>
      'Reminders beyond the system limit (iOS 64 / Android 256) or more than 366 days out aren’t scheduled.';

  @override
  String get r2TabsNoReminderServers => 'Servers without reminders';

  @override
  String get r2TabsReasonArchived => 'Archived';

  @override
  String get r2TabsReasonDemo => 'Demo data';

  @override
  String get r2TabsReasonNoDate => 'No due date';

  @override
  String get r2TabsReasonNotPrepaid => 'Not prepaid';

  @override
  String get r2TabsReasonOff => 'Reminders off';

  @override
  String get r2TabsReasonNoUpcoming => 'Nothing upcoming';

  @override
  String get r2TabsAllReminders => 'All Reminders';

  @override
  String get r2TabsFilterAll => 'All';

  @override
  String get r2TabsSearchHint => 'Search by server name';

  @override
  String get r2TabsEmpty => 'Nothing to show';

  @override
  String get r2TabsNoUpcoming => 'No upcoming reminders';

  @override
  String get r2TabsEnableHelp =>
      'Requires system notifications and per-server reminders to be on.';

  @override
  String get r2TabsPermissionHelp =>
      'If you denied permission, turn notifications on in system settings.';

  @override
  String r2TabsNotifyScheduled(String n) {
    return '$n scheduled';
  }

  @override
  String get reminderHorizonHelp =>
      'Only reminders for known due dates within the next 366 days are scheduled, and reminder times that have already passed aren’t retried. iOS allows up to 64 pending reminders and Android 256; the rest show as not scheduled. Open the app regularly to refresh them.';

  @override
  String get reminderDeliveryHelp =>
      'The app rechecks permission and your time zone each time it opens. After traveling, open the app, or existing reminders may still use the old time zone. Battery saver, Focus modes, and device restrictions can delay or block reminders. Scheduled doesn’t mean delivered.';

  @override
  String get reminderPrivacyHelp =>
      'Reminders contain only the due date and a prompt to check it. They never include server names, addresses, accounts, or amounts, and they don’t make payments or change renewal settings with your provider.';

  @override
  String get reminderRulesSaved =>
      'Reminder rules saved. Check the system status in Settings > Notification Access.';

  @override
  String get localExpiryReminders => 'Expiry Reminders';

  @override
  String get back => 'Back';

  @override
  String get recordMissingReload =>
      'This record no longer exists. Go back and reload.';

  @override
  String get dueDateNotEntered => 'No due date entered';

  @override
  String get reminderSaveHelp =>
      'Tap Save Reminder Rules to apply changes. If reminders are on and you choose Stop using at expiry, you’ll still be reminded to check renewal settings with your provider.';

  @override
  String get uiTabsReminderSaveHelp => 'Tap Save at the top right to apply.';

  @override
  String uiTabsReminderDue(String name, String date) {
    return '$name expires on $date.';
  }

  @override
  String uiTabsReminderPreview(String dates, String time) {
    return 'You’ll be reminded on $dates at $time (device time zone). Notifications never include names, IPs, or amounts.';
  }

  @override
  String get uiTabsReminderPreviewNone =>
      'These settings produce no upcoming reminders. Notifications never include names, IPs, or amounts.';

  @override
  String get uiTabsUsageContinueHint => 'Reminds you to renew before expiry';

  @override
  String get uiTabsUsageUndecidedHint => 'Reminds you to decide';

  @override
  String get uiTabsUsageStopHint =>
      'Still reminds you to check and cancel auto-renewal';

  @override
  String get demoNoNotifications =>
      'Demo records don’t schedule real system notifications.';

  @override
  String get archivedNoReminders =>
      'Archived records don’t schedule reminders.';

  @override
  String get enableServerReminders => 'Reminders for this server';

  @override
  String get reminderOnlyHelp =>
      'Reminders only. No automatic renewal or cancellation.';

  @override
  String get daysBefore => 'Days before due date';

  @override
  String get sameDay => 'Same day';

  @override
  String dayCount(int p0) {
    String _temp0 = intl.Intl.pluralLogic(
      p0,
      locale: localeName,
      other: '$p0 days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get reminderTime => 'Reminder time';

  @override
  String get selectReminderTime => 'Set Reminder Time';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'OK';

  @override
  String get hour => 'Hour';

  @override
  String get minute => 'Minute';

  @override
  String get invalidTime => 'Enter a valid time';

  @override
  String get reminderDstHelp =>
      'Uses the device time zone. Times skipped by daylight saving time move forward, and repeated times fire once.';

  @override
  String get myUsagePlan => 'My usage plan';

  @override
  String get usagePlanWarning =>
      'A usage plan is only a local note and doesn’t stop provider billing. Cancel renewal with the provider separately.';

  @override
  String get savedRuleSchedule => 'Schedule for saved rules';

  @override
  String serverScheduledCount(String p0) {
    return 'Scheduled for this server: $p0';
  }

  @override
  String get viewReminderCoverage => 'View notification access and coverage';

  @override
  String get saving => 'Saving…';

  @override
  String get saveReminderRules => 'Save reminder rules';

  @override
  String get expiryNotificationTitle => 'Check VPS expiry';

  @override
  String notificationDueDate(String p0) {
    return 'expires on $p0';
  }

  @override
  String notificationStopBody(String p0) {
    return 'A service $p0. Make sure you’ve canceled renewal with your provider. A local plan doesn’t stop billing.';
  }

  @override
  String notificationContinueBody(String p0) {
    return 'A service $p0. Check the provider’s bill and your usage plan. This reminder doesn’t make payments.';
  }

  @override
  String get expiryChecks => 'Expiry checks';

  @override
  String get expiryChannelDescription =>
      'Local expiry reminders. No automatic renewal or payment.';

  @override
  String get reminderNotChecked => 'System notifications haven’t been checked';

  @override
  String get reminderChecking => 'Checking system reminders…';

  @override
  String reminderScheduleCounts(String p0, String p1) {
    return 'Scheduled: $p0 · Not scheduled: $p1';
  }

  @override
  String get reminderPermissionDenied =>
      'Notifications aren’t allowed or the channel is off. Saved rules are kept.';

  @override
  String get reminderUnsupported =>
      'This platform doesn’t support scheduled notifications, so saved rules won’t trigger reminders on this device.';

  @override
  String get reminderCheckFailed =>
      'Couldn’t check reminder status. Older reminders may remain. Try again or check device settings.';

  @override
  String get jsonLedgerBackup => 'JSON ledger backup';

  @override
  String get backupTooLarge => 'The backup is over the 10 MiB limit';

  @override
  String get backupExportInvalid =>
      'Export validation failed. No backup was saved or shared. The ledger is unchanged.';

  @override
  String get backupShareSelected =>
      'You picked a sharing option. Check the destination app to confirm the file was saved or delivered.';

  @override
  String get backupShareCancelled =>
      'Sharing canceled. The backup preview is kept.';

  @override
  String get backupShareUnknown =>
      'No sharing result was received. The backup preview is kept.';

  @override
  String get systemShareUnsupported =>
      'System sharing isn’t supported on this platform.';

  @override
  String get completeCurrentShare => 'Finish the current sharing action first.';

  @override
  String get backupShareFailed =>
      'Sharing didn’t complete. The backup preview is kept.';

  @override
  String get backupSaveCancelled =>
      'Saving canceled. The backup preview is kept.';

  @override
  String backupSavedPath(String p0) {
    return 'Backup saved:\n$p0';
  }

  @override
  String get backupSaveFailed =>
      'Couldn’t save the backup. Check storage and permissions, then try again.';

  @override
  String get backupSelectionCancelled => 'Backup selection canceled.';

  @override
  String get backupReadInvalid =>
      'Couldn’t read or validate the file. Choose a complete version 1 or 2 JSON ledger backup no larger than 10 MiB. Existing data is unchanged.';

  @override
  String get restoreEmptyLedgerQuestion => 'Restore to this empty ledger?';

  @override
  String restoreConfirmation(String p0) {
    return '$p0\nOriginal IDs, amounts, and voided payments are kept. Manual reference exchange rates are replaced. Notes, connections, security data, and reminder rules aren’t restored, and reminders for imported servers stay off. Restoring never connects to or renews servers.';
  }

  @override
  String get confirmRestore => 'Restore';

  @override
  String get ledgerRestored =>
      'Ledger restored. Set up connections and reminders again. No servers were connected.';

  @override
  String get restoreFailed =>
      'Couldn’t restore. Existing data is unchanged. Only empty ledgers can be restored. Choose the backup and check it again.';

  @override
  String deviceTime(String p0) {
    return '$p0 (device time)';
  }

  @override
  String backupCounts(String p0, String p1, String p2, String p3) {
    return 'Servers: $p0 · Groups: $p1\nPayments (including voided): $p2 · Service periods: $p3';
  }

  @override
  String get ledgerBackupRestore => 'Ledger Backup & Restore';

  @override
  String get plainJsonVersion => 'Unencrypted JSON · Format v2';

  @override
  String get backupContentsWarning =>
      'Includes server names, providers, addresses, regions, purposes, operating systems, specifications, hardware details, groups, amounts, dates, payments, and manual exchange rates. The file is unencrypted: store it safely and share it only with trusted destinations. Anything sensitive you typed into these fields is exported too.';

  @override
  String get notIncluded => 'Not included:';

  @override
  String get generateBackupPreview => 'Preview Export';

  @override
  String get exportPreview => 'Export preview';

  @override
  String backupGeneratedTime(String p0) {
    return 'Backup created: $p0';
  }

  @override
  String get shareUnencryptedBackup => 'Share Unencrypted Backup';

  @override
  String get saveJsonBackup => 'Save JSON Backup';

  @override
  String get restoreEmptyOnlyHelp =>
      'You can restore only into a ledger with no servers, groups, payments, or service periods. Existing data is never overwritten or merged. Reminders for imported servers start off. App preferences stay as they are.';

  @override
  String get chooseJsonPreviewRestore => 'Choose Backup File';

  @override
  String get restorePreview => 'Restore preview';

  @override
  String backupTime(String p0) {
    return 'Backup time: $p0';
  }

  @override
  String get restoreContentsHelp =>
      'Only ledger records and manual rates are restored. The items listed above aren’t in the backup.';

  @override
  String get restoreToEmptyLedger => 'Restore to Empty Ledger';

  @override
  String get appearance => 'Appearance';

  @override
  String get followSystem => 'Follow system';

  @override
  String get lightTheme => 'Light';

  @override
  String get darkTheme => 'Dark';

  @override
  String get appDescription => 'Personal VPS ledger · Local-first';

  @override
  String get organizationData => 'Organization and data';

  @override
  String get manageGroups => 'Manage Groups';

  @override
  String groupCountHelp(String p0) {
    return 'Groups: $p0 · Deleting a group keeps its records';
  }

  @override
  String get archivedRecords => 'Archived Records';

  @override
  String archiveCountHelp(String p0) {
    return 'Records: $p0 · Can be restored to the server list';
  }

  @override
  String get accountsPreferences => 'Accounts and preferences';

  @override
  String get keysSecurity => 'Keys & Security';

  @override
  String get keysSecurityDescription =>
      'Credentials, SSH settings, and host trust';

  @override
  String get currenciesReferenceRates => 'Currencies & Reference Rates';

  @override
  String currencyRateSummary(String p0, String p1) {
    return '$p0 · Manual rates: $p1';
  }

  @override
  String get notSet => 'Not set';

  @override
  String get notificationAccess => 'Notification Access';

  @override
  String get backupExclusionsSummary =>
      'Excludes credentials and host trust · Unencrypted JSON';

  @override
  String get about => 'About';

  @override
  String get developmentVersion => 'Development build · 0.1.0';

  @override
  String get appLocalDataHelp =>
      'Your data stays on this device, and no account is needed. Archiving doesn’t cancel the service or stop billing.';

  @override
  String get groupSaveFailed =>
      'Couldn’t save the group. Check for a duplicate name, then try again.';

  @override
  String deleteGroupQuestion(String p0) {
    return 'Delete “$p0”?';
  }

  @override
  String get deleteGroupHelp =>
      'All servers in this group, including archived ones, move to Ungrouped. Server details and payment history are kept, and remote servers aren’t touched.';

  @override
  String get deleteGroup => 'Delete Group';

  @override
  String get addGroup => 'Add Group';

  @override
  String get groupsHelp => 'Organize servers by purpose.';

  @override
  String get noGroupsHelp =>
      'No custom groups yet. Tap + at the top right to create one.';

  @override
  String unarchivedServerCount(String p0) {
    return 'Unarchived servers: $p0';
  }

  @override
  String actionsForGroup(String p0) {
    return 'Actions for $p0';
  }

  @override
  String get rename => 'Rename';

  @override
  String get moveUp => 'Move Up';

  @override
  String get moveDown => 'Move Down';

  @override
  String get ungrouped => 'Ungrouped';

  @override
  String ungroupedCountHelp(String p0) {
    return 'Unarchived servers: $p0 · Default group; can’t be deleted';
  }

  @override
  String get archiveHelp =>
      'Archiving keeps the record. Restoring doesn’t start or renew the service.';

  @override
  String get noArchivedRecords => 'No archived records';

  @override
  String get restoreRecord => 'Restore Record';

  @override
  String get renameGroup => 'Rename Group';

  @override
  String get groupName => 'Group name';

  @override
  String get save => 'Save';

  @override
  String get operationFailed =>
      'Couldn’t complete that. Try again. Saved details are kept.';

  @override
  String get recordChanged => 'This record has changed. Go back and try again.';

  @override
  String get gotIt => 'Got It';

  @override
  String get financeCancel => 'Cancel';

  @override
  String get financeSaving => 'Saving…';

  @override
  String get financeUnknown => 'Unknown';

  @override
  String get financeNotSet => 'Not set';

  @override
  String get financeDateNotSet => 'Date not set';

  @override
  String get financePayments => 'Payment Records';

  @override
  String get financeCalculationRules => 'Calculation Basis';

  @override
  String get financeAllGroups => 'All groups';

  @override
  String get financeUngrouped => 'Ungrouped';

  @override
  String get financeNotEntered => 'Not entered';

  @override
  String get financeNote => 'Note';

  @override
  String get financeStatus => 'Status';

  @override
  String get financeEstimatedOnly => 'Estimate · No ledger entry';

  @override
  String get financeValueTitle =>
      'Remaining value · At the current renewal price';

  @override
  String get financeNotApplicable => 'Not applicable / excluded';

  @override
  String get financeDataUnknown => 'Information unknown';

  @override
  String get financeMissingFxPreserved =>
      'Exchange rate missing · Original currency retained';

  @override
  String get financeMissingFxExcluded =>
      'Only amounts with an exchange rate are totaled. Missing amounts aren’t counted as zero.';

  @override
  String get financeValuationAndDue => 'Valuation date / service due date';

  @override
  String get financeRemainingDays => 'Remaining service days';

  @override
  String get financeRenewalCycle => 'Renewal price / cycle';

  @override
  String get financeDailyShown => 'Daily average for the shown period';

  @override
  String get r2CopyMetricDaysLeft => 'Days left';

  @override
  String get r2CopyMetricDaily => 'Daily';

  @override
  String get financeInferredPeriods =>
      'Start dates are inferred from the due date; not proof of payment.';

  @override
  String get financeValueDisclaimer =>
      'Based on remaining time; not a refund promise or sale price.';

  @override
  String get financeShownPeriod => 'Shown period';

  @override
  String get financeFuturePeriod => 'Future period';

  @override
  String get financeEndedPeriod => 'Ended period';

  @override
  String get financeCurrentPeriod => 'Current period';

  @override
  String get financeFxTitle => 'Currencies & Reference Rates';

  @override
  String get financeFxScope =>
      'Affects reference conversions only; no live rates are fetched. Leave blank if unknown.';

  @override
  String get financeDisplayCurrency => 'Currency for totals';

  @override
  String get financeUsdRate => '1 USD = how many CNY';

  @override
  String get financeEurRate => '1 EUR = how many CNY';

  @override
  String get financeUnknownRateHint => 'Leave blank if the rate is unknown';

  @override
  String get financeRateError =>
      'Enter a rate greater than 0, with up to 8 decimal places';

  @override
  String get financeRateDate => 'Reference rate date';

  @override
  String get financePastDateError =>
      'Enter a valid date that is no later than today';

  @override
  String get financeFxBasis =>
      'CNY is the base. Currencies without a rate are left out of totals.';

  @override
  String get financeSaveFx => 'Save Reference Rates';

  @override
  String get financeReferenceTitle => 'Use Server Details';

  @override
  String get financeReferenceNote =>
      'Copies the current renewal details only. The server isn’t changed.';

  @override
  String get financeNoPrepaid =>
      'No prepaid servers are available. You can calculate an independent estimate.';

  @override
  String get financeDateRangeError =>
      'Check the dates. Estimates are limited to a 100-year range.';

  @override
  String get financeMissingPeriodsError =>
      'The referenced details have no valid service period. Add the server’s dates first, or change the due date or cycle to calculate an independent estimate.';

  @override
  String get financeCalculatorTitle => 'Remaining Value Calculator';

  @override
  String get financeReferenceServer => 'Use a server';

  @override
  String get financeIndependentRebuilt =>
      'Switched to an independent estimate. Service periods are recalculated from the due date and cycle.';

  @override
  String get financeIndependentNote =>
      'Independent estimate; no server needed. Assumes continuous service before the due date.';

  @override
  String get financeRenewalAmount => 'Renewal price per cycle';

  @override
  String get financeAmountError =>
      'Enter a valid amount. Use 0 only if the service is known to be free.';

  @override
  String get financeOriginalCurrency => 'Original currency';

  @override
  String get financeCycle => 'Renewal cycle';

  @override
  String get financeValuationDate => 'Valuation date';

  @override
  String get financeValuationDateError => 'Enter a valid valuation date';

  @override
  String get financeServiceDue => 'Service due date';

  @override
  String get financeDueError => 'Enter a valid due date';

  @override
  String get r6CalcServiceStart => 'Service start date';

  @override
  String get r6CalcDueAutoNote =>
      'The due date follows the start date and cycle until you pick a different one.';

  @override
  String get financeAlgorithmTitle => 'Periods and calculation method';

  @override
  String get financeAlgorithmNote =>
      'Remaining value = Σ (renewal price per cycle × fraction of unused days in that cycle).\nCalendar cycles use actual day counts, not fixed 30-day months. Month-end dates are calculated backward from the original due-date anchor, with leap years handled for yearly cycles. Valuing a period before its known start never exceeds its full price.\nIndependent mode works backward to cover the valuation date, up to 100 years. Value is 0 on the due date. Transferability and refund eligibility aren’t checked.';

  @override
  String get financeCalculateValue => 'Calculate Remaining Value';

  @override
  String get financeEstimateNoWrite =>
      'Estimates never change any server or payment.';

  @override
  String get financeReferenceRateMissing => 'Reference exchange rate missing';

  @override
  String get financeIndependentBasis =>
      'Independent assumption: service is continuous before the due date, with periods calculated backward from it.';

  @override
  String get financeQuoteFxError =>
      'The required exchange rate is missing, so the reference value and settlement amounts can’t be calculated.';

  @override
  String get financeCopied =>
      'Result copied. It contains calculation details only.';

  @override
  String get financeCopyError => 'Couldn’t write to the clipboard. Try again.';

  @override
  String get financeResultTitle => 'Calculation Result';

  @override
  String get financeEditInputs => 'Edit inputs';

  @override
  String get financeCopyResult => 'Copy result';

  @override
  String get financePreviewPng => 'Preview / Save PNG';

  @override
  String get financeQuoteTitle => 'Transfer quote estimate · Optional';

  @override
  String get financeQuoteNote =>
      'Estimate only; no transaction is made. Check that the provider allows transfers.';

  @override
  String get financeQuoteAmountError =>
      'Enter a quote of 0 or a positive amount';

  @override
  String get financeTransferFee => 'Transfer fee (Push)';

  @override
  String get financeQuoteFeeError => 'Enter a fee of 0 or a positive amount';

  @override
  String get financeFeeCurrency => 'Fee currency';

  @override
  String get financeFeePayer => 'Who pays the fee';

  @override
  String get financeBuyerPays => 'Buyer';

  @override
  String get financeSellerPays => 'Seller';

  @override
  String get financeSplitFee => 'Split equally';

  @override
  String get financeSplitFeeNote =>
      'The fee is split in minor units; any odd 0.01 goes to the buyer.';

  @override
  String get financeCalculateQuote => 'Calculate Quote and Fees';

  @override
  String get financePremiumLabel =>
      'Quote minus reference value (premium / discount)';

  @override
  String get financeBuyerSellerFee => 'Buyer / seller fee';

  @override
  String get financeBuyerEstimate => 'Estimated buyer outlay';

  @override
  String get financeSellerEstimate => 'Estimated seller net proceeds';

  @override
  String get financeAccountNameError => 'Enter an account display name';

  @override
  String get financePaidAmountError =>
      'Enter a valid amount paid. 0 means free.';

  @override
  String get financeDateError => 'Enter a valid date, for example 2026-10-06';

  @override
  String get financePaymentFutureError =>
      'The payment date can’t be later than today';

  @override
  String get financePaymentConfirmError =>
      'Confirm that you have paid the provider and checked the details';

  @override
  String get financeBillPeriodError =>
      'Enter both billing period dates together. The end must be later than the start.';

  @override
  String get financePaymentSavedRefresh =>
      'Payment saved, but the screen hasn’t updated. Reload.';

  @override
  String get financeAccountPaymentSaved =>
      'Account bill recorded once. Instance due dates are unchanged.';

  @override
  String get financePaymentSaved =>
      'Payment recorded. Service periods and totals are updated.';

  @override
  String get financeRecordPayment => 'Record a Completed Payment';

  @override
  String get financeNoRenewalDate =>
      'No usable prepaid due date. Check the server details.';

  @override
  String get financeRecordAccountBill => 'Record an Account Bill';

  @override
  String get financeLocalPaymentOnly =>
      'Saves a local ledger entry only. No payment is made to the provider.';

  @override
  String get financeAccountBillNote =>
      'A standalone bill, counted once. It isn’t split across periods and creates no service period.';

  @override
  String get financeAccountName => 'Account display name';

  @override
  String get financeAccountNameHint =>
      'For example: Provider · Personal account';

  @override
  String get financePaidAmount => 'Amount paid';

  @override
  String get financePaidCurrency => 'Payment currency';

  @override
  String get financePaidDate => 'Actual payment date';

  @override
  String get financeRenewalCount => 'Number of renewal cycles';

  @override
  String get financeNewDue => 'New due date';

  @override
  String get financeNewDueHint =>
      'Must match the date calculated from the selected cycles';

  @override
  String get financePaymentRenewalNote =>
      'The amount paid is saved separately and doesn’t change the renewal price. Whole cycles only.';

  @override
  String get financeBillStart => 'Billing period start (optional)';

  @override
  String get financeBillEnd => 'Billing period end (optional)';

  @override
  String get financeOptionalNote => 'Note (optional)';

  @override
  String get financeConfirmAccountPaid =>
      'I’ve paid the provider and checked the bill amount and dates.';

  @override
  String get financeConfirmServerPaid =>
      'I’ve paid the provider and checked the amount paid and new due date.';

  @override
  String get financeSavePayment => 'Save Payment';

  @override
  String get financeNotReceipt =>
      'This isn’t a payment receipt from the provider, and it doesn’t change auto-renewal settings.';

  @override
  String get financePaymentTarget => 'Payment target';

  @override
  String get financeAllPayments => 'All payment records';

  @override
  String get financeRecent30 => 'Last 30 days';

  @override
  String get financeShowVoided => 'Show deleted';

  @override
  String get financeRecordedPaidTotal => 'Total recorded payments';

  @override
  String get financeNoPayments => '— No payment records yet';

  @override
  String get financePaymentDetails => 'Payment breakdown';

  @override
  String get financeArchivedPayment => 'Server archived · Past payments kept';

  @override
  String get financeNoPaymentsInRange =>
      'No payments in this range. Record completed renewal payments from a server’s details.';

  @override
  String get financeVoidTitle => 'Void this local record?';

  @override
  String get financeVoidAccountNote =>
      'Marks this bill as voided. It doesn’t request a refund from the provider.';

  @override
  String get financeVoidServerNote =>
      'Undoes only the service periods and due date this record added, and marks the payment as voided. It doesn’t request a provider refund or cancel service.';

  @override
  String get financeVoidRecord => 'Void Record';

  @override
  String get financePaymentVoided => 'This local payment record was voided';

  @override
  String get financePaymentDetail => 'Payment Details';

  @override
  String get financePaymentUnavailable =>
      'This record is unavailable. Go back and reload.';

  @override
  String get financePaymentDateLabel => 'Payment date';

  @override
  String get financeType => 'Type';

  @override
  String get financeAccountBill => 'Account bill';

  @override
  String get financeBillServicePeriod => 'Billing / service period';

  @override
  String get financeVoidedStatus => 'Deleted, excluded from payment totals';

  @override
  String get financeRecordedStatus => 'Recorded';

  @override
  String get financePaymentHistoryNote =>
      'Original-currency history. It doesn’t follow renewal prices or exchange rates.';

  @override
  String get financeVoidThisRecord => 'Void This Record';

  @override
  String get r2FinanceEdit => 'Edit';

  @override
  String get r2FinanceEditTitle => 'Edit Payment';

  @override
  String get r2FinanceEditHint =>
      'Edits bookkeeping details only. Service periods, due date, and cycles stay as they are.';

  @override
  String get r2FinanceDelete => 'Delete Record';

  @override
  String get r2FinanceDeleteTitle => 'Delete this payment record?';

  @override
  String get r2FinanceDeleteAccountMsg =>
      'This removes the bill from your local ledger only. No server is affected, and the provider doesn’t refund anything. It no longer counts toward payment totals.';

  @override
  String get r2FinanceDeleteKeepMsg =>
      'Only the payment record is deleted. Service periods and the due date stay as they are, and the provider doesn’t refund anything.';

  @override
  String get r2FinanceDeleteKeep => 'Delete Record Only, Keep Periods';

  @override
  String r4PayDeleteRollbackTo(String date) {
    return 'Delete and Roll Due Date Back to $date';
  }

  @override
  String r4PayDeleteChoiceMsg(String until) {
    return 'If you delete only the record, the service periods stay and the due date remains $until. The provider doesn’t refund anything.';
  }

  @override
  String r4PayDeleteLaterMsg(String dates) {
    return 'There are later renewals ($dates). Delete those first to roll the due date back. This option only deletes the record: periods and due date stay, and the provider doesn’t refund anything.';
  }

  @override
  String r4PayOrphanBanner(String from, String until) {
    return 'The payment for $from → $until was deleted. Roll the due date back to $from?';
  }

  @override
  String get r4PayOrphanTitle => 'Roll back the due date?';

  @override
  String r4PayOrphanMsg(String from, String until) {
    return 'Removes the service periods left by the deleted payment ($from → $until) and restores the due date to $from. Other payment records aren’t affected.';
  }

  @override
  String get r4PayOrphanAction => 'Roll Back';

  @override
  String r4PayOrphanDone(String date) {
    return 'Due date rolled back to $date';
  }

  @override
  String get r2FinanceDeleted => 'Payment record deleted';

  @override
  String get r2FinanceUpdated => 'Payment record updated';

  @override
  String get financeVoidBlocked =>
      'Details have changed. Review them first. After later edits, payments, or archiving, an old record can’t overwrite the current details.';

  @override
  String get financeRulesTitle => 'How these figures are calculated';

  @override
  String get financeTitle => 'Costs';

  @override
  String get financeOverview =>
      'View monthly cost references, remaining value, and recorded payments.';

  @override
  String get financeScope => 'Scope';

  @override
  String get financeMonthlyReference => 'Monthly cost reference';

  @override
  String get financeTotalRemaining => 'Total remaining value  ›';

  @override
  String get financeMonthlyNotPaid =>
      'Renewal prices spread monthly, plus metered estimates. Not what you paid this month.';

  @override
  String get financeUpcomingRenewals => 'Expected renewals in the next 30 days';

  @override
  String get financeRecentPayments => 'Payment Records';

  @override
  String get financeUnrecordedNotZero =>
      'No payments recorded yet. That doesn’t mean you haven’t spent anything.';

  @override
  String get financeMonthlyDistribution => 'Monthly cost breakdown';

  @override
  String get financeByVendor => 'By provider';

  @override
  String get financeByGroup => 'By group';

  @override
  String get financeDistributionEmpty =>
      'Add cost details to see the breakdown.';

  @override
  String get financeDistributionNote => 'Tap a category for server details.';

  @override
  String get financeGroupDistributionNote =>
      'Account-level payments aren’t split across groups. Tap a category for details.';

  @override
  String get financeSixMonthTitle =>
      'Six months from this month · Prepaid renewals';

  @override
  String get financeForecastNote =>
      'Forecast at current renewal prices, assuming renewal continues. Excludes metered bills and expired services.';

  @override
  String get financeMonthlyDetail => 'Monthly Cost Details';

  @override
  String get financeValueDetail => 'Remaining Value Details';

  @override
  String get financeInventoryDetail => 'Server breakdown';

  @override
  String get financeIncompleteDetail => 'Check Costs & Due Dates';

  @override
  String get financeMeteredValueNa =>
      'Metered billing · Remaining value doesn’t apply';

  @override
  String get financeExpiredMonthlyExcluded =>
      'Expired · Not in the monthly cost reference';

  @override
  String get financeUnknownAmount =>
      'Date or cost details are incomplete; amount unknown';

  @override
  String get financeNoServersInRange => 'No servers in this range.';

  @override
  String get financeUnknownZeroNote =>
      '“—” means unknown or not applicable, not free.';

  @override
  String get financeRenewals30Title => 'Renewals in the Next 30 Days';

  @override
  String get financeNoKnownRenewals =>
      'No known prepaid renewals in this range.';

  @override
  String get financeExpiredCheck => 'Expired · Verify first';

  @override
  String get financeMeteredRenewalNote =>
      'Metered costs create no renewal events; edit the monthly estimate in server details.';

  @override
  String get financePngRenderFailed =>
      'Couldn’t create the image. Your calculation result is kept.';

  @override
  String get financePngSaveFailed =>
      'Saving didn’t finish. The preview is kept. Check storage space and permissions, then try again.';

  @override
  String get financePngShareSelected =>
      'You picked a share option. Check the destination app to confirm delivery.';

  @override
  String get financePngShareDismissed =>
      'Sharing canceled. The preview is kept.';

  @override
  String get financePngShareUnknown =>
      'No share result was received. The preview is kept.';

  @override
  String get financePngShareUnsupported =>
      'Sharing PNG files isn’t supported on this platform. You can save the file locally.';

  @override
  String get financePngShareBusy => 'Finish the current share action first.';

  @override
  String get financePngShareFailed =>
      'Sharing didn’t finish. The preview is kept. Try again.';

  @override
  String get financePngPreview => 'Image preview';

  @override
  String get financePngPrivacy =>
      'The image contains only amounts, dates, periods, and reference rates, never server names, addresses, or notes.';

  @override
  String get financePngSemantic => 'Remaining value calculation result PNG';

  @override
  String get financeRegenerate => 'Generate Again';

  @override
  String get financeSavePng => 'Save PNG';

  @override
  String get financeSharing => 'Sharing…';

  @override
  String get financeSharePng => 'Share PNG';

  @override
  String get financePngLocationNote =>
      'The file may be in the app’s private folder. Use Share to save it elsewhere.';

  @override
  String get financeRulesBody =>
      'Monthly cost reference: unexpired prepaid renewal prices divided by the cycle length in months, plus metered monthly estimates. Prepaid services are excluded on and after their due date. Missing dates or costs are marked unknown.\n\nRemaining value: the current renewal price prorated by unused days in each known service period. The start date is included and the end date excluded. Future whole periods count at full price; ended periods count as 0. Not applicable to metered billing; unknown when details are insufficient. This isn’t a refundable amount or sale price.\n\nRenewal forecast: assumes continued renewal at the current price and cycle. The next 30 days includes today and the following 29 days. Six months means the rest of this month and the next five calendar months. Expired services aren’t projected forward. Metered bills are excluded. Local usage plans don’t change the forecast.\n\nPayments in the last 30 days: recorded payments from today and the preceding 29 days. The all-groups scope retains payments for archived servers and counts each independent account bill once. Account bills aren’t allocated to groups.\n\nWhen cross-currency rates are missing, only convertible amounts are totaled, while original-currency subtotals are retained. Exact amounts are summed before rounding to minor units. Reference conversions aren’t actual charges.';

  @override
  String financeApproxAmount(String amount, String currency) {
    return 'Approx. $amount $currency';
  }

  @override
  String financeTotalAmount(String covered, String amount, String currency) {
    String _temp0 = intl.Intl.selectLogic(covered, {
      'yes': 'Approx. $amount $currency',
      'other': '$amount $currency',
    });
    return '$_temp0';
  }

  @override
  String financeCoverage(int covered, int total, int missing) {
    String _temp0 = intl.Intl.pluralLogic(
      missing,
      locale: localeName,
      other: ' · $missing items missing exchange rates',
      one: ' · 1 item missing an exchange rate',
      zero: '',
    );
    return 'Conversion coverage $covered / $total$_temp0';
  }

  @override
  String financeUnknownExcluded(int unknown, int excluded) {
    return '$unknown unknown · $excluded not applicable / excluded';
  }

  @override
  String financeOriginalSubtotals(String amounts) {
    return 'Original-currency subtotals: $amounts';
  }

  @override
  String financePeriodProgress(
    String period,
    String percent,
    int remaining,
    int days,
  ) {
    return '$period: $percent% remaining · $remaining / $days days';
  }

  @override
  String financePeriodDates(String start, String end) {
    return '$start to $end (end date excluded)';
  }

  @override
  String financeDaysValue(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String financeRenewalValue(String amount, String currency, int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: '$months months',
      one: '1 month',
    );
    return '$amount $currency / $_temp0';
  }

  @override
  String financeFuturePeriodsNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count future periods',
      one: '1 future period',
    );
    return 'Includes $_temp0.';
  }

  @override
  String financeReferenceServerSubtitle(String billing, String due) {
    return '$billing · Until $due';
  }

  @override
  String financeReferenceBasis(String name) {
    return 'Uses known periods from $name. Changing the inputs doesn’t change the original server.';
  }

  @override
  String financeEveryMonths(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: 'Every $months months',
      one: 'Every month',
    );
    return '$_temp0';
  }

  @override
  String financeFxSource(String date) {
    return 'Manual exchange rate · $date · Not a live quote';
  }

  @override
  String financeKnownPeriodsBasis(String inferred) {
    String _temp0 = intl.Intl.selectLogic(inferred, {
      'yes': 'Known service periods copied when referenced; some start dates are inferred. The ledger is unchanged.',
      'other': 'Known service periods copied when referenced. The ledger is unchanged.',
    });
    return '$_temp0';
  }

  @override
  String financeSellerQuote(String currency) {
    return 'Seller quote · $currency';
  }

  @override
  String get r3FinancePeriodWeek => 'Last week';

  @override
  String get r3FinancePeriodMonth => 'Last month';

  @override
  String get r3FinancePeriodQuarter => 'Last 3 months';

  @override
  String get r3FinancePeriodHalfYear => 'Last 6 months';

  @override
  String get r3FinancePeriodYear => 'Last year';

  @override
  String get r3FinancePeriodAll => 'All';

  @override
  String r3FinanceRecentSub(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count payments',
      one: '1 payment',
    );
    return 'Last 30 days · $_temp0';
  }

  @override
  String get r3FinanceTimelineStart => 'Period start';

  @override
  String get r3FinanceTimelineAsOf => 'Valuation';

  @override
  String get r3FinanceTimelineDue => 'Due';

  @override
  String get r3FinanceQuoteMode => 'Input';

  @override
  String get r3FinanceQuoteModeOffer => 'Enter the quote';

  @override
  String get r3FinanceQuoteModePremium => 'Enter a premium amount';

  @override
  String get r3FinanceQuoteModePercent => 'Enter a premium percentage';

  @override
  String get r3FinanceQuoteDirection => 'Direction';

  @override
  String get r3FinanceQuotePremium => 'Premium';

  @override
  String get r3FinanceQuoteDiscount => 'Discount';

  @override
  String r3FinanceQuotePremiumField(String currency) {
    return 'Amount · $currency';
  }

  @override
  String get r3FinanceQuotePercentField => '% of remaining value';

  @override
  String get r3FinanceQuotePercentError =>
      'Enter a percentage from 0 to 1000 with up to 2 decimals';

  @override
  String get r3FinanceQuoteRangeError =>
      'A discount can’t exceed the remaining value, and the price must stay within the supported range';

  @override
  String get r3FinanceQuoteSettlement => 'Settlement';

  @override
  String get r3FinanceQuoteRef => 'Remaining value';

  @override
  String get r3FinanceQuoteDeal => 'Suggested price';

  @override
  String get r3FinanceQuoteFeesRow => 'Total fee';

  @override
  String financeRoundingNote(String rate, String source) {
    return '$rate\n$source. Conversions are for reference only.';
  }

  @override
  String financeCycleEndError(String date) {
    return 'The selected cycles must end on $date';
  }

  @override
  String financeCycleCountOption(int count, int months) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cycles',
      one: '1 cycle',
    );
    String _temp1 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: '$months months per cycle',
      one: '1 month per cycle',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String financeExtendFromDue(String date) {
    return 'Extends from the current due date, $date.';
  }

  @override
  String financeNextRenewalPrice(String billing, String currency) {
    return 'Next renewal price: $billing';
  }

  @override
  String financeArchivedName(String name, String archived) {
    String _temp0 = intl.Intl.selectLogic(archived, {
      'yes': '$name · Archived',
      'other': '$name',
    });
    return '$_temp0';
  }

  @override
  String financeValidPaymentsNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count records',
      one: '1 record',
    );
    return '$_temp0; deleted ones are excluded.';
  }

  @override
  String financePaymentGroupNote(String group) {
    return 'Group: $group. Account bills aren’t included.';
  }

  @override
  String financeVoidedName(String name, String voided) {
    String _temp0 = intl.Intl.selectLogic(voided, {
      'yes': '$name · Voided',
      'other': '$name',
    });
    return '$_temp0';
  }

  @override
  String financePaymentSummary(String date, String account, String due) {
    String _temp0 = intl.Intl.selectLogic(account, {
      'yes': '$date · Past account bill, counted once',
      'other': '$date · Due date: $due',
    });
    return '$_temp0';
  }

  @override
  String financePrepaidRenewalType(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cycles',
      one: '1 cycle',
    );
    return 'Prepaid renewal · $_temp0';
  }

  @override
  String financePaymentPeriodRange(String start, String end) {
    return '$start to $end';
  }

  @override
  String financeFxOverview(String currency, String date) {
    return '$currency reference · Manual rates $date';
  }

  @override
  String financeManagedCount(int count) {
    return 'Unarchived servers: $count  ›';
  }

  @override
  String financeRenewalEventNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count prepaid renewals',
      one: '1 prepaid renewal',
    );
    return '$_temp0 · Today and the next 29 days';
  }

  @override
  String financeRecentPaymentNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count payments',
      one: '1 payment',
    );
    return '$_temp0 · Today and the previous 29 days';
  }

  @override
  String financeIncompleteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count servers with incomplete costs / expired service',
      one: '1 server with incomplete costs / expired service',
    );
    return '$_temp0';
  }

  @override
  String financeSliceLabel(String label, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count servers',
      one: '1 server',
    );
    return '$label · $_temp0';
  }

  @override
  String uiFinanceDisplayChip(String currency) {
    return 'Show $currency';
  }

  @override
  String get uiFinanceCurrencyNote =>
      'Only changes how totals are converted and shown. Original-currency records stay unchanged.';

  @override
  String get uiFinanceTileRemaining => 'Remaining value';

  @override
  String get uiFinanceTileRenewals => 'Renewals in 30 days';

  @override
  String uiFinanceBannerMissingFx(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count amounts have no exchange rate and are left out of totals',
      one: '1 amount has no exchange rate and is left out of totals',
    );
    return '$_temp0';
  }

  @override
  String uiFinanceGapMissingFx(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count missing rates',
      one: '1 missing rate',
    );
    return '$_temp0';
  }

  @override
  String uiFinanceGapUnknown(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unknown amounts',
      one: '1 unknown amount',
    );
    return '$_temp0';
  }

  @override
  String uiFinanceMonthShort(String month) {
    String _temp0 = intl.Intl.selectLogic(month, {
      '1': 'Jan',
      '2': 'Feb',
      '3': 'Mar',
      '4': 'Apr',
      '5': 'May',
      '6': 'Jun',
      '7': 'Jul',
      '8': 'Aug',
      '9': 'Sep',
      '10': 'Oct',
      '11': 'Nov',
      '12': 'Dec',
      'other': '$month',
    });
    return '$_temp0';
  }

  @override
  String get uiFinanceForecastBasis => 'At current renewal prices';

  @override
  String get uiFinanceToolsHeader => 'Records & tools';

  @override
  String uiFinanceServerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count servers',
      one: '1 server',
    );
    return '$_temp0';
  }

  @override
  String get uiFinanceFootnote =>
      'Uses renewal prices and manual rates. For reference only; not actual bills.';

  @override
  String get uiFinanceVoidedPill => 'Deleted';

  @override
  String get uiFinanceArchivedPill => 'Archived';

  @override
  String get uiFinanceAccountPill => 'Account bill';

  @override
  String financeForecastMonth(int year, int month, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count renewals',
      one: '1 renewal',
    );
    return '$year-$month · $_temp0';
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
      other: ' · $missing items missing exchange rates',
      one: ' · 1 item missing an exchange rate',
      zero: '',
    );
    String _temp1 = intl.Intl.pluralLogic(
      unknown,
      locale: localeName,
      other: ' · $unknown unknown amounts',
      one: ' · 1 unknown amount',
      zero: '',
    );
    return '$amount $currency$_temp0$_temp1';
  }

  @override
  String financeDetailScope(String label, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unarchived servers',
      one: '1 unarchived server',
    );
    return '$label · $_temp0';
  }

  @override
  String financeAmountMetric(String amount, String currency, String metric) {
    String _temp0 = intl.Intl.selectLogic(metric, {
      'value': '$amount $currency remaining value',
      'other': '$amount $currency / month reference',
    });
    return '$_temp0';
  }

  @override
  String financeDueDateValue(String date) {
    return 'Due date: $date';
  }

  @override
  String financeRenewalsMonthTitle(int year, int month) {
    return 'Renewals in $year-$month';
  }

  @override
  String financeRenewalsScopeNote(int count, String group) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count renewals',
      one: '1 renewal',
    );
    return '$_temp0 · $group · Forecast at current renewal prices, not recorded payments.';
  }

  @override
  String financeRenewalEventDate(String date, int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: '$months-month cycle',
      one: '1-month cycle',
    );
    return '$date · $_temp0';
  }

  @override
  String financeExpiredDate(String date) {
    return 'Expired on $date. This doesn’t imply downtime.';
  }

  @override
  String financePngSavedPath(String path) {
    return 'PNG saved:\n$path';
  }

  @override
  String get financeRenewalDateError =>
      'Renewal requires a valid cycle and original due date.';

  @override
  String get financeAnchorMismatch =>
      'The service period anchor doesn’t match the due date. Check the details.';

  @override
  String get financeDueRangeError =>
      'The due date is outside the supported range.';

  @override
  String get financeTrialInputError =>
      'Choose valid dates and a cycle. Estimates are limited to a 100-year range.';

  @override
  String get financePeriodRangeError =>
      'The service period is outside the supported range.';

  @override
  String get financeTrialRangeError =>
      'Estimates are limited to a 100-year range.';

  @override
  String get financeUnsupportedCurrency =>
      'The display currency isn’t supported.';

  @override
  String get financeInvalidRate =>
      'Exchange rates must be positive, with at most 9 integer digits and 8 decimal places.';

  @override
  String get financeMissingRateDate => 'Enter the manual exchange rate date.';

  @override
  String get financeExportDisclaimer =>
      'A price-based estimate of unused service time, not a refund promise or sale price.';

  @override
  String get financeExportHeading =>
      'vps tell you · Estimate · No ledger entry';

  @override
  String get financeExportFooter =>
      'Independent estimate · Image contains calculation information only';

  @override
  String financeExportValue(String amount, String currency) {
    return 'Remaining value: $amount $currency';
  }

  @override
  String financeExportValuationDate(String date) {
    return 'Valuation date: $date';
  }

  @override
  String financeExportPeriod(String period, String start, String end) {
    return '$period: $start to $end (end date excluded)';
  }

  @override
  String financeExportPeriodRemaining(
    String period,
    int remaining,
    int days,
    String percent,
  ) {
    return '$period: $remaining / $days days remaining · $percent';
  }

  @override
  String financeExportServiceRemaining(String due, int days) {
    return 'Service due date: $due; remaining service days: $days';
  }

  @override
  String financeExportRenewalDaily(String renewal, String daily) {
    return 'Renewal price / cycle: $renewal; daily average for the shown period: $daily';
  }

  @override
  String financeExportFuturePeriods(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count future periods',
      one: '1 future period',
    );
    return 'Includes $_temp0. Progress shows only the period above.';
  }

  @override
  String financeExportDue(String date) {
    return 'Service due date: $date';
  }

  @override
  String financeExportRemainingDays(int days) {
    return 'Remaining service days: $days';
  }

  @override
  String financeExportRenewal(String renewal) {
    return 'Renewal price / cycle: $renewal';
  }

  @override
  String financeExportDaily(String daily) {
    return 'Daily average for the shown period: $daily';
  }

  @override
  String get billingCostUnknown => 'Cost unknown';

  @override
  String billingMeteredAmount(String amount) {
    return '$amount/mo est.';
  }

  @override
  String billingAnnualAmount(String amount) {
    return '$amount/year';
  }

  @override
  String billingMonthlyAmount(String amount, int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: '$months months',
      one: '1 month',
    );
    return '$amount/$_temp0';
  }

  @override
  String get backupExcludedSecrets =>
      'Passwords, private keys, passphrases, tokens, credential metadata, and secure-storage references';

  @override
  String get backupExcludedConnections => 'SSH settings and host trust';

  @override
  String get backupExcludedNotes =>
      'Command snippets, server notes, and payment notes';

  @override
  String get backupExcludedPreferences =>
      'Reminder rules, notification schedules, and app preferences';

  @override
  String get backupInvalidJson => 'The backup isn’t valid JSON';

  @override
  String get backupUnsupportedFormat =>
      'Unsupported ledger backup format or version';

  @override
  String get backupInvalidCollections =>
      'Invalid backup collection types or counts';

  @override
  String get backupDuplicateIds => 'The backup contains duplicate record IDs';

  @override
  String get backupGroupNameConflict => 'Conflicting group names in the backup';

  @override
  String get backupMissingGroup =>
      'A server refers to a group that doesn’t exist';

  @override
  String get backupInvalidServer => 'Server field validation failed';

  @override
  String get backupAnchorMismatch =>
      'The renewal anchor and due date don’t match';

  @override
  String get backupInvalidPaymentPeriod => 'Invalid payment service period';

  @override
  String get backupAccountBillMismatch =>
      'Inconsistent independent account bill fields';

  @override
  String get backupInvalidServerPayment => 'Invalid server payment link';

  @override
  String get backupPaymentDateConflict =>
      'An active payment conflicts with the server dates';

  @override
  String get backupServiceDateMismatch =>
      'Service periods don’t match the server dates';

  @override
  String get backupDuplicateInitialPeriod =>
      'A server has duplicate initial service periods';

  @override
  String get backupInvalidPeriodPayment =>
      'Invalid service-period payment link';

  @override
  String get backupOverlappingPeriods =>
      'A server has overlapping service periods';

  @override
  String get backupIncompletePaymentPeriod =>
      'An active payment is missing its complete service period';

  @override
  String get backupPaymentCycleMismatch =>
      'A payment service period doesn’t match the renewal cycle';

  @override
  String get backupInitialPeriodMismatch =>
      'The initial service period is missing or doesn’t match the original dates';

  @override
  String get backupInitialPeriodOutOfRange =>
      'The initial service period is outside the supported date range';

  @override
  String get backupPeriodsNotContinuous =>
      'Active service periods must be continuous';

  @override
  String get backupPeriodsDoNotCoverDue =>
      'Active service periods don’t cover the current due date';

  @override
  String get backupInvalidRates => 'Invalid reference exchange rates';

  @override
  String get restoreRequiresEmptyLedger =>
      'Restore requires an empty ledger. Existing data is unchanged.';

  @override
  String get restoreMissingRateSettings =>
      'Reference rate settings are missing. The restore was rolled back.';

  @override
  String get backupGroups => 'groups';

  @override
  String get backupServersIncludingArchived => 'servers (including archived)';

  @override
  String get backupPaymentsIncludingVoided => 'payments (including voided)';

  @override
  String get backupServicePeriods => 'service periods';

  @override
  String restoreExistingRecords(String p0) {
    return 'The destination ledger already contains $p0';
  }

  @override
  String get backupInvalidFields =>
      'Backup fields are missing, unknown, or have the wrong type';

  @override
  String get backupInvalidText => 'Invalid text field in the backup';

  @override
  String get backupNumberOutOfRange =>
      'An integer or amount in the backup is out of range';

  @override
  String get backupInvalidEnum => 'Invalid enum value in the backup';

  @override
  String get backupInvalidDate => 'Invalid date in the backup';

  @override
  String get backupTimeRequiresUtc =>
      'Backup timestamps must use canonical UTC format';

  @override
  String get backupInvalidTime => 'Invalid timestamp in the backup';

  @override
  String get paymentPeriodsLockFields =>
      'This server has payment service periods, so its dates, cycles, and billing type can’t be edited directly. Review its payments and safely void eligible records first.';

  @override
  String get invalidGroupName =>
      'Enter a group name of 1–40 characters. The reserved name “未分组” isn’t allowed.';

  @override
  String get demoRequiresEmptyLedger =>
      'Demo data can be loaded only into an empty ledger';

  @override
  String get futureRateDate => 'The exchange-rate date can’t be in the future';

  @override
  String get invalidPaymentId => 'Invalid payment ID';

  @override
  String get invalidPaidAmount =>
      'Enter a valid amount actually paid. Enter 0 for free.';

  @override
  String get futurePaymentDate => 'The payment date can’t be in the future';

  @override
  String get notesTooLong => 'Notes can contain up to 4,000 characters';

  @override
  String get paymentAlreadyVoided =>
      'This payment is already voided. Check the details and create a new record.';

  @override
  String get paymentIdContentMismatch =>
      'This payment ID has different details. Don’t enter it again.';

  @override
  String get confirmProviderPayment =>
      'Confirm that you paid the provider and checked the amount and dates';

  @override
  String get invalidRenewalCycleCount => 'Select 1–3 valid renewal cycles';

  @override
  String get renewalNeedsPrepaidDate =>
      'Only prepaid services with a known due date can be renewed';

  @override
  String get renewalDateMismatch =>
      'The new due date doesn’t match the selected cycles and original renewal anchor';

  @override
  String get duplicateExpiryPayment =>
      'A payment already exists for this due date. Don’t enter it again.';

  @override
  String get invalidAccountName => 'Use 1–80 characters for the account name';

  @override
  String get invalidOptionalBillingPeriod =>
      'For an optional billing period, enter valid start and end dates. The end must be after the start.';

  @override
  String get invalidCredentialDetails => 'Invalid credential details';

  @override
  String get secretWriteNotPrepared => 'The secret isn’t ready to be saved';

  @override
  String get chooseOtherCredential => 'Choose a different credential';

  @override
  String get invalidSshConfiguration =>
      'Enter a valid host, port, and explicit username';

  @override
  String get verificationCancelled => 'Verification canceled';

  @override
  String get completeLocalResources =>
      'Complete and confirm all six local resource fields first';

  @override
  String get securityOperationIncomplete =>
      'The security operation didn’t complete. Try again.';

  @override
  String get serverNameRange => 'Use 1–80 characters for the name';

  @override
  String get serverVendorRange => 'Use 1–80 characters for the provider';

  @override
  String get serverHostFormat =>
      'Enter an IP address or domain without a protocol, port, path, or username';

  @override
  String get serverUnsupportedCurrency => 'Unsupported currency';

  @override
  String get serverValidAmount => 'Enter a valid amount. Enter 0 for free.';

  @override
  String get serverValidCycle => 'Select a valid cycle';

  @override
  String get serverInvalidDate => 'Invalid date';

  @override
  String get serverDueAfterStart => 'The due date must be after the start date';

  @override
  String get resourceMonth => 'Month';

  @override
  String get resourceQuarter => 'Quarter';

  @override
  String get resourceYear => 'Year';

  @override
  String get resourceValidIp =>
      'Enter a valid IPv4 or IPv6 address. Unspecified addresses aren’t allowed.';

  @override
  String get resourceValidHostname =>
      'Enter a valid hostname without a protocol, port, or path';

  @override
  String get resourceValidVcpu =>
      'Enter a whole number of vCPUs from 1 to 65,536';

  @override
  String get resourceValidRam => 'Enter a valid positive memory capacity';

  @override
  String get resourceValidDisk => 'Enter a valid positive disk capacity';

  @override
  String get resourceValidTraffic =>
      'Enter a valid positive traffic quota, or explicitly select unlimited';

  @override
  String get resourceValidPeriod =>
      'Choose a monthly, quarterly, yearly, or unset traffic period';

  @override
  String get resourceTooLarge => 'Local resource configuration is too large';

  @override
  String get resourceInvalidFields => 'Invalid local resource fields';

  @override
  String get resourceUnlimitedTraffic => 'Unlimited traffic';

  @override
  String get resourceUnknownTraffic => 'Traffic unknown';

  @override
  String resourceTrafficQuota(String p0) {
    return '$p0 traffic';
  }

  @override
  String get resourcePeriodNotSet => 'Period not set';

  @override
  String resourceEveryPeriod(String p0) {
    return 'Per $p0';
  }

  @override
  String resourceDiskQuota(String p0) {
    return '$p0 disk';
  }

  @override
  String get resourceFieldValidIp =>
      'Enter a valid IPv4 or IPv6 address, not an all-zero address';

  @override
  String get r6IpValidIpv4 =>
      'Enter a valid IPv4 address such as 192.0.2.1. All-zero addresses aren’t allowed.';

  @override
  String get r6IpValidIpv6 =>
      'Enter a valid IPv6 address such as 2001:db8::1, without brackets or a zone.';

  @override
  String get resourceFieldValidVcpu =>
      'Enter a whole-number core count from 1 to 65,536';

  @override
  String get resourceFieldValidBytes =>
      'Enter a positive capacity that resolves to a whole number of bytes';

  @override
  String get resourceCapacity => 'Capacity';

  @override
  String resourceUnitSemantics(String p0) {
    return '$p0 unit, base 1024';
  }

  @override
  String get resourceUnit => 'Unit';

  @override
  String get resourceTrafficPeriod => 'Traffic period';

  @override
  String get resourcePeriod => 'Period';

  @override
  String get resourceNewPeriodHelp =>
      'New records default to monthly; you can change it.';

  @override
  String get resourcePeriodHelp =>
      'The period is separate from the capacity unit. Choose Not set if unknown.';

  @override
  String get resourceHardware => 'Hardware details';

  @override
  String get resourceLocalHelp =>
      'Capacities use 1024 units. Choosing a package fills these in, and you can still edit them.';

  @override
  String get resourceIpAddress => 'IP address';

  @override
  String get r6IpIpv4 => 'IPv4';

  @override
  String get r6IpIpv6 => 'IPv6';

  @override
  String get resourceHostname => 'Hostname';

  @override
  String get resourceDiskCapacity => 'Disk capacity';

  @override
  String get resourceTrafficQuotaLabel => 'Traffic quota';

  @override
  String get resourceUnlimitedHelp =>
      'Turn on only if the plan is explicitly unlimited.';

  @override
  String get resourceMemoryCapacity => 'Memory capacity';

  @override
  String get resourceVcpuCount => 'vCPU count';

  @override
  String get serverFilterTitle => 'Filter Servers';

  @override
  String get serverGroup => 'Group';

  @override
  String get serverAllGroups => 'All groups';

  @override
  String get serverDueStatus => 'Due status';

  @override
  String get serverAllStatuses => 'All statuses';

  @override
  String get serverExpired => 'Expired';

  @override
  String get serverDueNext30 => 'Due in the next 30 days';

  @override
  String get serverCostDateUnknown => 'Cost / due date unknown';

  @override
  String get serverApplyFilters => 'Apply filters';

  @override
  String serverLedgerCount(String p0) {
    return 'Servers: $p0 · Local ledger';
  }

  @override
  String get serverReloadLocal => 'Reload local ledger';

  @override
  String get serverReloadedLocal =>
      'Local ledger reloaded. Remote status wasn’t checked.';

  @override
  String get serverAdd => 'Add Server';

  @override
  String get serverFirstTitle => 'Your first VPS\nstarts here';

  @override
  String get serverFirstDescription =>
      'Due dates, costs, and connections in one place.';

  @override
  String get serverAddFirst => 'Add Your First Server';

  @override
  String get serverLoadDemoQuestion => 'Load demo data?';

  @override
  String get serverLoadDemoHelp =>
      'Adds 4 demo records with reserved addresses. Nothing connects to a server, and you can archive them anytime.';

  @override
  String get serverLoadDemo => 'Load Demo';

  @override
  String get serverViewDemo => 'View Demo Data First';

  @override
  String get serverManualStartHelp =>
      'Already have servers? Start by recording them manually.';

  @override
  String get serverSearchHint =>
      'Search name, address, provider, purpose, or region';

  @override
  String get serverClearSearch => 'Clear search';

  @override
  String get serverAll => 'All';

  @override
  String get serverFavorites => 'Favorites';

  @override
  String serverFilterLabel(String p0) {
    return 'Filters$p0';
  }

  @override
  String get serverFilterSelectedSuffix => ' · Applied';

  @override
  String get serverExpiryNeedsCheck => 'Due dates need checking';

  @override
  String serverExpiryCounts(String p0, String p1) {
    return 'Expired: $p0 · Due within 30 days: $p1';
  }

  @override
  String get serverFavoriteServers => 'Favorite servers';

  @override
  String get serverAllServers => 'All servers';

  @override
  String get serverSort => 'Sort';

  @override
  String get serverSortFavorites => 'Favorites first';

  @override
  String get serverSortDue => 'By due date';

  @override
  String get serverSortName => 'By name';

  @override
  String get serverSortUpdated => 'By last updated';

  @override
  String get serverNoUnarchived => 'No unarchived servers';

  @override
  String get serverNoMatches => 'No matching records';

  @override
  String get serverNoMatchesHelp =>
      'Try changing the filters. You can restore archived records in Settings.';

  @override
  String get uiServersDueSoon => 'Due in 30 days';

  @override
  String get uiServersArchive => 'Archive';

  @override
  String get uiServersReset => 'Reset';

  @override
  String uiServersShowCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Show $count Servers',
      one: 'Show 1 Server',
    );
    return '$_temp0';
  }

  @override
  String get uiServersRowHint =>
      'Swipe left or long-press a server for quick actions';

  @override
  String get serverClearFilters => 'Clear Filters';

  @override
  String get serverListObservationHelp =>
      'Servers aren’t monitored. Days left use the device date.';

  @override
  String get serverCostsMissing => 'Add cost details';

  @override
  String get serverMeteredBilling => 'Metered billing';

  @override
  String get serverDueUnknown => 'Due date unknown';

  @override
  String serverExpiredDays(int p0) {
    String _temp0 = intl.Intl.pluralLogic(
      p0,
      locale: localeName,
      other: 'Expired $p0 days ago · Check status',
      one: 'Expired 1 day ago · Check status',
    );
    return '$_temp0';
  }

  @override
  String get serverDueToday => 'Expires today';

  @override
  String serverDueInDays(int p0) {
    String _temp0 = intl.Intl.pluralLogic(
      p0,
      locale: localeName,
      other: 'Expires in $p0 days',
      one: 'Expires in 1 day',
    );
    return '$_temp0';
  }

  @override
  String get serverDemo => 'Demo';

  @override
  String get serverLocalUnqueried =>
      'Local record · Runtime status not checked';

  @override
  String get serverNotEntered => 'Not entered';

  @override
  String get resourceUnlimitedConfirmed => 'Unlimited (confirmed)';

  @override
  String get resourceCardHelp =>
      'Local data only; a package only pre-fills it.';

  @override
  String get serverSavedDisplayStale =>
      'Changes saved, but the screen hasn’t updated yet';

  @override
  String get serverReloadBeforeEditing =>
      'Reload the local ledger before making more changes. Don’t submit again. Your existing data won’t be cleared.';

  @override
  String get serverReloadStillFailed =>
      'Couldn’t reload. Saved changes are kept. Try reloading later.';

  @override
  String get serverReload => 'Reload';

  @override
  String get serverArchiveQuestion => 'Archive this server record?';

  @override
  String serverArchiveHelp(String p0) {
    return '$p0\n\nArchiving hides the record from the server list and current cost statistics. Payment history is kept. Restore it in Settings > Archived Records. This doesn’t stop or destroy the server, and it doesn’t stop provider billing.';
  }

  @override
  String get serverArchiveLocal => 'Archive Local Record';

  @override
  String get serverArchived =>
      'Archived. Remote resources and billing are unchanged.';

  @override
  String get serverUndo => 'Undo';

  @override
  String get serverUndoArchiveFailed =>
      'Couldn’t undo. Check Archived Records in Settings.';

  @override
  String get serverMissingDetails => 'Not yet added';

  @override
  String get serverDetails => 'Server Details';

  @override
  String get serverRecordUnavailable =>
      'This record is unavailable. Go back and try again.';

  @override
  String get serverRemoveFavorite => 'Remove from Favorites';

  @override
  String get serverSetFavorite => 'Add to Favorites';

  @override
  String get serverMoreActions => 'More Actions';

  @override
  String get serverDemoWarning =>
      'Demo record · Reserved address; no real server connection';

  @override
  String get serverBasicInfo => 'Basic details';

  @override
  String get serverEdit => 'Edit';

  @override
  String get serverHostAddress => 'Host address';

  @override
  String get r7DetailSavedAddress => 'Saved address';

  @override
  String get serverCopyHost => 'Copy Address';

  @override
  String get serverHostCopied => 'Address copied';

  @override
  String get serverCopyHostFailed => 'Couldn’t copy the address. Try again.';

  @override
  String get serverOperatingSystem => 'Operating system';

  @override
  String get serverGroupPurpose => 'Group / purpose';

  @override
  String get serverSpecifications => 'Specifications';

  @override
  String get serverEditHardware => 'Edit Hardware';

  @override
  String get serverCostExpiry => 'Costs and due date';

  @override
  String get serverMonthlyEstimate => 'Monthly cost estimate';

  @override
  String get serverRenewalAmount => 'Renewal amount';

  @override
  String get serverRenewalCycle => 'Renewal cycle';

  @override
  String serverMonths(int p0) {
    String _temp0 = intl.Intl.pluralLogic(
      p0,
      locale: localeName,
      other: '$p0 months',
      one: '1 month',
    );
    return '$_temp0';
  }

  @override
  String get serverServiceStart => 'Service start date';

  @override
  String get serverUnknown => 'Unknown';

  @override
  String get serverServiceDue => 'Service due date';

  @override
  String get serverUnknownCostHelp =>
      'An amount left blank is never counted as 0.';

  @override
  String get serverMeteredValueHelp =>
      'Metered billing is a monthly estimate; no remaining value is calculated.';

  @override
  String get serverRenewalValueHelp =>
      'Remaining value is a reference at the renewal price, not a refund or resale price.';

  @override
  String get serverReminderPlan => 'Reminders & Usage Plan';

  @override
  String get serverRemindersOff => 'Reminders off';

  @override
  String get serverRemainingValue => 'Remaining value';

  @override
  String get serverUnknownValueHelp =>
      'Dates or cost details are incomplete. Remaining value is unknown, not 0.';

  @override
  String get serverRecordPayment => 'Record Payment';

  @override
  String get serverUseForCalculation => 'Calculate using these details';

  @override
  String get serverViewPayments => 'View payment records';

  @override
  String get serverConnectionsControl => 'Connections and controls';

  @override
  String get serverSshSettings => 'SSH Connection Settings';

  @override
  String get serverSshSettingsDescription =>
      'Connection address, port, username, and credentials';

  @override
  String get serverConnectSsh => 'Connect with SSH';

  @override
  String get serverTcpTest => 'TCP Test';

  @override
  String get serverPower => 'Server power';

  @override
  String get serverConnectionSafety =>
      'Verify the host fingerprint the first time you connect. Shutting down or restarting doesn’t stop billing.';

  @override
  String get serverNotes => 'Notes';

  @override
  String serverSavedMetadata(String p0, String p1) {
    return 'Saved locally: $p0\nServer ID: $p1';
  }

  @override
  String get uiDetailCopy => 'Copy';

  @override
  String get uiDetailMenuValuation => 'Use for Remaining-Value Estimate';

  @override
  String get uiDetailPurpose => 'Purpose';

  @override
  String get uiDetailRegion => 'Region';

  @override
  String uiDetailDueOn(String date) {
    return 'Due $date';
  }

  @override
  String uiDetailConverted(String currency) {
    return 'In $currency';
  }

  @override
  String get uiDetailDaily => 'Daily';

  @override
  String get uiDetailRemainingDays => 'Days left';

  @override
  String get uiDetailPayments => 'Payments';

  @override
  String get uiDetailValuation => 'Estimate';

  @override
  String get uiDetailFillIn => 'Fill In';

  @override
  String get uiDetailHostKey => 'Host key';

  @override
  String get uiDetailHostKeyTrusted => 'Verified';

  @override
  String get uiDetailHostKeyFirstUse => 'Verified on first connect';

  @override
  String get uiDetailNotConfigured => 'Not set up';

  @override
  String get uiDetailNeedSshTitle => 'SSH isn’t set up';

  @override
  String uiDetailNeedSshMessage(String name) {
    return 'Set the address, port, username, and credential for $name before connecting or using power actions.';
  }

  @override
  String get uiDetailGoConfigure => 'Set Up';

  @override
  String get uiDetailArchivedUnavailable =>
      'This action isn’t available for archived servers.';

  @override
  String get uiDetailNotPrepaid =>
      'Only prepaid servers can record renewal payments.';

  @override
  String get uiDetailCannotRenew =>
      'The due date or renewal cycle is incomplete, so a renewal payment can’t be recorded yet. Fill in the cost details first.';

  @override
  String get uiDetailReadOnly =>
      'Local data is still loading or busy, so you can’t record a payment right now. Reload first.';

  @override
  String get uiDetailQuickSsh => 'SSH';

  @override
  String get uiDetailQuickPayment => 'Payment';

  @override
  String get uiDetailQuickPower => 'Power';

  @override
  String get r2DetailMetricValue => 'Value left';

  @override
  String get r2DetailMetricDays => 'Days left';

  @override
  String get r2DetailMetricDaily => 'Daily';

  @override
  String serverRequiredField(String p0) {
    return 'Enter $p0';
  }

  @override
  String get serverAmountPrecision =>
      'Enter a valid amount with up to two decimal places';

  @override
  String get serverDateExample => 'Enter a valid date, for example 2026-10-06';

  @override
  String get serverBillingType => 'Billing type';

  @override
  String get serverEveryYear => 'Every year';

  @override
  String serverEveryMonths(int p0) {
    String _temp0 = intl.Intl.pluralLogic(
      p0,
      locale: localeName,
      other: 'Every $p0 months',
      one: 'Every month',
    );
    return '$_temp0';
  }

  @override
  String get serverHalfYear => '6 mo';

  @override
  String get serverTwoYears => '2 yr';

  @override
  String get serverThreeYears => '3 yr';

  @override
  String get serverAmount => 'Amount';

  @override
  String get serverOriginalCurrency => 'Original currency';

  @override
  String get serverCurrency => 'Currency';

  @override
  String get serverMonthlyCostEstimate => 'Monthly cost estimate';

  @override
  String serverRenewalPriceHelp(String p0) {
    return 'Renewal amount: $p0. Record actual payments separately.';
  }

  @override
  String get serverStartDate => 'Start date';

  @override
  String get serverDueDate => 'Due date';

  @override
  String get serverOptionalStart => 'Service start date (optional)';

  @override
  String get serverOptionalDue => 'Service due date (optional)';

  @override
  String get serverManualAdd => 'Add manually';

  @override
  String get serverEditTitle => 'Edit Server';

  @override
  String get serverFormHelp =>
      'Saved on this device only; remote servers are unchanged.';

  @override
  String get serverBasicData => 'Basic details';

  @override
  String get serverName => 'Server name';

  @override
  String get serverProvider => 'Provider';

  @override
  String get serverProviderExample =>
      'For example: BandwagonHost / Your provider';

  @override
  String get serverNewHostHelp =>
      'For new records, leaving this blank uses the IP or hostname from hardware details. Set the SSH connection address separately.';

  @override
  String get serverSavedHostHelp =>
      'This address is saved separately. Editing hardware doesn’t change it. Set the SSH connection address separately.';

  @override
  String get serverOptionalPurpose => 'Purpose (optional)';

  @override
  String get serverOptionalRegion => 'Region (optional)';

  @override
  String get serverOptionalOs => 'Operating system (optional)';

  @override
  String get serverOptionalSpec => 'Additional specifications (optional)';

  @override
  String get serverSpecExample => 'For example: CPU model, network bandwidth';

  @override
  String get serverCostDetails => 'Cost details';

  @override
  String get serverPaymentLockHelp =>
      'Billing type, cycle, and dates are locked because payments exist.';

  @override
  String get serverCostUnknownOption => 'Cost unknown · Add later';

  @override
  String get serverPrepaidOption => 'Prepaid · Renew by cycle';

  @override
  String get serverMeteredOption => 'Metered · Monthly estimate';

  @override
  String get serverPrepaid => 'Prepaid';

  @override
  String get serverMetered => 'Metered';

  @override
  String get serverDatesHelp =>
      'Due date defaults to start date plus cycle; you can change it.';

  @override
  String get serverAmountHelp =>
      '0 means free; choose Unknown if unsure. No payment is recorded.';

  @override
  String get serverOptionalNotes => 'Notes (optional)';

  @override
  String get serverNotesSafety =>
      'Notes aren’t encrypted. Don’t store passwords, keys, or tokens.';

  @override
  String get serverSave => 'Save Server';

  @override
  String get uiFormProvider => 'Provider';

  @override
  String get r7FormProviderNone => 'None';

  @override
  String get r7FormProviderNew => 'New Provider…';

  @override
  String get uiFormPurpose => 'Purpose';

  @override
  String get uiFormRegion => 'Region';

  @override
  String get uiFormSpec => 'Spec note';

  @override
  String get uiFormOptional => 'Optional';

  @override
  String get uiFormNameHint => 'e.g. HK-01';

  @override
  String get uiFormDone => 'Done';

  @override
  String get uiFormSetUnknown => 'Set Unknown';

  @override
  String get uiFormPickDate => 'Choose date';

  @override
  String get uiFormUnknownCostFootnote => 'Unknown cost is left out of totals.';

  @override
  String get uiFormVcpuDecrease => 'Decrease vCPU';

  @override
  String get uiFormVcpuIncrease => 'Increase vCPU';

  @override
  String get uiFormCollapse => 'Collapse hardware details';

  @override
  String get uiFormExpand => 'Expand hardware details';

  @override
  String get uiFormMemory => 'Memory';

  @override
  String get uiFormDisk => 'Disk';

  @override
  String get uiFormTraffic => 'Traffic';

  @override
  String get uiFormBillingPrepaid => 'Prepaid';

  @override
  String get uiFormBillingMetered => 'Metered';

  @override
  String get serverWaitForOperation =>
      'Wait for the current operation to finish';

  @override
  String get serverReloadSavedFirst => 'Reload the saved ledger first';

  @override
  String get connectionBrowserTcpUnsupported =>
      'Browsers can’t open native TCP connections. Use the native app.';

  @override
  String get connectionHostKeyUnverified =>
      'Couldn’t verify the full host key. Connection blocked.';

  @override
  String get connectionHandshakeUnsupported =>
      'Unsupported SSH handshake format or size';

  @override
  String get tcpValidIpv6 => 'Enter a valid IPv6 address';

  @override
  String get tcpValidHost =>
      'Enter an IP address or domain without a protocol, port, or path';

  @override
  String get tcpValidPort => 'Enter a port from 1 to 65,535';

  @override
  String get tcpSource => 'TCP connection test from this device';

  @override
  String get tcpConnected => 'TCP connection succeeded';

  @override
  String get tcpRefused => 'Connection refused';

  @override
  String get tcpTimedOut => 'Connection timed out';

  @override
  String get tcpCancelled => 'Test canceled';

  @override
  String get tcpFailed => 'Connection failed (network or address unavailable)';

  @override
  String get tcpTimeoutPositive => 'Timeout must be greater than 0';

  @override
  String get tcpSingleTarget => 'Single-Target TCP Test';

  @override
  String get tcpTestExplanation =>
      'Only checks whether a TCP connection opens; no data is sent. Success doesn’t mean SSH login works or the service is healthy.';

  @override
  String get tcpAddress => 'IP / domain';

  @override
  String get connectionPort => 'Port';

  @override
  String tcpTestingTarget(String p0) {
    return 'Testing $p0';
  }

  @override
  String get tcpCancel => 'Cancel Test';

  @override
  String get tcpStart => 'Start Test';

  @override
  String tcpTimeoutHelp(int p0) {
    String _temp0 = intl.Intl.pluralLogic(
      p0,
      locale: localeName,
      other: '$p0 seconds',
      one: '1 second',
    );
    return 'Each test lasts up to $_temp0. Changing the target, leaving this page, or putting the app in the background cancels it.';
  }

  @override
  String tcpTarget(String p0) {
    return 'Target: $p0';
  }

  @override
  String tcpActualAddress(String p0) {
    return 'Actual address: $p0';
  }

  @override
  String tcpResultSource(String p0) {
    return 'Source: $p0';
  }

  @override
  String tcpFinished(String p0) {
    return 'Finished: $p0 (device time)';
  }

  @override
  String tcpElapsed(String p0) {
    return 'Elapsed: $p0 ms';
  }

  @override
  String get tcpOneObservation =>
      'This result reflects only this test, not ongoing status.';

  @override
  String get terminalCurrentDirectory => 'Current directory';

  @override
  String get terminalListFiles => 'List files';

  @override
  String get terminalUptime => 'Uptime';

  @override
  String get terminalDiskUsage => 'Disk usage';

  @override
  String get terminalMemoryUsage => 'Memory usage';

  @override
  String get terminalCommandsWithDraft =>
      'Commands and snippets · Unsent draft';

  @override
  String get terminalCommandsSnippets => 'Commands and Snippets';

  @override
  String get terminalCommands => 'Commands';

  @override
  String get terminalControlHelp =>
      'Ctrl applies to the next key. Tap again to cancel.';

  @override
  String get terminalControlPaste =>
      'Ctrl V · Paste into draft without sending';

  @override
  String get terminalArrowUp => 'Up arrow';

  @override
  String get terminalArrowDown => 'Down arrow';

  @override
  String get terminalArrowLeft => 'Left arrow';

  @override
  String get terminalArrowRight => 'Right arrow';

  @override
  String get terminalSendUnconfirmed =>
      'Couldn’t confirm the send. The draft is kept. Check the remote state before trying again so it doesn’t run twice.';

  @override
  String get terminalSend => 'Send';

  @override
  String get terminalSendExecute => 'Send and Execute';

  @override
  String get terminalBack => 'Back to Terminal';

  @override
  String get terminalQuickCommands => 'Quick commands';

  @override
  String get terminalInsertSnippet => 'Insert Snippet';

  @override
  String get terminalDraft => 'Draft to send';

  @override
  String get terminalDraftHint => 'Edit what you want to send here';

  @override
  String get terminalPaste => 'Paste';

  @override
  String get terminalSendTo => 'Send to';

  @override
  String get terminalControlCharacterWarning =>
      'The text contains newlines, carriage returns, or control characters, so it may run immediately even without Enter.';

  @override
  String get terminalSessionChanged =>
      'The session has changed. Return to the terminal and reopen this panel. The draft isn’t sent automatically.';

  @override
  String get terminalCannotSend =>
      'Can’t send right now. Reconnecting clears the draft and doesn’t replay input.';

  @override
  String get terminalSendMeaning =>
      'Send sends the text exactly as is. Send and Execute adds Enter, and the current terminal program handles it.';

  @override
  String get connectionReadFailed =>
      'Couldn’t read the connection details. Try again.';

  @override
  String get connectionTemporary => 'Temporary connection';

  @override
  String get connectionInvalidDetails =>
      'Invalid connection details. Check the address, port, and credentials.';

  @override
  String get connectionChoosePowerTarget => 'Choose a Server for Power Control';

  @override
  String get connectionIdentityFirst =>
      'Connect to one server at a time. Your selected credentials are sent only after the host’s identity is verified.';

  @override
  String get connectionWebPreviewWarning =>
      'The web preview doesn’t support native SSH / TCP or accept real login credentials. Use the native app.';

  @override
  String get connectionReloadDetails => 'Reload Connection Details';

  @override
  String get connectionTargetServer => 'Target server';

  @override
  String get connectionTemporaryTarget =>
      'Temporary target · Settings aren’t saved';

  @override
  String get connectionDemoSuffix => ' · Demo, no connection';

  @override
  String get connectionDemoBlocked =>
      'Demo servers use reserved addresses and can’t make network connections.';

  @override
  String get connectionAddressHint => 'IPv4 / IPv6 / domain';

  @override
  String get connectionValidHost =>
      'Enter a valid host without a protocol, username, or port';

  @override
  String get connectionPortRange => 'Enter a port from 1 to 65,535';

  @override
  String get connectionUsername => 'Login username';

  @override
  String get connectionValidUsername => 'Enter a valid login username';

  @override
  String get connectionSavedCredentials => 'Saved Login Credentials';

  @override
  String get connectionChooseCredentials => 'Choose login credentials';

  @override
  String connectionUseDefaultUsername(String p0) {
    return 'Use Default Username: $p0';
  }

  @override
  String get connectionManageCredentials => 'Manage Credentials';

  @override
  String get connectionEditSavedSettings =>
      'Edit and Save SSH Settings for This Server';

  @override
  String get connectionTemporaryChangesHelp =>
      'Changes on this page apply only to this connection. Passwords or private keys come from saved credentials and aren’t entered or saved again here. The connection ends when the app enters the background. Use tmux / screen on the remote server for long-running tasks.';

  @override
  String get connectionSnippetDraftOnly =>
      'The snippet goes into a separate draft. Connecting, verification, and authentication never send it.';

  @override
  String get connectionPowerAfterConnect =>
      'After connecting, choose restart or shutdown and complete both confirmations. Powering on isn’t supported.';

  @override
  String get connectionReviewConnect => 'Review and Connect';

  @override
  String get uiConnTarget => 'Target';

  @override
  String get uiConnCredential => 'Credential';

  @override
  String get uiConnStatus => 'Status';

  @override
  String get uiConnHostKey => 'Host key';

  @override
  String get uiConnHostKeyVerified => 'Verified';

  @override
  String get uiConnHostKeyFirstUse => 'Verify on first connect';

  @override
  String get uiConnResult => 'Result';

  @override
  String get uiConnSource => 'Source';

  @override
  String get uiConnFinished => 'Finished (device)';

  @override
  String get uiConnElapsed => 'Elapsed';

  @override
  String get uiConnActualAddress => 'Actual address';

  @override
  String get uiConnMoreActions => 'More Actions';

  @override
  String get snippetFullEscapedPreview => 'Full content preview (escaped)';

  @override
  String get snippetEscapeLegend =>
      'Newlines appear as \\n, carriage returns as \\r, tabs as \\t, and other control characters as \\u{…}. Backslashes are also escaped.';

  @override
  String get snippetPreviewNoSend =>
      'Previewing and inserting never send anything. Check the target and the full draft in the terminal, then choose Send or Send and Execute.';

  @override
  String get connectionClose => 'Close';

  @override
  String get snippetInsertDraftOnly => 'Insert into Draft Only';

  @override
  String get snippetChanged =>
      'The snippet was edited or deleted. Reopen the list and try again.';

  @override
  String get snippetOperationFailed =>
      'Couldn’t complete that. Try again. Your saved content is kept.';

  @override
  String get snippetDeleteQuestion => 'Delete this local snippet?';

  @override
  String snippetDeleteHelp(String p0) {
    return 'Deletes “$p0” from this device. Servers and drafts that already include it are unchanged.';
  }

  @override
  String get snippetDelete => 'Delete Snippet';

  @override
  String get snippetChoose => 'Choose Snippet';

  @override
  String get snippetReadFailed =>
      'Couldn’t read snippets. Local data is unchanged.';

  @override
  String get snippetSelectPreviewHelp =>
      'Preview first. The snippet is only added to the draft; nothing is sent automatically.';

  @override
  String get snippetPlaintextHelp =>
      'Snippets are stored as plain text on this device. Don’t save passwords, private keys, or tokens. Choose Insert Snippet in the terminal to add one to a draft.';

  @override
  String get snippetAdd => 'Add Snippet';

  @override
  String get snippetEmptyHelp =>
      'No snippets yet. Add templates for commands you use often.';

  @override
  String snippetCharacterCount(String p0) {
    return 'Characters: $p0 · Local template';
  }

  @override
  String get snippetPreviewInsert => 'Preview and Insert into Draft';

  @override
  String get snippetFullPreview => 'Full Preview';

  @override
  String get connectionDelete => 'Delete';

  @override
  String get snippetDiscardQuestion => 'Discard snippet changes?';

  @override
  String get snippetDiscardHelp =>
      'Unsaved changes won’t be saved to the snippet.';

  @override
  String get connectionDiscardChanges => 'Discard Changes';

  @override
  String get snippetEdit => 'Edit Snippet';

  @override
  String get snippetCancelEdit => 'Cancel Snippet Editing';

  @override
  String get snippetSaveSafety =>
      'Snippets are stored as plain text. Don’t enter passwords, keys or tokens.';

  @override
  String get snippetName => 'Snippet name';

  @override
  String get snippetFullContent =>
      'Full content (preserves original newlines and control characters)';

  @override
  String get snippetContentRange =>
      'Content is required and can contain up to 16,384 characters';

  @override
  String get snippetExactContentHelp =>
      'Content is saved exactly, including whitespace and control characters. Check the full preview.';

  @override
  String get connectionSaving => 'Saving…';

  @override
  String get snippetSave => 'Save Snippet';

  @override
  String get terminalCopyFailed => 'Couldn’t copy terminal content. Try again.';

  @override
  String get terminalSelectionCopied => 'Selected terminal content copied';

  @override
  String get terminalDraftChangedPaste =>
      'The draft has changed. Tap Paste again.';

  @override
  String get terminalClipboardEmpty => 'The clipboard has no text to paste.';

  @override
  String get terminalPasteTooLong =>
      'Pasting would exceed 16,384 characters. The draft is unchanged.';

  @override
  String get terminalClipboardReadFailed =>
      'Couldn’t read the clipboard. The draft is unchanged. Tap Paste again.';

  @override
  String get terminalReplaceDraftQuestion => 'Replace the current draft?';

  @override
  String get terminalReplaceDraftHelp =>
      'The current unsent draft will be replaced. Nothing will be sent over SSH.';

  @override
  String get terminalReplaceDraft => 'Replace Draft';

  @override
  String get terminalCurrentSession => 'Current SSH Session';

  @override
  String terminalDimensions(String p0, String p1, String p2) {
    return '$p0 · $p1 columns × $p2 rows';
  }

  @override
  String get terminalSelectionHelp =>
      'Tap the terminal to type. Touch and hold, then drag to select, and use Copy. Scroll up for history; the down arrow returns to the latest output.';

  @override
  String get terminalInputHelp =>
      'Keyboard input and special keys go straight to SSH. Quick commands, snippets, and pasted text go into a separate draft first. Send doesn’t add Enter; Send and Execute does, and the current terminal program handles it. Newlines already in the text may still run. Ctrl applies to the next key; tap it again to cancel.';

  @override
  String get terminalBackgroundHelp =>
      'Ending the session, leaving, or backgrounding the app closes this page. Nothing reconnects or replays input automatically. Use tmux / screen on the remote server for long-running tasks.';

  @override
  String r2ConnDisconnectHelp(String p0) {
    return '$p0\nRemote tasks outside tmux / screen may be interrupted; the unsent draft is discarded.';
  }

  @override
  String get terminalOfflineFont =>
      'Offline font: DejaVu Sans Mono · Chinese uses device font fallback';

  @override
  String get terminalLicenses => 'Open-Source Licenses';

  @override
  String get terminalDisconnectQuestion => 'Disconnect the SSH session?';

  @override
  String get terminalDiscardExitQuestion => 'Discard the draft and exit?';

  @override
  String terminalDisconnectHelp(String p0, String p1) {
    return '$p0\nRemote tasks outside tmux / screen may be interrupted. $p1';
  }

  @override
  String get terminalDraftKeptUntilReconnect =>
      'The draft is kept for now and cleared on reconnect.';

  @override
  String get terminalDraftWillClear => 'The unsent draft will be cleared.';

  @override
  String get terminalUnsentDraftExit =>
      'The draft hasn’t been sent. It will be cleared when you exit.';

  @override
  String get terminalDisconnect => 'Disconnect';

  @override
  String get terminalDisconnectExit => 'Disconnect and Exit';

  @override
  String get terminalDiscardExit => 'Discard and Exit';

  @override
  String get terminalBackgroundDisconnected =>
      'Disconnected because the app went to the background';

  @override
  String get terminalTargetChanged => 'Disconnected because the target changed';

  @override
  String get terminalPowerMenuHelp =>
      'After connecting, choose SSH Restart or SSH Shutdown in the Terminal Menu and complete both confirmations.';

  @override
  String get terminalHostChanged => 'Host Key Changed · Authentication Blocked';

  @override
  String get terminalHostChangedHelp =>
      'This may be a reinstall or a man-in-the-middle attack. Your login credentials haven’t been sent. Verify the reason and the new host key through an independent source, such as the provider console.';

  @override
  String get terminalPreviousFingerprint => 'Previous fingerprint';

  @override
  String get terminalNoRecord => 'No record';

  @override
  String get terminalCurrentFingerprint => 'Current fingerprint';

  @override
  String get terminalRejectConnection => 'Reject Connection';

  @override
  String get terminalReverify => 'Start Independent Verification';

  @override
  String get terminalPowerFailed =>
      'Couldn’t confirm that the power command succeeded. Check the connection, remote permissions, and the provider console before trying again. It won’t be resent automatically.';

  @override
  String get terminalPowerUnknown =>
      'We tried to send the power command, but the result is unknown. A disconnect doesn’t prove it finished. Check the provider console. It won’t be resent automatically.';

  @override
  String get terminalNotConnected => 'Not connected';

  @override
  String get terminalConnecting => 'Connecting';

  @override
  String get terminalVerifying => 'Verifying host identity';

  @override
  String get terminalAuthenticating => 'Authenticating';

  @override
  String get terminalConnected => 'Connected · SSH PTY';

  @override
  String get terminalDisconnected => 'Disconnected';

  @override
  String get terminalFailed => 'Connection failed';

  @override
  String get terminalExit => 'Exit Terminal';

  @override
  String terminalSessionSemantics(String p0, String p1) {
    return 'Session details, $p0, $p1';
  }

  @override
  String get terminalHideKeyboard => 'Hide Keyboard';

  @override
  String get terminalOpenKeyboard => 'Open Keyboard';

  @override
  String get terminalMenu => 'Terminal Menu';

  @override
  String get terminalSessionDetails => 'Session Details and Help';

  @override
  String get terminalPasteIntoDraft => 'Paste into Draft';

  @override
  String get r3TermColorScheme => 'Colors & Highlighting';

  @override
  String get r3TermSchemeDark => 'Dark';

  @override
  String get r3TermSchemeLight => 'Light';

  @override
  String get r3TermSchemeFootnote =>
      'Display only; nothing is sent to the server. Resets when the app restarts.';

  @override
  String get r4HlSmart => 'Smart highlighting';

  @override
  String get r4HlSmartNote =>
      'Colors paths, IPs, numbers and keywords in uncolored output. Display only; nothing sent or changed.';

  @override
  String get r4HlLanguage => 'Syntax Highlighting';

  @override
  String get r4HlAuto => 'Auto-detect';

  @override
  String get r4HlPlain => 'Off (plain text)';

  @override
  String get r4HlGeneric => 'Generic';

  @override
  String get r4HlTooLarge => 'Over 256 KiB: highlighting is off';

  @override
  String get terminalReconnectClear => 'Reconnect and Clear Draft';

  @override
  String get terminalCancelConnection => 'Cancel Connection';

  @override
  String get terminalSshRestart => 'SSH Restart';

  @override
  String get terminalSshShutdown => 'SSH Shutdown';

  @override
  String get terminalTypeDirectly => 'Tap to type. Keys are sent directly.';

  @override
  String get terminalCopy => 'Copy';

  @override
  String get terminalClearSelection => 'Clear Selection';

  @override
  String get terminalLatestOutput => 'Return to Latest Output';

  @override
  String get terminalEstablishingSecure => 'Establishing a secure connection…';

  @override
  String get terminalOffline => 'Terminal disconnected';

  @override
  String get terminalConnect => 'Connect';

  @override
  String get terminalReconnectShort => 'Reconnect · Clear Draft';

  @override
  String get terminalBrowserUnsupported =>
      'Browsers don’t support native SSH. Use the native app.';

  @override
  String get terminalConnectedInputHelp =>
      'After connecting, tap the terminal to type. Keys are sent directly to the server.';

  @override
  String get terminalRetainedOutputHelp =>
      'Output is kept. Reconnecting clears the terminal and draft without replaying input.';

  @override
  String get terminalDismissNotice => 'Dismiss Notice';

  @override
  String get terminalVerifyNewHost => 'Verify New Host Key';

  @override
  String get terminalFirstHostVerification =>
      'First Connection · Verify Host Identity';

  @override
  String terminalHostIdentity(String p0, String p1, String p2) {
    return 'Host: $p0\nPort: $p1\nAlgorithm: $p2';
  }

  @override
  String get terminalSha256Fingerprint => 'SHA-256 fingerprint';

  @override
  String get terminalFullHostKey => 'Full host key';

  @override
  String get terminalIndependentVerificationHelp =>
      'Check against the provider console or another independent, trusted source. Seeing this dialog doesn’t establish trust.';

  @override
  String get terminalConfirmedChangedHost =>
      'I independently verified why it changed and the full new host key';

  @override
  String get terminalConfirmedHost =>
      'I verified the full host identity through an independent source';

  @override
  String get terminalVerificationExpired =>
      'The connection was canceled or timed out. This verification is no longer valid.';

  @override
  String get terminalUpdateTrustAuthenticate =>
      'Update Trust and Continue Authentication';

  @override
  String get terminalTrustAuthenticate => 'Trust and Authenticate';

  @override
  String get terminalUnlockKey => 'Unlock SSH Key';

  @override
  String terminalCredentialName(String p0) {
    return 'Credential: $p0';
  }

  @override
  String get terminalPassphraseHelp =>
      'Decrypts the private key; it isn’t the login password. Used for this connection only and not saved.';

  @override
  String get terminalKeyPassphrase =>
      'Private key passphrase for this connection';

  @override
  String get terminalPassphraseCleared =>
      'The passphrase was cleared. Cancel and reconnect.';

  @override
  String get terminalUnlockOnce => 'Unlock for This Connection Only';

  @override
  String get powerRestart => 'Restart';

  @override
  String get powerShutdown => 'Shut Down';

  @override
  String powerImpactTitle(String p0) {
    return '$p0 (1/2)';
  }

  @override
  String powerImpactHelp(String p0, String p1, String p2) {
    return '$p0\n$p1\n\nRun through this single SSH connection:\n$p2\n\nThis may immediately interrupt services and the SSH session, and it needs the right permissions on the remote server. Shutdown doesn’t stop provider billing, and SSH can’t power the server back on. After a disconnect or timeout, the result is unknown. Check the provider console instead of retrying blindly.';
  }

  @override
  String get powerUnderstandContinue => 'Review Target';

  @override
  String powerFinalTitle(String p0) {
    return '$p0 (2/2)';
  }

  @override
  String get powerEnterTarget =>
      'Enter the full target to confirm sending this command once:';

  @override
  String get powerTargetFormat => 'username@host:port';

  @override
  String get powerConfirmationInvalidated =>
      'The connection changed. This confirmation is no longer valid, and no command was sent.';

  @override
  String powerExecuteOnce(String p0) {
    return '$p0 Once';
  }

  @override
  String get snippetInvalidId => 'Invalid snippet ID';

  @override
  String get sshCheckTarget => 'Check the SSH port, username, and credentials';

  @override
  String get sshConnectionCancelled => 'SSH connection canceled';

  @override
  String get sshBrowserUnsupported =>
      'Browsers don’t support native SSH. Use the native app.';

  @override
  String get sshCredentialReadTimeout => 'Reading SSH credentials timed out';

  @override
  String get sshKeyNeedsPassphrase =>
      'This private key needs a passphrase. Reconnect and enter it.';

  @override
  String get sshPassphraseInputTimeout =>
      'Private-key passphrase entry timed out. No connection was made.';

  @override
  String get sshPassphraseCancelled =>
      'Private-key passphrase entry was canceled. No connection was made.';

  @override
  String get sshPassphraseTooLong =>
      'The private-key passphrase exceeds the length limit';

  @override
  String get sshKeyDecryptionTimeout =>
      'Private-key decryption timed out. No connection was made.';

  @override
  String get sshTcpTimeout => 'SSH TCP connection timed out';

  @override
  String get sshHandshakeTimeout => 'SSH handshake timed out';

  @override
  String get sshIdentityChanged =>
      'Host verification or credentials changed. Authentication was blocked.';

  @override
  String get sshVerificationCancelled => 'SSH verification canceled';

  @override
  String get sshVerificationTimeout =>
      'Host verification timed out. Authentication didn’t start.';

  @override
  String get sshCredentialChanged => 'Credentials changed. Reconnect.';

  @override
  String get sshAuthenticationTimeout => 'SSH authentication timed out';

  @override
  String get sshTerminalOpenTimeout => 'Opening the SSH terminal timed out';

  @override
  String get r3SftpOpenTimeout => 'Opening SFTP timed out';

  @override
  String get r3SftpUnavailable =>
      'The server didn’t open SFTP. It may be turned off for this account.';

  @override
  String get r3SftpTitle => 'SFTP Files';

  @override
  String get r3SftpRowSubtitle => 'Browse and transfer files';

  @override
  String get r3SftpUp => 'Parent folder';

  @override
  String get r3SftpRoot => 'Root';

  @override
  String get r3SftpNewFolder => 'New Folder';

  @override
  String get r3SftpNewFile => 'New Empty File';

  @override
  String get r3SftpUpload => 'Upload from Phone';

  @override
  String get r3SftpSort => 'Sort by';

  @override
  String get r3SftpSortName => 'Name';

  @override
  String get r3SftpSortSize => 'Size';

  @override
  String get r3SftpSortTime => 'Modified';

  @override
  String get r3SftpShowHidden => 'Show hidden files';

  @override
  String get r3SftpSearch => 'Search folder';

  @override
  String get r3SftpEmpty => 'This folder is empty';

  @override
  String get r3SftpNoMatch => 'No matches';

  @override
  String r3SftpShowMore(int count) {
    return 'Show More ($count)';
  }

  @override
  String get r3SftpMore => 'More';

  @override
  String get r3SftpAdd => 'New';

  @override
  String get r3SftpOpen => 'Open';

  @override
  String get r3SftpView => 'View / Edit';

  @override
  String get r3SftpDownload => 'Download';

  @override
  String get r3SftpRename => 'Rename / Move';

  @override
  String get r3SftpCopyPath => 'Copy Path';

  @override
  String get r3SftpDelete => 'Delete';

  @override
  String get r3SftpPathCopied => 'Path copied';

  @override
  String get r3SftpNameLabel => 'Name';

  @override
  String get r3SftpFolderLabel => 'Folder';

  @override
  String get r3SftpCreate => 'Create';

  @override
  String get r3SftpRenameTitle => 'Rename or Move';

  @override
  String get r3SftpRenameHint =>
      'Change the name to rename, or the folder to move.';

  @override
  String get r3SftpInvalidName => 'Enter a name without “/”';

  @override
  String get r3SftpInvalidFolder => 'Enter an absolute path starting with /';

  @override
  String r3SftpDeleteTitle(String name) {
    return 'Delete “$name”?';
  }

  @override
  String get r3SftpDeleteFileMessage =>
      'The file is deleted permanently on the server.';

  @override
  String get r3SftpDeleteFolderMessage =>
      'The empty folder is deleted permanently on the server.';

  @override
  String get r3SftpDeleteRecursiveTitle =>
      'Delete folder and everything in it?';

  @override
  String r3SftpDeleteRecursiveMessage(String name, int max) {
    return '“$name” isn’t empty. Everything inside is deleted permanently (recursive delete; links aren’t followed). Folders with more than $max items are refused, and nothing is deleted.';
  }

  @override
  String get r3SftpDeleteRecursiveAction => 'Delete Everything';

  @override
  String get r3SftpDeleted => 'Deleted';

  @override
  String r3SftpDeletedCount(int count) {
    return 'Deleted $count items';
  }

  @override
  String get r3SftpCreated => 'Created';

  @override
  String get r3SftpRenamed => 'Renamed';

  @override
  String get r3SftpErrPermission => 'Permission denied';

  @override
  String get r3SftpErrNotFound =>
      'Not found. It may have been moved or deleted.';

  @override
  String get r3SftpErrExists => 'Already exists';

  @override
  String get r3SftpErrNotEmpty => 'The folder isn’t empty';

  @override
  String get r3SftpErrWrongType =>
      'That item type doesn’t work for this action';

  @override
  String get r3SftpErrCancelled => 'Canceled';

  @override
  String get r3SftpErrTooLarge => 'Too large to open as text (limit 512 KiB)';

  @override
  String get r3SftpErrNotText => 'Not a UTF-8 text file';

  @override
  String r3SftpErrTooMany(int max) {
    return 'Too many items (limit $max); nothing was deleted';
  }

  @override
  String get r3SftpErrInvalidPath => 'Invalid path';

  @override
  String get r3SftpErrTimeout => 'The server took too long to respond';

  @override
  String get r3SftpErrConnectionLost => 'The SFTP connection ended';

  @override
  String get r3SftpErrUnavailable => 'SFTP isn’t available on this connection';

  @override
  String get r3SftpErrLocalFile => 'Couldn’t read or write the local file';

  @override
  String get r3SftpErrFailed => 'That didn’t work';

  @override
  String r3SftpEditorSize(String size) {
    return '$size · UTF-8';
  }

  @override
  String get r3SftpSaved => 'Saved';

  @override
  String get r3SftpUnsavedTitle => 'Discard unsaved changes?';

  @override
  String get r3SftpUnsavedMessage =>
      'Your edits haven’t been saved to the server.';

  @override
  String get r3SftpDiscard => 'Discard';

  @override
  String get r3SftpConflictTitle => 'File Changed on the Server';

  @override
  String get r3SftpConflictMessage =>
      'It was modified after you opened it. Overwrite the server’s version with yours?';

  @override
  String get r3SftpOverwrite => 'Overwrite';

  @override
  String get r3SftpSkip => 'Skip';

  @override
  String r3SftpExistsTitle(String name) {
    return '“$name” already exists';
  }

  @override
  String get r3SftpExistsMessage =>
      'Overwrite the file on the server, or skip this upload?';

  @override
  String get r3SftpLargeTitle => 'Large File';

  @override
  String r3SftpLargeMessage(String name, String size) {
    return '“$name” is $size. It can take a long time and use a lot of data. Continue?';
  }

  @override
  String get r3SftpContinue => 'Continue';

  @override
  String get r3SftpTransfers => 'Transfers';

  @override
  String r3SftpTransferUp(String name) {
    return 'Uploading $name';
  }

  @override
  String r3SftpTransferDown(String name) {
    return 'Downloading $name';
  }

  @override
  String r3SftpTransferCount(int index, int total) {
    return '$index of $total';
  }

  @override
  String get r3SftpStateQueued => 'Waiting';

  @override
  String get r3SftpStateDone => 'Done';

  @override
  String get r3SftpStateFailed => 'Failed';

  @override
  String get r3SftpStateCancelled => 'Canceled';

  @override
  String get r3SftpStateSkipped => 'Skipped';

  @override
  String get r3SftpCancelAll => 'Cancel All';

  @override
  String get r3SftpClearFinished => 'Clear Finished';

  @override
  String get r3SftpShare => 'Share';

  @override
  String r3SftpSavedTo(String path) {
    return 'Saved to $path';
  }

  @override
  String get r3SftpDownloadsWhere =>
      'Downloads are saved in the app folder “SFTP Downloads”. Use Share to keep a copy elsewhere, for example in Files.';

  @override
  String get r3SftpCloseBusyTitle => 'Transfers in Progress';

  @override
  String get r3SftpCloseBusyMessage =>
      'Closing cancels the running and waiting transfers.';

  @override
  String get r3SftpCloseBusyAction => 'Cancel Transfers and Close';

  @override
  String get r3SftpBackgroundClosed =>
      'SFTP was closed because the app went to the background';

  @override
  String get r3SftpConnecting => 'Connecting SFTP…';

  @override
  String get r3SftpConnectFailed => 'Couldn’t open SFTP';

  @override
  String get r3SftpRetry => 'Try Again';

  @override
  String get r3SftpChooseCredential =>
      'Choose a credential in the SSH settings first.';

  @override
  String get r3SftpSshSettings => 'SSH Settings';

  @override
  String get r3SftpLoadFailed => 'Couldn’t load this folder';

  @override
  String get r3SftpClose => 'Close';

  @override
  String r3SftpUploadsQueued(int count) {
    return '$count uploads queued';
  }

  @override
  String get sshAuthenticationFailed =>
      'SSH authentication failed. Check the username and credentials.';

  @override
  String get sshHostNotTrusted =>
      'The host wasn’t trusted. Authentication didn’t start.';

  @override
  String get sshConnectionIncomplete =>
      'The SSH connection didn’t complete. Check the address, network, and service.';

  @override
  String get sshSessionEnded =>
      'The SSH session ended. Reconnect to check whether the command finished.';

  @override
  String get sshInputUnconfirmed =>
      'Couldn’t confirm that the input reached SSH. Reconnect and check before retrying so it doesn’t run twice.';

  @override
  String get sshResizeFailed => 'Couldn’t resize the SSH terminal. Reconnect.';

  @override
  String get sshPrivatePublicMismatch =>
      'The private key doesn’t match the saved public-key details. Import the private key again before connecting.';

  @override
  String get securityReadFailed =>
      'Couldn’t read the security data. Try again.';

  @override
  String get securitySavedReloadFailed =>
      'Saved, but the data couldn’t be reloaded. Reload before making more changes.';

  @override
  String get securityDataChanged =>
      'The data has changed. Reload and try again.';

  @override
  String get securityMutationFailed =>
      'Couldn’t complete that security action. Existing data is unchanged. Try again.';

  @override
  String get securityInvalidCredentialIdentity =>
      'Enter a name of 1–80 characters and a valid default username.';

  @override
  String get securitySecretRequired => 'Enter the password or private key.';

  @override
  String get securityReimportForPassphrase =>
      'To update the saved passphrase, also reimport the matching private key.';

  @override
  String get securityPasswordNoPassphrase =>
      'Password credentials don’t use a private-key passphrase.';

  @override
  String get securitySecretSizeInvalid =>
      'The secret is empty or exceeds the size limit.';

  @override
  String get securitySecretWriteUnverified =>
      'Couldn’t verify that the secret was saved. The existing credential is unchanged.';

  @override
  String get securityCleanupIncomplete =>
      'Secret cleanup is incomplete. You can retry later.';

  @override
  String get securityCleanupReadFailed =>
      'Couldn’t read the pending cleanup data. Try again.';

  @override
  String get securitySshCancelled =>
      'The SSH connection was canceled, or the data needs to be reloaded.';

  @override
  String get securityChooseAvailableCredential =>
      'Select an available credential.';

  @override
  String get securityCredentialSecretMissing =>
      'This credential’s password or private key wasn’t found. Open Manage Credentials to save the password again or import the private key.';

  @override
  String get securityStoredSecretUnreadable =>
      'Couldn’t read the data in secure storage.';

  @override
  String get securityCredentialChanged =>
      'The credential has changed. Reload and try again.';

  @override
  String get securitySshCredentialReadFailed =>
      'Couldn’t read the SSH credential. Try again.';

  @override
  String get securityAuthenticationHidden =>
      'Device authentication didn’t complete. The secret stays hidden.';

  @override
  String get securitySavedPasswordMissing =>
      'The saved password wasn’t found. Edit this credential and save the password again.';

  @override
  String get securityRevealFailed => 'Couldn’t show the secret. Try again.';

  @override
  String get securityHostTargetMismatch =>
      'The host verification targets don’t match.';

  @override
  String get securityHostAuthenticationIncomplete =>
      'Host verification or authentication didn’t complete.';

  @override
  String get securityInvalidHost =>
      'Invalid host address. Enter an IP address or domain without a scheme, username, port, or path.';

  @override
  String get securityInvalidSshPort => 'Enter an SSH port from 1 to 65,535.';

  @override
  String get securityHostKeyUnreadable =>
      'Couldn’t recognize the host key. Check the complete key and the selected type.';

  @override
  String get securityPrivateKeyUnreadable =>
      'Couldn’t read the private key. Check its complete content, supported format, and decryption passphrase.';

  @override
  String get securityNativeStorageUnsupported =>
      'Native secure storage isn’t available on this platform.';

  @override
  String get securityNativeStorageUnavailable =>
      'Native secure storage is unavailable or the operation didn’t complete. Check your device and try again.';

  @override
  String get securityDeviceAuthUnsupported =>
      'Device authentication isn’t supported on this platform, so secrets can’t be shown.';

  @override
  String get securityDeviceAuthReason =>
      'Verify your identity to view the saved password';

  @override
  String get securityDeviceAuthIncomplete =>
      'Device authentication didn’t complete.';

  @override
  String get securityPasswordKind => 'Username and password';

  @override
  String get securityPrivateKeyKind => 'SSH key';

  @override
  String get securityReloadSaved => 'Reload Saved Data';

  @override
  String get securityCleanupNotice =>
      'Secure-storage cleanup is incomplete. References used by current connections are kept. Retry when system secure storage is available. Secrets still in use won’t be deleted.';

  @override
  String get securityRetryCleanup => 'Retry Unused-Secret Cleanup';

  @override
  String get securityAddLoginCredential => 'Add Login Credential';

  @override
  String get securityImportKey => 'Import SSH key';

  @override
  String get securityImportKeySubtitle =>
      'Choose a file or paste · Validate format and passphrase';

  @override
  String get securitySaveUsernamePassword => 'Save username and password';

  @override
  String get securityReusableCredential => 'Can be used by multiple servers';

  @override
  String get securityTitle => 'Keys & Security';

  @override
  String get securityAddCredential => 'Add Credential';

  @override
  String get securityCredentialStorageNotice =>
      'Secrets live only in system secure storage; servers just reference credentials.';

  @override
  String get securitySearchCredentials => 'Search name or default username';

  @override
  String get securityAll => 'All';

  @override
  String securityCredentialCount(int count) {
    return 'Saved login credentials · $count';
  }

  @override
  String get securityNoMatchingCredentials =>
      'No matching credentials. Change the filter or add one.';

  @override
  String securityLinkedServerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count linked servers',
      one: '1 linked server',
    );
    return '$_temp0';
  }

  @override
  String get securityDeviceConnectionSecurity =>
      'Device and connection security';

  @override
  String get securityTrustedHosts => 'Trusted Hosts';

  @override
  String get securityTrustedHostsSubtitle =>
      'Host, port, algorithm, and complete host key';

  @override
  String get securityCredentialProtection => 'Credential Protection';

  @override
  String get securityCredentialProtectionSubtitle =>
      'Device verification, brief reveal, and platform limits';

  @override
  String get securityCredentialProtectionDetail =>
      'Passwords, private keys, and key passphrases are excluded from the ledger database, exports, and logs. Viewing a password requires system device verification. It is hidden after 20 seconds or when you leave the page. This app doesn’t support device verification on Linux, so secrets can’t be viewed there.\n\nDevice authentication gates display in the app; it doesn’t mean each secret is separately encrypted by biometric hardware. Security behavior still needs verification on physical iOS / Android devices. Dart doesn’t guarantee secure memory erasure. Copying or exporting secrets is currently unavailable.';

  @override
  String get securityLocalCredentialNotice =>
      'Only the local credential changes; the server’s password and authorized_keys are untouched.';

  @override
  String get securityViewDetails => 'View Details';

  @override
  String get securityPrivateKeyDetailsSubtitle =>
      'Public-key fingerprint and metadata; private key hidden';

  @override
  String get securityPasswordDetailsSubtitle =>
      'Password hidden by default; device verification required to view';

  @override
  String get securityEditCredential => 'Edit Credential';

  @override
  String get securityKeepSecret => 'Leave blank to keep the saved secret';

  @override
  String get securityLinkedServers => 'Linked Servers';

  @override
  String get securityIndependentUsernames =>
      'Connection usernames are stored separately';

  @override
  String get securityDeleteCredential => 'Delete Credential';

  @override
  String get securityReviewDeleteImpact =>
      'Review the impact of replacing or unlinking first';

  @override
  String get securityDiscardCredentialTitle => 'Discard these edits?';

  @override
  String get securityDiscardCredentialMessage =>
      'Unsaved credential content will be cleared.';

  @override
  String get securityDiscardChanges => 'Discard Changes';

  @override
  String get securityKeyImported =>
      'Private key imported into the draft. Its format and passphrase will be validated when saved.';

  @override
  String get securityKeyFileReadFailed =>
      'Couldn’t read the private-key file. Choose a UTF-8 private-key file no larger than 128 KB.';

  @override
  String get securityKeyPasted =>
      'Private key pasted into the draft. It remains hidden and will be validated when saved.';

  @override
  String get securityKeyPasteFailed =>
      'Couldn’t paste the private key. Copy the complete private key, no larger than 128 KB.';

  @override
  String get securityCredentialSaved =>
      'Credential saved. Remote authentication details are unchanged.';

  @override
  String get securityCancelCredentialEdit => 'Cancel Credential Editing';

  @override
  String get securityCredentialName => 'Credential name';

  @override
  String get securityCredentialNameRequired => 'Enter a credential name.';

  @override
  String get securityDefaultLoginUsername => 'Default login username';

  @override
  String get securityOptionalDefaultUsername => 'Default username (optional)';

  @override
  String get securityDefaultUsernameRequired => 'Enter a default username.';

  @override
  String get securityChoosingFile => 'Choosing file…';

  @override
  String get securityChoosePrivateKeyFile => 'Choose Private-Key File';

  @override
  String get securityPasteCompleteKey => 'Paste Complete Private Key';

  @override
  String get securityPrivateKeyImportNotice =>
      'OpenSSH / PEM private keys. The file path isn’t saved and the content stays hidden.';

  @override
  String get securityLoginPassword => 'Login password';

  @override
  String get securityPrivateKeyContent => 'Private-key content';

  @override
  String get securityKeepSecretHidden =>
      'Leave blank to keep saved content. The existing secret is never shown here.';

  @override
  String get securityLoginPasswordRequired => 'Enter the login password.';

  @override
  String get securityPrivateKeyRequired =>
      'Choose a private-key file or paste the complete private key.';

  @override
  String get securityPrivateKeyPassphrase => 'Private-key passphrase (if any)';

  @override
  String get securityPrivateKeyPassphraseHelp =>
      'Decrypts the private key; not the login password.';

  @override
  String get securityStoreKeyPassphrase =>
      'Save the private-key passphrase in device secure storage';

  @override
  String get securityStoreKeyPassphraseHelp =>
      'Not saved by default. If an encrypted key’s passphrase isn’t saved, you’ll need to enter it for every connection. Canceling or entering a wrong passphrase stops the connection. This option applies only when importing a private key.';

  @override
  String get securityCredentialEditNotice =>
      'The username is only a suggestion for new connections. Updating a credential affects future logins only and changes nothing on the server. Unsaved secrets are cleared when the app goes to the background.';

  @override
  String get securityCurrentLinkImpact => 'Impact on current links';

  @override
  String get securityServerFallback => 'Server';

  @override
  String get securitySaving => 'Saving…';

  @override
  String get securitySaveCredential => 'Save Credential';

  @override
  String get securityCredentialDetails => 'Credential Details';

  @override
  String get securityCredentialDeleted => 'Credential deleted';

  @override
  String securityCredentialDefaultUsername(String kind, String username) {
    return '$kind\nDefault username: $username';
  }

  @override
  String get securityUsernamePerConnection =>
      'Set separately for each connection';

  @override
  String get securityPublicKeyFingerprint => 'Public-key fingerprint';

  @override
  String get securityPublicKeyFingerprintNotice =>
      'The fingerprint identifies a login key and differs from the server’s host fingerprint. Private keys are never shown.';

  @override
  String get securityFingerprintCopied => 'Public-key fingerprint copied';

  @override
  String get securityCopyFailed => 'Couldn’t copy. Try again.';

  @override
  String get securityCopyFingerprint => 'Copy Public-Key Fingerprint';

  @override
  String get securityProtectedPassword => 'Protected password';

  @override
  String get securityPasswordRevealNotice =>
      'Hidden after 20 seconds, or immediately when you leave this page or move the app to the background.';

  @override
  String get securityPasswordHiddenNotice =>
      'Shown briefly after successful verification. It stays hidden if device authentication isn’t available. Viewing isn’t available on Linux yet.';

  @override
  String get securityHidePassword => 'Hide Password';

  @override
  String get securityVerifyViewPassword => 'Verify Device to View Password';

  @override
  String get securityCancelVerifyHide => 'Cancel Verification and Hide';

  @override
  String securityCredentialReferenceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count servers use this credential',
      one: '1 server uses this credential',
    );
    return '$_temp0 (including archived).';
  }

  @override
  String get securityNoCredentialReferences =>
      'No links yet. Choose this credential in a server’s SSH settings.';

  @override
  String securityCredentialDeleteImpact(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count servers will be affected',
      one: '1 server will be affected',
    );
    return '$_temp0 (including archived).';
  }

  @override
  String get securityManageLinks => 'How to handle links';

  @override
  String get securityReplaceOrUnlink => 'Replace or unlink';

  @override
  String get securityUnlinkAll => 'Unlink all';

  @override
  String securityReplaceWith(String name) {
    return 'Replace with $name';
  }

  @override
  String get securityUnlinkCredentialNotice =>
      'Unlinking keeps servers, usernames, and payments. You’ll need to choose a credential again before the next connection.';

  @override
  String get securityReplaceCredentialNotice =>
      'Only credential references are replaced. All current server usernames stay unchanged.';

  @override
  String get securityDeleteLocalCredentialNotice =>
      'Deletes only the local credential and can’t be undone. Servers and cloud services are unaffected.';

  @override
  String get securityConfirmCredentialImpact =>
      'I’ve reviewed the impact on linked servers and want to delete the local credential';

  @override
  String get securityLocalCredentialDeleted =>
      'Local credential deleted. Remote authentication details are unchanged.';

  @override
  String get securityConfirmDelete => 'Confirm Deletion';

  @override
  String get securityVerifyHostKey => 'Verify Host Key';

  @override
  String get securityHostTrustNotice =>
      'Trust is tied to the host address, port, and full host key, and is separate from login credentials.';

  @override
  String get securityNoTrustedHosts =>
      'No trusted hosts yet. Enter a host key you got from an independent, trusted source (such as the provider’s console or an administrator), or verify it on the first SSH connection. This page doesn’t connect to the server.';

  @override
  String securityHostVerifiedAt(String algorithm, String date) {
    return '$algorithm\nVerified at $date';
  }

  @override
  String get securityCompleteHostKey => 'Full host key';

  @override
  String get securityReverifyHost => 'Reverify Host';

  @override
  String get securityRemoveHostTrustTitle => 'Remove host trust?';

  @override
  String securityRemoveHostTrustMessage(
    String host,
    int port,
    String fingerprint,
  ) {
    return '$host:$port\n$fingerprint\n\nThe host’s identity must be verified again on the next connection. The server and login credentials won’t be deleted.';
  }

  @override
  String get securityRemoveHostTrust => 'Remove Trust';

  @override
  String get securityHostChangedNotice =>
      'If a host key changes, authentication stops until you verify the host again through an independent source. There’s no “ignore and connect” option.';

  @override
  String get securityHostTrustReadFailed =>
      'Couldn’t read the host trust data. Try again.';

  @override
  String get securityHostTrustInputNotice =>
      'Enter the host key from an independent, trusted source such as the provider console. This page only saves local trust and doesn’t connect.';

  @override
  String get securityHostAddress => 'Host address';

  @override
  String get securityPort => 'Port';

  @override
  String get securityHostKeyType => 'Host key type';

  @override
  String get securityHostKeyHelp =>
      'A public-key line or complete Base64, not a private key or just a fingerprint';

  @override
  String get securityRsaHostKeyNotice =>
      'rsa-sha2-256 / 512 are signature algorithms; choose ssh-rsa as the key type.';

  @override
  String get r2CopyInfoRsaKey => 'About RSA host keys';

  @override
  String get securityChecking => 'Validating…';

  @override
  String get securityCheckFingerprint => 'Check Fingerprint';

  @override
  String get securityHostKeyMismatch => 'Host Key Differs from Saved Record';

  @override
  String get securityFirstHostVerification => 'First Host Verification';

  @override
  String get securityHostMismatchBadge =>
      'Public key differs · Reverify independently';

  @override
  String get securityHostVerifyBeforeSave =>
      'Verify the host’s identity before saving trust';

  @override
  String get securitySavedHostFingerprint => 'Saved host fingerprint';

  @override
  String get securityCandidateHostFingerprint => 'Host fingerprint to verify';

  @override
  String get securityHostVerificationWarning =>
      'Verify the fingerprint and address through an independent source. A change may be a reinstall or a man-in-the-middle attack; reject if unsure.';

  @override
  String get securityBeginHostReverification =>
      'Start Independent Reverification';

  @override
  String get securityConfirmHostVerified =>
      'I have verified the host, port, and complete fingerprint through an independent source';

  @override
  String get securityHostTrustSaved =>
      'Host trust saved. No connection or authentication was started.';

  @override
  String get securityReverifyReplaceTrust => 'Reverify and Replace Trust';

  @override
  String get securitySaveVerifiedHostTrust => 'Save Verified Host Trust';

  @override
  String get securityRejectBack => 'Reject and Go Back';

  @override
  String get uiSecurityVerified => 'Verified';

  @override
  String get uiSecurityUnverified => 'Not verified';

  @override
  String get uiSecurityKeyChanged => 'Host key changed';

  @override
  String get securitySavingHostTrust =>
      'Saving confirmed trust. You can’t go back until this finishes.';

  @override
  String get securityLocalHostTrustOnly =>
      'Only local trust is recorded. Rejecting, canceling, or going back saves nothing.';

  @override
  String get securityDiscardSshTitle => 'Discard connection settings?';

  @override
  String get securityDiscardSshMessage =>
      'Unsaved address, username, and credential choices won’t take effect.';

  @override
  String get securityChooseCredential => 'Choose Login Credential';

  @override
  String get securityUnlinkCurrentCredential => 'Unlink current credential';

  @override
  String get securityChooseCredentialLater =>
      'Keep the settings and choose a credential later';

  @override
  String securityCredentialChoiceSubtitle(String kind, String username) {
    return '$kind · Default: $username';
  }

  @override
  String get securityNotSet => 'Not set';

  @override
  String get securityNoCredentialsToChoose =>
      'No credentials yet. Go back and use Manage Credentials to add one.';

  @override
  String get securityAdoptUsernameTitle =>
      'Use the credential’s default username?';

  @override
  String securityAdoptUsernameMessage(String current, String suggested) {
    return 'Current connection username: $current\nCredential default username: $suggested\n\nOnly this connection is affected. Canceling keeps the current username.';
  }

  @override
  String get securityNotEntered => 'Not entered';

  @override
  String get securityAdoptUsername => 'Use Default Username';

  @override
  String get securitySshConfigurationSaved =>
      'SSH settings saved. No network connection was made.';

  @override
  String get securitySshConfiguration => 'SSH Connection Settings';

  @override
  String get securityCancelSshConfiguration => 'Cancel Connection Settings';

  @override
  String get securitySshConfigurationNotice =>
      'Connection settings and the ledger address are stored separately. Cloud server settings aren’t changed.';

  @override
  String get securityHostHint => 'IPv4 / IPv6 / domain, without a scheme';

  @override
  String get securityHostRequired => 'Enter a host address.';

  @override
  String get securityPortRequired => 'Enter a port from 1 to 65,535.';

  @override
  String get securityConnectionUsername => 'Current connection username';

  @override
  String get securityConnectionUsernameRequired =>
      'Enter a login username, or use the credential’s default username.';

  @override
  String get securityLoginCredential => 'Login credential';

  @override
  String get securityManageCredentials => 'Manage Credentials';

  @override
  String get securityCredentialNotConfigured => 'Credential not configured';

  @override
  String get securityCredentialRequiredBeforeConnect =>
      'You can save now, but you must choose a credential before connecting';

  @override
  String securityChangeCredentialSubtitle(String kind) {
    return '$kind · Tap to change or unlink';
  }

  @override
  String get securityConnectionUsernameNotice =>
      'The username belongs to this connection. Changing credentials changes it only if you explicitly choose “Use Default Username.” Canceling or choosing the same username doesn’t change other connections.';

  @override
  String get securityConfigurationOnlyNotice =>
      'Saves connection settings only. The host key is verified before login; a changed key pauses authentication.';

  @override
  String get securitySaveSshConfiguration => 'Save SSH Settings';

  @override
  String get securityOpenKeyFile => 'Import';

  @override
  String get securityAuthCancel => 'Cancel';

  @override
  String get securityAuthSignInTitle => 'Verify identity';

  @override
  String get securityAuthBiometricHint => 'Verify your identity';

  @override
  String get securityAuthBiometricNotRecognized => 'Not recognized. Try again.';

  @override
  String get securityAuthBiometricSuccess => 'Verified';

  @override
  String get securityAuthRequiredTitle => 'Biometric Verification Required';

  @override
  String get securityAuthSetupDescription =>
      'Enable biometric verification in your device settings.';

  @override
  String get securityAuthGoToSettings => 'Go to Settings';

  @override
  String get securityAuthDeviceSetupDescription =>
      'Enable device authentication in your device settings.';

  @override
  String get securityAuthDeviceRequiredTitle => 'Device Verification Required';

  @override
  String get securityAuthIosLockout =>
      'Biometric verification is locked. Lock and unlock your device, then try again.';

  @override
  String get securityAuthIosSetupDescription =>
      'Enable Face ID or Touch ID in your device settings.';

  @override
  String serverCompactMonths(int months) {
    return '$months mo';
  }

  @override
  String get resourceTrafficPeriodUnsetShort => '—';

  @override
  String get resourceTrafficPeriodMonthShort => 'M';

  @override
  String get resourceTrafficPeriodQuarterShort => 'Q';

  @override
  String get resourceTrafficPeriodYearShort => 'Y';

  @override
  String get providerNameRange => 'Use 1–80 characters for the provider name.';

  @override
  String get providerAlreadyExists =>
      'This provider already exists. Select it from the list.';

  @override
  String get providerUiTitle => 'Providers';

  @override
  String get uiCloudProvidersTitle => 'Providers';

  @override
  String get providerUiDetails => 'Provider Details';

  @override
  String get providerUiAdd => 'Add Provider';

  @override
  String get providerUiRename => 'Rename Provider';

  @override
  String get providerUiName => 'Provider name';

  @override
  String get providerUiUnspecified => 'Unspecified provider';

  @override
  String get providerUiUnspecifiedHelp =>
      'You can assign a provider later by editing the server.';

  @override
  String get providerUiHierarchyHelp =>
      'A provider is who sells you servers. A catalog provider also lists its packages.';

  @override
  String r6CatProviderSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count servers',
      one: '1 server',
      zero: 'No servers',
    );
    return '$_temp0';
  }

  @override
  String get r6CatCatalogSection => 'Catalog providers';

  @override
  String get r6CatMineSection => 'My providers';

  @override
  String get r6CatCatalogFooter =>
      'Catalog providers come with ready-made packages. Choose Add Provider if yours isn’t listed.';

  @override
  String r6CatPackageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count packages',
      one: '1 package',
    );
    return '$_temp0';
  }

  @override
  String get r6CatNoPackageList => 'No package list';

  @override
  String get r6CatAdded => 'Added';

  @override
  String get r6CatChoosePackage => 'Choose a Package';

  @override
  String get r6CatPackageFooter =>
      'A package fills in hardware and price. You can still edit everything in the next step.';

  @override
  String get r6CatNoPackage => 'No Package';

  @override
  String get r6CatNoPackageHelp => 'Fill in the hardware and price yourself.';

  @override
  String get r6CatDefaultPill => 'Default';

  @override
  String get r6CatContinue => 'Continue';

  @override
  String get r6CatPackageDetails => 'Package';

  @override
  String get r6CatSpecs => 'Specifications';

  @override
  String get r6CatPrice => 'Price';

  @override
  String r6CatPriceValue(String amount, String currency, String cycle) {
    return '$amount $currency · $cycle';
  }

  @override
  String get r6CatUnknownPrice => 'No price listed';

  @override
  String get r6CatLinkedServers => 'Servers with this package';

  @override
  String get r6CatNoLinkedServers => 'No server uses this package yet.';

  @override
  String get r6CatLinkedFooter =>
      'Servers keep their own hardware and price; the package is only a record of what you picked.';

  @override
  String get r6CatAddServerWithPackage => 'Add Server with This Package';

  @override
  String get r6CatChangedNotice =>
      'The catalog has updated this package since it was chosen. Servers keep the values they saved.';

  @override
  String get r6CatChangedPill => 'Catalog updated';

  @override
  String get r6CatRemovedNotice =>
      'The catalog no longer lists this package. Servers keep the values they saved.';

  @override
  String get r6CatRemovedPill => 'No longer listed';

  @override
  String get r6CatSavedValues => 'As saved on this server';

  @override
  String get r6CatCurrentValues => 'Current catalog';

  @override
  String get r6CatServerSection => 'Provider and package';

  @override
  String get r6CatServerFooter =>
      'The server keeps its own hardware and price. Edit the server to change its provider or package.';

  @override
  String get r6CatNoPackageRow => 'No package';

  @override
  String get r6CatOpenPackage => 'View package';

  @override
  String get r6CatFormPackage => 'Package';

  @override
  String get r6CatFormPackageFooter =>
      'Choosing a package fills in hardware and price. You can still edit them.';

  @override
  String get r6CatReplaceTitle => 'Replace hardware and price?';

  @override
  String get r6CatReplaceMessage =>
      'The package’s values will replace this server’s hardware and price in the form. Nothing is saved until you save.';

  @override
  String get r6CatReplaceAction => 'Replace Values';

  @override
  String get r6CatPackagesHeader => 'Packages';

  @override
  String get r6CatPackagesFooter =>
      'Packages come from the catalog and only pre-fill a new server.';

  @override
  String get r6CatNoPackagesYet => 'This provider has no package list.';

  @override
  String get r6CatCatalogFailed =>
      'The package catalog couldn’t be loaded. You can still use your own providers.';

  @override
  String get r6CatRetry => 'Retry';

  @override
  String get r6CatCatalogProviderHelp =>
      'Not added yet. Add it to use its packages when you add servers.';

  @override
  String get r6CatPackageInvalid =>
      'The package doesn’t match this server’s provider.';

  @override
  String get r6CatBackupProviders => 'providers';

  @override
  String r6CatBackupProviderCount(int count) {
    return 'Providers: $count';
  }

  @override
  String get r6CatSampleNote => 'Sample catalog data for testing.';

  @override
  String get providerUiEmpty => 'No providers yet';

  @override
  String get providerUiEmptyHelp =>
      'Add a provider name, or choose one from the catalog when you add a server.';

  @override
  String providerUiUnspecifiedCount(int count) {
    return '$count servers have no provider assigned.';
  }

  @override
  String get providerUiChoose => 'Choose a Provider';

  @override
  String get providerUiChooseHelp => 'Choose the provider you buy from.';

  @override
  String get providerUiDevices => 'Provider servers';

  @override
  String get providerUiNoDevices => 'No servers belong to this provider yet.';

  @override
  String get providerUiUnavailable =>
      'This provider changed or is unavailable. Go back and choose again.';

  @override
  String get providerUiOpenProvider => 'View provider';
}
