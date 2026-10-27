import 'package:flutter/material.dart';
import 'package:maseef_app/booking/booking_client.dart';
import 'package:maseef_app/booking/booking_models.dart';
import 'package:maseef_app/l10n/locale_scope.dart';
import 'package:maseef_app/theme/maseef_theme.dart';
import 'package:maseef_app/widgets/language_switcher.dart';

class BookingRequestsPage extends StatefulWidget {
  const BookingRequestsPage({super.key, required this.client});

  final BookingClient client;

  @override
  State<BookingRequestsPage> createState() => _BookingRequestsPageState();
}

class _BookingRequestsPageState extends State<BookingRequestsPage> {
  bool _loading = true;
  BookingBlockReason? _blockReason;
  bool _failed = false;
  List<CustomerBookingRequest> _requests = const [];

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
      _blockReason = null;
    });
    try {
      final requests = await widget.client.loadMyRequests();
      if (!mounted) return;
      setState(() {
        _requests = requests;
        _loading = false;
      });
    } on BookingAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _blockReason = error.reason;
        _requests = const [];
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = LocaleScope.of(context).strings;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(strings.requestsTitle),
        actions: const [
          Padding(
            padding: EdgeInsetsDirectional.only(end: 12),
            child: LanguageSwitcher(),
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              if (_loading)
                Text(
                  strings.availabilityLoading,
                  key: const Key('requests-loading'),
                )
              else if (_blockReason != null)
                Text(
                  _blockReason == BookingBlockReason.storageNotApproved
                      ? strings.requestsStorageClosed
                      : strings.requestsAuthRequired,
                  key: const Key('requests-auth-required'),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: MaseefColors.ink),
                )
              else if (_failed)
                Column(
                  key: const Key('requests-error'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(strings.availabilityError),
                    TextButton(onPressed: _load, child: Text(strings.retry)),
                  ],
                )
              else if (_requests.isEmpty)
                Text(
                  strings.requestsEmpty,
                  key: const Key('requests-empty'),
                  style: Theme.of(context).textTheme.bodyLarge,
                )
              else
                for (final request in _requests) _RequestTile(request: request),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({required this.request});

  final CustomerBookingRequest request;

  @override
  Widget build(BuildContext context) {
    final strings = LocaleScope.of(context).strings;
    final status = switch (request.status) {
      'confirmed' => strings.stateBooked,
      'rejected' => strings.stateRejected,
      'cancelled' => strings.stateCancelled,
      _ => strings.statePending,
    };
    return Container(
      key: Key('request-${request.reference}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MaseefColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.bookingReference(request.reference),
            style: const TextStyle(
              color: MaseefColors.deep,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(request.stayDate, textDirection: TextDirection.ltr),
          const SizedBox(height: 6),
          Text(
            status,
            key: Key('request-status-${request.reference}'),
            style: const TextStyle(
              color: MaseefColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (request.status == 'pending') ...[
            const SizedBox(height: 6),
            Text(strings.bookingReceived),
          ],
        ],
      ),
    );
  }
}
