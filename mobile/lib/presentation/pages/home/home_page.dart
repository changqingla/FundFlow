import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_router.dart';
import '../ai/ai_chat_page.dart';
import 'tabs/fund_tab.dart';
import 'tabs/market_tab.dart';
import 'tabs/news_tab.dart';
import 'tabs/sector_tab.dart';

/// Home page with bottom navigation
///
/// Features:
/// - Bottom navigation with 5 tabs: 快讯, 市场, 基金, 板块, AI
/// - Settings icon in app bar for navigation to settings page
///
/// Requirements: 17.2
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    NewsTab(),
    MarketTab(),
    FundTab(),
    SectorTab(),
    AIChatPage(),
  ];

  final List<String> _titles = const [
    '快讯',
    '市场',
    '基金',
    '板块',
    'AI 助手',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '设置',
            onPressed: () => _navigateToSettings(context),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.flash_on),
            label: '快讯',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.show_chart),
            label: '市场',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: '基金',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.category),
            label: '板块',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.smart_toy),
            label: 'AI',
          ),
        ],
      ),
    );
  }

  void _navigateToSettings(BuildContext context) {
    context.pushToSettings();
  }
}
