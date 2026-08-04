// lib/l10n/app_strings.dart
//
// Simple key -> {en, ta, hi} translation map. No flutter_localizations /
// .arb setup needed — LanguageProvider.t(key) looks values up from here.
//
// HOW TO ADD MORE STRINGS:
//   1. Add a new key below with 'en' / 'ta' / 'hi' values.
//   2. Use it in a widget as: languageProvider.t('your_key')
//
// HOW TO ADD PARAMS (e.g. "{label} copied to clipboard"):
//   Use {paramName} inside the string, then call:
//   languageProvider.t('copied_to_clipboard', {'label': 'Phone number'})

class AppStrings {
  AppStrings._();

  static const Map<String, Map<String, String>> _strings = {
    // ── App bar ──────────────────────────────────────────────
    'profile_title': {
      'en': 'Profile',
      'ta': 'சுயவிவரம்',
      'hi': 'प्रोफ़ाइल',
    },
    'loading': {
      'en': 'Loading...',
      'ta': 'ஏற்றுகிறது...',
      'hi': 'लोड हो रहा है...',
    },

    // ── ACCOUNT section ──────────────────────────────────────
    'section_account': {
      'en': 'ACCOUNT',
      'ta': 'கணக்கு',
      'hi': 'खाता',
    },
    'change_password_title': {
      'en': 'Change Password',
      'ta': 'கடவுச்சொல்லை மாற்று',
      'hi': 'पासवर्ड बदलें',
    },
    'personal_information_title': {
      'en': 'Personal Information',
      'ta': 'தனிப்பட்ட தகவல்',
      'hi': 'व्यक्तिगत जानकारी',
    },
    'personal_information_subtitle': {
      'en': 'Update your name and phone number',
      'ta': 'உங்கள் பெயர் & தொலைபேசி எண்ணை புதுப்பிக்கவும்',
      'hi': 'अपना नाम और फ़ोन नंबर अपडेट करें',
    },
    'name_label': {
      'en': 'Full Name',
      'ta': 'முழுப் பெயர்',
      'hi': 'पूरा नाम',
    },
    'phone_label_field': {
      'en': 'Phone Number',
      'ta': 'தொலைபேசி எண்',
      'hi': 'फ़ोन नंबर',
    },
    'email_readonly_note': {
      'en': 'Email cannot be changed here',
      'ta': 'மின்னஞ்சலை இங்கு மாற்ற முடியாது',
      'hi': 'ईमेल यहां नहीं बदला जा सकता',
    },
    'save': {
      'en': 'Save',
      'ta': 'சேமி',
      'hi': 'सहेजें',
    },
    'profile_updated': {
      'en': 'Profile updated',
      'ta': 'சுயவிவரம் புதுப்பிக்கப்பட்டது',
      'hi': 'प्रोफ़ाइल अपडेट की गई',
    },
    'profile_update_failed': {
      'en': 'Failed to update profile',
      'ta': 'சுயவிவரத்தைப் புதுப்பிக்க முடியவில்லை',
      'hi': 'प्रोफ़ाइल अपडेट करने में विफल',
    },
    'name_required': {
      'en': 'Name cannot be empty',
      'ta': 'பெயர் காலியாக இருக்கக்கூடாது',
      'hi': 'नाम खाली नहीं हो सकता',
    },
    'change_password_subtitle': {
      'en': 'Sends a reset link to your email',
      'ta': 'உங்கள் மின்னஞ்சலுக்கு மீட்டமைப்பு இணைப்பு அனுப்பப்படும்',
      'hi': 'आपके ईमेल पर रीसेट लिंक भेजा जाएगा',
    },
    'change_password_dialog_desc': {
      'en': 'We will send a password reset link to:',
      'ta': 'கடவுச்சொல் மீட்டமைப்பு இணைப்பு இதற்கு அனுப்பப்படும்:',
      'hi': 'पासवर्ड रीसेट लिंक इस पते पर भेजा जाएगा:',
    },
    'send_reset_link': {
      'en': 'Send Reset Link',
      'ta': 'மீட்டமைப்பு இணைப்பை அனுப்பு',
      'hi': 'रीसेट लिंक भेजें',
    },
    'cancel': {
      'en': 'Cancel',
      'ta': 'ரத்து செய்',
      'hi': 'रद्द करें',
    },
    'reset_link_sent': {
      'en': 'Reset link sent! Check your email.',
      'ta': 'மீட்டமைப்பு இணைப்பு அனுப்பப்பட்டது! உங்கள் மின்னஞ்சலைப் பாருங்கள்.',
      'hi': 'रीसेट लिंक भेजा गया! अपना ईमेल जांचें।',
    },
    'reset_link_failed': {
      'en': 'Failed to send reset link',
      'ta': 'மீட்டமைப்பு இணைப்பை அனுப்ப முடியவில்லை',
      'hi': 'रीसेट लिंक भेजने में विफल',
    },
    'no_email_found': {
      'en': 'No email found for this account',
      'ta': 'இந்தக் கணக்கிற்கு மின்னஞ்சல் கிடைக்கவில்லை',
      'hi': 'इस खाते के लिए कोई ईमेल नहीं मिला',
    },
    'biometric_login_title': {
      'en': 'Biometric Login',
      'ta': 'பயோமெட்ரிக் உள்நுழைவு',
      'hi': 'बायोमेट्रिक लॉगिन',
    },
    'biometric_login_subtitle': {
      'en': 'Use fingerprint / face unlock',
      'ta': 'கைரேகை / முக அடையாளத்தைப் பயன்படுத்தவும்',
      'hi': 'फिंगरप्रिंट / फेस अनलॉक का उपयोग करें',
    },

    // ── NOTIFICATIONS section ────────────────────────────────
    'section_notifications': {
      'en': 'NOTIFICATIONS',
      'ta': 'அறிவிப்புகள்',
      'hi': 'सूचनाएं',
    },
    'push_notifications_title': {
      'en': 'Push Notifications',
      'ta': 'புஷ் அறிவிப்புகள்',
      'hi': 'पुश सूचनाएं',
    },
    'push_notifications_subtitle': {
      'en': 'Stock alerts & drone activity',
      'ta': 'ஸ்டாக் அலர்ட் & ட்ரோன் செயல்பாடு',
      'hi': 'स्टॉक अलर्ट और ड्रोन गतिविधि',
    },
    'email_notifications_title': {
      'en': 'Email Notifications',
      'ta': 'மின்னஞ்சல் அறிவிப்புகள்',
      'hi': 'ईमेल सूचनाएं',
    },
    'email_notifications_subtitle': {
      'en': 'Weekly inventory reports',
      'ta': 'வாராந்திர சரக்கு அறிக்கைகள்',
      'hi': 'साप्ताहिक इन्वेंट्री रिपोर्ट',
    },

    // ── PREFERENCES section ──────────────────────────────────
    'section_preferences': {
      'en': 'PREFERENCES',
      'ta': 'விருப்பத்தேர்வுகள்',
      'hi': 'प्राथमिकताएं',
    },
    'dark_mode_title': {
      'en': 'Dark Mode',
      'ta': 'இருண்ட பயன்முறை',
      'hi': 'डार्क मोड',
    },
    'dark_mode_subtitle_on': {
      'en': 'Navy theme (on)',
      'ta': 'நேவி தீம் (ஆன்)',
      'hi': 'नेवी थीम (चालू)',
    },
    'light_mode_title': {
      'en': 'Light Mode',
      'ta': 'வெளிச்ச பயன்முறை',
      'hi': 'लाइट मोड',
    },
    'light_mode_subtitle_on': {
      'en': 'Light theme (on)',
      'ta': 'லைட் தீம் (ஆன்)',
      'hi': 'लाइट थीम (चालू)',
    },
    'language_title': {
      'en': 'Language',
      'ta': 'மொழி',
      'hi': 'भाषा',
    },
    'select_language': {
      'en': 'Select Language',
      'ta': 'மொழியைத் தேர்ந்தெடுக்கவும்',
      'hi': 'भाषा चुनें',
    },
    'language_updated': {
      'en': 'Language updated',
      'ta': 'மொழி புதுப்பிக்கப்பட்டது',
      'hi': 'भाषा अपडेट की गई',
    },

    // ── SUPPORT section ───────────────────────────────────────
    'section_support': {
      'en': 'SUPPORT',
      'ta': 'ஆதரவு',
      'hi': 'सहायता',
    },
    'help_support_title': {
      'en': 'Help & Support',
      'ta': 'உதவி & ஆதரவு',
      'hi': 'सहायता और समर्थन',
    },
    'help_support_subtitle': {
      'en': 'Contact the CDA IT team',
      'ta': 'CDA IT குழுவைத் தொடர்பு கொள்ளவும்',
      'hi': 'CDA IT टीम से संपर्क करें',
    },
    'help_support_dialog_desc': {
      'en': 'Reach the CDA IT team for account, app, or training queries.',
      'ta': 'கணக்கு, ஆப் அல்லது பயிற்சி தொடர்பான கேள்விகளுக்கு CDA IT '
          'குழுவைத் தொடர்பு கொள்ளவும்.',
      'hi': 'खाता, ऐप या प्रशिक्षण संबंधी प्रश्नों के लिए CDA IT टीम से '
          'संपर्क करें।',
    },
    'about_app_title': {
      'en': 'About App',
      'ta': 'ஆப் பற்றி',
      'hi': 'ऐप के बारे में',
    },
    'about_app_subtitle': {
      'en': 'RPTO Management v1.0',
      'ta': 'RPTO மேலாண்மை v1.0',
      'hi': 'RPTO प्रबंधन v1.0',
    },
    'about_app_org': {
      'en': 'CDA RPTO — Remote Pilot Training Organisation',
      'ta': 'CDA RPTO — தொலைநிலை பைலட் பயிற்சி நிறுவனம்',
      'hi': 'CDA RPTO — रिमोट पायलट प्रशिक्षण संगठन',
    },
    'about_app_desc': {
      'en': 'Manages instructors, students, batches, drones and training '
          'documents for Chennai Drone Academy.',
      'ta': 'சென்னை ட்ரோன் அகாடமிக்கான பயிற்றுநர்கள், மாணவர்கள், '
          'பேட்ச்கள், ட்ரோன்கள் மற்றும் பயிற்சி ஆவணங்களை நிர்வகிக்கிறது.',
      'hi': 'चेन्नई ड्रोन अकादमी के लिए प्रशिक्षक, छात्र, बैच, ड्रोन और '
          'प्रशिक्षण दस्तावेज़ों का प्रबंधन करता है।',
    },
    'version_label': {
      'en': 'Version',
      'ta': 'பதிப்பு',
      'hi': 'संस्करण',
    },
    'copyright': {
      'en': '© 2026 SkyLNK Unmanned Pvt. Ltd.',
      'ta': '© 2026 SkyLNK Unmanned Pvt. Ltd.',
      'hi': '© 2026 SkyLNK Unmanned Pvt. Ltd.',
    },
    'close': {
      'en': 'Close',
      'ta': 'மூடு',
      'hi': 'बंद करें',
    },

    // ── Misc / dynamic ────────────────────────────────────────
    'upload_failed': {
      'en': 'Upload failed, try again',
      'ta': 'பதிவேற்றம் தோல்வியடைந்தது, மீண்டும் முயற்சிக்கவும்',
      'hi': 'अपलोड विफल हुआ, फिर से प्रयास करें',
    },
    'phone_label': {
      'en': 'Phone number',
      'ta': 'தொலைபேசி எண்',
      'hi': 'फ़ोन नंबर',
    },
    'email_label': {
      'en': 'Email address',
      'ta': 'மின்னஞ்சல் முகவரி',
      'hi': 'ईमेल पता',
    },
    'copied_to_clipboard': {
      'en': '{label} copied to clipboard',
      'ta': '{label} கிளிப்போர்டுக்கு நகலெடுக்கப்பட்டது',
      'hi': '{label} क्लिपबोर्ड पर कॉपी हो गया',
    },
  };

  /// Returns the string for [key] in [code] ('en' | 'ta' | 'hi').
  /// Falls back to English, then to the key itself if nothing is found.
  static String get(String key, String code) {
    final entry = _strings[key];
    if (entry == null) return key;
    return entry[code] ?? entry['en'] ?? key;
  }
}