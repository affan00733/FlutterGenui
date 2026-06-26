import 'dart:convert';

import 'package:genui_template/data/supabase_config.dart';
import 'package:genui_template/domain/market_data.dart';
import 'package:genui_template/domain/user_profile.dart';
import 'package:http/http.dart' as http;

/// The Data + Services layer's entry point. Loads the user's financial profile
/// from Supabase's REST (PostgREST) API when configured, and falls back to the
/// bundled mock otherwise — so the app runs identically with or without a
/// backend. Uses plain HTTP (no SDK), which keeps it light and CORS-friendly.
abstract final class ProfileRepository {
  ProfileRepository._();

  /// The active profile. Defaults to the mock until [init] loads live data.
  static UserProfile profile = UserProfile.demo;

  /// Market assumptions, loaded live or defaulted.
  static MarketData market = MarketData.demo;

  /// True once a real profile has been loaded from Supabase.
  static bool isLive = false;

  /// Loads the profile + market data from Supabase if configured. Any failure
  /// leaves the mock data in place. Call once before `runApp`.
  static Future<void> init() async {
    if (!SupabaseConfig.isConfigured) return;
    try {
      final loaded = await _load();
      if (loaded != null) {
        profile = loaded;
        isLive = true;
      }
      market = await _loadMarket() ?? MarketData.demo;
    } on Object catch (_) {
      // Keep the mock data so the demo never breaks on a config issue.
    }
  }

  static Future<MarketData?> _loadMarket() async {
    final rows = await _select('market');
    if (rows.isEmpty) return null;
    final m = rows.first;
    num n(Object? v, num fallback) => (v as num?) ?? fallback;
    return MarketData(
      sp500Return: n(m['sp500_return'], 7),
      savingsApy: n(m['savings_apy'], 4.5),
      mortgageRate: n(m['mortgage_rate'], 6.7),
      inflation: n(m['inflation'], 3),
    );
  }

  static Map<String, String> get _headers => {
    'apikey': SupabaseConfig.anonKey,
    'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
  };

  static Future<List<Map<String, dynamic>>> _select(String table) async {
    final res = await http.get(
      Uri.parse('${SupabaseConfig.url}/rest/v1/$table?select=*'),
      headers: _headers,
    );
    if (res.statusCode != 200) return const [];
    return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
  }

  static Future<UserProfile?> _load() async {
    final profiles = await _select('profiles');
    if (profiles.isEmpty) return null;
    final p = profiles.first;
    final debts = await _select('debts');
    final assets = await _select('assets');

    num n(Object? v) => (v as num?) ?? 0;

    return UserProfile(
      firstName: p['first_name'] as String? ?? 'there',
      monthlyNetIncome: n(p['monthly_net_income']),
      monthlyExpenses: n(p['monthly_expenses']),
      cashSavings: n(p['cash_savings']),
      emergencyFundTarget: n(p['emergency_fund_target']),
      creditCardBalance: n(p['credit_card_balance']),
      creditCardApr: n(p['credit_card_apr']),
      investmentExperience: p['investment_experience'] as String? ?? 'some',
      riskTolerance: p['risk_tolerance'] as String? ?? 'moderate',
      expectedMarketReturn: n(p['expected_market_return']),
      debts: [
        for (final d in debts)
          (
            name: d['name'] as String? ?? 'Debt',
            balance: n(d['balance']),
            apr: n(d['apr']),
            minPayment: n(d['min_payment']),
          ),
      ],
      assets: [
        for (final a in assets)
          (name: a['name'] as String? ?? 'Asset', amount: n(a['amount'])),
      ],
    );
  }
}
