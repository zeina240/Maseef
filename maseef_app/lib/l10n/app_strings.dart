import 'package:maseef_app/l10n/place_names.dart';

enum AppLanguage { english, arabic }

class AppStrings {
  const AppStrings(this.language);

  final AppLanguage language;

  bool get isArabic => language == AppLanguage.arabic;

  static AppStrings of(AppLanguage language) => AppStrings(language);

  String get brand => 'MASEEF';

  String get tagline => isArabic
      ? 'شاليهات وإقامات سياحية في فلسطين'
      : 'Chalets and vacation stays in Palestine';

  String get headline =>
      isArabic ? 'اعثر على إجازتك المثالية' : 'Find Your Perfect Getaway';

  String get supporting => isArabic
      ? 'اكتشف شاليهات جميلة وأماكن استرخاء في مختلف أنحاء فلسطين.'
      : 'Discover beautiful chalets and relaxing escapes across Palestine.';

  String get search => isArabic ? 'بحث' : 'Search';

  String get searchHint => isArabic
      ? 'الاسم أو المحافظة أو البلدة'
      : 'Name, governorate, or locality';

  String get listingsTitle => isArabic ? 'الشاليهات' : 'Chalets';

  String get listingsSubtitle => isArabic
      ? 'تصفّح الإقامات وتواصل مع المضيف مباشرة.'
      : 'Browse stays and contact the host directly.';

  String get contactForPrice =>
      isArabic ? 'تواصل لمعرفة السعر' : 'Contact for price';

  String get whatsapp => isArabic ? 'واتساب' : 'WhatsApp';

  String get instagram => isArabic ? 'إنستغرام' : 'Instagram';

  String get facebook => isArabic ? 'فيسبوك' : 'Facebook';

  String get detailsTitle => isArabic ? 'تفاصيل الشاليه' : 'Chalet details';

  String get back => isArabic ? 'رجوع' : 'Back';

  String get backToStays => isArabic ? 'العودة إلى الإقامات' : 'Back to stays';

  String get governorate => isArabic ? 'المحافظة' : 'Governorate';

  String get locality => isArabic ? 'البلدة' : 'Locality';

  String get contact => isArabic ? 'التواصل' : 'Contact';

  String get houseRules => isArabic ? 'قواعد المنزل' : 'House rules';

  String get houseRulesNotProvided => isArabic
      ? 'لم يزوّد المالك قواعد المنزل بعد.'
      : 'House rules have not been provided yet.';

  String get loading => isArabic ? 'جارٍ تحميل الإقامات' : 'Loading stays';

  String get loadErrorTitle =>
      isArabic ? 'تعذّر تحميل الإقامات' : "Couldn't load stays";

  String get loadError => isArabic
      ? 'تعذّر تحميل الإقامات. حاول مرة أخرى.'
      : "We couldn't load the stays. Please try again.";

  String get retry => isArabic ? 'إعادة المحاولة' : 'Try again';

  String get emptyTitle => isArabic ? 'لا توجد نتائج' : 'No stays found';

  String get emptyMessage => isArabic
      ? 'جرّب اسماً أو محافظة أو بلدة أخرى.'
      : 'Try another name, governorate, or locality.';

  String get linkError => isArabic
      ? 'تعذّر فتح الرابط على هذا الجهاز.'
      : "Couldn't open this link on this device.";

  String get photoUnavailable =>
      isArabic ? 'الصورة غير متوفرة' : 'Photo not available';

  String get languageEnglish => 'English';

  String get languageArabic => 'العربية';

  String get languageShortEnglish => 'EN';

  String get languageShortArabic => 'عربي';

  String place(String canonical) =>
      displayPlaceName(canonical, arabic: isArabic);

  String locationLine(String locality, String governorate) {
    final localName = place(locality);
    final governorateName = place(governorate);
    return isArabic
        ? '$localName، $governorateName'
        : '$localName, $governorateName';
  }

  String get bedrooms => isArabic ? 'غرف النوم' : 'Bedrooms';

  String get amenities => isArabic ? 'المرافق' : 'Amenities';

  String galleryPosition(int index, int total) =>
      isArabic ? 'صورة $index من $total' : 'Photo $index of $total';

  String photoCount(int count) {
    if (!isArabic) return count == 1 ? '1 photo' : '$count photos';
    if (count == 1) return 'صورة واحدة';
    if (count == 2) return 'صورتان';
    return count <= 10 ? '$count صور' : '$count صورة';
  }

  String showAllPhotos(int count) =>
      isArabic ? 'عرض كل الصور ($count)' : 'Show all $count photos';

  String get closeViewer => isArabic ? 'إغلاق' : 'Close';

  String get previousPhoto => isArabic ? 'الصورة السابقة' : 'Previous photo';

  String get nextPhoto => isArabic ? 'الصورة التالية' : 'Next photo';

  String get priceLabel => isArabic ? 'السعر' : 'Price';

  String get contactForPriceHelp => isArabic
      ? 'راسل المضيف مباشرة للاستفسار عن السعر والتواريخ.'
      : 'Message the host directly to ask about price and dates.';

  String get onlineBookingNotOpen => isArabic
      ? 'الحجز عبر الإنترنت غير متاح بعد. تواصل مع المضيف مباشرة.'
      : 'Online booking is not open yet. Please contact the host directly.';

  String get messageOnWhatsApp =>
      isArabic ? 'راسل عبر واتساب' : 'Message on WhatsApp';

  String get socialChannels =>
      isArabic ? 'قنوات التواصل الاجتماعي' : 'Social channels';

  String get locationTitle => isArabic ? 'الموقع' : 'Location';

  String get areaLevelBadge =>
      isArabic ? 'موقع على مستوى المنطقة' : 'Area-level location';

  String get exactLocationBadge =>
      isArabic ? 'الموقع الدقيق' : 'Exact location';

  String get areaLocationNote => isArabic
      ? 'لم يزوّد المضيف العنوان الدقيق لهذا الشاليه. سيبحث خرائط Google عن المنطقة فقط، وليس عن الشاليه نفسه.'
      : "The host hasn't provided this chalet's exact address. Google Maps will search for the area only, not the chalet itself.";

  String get exactLocationNote => isArabic
      ? 'إحداثيات زوّدها المضيف.'
      : 'Coordinates provided by the host.';

  String get coordinatesLabel => isArabic ? 'الإحداثيات' : 'Coordinates';

  String get openInMaps =>
      isArabic ? 'فتح في خرائط Google' : 'Open in Google Maps';

  String get openAreaInMaps =>
      isArabic ? 'فتح المنطقة في خرائط Google' : 'Open area in Google Maps';

  String locationLinkTooltip(String area) =>
      isArabic ? 'فتح $area في خرائط Google' : 'Open $area in Google Maps';

  String get areaOnlyCaption =>
      isArabic ? 'المنطقة فقط · بلا دبوس دقيق' : 'Area only · no exact pin';

  String get jumpToAmenities =>
      isArabic ? 'الانتقال إلى المرافق' : 'Jump to amenities';

  // ---- Rating (prototype until a reviews endpoint is connected) ----

  String get noRatingsYet =>
      isArabic ? 'لا توجد تقييمات بعد' : 'No ratings yet';

  String reviewCount(int count) {
    if (!isArabic) return count == 1 ? '1 review' : '$count reviews';
    if (count == 1) return 'تقييم واحد';
    if (count == 2) return 'تقييمان';
    return count <= 10 ? '$count تقييمات' : '$count تقييماً';
  }

  String ratingSemantics(String average, int count) => isArabic
      ? 'التقييم $average من 5 بناءً على ${reviewCount(count)}'
      : 'Rated $average out of 5 from ${reviewCount(count)}';

  /// Shown once a star is tapped, above the confirm action.
  String ratingPrompt(int stars) => isArabic
      ? 'قيّم هذا الشاليه: $stars من 5 نجوم'
      : 'Rate this chalet: $stars of 5 stars';

  String get ratingNotSavedShort => isArabic
      ? 'معاينة فقط. لا يتم حفظ التقييمات بعد.'
      : 'Preview only. Ratings are not saved yet.';

  String get ratingConfirmAction =>
      isArabic ? 'تأكيد المعاينة' : 'Confirm preview';

  String ratingConfirmed(int stars) => isArabic
      ? 'تم تأكيد المعاينة: $stars من 5. لم يُحفظ أي تقييم.'
      : 'Preview confirmed: $stars of 5. Nothing was saved.';

  String get ratingStarsLabel =>
      isArabic ? 'اختر عدد النجوم' : 'Choose a star rating';

  String starOf(int stars) =>
      isArabic ? '$stars من 5 نجوم' : '$stars of 5 stars';

  String amenity(String key) {
    const english = {
      'outdoor_seating': 'Outdoor seating',
      'equipped_kitchen': 'Equipped kitchen',
      'swimming_pool': 'Swimming pool',
      'wifi': 'Wi-Fi',
      'billiards': 'Billiards',
      'childrens_pool': "Children's pool",
      'childrens_play_equipment': "Children's play equipment",
      'barbecue_grill': 'Barbecue grill',
      'private_parking': 'Private parking',
    };
    const arabic = {
      'outdoor_seating': 'جلسات خارجية',
      'equipped_kitchen': 'مطبخ مجهّز',
      'swimming_pool': 'مسبح',
      'wifi': 'واي فاي',
      'billiards': 'بلياردو',
      'childrens_pool': 'مسبح أطفال',
      'childrens_play_equipment': 'ألعاب أطفال',
      'barbecue_grill': 'منقل شواء',
      'private_parking': 'موقف خاص',
    };
    final labels = isArabic ? arabic : english;
    return labels[key] ?? key;
  }

  String get availabilityTitle => isArabic ? 'التوفر' : 'Availability';

  String get availabilityNotProvided =>
      isArabic ? 'لم يُعلَن التوفر بعد' : 'Availability not yet provided';

  String get availabilityNextStep => isArabic
      ? 'لم ينشر المضيف تواريخ هذا الشاليه. يمكنك التواصل معه مباشرة. تُرسل طلبات الحجز بعد تسجيل دخول الضيف ونشر جدول المضيف.'
      : 'The host has not published dates for this chalet. You can contact them directly. Booking requests open after customer sign-in and the host schedule are available.';

  String get availabilityLoading =>
      isArabic ? 'جارٍ تحميل التوفر' : 'Loading availability';

  String get availabilityError => isArabic
      ? 'تعذّر تحميل التوفر. حاول مرة أخرى.'
      : "We couldn't load availability. Please try again.";

  String get previousMonth => isArabic ? 'الشهر السابق' : 'Previous month';

  String get nextMonth => isArabic ? 'الشهر التالي' : 'Next month';

  String get stateAvailable => isArabic ? 'متاح' : 'Available';

  String get statePending => isArabic ? 'طلب قيد الانتظار' : 'Pending request';

  String get stateBooked => isArabic ? 'محجوز' : 'Booked';

  String get stateUnavailable => isArabic ? 'غير متاح' : 'Unavailable';

  String get stateClosed => isArabic ? 'مغلق' : 'Closed';

  String get statePartial => isArabic ? 'متاح جزئياً' : 'Partially available';

  String get stateRejected => isArabic ? 'مرفوض' : 'Rejected';

  String get stateCancelled => isArabic ? 'ملغى' : 'Cancelled';

  String get noOpenDates => isArabic
      ? 'لا توجد تواريخ مفتوحة هذا الشهر.'
      : 'No open dates this month.';

  String get modeFullDay => isArabic ? 'يوم كامل' : 'Full day';

  String get modeMorning => isArabic ? 'فترة صباحية' : 'Morning session';

  String get modeEvening => isArabic ? 'فترة مسائية' : 'Evening session';

  String get requestBooking =>
      isArabic ? 'إرسال طلب حجز' : 'Send booking request';

  String get bookingAuthRequired => isArabic
      ? 'يلزم تسجيل الدخول بحساب ضيف قبل إرسال الطلب. لم يُرسل هذا الطلب.'
      : 'Sign in with a guest account before sending a request. This request was not submitted.';

  String get bookingStorageClosed => isArabic
      ? 'طلبات الحجز تبقى مغلقة إلى أن تُعتمد قاعدة بيانات الحجز وربط الشاليه بالمالك. لم يُرسل هذا الطلب.'
      : 'Booking requests stay closed until the booking database and chalet ownership are approved. This request was not submitted.';

  String get bookingReceived => isArabic
      ? 'وصل طلبك وهو قيد الانتظار إلى أن يرد المضيف. لم يتم تأكيد الحجز.'
      : 'Your request was received and is pending until the host responds. The booking is not confirmed.';

  String bookingReference(String reference) =>
      isArabic ? 'رقم الطلب: $reference' : 'Booking reference: $reference';

  String get viewBookingRequests =>
      isArabic ? 'طلبات الحجز' : 'Booking requests';

  String get requestsTitle => isArabic ? 'طلباتك' : 'Your requests';

  String get requestsAuthRequired => isArabic
      ? 'سجّل الدخول بحساب ضيف لعرض طلبات الحجز.'
      : 'Sign in with a guest account to view booking requests.';

  String get requestsSignInRequired => requestsAuthRequired;

  String get requestsStorageClosed => isArabic
      ? 'طلبات الحجز تبقى مغلقة إلى أن تُعتمد قاعدة بيانات الحجز وربط الشاليه بالمالك.'
      : 'Booking requests stay closed until the booking database and chalet ownership are approved.';

  String get signIn => isArabic ? 'تسجيل الدخول' : 'Sign in';

  String get account => isArabic ? 'الحساب' : 'Account';

  String get register => isArabic ? 'إنشاء حساب' : 'Create account';

  String get fullName => isArabic ? 'الاسم الكامل' : 'Full name';

  String get email => isArabic ? 'البريد الإلكتروني' : 'Email';

  String get password => isArabic ? 'كلمة المرور' : 'Password';

  String get confirmPassword =>
      isArabic ? 'تأكيد كلمة المرور' : 'Confirm password';

  String get phoneOptional =>
      isArabic ? 'الهاتف (اختياري)' : 'Phone (optional)';

  String get passwordHint =>
      isArabic ? '10 أحرف على الأقل' : 'At least 10 characters';

  String get roleLabel => isArabic ? 'نوع الحساب' : 'Account type';

  String get customerRole => isArabic ? 'ضيف' : 'Guest';

  String get ownerRole => isArabic ? 'مضيف' : 'Host';

  String roleName(String role) {
    switch (role) {
      case 'customer':
        return customerRole;
      case 'owner':
        return ownerRole;
      case 'admin':
        return isArabic ? 'مدير' : 'Admin';
      default:
        return role;
    }
  }

  String get registerOwnerNote => isArabic
      ? 'حساب المضيف لا يربط أي شاليه. ربط الشاليه خطوة منفصلة بعد الموافقة، ولا يمكن اختيار حساب مدير من التسجيل.'
      : 'A host account does not claim a chalet. Linking a chalet is a separate step after approval, and public registration cannot create an admin account.';

  // Friendly "good to know" note under the Guest / Host choice. Same facts as
  // [registerOwnerNote], split into short points.
  String get registerNoteTitle => isArabic ? 'معلومة مفيدة' : 'Good to know';

  String get registerNoteHost => isArabic
      ? 'اختيار «مضيف» لا ينشئ شاليهاً ولا يمنحك شاليهاً تلقائياً.'
      : 'Choosing Host doesn’t create or assign a chalet automatically.';

  String get registerNoteLink => isArabic
      ? 'يتم ربط شاليهك في خطوة منفصلة بعد موافقة MASEEF.'
      : 'Your chalet is linked in a separate step, after MASEEF approves it.';

  String get registerNoteAdmin => isArabic
      ? 'حفاظاً على الأمان، لا يمكن إنشاء حسابات مدير من التسجيل العام.'
      : 'For security, admin accounts can’t be created from public sign-up.';

  String get needAccount => isArabic ? 'ليس لديك حساب؟' : 'Need an account?';

  String get haveAccount =>
      isArabic ? 'لديك حساب؟' : 'Already have an account?';

  String get logout => isArabic ? 'تسجيل الخروج' : 'Log out';

  String get accountBookingClosed => isArabic
      ? 'طلبات الحجز غير متاحة بعد. تبقى مغلقة إلى أن تُعتمد قاعدة البيانات وربط الشاليه.'
      : 'Booking requests are not open yet. They stay closed until the database and chalet link are approved.';

  String get webSessionNote => isArabic
      ? 'في المتصفح يُحفظ تسجيل الدخول حيث يمكن لنصوص هذا الموقع قراءته. استخدم جهازاً خاصاً.'
      : 'In the browser, sign-in is saved where scripts on this site can read it. Use a private device.';

  String get sessionNotSaved => isArabic
      ? 'تعذّر حفظ تسجيل الدخول على هذا الجهاز. ستحتاج إلى تسجيل الدخول مرة أخرى بعد إغلاق التطبيق.'
      : 'Sign-in could not be saved on this device. You will need to sign in again after the app closes.';

  String get authInvalidCredentials => isArabic
      ? 'البريد أو كلمة المرور غير صحيحة.'
      : 'The email or password is incorrect.';

  String get authEmailTaken => isArabic
      ? 'يوجد حساب بهذا البريد.'
      : 'An account with this email already exists.';

  String get authInvalidPassword => isArabic
      ? 'استخدم كلمة مرور من 10 أحرف على الأقل وحتى 128.'
      : 'Use a password of at least 10 characters and at most 128.';

  String get authInvalidEmail => isArabic
      ? 'أدخل بريداً إلكترونياً صالحاً.'
      : 'Enter a valid email address.';

  String get authInvalidName =>
      isArabic ? 'أدخل الاسم الكامل.' : 'Enter your full name.';

  String get authInvalidPhone =>
      isArabic ? 'أدخل رقم هاتف صالحاً.' : 'Enter a valid phone number.';

  String get authInvalidRole => isArabic
      ? 'يمكن التسجيل كضيف أو مضيف فقط.'
      : 'You can register only as a guest or a host.';

  String get authPasswordMismatch =>
      isArabic ? 'كلمتا المرور غير متطابقتين.' : 'The passwords do not match.';

  String get authNetwork => isArabic
      ? 'تعذّر الاتصال بالخادم. حاول مرة أخرى.'
      : "Couldn't reach the server. Please try again.";

  String get authFailed => isArabic
      ? 'تعذّر إكمال الطلب. حاول مرة أخرى.'
      : "The request could not be completed. Please try again.";

  // ---- Authentication pages ----

  String get authTagline => isArabic
      ? 'رحلتك القادمة تبدأ من هنا.'
      : 'Your next getaway starts here.';

  String get authTaglineSub => isArabic
      ? 'اكتشف ملاذك المثالي مع MASEEF.'
      : 'Discover your perfect escape with MASEEF.';

  String get welcomeBack => isArabic ? 'أهلاً بعودتك' : 'Welcome back';

  String get signInSubtitle => isArabic
      ? 'سجّل الدخول لمتابعة رحلتك مع MASEEF.'
      : 'Sign in to continue your journey with MASEEF.';

  String get forgotPasswordLink =>
      isArabic ? 'نسيت كلمة المرور؟' : 'Forgot password?';

  String get registerHeading =>
      isArabic ? 'أنشئ حسابك في MASEEF' : 'Create your MASEEF account';

  String get registerSubtitle => isArabic
      ? 'انضم إلى MASEEF لاكتشاف إقامات العطلات والتخطيط لرحلتك القادمة.'
      : 'Join MASEEF to discover vacation stays and plan your next escape.';

  String get roleCustomerHint => isArabic
      ? 'اكتشف الإقامات وتواصل مع المضيفين'
      : 'Discover and contact stays';

  String get roleOwnerHint =>
      isArabic ? 'لأصحاب الشاليهات ومديريها' : 'For chalet owners and managers';

  String get showPassword => isArabic ? 'إظهار كلمة المرور' : 'Show password';

  String get hidePassword => isArabic ? 'إخفاء كلمة المرور' : 'Hide password';

  String get signingIn => isArabic ? 'جارٍ تسجيل الدخول…' : 'Signing in…';

  String get creatingAccount =>
      isArabic ? 'جارٍ إنشاء الحساب…' : 'Creating account…';

  String get sendingLink => isArabic ? 'جارٍ الإرسال…' : 'Sending…';

  String get updatingPassword =>
      isArabic ? 'جارٍ تحديث كلمة المرور…' : 'Updating password…';

  String get authPasswordRequired =>
      isArabic ? 'أدخل كلمة المرور.' : 'Enter your password.';

  String get authConfirmRequired =>
      isArabic ? 'أكّد كلمة المرور.' : 'Confirm your password.';

  String get backToSignIn =>
      isArabic ? 'العودة إلى تسجيل الدخول' : 'Back to sign in';

  String get forgotHeading =>
      isArabic ? 'نسيت كلمة المرور؟' : 'Forgot your password?';

  String get forgotSubtitle => isArabic
      ? 'أدخل بريدك الإلكتروني وسنساعدك على استعادة الوصول إلى حسابك.'
      : "Enter your email address and we'll help you recover access to your account.";

  String get sendResetLink =>
      isArabic ? 'إرسال رابط الاستعادة' : 'Send reset link';

  String get forgotSuccessTitle =>
      isArabic ? 'تحقق من بريدك الإلكتروني' : 'Check your email';

  // Deliberately identical whether or not the address has an account.
  String get forgotSuccessBody => isArabic
      ? 'إذا كان هناك حساب مرتبط بهذا البريد، فسيصله رابط لإعادة تعيين كلمة المرور. قد يستغرق وصوله بضع دقائق.'
      : 'If an account exists for that email address, a link to reset your password is on its way. It can take a few minutes to arrive.';

  String get useAnotherEmail =>
      isArabic ? 'استخدم بريداً آخر' : 'Use a different email';

  String get resetHeading =>
      isArabic ? 'أنشئ كلمة مرور جديدة' : 'Create a new password';

  String get resetSubtitle => isArabic
      ? 'اختر كلمة مرور جديدة لحسابك في MASEEF.'
      : 'Choose a new password for your MASEEF account.';

  String get newPassword => isArabic ? 'كلمة المرور الجديدة' : 'New password';

  String get confirmNewPassword =>
      isArabic ? 'تأكيد كلمة المرور الجديدة' : 'Confirm new password';

  String get resetPasswordAction =>
      isArabic ? 'إعادة تعيين كلمة المرور' : 'Reset password';

  String get resetSuccessTitle =>
      isArabic ? 'تم تحديث كلمة المرور' : 'Password updated';

  String get resetSuccessBody => isArabic
      ? 'تم تغيير كلمة المرور. سننقلك إلى تسجيل الدخول…'
      : 'Your password has been changed. Taking you to sign in…';

  String get goToSignIn =>
      isArabic ? 'الانتقال إلى تسجيل الدخول' : 'Go to sign in';

  String get resetLinkInvalidTitle =>
      isArabic ? 'رابط الاستعادة غير صالح' : "This reset link isn't valid";

  String get resetLinkInvalidBody => isArabic
      ? 'الرابط ناقص أو غير مكتمل أو انتهت صلاحيته. اطلب رابطاً جديداً للمتابعة.'
      : 'The link is missing, incomplete or has expired. Request a new one to continue.';

  String get requestNewLink =>
      isArabic ? 'اطلب رابطاً جديداً' : 'Request a new link';

  String get authUnavailable => isArabic
      ? 'هذه الخدمة غير متاحة بعد. حاول لاحقاً أو تواصل مع دعم MASEEF.'
      : "This isn't available yet. Please try again later or contact MASEEF support.";

  String get authRateLimited => isArabic
      ? 'محاولات كثيرة. انتظر قليلاً ثم حاول مجدداً.'
      : 'Too many attempts. Please wait a moment and try again.';

  String authError(String code) {
    switch (code) {
      case 'invalid_token':
        return resetLinkInvalidBody;
      case 'unavailable':
        return authUnavailable;
      case 'rate_limited':
        return authRateLimited;
      case 'invalid_credentials':
        return authInvalidCredentials;
      case 'email_taken':
        return authEmailTaken;
      case 'invalid_password':
        return authInvalidPassword;
      case 'invalid_email':
        return authInvalidEmail;
      case 'invalid_name':
        return authInvalidName;
      case 'invalid_phone':
        return authInvalidPhone;
      case 'invalid_role':
        return authInvalidRole;
      case 'password_mismatch':
        return authPasswordMismatch;
      // Client-side validation codes (never sent by the server).
      case 'password_required':
        return authPasswordRequired;
      case 'confirm_required':
        return authConfirmRequired;
      case 'network':
        return authNetwork;
      default:
        return authFailed;
    }
  }

  String get requestsEmpty => isArabic
      ? 'لا توجد طلبات حجز على هذا الحساب.'
      : 'This account has no booking requests.';

  String hostPrice(String amount) =>
      isArabic ? 'سعر حدده المضيف: $amount' : 'Host price: $amount';

  String monthYear(int year, int month) {
    final date = DateTime(year, month);
    if (isArabic) {
      const months = [
        'يناير',
        'فبراير',
        'مارس',
        'أبريل',
        'مايو',
        'يونيو',
        'يوليو',
        'أغسطس',
        'سبتمبر',
        'أكتوبر',
        'نوفمبر',
        'ديسمبر',
      ];
      return '${months[month - 1]} $year';
    }
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} $year';
  }

  List<String> get weekdayLabels => isArabic
      ? const ['سبت', 'أحد', 'إثن', 'ثلا', 'أرب', 'خمي', 'جمع']
      : const ['Sat', 'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
}
