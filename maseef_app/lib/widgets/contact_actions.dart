import 'package:flutter/material.dart';
import 'package:maseef_app/l10n/app_strings.dart';
import 'package:maseef_app/l10n/locale_scope.dart';
import 'package:maseef_app/models/listing.dart';
import 'package:maseef_app/widgets/social_icon_button.dart';

/// How the contact buttons are arranged.
enum ContactLayout {
  /// Listing cards: a row of compact brand icon buttons.
  card,

  /// Details page: every channel as a labeled button.
  labeled,
}

/// Contact buttons for a chalet. The destinations come from the listing and the
/// callbacks; this widget never builds or rewrites a link itself.
class ContactActions extends StatelessWidget {
  const ContactActions({
    super.key,
    required this.listing,
    required this.onWhatsApp,
    required this.onInstagram,
    required this.onFacebook,
    this.layout = ContactLayout.card,
    this.includeWhatsApp = true,
  });

  final Listing listing;
  final VoidCallback onWhatsApp;
  final VoidCallback onInstagram;
  final VoidCallback onFacebook;
  final ContactLayout layout;
  final bool includeWhatsApp;

  @override
  Widget build(BuildContext context) {
    final strings = LocaleScope.of(context).strings;
    return layout == ContactLayout.card ? _card(strings) : _labeled(strings);
  }

  Widget _card(AppStrings strings) {
    final instagram = listing.instagramUrl != null
        ? SocialIconButton(
            key: Key('instagram-${listing.id}'),
            platform: SocialPlatform.instagram,
            tooltip: strings.instagram,
            onPressed: onInstagram,
          )
        : null;
    final facebook = listing.facebookUrl != null
        ? SocialIconButton(
            key: Key('facebook-${listing.id}'),
            platform: SocialPlatform.facebook,
            tooltip: strings.facebook,
            onPressed: onFacebook,
          )
        : null;
    return Row(
      children: [
        if (includeWhatsApp)
          SocialIconButton(
            key: Key('whatsapp-${listing.id}'),
            platform: SocialPlatform.whatsapp,
            tooltip: strings.whatsapp,
            onPressed: onWhatsApp,
          ),
        if (instagram != null) ...[
          if (includeWhatsApp) const SizedBox(width: 10),
          instagram,
        ],
        if (facebook != null) ...[
          if (includeWhatsApp || instagram != null) const SizedBox(width: 10),
          facebook,
        ],
      ],
    );
  }

  /// Details page: every channel as a labelled button in a tidy two-column
  /// grid (WhatsApp and Facebook side by side, Instagram below when present).
  /// An odd last button spans the full width so the grid stays even.
  Widget _labeled(AppStrings strings) {
    final buttons = <Widget>[
      if (includeWhatsApp)
        SocialPillButton(
          key: Key('whatsapp-${listing.id}'),
          platform: SocialPlatform.whatsapp,
          label: strings.whatsapp,
          onPressed: onWhatsApp,
        ),
      if (listing.facebookUrl != null)
        SocialPillButton(
          key: Key('facebook-${listing.id}'),
          platform: SocialPlatform.facebook,
          label: strings.facebook,
          onPressed: onFacebook,
        ),
      if (listing.instagramUrl != null)
        SocialPillButton(
          key: Key('instagram-${listing.id}'),
          platform: SocialPlatform.instagram,
          label: strings.instagram,
          onPressed: onInstagram,
        ),
    ];
    const gap = 10.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final half = (constraints.maxWidth - gap) / 2;
        final canPair = constraints.maxWidth >= 240;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < buttons.length; i++)
              SizedBox(
                width: !canPair || (i == buttons.length - 1 && i.isEven)
                    ? constraints.maxWidth
                    : half,
                child: buttons[i],
              ),
          ],
        );
      },
    );
  }
}
