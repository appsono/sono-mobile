import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sono/styles/app_theme.dart';

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            backgroundColor: AppTheme.backgroundDark,
            elevation: 0,
            pinned: true,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_rounded,
                color: Colors.white,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text(
              'Privacy Policy',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFamily: 'VarelaRound',
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      'Last Updated: January 24, 2026',
                      style: TextStyle(
                        color: Colors.white.withAlpha(153),
                        fontSize: 14,
                        fontFamily: 'VarelaRound',
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  _buildSection('1. Data Controller', [
                    'The data controller within the meaning of the General Data Protection Regulation (GDPR) is:\n\nMathis Laarmanns\nNorth Rhine-Westphalia, Germany\nEmail: business@mail.sono.wtf',
                  ]),

                  _buildSection('2. Principles of Data Processing', [
                    'We process your personal data in accordance with the principles of the GDPR:',
                    '• Lawfulness, fairness, and transparency\n• Purpose limitation\n• Data minimization\n• Accuracy\n• Storage limitation\n• Integrity and confidentiality',
                  ]),

                  _buildSection('3. Legal Basis for Processing', [
                    'The processing of personal data is based on:',
                    '• Art. 6(1)(a) GDPR - Consent\n• Art. 6(1)(b) GDPR - Contract performance\n• Art. 6(1)(f) GDPR - Legitimate interests\n• Art. 6(1)(c) GDPR - Legal obligation',
                  ]),

                  _buildSection('4. Types of Data Processed', []),

                  _buildSubsection('4.1 Account Data (Sono Accounts API) - OPTIONAL', [
                    'Registration provides access to Sono API Features. If you create a Sono Account, we collect:',
                    '• Username\n• Email address\n• Password (encrypted)\n• Profile picture (optional)',
                    'What you can do with a Sono Account:',
                    '• Upload songs to the Sono CDN (Content Delivery Network)\n• Create playlists with your uploaded songs\n• Access your content from any device',
                    'Legal basis: Art. 6(1)(b) GDPR (contract performance)\nStorage duration: Until account deletion\nNote: You can use the App without an account for all local features',
                  ]),

                  _buildSubsection('4.2 Music Library and Metadata', [
                    'Local (No Account Required):',
                    '• Titles, artists, albums of local music files\n• Playback history (stored locally on your device)\n• Local playlists and favorites',
                    'Cloud-Based (Sono Account Required):',
                    '• Songs uploaded to Sono CDN\n• Playlists created with uploaded songs\n• Cloud playlist metadata',
                    'Legal basis: Art. 6(1)(b) GDPR (contract performance)\nStorage location: Local data on your device only; Uploaded songs on Sono CDN (requires account)',
                  ]),

                  _buildSubsection('4.3 Uploaded Songs (Sono Account Feature)', [
                    'If you have a Sono Account and upload songs to the CDN:',
                    '• Song files (audio content)\n• Metadata (title, artist, album, duration)\n• Upload timestamp\n• Associated user account',
                    'Purpose: To create playlists with your uploaded songs and access them across devices.',
                    'Legal basis: Art. 6(1)(b) GDPR (contract performance)\nStorage location: Sono CDN (Content Delivery Network)\nStorage duration: Until you delete the content or your account',
                  ]),

                  _buildSubsection('4.4 Device Information', [
                    '• Device model and operating system version\n• App version\n• Unique device ID (for session management)\n• IP address (temporarily for SAS sessions)',
                    'Legal basis: Art. 6(1)(f) GDPR (legitimate interest in functionality)\nStorage duration: Until session termination/disconnection',
                  ]),

                  _buildSubsection('4.5 Crash Logs - OPTIONAL (OPT-OUTABLE)', [
                    'We collect crash logs to improve app stability and fix bugs. This includes:',
                    '• Error logs and stack traces (anonymized, no personal data)\n• Device type and OS version (for compatibility)\n• App version and build number',
                  ]),

                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(13),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withAlpha(51),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Important:',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'VarelaRound',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• This data is fully anonymized and cannot be linked to you\n• No personally identifiable information is included\n• You can opt out at any time in Settings > Devloper > "Crash Reporting"',
                          style: TextStyle(
                            color: Colors.white.withAlpha(204),
                            fontSize: 15,
                            height: 1.6,
                            fontFamily: 'VarelaRound',
                          ),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      'Legal basis: Art. 6(1)(f) GDPR (legitimate interest in app improvement)\nStorage duration: 12 months, then automatic deletion\nOpt-out: Settings > Devloper > Crash Reporting (toggle off)',
                      style: TextStyle(
                        color: Colors.white.withAlpha(204),
                        fontSize: 15,
                        height: 1.6,
                        fontFamily: 'VarelaRound',
                      ),
                    ),
                  ),

                  _buildSubsection('4.6 Camera and Photo Access (Optional)', [
                    '• Camera: For QR code scanning (SAS sessions) and profile pictures\n• Photo Library: For selecting profile pictures',
                    'Legal basis: Art. 6(1)(a) GDPR (consent)\nUsage: Only when actively using the feature',
                  ]),

                  _buildSection('5. Data Sharing with Third Parties', []),

                  _buildSubsection('5.1 Last.fm API', [
                    'When Last.fm scrobbling is enabled, we transmit:',
                    '• Song title, artist, album\n• Playback timestamp\n• Your Last.fm username',
                    'Recipient: Last FM Limited, UK\nLegal basis: Art. 6(1)(a) GDPR (consent)\nPrivacy Policy: https://www.last.fm/legal/privacy',
                  ]),

                  _buildSubsection('5.2 MusicBrainz API', [
                    'For music metadata (album release dates):',
                    '• Artist name, album title (as search query)',
                    'Recipient: MetaBrainz Foundation\nLegal basis: Art. 6(1)(b) GDPR (contract performance)\nPrivacy Policy: https://metabrainz.org/privacy',
                  ]),

                  _buildSubsection('5.3 lrclib API', [
                    'For lyrics retrieval:',
                    '• Song title, artist (as search query)',
                    'Legal basis: Art. 6(1)(b) GDPR (contract performance)',
                  ]),

                  _buildSubsection('5.4 No Sale or Marketing', [
                    'Your data is never sold or shared with third parties for advertising purposes.',
                  ]),

                  _buildSection('6. SAS (Sono Audio Stream)', [
                    'SAS (Sono Audio Stream) is a peer-to-peer audio streaming feature for shared listening experiences.',
                    'Host Mode: As a SAS session host, a temporary server is created on your device. Your local IP address is visible to connected clients.',
                    'Client Mode: As a participant, your IP address is visible to the host. You receive audio streams from the host.',
                    'Important: SAS sessions are peer-to-peer between devices. We do not store any audio data on our servers.',
                    'Duration: Only during active session',
                  ]),

                  _buildSection('7. Data Security', [
                    'We implement technical and organizational measures:',
                    '• Encrypted transmission (TLS/SSL)\n• Encrypted password storage (hashing)\n• Regular security updates\n• Server access restrictions\n• Secure audio streaming connections',
                  ]),

                  _buildSection('8. Your Rights', [
                    'You have the following rights under the GDPR:',
                  ]),

                  _buildSubsection('8.1 Right to Access (Art. 15 GDPR)', [
                    'You can request information about the data stored about you at any time.',
                  ]),

                  _buildSubsection('8.2 Right to Rectification (Art. 16 GDPR)', [
                    'Incorrect data will be corrected immediately upon your request.',
                  ]),

                  _buildSubsection('8.3 Right to Erasure (Art. 17 GDPR)', [
                    'You can request deletion of your data, provided there are no legal retention obligations.',
                    'With Account: Request account deletion at business@mail.sono.wtf\nWithout Account: Simply delete the app to remove all local data',
                  ]),

                  _buildSubsection(
                    '8.4 Right to Data Portability (Art. 20 GDPR)',
                    [
                      'You can receive your data in a structured, machine-readable format.',
                    ],
                  ),

                  _buildSubsection('8.5 Withdrawal of Consent (Art. 7(3) GDPR)', [
                    'You can withdraw any consent given at any time:',
                    '• Crash Reports: Settings > Devloper > Crash Reporting (toggle off)\n• Last.fm: Settings > Library & Scrobbling > Last.fm Scrobbling > Enable Scrobbling (toggle off)\n• Permissions: Device Settings > Apps > Sono > Permissions',
                  ]),

                  _buildSubsection(
                    '8.6 Right to Lodge a Complaint (Art. 77 GDPR)',
                    [
                      'You have the right to lodge a complaint with a data protection supervisory authority:',
                      'For Germany:\nDie Bundesbeauftragte für den Datenschutz und die Informationsfreiheit\nGraurheindorfer Str. 153\n53117 Bonn\nPhone: +49 (0)228-997799-0\nEmail: poststelle@bfdi.bund.de\nWebsite: https://www.bfdi.bund.de',
                    ],
                  ),

                  _buildSection('9. Age Requirements', [
                    'Using the App: No age restriction - anyone can use the App',
                    'Creating a Sono Account: Users must be at least 13 years old, or the minimum age required by law in their country of residence, whichever is higher',
                    'Users under 18: May require parental consent depending on local jurisdiction',
                  ]),

                  _buildSection('10. International Data Transfers', [
                    'Data may be transferred to countries outside the EU/EEA. In such cases, we ensure adequate protection through:',
                    '• EU Standard Contractual Clauses (SCCs)\n• Adequacy decisions by the European Commission\n• Other appropriate safeguards under GDPR',
                  ]),

                  _buildSection('11. Third-Party Services', [
                    'The App integrates services from Last.fm, MusicBrainz, and lrclib. Each service operates under its own privacy policy. We are not responsible for the data processing practices of these external services.',
                  ]),

                  _buildSection('12. Dispute Resolution', [
                    'The EU Online Dispute Resolution platform has been discontinued as of July 20, 2025 (Regulation EU 2024/3228). For information on consumer redress bodies in the EU, please visit:',
                  ]),

                  GestureDetector(
                    onTap:
                        () => _launchUrl(
                          'https://consumer-redress.ec.europa.eu/dispute-resolution-bodies',
                        ),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        'https://consumer-redress.ec.europa.eu/dispute-resolution-bodies',
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontSize: 15,
                          fontFamily: 'VarelaRound',
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),

                  _buildSection('13. Changes to This Privacy Policy', [
                    'We reserve the right to update this Privacy Policy to reflect changes in legal requirements or App functionality.',
                    'The current version is always available on https://sono.wtf/privacy',
                    'You will be notified of significant changes via in-app notification or email (if you have an account).',
                  ]),

                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(13),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withAlpha(26),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                          'Contact',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'VarelaRound',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'For questions about data protection or to exercise your rights, please contact us:',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withAlpha(179),
                            fontSize: 15,
                            fontFamily: 'VarelaRound',
                          ),
                        ),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap:
                              () => _launchUrl('mailto:business@mail.sono.wtf'),
                          child: Text(
                            'Email: business@mail.sono.wtf',
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontSize: 15,
                              fontFamily: 'VarelaRound',
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Mathis Laarmanns\nNorth Rhine-Westphalia, Germany',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withAlpha(179),
                            fontSize: 15,
                            fontFamily: 'VarelaRound',
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'This Privacy Policy complies with the requirements of the GDPR, the German Federal Data Protection Act (BDSG), and the Telecommunications-Telemedia Data Protection Act (TTDSG).',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withAlpha(128),
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            fontFamily: 'VarelaRound',
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<String> content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'VarelaRound',
            ),
          ),
          if (content.isNotEmpty) const SizedBox(height: 12),
          ...content.map(
            (text) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                text,
                style: TextStyle(
                  color: Colors.white.withAlpha(204),
                  fontSize: 15,
                  height: 1.6,
                  fontFamily: 'VarelaRound',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubsection(String title, List<String> content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withAlpha(242),
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: 'VarelaRound',
            ),
          ),
          const SizedBox(height: 8),
          ...content.map(
            (text) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                text,
                style: TextStyle(
                  color: Colors.white.withAlpha(204),
                  fontSize: 15,
                  height: 1.6,
                  fontFamily: 'VarelaRound',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}