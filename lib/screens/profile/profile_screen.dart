import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/profile_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/language_provider.dart';
import '../../services/auth_service.dart';

// ─────────────────────────────────────────────────────────────────────────
// Local isDark-aware color set for this screen. The original file used a
// static `AppColors.xxx` (from config/theme.dart) that never changed
// regardless of a "dark mode" switch — the switch just flipped a bool that
// nothing read. This local set is driven by ThemeProvider.isDark instead,
// so the Dark Mode / Light Mode toggle actually repaints the screen.
//
// TODO (app-wide, not just this screen): to make Dark/Light apply outside
// Profile too, wrap MaterialApp in main.dart with a Consumer<ThemeProvider>
// and set `theme:`/`darkTheme:`/`themeMode:` from `themeProvider.isDark` —
// see the wiring snippet shared alongside this file.
//
// All display text on this screen is now sourced via
// `languageProvider.t('key')` (see lib/l10n/app_strings.dart) so the
// Language picker actually changes what's shown, not just the saved code.
// ─────────────────────────────────────────────────────────────────────────
class _Colors {
  final bool isDark;
  const _Colors(this.isDark);

  Color get bg => isDark ? const Color(0xFF050A14) : const Color(0xFFF2F5FA);
  Color get surface => isDark ? const Color(0xFF0F1B2E) : Colors.white;
  Color get border => isDark ? const Color(0xFF1A2E50) : const Color(0xFFD8E0EC);

  Color get textPrimary => isDark ? const Color(0xFFF0F6FF) : const Color(0xFF0A1428);
  Color get textSecondary => isDark ? const Color(0xFFA0B8D0) : const Color(0xFF4A5A70);

  Color get teal => const Color(0xFF14B8A6);
  Color get blue => const Color(0xFF1E5FC8);
  Color get purple => const Color(0xFF8B5CF6);
  Color get amber => const Color(0xFFF5A623);
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isUploading = false;
  bool _isSendingReset = false;
  bool _emailNotifications = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfileProvider>().loadProfile();
    });
  }

  Future<void> _pickAndUploadPhoto(ProfileProvider provider, LanguageProvider lang) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 800,
    );
    if (picked == null) return;

    setState(() => _isUploading = true);
    final success = await provider.uploadProfilePhoto(picked);
    setState(() => _isUploading = false);

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lang.t('upload_failed'))),
      );
    }
  }

  // ── Language picker ───────────────────────────────────────────────────
  Future<void> _showLanguagePicker(_Colors c, LanguageProvider lang) async {
    const options = [
      {'code': 'en', 'label': 'English (India)'},
      {'code': 'ta', 'label': 'தமிழ் (Tamil)'},
      {'code': 'hi', 'label': 'हिन्दी (Hindi)'},
    ];

    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    lang.t('select_language'),
                    style: TextStyle(color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              for (final o in options)
                RadioListTile<String>(
                  value: o['code']!,
                  groupValue: lang.code,
                  activeColor: c.teal,
                  title: Text(o['label']!, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600)),
                  onChanged: (val) => Navigator.pop(ctx, val),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (chosen != null && chosen != lang.code) {
      await lang.setLanguage(chosen);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lang.t('language_updated'))),
        );
      }
    }
  }

  // ── Personal Information ──────────────────────────────────────────────
  void _showPersonalInfoDialog(_Colors c, LanguageProvider lang, ProfileProvider provider) {
    final nameController = TextEditingController(text: provider.name ?? '');
    final phoneController = TextEditingController(text: provider.phone ?? '');
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: c.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(Icons.badge_outlined, color: c.blue),
                  const SizedBox(width: 10),
                  Text(lang.t('personal_information_title'),
                      style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lang.t('name_label'),
                        style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameController,
                      style: TextStyle(color: c.textPrimary),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: c.bg,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: c.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: c.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: c.teal),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(lang.t('phone_label_field'),
                        style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      style: TextStyle(color: c.textPrimary),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: c.bg,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: c.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: c.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: c.teal),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${lang.t('email_readonly_note')}: ${provider.email ?? ''}',
                      style: TextStyle(color: c.textSecondary, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: Text(lang.t('cancel'), style: TextStyle(color: c.textSecondary, fontWeight: FontWeight.w700)),
                ),
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                    final newName = nameController.text.trim();
                    if (newName.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(lang.t('name_required'))),
                      );
                      return;
                    }

                    setDialogState(() => isSaving = true);
                    final success = await provider.updatePersonalInfo(
                      name: newName,
                      phone: phoneController.text.trim(),
                    );
                    setDialogState(() => isSaving = false);

                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);

                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(success ? lang.t('profile_updated') : lang.t('profile_update_failed')),
                      ),
                    );
                  },
                  child: isSaving
                      ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: c.teal),
                  )
                      : Text(lang.t('save'), style: TextStyle(color: c.teal, fontWeight: FontWeight.w700)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Change Password ───────────────────────────────────────────────────
  void _showChangePasswordDialog(_Colors c, LanguageProvider lang, ProfileProvider provider) {
    final email = provider.email;

    if (email == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lang.t('no_email_found'))),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: c.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(Icons.lock_outline, color: c.blue),
                  const SizedBox(width: 10),
                  Text(lang.t('change_password_title'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang.t('change_password_dialog_desc'),
                    style: TextStyle(color: c.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: c.bg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: c.border),
                    ),
                    child: Text(
                      email,
                      style: TextStyle(color: c.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: _isSendingReset ? null : () => Navigator.pop(ctx),
                  child: Text(lang.t('cancel'), style: TextStyle(color: c.textSecondary, fontWeight: FontWeight.w700)),
                ),
                TextButton(
                  onPressed: _isSendingReset
                      ? null
                      : () async {
                    setDialogState(() => _isSendingReset = true);
                    setState(() => _isSendingReset = true);

                    final error = await AuthService.sendPasswordResetEmail(email);

                    setState(() => _isSendingReset = false);
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);

                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(error == null ? lang.t('reset_link_sent') : '${lang.t('reset_link_failed')}: $error'),
                      ),
                    );
                  },
                  child: _isSendingReset
                      ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: c.teal),
                  )
                      : Text(lang.t('send_reset_link'), style: TextStyle(color: c.teal, fontWeight: FontWeight.w700)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Help & Support ────────────────────────────────────────────────────
  // TODO: swap in the real CDA IT support phone/email below.
  static const _supportPhone = '+91 00000 00000';
  static const _supportEmail = 'support@chennaidroneacademy.com';

  Future<void> _copyToClipboard(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) {
      final lang = context.read<LanguageProvider>();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lang.t('copied_to_clipboard', {'label': label}))),
      );
    }
  }

  /// Opens the dialer/mail app via [uri]. If no app on the device can
  /// handle it (e.g. no email client configured on an emulator), falls
  /// back to copying [fallbackValue] to the clipboard instead of failing
  /// silently.
  Future<void> _launchOrCopy(Uri uri, String fallbackValue, String label) async {
    try {
      final launched = await launchUrl(uri);
      if (!launched) await _copyToClipboard(fallbackValue, label);
    } catch (_) {
      await _copyToClipboard(fallbackValue, label);
    }
  }

  void _showHelpSupportDialog(_Colors c, LanguageProvider lang) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: c.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.support_agent, color: c.amber),
              const SizedBox(width: 10),
              Text(lang.t('help_support_title'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lang.t('help_support_dialog_desc'),
                style: TextStyle(color: c.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              _contactRow(
                c,
                icon: Icons.phone_outlined,
                value: _supportPhone,
                onTap: () => _launchOrCopy(
                  Uri(scheme: 'tel', path: _supportPhone.replaceAll(' ', '')),
                  _supportPhone,
                  lang.t('phone_label'),
                ),
              ),
              const SizedBox(height: 10),
              _contactRow(
                c,
                icon: Icons.email_outlined,
                value: _supportEmail,
                onTap: () => _launchOrCopy(
                  Uri(scheme: 'mailto', path: _supportEmail),
                  _supportEmail,
                  lang.t('email_label'),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(lang.t('close'), style: TextStyle(color: c.teal, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  Widget _contactRow(_Colors c, {required IconData icon, required String value, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: c.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 17, color: c.teal),
            const SizedBox(width: 10),
            Expanded(
              child: Text(value, style: TextStyle(color: c.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
            Icon(Icons.chevron_right_rounded, size: 17, color: c.textSecondary),
          ],
        ),
      ),
    );
  }

  // ── About App ──────────────────────────────────────────────────────────
  Future<void> _showAboutDialog(_Colors c, LanguageProvider lang) async {
    String version = '1.0.0';
    try {
      final info = await PackageInfo.fromPlatform();
      version = '${info.version}+${info.buildNumber}';
    } catch (_) {
      // package_info_plus not set up on this platform yet — fall back
      // to the hardcoded version below instead of failing the dialog.
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: c.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.info_outline, color: c.amber),
              const SizedBox(width: 10),
              Text(lang.t('about_app_title'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lang.t('about_app_org'),
                style: TextStyle(color: c.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                lang.t('about_app_desc'),
                style: TextStyle(color: c.textSecondary, fontSize: 12.5),
              ),
              const SizedBox(height: 12),
              Text('${lang.t('version_label')} $version', style: TextStyle(color: c.textSecondary, fontSize: 12)),
              const SizedBox(height: 4),
              Text(lang.t('copyright'), style: TextStyle(color: c.textSecondary, fontSize: 12)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(lang.t('close'), style: TextStyle(color: c.teal, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final languageProvider = context.watch<LanguageProvider>();
    final c = _Colors(themeProvider.isDark);
    final lang = languageProvider;

    return Consumer<ProfileProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: c.bg,
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  backgroundColor: c.bg,
                  pinned: true,
                  title: Text(
                    lang.t('profile_title'),
                    style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800),
                  ),
                  iconTheme: IconThemeData(color: c.textPrimary),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPhotoSection(c, provider, lang),
                        const SizedBox(height: 28),
                        _sectionLabel(c, lang.t('section_account'), Icons.person_outline),
                        const SizedBox(height: 10),
                        _sectionCard(c, [
                          _tile(
                            c,
                            icon: Icons.badge_outlined,
                            iconColor: c.blue,
                            title: lang.t('personal_information_title'),
                            subtitle: lang.t('personal_information_subtitle'),
                            onTap: () => _showPersonalInfoDialog(c, lang, provider),
                          ),
                          _tile(
                            c,
                            icon: Icons.lock_outline,
                            iconColor: c.blue,
                            title: lang.t('change_password_title'),
                            subtitle: lang.t('change_password_subtitle'),
                            onTap: () => _showChangePasswordDialog(c, lang, provider),
                          ),
                        ]),
                        const SizedBox(height: 22),
                        _sectionLabel(c, lang.t('section_notifications'), Icons.notifications_none),
                        const SizedBox(height: 10),
                        _sectionCard(c, [
                          _tile(
                            c,
                            icon: Icons.mail_outline,
                            iconColor: c.purple,
                            title: lang.t('email_notifications_title'),
                            subtitle: lang.t('email_notifications_subtitle'),
                            trailing: Switch(
                              value: _emailNotifications,
                              activeColor: c.teal,
                              onChanged: (val) => setState(() => _emailNotifications = val),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 22),
                        _sectionLabel(c, lang.t('section_preferences'), Icons.tune),
                        const SizedBox(height: 10),
                        _sectionCard(c, [
                          _tile(
                            c,
                            icon: Icons.language,
                            iconColor: c.teal,
                            title: lang.t('language_title'),
                            subtitle: languageProvider.displayName,
                            onTap: () => _showLanguagePicker(c, languageProvider),
                          ),
                        ]),
                        const SizedBox(height: 22),
                        _sectionLabel(c, lang.t('section_support'), Icons.help_outline),
                        const SizedBox(height: 10),
                        _sectionCard(c, [
                          _tile(
                            c,
                            icon: Icons.support_agent,
                            iconColor: c.amber,
                            title: lang.t('help_support_title'),
                            subtitle: lang.t('help_support_subtitle'),
                            onTap: () => _showHelpSupportDialog(c, lang),
                          ),
                          _tile(
                            c,
                            icon: Icons.info_outline,
                            iconColor: c.amber,
                            title: lang.t('about_app_title'),
                            subtitle: lang.t('about_app_subtitle'),
                            onTap: () => _showAboutDialog(c, lang),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPhotoSection(_Colors c, ProfileProvider provider, LanguageProvider lang) {
    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 45,
                backgroundColor: c.surface,
                backgroundImage: provider.photoUrl != null
                    ? NetworkImage(provider.photoUrl!)
                    : null,
                child: provider.photoUrl == null
                    ? Icon(Icons.person, size: 45, color: c.textSecondary)
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _isUploading ? null : () => _pickAndUploadPhoto(provider, lang),
                  child: CircleAvatar(
                    radius: 15,
                    backgroundColor: c.teal,
                    child: _isUploading
                        ? const SizedBox(
                      width: 13,
                      height: 13,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                        : const Icon(Icons.camera_alt, size: 15, color: Colors.black),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            provider.name ?? lang.t('loading'),
            style: TextStyle(color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
          ),
          if (provider.email != null) ...[
            const SizedBox(height: 3),
            Text(
              provider.email!,
              style: TextStyle(color: c.textSecondary, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionLabel(_Colors c, String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: c.textSecondary),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: c.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
  }

  Widget _sectionCard(_Colors c, List<Widget> tiles) {
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          for (int i = 0; i < tiles.length; i++) ...[
            tiles[i],
            if (i != tiles.length - 1) Divider(color: c.border, height: 1),
          ],
        ],
      ),
    );
  }

  Widget _tile(
      _Colors c, {
        required IconData icon,
        required Color iconColor,
        required String title,
        required String subtitle,
        Widget? trailing,
        VoidCallback? onTap,
      }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 19),
      ),
      title: Text(
        title,
        style: TextStyle(color: c.textPrimary, fontSize: 14.5, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: c.textSecondary, fontSize: 12.5),
      ),
      trailing: trailing ?? (onTap != null ? Icon(Icons.chevron_right, color: c.textSecondary, size: 20) : null),
    );
  }
}