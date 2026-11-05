import 'package:flutter/material.dart';

import 'agents_tab.dart';
import 'goals_tab.dart';
import 'motion.dart';
import 'insights_tab.dart';
import 'plan_tab.dart';
import 'risk_tab.dart';
import 'settings/settings_page.dart';
import 'wealth_tab.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  static const _tabs = <(String, IconData, Widget)>[
    ('Plan', Icons.pie_chart_outline, PlanTab()),
    ('Wealth', Icons.account_balance_wallet_outlined, WealthTab()),
    ('Goals', Icons.flag_outlined, GoalsTab()),
    ('Insights', Icons.insights_outlined, InsightsTab()),
    ('Agents', Icons.smart_toy_outlined, AgentsTab()),
    ('Risk', Icons.speed_outlined, RiskTab()),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Samridhi · ${_tabs[_index].$1}'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
            ),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: motionDuration(context, 250),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, 0.02),
              end: Offset.zero,
            ).animate(anim),
            child: child,
          ),
        ),
        child: KeyedSubtree(key: ValueKey(_index), child: _tabs[_index].$3),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final t in _tabs)
            NavigationDestination(icon: Icon(t.$2), label: t.$1),
        ],
      ),
    );
  }
}
