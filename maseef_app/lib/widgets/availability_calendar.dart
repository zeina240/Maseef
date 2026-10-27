import 'package:flutter/material.dart';
import 'package:maseef_app/booking/booking_client.dart';
import 'package:maseef_app/booking/booking_models.dart';
import 'package:maseef_app/l10n/app_strings.dart';
import 'package:maseef_app/l10n/locale_scope.dart';
import 'package:maseef_app/pages/booking_requests_page.dart';
import 'package:maseef_app/theme/maseef_theme.dart';
import 'package:maseef_app/widgets/detail_section.dart';

class AvailabilitySection extends StatefulWidget {
  const AvailabilitySection({
    super.key,
    required this.listingKey,
    required this.client,
    this.initialMonth,
  });

  final String listingKey;
  final BookingClient client;
  final DateTime? initialMonth;

  @override
  State<AvailabilitySection> createState() => _AvailabilitySectionState();
}

class _AvailabilitySectionState extends State<AvailabilitySection> {
  late DateTime _month;
  AvailabilitySnapshot? _snapshot;
  bool _loading = true;
  bool _failed = false;
  DateTime? _selected;
  BookingMode? _mode;
  BookingBlockReason? _blockReason;
  CustomerBookingRequest? _submitted;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialMonth ?? DateTime.now();
    _month = DateTime(initial.year, initial.month);
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final snapshot = await widget.client.loadMonth(
        listingKey: widget.listingKey,
        year: _month.year,
        month: _month.month,
      );
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
        _selected = null;
        _mode = null;
        _blockReason = null;
        _submitted = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
        _snapshot = null;
      });
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
    });
    _load();
  }

  Future<void> _submit() async {
    final selected = _selected;
    final mode = _mode;
    if (selected == null || mode == null) return;
    final day = _snapshot?.dayOn(selected);
    final offer = day?.modes[mode];
    if (offer == null || offer.status != ModeAvailability.available) return;
    try {
      final request = await widget.client.submitRequest(
        BookingDraft(
          listingKey: widget.listingKey,
          stayDate: day!.isoDate,
          mode: mode,
        ),
      );
      if (!mounted) return;
      setState(() {
        _submitted = request;
        _blockReason = null;
      });
    } on BookingAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _submitted = null;
        _blockReason = error.reason;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = LocaleScope.of(context).strings;
    return DetailSection(
      key: const Key('availability-section'),
      title: strings.availabilityTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_loading)
            _StatusRow(
              key: const Key('availability-loading'),
              label: strings.availabilityLoading,
              busy: true,
            )
          else if (_failed)
            _ErrorState(onRetry: _load)
          else if (_snapshot == null || !_snapshot!.configured)
            _NotProvided(onRequests: () => _openRequests(context))
          else
            _CalendarBody(
              month: _month,
              snapshot: _snapshot!,
              selected: _selected,
              mode: _mode,
              notice: _blockReason == null
                  ? null
                  : _blockReason == BookingBlockReason.storageNotApproved
                  ? strings.bookingStorageClosed
                  : strings.bookingAuthRequired,
              submitted: _submitted,
              onPrevious: () => _changeMonth(-1),
              onNext: () => _changeMonth(1),
              onSelect: (day) {
                setState(() {
                  _selected = day.date;
                  _mode = _firstOpenMode(day);
                  _blockReason = null;
                  _submitted = null;
                });
              },
              onMode: (mode) {
                setState(() {
                  _mode = mode;
                  _blockReason = null;
                  _submitted = null;
                });
              },
              onSubmit: _submit,
              onRequests: () => _openRequests(context),
            ),
        ],
      ),
    );
  }

  void _openRequests(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => BookingRequestsPage(client: widget.client),
      ),
    );
  }

  BookingMode? _firstOpenMode(CalendarDay day) {
    for (final mode in BookingMode.values) {
      final offer = day.modes[mode];
      if (offer != null && offer.status == ModeAvailability.available) {
        return mode;
      }
    }
    return null;
  }
}

class _NotProvided extends StatelessWidget {
  const _NotProvided({required this.onRequests});

  final VoidCallback onRequests;

  @override
  Widget build(BuildContext context) {
    final strings = LocaleScope.of(context).strings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.availabilityNotProvided,
          key: const Key('availability-not-provided'),
          style: const TextStyle(
            color: MaseefColors.ink,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          strings.availabilityNextStep,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 12),
        _RequestsButton(onPressed: onRequests),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final strings = LocaleScope.of(context).strings;
    return Column(
      key: const Key('availability-error'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.availabilityError,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: onRetry, child: Text(strings.retry)),
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({super.key, required this.label, required this.busy});

  final String label;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (busy) ...[
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
        ],
        Flexible(child: Text(label)),
      ],
    );
  }
}

class _CalendarBody extends StatelessWidget {
  const _CalendarBody({
    required this.month,
    required this.snapshot,
    required this.selected,
    required this.mode,
    required this.notice,
    required this.submitted,
    required this.onPrevious,
    required this.onNext,
    required this.onSelect,
    required this.onMode,
    required this.onSubmit,
    required this.onRequests,
  });

  final DateTime month;
  final AvailabilitySnapshot snapshot;
  final DateTime? selected;
  final BookingMode? mode;
  final String? notice;
  final CustomerBookingRequest? submitted;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<CalendarDay> onSelect;
  final ValueChanged<BookingMode> onMode;
  final VoidCallback onSubmit;
  final VoidCallback onRequests;

  @override
  Widget build(BuildContext context) {
    final strings = LocaleScope.of(context).strings;
    final first = DateTime(month.year, month.month, 1);
    final days = DateTime(month.year, month.month + 1, 0).day;
    final leading = (first.weekday + 1) % 7;
    final selectedDay = selected == null ? null : snapshot.dayOn(selected!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              key: const Key('previous-month'),
              tooltip: strings.previousMonth,
              onPressed: onPrevious,
              icon: Icon(_backIcon(context)),
            ),
            Expanded(
              child: Text(
                strings.monthYear(month.year, month.month),
                key: const Key('calendar-month'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: MaseefColors.deep,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ),
            IconButton(
              key: const Key('next-month'),
              tooltip: strings.nextMonth,
              onPressed: onNext,
              icon: Icon(_forwardIcon(context)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _Legend(strings: strings),
        const SizedBox(height: 12),
        if (!snapshot.hasOpenDate)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              strings.noOpenDates,
              key: const Key('no-open-dates'),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        Row(
          children: [
            for (final label in strings.weekdayLabels)
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: MaseefColors.muted,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        // Wide sections use shorter, wider cells so the month does not become
        // a very tall block of oversized squares.
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 520;
            return GridView.builder(
              key: const Key('calendar-grid'),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: leading + days,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: wide ? 1.7 : 1,
              ),
              itemBuilder: (context, index) {
                if (index < leading) return const SizedBox.shrink();
                final date = DateTime(
                  month.year,
                  month.month,
                  index - leading + 1,
                );
                final day =
                    snapshot.dayOn(date) ??
                    CalendarDay(
                      date: date,
                      state: DayState.unavailable,
                      modes: const {},
                    );
                final isSelected =
                    selected != null &&
                    selected!.year == date.year &&
                    selected!.month == date.month &&
                    selected!.day == date.day;
                return _DayCell(
                  day: day,
                  selected: isSelected,
                  onSelect:
                      day.state == DayState.available ||
                          day.state == DayState.partial
                      ? () => onSelect(day)
                      : null,
                );
              },
            );
          },
        ),
        if (selectedDay != null) ...[
          const SizedBox(height: 16),
          Text(
            _stateLabel(strings, selectedDay.state),
            key: const Key('selected-day-status'),
            style: const TextStyle(
              color: MaseefColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final offer in selectedDay.modes.values)
                _ModeChoice(
                  offer: offer,
                  selected: mode == offer.mode,
                  onSelected: offer.status == ModeAvailability.available
                      ? () => onMode(offer.mode)
                      : null,
                ),
            ],
          ),
        ],
        if (notice != null) ...[
          const SizedBox(height: 12),
          Text(
            notice!,
            key: const Key('booking-auth-required'),
            style: const TextStyle(color: Color(0xFF8C2F2F), height: 1.5),
          ),
        ],
        if (submitted != null) ...[
          const SizedBox(height: 12),
          Text(
            strings.bookingReceived,
            key: const Key('booking-pending-confirmation'),
            style: const TextStyle(color: MaseefColors.ink, height: 1.5),
          ),
          const SizedBox(height: 4),
          Text(
            strings.bookingReference(submitted!.reference),
            key: const Key('booking-reference'),
            style: const TextStyle(
              color: MaseefColors.deep,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton(
              key: const Key('submit-booking-request'),
              onPressed:
                  selectedDay != null &&
                      mode != null &&
                      selectedDay.modes[mode]?.status ==
                          ModeAvailability.available
                  ? onSubmit
                  : null,
              child: Text(strings.requestBooking),
            ),
            _RequestsButton(onPressed: onRequests),
          ],
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _LegendItem(
          Key('legend-available'),
          _swatch(DayState.available),
          strings.stateAvailable,
        ),
        _LegendItem(
          Key('legend-pending'),
          _swatch(DayState.pending),
          strings.statePending,
        ),
        _LegendItem(
          Key('legend-booked'),
          _swatch(DayState.booked),
          strings.stateBooked,
        ),
        _LegendItem(
          Key('legend-partial'),
          _swatch(DayState.partial),
          strings.statePartial,
        ),
        _LegendItem(
          Key('legend-unavailable'),
          _swatch(DayState.unavailable),
          strings.stateUnavailable,
        ),
        _LegendItem(
          Key('legend-closed'),
          _swatch(DayState.closed),
          strings.stateClosed,
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem(this.itemKey, this.color, this.label);

  final Key itemKey;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: itemKey,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: MaseefColors.line),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: MaseefColors.ink, fontSize: 13),
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.selected,
    required this.onSelect,
  });

  final CalendarDay day;
  final bool selected;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final strings = LocaleScope.of(context).strings;
    final background = _swatch(day.state);
    final foreground = day.state == DayState.booked
        ? Colors.white
        : MaseefColors.ink;
    return Semantics(
      button: onSelect != null,
      selected: selected,
      enabled: onSelect != null,
      label: '${day.date.day}, ${_stateLabel(strings, day.state)}',
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: selected ? MaseefColors.deep : MaseefColors.line,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          key: Key('day-${day.isoDate}'),
          onTap: onSelect,
          child: Center(
            child: Text(
              '${day.date.day}',
              style: TextStyle(color: foreground, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeChoice extends StatelessWidget {
  const _ModeChoice({
    required this.offer,
    required this.selected,
    required this.onSelected,
  });

  final ModeOffer offer;
  final bool selected;
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) {
    final strings = LocaleScope.of(context).strings;
    final enabled = onSelected != null;
    final label = StringBuffer(_modeLabel(strings, offer.mode))
      ..write(' ')
      ..write(offer.start)
      ..write('–')
      ..write(offer.end)
      ..write(' · ')
      ..write(_modeState(strings, offer.status));
    if (offer.price != null) {
      label
        ..write(' · ')
        ..write(strings.hostPrice(_formatPrice(offer.price!)));
    }
    final maxWidth = MediaQuery.sizeOf(context).width - 72;
    return ChoiceChip(
      key: Key('mode-${bookingModeToJson(offer.mode)}'),
      label: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth < 120 ? 120 : maxWidth),
        child: Text(label.toString()),
      ),
      selected: selected,
      onSelected: enabled ? (_) => onSelected!() : null,
    );
  }
}

class _RequestsButton extends StatelessWidget {
  const _RequestsButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      key: const Key('view-booking-requests'),
      onPressed: onPressed,
      child: Text(LocaleScope.of(context).strings.viewBookingRequests),
    );
  }
}

String _stateLabel(AppStrings strings, DayState state) {
  switch (state) {
    case DayState.available:
      return strings.stateAvailable;
    case DayState.pending:
      return strings.statePending;
    case DayState.booked:
      return strings.stateBooked;
    case DayState.unavailable:
      return strings.stateUnavailable;
    case DayState.closed:
      return strings.stateClosed;
    case DayState.partial:
      return strings.statePartial;
  }
}

String _modeLabel(AppStrings strings, BookingMode mode) {
  switch (mode) {
    case BookingMode.fullDay:
      return strings.modeFullDay;
    case BookingMode.morning:
      return strings.modeMorning;
    case BookingMode.evening:
      return strings.modeEvening;
  }
}

String _modeState(AppStrings strings, ModeAvailability status) {
  switch (status) {
    case ModeAvailability.available:
      return strings.stateAvailable;
    case ModeAvailability.pending:
      return strings.statePending;
    case ModeAvailability.booked:
      return strings.stateBooked;
  }
}

String _formatPrice(double price) {
  if (price == price.roundToDouble()) return price.toStringAsFixed(0);
  return price.toStringAsFixed(2);
}

Color _swatch(DayState state) {
  switch (state) {
    case DayState.available:
      return Colors.white;
    case DayState.pending:
      return MaseefColors.goldSoft;
    case DayState.booked:
      return MaseefColors.deep;
    case DayState.unavailable:
      return const Color(0xFFEEF3F6);
    case DayState.closed:
      return const Color(0xFFD9E3EA);
    case DayState.partial:
      return const Color(0xFFCFE4F2);
  }
}

IconData _backIcon(BuildContext context) {
  return Directionality.of(context) == TextDirection.rtl
      ? Icons.chevron_right
      : Icons.chevron_left;
}

IconData _forwardIcon(BuildContext context) {
  return Directionality.of(context) == TextDirection.rtl
      ? Icons.chevron_left
      : Icons.chevron_right;
}
