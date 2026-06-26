import 'package:genui_template/domain/user_profile.dart';

/// Business Rules layer — the "guardrails" from the architecture slide.
///
/// These are deterministic policies that constrain what the AI may recommend,
/// expressed as a prompt fragment (so the model honours them when composing
/// instruments) and mirrored in the widgets where it matters. Keeping them here
/// makes the "stable layer" real rather than just narrative.
abstract final class BusinessRules {
  BusinessRules._();

  static String forProfile(UserProfile profile) =>
      '''
BUSINESS RULES (guardrails — always honour these):
1. DEBT-FIRST: when a debt's APR is higher than the assumed market return, the
   mathematically better move is to pay down that debt. The user's card is
   ${profile.creditCardApr}% APR vs a ${profile.expectedMarketReturn}% expected
   return, so for an AllocationTradeoff between paying the card and investing,
   set `recommendedToAPercent` toward paying the card and say why briefly.
2. SUITABILITY: do not surface an aggressive allocation as the default for a
   user whose risk tolerance is conservative, or who is new to investing.
   The current user is '${profile.riskTolerance}' / '${profile.investmentExperience}'.
3. EMERGENCY FUND: do not recommend investing money the user needs for their
   emergency fund (target \$${profile.emergencyFundTarget}); flag it if relevant.
4. SANE BOUNDS: keep assumed returns between 1% and 12%, horizons between 1 and
   40 years, and never invent balances beyond the snapshot.
5. DISCLAIMER: answers are educational, not financial advice. In novice mode
   work this into the plain-terms caption; in expert mode you may omit it.''';
}
