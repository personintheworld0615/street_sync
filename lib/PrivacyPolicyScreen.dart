import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const _pageBg = Color(0xFFF7F8FA);
  static const _ink = Color(0xFF111827);
  static const _muted = Color(0xFF5E5D5D);

  static const _sections = <_PolicySection>[
    _PolicySection(
      title: '1. Information We Collect',
      body:
          'Depending on the features you use, StreetSync may collect the following information.',
      bullets: [
        _PolicyBullet(
          label: 'Account Information',
          text:
              'When you create an account, we collect your email address, first name, last name, and password (stored securely by our authentication provider). If you sign in with Google, we receive your name, email address, and profile photo from Google, as permitted by your Google account settings.',
        ),
        _PolicyBullet(
          label: 'Location Information',
          text:
              'StreetSync may use your device’s location to identify where an issue is being reported. Location access is used to help accurately place reports and is only accessed when permitted by you. You may also pin or adjust a location manually.',
        ),
        _PolicyBullet(
          label: 'Photos',
          text:
              'You may capture or upload images of infrastructure issues, and you may upload a profile photo. Report images are stored as part of the submitted report. Profile photos are stored with your account.',
        ),
        _PolicyBullet(
          label: 'Voice Input',
          text:
              'StreetSync may allow you to describe an issue using voice input. Voice input is converted to text using speech-recognition technology so that the description can be included in a report.',
        ),
        _PolicyBullet(
          label: 'Report Information',
          text:
              'We collect information you provide when creating a report, including the type of infrastructure issue, title, description, severity, approximate or precise location (including map coordinates when available), images, and the date and time of the report. Draft reports may also be saved until you submit or delete them.',
        ),
        _PolicyBullet(
          label: 'Public Profile Information',
          text:
              'Your display name and reporting activity may appear on the in-app leaderboard. Other users of StreetSync may also see submitted reports, including photos, descriptions, and locations, on the map and in community feeds.',
        ),
        _PolicyBullet(
          label: 'Technical Information',
          text:
              'StreetSync may collect limited technical information necessary for the application to function, such as error information or basic device information. The app may also cache report and account information on your device to improve performance.',
        ),
      ],
    ),
    _PolicySection(
      title: '2. How We Use Information',
      body: 'Information collected through StreetSync may be used to:',
      items: [
        'Create, authenticate, and manage your account.',
        'Create, save, and process infrastructure reports.',
        'Determine the location of reported issues.',
        'Display reported issues within the application, including on maps and community feeds.',
        'Analyze voice transcripts with AI to suggest a title, description, category, and severity, which you can review before submitting.',
        'Show contributor activity on the leaderboard.',
        'Organize reports for potential review by relevant local authorities.',
        'Improve the functionality and reliability of StreetSync.',
        'Prevent misuse or abuse of the platform.',
      ],
      footer: 'StreetSync does not use personal information for targeted advertising.',
    ),
    _PolicySection(
      title: '3. Location Data',
      paragraphs: [
        'Location information is used to determine where a reported infrastructure issue is located and to help you find reports near you.',
        'You may manually provide or adjust the location of an issue instead of relying on your device’s location services.',
        'StreetSync does not continuously track your location when the application is not being used to create or interact with reports.',
      ],
    ),
    _PolicySection(
      title: '4. Photos and Uploaded Content',
      paragraphs: [
        'You should only upload images that are relevant to the infrastructure issue being reported.',
        'Please avoid intentionally including sensitive personal information in photographs, descriptions, or profile photos. Because reports concern public infrastructure, submitted information may be viewed by other StreetSync users, project administrators, or organizations involved in reviewing the report.',
      ],
    ),
    _PolicySection(
      title: '5. Voice Processing and AI',
      paragraphs: [
        'If voice reporting is used, StreetSync processes voice input using speech-recognition technology on your device (typically provided by Apple or Google) to convert your description into text.',
        'That text may then be sent to StreetSync’s servers and processed by third-party AI language-model providers to suggest a title, description, category, and severity for the report. You can review and edit this information before submitting.',
        'StreetSync does not use voice recordings or transcripts for advertising or unrelated purposes.',
      ],
    ),
    _PolicySection(
      title: '6. Sharing of Information',
      paragraphs: [
        'Submitted reports, including photos, descriptions, and locations, may be visible to other StreetSync users inside the app.',
        'StreetSync may also share information contained in an infrastructure report with relevant local government departments, municipal officials, or other organizations responsible for addressing the reported issue.',
        'We do not sell users’ personal information.',
        'Information may also be disclosed when reasonably necessary to comply with applicable law, protect the security of StreetSync, or prevent misuse of the service.',
      ],
    ),
    _PolicySection(
      title: '7. Third-Party Services',
      body:
          'StreetSync relies on third-party technology providers to operate. These services may process limited information necessary to provide their functionality and operate under their own privacy policies. Current providers include:',
      items: [
        'Supabase, for authentication, databases, and image storage.',
        'Google, for Maps, location geocoding, and optional Google Sign-In.',
        'Apple or Google speech recognition, when voice input is used.',
        'Third-party AI language-model providers, when voice reports are analyzed to suggest report details.',
        'StreetSync’s own hosting and API infrastructure, which stores accounts and reports.',
      ],
    ),
    _PolicySection(
      title: '8. Data Security',
      paragraphs: [
        'We take reasonable measures to protect information handled by StreetSync. However, no online service, database, or method of electronic transmission can be guaranteed to be completely secure.',
        'Please avoid submitting unnecessary sensitive or confidential information through StreetSync.',
      ],
    ),
    _PolicySection(
      title: '9. Data Retention',
      paragraphs: [
        'StreetSync retains account and report information for as long as reasonably necessary to operate, display, improve, or evaluate the application, unless a longer period is required for legitimate operational or legal purposes.',
        'Draft reports are kept until you submit or delete them. Cached information stored on your device can be removed by signing out, deleting your account, or uninstalling the app.',
      ],
    ),
    _PolicySection(
      title: '10. Children’s Privacy',
      paragraphs: [
        'StreetSync is a civic reporting tool and is not directed at children under 13. We do not knowingly collect personal information from children under 13.',
        'If you believe a child under 13 has provided personal information through StreetSync, please contact us so we can delete it. Users should also avoid including sensitive personal information about themselves or others in reports.',
      ],
    ),
    _PolicySection(
      title: '11. User Choices',
      paragraphs: [
        'You may choose not to grant certain device permissions, such as location, camera, or microphone access. Some StreetSync features may not function correctly without the permissions required for those features.',
        'Where available, you may instead manually enter information, such as pinning a location on the map or typing a description instead of using voice input.',
        'You may also choose not to sign in with Google and create an account with an email address instead.',
      ],
    ),
    _PolicySection(
      title: '12. Access and Account Deletion',
      paragraphs: [
        'You can review and update many details of a report before it is submitted, and you can view your submitted reports and drafts from your profile.',
        'You may delete your StreetSync account from the Profile screen. Deleting your account permanently removes your account and associated reports from StreetSync. This cannot be undone.',
      ],
    ),
    _PolicySection(
      title: '13. Changes to This Privacy Policy',
      paragraphs: [
        'We may update this Privacy Policy as StreetSync develops or as new features are introduced.',
        'When significant changes are made, the “Last Updated” date at the top of this policy will be updated.',
      ],
    ),
    _PolicySection(
      title: '14. Contact',
      paragraphs: [
        'Questions or concerns regarding this Privacy Policy can be directed to aaravg.0615@gmail.com.',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: _pageBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: _ink,
        title: Text(
          'Privacy policy',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: -0.3,
            color: _ink,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
        children: [
          Text(
            'StreetSync Privacy Policy',
            style: GoogleFonts.playfairDisplay(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: _ink,
              height: 1.15,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Last updated: August 17, 2026',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: _muted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'StreetSync (“StreetSync,” “we,” “our,” or “us”) is a civic technology application designed to help users report community infrastructure issues, such as potholes, damaged signs, sidewalks, and other public concerns.',
            style: _bodyStyle,
          ),
          const SizedBox(height: 12),
          Text(
            'This Privacy Policy explains what information StreetSync may collect, why it is collected, and how it is handled when you use the application.',
            style: _bodyStyle,
          ),
          const SizedBox(height: 28),
          for (final section in _sections) ...[
            _section(section),
            const SizedBox(height: 28),
          ],
          Text(
            'StreetSync is a civic technology project developed to make reporting local infrastructure issues simpler and more accessible.',
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.5,
              color: _muted,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  TextStyle get _bodyStyle => GoogleFonts.inter(
        fontSize: 15,
        height: 1.55,
        color: _ink,
        fontWeight: FontWeight.w400,
      );

  Widget _section(_PolicySection section) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          section.title,
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: _ink,
            letterSpacing: -0.2,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 10),
        if (section.body != null) ...[
          Text(section.body!, style: _bodyStyle),
          const SizedBox(height: 10),
        ],
        if (section.paragraphs != null)
          for (final paragraph in section.paragraphs!) ...[
            Text(paragraph, style: _bodyStyle),
            const SizedBox(height: 10),
          ],
        if (section.bullets != null)
          for (final bullet in section.bullets!) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${bullet.label}. ',
                      style: _bodyStyle.copyWith(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(text: bullet.text, style: _bodyStyle),
                  ],
                ),
              ),
            ),
          ],
        if (section.items != null)
          for (final item in section.items!) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8, right: 10),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: _ink,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Expanded(child: Text(item, style: _bodyStyle)),
                ],
              ),
            ),
          ],
        if (section.footer != null) ...[
          const SizedBox(height: 4),
          Text(section.footer!, style: _bodyStyle),
        ],
      ],
    );
  }
}

class _PolicySection {
  const _PolicySection({
    required this.title,
    this.body,
    this.paragraphs,
    this.bullets,
    this.items,
    this.footer,
  });

  final String title;
  final String? body;
  final List<String>? paragraphs;
  final List<_PolicyBullet>? bullets;
  final List<String>? items;
  final String? footer;
}

class _PolicyBullet {
  const _PolicyBullet({required this.label, required this.text});

  final String label;
  final String text;
}
