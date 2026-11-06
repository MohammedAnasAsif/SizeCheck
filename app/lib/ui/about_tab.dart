import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import 'add_chart_screen.dart' show repoUrl;

class AboutTab extends StatelessWidget {
  const AboutTab({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final text = Theme.of(context).textTheme;
    final checked = state.lastDataCheck;

    Future<void> open(String url) =>
        launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              Text('SizeCheck', style: text.headlineSmall),
              const SizedBox(height: 4),
              const Text(
                'One body profile, the right size in every brand. '
                'Free and open source.',
              ),
              const SizedBox(height: 20),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.dataset_outlined),
                      title: Text(
                        '${state.builtInBrandCount} brands with '
                        'verified charts',
                      ),
                      subtitle: Text(
                        'Data version ${state.dataVersion}'
                        '${checked == null ? '' : ' · checked ${checked.toLocal().toString().substring(0, 16)}'}',
                      ),
                      trailing: state.checkingForUpdate
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : IconButton(
                              tooltip: 'Check for new charts',
                              icon: const Icon(Icons.refresh),
                              onPressed: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                final updated = await state.checkForUpdate(
                                  force: true,
                                );
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      updated
                                          ? 'Downloaded the latest size charts.'
                                          : 'You already have the latest charts.',
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.lock_outline),
                      title: const Text('Your data stays on this device'),
                      subtitle: const Text(
                        'No account, no tracking. SizeCheck '
                        'only goes online to download new size charts.',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.add_business_outlined),
                      title: const Text('Add or fix a brand'),
                      subtitle: const Text(
                        'Everyone benefits from each chart '
                        'added.',
                      ),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: () => open('$repoUrl/blob/main/CONTRIBUTING.md'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.code),
                      title: const Text('Source code'),
                      subtitle: const Text(
                        'github.com/MohammedAnasAsif/SizeCheck',
                      ),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: () => open(repoUrl),
                    ),
                    ListTile(
                      leading: const Icon(Icons.bug_report_outlined),
                      title: const Text('Report a problem'),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: () => open('$repoUrl/issues/new'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.gavel_outlined),
                      title: const Text('Licences'),
                      onTap: () => showLicensePage(
                        context: context,
                        applicationName: 'SizeCheck',
                        applicationLegalese:
                            'Code: Apache-2.0. Size data: '
                            'CC BY 4.0. Brand names belong to their owners and '
                            'are used only to identify their size charts.',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Size charts change and brands are not always consistent, so '
                'a recommendation is a well-informed guess. When in doubt, '
                'check the product page.',
                style: text.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
