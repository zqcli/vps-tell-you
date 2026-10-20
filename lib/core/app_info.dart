/// Product identity shown in the UI. The version must match `pubspec.yaml`
/// (the part before `+`); `test/app_info_test.dart` enforces it.
library;

const kAppName = 'VPS Tell You';
const kAppVersion = '0.6.0';
const kRepoUrl = 'https://github.com/zqcli/vps-tell-you';

/// [kRepoUrl] without the scheme, for display.
const kRepoDisplay = 'github.com/zqcli/vps-tell-you';

/// Public copies of the privacy policy and the support page (the files at the
/// repository root, also bundled as assets). English users get the `.en` file.
String privacyUrl(String languageCode) => _docUrl('PRIVACY', languageCode);
String supportUrl(String languageCode) => _docUrl('SUPPORT', languageCode);

String _docUrl(String name, String languageCode) =>
    '$kRepoUrl/blob/dev/$name${languageCode == 'en' ? '.en' : ''}.md';
