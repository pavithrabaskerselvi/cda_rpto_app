import '../widgets/attach_document_button.dart';

/// One "module" in the Drone Details Attachments screen — mirrors a
/// folder in the Drive structure under "13. DRONE DETAILS".
class DroneDocCategory {
  final String key;
  final String label;

  /// Lowercase keywords used by [DroneDocCategories.classify] to map a
  /// raw Drive folder name (e.g. "2.INSURANCE", "Model T Manuals") onto
  /// this category.
  final List<String> matchTokens;

  const DroneDocCategory({
    required this.key,
    required this.label,
    required this.matchTokens,
  });
}

/// DroneDocCategories
/// --------------------
/// Sourced from the two Drive folders you're upgrading against:
///
///   13. DRONE DETAILS > 1.SMALL
///     Battery & Charger, Checklist, COC, INSURANCE, INVOICE,
///     Maintenance Agreement, Master Slave, Model T Manuals, PHOTOS,
///     UIN & TC, Warranty
///
///   13. DRONE DETAILS > 2.MEDIUM
///     1.DRONE PHOTOS, 2.INSURANCE, BATTERY CHARGER..., BATTERY
///     COMPATIBILTY, COC, DECLARATION FORM, FORM D2 & D3, INSTALLATION
///     PROCESS..., INVOICE, MAINTENANCE..., MASTER SLAVE, TC DOCUMENT,
///     WARRANTY CARD, WARRANTY CERTIFICATE
///
/// Folders that mean the same thing across both sizes (Insurance,
/// COC, Invoice, Master Slave, Battery & Charger...) are merged into a
/// single category; Drive folder names that only exist for one size
/// (Checklist, Model T Manuals, Declaration Form, Form D2 & D3,
/// Installation Process, Battery Compatibility) still get their own
/// slot so nothing is lost.
///
/// Nothing here is marked `required` — a Small drone never has a
/// "Declaration Form" folder and a Medium drone never has a
/// "Checklist" folder, so validation would just nag for no reason.
/// Every category also allows multiple documents (a "PHOTOS" or
/// "INVOICE" folder usually has more than one file in it).
class DroneDocCategories {
  DroneDocCategories._();

  static const List<DroneDocCategory> all = [
    DroneDocCategory(
      key: 'photos',
      label: 'Photos',
      matchTokens: ['photo'],
    ),
    DroneDocCategory(
      key: 'battery_charger',
      label: 'Battery & Charger',
      matchTokens: ['battery & charger', 'battery charger', 'charger'],
    ),
    DroneDocCategory(
      key: 'battery_compatibility',
      label: 'Battery Compatibility',
      matchTokens: ['compatib'],
    ),
    DroneDocCategory(
      key: 'checklist',
      label: 'Checklist',
      matchTokens: ['checklist'],
    ),
    DroneDocCategory(
      key: 'coc',
      label: 'COC',
      matchTokens: ['coc'],
    ),
    DroneDocCategory(
      key: 'insurance',
      label: 'Insurance',
      matchTokens: ['insurance'],
    ),
    DroneDocCategory(
      key: 'invoice',
      label: 'Invoice',
      matchTokens: ['invoice'],
    ),
    DroneDocCategory(
      key: 'maintenance_agreement',
      label: 'Maintenance Agreement',
      matchTokens: ['maint'],
    ),
    DroneDocCategory(
      key: 'master_slave',
      label: 'Master Slave',
      matchTokens: ['master slave', 'master', 'slave'],
    ),
    DroneDocCategory(
      key: 'manuals',
      label: 'Manuals',
      matchTokens: ['manual'],
    ),
    DroneDocCategory(
      key: 'declaration_form',
      label: 'Declaration Form',
      matchTokens: ['declaration'],
    ),
    DroneDocCategory(
      key: 'form_d2_d3',
      label: 'Form D2 & D3',
      matchTokens: ['form d2', 'form d3', 'd2 & d3', 'd2&d3'],
    ),
    DroneDocCategory(
      key: 'installation_process',
      label: 'Installation Process',
      matchTokens: ['installation'],
    ),
    DroneDocCategory(
      key: 'uin_tc',
      label: 'UIN & TC',
      matchTokens: ['uin', 'tc document', 'tc'],
    ),
    DroneDocCategory(
      key: 'warranty',
      label: 'Warranty',
      matchTokens: ['warranty'],
    ),
    // Catch-all — keep last. Anything that doesn't match a known
    // folder still gets imported instead of silently dropped.
    DroneDocCategory(
      key: 'other',
      label: 'Other',
      matchTokens: [],
    ),
  ];

  /// The Attachments screen slots for Drone Details — one per category
  /// (except the 'other' catch-all), none required, all allowing more
  /// than one file.
  static List<DocumentRequirement> get requirements => all
      .where((c) => c.key != 'other')
      .map(
        (c) => DocumentRequirement(
      key: c.key,
      label: c.label,
      required: false,
      allowMultiple: true,
    ),
  )
      .toList();

  static DroneDocCategory byKey(String key) => all.firstWhere(
        (c) => c.key == key,
    orElse: () => all.last,
  );

  // ------------------------------------------------------------------
  // Size-specific modules — "Small" and "Medium" shown as two separate
  // sections on the Drone Details page, each mirroring its own Drive
  // folder exactly (not merged together like [all]/[requirements]
  // above). Keys are prefixed per group so a Small and a Medium slot
  // with the same label (e.g. "Insurance") never collide when both
  // are stored in the same drone's `documents` field.
  // ------------------------------------------------------------------

  /// 13. DRONE DETAILS > 1.SMALL
  static const List<DroneDocCategory> small = [
    DroneDocCategory(key: 'small_battery_charger', label: 'Battery & Charger', matchTokens: ['battery & charger', 'battery charger', 'charger']),
    DroneDocCategory(key: 'small_checklist', label: 'Checklist', matchTokens: ['checklist']),
    DroneDocCategory(key: 'small_coc', label: 'COC', matchTokens: ['coc']),
    DroneDocCategory(key: 'small_insurance', label: 'Insurance', matchTokens: ['insurance']),
    DroneDocCategory(key: 'small_invoice', label: 'Invoice', matchTokens: ['invoice']),
    DroneDocCategory(key: 'small_maintenance_agreement', label: 'Maintenance Agreement', matchTokens: ['maint']),
    DroneDocCategory(key: 'small_master_slave', label: 'Master Slave', matchTokens: ['master slave', 'master', 'slave']),
    DroneDocCategory(key: 'small_model_t_manuals', label: 'Model T Manuals', matchTokens: ['manual']),
    DroneDocCategory(key: 'small_photos', label: 'Photos', matchTokens: ['photo']),
    DroneDocCategory(key: 'small_uin_tc', label: 'UIN & TC', matchTokens: ['uin', 'tc']),
    DroneDocCategory(key: 'small_warranty', label: 'Warranty', matchTokens: ['warranty']),
  ];

  /// 13. DRONE DETAILS > 2.MEDIUM
  static const List<DroneDocCategory> medium = [
    DroneDocCategory(key: 'medium_drone_photos', label: 'Drone Photos', matchTokens: ['photo']),
    DroneDocCategory(key: 'medium_insurance', label: 'Insurance', matchTokens: ['insurance']),
    DroneDocCategory(key: 'medium_battery_charger', label: 'Battery Charger', matchTokens: ['battery charger', 'charger']),
    DroneDocCategory(key: 'medium_battery_compatibility', label: 'Battery Compatibility', matchTokens: ['compatib']),
    DroneDocCategory(key: 'medium_coc', label: 'COC', matchTokens: ['coc']),
    DroneDocCategory(key: 'medium_declaration_form', label: 'Declaration Form', matchTokens: ['declaration']),
    DroneDocCategory(key: 'medium_form_d2_d3', label: 'Form D2 & D3', matchTokens: ['form d2', 'form d3', 'd2 & d3', 'd2&d3']),
    DroneDocCategory(key: 'medium_installation_process', label: 'Installation Process', matchTokens: ['installation']),
    DroneDocCategory(key: 'medium_invoice', label: 'Invoice', matchTokens: ['invoice']),
    DroneDocCategory(key: 'medium_maintenance_agreement', label: 'Maintenance Agreement', matchTokens: ['maint']),
    DroneDocCategory(key: 'medium_master_slave', label: 'Master Slave', matchTokens: ['master slave', 'master', 'slave']),
    DroneDocCategory(key: 'medium_tc_document', label: 'TC Document', matchTokens: ['tc document', 'tc']),
    DroneDocCategory(key: 'medium_warranty_card', label: 'Warranty Card', matchTokens: ['warranty card']),
    DroneDocCategory(key: 'medium_warranty_certificate', label: 'Warranty Certificate', matchTokens: ['warranty certificate']),
  ];

  /// Attachments-screen slots for the "Small" module — none required,
  /// all allow multiple files (Photos/Invoice etc. naturally hold more
  /// than one).
  static List<DocumentRequirement> get smallRequirements => small
      .map((c) => DocumentRequirement(
    key: c.key,
    label: c.label,
    required: false,
    allowMultiple: true,
  ))
      .toList();

  /// Attachments-screen slots for the "Medium" module.
  static List<DocumentRequirement> get mediumRequirements => medium
      .map((c) => DocumentRequirement(
    key: c.key,
    label: c.label,
    required: false,
    allowMultiple: true,
  ))
      .toList();

  /// Classifies a raw Drive folder name into one of the categories
  /// above. Case-insensitive, ignores leading numbering ("1.", "2)").
  /// Falls back to 'other' if nothing matches.
  static DroneDocCategory classify(String rawFolderName) {
    final normalized = rawFolderName
        .trim()
        .toLowerCase()
        .replaceFirst(RegExp(r'^\d+\s*[.)-]?\s*'), '')
        .trim();

    for (final category in all) {
      if (category.key == 'other') continue;
      for (final token in category.matchTokens) {
        if (normalized.contains(token)) return category;
      }
    }
    return all.last; // 'other'
  }
}