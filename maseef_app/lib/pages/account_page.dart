import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:maseef_app/auth/auth_scope.dart';
import 'package:maseef_app/l10n/locale_scope.dart';
import 'package:maseef_app/theme/maseef_theme.dart';
import 'package:maseef_app/widgets/auth_frame.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = LocaleScope.of(context).strings;
    final session = AuthScope.watch(context);
    final user = session.user;
    if (user == null) {
      return AuthFrame(
        title: strings.account,
        child: Text(strings.requestsSignInRequired),
      );
    }

    return AuthFrame(
      title: strings.account,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(user.fullName, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            user.email,
            key: const Key('account-email'),
            textDirection: TextDirection.ltr,
          ),
          if (user.phone != null) ...[
            const SizedBox(height: 6),
            Text(
              user.phone!,
              key: const Key('account-phone'),
              textDirection: TextDirection.ltr,
            ),
          ],
          const SizedBox(height: 8),
          Text(
            strings.roleName(user.role),
            key: const Key('account-role'),
            style: const TextStyle(
              color: MaseefColors.deep,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (user.isOwner) ...[
            const SizedBox(height: 12),
            Text(
              strings.registerOwnerNote,
              key: const Key('account-owner-note'),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            strings.accountBookingClosed,
            key: const Key('account-booking-closed'),
          ),
          if (kIsWeb) ...[
            const SizedBox(height: 12),
            Text(strings.webSessionNote, key: const Key('web-session-note')),
          ],
          if (session.persistenceFailed) ...[
            const SizedBox(height: 12),
            Text(
              strings.sessionNotSaved,
              key: const Key('session-not-saved'),
              style: const TextStyle(color: Color(0xFF8C2F2F), height: 1.45),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton(
            key: const Key('account-logout'),
            onPressed: () async {
              await session.logout();
              if (!context.mounted) return;
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: Text(strings.logout),
          ),
        ],
      ),
    );
  }
}
