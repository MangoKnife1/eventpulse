import 'package:flutter/material.dart';

class LegalDocumentsView extends StatelessWidget {
  const LegalDocumentsView({super.key});

  static const _lastUpdated = 'October 2, 2026';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final mutedColor =
        isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & Terms')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text('EventPulse legal information',
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w800, color: textColor)),
          const SizedBox(height: 6),
          Text('Last updated: $_lastUpdated',
              style: TextStyle(fontSize: 12, color: mutedColor)),
          const SizedBox(height: 20),
          _notice(
            context,
            icon: Icons.info_outline,
            title: 'Please read before using the app',
            body:
                'EventPulse is an academic demonstration. Use test details only and do not submit sensitive personal information. A full name and email address are personal information, but are generally not sensitive personal information by themselves under Philippine law. Do not enter government ID numbers, financial details, health information, passwords from another service, biometric data, religious or political affiliations, or other sensitive details. This page is a practical demo notice, not legal advice.',
          ),
          const SizedBox(height: 20),
          _section(context, '1. Privacy Notice', [
            _paragraph(
                'EventPulse respects your privacy and handles personal data in accordance with Republic Act No. 10173, the Philippine Data Privacy Act of 2012, its Implementing Rules and Regulations, and applicable issuances of the National Privacy Commission (NPC).'),
            _heading('Information we may collect'),
            _paragraph(
                'Depending on the features you use, we may collect your name, email address, profile photo, account and role details, event registrations, ticket or QR pass information, organizer application details, device or diagnostic information, and information you send to support. Organizer applications ask for a full name, email address, organization or company name, and optional event mission or topics. Event creation asks for event title, venue name, street address, capacity, description, category, tags, date and time, and an optional event image. Camera access is used for QR scanning when you choose to use the scanner; camera images are not collected by this app merely because permission is granted.'),
            _heading('Why we use it'),
            _paragraph(
                'We use information to create and secure accounts, display event listings, issue and validate passes, process organizer applications, operate QR check-in, send service notifications, prevent fraud or misuse, improve reliability, and comply with legal obligations. We only request permissions needed for the feature you choose to use.'),
            _heading('Legal bases and consent'),
            _paragraph(
                'Processing may be based on your consent, the performance of a service you request, compliance with a legal obligation, or a legitimate interest that does not override your rights. Where consent is required, you may withdraw it at any time, although this will not affect processing already completed lawfully and may limit a feature that depends on it.'),
            _heading('Sharing and service providers'),
            _paragraph(
                'We may share the minimum information needed with event organizers for events you join, Firebase for authentication and database services, Cloudinary for profile-image storage where enabled, and other contracted providers that help operate the app. We do not sell personal data. Providers must handle information under appropriate contractual, organizational, and security safeguards.'),
            _heading('Retention and security'),
            _paragraph(
                'We retain information only for as long as reasonably necessary for the purposes above, legitimate business records, dispute handling, and legal requirements. We use access controls and technical and organizational safeguards, but no online service can guarantee absolute security. Report suspected unauthorized access promptly using the contact details below.'),
            _heading('Your rights under Philippine law'),
            _paragraph(
                'Subject to the conditions and exceptions under the Data Privacy Act, you may be entitled to be informed, access your personal data, object to or withdraw consent, request correction, request blocking or removal, obtain data portability, and seek damages or file a complaint. Contact the app owner first so we can verify and address your request. You may also contact the NPC through its official channels at privacy.gov.ph.'),
            _heading('Children'),
            _paragraph(
                'The service is not directed to children who cannot validly consent under applicable law. If a parent or guardian believes a child provided personal data without appropriate authority, please contact us so we can review and take suitable action.'),
            _heading('Privacy contact'),
            _paragraph(
                'Data controller / app owner: EventPulse academic project\nBusiness address: None; this is an academic demonstration and not a registered business\nPrivacy contact or Data Protection Officer: millaxymonn@gmail.com\nResponse target: We aim to acknowledge privacy requests promptly and respond within the period required by applicable law.'),
          ]),
          const SizedBox(height: 20),
          _section(context, '2. Terms and Conditions', [
            _paragraph(
                'By creating an account or using EventPulse, you agree to these Terms. If you do not agree, do not use the service. The app owner may update these Terms when reasonably necessary; the current version and update date will be shown in this screen.'),
            _heading('The service'),
            _paragraph(
                'EventPulse helps people discover events, register, manage event listings, and use QR-based check-in. EventPulse does not guarantee that an event will occur, that an organizer will perform as described, or that an event listing is suitable for every user. Confirm important details directly with the organizer.'),
            _heading('Accounts and acceptable use'),
            _paragraph(
                'Provide accurate information, protect your login credentials, and use only accounts you are authorized to use. Do not impersonate others, submit misleading listings, misuse QR passes, scrape or attack the service, bypass security, upload unlawful or infringing content, harass others, or use the app for fraud or unauthorized commercial activity.'),
            _heading('Tickets, events, and organizers'),
            _paragraph(
                'An organizer is responsible for the accuracy, legality, safety, accessibility, changes, cancellations, refunds, and delivery of its event. Any payment, refund, venue, or attendance dispute should first be raised with the relevant organizer unless the app owner expressly states otherwise.'),
            _heading('Content and intellectual property'),
            _paragraph(
                'You keep rights in content you submit, but grant EventPulse a limited license to host, display, process, and distribute it as needed to operate the service. EventPulse and its branding, software, and interface are protected by applicable intellectual-property laws. Do not copy, modify, or redistribute them without permission.'),
            _heading('Suspension and termination'),
            _paragraph(
                'We may suspend or terminate access when necessary to protect users, investigate misuse, comply with law, or address a material breach. You may stop using the service at any time. Provisions that should reasonably survive termination, including privacy, intellectual property, liability, and dispute provisions, will continue.'),
            _heading('Disclaimers and liability'),
            _paragraph(
                'To the extent permitted by Philippine law, the service is provided on an as-available basis. Nothing in these Terms removes rights or remedies that cannot legally be waived, including rights under consumer-protection and data-privacy laws. The app owner is not responsible for an organizer’s independent acts, event changes, or information outside its reasonable control.'),
            _heading('Governing law and contact'),
            _paragraph(
                'These Terms are governed by the laws of the Republic of the Philippines. The parties will try to resolve concerns in good faith before pursuing remedies available under Philippine law. Legal notices and support requests should be sent to millaxymonn@gmail.com. This academic project does not have a business address.'),
          ]),
          const SizedBox(height: 20),
          Text(
              'By continuing to use EventPulse, you confirm that you have had an opportunity to read this Privacy Notice and these Terms.',
              style: TextStyle(fontSize: 12, color: mutedColor)),
        ],
      ),
    );
  }

  Widget _notice(BuildContext context,
      {required IconData icon, required String title, required String body}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: scheme.primary),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(fontSize: 13, height: 1.45)),
        ])),
      ]),
    );
  }

  Widget _section(BuildContext context, String title, List<Widget> children) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        ...children,
      ]),
    );
  }

  Widget _heading(String text) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 4),
        child: Text(text,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
      );

  Widget _paragraph(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text, style: const TextStyle(fontSize: 13, height: 1.5)),
      );
}
