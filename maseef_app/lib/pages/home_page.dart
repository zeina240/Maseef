import 'package:flutter/material.dart';
import 'package:maseef_app/auth/auth_scope.dart';
import 'package:maseef_app/auth/auth_session.dart';
import 'package:maseef_app/booking/booking_client.dart';
import 'package:maseef_app/data/real_listings.dart';
import 'package:maseef_app/l10n/app_strings.dart';
import 'package:maseef_app/l10n/locale_scope.dart';
import 'package:maseef_app/models/listing.dart';
import 'package:maseef_app/pages/account_page.dart';
import 'package:maseef_app/pages/listing_details_page.dart';
import 'package:maseef_app/pages/login_page.dart';
import 'package:maseef_app/theme/maseef_theme.dart';
import 'package:maseef_app/widgets/brand_mark.dart';
import 'package:maseef_app/widgets/language_switcher.dart';
import 'package:maseef_app/widgets/listing_card.dart';
import 'package:url_launcher/url_launcher.dart';

const _homeImage = 'assets/images/home.png';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.source = const ListingSource(),
    this.openLink,
    this.bookingClient,
  });

  final ListingSource source;
  final Future<void> Function(Uri uri)? openLink;
  final BookingClient? bookingClient;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final _listingsKey = GlobalKey();
  late final BookingClient _bookingClient;
  List<Listing> _listings = const [];
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _bookingClient =
        widget.bookingClient ??
        ApiBookingClient(session: AuthScope.read(context));
    Future<void>.microtask(_load);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _failed = false;
      });
    }
    try {
      final listings = await widget.source.load();
      if (!mounted) return;
      setState(() {
        _listings = listings;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  List<Listing> get _visible {
    return _listings
        .where((listing) => listing.matchesQuery(_searchController.text))
        .toList();
  }

  Future<void> _open(Uri uri) async {
    final opener = widget.openLink;
    if (opener != null) {
      await opener(uri);
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      final strings = LocaleScope.of(context).strings;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.linkError)));
    }
  }

  void _openDetails(Listing listing) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ListingDetailsPage(
          listing: listing,
          onOpenLink: _open,
          bookingClient: _bookingClient,
        ),
      ),
    );
  }

  void _scrollToListings() {
    final target = _listingsKey.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      alignment: 0.02,
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = LocaleScope.of(context).strings;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final padding = width >= 720 ? 32.0 : 20.0;
            final columns = width >= 1100 ? 3 : (width >= 740 ? 2 : 1);
            final wideSearch = width >= 700;
            return CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverToBoxAdapter(child: _header(strings, padding, width)),
                SliverToBoxAdapter(
                  child: _hero(strings, width, padding, wideSearch),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 56)),
                ..._listingBand(strings, padding, columns),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _frame(double padding, Widget child) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: padding),
          child: child,
        ),
      ),
    );
  }

  Widget _mist(Widget child) {
    return ColoredBox(color: MaseefColors.mist, child: child);
  }

  void _openAccount() {
    final session = AuthScope.read(context);
    if (session == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            session.isSignedIn ? const AccountPage() : const LoginPage(),
      ),
    );
  }

  Widget _accountButton(AppStrings strings, AuthSession session, bool narrow) {
    final label = session.isSignedIn ? strings.account : strings.signIn;
    if (narrow) {
      return IconButton(
        key: const Key('account-button'),
        tooltip: label,
        onPressed: _openAccount,
        icon: Icon(session.isSignedIn ? Icons.person_outline : Icons.login),
      );
    }
    return TextButton(
      key: const Key('account-button'),
      onPressed: _openAccount,
      child: Text(label),
    );
  }

  Widget _header(AppStrings strings, double padding, double width) {
    final session = AuthScope.watch(context);
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: MaseefColors.line)),
      ),
      child: _frame(
        padding,
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              const BrandMark(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.brand,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                        color: MaseefColors.deep,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        height: 1,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      strings.tagline,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MaseefColors.muted,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _accountButton(strings, session, width < 720),
              const SizedBox(width: 8),
              const LanguageSwitcher(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hero(
    AppStrings strings,
    double width,
    double padding,
    bool wideSearch,
  ) {
    final inset = _contentInset(width, padding);
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: width >= 900 ? 560 : 500),
      child: Stack(
        alignment: AlignmentDirectional.bottomStart,
        children: [
          Positioned.fill(
            child: Image.asset(
              _homeImage,
              key: const Key('home-hero-image'),
              fit: BoxFit.cover,
              alignment: Alignment.center,
              filterQuality: FilterQuality.medium,
              excludeFromSemantics: true,
              errorBuilder: (context, error, stackTrace) {
                return const ColoredBox(color: MaseefColors.deep);
              },
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x14123A68),
                    Color(0x00123A68),
                    Color(0x99123A68),
                    Color(0xF2123A68),
                  ],
                  stops: [0, 0.38, 0.7, 1],
                ),
              ),
            ),
          ),
          if (width >= 900)
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: AlignmentDirectional.centerStart,
                    end: AlignmentDirectional.centerEnd,
                    colors: [
                      Color(0xC4123A68),
                      Color(0x55123A68),
                      Color(0x00123A68),
                    ],
                    stops: [0, 0.32, 0.58],
                  ),
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              inset,
              28,
              inset,
              width >= 900 ? 40 : 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.headline,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: width >= 900 ? 48 : 34,
                      height: 1.12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    strings.supporting,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.94),
                      fontSize: width >= 900 ? 18 : 16,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 22),
                  wideSearch
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(child: _searchField(strings)),
                            const SizedBox(width: 12),
                            _searchButton(strings, expand: false),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _searchField(strings),
                            const SizedBox(height: 12),
                            _searchButton(strings, expand: true),
                          ],
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchField(AppStrings strings) {
    return TextField(
      key: const Key('search-field'),
      controller: _searchController,
      onChanged: (_) => setState(() {}),
      onSubmitted: (_) => _scrollToListings(),
      textInputAction: TextInputAction.search,
      style: const TextStyle(color: MaseefColors.ink, fontSize: 16),
      decoration: InputDecoration(
        hintText: strings.searchHint,
        prefixIcon: const Icon(Icons.search, color: MaseefColors.deep),
      ),
    );
  }

  Widget _searchButton(AppStrings strings, {required bool expand}) {
    final button = FilledButton(
      key: const Key('search-button'),
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: MaseefColors.deep,
        minimumSize: const Size(132, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      onPressed: _scrollToListings,
      child: Text(strings.search),
    );
    if (!expand) return button;
    return SizedBox(width: double.infinity, height: 56, child: button);
  }

  List<Widget> _listingBand(AppStrings strings, double padding, int columns) {
    return [
      SliverToBoxAdapter(
        child: _mist(
          _frame(
            padding,
            Padding(
              key: _listingsKey,
              padding: const EdgeInsets.only(top: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.listingsTitle,
                    style: const TextStyle(
                      color: MaseefColors.deep,
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    strings.listingsSubtitle,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
      ..._results(strings, padding, columns),
      SliverToBoxAdapter(child: _mist(_footer(strings))),
    ];
  }

  List<Widget> _results(AppStrings strings, double padding, int columns) {
    if (_loading) {
      return [
        SliverToBoxAdapter(
          child: _mist(
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(key: Key('listings-loading')),
                  ],
                ),
              ),
            ),
          ),
        ),
      ];
    }

    if (_failed) {
      return [
        SliverToBoxAdapter(
          child: _mist(
            _Status(
              key: const Key('listings-error'),
              title: strings.loadErrorTitle,
              message: strings.loadError,
              action: FilledButton(
                onPressed: _load,
                child: Text(strings.retry),
              ),
            ),
          ),
        ),
      ];
    }

    final visible = _visible;
    if (visible.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: _mist(
            _Status(
              key: const Key('listings-empty'),
              title: strings.emptyTitle,
              message: strings.emptyMessage,
            ),
          ),
        ),
      ];
    }

    final rowCount = (visible.length / columns).ceil();
    return [
      SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          return _mist(
            _frame(
              padding,
              Padding(
                padding: EdgeInsets.only(top: index == 0 ? 16 : 0, bottom: 24),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var column = 0; column < columns; column++) ...[
                        if (column > 0) const SizedBox(width: 20),
                        Expanded(
                          child: index * columns + column < visible.length
                              ? ListingCard(
                                  key: Key(
                                    visible[index * columns + column].id,
                                  ),
                                  listing: visible[index * columns + column],
                                  onOpen: () => _openDetails(
                                    visible[index * columns + column],
                                  ),
                                  onWhatsApp: () => _open(
                                    whatsAppUri(
                                      visible[index * columns + column]
                                          .whatsapp,
                                    ),
                                  ),
                                  onInstagram: () {
                                    final url =
                                        visible[index * columns + column]
                                            .instagramUrl;
                                    if (url != null) _open(Uri.parse(url));
                                  },
                                  onFacebook: () {
                                    final url =
                                        visible[index * columns + column]
                                            .facebookUrl;
                                    if (url != null) _open(Uri.parse(url));
                                  },
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        }, childCount: rowCount),
      ),
    ];
  }

  Widget _footer(AppStrings strings) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 28, 20, 28 + bottom),
      child: Column(
        children: [
          Text(
            strings.brand,
            textDirection: TextDirection.ltr,
            style: const TextStyle(
              color: MaseefColors.deep,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            strings.supporting,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: MaseefColors.muted,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

double _contentInset(double width, double padding) {
  final centered = (width - 1120) / 2 + padding;
  return centered > padding ? centered : padding;
}

class _Status extends StatelessWidget {
  const _Status({
    super.key,
    required this.title,
    required this.message,
    this.action,
  });

  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 48),
      child: Column(
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}
