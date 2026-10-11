import 'package:flutter/material.dart';

import '../widgets/contract_board.dart';
import '../widgets/terminal.dart';

/// Contracts, off the home sheet.
///
/// They were three bands on a screen that already had eight zones on it.
/// Home is for dispatching, not for reading; anything you study rather than
/// glance at belongs behind a line in the index.
class ContractsScreen extends StatelessWidget {
  const ContractsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return TerminalScaffold(
      title: 'CONTRACTS',
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 40),
        children: const [ContractBoardPanel()],
      ),
    );
  }
}
