// Synthetic demo ledger for the store screenshots (see docs/SCREENSHOTS.md).
//
// Documentation-only addresses (RFC 5737 / RFC 3849), invented names, no real
// credentials. Every date is relative to "today" so the tour always shows a
// renewal due in a few days.
import 'package:sqflite/sqflite.dart' as mobile;
import 'package:vps_tell_you/core/value_types.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/finance/finance_math.dart';
import 'package:vps_tell_you/finance/finance_models.dart';
import 'package:vps_tell_you/l10n/locale_preference.dart';
import 'package:vps_tell_you/providers/provider_record.dart';
import 'package:vps_tell_you/servers/server_record.dart';
import 'package:vps_tell_you/servers/server_resources.dart';

const _gib = 1024 * 1024 * 1024;

class _Demo {
  const _Demo({
    required this.name,
    required this.catalogId,
    required this.providerZh,
    required this.providerEn,
    required this.regionZh,
    required this.regionEn,
    required this.purposeZh,
    required this.purposeEn,
    required this.address,
    required this.currency,
    required this.minor,
    required this.cycleMonths,
    required this.dueInDays,
    required this.payments,
    required this.os,
    required this.vcpu,
    required this.ramGib,
    required this.diskGib,
    required this.trafficGib,
    this.favorite = false,
  });
  final String name, providerZh, providerEn, regionZh, regionEn;
  final String purposeZh, purposeEn, address, currency, os;
  final String? catalogId;
  final int minor, cycleMonths, dueInDays, payments, vcpu, diskGib, trafficGib;
  final double ramGib;
  final bool favorite;
}

const _servers = [
  _Demo(
    name: 'hk-01',
    catalogId: 'bandwagonhost',
    providerZh: 'BandwagonHost',
    providerEn: 'BandwagonHost',
    regionZh: '香港',
    regionEn: 'Hong Kong',
    purposeZh: '生产主站',
    purposeEn: 'Production site',
    address: '203.0.113.18',
    currency: 'USD',
    minor: 4999,
    cycleMonths: 12,
    dueInDays: 5,
    payments: 2,
    os: 'Debian 12',
    vcpu: 2,
    ramGib: 2,
    diskGib: 40,
    trafficGib: 1000,
    favorite: true,
  ),
  _Demo(
    name: 'sh-api',
    catalogId: 'aliyun',
    providerZh: '阿里云',
    providerEn: 'Alibaba Cloud',
    regionZh: '上海',
    regionEn: 'Shanghai',
    purposeZh: 'API 服务',
    purposeEn: 'API service',
    address: '198.51.100.24',
    currency: 'CNY',
    minor: 9900,
    cycleMonths: 1,
    dueInDays: 21,
    payments: 8,
    os: 'Ubuntu 24.04',
    vcpu: 2,
    ramGib: 4,
    diskGib: 60,
    trafficGib: 500,
  ),
  _Demo(
    name: 'la-ci',
    catalogId: 'racknerd',
    providerZh: 'RackNerd',
    providerEn: 'RackNerd',
    regionZh: '洛杉矶',
    regionEn: 'Los Angeles',
    purposeZh: '构建机',
    purposeEn: 'CI runner',
    address: '203.0.113.77',
    currency: 'USD',
    minor: 2888,
    cycleMonths: 12,
    dueInDays: 112,
    payments: 2,
    os: 'Debian 12',
    vcpu: 2,
    ramGib: 3.5,
    diskGib: 65,
    trafficGib: 6000,
  ),
  _Demo(
    name: 'fra-db',
    catalogId: 'hetzner',
    providerZh: 'Hetzner',
    providerEn: 'Hetzner',
    regionZh: '法兰克福',
    regionEn: 'Frankfurt',
    purposeZh: '数据库',
    purposeEn: 'Database',
    address: '2001:db8:fe::10',
    currency: 'EUR',
    minor: 451,
    cycleMonths: 1,
    dueInDays: 12,
    payments: 9,
    os: 'Debian 12',
    vcpu: 2,
    ramGib: 4,
    diskGib: 40,
    trafficGib: 20000,
    favorite: true,
  ),
  _Demo(
    name: 'tyo-edge',
    catalogId: 'dmit',
    providerZh: 'DMIT',
    providerEn: 'DMIT',
    regionZh: '东京',
    regionEn: 'Tokyo',
    purposeZh: '边缘节点',
    purposeEn: 'Edge node',
    address: '198.51.100.130',
    currency: 'USD',
    minor: 1699,
    cycleMonths: 3,
    dueInDays: 33,
    payments: 5,
    os: 'Ubuntu 22.04',
    vcpu: 1,
    ramGib: 1,
    diskGib: 20,
    trafficGib: 1000,
  ),
  _Demo(
    name: 'lab-01',
    catalogId: null,
    providerZh: '实验室主机',
    providerEn: 'Lab Hosting',
    regionZh: '新加坡',
    regionEn: 'Singapore',
    purposeZh: '测试环境',
    purposeEn: 'Staging',
    address: '203.0.113.201',
    currency: 'CNY',
    minor: 36000,
    cycleMonths: 12,
    dueInDays: 201,
    payments: 1,
    os: 'Rocky Linux 9',
    vcpu: 1,
    ramGib: 2,
    diskGib: 30,
    trafficGib: 800,
  ),
];

/// A fresh, seeded ledger at [path] ([path] is deleted first by the caller).
Future<LedgerStore> openDemoLedger(
  String path, {
  required bool zh,
  required String theme,
}) async {
  final store = await LedgerStore.open(
    factory: mobile.databaseFactory,
    path: path,
  );
  final today = LedgerDate.today(DateTime.now());
  var serial = 0;
  for (final demo in _servers) {
    final finalDue = today.addDays(demo.dueInDays);
    final firstDue = finalDue.addMonths(-demo.cycleMonths * demo.payments);
    final providerName = zh ? demo.providerZh : demo.providerEn;
    final record = ServerRecord(
      id: newLocalId(),
      name: demo.name,
      vendor: providerName,
      region: zh ? demo.regionZh : demo.regionEn,
      purpose: zh ? demo.purposeZh : demo.purposeEn,
      os: demo.os,
      resources: ServerResources(
        ip: demo.address.contains(':') ? '' : demo.address,
        ipv6: demo.address.contains(':') ? demo.address : '',
        vcpu: demo.vcpu,
        ramBytes: (demo.ramGib * _gib).round(),
        diskBytes: demo.diskGib * _gib,
        trafficBytes: demo.trafficGib * _gib,
        trafficPeriodMonths: 1,
      ),
      favorite: demo.favorite,
      billing: BillingKind.prepaid,
      currency: demo.currency,
      amountMinor: demo.minor,
      cycleMonths: demo.cycleMonths,
      startDate: firstDue.addMonths(-demo.cycleMonths),
      dueDate: firstDue,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final catalog = demo.catalogId == null
        ? null
        : CatalogProviderRef(catalogId: demo.catalogId!, name: providerName);
    await store.saveServer(
      record,
      isNew: true,
      catalogProvider: catalog,
      newProvider: catalog == null
          ? ProviderRecord(
              id: newLocalId(),
              name: providerName,
              createdAt: DateTime.now(),
            )
          : null,
    );
    // One payment per elapsed cycle, each on the due date it renewed.
    for (var i = 0; i < demo.payments; i++) {
      final current = (await store.servers()).firstWhere(
        (s) => s.id == record.id,
      );
      await store.recordPayment(
        id: 'demo-${serial++}',
        server: current,
        amount: Money(demo.currency, demo.minor),
        paidDate: current.dueDate!,
        cycleCount: 1,
        until: renewalDate(current, 1),
        confirmed: true,
      );
    }
  }
  await store.recordAccountPayment(
    id: 'demo-account',
    accountLabel: zh ? '域名 example.com' : 'Domain example.com',
    amount: const Money('USD', 1299),
    paidDate: today.addDays(-40),
  );
  await store.saveFx(
    FxSettings(
      displayCurrency: zh ? 'CNY' : 'USD',
      usdToCny: '7.10',
      eurToCny: '7.75',
      rateDate: today,
    ),
  );
  await store.saveLanguagePreference(
    zh ? LocalePreference.chinese : LocalePreference.english,
  );
  await store.saveThemeMode(theme);
  return store;
}
