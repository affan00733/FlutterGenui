import 'package:genui/genui.dart';
import 'package:genui_template/domain/persona.dart';
import 'package:genui_template/widgets/instruments/affordability_check.dart';
import 'package:genui_template/widgets/instruments/allocation_tradeoff.dart';
import 'package:genui_template/widgets/instruments/amortization_schedule.dart';
import 'package:genui_template/widgets/instruments/budget_breakdown.dart';
import 'package:genui_template/widgets/instruments/confirmation_card.dart';
import 'package:genui_template/widgets/instruments/debt_payoff_planner.dart';
import 'package:genui_template/widgets/instruments/emergency_fund_gauge.dart';
import 'package:genui_template/widgets/instruments/growth_projection.dart';
import 'package:genui_template/widgets/instruments/net_worth_tracker.dart';
import 'package:genui_template/widgets/instruments/option_comparison.dart';
import 'package:genui_template/widgets/instruments/paycheck_breakdown.dart';
import 'package:genui_template/widgets/instruments/rent_vs_buy.dart';
import 'package:genui_template/widgets/instruments/retirement_projection.dart';
import 'package:genui_template/widgets/instruments/risk_allocation.dart';
import 'package:genui_template/widgets/instruments/savings_goal_simulator.dart';
import 'package:genui_template/widgets/instruments/subscription_audit.dart';

/// Builds the catalog of widgets the model is allowed to generate, adapted to
/// the [persona] — an example of a catalog that changes based on who is using
/// the app (while staying a fixed, safe vocabulary the model can't escape).
///
/// A [Catalog] is the model's vocabulary: each entry is a widget the model can
/// request by name. The same catalog drives both the rendered surfaces and the
/// system prompt, so the model only ever emits components this client can
/// actually build.
///
/// Both personas get the core single-decision tools; Expert additionally
/// unlocks the advanced instruments (multi-option comparison and risk
/// allocation), so the available toolset literally expands with expertise.
Catalog buildCatalog(Persona persona) {
  return BasicCatalogItems.asNoAssetCatalog().copyWith(
    newItems: [
      // Core tools, available to everyone.
      allocationTradeoff,
      savingsGoalSimulator,
      growthProjection,
      budgetBreakdown,
      amortizationSchedule,
      debtPayoffPlanner,
      affordabilityCheck,
      netWorthTracker,
      emergencyFundGauge,
      retirementProjection,
      rentVsBuy,
      paycheckBreakdown,
      subscriptionAudit,
      confirmationCard,
      // Advanced tools, unlocked for experienced users.
      if (persona == Persona.expert) ...[
        optionComparison,
        riskAllocation,
      ],
    ],
  );
}
