/// Data + Services layer — the "source of truth" from the architecture slide.
///
/// In a real app this comes from a backend (PMS/CRM/accounts, or Supabase for
/// this hackathon). Here it's a realistic mock so the generated instruments
/// arrive PRE-FILLED with the user's actual numbers, which is what makes the
/// experience feel personalized rather than generic.
library;

/// One of the user's debts.
typedef DebtRecord = ({String name, num balance, num apr, num minPayment});

/// One of the user's assets.
typedef AssetRecord = ({String name, num amount});

class UserProfile {
  const UserProfile({
    required this.firstName,
    required this.monthlyNetIncome,
    required this.monthlyExpenses,
    required this.cashSavings,
    required this.emergencyFundTarget,
    required this.creditCardBalance,
    required this.creditCardApr,
    required this.investmentExperience,
    required this.riskTolerance,
    required this.expectedMarketReturn,
    required this.debts,
    required this.assets,
  });

  final String firstName;
  final num monthlyNetIncome;
  final num monthlyExpenses;
  final num cashSavings;
  final num emergencyFundTarget;

  /// Outstanding credit-card balance and its APR — the hook for the
  /// debt-vs-invest trade-off demo.
  final num creditCardBalance;
  final num creditCardApr;

  /// 'none' | 'some' | 'experienced'.
  final String investmentExperience;

  /// 'conservative' | 'moderate' | 'aggressive'.
  final String riskTolerance;

  /// A reasonable long-run expected return assumption (%) used as the default
  /// for projections.
  final num expectedMarketReturn;

  /// All of the user's debts (powers DebtPayoffPlanner with zero typing).
  final List<DebtRecord> debts;

  /// All of the user's assets (powers NetWorthTracker with zero typing).
  final List<AssetRecord> assets;

  num get monthlySurplus => monthlyNetIncome - monthlyExpenses;

  /// The default profile used across the app.
  static const demo = UserProfile(
    firstName: 'Affan',
    monthlyNetIncome: 7200,
    monthlyExpenses: 4300,
    cashSavings: 18000,
    emergencyFundTarget: 25800, // ~6 months of expenses
    creditCardBalance: 6400,
    creditCardApr: 22.0,
    investmentExperience: 'some',
    riskTolerance: 'moderate',
    expectedMarketReturn: 7.0,
    debts: [
      (name: 'Store card', balance: 1200, apr: 26, minPayment: 35),
      (name: 'Visa', balance: 6400, apr: 22, minPayment: 160),
      (name: 'Car loan', balance: 9000, apr: 6, minPayment: 240),
    ],
    assets: [
      (name: 'Cash savings', amount: 18000),
      (name: 'Investments', amount: 32000),
      (name: 'Car', amount: 14000),
    ],
  );

  /// A compact snapshot the system prompt injects so the model can pre-fill
  /// instruments with the user's real figures.
  String toPromptSnapshot() {
    final debtLines = debts
        .map((d) => '${d.name} \$${d.balance} @ ${d.apr}% (min \$${d.minPayment}/mo)')
        .join('; ');
    final assetLines = assets
        .map((a) => '${a.name} \$${a.amount}')
        .join('; ');
    return '''
USER FINANCIAL SNAPSHOT (use these numbers to pre-fill instruments):
- Name: $firstName
- Monthly net income: \$$monthlyNetIncome
- Monthly expenses: \$$monthlyExpenses (monthly surplus ≈ \$$monthlySurplus)
- Cash savings: \$$cashSavings  (emergency-fund target: \$$emergencyFundTarget)
- Debts: $debtLines
- Assets: $assetLines
- Investment experience: $investmentExperience
- Risk tolerance: $riskTolerance
- Assumed long-run market return: $expectedMarketReturn%''';
  }
}
