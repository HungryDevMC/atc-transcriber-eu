import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart';
import '../../core/utils/atc_vocabulary.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final darkMode = ref.watch(darkModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          _buildSection(
            'Appearance',
            [
              SwitchListTile(
                title: const Text('Dark Mode'),
                subtitle: const Text('Use dark theme for cockpit visibility'),
                value: darkMode,
                onChanged: (value) {
                  ref.read(darkModeProvider.notifier).state = value;
                  ref.read(storageServiceProvider).setDarkMode(value);
                },
              ),
            ],
          ),
          _buildSection(
            'Audio',
            [
              ListTile(
                title: const Text('Speech Model'),
                subtitle: const Text('Vosk small-en-us'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showModelInfo(context),
              ),
            ],
          ),
          _buildSection(
            'Reference',
            [
              ListTile(
                title: const Text('Belgian Airports'),
                subtitle: Text('${AtcVocabulary.belgianAirports.length} airports'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showAirports(context),
              ),
              ListTile(
                title: const Text('Common Frequencies'),
                subtitle: Text('${AtcVocabulary.belgianFrequencies.length} frequencies'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showFrequencies(context),
              ),
              ListTile(
                title: const Text('Phonetic Alphabet'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showPhonetic(context),
              ),
            ],
          ),
          _buildSection(
            'About',
            [
              const ListTile(
                title: Text('Version'),
                subtitle: Text('0.1.0'),
              ),
              ListTile(
                title: const Text('Licenses'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showLicensePage(context: context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              letterSpacing: 1,
            ),
          ),
        ),
        ...children,
      ],
    );
  }

  void _showModelInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Speech Model'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This app uses Vosk for offline speech recognition.',
            ),
            SizedBox(height: 16),
            Text(
              'To install a model:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('1. Download a Vosk model from:'),
            Text(
              'https://alphacephei.com/vosk/models',
              style: TextStyle(color: Colors.blue),
            ),
            SizedBox(height: 8),
            Text('2. Extract and place in the app documents folder'),
            SizedBox(height: 8),
            Text(
              'Recommended: vosk-model-small-en-us (40MB)',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showAirports(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Belgian Airports',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                ...AtcVocabulary.belgianAirports.entries.map(
                  (e) => ListTile(
                    leading: const Icon(Icons.flight),
                    title: Text(e.key),
                    subtitle: Text(e.value),
                  ),
                ),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Nearby Airports',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                ...AtcVocabulary.nearbyAirports.entries.map(
                  (e) => ListTile(
                    leading: const Icon(Icons.flight_outlined),
                    title: Text(e.key),
                    subtitle: Text(e.value),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFrequencies(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Belgian Frequencies',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ListView(
              children: AtcVocabulary.belgianFrequencies.entries.map(
                (e) => ListTile(
                  leading: const Icon(Icons.radio),
                  title: Text(e.key),
                  subtitle: Text(e.value),
                ),
              ).toList(),
            ),
          ),
        ],
      ),
    );
  }

  void _showPhonetic(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'NATO Phonetic Alphabet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: GridView.count(
              crossAxisCount: 4,
              padding: const EdgeInsets.all(16),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.2,
              children: AtcVocabulary.phoneticAlphabet.entries.map(
                (e) => Card(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          e.key,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          e.value,
                          style: const TextStyle(fontSize: 9),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
