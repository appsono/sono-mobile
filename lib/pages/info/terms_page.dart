import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sono/styles/app_theme.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

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
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text(
              'Terms of Service',
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

                  _buildSection('1. Scope and Service Provider', [
                    '1.1 These Terms of Service (hereinafter "Terms") govern the use of the mobile application "Sono" (hereinafter "App") and all associated services.',
                    '1.2 The App is operated by:\n\nMathis Laarmanns\nNorth Rhine-Westphalia, Germany\nEmail: business@mail.sono.wtf',
                    '1.3 These Terms regulate the contractual relationship between the operator and the users of the App.',
                  ]),

                  _buildSection('2. Contract Formation and Registration', [
                    '2.1 By downloading and installing the App, a usage agreement is established between the user and the operator.',
                    '2.2 Registration is optional. The App can be used without creating an account for basic features including:',
                    '• Playing local music files\n• Creating local playlists\n• SAS (Sono Audio Stream) sessions\n• Last.fm integration\n• Sleep timer and playback controls',
                    '2.3 A Sono Account provides access to Sono API Features, including:',
                    '• Uploading songs to the Sono CDN (Content Delivery Network)\n• Creating playlists with uploaded songs\n• Cross-device access to your uploaded content\n• Cloud-based playlist management\n• Other cloud-based Sono API features',
                    '2.4 Age Requirements:',
                    '• The App can be used without any age restriction\n• Creating a Sono Account requires users to be at least 13 years old, or the minimum age required by law in their country of residence, whichever is higher\n• Users under 18 may require parental consent depending on their local jurisdiction',
                    '2.5 Users who create an account must provide truthful and complete information and keep it current.',
                  ]),

                  _buildSection('3. Service Description', [
                    '3.1 Sono is a music player application with the following main features:',
                    '• Playback of local music files\n• SAS (Sono Audio Stream) - peer-to-peer audio streaming for shared listening experiences\n• Last.fm integration for scrobbling and music metadata\n• Lyrics display via lrclib integration\n• Music metadata via MusicBrainz\n• Sleep timer functionality\n• Speed and pitch adjustments',
                    'Sono API Features (requires Sono Account):',
                    '• Upload songs to the Sono CDN (Content Delivery Network)\n• Create and manage playlists with uploaded songs\n• Access your uploaded content across devices\n• Cloud-based playlist management',
                    '3.2 The operator reserves the right to develop, modify, or restrict the App\'s features, provided this is reasonable for the user.',
                    '3.3 The operator does not guarantee any specific availability of the App or connected services.',
                    '3.4 The operator reserves the right to introduce premium features or paid subscription tiers in the future. Users will be notified in advance.',
                  ]),

                  _buildSection('4. Usage Rights and Obligations', [
                    '4.1 The operator grants the user a non-exclusive, non-transferable, limited right to use the App for personal, non-commercial purposes for the duration of the contract.',
                    '4.2 The user agrees to:',
                    '• Use the App only in accordance with applicable laws\n• Not violate any third-party rights (particularly copyright, trademark, or personal rights)\n• Not decompile, reverse engineer, or modify the App\n• Not take any measures that impair the functionality of the App\n• Only use music for which they have appropriate usage rights\n• Not upload copyrighted content without authorization (for users with Sono Accounts)',
                    '4.3 In case of violations of these obligations, the operator may block access to the App and terminate the contract extraordinarily.',
                  ]),

                  _buildSection('5. SAS (Sono Audio Stream)', [
                    '5.1 SAS (Sono Audio Stream) is a feature that enables peer-to-peer audio streaming between devices for shared listening experiences.',
                    '5.2 The host of a SAS session is responsible for the legality of the streamed content.',
                    '5.3 Participation in SAS sessions occurs via QR code scanning. The user is responsible for the security of their session access credentials.',
                    '5.4 The operator assumes no liability for content shared in SAS sessions.',
                    '5.5 SAS sessions are direct device-to-device connections. No audio data is stored on our servers.',
                  ]),

                  _buildSection('6. Sono Account and API Features (Optional)', [
                    '6.1 Users who create a Sono Account gain access to Sono API Features:',
                    '• Upload songs to the Sono CDN (Content Delivery Network)\n• Create playlists with uploaded songs\n• Access uploaded content from any device\n• Manage cloud-based playlists',
                    '6.2 To create a playlist using Sono API Features, songs must first be uploaded to the Sono CDN. Local playlists can be created without an account.',
                    '6.3 The operator reserves the right to impose reasonable storage limits on uploaded content.',
                    '6.4 Users are solely responsible for ensuring they have the legal rights to upload content to Sono CDN.',
                    '6.5 The operator may remove uploaded content that violates copyright laws or these Terms without prior notice.',
                  ]),

                  _buildSection('7. External Services and APIs', [
                    '7.1 The App uses external services (Last.fm, MusicBrainz, lrclib). The respective terms of service of these providers apply.',
                    '7.2 The operator provides no guarantee for the availability, accuracy, or completeness of data from external services.',
                    '7.3 Use of Last.fm requires a separate account. Processing occurs according to Last.fm\'s privacy policy.',
                  ]),

                  _buildSection('8. Compensation and Payment', [
                    '8.1 The basic use of the App is currently free of charge.',
                    '8.2 The operator reserves the right to offer paid premium features in the future. Users will be informed in a timely manner.',
                  ]),

                  _buildSection('9. Data Protection', [
                    '9.1 The processing of personal data is carried out in accordance with the App\'s Privacy Policy and the provisions of the GDPR.',
                    '9.2 The Privacy Policy is an integral part of these Terms.',
                  ]),

                  _buildSection('10. Term and Termination', [
                    '10.1 The contract is concluded for an indefinite period.',
                    '10.2 Both parties may terminate the contract at any time without notice.',
                    '10.3 Termination by the user occurs through deletion of the account in the App settings or by email to business@mail.sono.wtf. Users without accounts can simply delete the App.',
                    '10.4 The right to extraordinary termination for good cause remains unaffected.',
                  ]),

                  _buildSection('11. Final Provisions', [
                    '11.1 The law of the Federal Republic of Germany applies, excluding the UN Convention on Contracts for the International Sale of Goods.',
                    '11.2 If the user is a consumer with residence in another EU member state, the mandatory consumer protection provisions of that state remain applicable.',
                    '11.3 Should individual provisions of these Terms be or become invalid, the validity of the remaining provisions remains unaffected.',
                  ]),

                  _buildSection('12. Dispute Resolution', [
                    '12.1 The European Online Dispute Resolution (ODR) platform was discontinued as of 20 July 2025 (Regulation (EU) 2024/3228). For information about consumer dispute resolution bodies in the EU, Norway, and Iceland, please refer to the official list provided by the European Commission.',
                    '12.2 You may also find useful advice and guidance for consumers on the Your Europe website.',
                    '12.3 If you do not have a consumer dispute but wish to contest an unjustified restriction of your content or account by an online platform, you may contact an out-of-court dispute settlement body certified pursuant to Article 21 of Regulation (EU) 2022/2065 (Digital Services Act).',
                    '12.4 The operator is not obligated or willing to participate in dispute resolution proceedings before a consumer arbitration board.',
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
          const SizedBox(height: 12),
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
}
