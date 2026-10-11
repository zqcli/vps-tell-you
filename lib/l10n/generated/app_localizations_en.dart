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
      'Switch the interface immediately. Drafts and connections are kept.';

  @override
  String get languageSystem => 'Follow system';

  @override
  String get languageSystemDescription => 'Other system languages use English.';

  @override
  String get languageChinese => '简体中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSaveFailed =>
      'Could not save the language setting. The current language is unchanged. Try again.';

  @override
  String get ledgerOpenFailed => 'Could not open the local ledger';

  @override
  String get ledgerOpenHelp =>
      'Your existing data is kept. Check device storage and file permissions. If you previously used a newer version, try that version or a later one.';

  @override
  String get retryOpen => 'Try opening again';

  @override
  String get ledgerDoNotErase =>
      'Do not clear app data or uninstall the app to try to fix this.';

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
  String get remainingValueCalculator => 'Remaining value calculator';

  @override
  String get calculatorDescription =>
      'Calculate from scratch or use server details. Export an image.';

  @override
  String get connectionsTroubleshooting => 'Connections and troubleshooting';

  @override
  String get sshQuickConnect => 'SSH quick connect';

  @override
  String get sshQuickConnectDescription =>
      'Choose a saved server or a one-time target. Verify the host before signing in.';

  @override
  String get tcpConnectionTest => 'TCP connection test';

  @override
  String get tcpConnectionDescription =>
      'Test one address and port from this device.';

  @override
  String get commandSnippets => 'Command snippets';

  @override
  String get commandSnippetsDescription =>
      'Save commands and insert them into a terminal draft before sending.';

  @override
  String get singleServerMaintenance => 'Server maintenance';

  @override
  String get powerControl => 'Power control';

  @override
  String get powerControlDescription =>
      'Restart or shut down over SSH. Check the target before proceeding.';

  @override
  String get powerControlWarning =>
      'After shutdown, use the provider panel to power on. SSH cannot power on a stopped server. Restarting or shutting down does not stop provider billing.';

  @override
  String get uiTabsCalculatorTile =>
      'Standalone estimate or from a server; export a privacy-safe image';

  @override
  String get uiTabsSshTile => 'Pick a configured server';

  @override
  String get uiTabsTcpTile => 'Probe one host and port';

  @override
  String get uiTabsSnippetsTile => 'Saved commands, sent as a draft';

  @override
  String get uiTabsPowerTile => 'Reboot or power off over SSH';

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
  String get reminderOnDueDate => 'On the expiry date';

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
  String get notificationStatus => 'Notification access and reminder status';

  @override
  String reminderLastTimezone(String p0) {
    return 'Time zone last used to schedule reminders: $p0';
  }

  @override
  String get reminderEnableHelp =>
      'Enable both system notifications and reminders for each server. Edit reminder days, time, and usage plans in server details. Rules can be saved even without notification permission.';

  @override
  String get requestingPermission => 'Requesting…';

  @override
  String get requestNotificationPermission => 'Request notification permission';

  @override
  String get notificationPermissionHelp =>
      'If permission was denied or the notification channel is off, change it in device settings. Then return to the app and check reminder status again.';

  @override
  String get checkReminderStatus => 'Check reminder status again';

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
    return 'Show all ($n)';
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
      'Reminders over the OS limit (iOS 64 / Android 256) or more than 366 days away are not scheduled.';

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
  String get r2TabsAllReminders => 'All reminders';

  @override
  String get r2TabsFilterAll => 'All';

  @override
  String get r2TabsSearchHint => 'Search server name';

  @override
  String get r2TabsEmpty => 'Nothing to show';

  @override
  String get r2TabsNoUpcoming => 'No upcoming reminders';

  @override
  String get r2TabsEnableHelp =>
      'Needs both system notifications and per-server reminders.';

  @override
  String get r2TabsPermissionHelp =>
      'If denied, enable notifications in system settings.';

  @override
  String r2TabsNotifyScheduled(String n) {
    return '$n scheduled';
  }

  @override
  String get reminderHorizonHelp =>
      'Only known expiry reminders within the next 366 days are submitted. Past reminder times are not retried. Up to 64 upcoming reminders on iOS or 256 on Android can be scheduled; the rest are shown as not scheduled. Open the app regularly to update them.';

  @override
  String get reminderDeliveryHelp =>
      'The app checks permission and the device time zone when reopened. Open it after travel; otherwise, existing reminders may still use the previous time zone. Power saving, focus modes, and device restrictions may delay or block reminders. Scheduled does not mean delivered.';

  @override
  String get reminderPrivacyHelp =>
      'Reminders contain only the expiry date and a prompt to check it. They omit server names, addresses, accounts, and amounts. They do not make payments or change provider renewal settings.';

  @override
  String get reminderRulesSaved =>
      'Reminder rules saved. Check system reminder status under Settings / Notification access.';

  @override
  String get localExpiryReminders => 'Expiry reminders on this device';

  @override
  String get back => 'Back';

  @override
  String get recordMissingReload =>
      'This record no longer exists. Go back and reload.';

  @override
  String get dueDateNotEntered => 'No expiry date entered';

  @override
  String get reminderSaveHelp =>
      'Tap Save reminder rules to apply changes. If reminders are enabled and you choose Stop using at expiry, reminders will still prompt you to check provider renewal settings.';

  @override
  String get uiTabsReminderSaveHelp => 'Tap Save at the top right to apply.';

  @override
  String uiTabsReminderDue(String name, String date) {
    return '$name expires on $date.';
  }

  @override
  String uiTabsReminderPreview(String dates, String time) {
    return 'You will be reminded on $dates at $time (device time zone). Notifications never include names, IPs or amounts.';
  }

  @override
  String get uiTabsReminderPreviewNone =>
      'No upcoming reminder time with these settings. Notifications never include names, IPs or amounts.';

  @override
  String get uiTabsUsageContinueHint => 'Reminds you to renew before expiry';

  @override
  String get uiTabsUsageUndecidedHint => 'Reminds you to decide';

  @override
  String get uiTabsUsageStopHint =>
      'Still reminds you to verify and cancel auto-renewal';

  @override
  String get demoNoNotifications =>
      'Demo records do not schedule real system notifications.';

  @override
  String get archivedNoReminders =>
      'Archived records do not schedule reminders.';

  @override
  String get enableServerReminders => 'Enable reminders for this server';

  @override
  String get reminderOnlyHelp =>
      'Reminders only. No automatic renewal or cancellation.';

  @override
  String get daysBefore => 'Days before expiry';

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
  String get selectReminderTime => 'Select reminder time';

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
      'Uses the device time zone. Times skipped by daylight saving move forward; repeated times fire once.';

  @override
  String get myUsagePlan => 'My usage plan';

  @override
  String get usagePlanWarning =>
      'Usage plans are local records only and do not stop provider billing. Cancel renewal with the provider separately.';

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
    return 'A service $p0. Check that renewal has been cancelled with the provider. A local plan does not stop billing.';
  }

  @override
  String notificationContinueBody(String p0) {
    return 'A service $p0. Check the provider bill and your usage plan. This reminder does not make payments.';
  }

  @override
  String get expiryChecks => 'Expiry checks';

  @override
  String get expiryChannelDescription =>
      'Local expiry reminders. No automatic renewal or payment.';

  @override
  String get reminderNotChecked => 'System notifications have not been checked';

  @override
  String get reminderChecking => 'Checking system reminders…';

  @override
  String reminderScheduleCounts(String p0, String p1) {
    return 'Scheduled: $p0 · Not scheduled: $p1';
  }

  @override
  String get reminderPermissionDenied =>
      'Notifications are not allowed or the channel is off. Saved rules are kept.';

  @override
  String get reminderUnsupported =>
      'This platform does not support scheduled notifications. Saved rules will not trigger reminders on this device.';

  @override
  String get reminderCheckFailed =>
      'Could not check reminder status. Older reminders may remain. Try again or check device settings.';

  @override
  String get jsonLedgerBackup => 'JSON ledger backup';

  @override
  String get backupTooLarge => 'The backup exceeds the 10 MiB limit';

  @override
  String get backupExportInvalid =>
      'Export validation failed. No backup was saved or shared. The ledger is unchanged.';

  @override
  String get backupShareSelected =>
      'A system sharing action was selected. Check the destination app to confirm the file was saved or delivered.';

  @override
  String get backupShareCancelled =>
      'Sharing cancelled. The backup preview is kept.';

  @override
  String get backupShareUnknown =>
      'No sharing result was received. The backup preview is kept.';

  @override
  String get systemShareUnsupported =>
      'System sharing is not supported on this platform.';

  @override
  String get completeCurrentShare => 'Finish the current sharing action first.';

  @override
  String get backupShareFailed =>
      'Sharing did not complete. The backup preview is kept.';

  @override
  String get backupSaveCancelled =>
      'Saving cancelled. The backup preview is kept.';

  @override
  String backupSavedPath(String p0) {
    return 'Backup saved:\n$p0';
  }

  @override
  String get backupSaveFailed =>
      'The backup could not be saved. Check storage and permissions, then try again.';

  @override
  String get backupSelectionCancelled => 'Backup selection cancelled.';

  @override
  String get backupReadInvalid =>
      'Reading or validation failed. Choose a complete version 1 JSON ledger backup no larger than 10 MiB. Existing data is unchanged.';

  @override
  String get restoreEmptyLedgerQuestion => 'Restore to this empty ledger?';

  @override
  String restoreConfirmation(String p0) {
    return '$p0\nOriginal IDs, amounts, and payment void status are kept. Manual reference exchange rates are replaced. Notes, connections, security data, and reminder rules are not restored. Reminders for imported servers stay off. Restoring does not connect to or renew servers.';
  }

  @override
  String get confirmRestore => 'Confirm restore';

  @override
  String get ledgerRestored =>
      'Ledger restored. Set up connections and reminders again. No servers were connected.';

  @override
  String get restoreFailed =>
      'Restore did not complete. Existing data is unchanged. Only empty ledgers can be restored. Select and check the backup again.';

  @override
  String deviceTime(String p0) {
    return '$p0 (device time)';
  }

  @override
  String backupCounts(String p0, String p1, String p2, String p3) {
    return 'Servers: $p0 · Groups: $p1\nPayments (including voided): $p2 · Service periods: $p3';
  }

  @override
  String get ledgerBackupRestore => 'Ledger backup and restore';

  @override
  String get plainJsonVersion => 'Unencrypted JSON · Format v1';

  @override
  String get backupContentsWarning =>
      'Includes server names, providers, addresses, regions, purposes, operating systems, specifications, hardware details, groups, amounts, dates, payments, and manual exchange rates. The file is unencrypted. Store it safely and share it only with trusted destinations. Sensitive content entered in these fields is also exported.';

  @override
  String get notIncluded => 'Not included:';

  @override
  String get generateBackupPreview => 'Generate export preview';

  @override
  String get exportPreview => 'Export preview';

  @override
  String backupGeneratedTime(String p0) {
    return 'Backup created: $p0';
  }

  @override
  String get shareUnencryptedBackup => 'Share unencrypted backup';

  @override
  String get saveJsonBackup => 'Save JSON backup';

  @override
  String get restoreEmptyOnlyHelp =>
      'Restore is supported only when the ledger has no servers, groups, payments, or service periods. Existing data is never overwritten or merged. Imported server reminders default to off. App preferences stay unchanged.';

  @override
  String get chooseJsonPreviewRestore => 'Choose JSON and preview restore';

  @override
  String get restorePreview => 'Restore preview';

  @override
  String backupTime(String p0) {
    return 'Backup time: $p0';
  }

  @override
  String get restoreContentsHelp =>
      'Only ledger records and manual rates are imported; items listed above are not in the backup.';

  @override
  String get restoreToEmptyLedger => 'Restore to empty ledger';

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
  String get manageGroups => 'Manage groups';

  @override
  String groupCountHelp(String p0) {
    return 'Groups: $p0 · Deleting a group keeps its records';
  }

  @override
  String get archivedRecords => 'Archived records';

  @override
  String archiveCountHelp(String p0) {
    return 'Records: $p0 · Can be restored to the server list';
  }

  @override
  String get accountsPreferences => 'Accounts and preferences';

  @override
  String get panelAccounts => 'Panel accounts';

  @override
  String panelConnectionCount(String p0) {
    return 'Saved panel connections: $p0';
  }

  @override
  String get keysSecurity => 'Keys and security';

  @override
  String get keysSecurityDescription =>
      'Credentials, SSH settings, and host trust';

  @override
  String get currenciesReferenceRates => 'Currencies and reference rates';

  @override
  String currencyRateSummary(String p0, String p1) {
    return '$p0 · Manual rates: $p1';
  }

  @override
  String get notSet => 'Not set';

  @override
  String get notificationAccess => 'Notification access';

  @override
  String get backupExclusionsSummary =>
      'Excludes credentials and host trust · Unencrypted JSON';

  @override
  String get about => 'About';

  @override
  String get developmentVersion => 'Development build · 0.1.0';

  @override
  String get appLocalDataHelp =>
      'Data stays on this device; no account needed. Archiving does not cancel the service or stop billing.';

  @override
  String get groupSaveFailed =>
      'Could not save the group. Check for a duplicate name, then try again.';

  @override
  String deleteGroupQuestion(String p0) {
    return 'Delete “$p0”?';
  }

  @override
  String get deleteGroupHelp =>
      'All servers in this group, including archived ones, will move to Ungrouped. Server details and payment history are kept. Remote servers are unchanged.';

  @override
  String get deleteGroup => 'Delete group';

  @override
  String get addGroup => 'Add group';

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
  String get moveUp => 'Move up';

  @override
  String get moveDown => 'Move down';

  @override
  String get ungrouped => 'Ungrouped';

  @override
  String ungroupedCountHelp(String p0) {
    return 'Unarchived servers: $p0 · Default group, cannot be deleted';
  }

  @override
  String get archiveHelp =>
      'Archiving keeps the record. Restoring does not start or renew the service.';

  @override
  String get noArchivedRecords => 'No archived records';

  @override
  String get restoreRecord => 'Restore record';

  @override
  String get renameGroup => 'Rename group';

  @override
  String get groupName => 'Group name';

  @override
  String get save => 'Save';

  @override
  String get operationFailed =>
      'The operation did not complete. Try again. Saved details are kept.';

  @override
  String get recordChanged => 'This record has changed. Go back and try again.';

  @override
  String get gotIt => 'Got it';

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
  String get financePayments => 'Payment records';

  @override
  String get financeCalculationRules => 'Calculation basis';

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
  String get financeNotApplicable => 'Not applicable / Excluded';

  @override
  String get financeDataUnknown => 'Information unknown';

  @override
  String get financeMissingFxPreserved =>
      'Exchange rate missing · Original currency retained';

  @override
  String get financeMissingFxExcluded =>
      'Only amounts with an exchange rate are totaled. Missing amounts are not treated as zero.';

  @override
  String get financeValuationAndDue => 'Valuation date / Service expiry date';

  @override
  String get financeRemainingDays => 'Remaining service days';

  @override
  String get financeRenewalCycle => 'Renewal price / Cycle';

  @override
  String get financeDailyShown => 'Daily average for the shown period';

  @override
  String get r2CopyMetricDaysLeft => 'Days left';

  @override
  String get r2CopyMetricDaily => 'Daily';

  @override
  String get financeInferredPeriods =>
      'Start dates are inferred from the expiry date; not proof of payment.';

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
  String get financeFxTitle => 'Currencies and reference exchange rates';

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
  String get financeSaveFx => 'Save reference rates';

  @override
  String get financeReferenceTitle => 'Use server details';

  @override
  String get financeReferenceNote =>
      'Copies current renewal details only; the server is not changed.';

  @override
  String get financeNoPrepaid =>
      'No prepaid servers are available. You can calculate an independent estimate.';

  @override
  String get financeDateRangeError =>
      'Check the dates. Estimates are limited to a 100-year range.';

  @override
  String get financeMissingPeriodsError =>
      'The referenced details have no valid service period. Add the server dates first, or change the expiry date or cycle to calculate an independent estimate.';

  @override
  String get financeCalculatorTitle => 'Remaining value calculator';

  @override
  String get financeReferenceServer => 'Use a server';

  @override
  String get financeIndependentRebuilt =>
      'Switched to an independent estimate; service periods are recalculated from the expiry date and cycle.';

  @override
  String get financeIndependentNote =>
      'Independent estimate, no server needed. Assumes continuous service before expiry.';

  @override
  String get financeRenewalAmount => 'Renewal price per cycle';

  @override
  String get financeAmountError =>
      'Enter a valid amount. Use 0 only when the service is known to be free.';

  @override
  String get financeOriginalCurrency => 'Original currency';

  @override
  String get financeCycle => 'Renewal cycle';

  @override
  String get financeValuationDate => 'Valuation date';

  @override
  String get financeValuationDateError => 'Enter a valid valuation date';

  @override
  String get financeServiceDue => 'Service expiry date';

  @override
  String get financeDueError => 'Enter a valid expiry date';

  @override
  String get financeAlgorithmTitle => 'Periods and calculation method';

  @override
  String get financeAlgorithmNote =>
      'Remaining value = Σ (renewal price per cycle × fraction of unused days in that cycle).\nCalendar cycles use actual day counts, not fixed 30-day months. Month-end dates are calculated backward from the original expiry anchor, with leap years handled for yearly cycles. Valuing a period before its known start does not exceed its full price.\nIndependent mode works backward to cover the valuation date, up to 100 years. Value is 0 on the expiry date. Transferability and refund eligibility are not checked.';

  @override
  String get financeCalculateValue => 'Calculate remaining value';

  @override
  String get financeEstimateNoWrite =>
      'Estimates never change any server or payment.';

  @override
  String get financeReferenceRateMissing => 'Reference exchange rate missing';

  @override
  String get financeIndependentBasis =>
      'Independent assumption: service is continuous before expiry, with periods calculated backward from the expiry date.';

  @override
  String get financeQuoteFxError =>
      'The required exchange rate is missing. Reference value and settlement amounts cannot be calculated.';

  @override
  String get financeCopied =>
      'Result copied. It contains calculation information only.';

  @override
  String get financeCopyError =>
      'Could not write to the clipboard. Please try again.';

  @override
  String get financeResultTitle => 'Calculation result';

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
  String get financeCalculateQuote => 'Calculate quote and fees';

  @override
  String get financePremiumLabel =>
      'Quote minus reference value (premium / discount)';

  @override
  String get financeBuyerSellerFee => 'Buyer / Seller fee';

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
      'The payment date cannot be later than today';

  @override
  String get financePaymentConfirmError =>
      'Confirm that you have paid the provider and checked the details';

  @override
  String get financeBillPeriodError =>
      'Enter both billing period dates together. The end must be later than the start.';

  @override
  String get financePaymentSavedRefresh =>
      'Payment saved, but the display has not updated. Please reload.';

  @override
  String get financeAccountPaymentSaved =>
      'Account bill recorded once. Instance expiry dates are unchanged.';

  @override
  String get financePaymentSaved =>
      'Payment recorded. Service periods and totals are updated.';

  @override
  String get financeRecordPayment => 'Record a completed payment';

  @override
  String get financeNoRenewalDate =>
      'No usable prepaid expiry date. Check the server details.';

  @override
  String get financeRecordAccountBill => 'Record an account bill';

  @override
  String get financeLocalPaymentOnly =>
      'Records a local ledger entry only. No payment is made to the provider.';

  @override
  String get financeAccountBillNote =>
      'Standalone bill, counted once. Not split; creates no service period.';

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
  String get financeNewDue => 'New expiry date';

  @override
  String get financeNewDueHint =>
      'Must match the date calculated from the selected cycles';

  @override
  String get financePaymentRenewalNote =>
      'The amount paid is stored separately and does not change the renewal price. Whole cycles only.';

  @override
  String get financeBillStart => 'Billing period start (optional)';

  @override
  String get financeBillEnd => 'Billing period end (optional)';

  @override
  String get financeOptionalNote => 'Note (optional)';

  @override
  String get financeConfirmAccountPaid =>
      'I have paid the provider and checked the bill amount and dates.';

  @override
  String get financeConfirmServerPaid =>
      'I have paid the provider and checked the amount paid and new expiry date.';

  @override
  String get financeSavePayment => 'Save payment record';

  @override
  String get financeNotReceipt =>
      'This is not a provider payment receipt and does not change auto-renewal settings.';

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
  String get financeArchivedPayment =>
      'Server archived · Past payments retained';

  @override
  String get financeNoPaymentsInRange =>
      'No payments in this range. Record completed renewal payments from the server details page.';

  @override
  String get financeVoidTitle => 'Void this local record?';

  @override
  String get financeVoidAccountNote =>
      'Marks this bill as voided. No refund is requested from the provider.';

  @override
  String get financeVoidServerNote =>
      'Reverts only the service periods and expiry date added by this record and marks the payment as voided. It does not request a provider refund or cancel service.';

  @override
  String get financeVoidRecord => 'Void record';

  @override
  String get financePaymentVoided =>
      'This local payment record has been voided';

  @override
  String get financePaymentDetail => 'Payment details';

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
  String get financeBillServicePeriod => 'Billing / Service period';

  @override
  String get financeVoidedStatus => 'Deleted, excluded from payment totals';

  @override
  String get financeRecordedStatus => 'Recorded';

  @override
  String get financePaymentHistoryNote =>
      'Original-currency history; it does not follow renewal prices or exchange rates.';

  @override
  String get financeVoidThisRecord => 'Void this record';

  @override
  String get r2FinanceEdit => 'Edit';

  @override
  String get r2FinanceEditTitle => 'Edit payment';

  @override
  String get r2FinanceEditHint =>
      'Only edits the bookkeeping. Service periods, due date and cycles stay as they are.';

  @override
  String get r2FinanceDelete => 'Delete record';

  @override
  String get r2FinanceDeleteTitle => 'Delete this payment record?';

  @override
  String get r2FinanceDeleteAccountMsg =>
      'Deletes this bill from the local ledger only. No server is affected and nothing is refunded by the provider. It no longer counts towards payment totals.';

  @override
  String get r2FinanceDeleteKeepMsg =>
      'Deletes the payment record only. Service periods and the due date stay as they are (the server has changed since, so the renewal cannot be rolled back). Nothing is refunded by the provider.';

  @override
  String get r2FinanceDeleteChoiceMsg =>
      'You can also roll back this renewal (restore the previous due date and remove its service periods), or delete only the record and keep the periods and due date. Neither option refunds anything at the provider.';

  @override
  String get r2FinanceDeleteRollback => 'Delete and roll back renewal';

  @override
  String get r2FinanceDeleteKeep => 'Delete record only, keep periods';

  @override
  String get r2FinanceDeleted => 'Payment record deleted';

  @override
  String get r2FinanceUpdated => 'Payment record updated';

  @override
  String get financeVoidBlocked =>
      'Details have changed. Please check them. After later edits, payments, or archiving, an old record cannot overwrite the current details.';

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
      'Renewals spread monthly + metered estimate; not this month’s payments.';

  @override
  String get financeUpcomingRenewals => 'Expected renewals in the next 30 days';

  @override
  String get financeRecentPayments => 'Payment records';

  @override
  String get financeUnrecordedNotZero =>
      'No payments recorded yet. This does not mean there has been no spending.';

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
      'Account-level payments are not split across groups. Tap a category for details.';

  @override
  String get financeSixMonthTitle =>
      'Six months from this month · Prepaid renewals';

  @override
  String get financeForecastNote =>
      'Forecast at current renewal prices, assuming renewal continues. Excludes metered bills and expired services.';

  @override
  String get financeMonthlyDetail => 'Monthly cost details';

  @override
  String get financeValueDetail => 'Remaining value details';

  @override
  String get financeInventoryDetail => 'Server breakdown';

  @override
  String get financeIncompleteDetail => 'Check costs and expiry dates';

  @override
  String get financeMeteredValueNa =>
      'Metered billing · Remaining value is not applicable';

  @override
  String get financeExpiredMonthlyExcluded =>
      'Expired, excluded from the monthly cost reference';

  @override
  String get financeUnknownAmount =>
      'Date or cost details are incomplete; amount unknown';

  @override
  String get financeNoServersInRange => 'No servers in this range.';

  @override
  String get financeUnknownZeroNote =>
      '“—” means unknown or not applicable, not free.';

  @override
  String get financeRenewals30Title => 'Renewals in the next 30 days';

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
      'Image generation failed. The original calculation result is preserved.';

  @override
  String get financePngSaveFailed =>
      'Saving did not finish. The preview is preserved. Check storage space and permissions, then try again.';

  @override
  String get financePngShareSelected =>
      'A system share action was selected. Check delivery in the destination app.';

  @override
  String get financePngShareDismissed =>
      'Sharing canceled. The preview is preserved.';

  @override
  String get financePngShareUnknown =>
      'No system share result was received. The preview is preserved.';

  @override
  String get financePngShareUnsupported =>
      'System sharing of PNG files is not supported on this platform. You can save the file locally.';

  @override
  String get financePngShareBusy =>
      'Finish the current system share action first.';

  @override
  String get financePngShareFailed =>
      'Sharing did not finish. The preview is preserved. Please try again.';

  @override
  String get financePngPreview => 'Image preview';

  @override
  String get financePngPrivacy =>
      'The image has only amounts, dates, periods and reference rates; no server names, addresses or notes.';

  @override
  String get financePngSemantic => 'Remaining value calculation result PNG';

  @override
  String get financeRegenerate => 'Generate again';

  @override
  String get financeSavePng => 'Save PNG';

  @override
  String get financeSharing => 'Sharing…';

  @override
  String get financeSharePng => 'Share PNG';

  @override
  String get financePngLocationNote =>
      'The file may be in an app-private folder. Use system sharing to save it elsewhere.';

  @override
  String get financeRulesBody =>
      'Monthly cost reference: unexpired prepaid renewal prices divided by the cycle length in months, plus metered monthly estimates. Prepaid services are excluded on and after their expiry date. Missing dates or costs are marked unknown.\n\nRemaining value: the current renewal price prorated by unused days in each known service period. The start date is included and the end date excluded. Future whole periods count at full price; ended periods count as 0. Not applicable to metered billing; unknown when details are insufficient. This is not a refundable amount or sale price.\n\nRenewal forecast: assumes continued renewal at the current price and cycle. The next 30 days includes today and the following 29 days. Six months means the rest of this month and the next five calendar months. Expired services are not projected forward. Metered bills are excluded. Local usage plans do not change the forecast.\n\nPayments in the last 30 days: recorded payments from today and the preceding 29 days. The all-groups scope retains payments for archived servers and counts each independent account bill once. Account bills are not allocated to groups.\n\nWhen cross-currency rates are missing, only convertible amounts are totaled, while original-currency subtotals are retained. Exact amounts are summed before rounding to minor units. Reference conversions are not actual charges.';

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
    return 'Uses known periods from $name. Changing the inputs does not change the original server.';
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
      'A discount cannot exceed the remaining value, and the price must stay in range';

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
    return 'Group: $group. Account bills are not included.';
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
      'other': '$date · Expiry date: $due',
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
    return 'Expiry date: $date';
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
    return 'Expired on $date. This does not imply downtime.';
  }

  @override
  String financePngSavedPath(String path) {
    return 'PNG saved:\n$path';
  }

  @override
  String get financeRenewalDateError =>
      'Renewal requires a valid cycle and original expiry date.';

  @override
  String get financeAnchorMismatch =>
      'The service-period anchor does not match the expiry date. Check the details.';

  @override
  String get financeDueRangeError =>
      'The expiry date is outside the supported range.';

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
      'The display currency is not supported.';

  @override
  String get financeInvalidRate =>
      'Exchange rates must be positive, with at most 9 integer digits and 8 decimal places.';

  @override
  String get financeMissingRateDate => 'Enter the manual exchange rate date.';

  @override
  String get financeExportDisclaimer =>
      'This is a price-based estimate of unused service time, not a refund promise or sale price.';

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
    return 'Service expiry date: $due; remaining service days: $days';
  }

  @override
  String financeExportRenewalDaily(String renewal, String daily) {
    return 'Renewal price / Cycle: $renewal; daily average for the shown period: $daily';
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
    return 'Service expiry date: $date';
  }

  @override
  String financeExportRemainingDays(int days) {
    return 'Remaining service days: $days';
  }

  @override
  String financeExportRenewal(String renewal) {
    return 'Renewal price / Cycle: $renewal';
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
  String get backupExcludedConnections =>
      'SSH settings, host trust, panel accounts, instance links, and API-returned information';

  @override
  String get backupExcludedNotes =>
      'Command snippets, server notes, and payment notes';

  @override
  String get backupExcludedPreferences =>
      'Reminder rules, notification schedules, and app preferences (format v1)';

  @override
  String get backupInvalidJson => 'The backup is not valid JSON';

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
      'A server refers to a group that does not exist';

  @override
  String get backupInvalidServer => 'Server field validation failed';

  @override
  String get backupAnchorMismatch =>
      'The renewal anchor and expiry date do not match';

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
      'Service periods do not match the server dates';

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
      'A payment service period does not match the renewal cycle';

  @override
  String get backupInitialPeriodMismatch =>
      'The initial service period is missing or does not match the original dates';

  @override
  String get backupInitialPeriodOutOfRange =>
      'The initial service period is outside the supported date range';

  @override
  String get backupPeriodsNotContinuous =>
      'Active service periods must be continuous';

  @override
  String get backupPeriodsDoNotCoverDue =>
      'Active service periods do not cover the current expiry date';

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
      'Payment service periods exist, so dates, cycles, and billing type cannot be edited directly. Review the payments and safely void eligible records first.';

  @override
  String get invalidGroupName =>
      'Enter a group name of 1–40 characters. The reserved name “未分组” is not allowed.';

  @override
  String get demoRequiresEmptyLedger =>
      'Demo data can be loaded only into an empty ledger';

  @override
  String get futureRateDate => 'The exchange-rate date cannot be in the future';

  @override
  String get invalidPaymentId => 'Invalid payment ID';

  @override
  String get invalidPaidAmount =>
      'Enter a valid amount actually paid. Enter 0 for free.';

  @override
  String get futurePaymentDate => 'The payment date cannot be in the future';

  @override
  String get notesTooLong => 'Notes can contain up to 4,000 characters';

  @override
  String get paymentAlreadyVoided =>
      'This payment is already voided. Check the details and create a new record.';

  @override
  String get paymentIdContentMismatch =>
      'This payment ID has different details. Do not enter it again.';

  @override
  String get confirmProviderPayment =>
      'Confirm that you paid the provider and checked the amount and dates';

  @override
  String get invalidRenewalCycleCount => 'Select 1–3 valid renewal cycles';

  @override
  String get renewalNeedsPrepaidDate =>
      'Only prepaid services with a known expiry date can be renewed';

  @override
  String get renewalDateMismatch =>
      'The new expiry date does not match the selected cycles and original renewal anchor';

  @override
  String get duplicateExpiryPayment =>
      'A payment already exists for this service expiry date. Do not enter it again.';

  @override
  String get invalidAccountName =>
      'The account name must contain 1–80 characters';

  @override
  String get invalidOptionalBillingPeriod =>
      'For an optional billing period, enter valid start and end dates. The end must be after the start.';

  @override
  String get invalidCredentialDetails => 'Invalid credential details';

  @override
  String get secretWriteNotPrepared => 'The secret write is not ready';

  @override
  String get chooseOtherCredential => 'Choose a different credential';

  @override
  String get invalidSshConfiguration =>
      'Enter a valid host, port, and explicit username';

  @override
  String get verificationCancelled => 'Verification cancelled';

  @override
  String get invalidServerName =>
      'The server name must contain 1–80 characters';

  @override
  String get completeLocalResources =>
      'Complete and confirm all six local resource fields first';

  @override
  String get securityOperationIncomplete =>
      'The security operation did not complete. Try again.';

  @override
  String get cloudAccounts => 'Adapter instances';

  @override
  String get cloudAddAccount => 'Add adapter instance';

  @override
  String get cloudPanelReadBadge => 'Read-only panel connections';

  @override
  String get cloudManageConnections =>
      'Manage adapter instances and device links';

  @override
  String get cloudConnectionsInfo =>
      'Each adapter instance has its own authorization and read scope.\nA provider can have multiple single-device or account-scoped adapter instances.';

  @override
  String get cloudMetadataIncomplete =>
      'Adapter instance details could not be fully loaded. Reload them to continue.';

  @override
  String get cloudReloadMetadata => 'Reload adapter instance details';

  @override
  String get cloudCleanupNotice =>
      'Old credentials awaiting cleanup may still be in secure storage on this device. Retry cleanup; revoke remote authorization in the panel.';

  @override
  String get cloudRetryCleanup => 'Retry old credential cleanup';

  @override
  String get cloudFirstAccount => 'Add your first adapter instance';

  @override
  String get cloudFirstAccountInfo =>
      'Choose an adapter type and verify its authorization, then review devices and resources before adding them to the ledger.';

  @override
  String get cloudChooseTemplate => 'Choose an adapter type';

  @override
  String get cloudReadOnlyBoundary =>
      'This app only reads data; the API credentials themselves may have other permissions.\nAdapter authorization and SSH credentials are managed separately. Unlinking keeps local records, costs, payments, and SSH settings.';

  @override
  String get cloudTemplateInfo =>
      'Choose the adapter type matching the panel. The provider is the business supplying the servers.';

  @override
  String get cloudV1TemplateInfo =>
      'Client API Key + Hash\nEach credential pair corresponds to one VPS';

  @override
  String get cloudV2TemplateInfo =>
      'User API Token\nRead the current user’s projects and devices';

  @override
  String get cloudRackNerdTemplateInfo =>
      'ctrl panel Client API Key + Hash\nRead one VPS through the compatible client interface';

  @override
  String get cloudSupportedPanels =>
      'Reads from SolusVM 1 / 2 and RackNerd ctrl. No power control, no remote changes, and billing is not stopped.';

  @override
  String get cloudReauthorize => 'Authorize again';

  @override
  String get cloudSingleVpsApi => 'Single VPS / Client API';

  @override
  String get cloudUserAccountApi => 'User account / API Token';

  @override
  String get cloudWebPreviewNotice =>
      'Web preview does not accept real API credentials. Connect in the native app.';

  @override
  String get cloudAliasLabel => 'Adapter instance name';

  @override
  String get cloudAliasRequired => 'Enter an adapter instance name';

  @override
  String get cloudEndpointLabel => 'HTTPS panel address';

  @override
  String get cloudEndpointValidation =>
      'Enter the HTTPS panel home address without credentials, parameters, or an API path';

  @override
  String get cloudEndpointInfo =>
      'Use the HTTPS panel home address (a specific port is fine). Certificate errors are not bypassed and redirects are not followed.';

  @override
  String get cloudRackNerdEndpointValidation =>
      'Enter the HTTPS panel home address, or the exact /api/client/command.php address, without credentials, parameters, or other paths';

  @override
  String get cloudRackNerdEndpointInfo =>
      'Use the HTTPS panel home address (a specific port is fine) and check the final address below. Certificate errors are not bypassed and redirects are not followed.';

  @override
  String get cloudEndpointIdentityInfo =>
      'The panel address is tied to this connection’s identity. Add a new connection for another panel. Saved credentials are not shown here.';

  @override
  String get cloudV1CredentialsInfo =>
      'Enter this VPS’s Client API Key / Hash (not a login password or admin credentials). The provider must enable Client API.';

  @override
  String get cloudRackNerdCredentialsInfo =>
      'Enter the Client API Key / Hash of this VPS from RackNerd ctrl (not a login password or admin credentials).';

  @override
  String get cloudV2CredentialsInfo =>
      'Use a token from Account → API Tokens in the SolusVM 2 user area, not an administrator token.';

  @override
  String get cloudV1ReauthorizationInfo =>
      'This API cannot prove that new credentials belong to the original VPS. After verification, explicitly confirm unlinking old associations, then choose whether to import new records. Existing ledger records, costs, and SSH settings are kept.';

  @override
  String get cloudV2ReauthorizationInfo =>
      'Reauthorization must verify the same remote user account. Otherwise the original authorization and links are kept.';

  @override
  String get cloudVerifyScopeInfo =>
      'This app only reads data, but the credentials may allow more. Verification only reads status; credentials enter secure device storage when you save.';

  @override
  String get cloudVerifyingInfo =>
      'Verifying and reading with a timeout. Going back or cancelling stops it.';

  @override
  String get cloudCancelVerification => 'Cancel verification';

  @override
  String get cloudVerifyRead => 'Verify and read';

  @override
  String get cloudCredentialMemoryInfo =>
      'Credential fields are cleared after verification or on leaving. They are not written to the ledger, logs, or exports. Dart does not guarantee secure memory erasure.';

  @override
  String get r2CopyInfoCredentialHandling => 'How credentials are handled';

  @override
  String get cloudChooseInstances => 'Choose devices to import';

  @override
  String get cloudEmptyVerification =>
      'This authorization returned no devices to import. You can save the adapter instance and read it again later.';

  @override
  String get cloudEmptyInventory =>
      'The complete read returned no devices to import. The adapter instance is saved; you can read it again later.';

  @override
  String get cloudV1Instance => 'The single VPS for these credentials';

  @override
  String get cloudAlreadyLinked => 'Already linked · Duplicate import skipped';

  @override
  String get cloudV1Identity =>
      'No stable device ID · Identified by this separate authorization';

  @override
  String get cloudIpNotProvided => 'IP not provided';

  @override
  String get cloudSelectBeforeComplete =>
      'Select the device above, then complete the details below. Filling in details alone does not import it.';

  @override
  String get cloudLocalDisplayName => 'Local display name (optional)';

  @override
  String get cloudLocalNameInfo =>
      'Used only for the new local record, not as remote device identity';

  @override
  String get cloudV1ResourcesInfo =>
      'SolusVM 1 provides no device ID and the readable fields depend on the provider. What you enter stays on this device.';

  @override
  String get cloudRackNerdResourcesInfo =>
      'RackNerd ctrl provides no device ID. Complete the six hardware fields before import; do not guess values the API omits.';

  @override
  String get cloudRebindWarning =>
      'Saving new authorization removes this instance’s old device links. Existing records, finances and SSH are kept; importing creates new records and never overwrites or relinks old devices.';

  @override
  String get cloudConfirmRebind =>
      'I confirm that saving new authorization will remove old device links';

  @override
  String get cloudReturnSelect => 'Return to device selection';

  @override
  String get cloudSaving => 'Saving…';

  @override
  String get cloudNoneSelected => 'No new devices selected';

  @override
  String get cloudSaveOnly => 'Save adapter instance only';

  @override
  String get cloudUpdateUnlink =>
      'Update authorization and remove old device links';

  @override
  String get cloudUpdateOnly => 'Update authorization only';

  @override
  String get cloudReturnVerify => 'Go back to verify again';

  @override
  String get cloudSavingInfo =>
      'Saving to this device. Please wait until it finishes before going back.';

  @override
  String get cloudReadImportable => 'Read devices available to import';

  @override
  String get cloudRefreshAccount => 'Refresh adapter instance status';

  @override
  String get cloudReadingInfo =>
      'Reading with a timeout. Cancelling or going back stops it without changing the ledger.';

  @override
  String get cloudCancelRead => 'Cancel read';

  @override
  String get cloudReadAgain => 'Read again';

  @override
  String get cloudReadCompleteInfo =>
      'Only read results were updated; local details were not overwritten.';

  @override
  String get cloudDone => 'Done';

  @override
  String get cloudViewDetails => 'View adapter instance details';

  @override
  String get cloudRenameAccount => 'Edit adapter instance name';

  @override
  String get cloudContinueImport => 'Import more devices';

  @override
  String get cloudLinkedServers => 'Linked servers';

  @override
  String get cloudUnlinkAccount => 'Delete adapter instance';

  @override
  String get cloudUnlinkAccountTitle => 'Delete this adapter instance?';

  @override
  String get cloudUnlinkLocal => 'Delete local adapter instance';

  @override
  String get cloudAccountDetails => 'Adapter instance details';

  @override
  String get cloudAccountRemovedNotice =>
      'The adapter instance was deleted. All local device records are kept.';

  @override
  String get cloudTemplateLabel => 'Adapter type';

  @override
  String get cloudPanelAddress => 'Panel address';

  @override
  String get cloudReadStatus => 'Read status';

  @override
  String get cloudLastAttempt => 'Last read attempt';

  @override
  String get cloudNoAttempts => 'No attempts yet';

  @override
  String get cloudVerifiedScope => 'Verified read scope';

  @override
  String get cloudV1Scope =>
      'Single device · Client API, without stable device identity';

  @override
  String get cloudAppCapabilities => 'App capabilities';

  @override
  String get cloudReadCapabilities => 'Reads data only; no API power control';

  @override
  String get cloudAuthorizationStorage => 'Credential storage';

  @override
  String get cloudSecureStorageInfo =>
      'Secure device storage; API credentials are not shown or exported';

  @override
  String get cloudScopeNotice =>
      'The credentials may allow more; check in the provider’s panel. Results reflect only the time of the read.';

  @override
  String get cloudNoLinkedInstances =>
      'No linked devices yet. Import more from the adapter instance menu.';

  @override
  String get cloudLocalRecord => 'Local record';

  @override
  String get cloudCancel => 'Cancel';

  @override
  String get cloudSaveName => 'Save name';

  @override
  String get cloudLinkPanelAccount => 'Link adapter instance';

  @override
  String get cloudLocalBindingInfo =>
      'Uses saved read results and does not connect to the panel. If no devices appear, refresh the adapter instance first.';

  @override
  String get cloudBindingCommitted =>
      'Link changes were saved. Reload the details before continuing; do not submit again.';

  @override
  String get cloudLedgerNotUpdated =>
      'The displayed ledger has not been updated. Reload it first.';

  @override
  String get cloudReloadLocal => 'Reload local list';

  @override
  String get cloudBindingReadOnly =>
      'Panel links cannot be changed for archived or demo records.';

  @override
  String get cloudCurrentLink => 'Current link';

  @override
  String get cloudUnlinkThis => 'Unlink this server';

  @override
  String get cloudSelectAccount => 'Choose an adapter instance';

  @override
  String get cloudNoSavedAccounts =>
      'This provider has no adapter instances with confirmed ownership. Add and verify one first.';

  @override
  String get cloudSelectReadInstance => 'Choose a previously read device';

  @override
  String get cloudNoSavedInstances =>
      'This adapter instance has no saved device information. Refresh it manually first.';

  @override
  String get cloudOtherServer => 'Another server';

  @override
  String get cloudMissingRefresh =>
      'Not returned in this read · Refresh the adapter instance manually';

  @override
  String get cloudFailedRefresh =>
      'Last read failed · Refresh the adapter instance manually';

  @override
  String get cloudSaveLink => 'Save link';

  @override
  String get cloudChangeLink => 'Change link';

  @override
  String get cloudLocalLinkBoundary =>
      'Only the local link changes. Server details, hardware, finances, and SSH settings are kept.';

  @override
  String get cloudSingleAccountInstance =>
      'The single device for this authorization';

  @override
  String get cloudUnlinkServerTitle => 'Unlink this server from the panel?';

  @override
  String get cloudChangeServerTitle => 'Change this server’s panel link?';

  @override
  String get cloudOnlyUnlinkThis => 'Unlink only this server';

  @override
  String get cloudConfirmChangeLink => 'Confirm link change';

  @override
  String get cloudMetadataReadFailed =>
      'Could not load adapter instance details. Try again.';

  @override
  String get cloudSavedReloadFailed =>
      'Saved, but the details could not be reloaded. Reload before making changes.';

  @override
  String get cloudAccountConflict =>
      'Adapter instance details have changed. Reload them and try again.';

  @override
  String get cloudOperationFailed =>
      'The adapter instance operation did not finish. Try again.';

  @override
  String get cloudCompleteResources =>
      'Complete all six hardware details before importing. Confirm unknown items with the provider first.';

  @override
  String get cloudCleanupIncomplete =>
      'Credential cleanup has not finished. Try again later.';

  @override
  String get cloudCleanupStatusFailed =>
      'Could not read the cleanup status. Try again.';

  @override
  String get cloudVerifyCancelled =>
      'Verification cancelled. Authorization was not saved.';

  @override
  String get cloudAliasInvalid =>
      'The adapter instance name must be 1–80 characters.';

  @override
  String get cloudVerifyFailed =>
      'Verification did not finish. Check the panel address, credentials, and network, then try again.';

  @override
  String get cloudVerifyNotSaved =>
      'Verification did not finish. Authorization was not saved.';

  @override
  String get cloudVerifyAgainRequired =>
      'Authorization was not saved. Verify again before importing.';

  @override
  String get cloudAuthorizationExpired =>
      'This authorization was cleared when you left the app. Go back and verify again. Any uncommitted save was cancelled.';

  @override
  String get cloudResourcesIncomplete =>
      'Check and complete all six hardware details. Confirm unknown items with the provider, then import once they are complete.';

  @override
  String get cloudSaveFailed => 'Saving did not finish. Try again.';

  @override
  String get cloudAccountSavedOnly =>
      'Adapter instance saved. No new devices were imported.';

  @override
  String get cloudInstancesSaved =>
      'Saved. Selected devices were added to the local ledger.';

  @override
  String get cloudReadCancelled =>
      'Read cancelled. Previously read information is kept.';

  @override
  String get cloudAccountUnlinkedReturn =>
      'The adapter instance was deleted. Go back to continue.';

  @override
  String get cloudReadIncomplete =>
      'The read did not finish. Previously read information is kept.';

  @override
  String get cloudAliasSaved => 'Adapter instance name saved.';

  @override
  String get cloudNameSaveFailed => 'The name was not saved. Try again.';

  @override
  String get cloudAccountUnlinked =>
      'Adapter instance deleted. Local details, finances, and SSH settings are kept.';

  @override
  String get cloudUnlinkFailed =>
      'Deleting the adapter instance did not finish. Try again.';

  @override
  String get cloudAliasRange =>
      'Enter an adapter instance name of 1–80 characters.';

  @override
  String get cloudBindingReadFailed =>
      'Could not load local link details. Try again.';

  @override
  String get cloudServerUnlinked => 'This server’s panel link was removed.';

  @override
  String get cloudBindingSaved => 'Adapter instance link saved.';

  @override
  String get cloudFailureInvalidEndpoint =>
      'Enter the HTTPS panel home address without login details, query parameters, or an API path.';

  @override
  String get cloudFailureInvalidCredentials =>
      'Enter valid API credentials for this template.';

  @override
  String get cloudFailureUnauthorized =>
      'The API credentials could not be verified. Check them or authorize again.';

  @override
  String get cloudFailureApiRejected =>
      'The panel rejected the API read. Check the credentials, API availability, and service status.';

  @override
  String get cloudFailureForbidden =>
      'The panel denied the read. Check API permissions and provider settings.';

  @override
  String get cloudFailureRateLimited =>
      'Too many panel requests. Retry manually later.';

  @override
  String get cloudFailureUnavailable =>
      'The panel is temporarily unable to serve API reads.';

  @override
  String get cloudFailureConnection =>
      'Connection failed. Check the network, panel address, and HTTPS certificate.';

  @override
  String get cloudFailureTimeout =>
      'The read timed out. Previously read information is kept. Try again later.';

  @override
  String get cloudFailureCancelled => 'Read cancelled.';

  @override
  String get cloudFailureRedirect =>
      'The panel returned a redirect. The request stopped to protect credentials. Check the panel address.';

  @override
  String get cloudFailureInvalidResponse =>
      'The panel response did not match the read protocol. Local details were not updated.';

  @override
  String get cloudFailureResponseTooLarge =>
      'The panel response exceeds the safe size limit.';

  @override
  String get cloudFailureInventoryTooLarge =>
      'The number of devices or pages exceeds this read’s limit. The incomplete list was not imported.';

  @override
  String get cloudFailureUnsupportedPlatform =>
      'This preview platform does not accept real API credentials. Use the native app.';

  @override
  String get cloudAccountFailureIdentity =>
      'The remote account or device identity changed. Existing links were not changed. Create a separate adapter instance.';

  @override
  String get cloudAccountFailureV1Rebind =>
      'This client API cannot prove that new credentials belong to the original device. Explicitly confirm removing old links, then choose devices to import. Existing local records are kept.';

  @override
  String get cloudAccountFailureSelection =>
      'The import list changed or the selection is invalid. Read it again.';

  @override
  String get cloudAccountFailureAlias =>
      'The adapter instance name must be 1–80 characters.';

  @override
  String get cloudAccountFailureSecret =>
      'API credentials could not be saved to secure device storage. Original authorization is unchanged. Unlock the device and try again.';

  @override
  String get cloudAccountFailureSecretRead =>
      'Could not read this adapter instance’s saved API credentials. Unlock the device and try again. If it still fails, authorize again from its menu.';

  @override
  String get cloudAccountFailureBindingTaken =>
      'This device is linked to another local server and cannot be overwritten. Reload the local list.';

  @override
  String get cloudAccountFailureBindingUnavailable =>
      'Device information is not currently available for linking. Refresh the adapter instance manually, then select it again.';

  @override
  String get cloudReadLimitPositive => 'Read limits must be greater than zero.';

  @override
  String cloudProviderLinks(String provider, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count linked servers',
      one: '1 linked server',
    );
    return '$provider · $_temp0';
  }

  @override
  String cloudRequiredField(String label) {
    return 'Enter $label';
  }

  @override
  String cloudConnectProvider(String provider) {
    return 'Connect $provider';
  }

  @override
  String cloudVerifyTarget(String normalization, String origin) {
    return '${normalization}Verification will connect to: $origin';
  }

  @override
  String cloudInventoryComplete(int count, String time, String authorization) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count devices',
      one: '1 device',
    );
    return 'Complete read finished · $_temp0\nRead at: $time$authorization';
  }

  @override
  String cloudInstanceFallback(String id) {
    return 'Device $id';
  }

  @override
  String cloudProjectInstance(String project, String id) {
    return 'Project $project · Device ID $id';
  }

  @override
  String cloudPowerLastRead(String power) {
    return 'Power: $power · Last read';
  }

  @override
  String cloudImportBoundary(String deduplication) {
    return 'Importing does not overwrite existing local names, costs, payments, notes, or SSH settings. $deduplication Archived linked records are also not imported again.';
  }

  @override
  String cloudV2Scope(String id) {
    return 'Verified user account $id · Projects and devices';
  }

  @override
  String cloudLinkedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count linked servers',
      one: '1 linked server',
    );
    return '$_temp0';
  }

  @override
  String cloudRecordWithState(String name, String state) {
    return '$name$state';
  }

  @override
  String cloudBindingWithTime(String summary, String time) {
    return '$summary\nRead at: $time';
  }

  @override
  String get cloudConsolePathRemoved => 'Removed /home.php.\n';

  @override
  String get cloudRackNerdApiPathRemoved =>
      'Removed /api/client/command.php for RackNerd ctrl.\n';

  @override
  String get cloudAuthorizationUnsaved =>
      '\nThis authorization has not been saved';

  @override
  String get cloudV1Deduplication =>
      'Devices already pinned to this authorization are not created again. Separate authorizations are not merged.';

  @override
  String get cloudV2Deduplication =>
      'Duplicates are judged by adapter, panel address, account, project and device ID. A matching IP or hostname is only a hint.';

  @override
  String get cloudArchivedSuffix => ' · Archived';

  @override
  String cloudImportCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count devices',
      one: '1 device',
    );
    return 'Import $_temp0';
  }

  @override
  String cloudSaveImportCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count devices',
      one: '1 device',
    );
    return 'Save adapter instance and import $_temp0';
  }

  @override
  String cloudUnlinkAccountMessage(String alias, String remoteAction) {
    return '$alias\n\nDelete this local adapter instance and its device links. Adding it again requires API credentials. Remote devices are not destroyed and billing does not stop.\n\n$remoteAction';
  }

  @override
  String get cloudRevokeV1 =>
      'You must also disable this VPS’s Client API or reset its Key / Hash in the panel.';

  @override
  String get cloudRevokeV2 =>
      'You must also revoke the issued token in the panel.';

  @override
  String cloudSuggestedAlias(String provider) {
    return 'My $provider adapter';
  }

  @override
  String cloudReadAt(String time) {
    return 'Read at: $time';
  }

  @override
  String cloudAlreadyLinkedTo(String name) {
    return 'Linked to: $name · Cannot overwrite';
  }

  @override
  String cloudChangeLinkMessage(
    String server,
    String account,
    String instance,
    String replacement,
  ) {
    return '$server\nCurrent: $account · $instance$replacement\n\nOnly the local link changes. Server details, hardware, costs, payments, SSH settings, the adapter instance, and authorization are kept. No remote devices are changed and billing does not stop.';
  }

  @override
  String cloudReplacementLink(String account, String instance) {
    return '\nReplace with: $account · $instance';
  }

  @override
  String get cloudPowerRunning => 'Running';

  @override
  String get cloudPowerStopped => 'Stopped';

  @override
  String get cloudPowerUnknown => 'Unknown';

  @override
  String get cloudMissingKept =>
      'Not returned in this read · Previous information kept';

  @override
  String get cloudFailedKept => 'Read failed · Previous information kept';

  @override
  String get cloudLastRead => 'Last read';

  @override
  String get cloudAuthorizationFailedKept =>
      'Authorization verification failed · Existing ledger kept';

  @override
  String get cloudVerifiedManual => 'Verified · Manual reads';

  @override
  String get cloudStepTemplate => 'Adapter type';

  @override
  String get cloudStepCredentials => 'Credentials';

  @override
  String get cloudStepInstances => 'Devices';

  @override
  String get cloudApiUnknown => 'Unknown (not provided by API)';

  @override
  String cloudBindingSummary(String freshness, String power) {
    return '$freshness · Power: $power';
  }

  @override
  String cloudStepLabel(int number, String label) {
    return '0$number $label';
  }

  @override
  String get serverNameRange => 'The name must contain 1–80 characters';

  @override
  String get serverVendorRange => 'The provider must contain 1–80 characters';

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
  String get serverDueAfterStart =>
      'The expiry date must be after the start date';

  @override
  String get resourceMonth => 'Month';

  @override
  String get resourceQuarter => 'Quarter';

  @override
  String get resourceYear => 'Year';

  @override
  String get resourceValidIp =>
      'Enter a valid IPv4 or IPv6 address. Unspecified addresses are not allowed.';

  @override
  String get resourceValidHostname =>
      'Enter a valid hostname without a protocol, port, or path';

  @override
  String get resourceValidVcpu =>
      'vCPU count must be a whole number from 1 to 65,536';

  @override
  String get resourceValidRam =>
      'Memory capacity must be a valid positive number';

  @override
  String get resourceValidDisk =>
      'Disk capacity must be a valid positive number';

  @override
  String get resourceValidTraffic =>
      'Enter a valid positive traffic quota, or explicitly select unlimited';

  @override
  String get resourceValidPeriod =>
      'Choose a monthly, quarterly, yearly, or unset traffic period';

  @override
  String get resourceInvalidSources => 'Invalid resource-source fields';

  @override
  String get resourceUnknownApiSource =>
      'Unknown resources cannot be marked as API-sourced';

  @override
  String get resourceTooLarge => 'Local resource configuration is too large';

  @override
  String get resourceInvalidFields => 'Invalid local resource fields';

  @override
  String get resourceInvalidSourceFields =>
      'Invalid local resource-source fields';

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
  String get resourceSourceManual => 'Source: entered manually';

  @override
  String get resourceSourceApi => 'Source: API';

  @override
  String get resourceSourceUnlimited => 'Source: unlimited confirmed manually';

  @override
  String get resourceSourceMissing =>
      'Needs input: the API did not return a valid value';

  @override
  String get resourceSourceCompleted => 'Source: completed manually';

  @override
  String get resourceSourceEditedApi => 'Source: API value edited manually';

  @override
  String get resourceFieldValidIp =>
      'Enter a valid IPv4 or IPv6 address, not an all-zero address';

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
  String get resourceSixRequired =>
      'Hardware details · All six fields required';

  @override
  String get resourceHardware => 'Hardware details';

  @override
  String get resourceImportHelp =>
      'Check and complete all six fields before importing. Capacities use base 1024; 0 does not mean unlimited. Skip this instance for now if details are missing, then import it once they are complete.';

  @override
  String get resourceLocalHelp =>
      'Capacities use 1024 units; panel refresh never overwrites manual edits.';

  @override
  String get resourceIpAddress => 'IP address';

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
  String get serverFilterTitle => 'Filter servers';

  @override
  String get serverGroup => 'Group';

  @override
  String get serverAllGroups => 'All groups';

  @override
  String get serverDueStatus => 'Expiry status';

  @override
  String get serverAllStatuses => 'All statuses';

  @override
  String get serverExpired => 'Expired';

  @override
  String get serverDueNext30 => 'Expires in the next 30 days';

  @override
  String get serverCostDateUnknown => 'Cost / Expiry date unknown';

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
      'Local ledger reloaded. Remote status was not checked.';

  @override
  String get serverAdd => 'Add server';

  @override
  String get serverImportPanel => 'Import from panel account';

  @override
  String get serverFirstTitle => 'Your first VPS\nstarts here';

  @override
  String get serverFirstDescription =>
      'Expiry, costs and connections in one place.';

  @override
  String get serverAddFirst => 'Add your first server';

  @override
  String get serverLoadDemoQuestion => 'Load demo data?';

  @override
  String get serverLoadDemoHelp =>
      'Adds 4 demo records with reserved addresses. Nothing connects to a server; archive them anytime.';

  @override
  String get serverLoadDemo => 'Load demo';

  @override
  String get serverViewDemo => 'View demo data first';

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
  String get serverExpiryNeedsCheck => 'Expiry needs checking';

  @override
  String serverExpiryCounts(String p0, String p1) {
    return 'Expired: $p0 · Expiring within 30 days: $p1';
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
  String get serverSortDue => 'By expiry date';

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
      'Try adjusting the filters. Restore archived records in Settings.';

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
      other: 'Show $count servers',
      one: 'Show 1 server',
    );
    return '$_temp0';
  }

  @override
  String get uiServersRowHint =>
      'Swipe left or long-press a server for quick actions';

  @override
  String get serverClearFilters => 'Clear filters';

  @override
  String get serverListObservationHelp =>
      'No continuous monitoring. Days to expiry use the device date.';

  @override
  String get serverCostsMissing => 'Add cost details';

  @override
  String get serverMeteredBilling => 'Metered billing';

  @override
  String get serverDueUnknown => 'Expiry date unknown';

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
      'Local data only; panel refresh never overwrites it.';

  @override
  String get serverSavedDisplayStale =>
      'Changes saved; displayed details are not yet updated';

  @override
  String get serverReloadBeforeEditing =>
      'Reload the local ledger before making more changes. Do not submit again. Existing data will not be cleared.';

  @override
  String get serverReloadStillFailed =>
      'Reload did not complete. Saved changes are kept. Try reloading later.';

  @override
  String get serverReload => 'Reload';

  @override
  String get serverArchiveQuestion => 'Archive this server record?';

  @override
  String serverArchiveHelp(String p0) {
    return '$p0\n\nArchiving hides the record from the server list and current cost statistics. Payment history is kept. Restore it under Settings / Archived records. This does not stop or destroy the server, or stop provider billing.';
  }

  @override
  String get serverArchiveLocal => 'Archive local record';

  @override
  String get serverArchived =>
      'Archived. Remote resources and billing are unchanged.';

  @override
  String get serverUndo => 'Undo';

  @override
  String get serverUndoArchiveFailed =>
      'Could not undo. Check Archived records in Settings.';

  @override
  String get serverMissingDetails => 'Not yet added';

  @override
  String get serverDetails => 'Server details';

  @override
  String get serverRecordUnavailable =>
      'This record is unavailable. Go back and try again.';

  @override
  String get serverRemoveFavorite => 'Remove from favorites';

  @override
  String get serverSetFavorite => 'Add to favorites';

  @override
  String get serverMoreActions => 'More actions';

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
  String get serverCopyHost => 'Copy host address';

  @override
  String get serverHostCopied => 'Host address copied';

  @override
  String get serverCopyHostFailed =>
      'Could not copy the host address. Try again.';

  @override
  String get serverOperatingSystem => 'Operating system';

  @override
  String get serverGroupPurpose => 'Group / Purpose';

  @override
  String get serverSpecifications => 'Specifications';

  @override
  String get serverLocalInfoHelp =>
      'These are local details. Panel refreshes do not overwrite them. A connection test does not prove ongoing service availability.';

  @override
  String get serverEditHardware => 'Edit hardware';

  @override
  String get serverPanelLink => 'Panel link';

  @override
  String get serverNoPanelLink => 'No linked panel account';

  @override
  String get serverPanelLinkHelp =>
      'Panel refresh never overwrites what you entered.';

  @override
  String get serverLinkPanel => 'Link panel account';

  @override
  String get serverManageLink => 'Manage link';

  @override
  String get serverReloadPanelDetails => 'Reload panel account details';

  @override
  String get serverCostExpiry => 'Costs and expiry';

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
  String get serverServiceDue => 'Service expiry date';

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
  String get serverReminderPlan => 'Expiry reminders and usage plan';

  @override
  String get serverRemindersOff => 'Reminders off';

  @override
  String get serverRemainingValue => 'Remaining value';

  @override
  String get serverUnknownValueHelp =>
      'Dates or cost details are incomplete. Remaining value is unknown, not 0.';

  @override
  String get serverRecordPayment => 'Record a payment made';

  @override
  String get serverUseForCalculation => 'Calculate using these details';

  @override
  String get serverViewPayments => 'View payment records';

  @override
  String get serverConnectionsControl => 'Connections and controls';

  @override
  String get serverSshSettings => 'SSH connection settings';

  @override
  String get serverSshSettingsDescription =>
      'Connection address, port, username, and credentials';

  @override
  String get serverConnectSsh => 'Connect with SSH';

  @override
  String get serverTcpTest => 'TCP test';

  @override
  String get serverPower => 'Server power';

  @override
  String get serverConnectionSafety =>
      'Verify the host fingerprint on first connect. Shutdown or reboot does not stop billing.';

  @override
  String get serverNotes => 'Notes';

  @override
  String serverSavedMetadata(String p0, String p1) {
    return 'Saved locally: $p0\nServer ID: $p1';
  }

  @override
  String get uiDetailCopy => 'Copy';

  @override
  String get uiDetailMenuValuation => 'Use for remaining-value estimate';

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
  String get uiDetailFillIn => 'Fill in';

  @override
  String get uiDetailHostKey => 'Host key';

  @override
  String get uiDetailHostKeyTrusted => 'Verified';

  @override
  String get uiDetailHostKeyFirstUse => 'Verified on first connect';

  @override
  String get uiDetailNotConfigured => 'Not set up';

  @override
  String get uiDetailNeedSshTitle => 'SSH is not set up';

  @override
  String uiDetailNeedSshMessage(String name) {
    return 'Set the address, port, username and credential for $name before connecting or using power actions.';
  }

  @override
  String get uiDetailGoConfigure => 'Set up';

  @override
  String get uiDetailArchivedUnavailable =>
      'This action is not available for archived servers.';

  @override
  String get uiDetailNotPrepaid =>
      'Only prepaid servers can record renewal payments.';

  @override
  String get uiDetailCannotRenew =>
      'The due date or renewal cycle is incomplete, so a renewal payment cannot be recorded yet. Fill in the cost details first.';

  @override
  String get uiDetailReadOnly =>
      'Local data is still loading or busy, so a payment cannot be recorded now. Reload first.';

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
  String get serverPlainHost =>
      'Enter an IP address or domain without a protocol, port, or path';

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
  String get serverDueDate => 'Expiry date';

  @override
  String get serverOptionalStart => 'Service start date (optional)';

  @override
  String get serverOptionalDue => 'Service expiry date (optional)';

  @override
  String get serverManualAdd => 'Add manually';

  @override
  String get serverEditTitle => 'Edit server';

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
  String get serverOptionalHost => 'Host address (optional)';

  @override
  String get serverHostExample => 'IPv4, IPv6, or domain; no protocol or port';

  @override
  String get serverNewHostHelp =>
      'For new records, leaving this blank uses the IP or hostname from hardware details. Set the SSH connection address separately.';

  @override
  String get serverSavedHostHelp =>
      'This address is saved separately. Editing hardware does not change it. Set the SSH connection address separately.';

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
      'Payments exist: billing type, cycle and dates are locked.';

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
      'Notes are not encrypted. Do not store passwords, keys or tokens.';

  @override
  String get serverSave => 'Save server';

  @override
  String get uiFormProvider => 'Provider';

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
  String get uiFormSetUnknown => 'Set unknown';

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
  String get r2FormAddressHelp =>
      'Empty address uses the hardware IP or hostname; SSH address is separate.';

  @override
  String get r2FormProviderLocked =>
      'Change the provider from the detail page.';

  @override
  String get serverWaitForOperation =>
      'Wait for the current operation to finish';

  @override
  String get serverReloadSavedFirst => 'Reload the saved ledger first';

  @override
  String get connectionBrowserTcpUnsupported =>
      'Browsers do not provide native TCP. Use the native app.';

  @override
  String get connectionHostKeyUnverified =>
      'Could not verify the complete host public key. Connection blocked.';

  @override
  String get connectionHandshakeUnsupported =>
      'Unsupported SSH handshake format or size';

  @override
  String get tcpValidIpv6 => 'Enter a valid IPv6 address';

  @override
  String get tcpValidHost =>
      'Enter an IP address or domain without a protocol, port, or path';

  @override
  String get tcpValidPort => 'The port must be between 1 and 65,535';

  @override
  String get tcpSource => 'TCP connection test from this device';

  @override
  String get tcpConnected => 'TCP connection succeeded';

  @override
  String get tcpRefused => 'Connection refused';

  @override
  String get tcpTimedOut => 'Connection timed out';

  @override
  String get tcpCancelled => 'Test cancelled';

  @override
  String get tcpFailed => 'Connection failed (network or address unavailable)';

  @override
  String get tcpTimeoutPositive => 'Timeout must be greater than 0';

  @override
  String get tcpSingleTarget => 'Single-target TCP test';

  @override
  String get tcpTestExplanation =>
      'Only checks whether a TCP connection opens; no data is sent. Success does not mean SSH login works or the service is healthy.';

  @override
  String get tcpAddress => 'IP / Domain';

  @override
  String get connectionPort => 'Port';

  @override
  String tcpTestingTarget(String p0) {
    return 'Testing $p0';
  }

  @override
  String get tcpCancel => 'Cancel test';

  @override
  String get tcpStart => 'Start test';

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
  String get terminalCommandsSnippets => 'Commands and snippets';

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
      'Sending was not confirmed. The draft is kept. Check the remote state before trying again to avoid duplicate execution.';

  @override
  String get terminalSend => 'Send';

  @override
  String get terminalSendExecute => 'Send and execute';

  @override
  String get terminalBack => 'Back to terminal';

  @override
  String get terminalQuickCommands => 'Quick commands';

  @override
  String get terminalInsertSnippet => 'Insert snippet';

  @override
  String get terminalDraft => 'Draft to send';

  @override
  String get terminalDraftHint => 'Edit the content to send here';

  @override
  String get terminalPaste => 'Paste';

  @override
  String get terminalSendTo => 'Send to';

  @override
  String get terminalControlCharacterWarning =>
      'The content contains newlines, carriage returns, or control characters. It may execute immediately even without appending Enter.';

  @override
  String get terminalSessionChanged =>
      'The session has changed. Return to the terminal and reopen this panel. The draft is not sent automatically.';

  @override
  String get terminalCannotSend =>
      'Sending is unavailable. Reconnecting clears the draft and does not replay input.';

  @override
  String get terminalSendMeaning =>
      'Send sends the exact text. Send and execute appends Enter, which is handled by the current terminal program.';

  @override
  String get connectionReadFailed =>
      'Could not read connection details. Try again.';

  @override
  String get connectionTemporary => 'Temporary connection';

  @override
  String get connectionInvalidDetails =>
      'Invalid connection details. Check the address, port, and credentials.';

  @override
  String get connectionChoosePowerTarget => 'Choose a server for power control';

  @override
  String get connectionIdentityFirst =>
      'Connect to one server at a time. Authentication using the selected credentials is sent only after the host identity is verified.';

  @override
  String get connectionWebPreviewWarning =>
      'The web preview does not support native SSH / TCP or accept real login credentials. Use the native app.';

  @override
  String get connectionReloadDetails => 'Reload connection details';

  @override
  String get connectionTargetServer => 'Target server';

  @override
  String get connectionTemporaryTarget =>
      'Temporary target · Settings are not saved';

  @override
  String get connectionDemoSuffix => ' · Demo, no connection';

  @override
  String get connectionDemoBlocked =>
      'Demo servers use reserved addresses and cannot make network connections.';

  @override
  String get connectionAddressHint => 'IPv4 / IPv6 / Domain';

  @override
  String get connectionValidHost =>
      'Enter a valid host without a protocol, username, or port';

  @override
  String get connectionPortRange => 'The port must be between 1 and 65,535';

  @override
  String get connectionUsername => 'Login username';

  @override
  String get connectionValidUsername => 'Enter a valid login username';

  @override
  String get connectionSavedCredentials => 'Saved login credentials';

  @override
  String get connectionChooseCredentials => 'Choose login credentials';

  @override
  String connectionUseDefaultUsername(String p0) {
    return 'Use default username: $p0';
  }

  @override
  String get connectionManageCredentials => 'Manage credentials';

  @override
  String get connectionEditSavedSettings =>
      'Edit and save SSH settings for this server';

  @override
  String get connectionTemporaryChangesHelp =>
      'Changes on this page apply only to this connection. Passwords or private keys come from saved credentials and are not entered or saved again here. The connection ends when the app enters the background. Use tmux / screen on the remote server for long-running tasks.';

  @override
  String get connectionSnippetDraftOnly =>
      'The snippet goes into a separate draft. Connecting, verification, and authentication do not send it.';

  @override
  String get connectionPowerAfterConnect =>
      'After connecting, choose restart or shutdown and complete both confirmations. Power-on is not supported.';

  @override
  String get connectionReviewConnect => 'Review and connect';

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
  String get uiConnMoreActions => 'More actions';

  @override
  String get snippetFullEscapedPreview => 'Full content preview (escaped)';

  @override
  String get snippetEscapeLegend =>
      'Newlines appear as \\n, carriage returns as \\r, tabs as \\t, and other control characters as \\u{…}. Backslashes are also escaped.';

  @override
  String get snippetPreviewNoSend =>
      'Previewing and inserting do not send content. Check the target and full draft in the terminal, then choose Send or Send and execute.';

  @override
  String get connectionClose => 'Close';

  @override
  String get snippetInsertDraftOnly => 'Insert into draft only';

  @override
  String get snippetChanged =>
      'The snippet was edited or deleted. Reopen the list and try again.';

  @override
  String get snippetOperationFailed =>
      'The snippet operation did not complete. Try again. Saved content is kept.';

  @override
  String get snippetDeleteQuestion => 'Delete this local snippet?';

  @override
  String snippetDeleteHelp(String p0) {
    return 'Deletes the local template “$p0”. Servers and already-inserted drafts are unchanged.';
  }

  @override
  String get snippetDelete => 'Delete snippet';

  @override
  String get snippetChoose => 'Choose a snippet for the draft';

  @override
  String get snippetReadFailed =>
      'Could not read snippets. Local data is unchanged.';

  @override
  String get snippetSelectPreviewHelp =>
      'Preview first. Only inserted into the draft; nothing is sent automatically.';

  @override
  String get snippetPlaintextHelp =>
      'Snippets are local plain text. Do not save passwords, private keys, or tokens. Choose Insert snippet in the terminal to add one to a draft.';

  @override
  String get snippetAdd => 'Add snippet';

  @override
  String get snippetEmptyHelp =>
      'No snippets yet. Add templates for commands you use often.';

  @override
  String snippetCharacterCount(String p0) {
    return 'Characters: $p0 · Local template';
  }

  @override
  String get snippetPreviewInsert => 'Preview and insert into draft';

  @override
  String get snippetFullPreview => 'Full preview';

  @override
  String get connectionDelete => 'Delete';

  @override
  String get snippetDiscardQuestion => 'Discard snippet changes?';

  @override
  String get snippetDiscardHelp =>
      'Unsaved content will not be written to the local snippet.';

  @override
  String get connectionDiscardChanges => 'Discard changes';

  @override
  String get snippetEdit => 'Edit snippet';

  @override
  String get snippetCancelEdit => 'Cancel snippet editing';

  @override
  String get snippetSaveSafety =>
      'Snippets are stored as plain text. Do not enter passwords, keys or tokens.';

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
  String get snippetSave => 'Save snippet';

  @override
  String get terminalCopyFailed =>
      'Could not copy terminal content. Try again.';

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
      'Could not read the clipboard. The draft is unchanged. Tap Paste again.';

  @override
  String get terminalReplaceDraftQuestion => 'Replace the current draft?';

  @override
  String get terminalReplaceDraftHelp =>
      'The current unsent draft will be replaced. Nothing will be sent over SSH.';

  @override
  String get terminalReplaceDraft => 'Replace draft';

  @override
  String get terminalCurrentSession => 'Current SSH session';

  @override
  String terminalDimensions(String p0, String p1, String p2) {
    return '$p0 · $p1 columns × $p2 rows';
  }

  @override
  String get terminalSelectionHelp =>
      'Tap the terminal to type. Touch and hold, then drag to select, and use Copy. Scroll up for history; the down arrow returns to the latest output.';

  @override
  String get terminalInputHelp =>
      'Keyboard input and special keys go directly to SSH. Quick commands, snippets, and pasted text go into a separate draft first. Send does not append Enter; Send and execute does, for the current terminal program to handle. Newlines already in the content may still execute. Ctrl applies to the next key; tap it again to cancel.';

  @override
  String get terminalBackgroundHelp =>
      'Ending the session, leaving, or backgrounding the app closes this page. Nothing reconnects or replays input automatically. Use tmux / screen remotely for long-running tasks.';

  @override
  String r2ConnDisconnectHelp(String p0) {
    return '$p0\nRemote tasks outside tmux / screen may be interrupted; the unsent draft is discarded.';
  }

  @override
  String get terminalOfflineFont =>
      'Offline font: DejaVu Sans Mono · Chinese uses device font fallback';

  @override
  String get terminalLicenses => 'Open-source licenses';

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
      'The current draft has not been sent. It will be cleared on exit.';

  @override
  String get terminalDisconnect => 'Disconnect';

  @override
  String get terminalDisconnectExit => 'Disconnect and exit';

  @override
  String get terminalDiscardExit => 'Discard and exit';

  @override
  String get terminalBackgroundDisconnected =>
      'The app went to the background; disconnected';

  @override
  String get terminalTargetChanged => 'The target changed; disconnected';

  @override
  String get terminalPowerMenuHelp =>
      'After connecting, choose SSH restart or shutdown in the Terminal menu and complete both confirmations.';

  @override
  String get terminalHostChanged => 'Host key changed · Authentication blocked';

  @override
  String get terminalHostChangedHelp =>
      'This may be a reinstall or a man-in-the-middle attack. Login credentials have not been sent. Verify the reason and new public key through an independent source such as the provider console.';

  @override
  String get terminalPreviousFingerprint => 'Previous fingerprint';

  @override
  String get terminalNoRecord => 'No record';

  @override
  String get terminalCurrentFingerprint => 'Current fingerprint';

  @override
  String get terminalRejectConnection => 'Reject connection';

  @override
  String get terminalReverify => 'Start independent verification';

  @override
  String get terminalPowerFailed =>
      'The power command could not be confirmed successful. Check the connection, remote permissions, and provider console before trying again. It will not be resent automatically.';

  @override
  String get terminalPowerUnknown =>
      'Submission of the power command was attempted, but the result is unknown. Disconnection does not prove completion. Check the provider console. It will not be resent automatically.';

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
  String get terminalExit => 'Exit terminal';

  @override
  String terminalSessionSemantics(String p0, String p1) {
    return 'Session details, $p0, $p1';
  }

  @override
  String get terminalHideKeyboard => 'Hide keyboard';

  @override
  String get terminalOpenKeyboard => 'Open keyboard';

  @override
  String get terminalMenu => 'Terminal menu';

  @override
  String get terminalSessionDetails => 'Session details and help';

  @override
  String get terminalPasteIntoDraft => 'Paste into draft';

  @override
  String get r3TermColorScheme => 'Color scheme';

  @override
  String get r3TermSchemeDark => 'Dark';

  @override
  String get r3TermSchemeLight => 'Light';

  @override
  String get r3TermSchemeFootnote =>
      'Display only; nothing is sent to the server. Resets when the app restarts.';

  @override
  String get terminalReconnectClear => 'Reconnect and clear draft';

  @override
  String get terminalCancelConnection => 'Cancel connection';

  @override
  String get terminalSshRestart => 'SSH restart';

  @override
  String get terminalSshShutdown => 'SSH shutdown';

  @override
  String get terminalTypeDirectly => 'Tap to type. Keys are sent directly.';

  @override
  String get terminalCopy => 'Copy';

  @override
  String get terminalClearSelection => 'Clear selection';

  @override
  String get terminalLatestOutput => 'Return to latest output';

  @override
  String get terminalEstablishingSecure => 'Establishing a secure connection…';

  @override
  String get terminalOffline => 'Terminal disconnected';

  @override
  String get terminalConnect => 'Connect';

  @override
  String get terminalReconnectShort => 'Reconnect · Clear draft';

  @override
  String get terminalBrowserUnsupported =>
      'Browsers do not support native SSH. Use the native app.';

  @override
  String get terminalConnectedInputHelp =>
      'After connecting, tap the terminal to type. Keys are sent directly to the server.';

  @override
  String get terminalRetainedOutputHelp =>
      'Output is kept. Reconnecting clears the terminal and draft without replaying input.';

  @override
  String get terminalDismissNotice => 'Dismiss notice';

  @override
  String get terminalVerifyNewHost => 'Verify the new host public key';

  @override
  String get terminalFirstHostVerification =>
      'First connection · Verify host identity';

  @override
  String terminalHostIdentity(String p0, String p1, String p2) {
    return 'Host: $p0\nPort: $p1\nAlgorithm: $p2';
  }

  @override
  String get terminalSha256Fingerprint => 'SHA-256 fingerprint';

  @override
  String get terminalFullHostKey => 'Full host public key';

  @override
  String get terminalIndependentVerificationHelp =>
      'Check against the provider console or another independent trusted source. Seeing this dialog does not establish trust.';

  @override
  String get terminalConfirmedChangedHost =>
      'I independently verified the reason for the change and the full new public key';

  @override
  String get terminalConfirmedHost =>
      'I verified the full host identity through an independent source';

  @override
  String get terminalVerificationExpired =>
      'The connection was cancelled or timed out. This verification is no longer valid.';

  @override
  String get terminalUpdateTrustAuthenticate =>
      'Update trust and continue authentication';

  @override
  String get terminalTrustAuthenticate => 'Trust and authenticate';

  @override
  String get terminalUnlockKey =>
      'Unlock the SSH private key for this connection';

  @override
  String terminalCredentialName(String p0) {
    return 'Credential: $p0';
  }

  @override
  String get terminalPassphraseHelp =>
      'Decrypts the private key; not the login password. Used for this connection only and not saved.';

  @override
  String get terminalKeyPassphrase =>
      'Private key passphrase for this connection';

  @override
  String get terminalPassphraseCleared =>
      'The passphrase was cleared. Cancel and reconnect.';

  @override
  String get terminalUnlockOnce => 'Unlock for this connection only';

  @override
  String get powerRestart => 'Restart';

  @override
  String get powerShutdown => 'Shut down';

  @override
  String powerImpactTitle(String p0) {
    return '$p0 (1/2)';
  }

  @override
  String powerImpactHelp(String p0, String p1, String p2) {
    return '$p0\n$p1\n\nRun through this single SSH connection:\n$p2\n\nThis may immediately interrupt services and the SSH session, and requires appropriate remote permissions. Shutdown does not stop provider billing, and SSH cannot power the server on again. After a disconnect or timeout, the result is unknown. Check the provider console rather than retrying blindly.';
  }

  @override
  String get powerUnderstandContinue => 'Review target';

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
    return '$p0 once';
  }

  @override
  String get snippetInvalidId => 'Invalid snippet ID';

  @override
  String get sshCheckTarget => 'Check the SSH port, username, and credentials';

  @override
  String get sshConnectionCancelled => 'SSH connection cancelled';

  @override
  String get sshBrowserUnsupported =>
      'Browsers do not support native SSH. Use the native app.';

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
      'Private-key passphrase entry was cancelled. No connection was made.';

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
  String get sshVerificationCancelled => 'SSH verification cancelled';

  @override
  String get sshVerificationTimeout =>
      'Host verification timed out. Authentication did not start.';

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
      'The server did not open SFTP. It may be disabled for this account.';

  @override
  String get r3SftpTitle => 'SFTP files';

  @override
  String get r3SftpRowSubtitle => 'Browse and transfer files';

  @override
  String get r3SftpUp => 'Parent folder';

  @override
  String get r3SftpRoot => 'Root';

  @override
  String get r3SftpNewFolder => 'New folder';

  @override
  String get r3SftpNewFile => 'New empty file';

  @override
  String get r3SftpUpload => 'Upload from phone';

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
  String get r3SftpSearch => 'Search this folder';

  @override
  String get r3SftpEmpty => 'This folder is empty';

  @override
  String get r3SftpNoMatch => 'No matches';

  @override
  String r3SftpShowMore(int count) {
    return 'Show more ($count)';
  }

  @override
  String get r3SftpMore => 'More';

  @override
  String get r3SftpAdd => 'New';

  @override
  String get r3SftpOpen => 'Open';

  @override
  String get r3SftpView => 'View / edit';

  @override
  String get r3SftpDownload => 'Download';

  @override
  String get r3SftpRename => 'Rename / move';

  @override
  String get r3SftpCopyPath => 'Copy path';

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
  String get r3SftpRenameTitle => 'Rename or move';

  @override
  String get r3SftpRenameHint =>
      'Change the name to rename, or the folder to move.';

  @override
  String get r3SftpInvalidName => 'Enter a name without “/”';

  @override
  String get r3SftpInvalidFolder =>
      'Folder must be an absolute path starting with /';

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
    return '“$name” is not empty. Everything inside is deleted permanently (recursive delete, links are not followed). Folders with more than $max items are refused and nothing is deleted.';
  }

  @override
  String get r3SftpDeleteRecursiveAction => 'Delete everything';

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
  String get r3SftpErrNotEmpty => 'The folder is not empty';

  @override
  String get r3SftpErrWrongType => 'Wrong item type for this action';

  @override
  String get r3SftpErrCancelled => 'Cancelled';

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
  String get r3SftpErrUnavailable => 'SFTP is not available on this connection';

  @override
  String get r3SftpErrLocalFile => 'Could not read or write the local file';

  @override
  String get r3SftpErrFailed => 'The operation failed';

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
      'Your edits have not been written to the server.';

  @override
  String get r3SftpDiscard => 'Discard';

  @override
  String get r3SftpConflictTitle => 'File changed on the server';

  @override
  String get r3SftpConflictMessage =>
      'It was modified after you opened it. Overwrite the server version with yours?';

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
  String get r3SftpLargeTitle => 'Large file';

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
  String get r3SftpStateCancelled => 'Cancelled';

  @override
  String get r3SftpStateSkipped => 'Skipped';

  @override
  String get r3SftpCancelAll => 'Cancel all';

  @override
  String get r3SftpClearFinished => 'Clear finished';

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
  String get r3SftpCloseBusyTitle => 'Transfers in progress';

  @override
  String get r3SftpCloseBusyMessage =>
      'Closing cancels the running and waiting transfers.';

  @override
  String get r3SftpCloseBusyAction => 'Cancel transfers and close';

  @override
  String get r3SftpBackgroundClosed =>
      'SFTP was closed because the app went to the background';

  @override
  String get r3SftpConnecting => 'Connecting SFTP…';

  @override
  String get r3SftpConnectFailed => 'Could not open SFTP';

  @override
  String get r3SftpRetry => 'Try again';

  @override
  String get r3SftpChooseCredential =>
      'Choose a credential in the SSH settings first.';

  @override
  String get r3SftpSshSettings => 'SSH settings';

  @override
  String get r3SftpLoadFailed => 'Could not load this folder';

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
      'The host was not trusted. Authentication did not start.';

  @override
  String get sshConnectionIncomplete =>
      'SSH connection did not complete. Check the address, network, and service.';

  @override
  String get sshSessionEnded =>
      'The SSH session ended. Reconnect to check whether the command completed.';

  @override
  String get sshInputUnconfirmed =>
      'SSH input delivery was not confirmed. Reconnect and check before retrying to avoid duplicate execution.';

  @override
  String get sshResizeFailed => 'Could not resize the SSH terminal. Reconnect.';

  @override
  String get sshPrivatePublicMismatch =>
      'The private key does not match the saved public-key details. Import the private key again before connecting.';

  @override
  String get securityReadFailed => 'Could not read security data. Try again.';

  @override
  String get securitySavedReloadFailed =>
      'Saved, but the data could not be reloaded. Reload before making more changes.';

  @override
  String get securityDataChanged =>
      'The data has changed. Reload and try again.';

  @override
  String get securityMutationFailed =>
      'The security action did not complete. Existing data is unchanged. Try again.';

  @override
  String get securityInvalidCredentialIdentity =>
      'Enter a name of 1–80 characters and a valid default username.';

  @override
  String get securitySecretRequired => 'Provide the password or private key.';

  @override
  String get securityReimportForPassphrase =>
      'To update the saved passphrase, also reimport the matching private key.';

  @override
  String get securityPasswordNoPassphrase =>
      'Password credentials do not use a private-key passphrase.';

  @override
  String get securitySecretSizeInvalid =>
      'The secret is empty or exceeds the size limit.';

  @override
  String get securitySecretWriteUnverified =>
      'The secret write could not be verified. The existing credential is unchanged.';

  @override
  String get securityCleanupIncomplete =>
      'Secret cleanup is incomplete. You can retry later.';

  @override
  String get securityCleanupReadFailed =>
      'Could not read pending cleanup data. Try again.';

  @override
  String get securitySshCancelled =>
      'The SSH connection was canceled, or the data needs to be reloaded.';

  @override
  String get securityChooseAvailableCredential =>
      'Select an available credential.';

  @override
  String get securityCredentialSecretMissing =>
      'This credential’s password or private key was not found. Open Manage credentials to save the password again or import the private key.';

  @override
  String get securityStoredSecretUnreadable =>
      'The data in secure storage could not be read.';

  @override
  String get securityCredentialChanged =>
      'The credential has changed. Reload and try again.';

  @override
  String get securitySshCredentialReadFailed =>
      'Could not read the SSH credential. Try again.';

  @override
  String get securityAuthenticationHidden =>
      'Device authentication did not complete. The secret remains hidden.';

  @override
  String get securitySavedPasswordMissing =>
      'The saved password was not found. Edit this credential and save the password again.';

  @override
  String get securityRevealFailed => 'Could not display the secret. Try again.';

  @override
  String get securityHostTargetMismatch =>
      'The host verification targets do not match.';

  @override
  String get securityHostAuthenticationIncomplete =>
      'Host verification or authentication did not complete.';

  @override
  String get securityInvalidHost =>
      'Invalid host address. Enter an IP address or domain without a scheme, username, port, or path.';

  @override
  String get securityInvalidSshPort =>
      'The SSH port must be between 1 and 65535.';

  @override
  String get securityHostKeyUnreadable =>
      'The host public key was not recognized. Check the complete public key and the selected type.';

  @override
  String get securityPrivateKeyUnreadable =>
      'Could not read the private key. Check its complete content, supported format, and decryption passphrase.';

  @override
  String get securityNativeStorageUnsupported =>
      'Native secure storage is not available on this platform.';

  @override
  String get securityNativeStorageUnavailable =>
      'Native secure storage is unavailable or the operation did not complete. Check your device and try again.';

  @override
  String get securityDeviceAuthUnsupported =>
      'Device authentication is not supported on this platform, so secrets cannot be displayed.';

  @override
  String get securityDeviceAuthReason =>
      'Verify your identity to view the saved password';

  @override
  String get securityDeviceAuthIncomplete =>
      'Device authentication did not complete.';

  @override
  String get securityPasswordKind => 'Username and password';

  @override
  String get securityPrivateKeyKind => 'SSH key';

  @override
  String get securityReloadSaved => 'Reload saved data';

  @override
  String get securityCleanupNotice =>
      'Secure-storage cleanup is incomplete. Current connection references are preserved. Retry when system secure storage is available. Secrets still in use will not be deleted.';

  @override
  String get securityRetryCleanup => 'Retry unused-secret cleanup';

  @override
  String get securityAddLoginCredential => 'Add login credential';

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
  String get securityTitle => 'Keys and security';

  @override
  String get securityAddCredential => 'Add credential';

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
  String get securityTrustedHosts => 'Trusted hosts';

  @override
  String get securityTrustedHostsSubtitle =>
      'Host, port, algorithm, and complete host public key';

  @override
  String get securityCredentialProtection => 'Credential protection';

  @override
  String get securityCredentialProtectionSubtitle =>
      'Device verification, brief reveal, and platform limits';

  @override
  String get securityCredentialProtectionDetail =>
      'Passwords, private keys, and key passphrases are excluded from the ledger database, exports, and logs. Viewing a password requires system device verification. It is hidden after 20 seconds or when you leave the page. This app does not support device verification on Linux, so secrets cannot be viewed there.\n\nDevice authentication gates display in the app; it does not mean each secret is separately encrypted by biometric hardware. Security behavior still needs verification on physical iOS / Android devices. Dart does not guarantee secure memory erasure. Copying or exporting secrets is currently unavailable.';

  @override
  String get securityLocalCredentialNotice =>
      'Only the local credential changes; the server’s password and authorized_keys are untouched.';

  @override
  String get securityViewDetails => 'View details';

  @override
  String get securityPrivateKeyDetailsSubtitle =>
      'Public-key fingerprint and metadata; private key hidden';

  @override
  String get securityPasswordDetailsSubtitle =>
      'Password hidden by default; device verification required to view';

  @override
  String get securityEditCredential => 'Edit credential';

  @override
  String get securityKeepSecret => 'Leave blank to keep the saved secret';

  @override
  String get securityLinkedServers => 'Linked servers';

  @override
  String get securityIndependentUsernames =>
      'Connection usernames are stored separately';

  @override
  String get securityDeleteCredential => 'Delete credential';

  @override
  String get securityReviewDeleteImpact =>
      'Review the impact of replacing or unlinking first';

  @override
  String get securityDiscardCredentialTitle => 'Discard these edits?';

  @override
  String get securityDiscardCredentialMessage =>
      'Unsaved credential content will be cleared.';

  @override
  String get securityDiscardChanges => 'Discard changes';

  @override
  String get securityKeyImported =>
      'Private key imported into the draft. Its format and passphrase will be validated when saved.';

  @override
  String get securityKeyFileReadFailed =>
      'Could not read the private-key file. Choose a UTF-8 private-key file no larger than 128 KB.';

  @override
  String get securityKeyPasted =>
      'Private key pasted into the draft. It remains hidden and will be validated when saved.';

  @override
  String get securityKeyPasteFailed =>
      'Could not paste the private key. Copy the complete private key, no larger than 128 KB.';

  @override
  String get securityCredentialSaved =>
      'Credential saved. Remote authentication details are unchanged.';

  @override
  String get securityCancelCredentialEdit => 'Cancel credential editing';

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
  String get securityChoosePrivateKeyFile => 'Choose private-key file';

  @override
  String get securityPasteCompleteKey => 'Paste complete private key';

  @override
  String get securityPrivateKeyImportNotice =>
      'OpenSSH / PEM private keys. The file path is not saved and the content stays hidden.';

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
      'Not saved by default. If an encrypted key’s passphrase is not saved, you must enter it for each connection. Canceling or entering a wrong passphrase stops the connection. This option applies only when importing a private key.';

  @override
  String get securityCredentialEditNotice =>
      'The username is only a suggestion for new connections. Updating a credential affects future logins only and changes nothing on the server. Unsaved secrets are cleared in the background.';

  @override
  String get securityCurrentLinkImpact => 'Impact on current links';

  @override
  String get securityServerFallback => 'Server';

  @override
  String get securitySaving => 'Saving…';

  @override
  String get securitySaveCredential => 'Save credential';

  @override
  String get securityCredentialDetails => 'Credential details';

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
  String get securityCopyFailed => 'Copying did not complete. Try again.';

  @override
  String get securityCopyFingerprint => 'Copy public-key fingerprint';

  @override
  String get securityProtectedPassword => 'Protected password';

  @override
  String get securityPasswordRevealNotice =>
      'Hidden after 20 seconds, or immediately when you leave this page or move the app to the background.';

  @override
  String get securityPasswordHiddenNotice =>
      'Shown briefly after successful verification. It stays hidden if device authentication is unavailable. Viewing is currently unavailable on Linux.';

  @override
  String get securityHidePassword => 'Hide password';

  @override
  String get securityVerifyViewPassword => 'Verify device to view password';

  @override
  String get securityCancelVerifyHide => 'Cancel verification and hide';

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
      'No links yet. Select this credential in SSH configuration on a server’s details page.';

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
      'Unlinking keeps servers, usernames, and payments. Select a credential again before the next connection.';

  @override
  String get securityReplaceCredentialNotice =>
      'Only credential references are replaced. All current server usernames stay unchanged.';

  @override
  String get securityDeleteLocalCredentialNotice =>
      'Deletes only the local credential and cannot be undone. Servers and cloud services are unaffected.';

  @override
  String get securityConfirmCredentialImpact =>
      'I have reviewed the linked-server impact and want to delete the local credential';

  @override
  String get securityLocalCredentialDeleted =>
      'Local credential deleted. Remote authentication details are unchanged.';

  @override
  String get securityConfirmDelete => 'Confirm deletion';

  @override
  String get securityVerifyHostKey => 'Verify host public key';

  @override
  String get securityHostTrustNotice =>
      'Trust is bound to the host address, port and full public key, separate from login credentials.';

  @override
  String get securityNoTrustedHosts =>
      'No trusted hosts yet. Enter a public key obtained through an independent trusted source, such as the provider’s console or an administrator, or verify it on the first SSH connection. This page does not connect to the server.';

  @override
  String securityHostVerifiedAt(String algorithm, String date) {
    return '$algorithm\nVerified at $date';
  }

  @override
  String get securityCompleteHostKey => 'Complete host public key';

  @override
  String get securityReverifyHost => 'Reverify host';

  @override
  String get securityRemoveHostTrustTitle => 'Remove host trust?';

  @override
  String securityRemoveHostTrustMessage(
    String host,
    int port,
    String fingerprint,
  ) {
    return '$host:$port\n$fingerprint\n\nThe host’s identity must be verified again on the next connection. The server and login credentials will not be deleted.';
  }

  @override
  String get securityRemoveHostTrust => 'Remove trust';

  @override
  String get securityHostChangedNotice =>
      'If the host key changes, authentication must stop until the host is verified again through an independent source. There is no “ignore and connect” option.';

  @override
  String get securityHostTrustReadFailed =>
      'Could not read host trust data. Try again.';

  @override
  String get securityHostTrustInputNotice =>
      'Enter the host public key from an independent trusted source such as the provider console. This page only saves local trust and does not connect.';

  @override
  String get securityHostAddress => 'Host address';

  @override
  String get securityPort => 'Port';

  @override
  String get securityHostKeyType => 'Host public-key type';

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
  String get securityCheckFingerprint => 'Check and verify fingerprint';

  @override
  String get securityHostKeyMismatch =>
      'Host public key differs from the saved record';

  @override
  String get securityFirstHostVerification => 'First host verification';

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
      'Start independent reverification';

  @override
  String get securityConfirmHostVerified =>
      'I have verified the host, port, and complete fingerprint through an independent source';

  @override
  String get securityHostTrustSaved =>
      'Host trust saved. No connection or authentication was started.';

  @override
  String get securityReverifyReplaceTrust => 'Reverify and replace trust';

  @override
  String get securitySaveVerifiedHostTrust => 'Save verified host trust';

  @override
  String get securityRejectBack => 'Reject and go back';

  @override
  String get uiSecurityVerified => 'Verified';

  @override
  String get uiSecurityUnverified => 'Not verified';

  @override
  String get uiSecurityKeyChanged => 'Key changed';

  @override
  String get securitySavingHostTrust =>
      'Saving confirmed trust. You cannot go back until this finishes.';

  @override
  String get securityLocalHostTrustOnly =>
      'Only local trust is recorded. Rejecting, cancelling or going back saves nothing.';

  @override
  String get securityDiscardSshTitle => 'Discard connection configuration?';

  @override
  String get securityDiscardSshMessage =>
      'Unsaved address, username, and credential choices will not take effect.';

  @override
  String get securityChooseCredential => 'Select login credential';

  @override
  String get securityUnlinkCurrentCredential => 'Unlink current credential';

  @override
  String get securityChooseCredentialLater =>
      'Keep connection configuration and select later';

  @override
  String securityCredentialChoiceSubtitle(String kind, String username) {
    return '$kind · Default: $username';
  }

  @override
  String get securityNotSet => 'Not set';

  @override
  String get securityNoCredentialsToChoose =>
      'No credentials yet. Go back and use Manage credentials to add one.';

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
  String get securityAdoptUsername => 'Use default username';

  @override
  String get securitySshConfigurationSaved =>
      'SSH configuration saved. No network connection was made.';

  @override
  String get securitySshConfiguration => 'SSH connection configuration';

  @override
  String get securityCancelSshConfiguration =>
      'Cancel connection configuration';

  @override
  String get securitySshConfigurationNotice =>
      'Connection configuration and the ledger address are stored separately. Cloud server settings are not changed.';

  @override
  String get securityHostHint => 'IPv4 / IPv6 / domain, without a scheme';

  @override
  String get securityHostRequired => 'Enter a host address.';

  @override
  String get securityPortRequired => 'The port must be between 1 and 65535.';

  @override
  String get securityConnectionUsername => 'Current connection username';

  @override
  String get securityConnectionUsernameRequired =>
      'Enter a login username, or use the credential’s default username.';

  @override
  String get securityLoginCredential => 'Login credential';

  @override
  String get securityManageCredentials => 'Manage credentials';

  @override
  String get securityCredentialNotConfigured => 'Credential not configured';

  @override
  String get securityCredentialRequiredBeforeConnect =>
      'You can save the configuration now, but must select a credential before connecting';

  @override
  String securityChangeCredentialSubtitle(String kind) {
    return '$kind · Tap to change or unlink';
  }

  @override
  String get securityConnectionUsernameNotice =>
      'The username belongs to this connection. Changing credentials changes it only if you explicitly select “Use default username.” Canceling or selecting the same username does not change other connections.';

  @override
  String get securityConfigurationOnlyNotice =>
      'Saves connection settings only. The host key is verified before login; a changed key pauses authentication.';

  @override
  String get securitySaveSshConfiguration => 'Save SSH configuration';

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
  String get securityAuthRequiredTitle => 'Biometric verification required';

  @override
  String get securityAuthSetupDescription =>
      'Enable biometric verification in your device settings.';

  @override
  String get securityAuthGoToSettings => 'Go to settings';

  @override
  String get securityAuthDeviceSetupDescription =>
      'Enable device authentication in your device settings.';

  @override
  String get securityAuthDeviceRequiredTitle => 'Device verification required';

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
  String get providerReviewRequired =>
      'Confirm this instance’s provider before adding authorization, importing, or linking servers.';

  @override
  String get providerNameRange => 'Use 1–80 characters for the provider name.';

  @override
  String get providerAlreadyExists =>
      'This provider already exists. Select it from the list.';

  @override
  String get providerChangeNeedsUnlink =>
      'Confirm unlinking the current adapter before changing the provider.';

  @override
  String get adapterProviderMismatch =>
      'The server and adapter instance must have the same provider.';

  @override
  String get adapterScopeUnavailable =>
      'This instance’s authorization scope is unverified. New links are unavailable.';

  @override
  String get adapterSingletonPinned =>
      'These single-device credentials are pinned to another local server. Unlinking does not expand their scope. Return to that record or explicitly reauthorize.';

  @override
  String get providerUiTitle => 'Providers';

  @override
  String get uiCloudProvidersTitle => 'Providers';

  @override
  String get uiCloudNeedsReviewPill => 'Ownership pending';

  @override
  String get uiCloudOwnerSection => 'Provider';

  @override
  String get uiCloudMethodSection => 'How to add';

  @override
  String get uiCloudAddFooter =>
      'Panel keys are stored only in secure device storage. Reading never changes the remote panel.';

  @override
  String get providerUiDetails => 'Provider details';

  @override
  String get providerUiAdd => 'Add provider';

  @override
  String get providerUiRename => 'Rename provider';

  @override
  String get providerUiName => 'Provider name';

  @override
  String get providerUiUnspecified => 'Unspecified provider';

  @override
  String get providerUiUnspecifiedHelp =>
      'Manual entry only. You can assign a provider later in server details.';

  @override
  String get providerUiHierarchyHelp =>
      'A provider is who sells your servers; each adapter instance holds a separate authorization.';

  @override
  String providerUiSummary(int instances, int devices) {
    return '$instances adapter instances · $devices servers';
  }

  @override
  String get providerUiEmpty => 'No providers yet';

  @override
  String get providerUiEmptyHelp =>
      'Add a provider name, then enter servers manually or configure a read-only adapter.';

  @override
  String get providerUiNeedsReview =>
      'Ownership needs confirmation. New authorization and links are unavailable.';

  @override
  String providerUiUnspecifiedCount(int count) {
    return '$count servers have no provider assigned.';
  }

  @override
  String get providerUiChoose => 'Choose a provider';

  @override
  String get providerUiChooseHelp =>
      'Choose the business provider. You will select the panel type and authorization later.';

  @override
  String get providerUiSelected => 'Server provider';

  @override
  String get providerUiChooseAnother => 'Choose another provider';

  @override
  String get providerUiChooseMethod => 'Choose how to add';

  @override
  String get providerUiManualHelp =>
      'Enter details manually. Unknown hardware and costs can stay blank.';

  @override
  String get providerUiAutomatic => 'Read through an adapter';

  @override
  String get providerUiAutomaticHelp =>
      'Choose an existing authorization or add an adapter, then review the devices to import.';

  @override
  String get providerUiAutoNeedsProvider =>
      'Choose a confirmed provider before automatic reading.';

  @override
  String get providerUiInstances => 'Adapter instances';

  @override
  String get providerUiNoInstances =>
      'No adapters configured. You can still add servers manually.';

  @override
  String get providerUiAddInstance => 'Add adapter instance';

  @override
  String get providerUiDevices => 'Provider servers';

  @override
  String get providerUiNoDevices => 'No servers belong to this provider yet.';

  @override
  String get providerUiManualDevice => 'No adapter link';

  @override
  String get providerUiLinkedDevice => 'Adapter linked';

  @override
  String providerUiLinkedCount(int count) {
    return '$count linked servers';
  }

  @override
  String get providerUiSingleScope => 'Single-device authorization';

  @override
  String get providerUiAccountScope => 'Account-scoped authorization';

  @override
  String get providerUiUnknownScope => 'Authorization scope unverified';

  @override
  String providerUiPinnedHelp(String name) {
    return 'This single-device authorization is pinned to “$name”. Unlinking does not free it for another device. Return to that record or explicitly reauthorize.';
  }

  @override
  String get providerUiChooseInstance => 'Choose an adapter instance';

  @override
  String get providerUiInstanceChoiceHelp =>
      'Only this provider’s instances are listed.';

  @override
  String get providerUiReviewHelp =>
      'The business provider could not be determined from older records. Confirm the provider and all affected servers for each instance. Until then, only existing links can be refreshed.';

  @override
  String get providerUiRenameReviewHelp =>
      'Renaming does not confirm ownership. Confirm the provider for the instance separately.';

  @override
  String get providerUiConfirmOwnership => 'Confirm instance provider';

  @override
  String providerUiConfirmOwnershipMessage(
    String alias,
    String provider,
    String devices,
  ) {
    return 'Assign “$alias” to “$provider”. These linked servers will move with it:\n$devices\n\nExisting authorization, server details, costs, and SSH remain. This does not expand authorization scope.';
  }

  @override
  String get providerUiNoAffectedDevices => 'No linked servers.';

  @override
  String get providerUiUnavailable =>
      'This provider changed or is unavailable. Go back and choose again.';

  @override
  String get providerUiChange => 'Change provider';

  @override
  String providerUiChangeMessage(
    String server,
    String oldProvider,
    String newProvider,
    String linkEffect,
  ) {
    return 'Change “$server” from “$oldProvider” to “$newProvider”.\n\n$linkEffect\n\nThe server ID, manual details, costs, and SSH remain. This does not automatically add authorization or a new link.';
  }

  @override
  String get providerUiChangeNoLink => 'This server has no adapter link.';

  @override
  String providerUiChangeUnlink(String alias) {
    return 'The local link to “$alias” must be removed. Its authorization remains, including any single-device pin.';
  }

  @override
  String get providerUiUnlinkAndChange => 'Unlink and change provider';

  @override
  String get providerUiChangeFromDetails =>
      'To change an existing server’s provider, return to details and choose “Change provider”. Any existing link must be explicitly removed.';

  @override
  String get providerUiProviderAndAdapter => 'Provider and adapter';

  @override
  String get providerUiOpenProvider => 'View provider';

  @override
  String get providerUiOpenInstance => 'View adapter instance';

  @override
  String providerPendingName(String name) {
    return '$name · provider unconfirmed';
  }

  @override
  String get providerBindingAssignFirst =>
      'Assign a provider in server details before choosing an adapter instance to link.';

  @override
  String get cloudImportSaved =>
      'Adapter instance saved. Its authorization is kept independently of these device import results.';

  @override
  String get cloudImportReady => 'Resources complete';

  @override
  String get cloudImportNeedsCompletion => 'Resources need completion';

  @override
  String get cloudImportImported => 'Imported';

  @override
  String get cloudImportExisting => 'Already exists';

  @override
  String get cloudImportFailed => 'Failed';

  @override
  String get cloudImportUnprocessed => 'Not processed';

  @override
  String get cloudImportCompleteResources => 'Complete resources';

  @override
  String get cloudImportReviewResources => 'Review resources';

  @override
  String get cloudImportCompleteAndSelect => 'Save draft and select';

  @override
  String get cloudImportCompletionInfo =>
      'Check all six resource fields before importing. Values the API omits stay unknown; choose unlimited traffic only when confirmed. Edits stay local.';

  @override
  String get cloudImportFinanceLater =>
      'Only devices and resource details are added; no costs or payments are created.';

  @override
  String cloudImportSummary(
    int imported,
    int existing,
    int failed,
    int unprocessed,
  ) {
    return 'Imported $imported · Existing $existing · Failed $failed · Not processed $unprocessed';
  }

  @override
  String cloudImportRetryCount(int count) {
    return 'Retry only $count unfinished devices';
  }

  @override
  String get cloudImportCancel => 'Stop remaining imports';

  @override
  String get cloudImportCancelling => 'Stopping…';

  @override
  String get cloudImportCancelled =>
      'Remaining imports stopped. Committed devices are kept. Review the results before retrying unfinished items.';

  @override
  String get cloudImportResultsTitle => 'Import results';

  @override
  String cloudImportExistingConflict(int count) {
    return 'Found $count local records with the same remote identity. Review each record; none is chosen or merged automatically.';
  }

  @override
  String cloudImportAddressHint(String names) {
    return 'IP or hostname also appears on: $names. This is a review hint only and does not prove the devices are identical.';
  }

  @override
  String cloudInstanceDeleteImpact(int count, String names) {
    return 'This removes links from $count local servers:\n$names\n\nAll local details, hardware, finances, and SSH settings are kept.';
  }

  @override
  String get cloudImportIdentityConflict => 'Device identity conflict';
}
