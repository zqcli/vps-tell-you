import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../l10n/locale_preference.dart';
import '../l10n/localized_message.dart';
import 'cloud_account.dart';
import 'cloud_models.dart';

String cloudProviderName(CloudProvider provider) => switch (provider) {
  CloudProvider.solusVm1 => 'SolusVM 1',
  CloudProvider.solusVm2 => 'SolusVM 2',
};

String cloudPowerLabel(CloudPower power, {AppLocalizations? l10n}) {
  final strings = l10n ?? defaultLocalizations;
  return switch (power) {
    CloudPower.running => strings.cloudPowerRunning,
    CloudPower.stopped => strings.cloudPowerStopped,
    CloudPower.unknown => strings.cloudPowerUnknown,
  };
}

String cloudTime(DateTime time) => time.toLocal().toString().substring(0, 16);

String cloudBindingSummary(CloudBinding binding, {AppLocalizations? l10n}) {
  final strings = l10n ?? defaultLocalizations;
  final freshness = binding.missing
      ? strings.cloudMissingKept
      : binding.stale
      ? strings.cloudFailedKept
      : strings.cloudLastRead;
  return strings.cloudBindingSummary(
    freshness,
    cloudPowerLabel(binding.power, l10n: strings),
  );
}

String cloudAccountStatus(CloudAccount account, {AppLocalizations? l10n}) {
  final strings = l10n ?? defaultLocalizations;
  return account.lastFailure == CloudFailureKind.unauthorized
      ? strings.cloudAuthorizationFailedKept
      : account.lastFailure != null
      ? strings.cloudFailedKept
      : strings.cloudVerifiedManual;
}

class CloudSteps extends StatelessWidget {
  const CloudSteps(this.step, {super.key});
  final int step;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        for (var i = 0; i < 3; i++)
          Text(
            context.l10n.cloudStepLabel(
              i + 1,
              [
                context.l10n.cloudStepTemplate,
                context.l10n.cloudStepCredentials,
                context.l10n.cloudStepInstances,
              ][i],
            ),
            style: TextStyle(
              fontSize: 12,
              fontWeight: i + 1 == step ? FontWeight.w700 : FontWeight.normal,
              color: i + 1 == step
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    ),
  );
}

class CloudNotice extends StatelessWidget {
  const CloudNotice(this.message, {super.key, this.error = false});
  final Object message;
  final bool error;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: error
              ? Theme.of(context).colorScheme.tertiaryContainer
              : Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          localizedText(message, context.l10n),
          style: TextStyle(
            fontSize: 12,
            color: error
                ? Theme.of(context).colorScheme.onTertiaryContainer
                : Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
      ),
    ),
  );
}

class CloudValue extends StatelessWidget {
  const CloudValue(this.label, this.value, {super.key});
  final String label;
  final String? value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 3),
        SelectableText(
          value == null || value!.isEmpty
              ? context.l10n.cloudApiUnknown
              : value!,
        ),
      ],
    ),
  );
}
