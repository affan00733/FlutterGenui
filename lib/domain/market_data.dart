/// Market assumptions used as sensible defaults across instruments (expected
/// return, savings APY, mortgage rate, inflation). Loaded live from Supabase
/// when configured, else these realistic defaults are used.
class MarketData {
  const MarketData({
    required this.sp500Return,
    required this.savingsApy,
    required this.mortgageRate,
    required this.inflation,
  });

  final num sp500Return;
  final num savingsApy;
  final num mortgageRate;
  final num inflation;

  static const demo = MarketData(
    sp500Return: 7.0,
    savingsApy: 4.5,
    mortgageRate: 6.7,
    inflation: 3.0,
  );

  /// Injected into the system prompt so instruments default to real figures.
  String toPromptSnapshot() =>
      '''
CURRENT MARKET ASSUMPTIONS (use these as defaults unless the user gives others):
- Long-run S&P 500 return: ~$sp500Return%
- High-yield savings APY: ~$savingsApy%
- 30-year mortgage rate: ~$mortgageRate%
- Inflation: ~$inflation%''';
}
