import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Map<String, dynamic> _sfMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) {
    return Map<String, dynamic>.from(v);
  }
  return <String, dynamic>{};
}

List<dynamic> _sfList(dynamic v) {
  if (v is List) return v;
  return const <dynamic>[];
}

double _sfDouble(dynamic v, double fallback) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim()) ?? fallback;
  return fallback;
}

int _sfInt(dynamic v, int fallback) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim()) ?? fallback;
  return fallback;
}

bool _sfBool(dynamic v, bool fallback) {
  if (v is bool) return v;
  if (v is String) {
    final l = v.trim().toLowerCase();
    if (l == 'true' || l == '1') return true;
    if (l == 'false' || l == '0') return false;
  }
  if (v is num) return v != 0;
  return fallback;
}

Color parseHexColor(dynamic val, Color fallback) {
  if (val == null) return fallback;
  var s = val.toString().trim();
  if (s.isEmpty) return fallback;
  if (s.toLowerCase() == 'transparent') return Colors.transparent;
  if (s.startsWith('#')) {
    s = s.substring(1);
  } else if (s.toLowerCase().startsWith('0x')) {
    s = s.substring(2);
  }
  if (s.length == 6) {
    s = 'FF$s';
  }
  if (s.length != 8) return fallback;
  final parsed = int.tryParse(s, radix: 16);
  if (parsed == null) return fallback;
  return Color(parsed);
}

Alignment parseAlignment(dynamic val, Alignment fallback) {
  final s = (val ?? '').toString().trim();
  switch (s) {
    case 'topLeft':
      return Alignment.topLeft;
    case 'topRight':
      return Alignment.topRight;
    case 'topCenter':
      return Alignment.topCenter;
    case 'bottomLeft':
      return Alignment.bottomLeft;
    case 'bottomRight':
      return Alignment.bottomRight;
    case 'bottomCenter':
      return Alignment.bottomCenter;
    case 'centerLeft':
      return Alignment.centerLeft;
    case 'centerRight':
      return Alignment.centerRight;
    case 'center':
      return Alignment.center;
    default:
      return fallback;
  }
}

FontWeight parseFontWeight(dynamic val, FontWeight fallback) {
  final n = _sfInt(val, 0);
  switch (n) {
    case 400:
      return FontWeight.w400;
    case 500:
      return FontWeight.w500;
    case 600:
      return FontWeight.w600;
    case 700:
      return FontWeight.w700;
    case 800:
      return FontWeight.w800;
    case 900:
      return FontWeight.w900;
    default:
      return fallback;
  }
}

CrossAxisAlignment parseCrossAlign(dynamic val, CrossAxisAlignment fallback) {
  final s = (val ?? '').toString().trim().toLowerCase();
  if (s == 'center') return CrossAxisAlignment.center;
  if (s == 'end') return CrossAxisAlignment.end;
  if (s == 'start') return CrossAxisAlignment.start;
  return fallback;
}

TextAlign parseTextAlign(dynamic val, TextAlign fallback) {
  final s = (val ?? '').toString().trim().toLowerCase();
  if (s == 'center') return TextAlign.center;
  if (s == 'end' || s == 'left') return TextAlign.end;
  if (s == 'start' || s == 'right') return TextAlign.start;
  return fallback;
}

IconData resolveStorefrontIcon(String? name) {
  switch ((name ?? '').trim().toLowerCase()) {
    case 'rocket':
    case 'rocket_launch':
      return Icons.rocket_launch_rounded;
    case 'bolt':
    case 'flash':
    case 'flash_on':
      return Icons.bolt_rounded;
    case 'star':
      return Icons.star_rounded;
    case 'star_border':
      return Icons.star_border_rounded;
    case 'workspace_premium':
    case 'crown':
    case 'premium':
      return Icons.workspace_premium_rounded;
    case 'verified':
      return Icons.verified_rounded;
    case 'shield':
    case 'security':
      return Icons.verified_user_rounded;
    case 'lock':
      return Icons.lock_rounded;
    case 'lock_outline':
      return Icons.lock_outline_rounded;
    case 'lock_open':
      return Icons.lock_open_rounded;
    case 'block':
      return Icons.block_rounded;
    case 'check':
      return Icons.check_rounded;
    case 'check_circle':
      return Icons.check_circle_rounded;
    case 'check_circle_outline':
      return Icons.check_circle_outline_rounded;
    case 'upgrade':
    case 'trending_up':
      return Icons.upgrade_rounded;
    case 'campaign':
    case 'announce':
      return Icons.campaign_rounded;
    case 'notifications':
      return Icons.notifications_active_rounded;
    case 'info':
      return Icons.info_rounded;
    case 'info_outline':
      return Icons.info_outline_rounded;
    case 'warning':
      return Icons.warning_amber_rounded;
    case 'local_offer':
    case 'offer':
    case 'discount':
    case 'sell':
      return Icons.local_offer_rounded;
    case 'card_giftcard':
    case 'gift':
      return Icons.card_giftcard_rounded;
    case 'sports_esports':
    case 'gamepad':
    case 'gaming':
      return Icons.sports_esports_rounded;
    case 'speed':
      return Icons.speed_rounded;
    case 'public':
    case 'language':
    case 'globe':
      return Icons.public_rounded;
    case 'router':
      return Icons.router_rounded;
    case 'wifi':
      return Icons.wifi_rounded;
    case 'auto_awesome':
    case 'sparkle':
      return Icons.auto_awesome_rounded;
    case 'diamond':
      return Icons.diamond_rounded;
    case 'layers':
      return Icons.layers_rounded;
    case 'support_agent':
      return Icons.support_agent_rounded;
    case 'schedule':
    case 'timer':
      return Icons.schedule_rounded;
    case 'receipt_long':
      return Icons.receipt_long_rounded;
    case 'shopping_bag':
      return Icons.shopping_bag_rounded;
    case 'credit_card':
      return Icons.credit_card_rounded;
    case 'arrow_forward':
      return Icons.arrow_forward_rounded;
    case 'open_in_new':
      return Icons.open_in_new_rounded;
    case 'content_copy':
    case 'copy':
      return Icons.content_copy_rounded;
    case 'refresh':
      return Icons.refresh_rounded;
    case 'tune':
      return Icons.tune_rounded;
    case 'dns':
      return Icons.dns_rounded;
    case 'vpn_key':
      return Icons.vpn_key_rounded;
    default:
      return Icons.star_rounded;
  }
}

String formatTomanComma(num n, {String currencyLabel = 'تومان'}) {
  final str = n.toInt().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      );
  final cur = currencyLabel.trim().isNotEmpty ? currencyLabel.trim() : 'تومان';
  return '$str $cur';
}

String formatStorefrontText(String raw, Map<String, dynamic> vars) {
  if (!raw.contains('{') || vars.isEmpty) return raw;
  var out = raw;
  vars.forEach((k, v) {
    out = out.replaceAll('{$k}', (v ?? '').toString());
  });
  return out;
}

String resolveStorefrontTemplate(
  String raw, {
  required String? userToken,
  required Map<String, dynamic>? userData,
  Map<String, dynamic>? extraVars,
}) {
  if (!raw.contains('{')) return raw;
  final tier = (userData?['plan_tier'] ?? 'PRO').toString().toUpperCase();
  final remaining = (userData?['remaining_text'] ?? 'نامشخص').toString();
  final username = (userData?['username'] ?? userData?['display_name'] ?? 'کاربر').toString();
  final daysLeft = (userData?['days_left'] ?? 0).toString();
  final expiresAt = (userData?['plan_expires_at'] ?? '').toString();
  final email = (userData?['email'] ?? '').toString();
  var out = raw
      .replaceAll('{tier}', tier)
      .replaceAll('{remaining}', remaining)
      .replaceAll('{username}', username)
      .replaceAll('{days_left}', daysLeft)
      .replaceAll('{expires_at}', expiresAt)
      .replaceAll('{email}', email);
  if (extraVars != null && extraVars.isNotEmpty) {
    out = formatStorefrontText(out, extraVars);
  }
  return out;
}

Map<String, dynamic> resolveStorefrontFeedback(
  dynamic raw,
  Map<String, dynamic> messages, {
  String? fallbackKey,
  String? fallbackText,
  Map<String, dynamic>? vars,
}) {
  dynamic source = raw;
  if (source == null && fallbackKey != null && fallbackKey.isNotEmpty && messages.containsKey(fallbackKey)) {
    source = messages[fallbackKey];
  }
  if (source is String) {
    final msg = source.trim().isNotEmpty ? source : (fallbackText ?? '');
    final formatted = vars != null ? formatStorefrontText(msg, vars) : msg;
    return {
      'mode': formatted.isEmpty ? 'silent' : 'toast',
      'message': formatted,
    };
  }
  if (source is Map) {
    final map = Map<String, dynamic>.from(source);
    var msg = (map['message'] ?? map['text'] ?? map['body'] ?? '').toString();
    if (msg.trim().isEmpty) {
      final fk = (map['feedback_key'] ?? '').toString().trim();
      if (fk.isNotEmpty && messages.containsKey(fk)) {
        return resolveStorefrontFeedback(
          messages[fk],
          messages,
          fallbackKey: fallbackKey,
          fallbackText: fallbackText,
          vars: vars,
        );
      }
      if (map['feedback'] != null) {
        return resolveStorefrontFeedback(
          map['feedback'],
          messages,
          fallbackKey: fallbackKey,
          fallbackText: fallbackText,
          vars: vars,
        );
      }
      msg = fallbackText ?? '';
    }
    var title = (map['title'] ?? '').toString();
    var closeBtn = (map['close_btn_text'] ?? 'متوجه شدم').toString();
    if (vars != null && vars.isNotEmpty) {
      msg = formatStorefrontText(msg, vars);
      if (title.isNotEmpty) title = formatStorefrontText(title, vars);
      if (closeBtn.isNotEmpty) closeBtn = formatStorefrontText(closeBtn, vars);
    }
    final mode = (map['mode'] ?? ((title.isNotEmpty || map['action_btn'] != null) ? 'dialog' : (msg.trim().isEmpty ? 'silent' : 'toast'))).toString().trim().toLowerCase();
    final out = Map<String, dynamic>.from(map);
    out['mode'] = mode;
    out['message'] = msg;
    out['title'] = title;
    out['close_btn_text'] = closeBtn;
    return out;
  }
  final fbTxt = fallbackText ?? '';
  final formatted = vars != null ? formatStorefrontText(fbTxt, vars) : fbTxt;
  return {
    'mode': formatted.isEmpty ? 'silent' : 'toast',
    'message': formatted,
  };
}

Future<void> showServerFeedback(
  BuildContext context,
  Map<String, dynamic> feedback, {
  required void Function(String) onToast,
  Future<void> Function(Map<String, dynamic>)? onAction,
}) async {
  final mode = (feedback['mode'] ?? 'toast').toString().trim().toLowerCase();
  final message = (feedback['message'] ?? '').toString();
  final title = (feedback['title'] ?? '').toString();
  if (mode == 'silent' || (message.trim().isEmpty && title.trim().isEmpty)) {
    return;
  }
  if (mode != 'dialog') {
    onToast(message.isNotEmpty ? message : title);
    return;
  }

  final dlgBg = parseHexColor(feedback['dialog_bg_color'], const Color(0xFF0E0E14));
  final dlgBorder = parseHexColor(feedback['border_color'], const Color(0x4DFF3B5C));
  final iconName = (feedback['icon'] ?? 'info').toString().trim();
  final iconColor = parseHexColor(feedback['icon_color'], const Color(0xFFFFAB00));
  final iconBg = parseHexColor(feedback['icon_bg_color'], const Color(0x1AFFAB00));
  final titleColor = parseHexColor(feedback['title_color'], Colors.white);
  final msgColor = parseHexColor(feedback['message_color'], const Color(0xFFD0D0E0));
  final closeText = (feedback['close_btn_text'] ?? 'متوجه شدم').toString();
  final closeColor = parseHexColor(feedback['close_btn_color'], const Color(0xFFA0A0B0));
  final actionBtn = _sfMap(feedback['action_btn']);
  final actionText = (actionBtn['text'] ?? actionBtn['label'] ?? '').toString().trim();

  await showDialog<void>(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: dlgBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: dlgBorder, width: 1.2),
        ),
        title: Row(
          children: [
            if (iconName.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(resolveStorefrontIcon(iconName), color: iconColor, size: 20),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                title.isNotEmpty ? title : 'توجه',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: titleColor),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(fontSize: 12.8, color: msgColor, height: 1.65),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        actions: [
          if (actionText.isNotEmpty && onAction != null) ...[
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(closeText, style: TextStyle(color: closeColor, fontSize: 12.5, fontWeight: FontWeight.w700)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await onAction(actionBtn);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: parseHexColor(actionBtn['bg_color'], const Color(0xFFFF3B5C)),
                foregroundColor: parseHexColor(actionBtn['text_color'], Colors.white),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              child: Text(actionText, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
            ),
          ] else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: parseHexColor(feedback['close_btn_bg_color'], const Color(0xFF1A1A28)),
                  foregroundColor: parseHexColor(feedback['close_btn_text_color'], Colors.white),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: dlgBorder.withOpacity(0.5)),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                ),
                child: Text(closeText, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              ),
            ),
        ],
      ),
    ),
  );
}

class StorefrontRuleResult {
  final String action; // 'allow' | 'block' | 'upgrade'
  final Map<String, dynamic> feedback;
  const StorefrontRuleResult({required this.action, required this.feedback});
}

bool _sfRuleMatches(
  Map<String, dynamic> rule, {
  required String userState,
  required String userTier,
  required String targetTier,
  required String accessTier,
  required String packageKey,
}) {
  List<String> _normList(dynamic raw) {
    if (raw is List) {
      final res = raw.map((e) => e.toString().trim().toLowerCase()).where((e) => e.isNotEmpty).toList();
      return res.isEmpty ? ['all'] : res;
    }
    return ['all'];
  }

  final uStates = _normList(rule['user_states']);
  if (!uStates.contains('all') && !uStates.contains(userState)) return false;

  final uTiers = _normList(rule['user_tiers']);
  if (!uTiers.contains('all') && !uTiers.contains(userTier)) return false;

  final tTiers = _normList(rule['target_tiers']);
  if (!tTiers.contains('all') && !tTiers.contains(targetTier) && !tTiers.contains(accessTier)) return false;

  final aTiers = _normList(rule['target_access_tiers']);
  if (!aTiers.contains('all') && !aTiers.contains(accessTier)) return false;

  final pKeys = _normList(rule['package_keys']);
  if (!pKeys.contains('all') && !pKeys.contains(packageKey)) return false;

  return true;
}

StorefrontRuleResult evaluateStorefrontSubscriptionRule({
  required Map<String, dynamic> storefrontConfig,
  required Map<String, dynamic> option,
  required Map<String, dynamic> planBlock,
  required Map<String, dynamic>? userData,
}) {
  final messages = _sfMap(storefrontConfig['messages']);
  final globalRules = _sfMap(storefrontConfig['subscription_rules']);
  final optRules = _sfMap(option['rules']);
  final blkRules = _sfMap(planBlock['rules']);

  final enabled = _sfBool(option['enabled'], true);
  final targetTier = (planBlock['tier'] ?? option['tier'] ?? 'pro').toString().trim().toLowerCase();
  final accessTier = (option['access_tier'] ?? planBlock['access_tier'] ?? (targetTier == 'plus' ? 'plus' : 'pro')).toString().trim().toLowerCase();
  final months = _sfInt(option['months'], 1);
  final rawPk = (option['package_key'] ?? '').toString().trim().toLowerCase();
  final packageKey = rawPk.isNotEmpty ? rawPk : '${targetTier}_${months}m';
  final planTitle = (option['invoice_title'] ?? option['short_title'] ?? planBlock['short_title'] ?? planBlock['title'] ?? '').toString();

  final vars = <String, dynamic>{
    'tier': (userData?['plan_tier'] ?? '').toString().toUpperCase(),
    'remaining': (userData?['remaining_text'] ?? '').toString(),
    'username': (userData?['username'] ?? userData?['display_name'] ?? 'کاربر').toString(),
    'target_tier': accessTier.toUpperCase(),
    'plan_title': planTitle,
  };

  if (!enabled) {
    final rawFb = option['disabled_feedback'] ??
        ((option['disabled_message'] ?? '').toString().trim().isNotEmpty ? option['disabled_message'] : null);
    final fb = resolveStorefrontFeedback(
      rawFb,
      messages,
      fallbackKey: 'option_disabled',
      fallbackText: 'این بسته در حال حاضر غیرفعال است.',
      vars: vars,
    );
    return StorefrontRuleResult(action: 'block', feedback: fb);
  }

  if (userData == null) {
    return const StorefrontRuleResult(action: 'allow', feedback: {'mode': 'silent', 'message': ''});
  }

  final isExpired = userData['is_expired'] == true;
  final isTrial = userData['is_trial'] == true;
  final userState = isExpired ? 'expired' : (isTrial ? 'trial' : 'active_paid');
  final userTier = (userData['plan_tier'] ?? '').toString().trim().toLowerCase();

  String namedSlot = '';
  String defaultMsgKey = 'same_tier_blocked';
  String defaultMsgText = 'در وضعیت فعلی امکان خرید این پلن وجود ندارد.';
  if (userState == 'trial') {
    namedSlot = 'trial_purchase';
    defaultMsgKey = 'trial_purchase_blocked';
    defaultMsgText = 'در دوره تست امکان خرید این پلن وجود ندارد.';
  } else if (userState == 'expired') {
    namedSlot = 'expired_purchase';
    defaultMsgKey = 'expired_purchase_blocked';
    defaultMsgText = 'در وضعیت فعلی امکان خرید این پلن وجود ندارد.';
  } else {
    if (userTier == 'pro' && accessTier == 'plus') {
      namedSlot = 'pro_to_plus';
      defaultMsgKey = 'downgrade_blocked';
      defaultMsgText = 'اشتراک فعال شما PRO است و امکان تمدید یا تغییر به پلن پایین‌تر (Plus) وجود ندارد.';
    } else if (userTier == 'plus' && accessTier == 'pro') {
      namedSlot = 'plus_to_pro';
      defaultMsgKey = 'plus_to_pro_blocked';
      defaultMsgText = 'امکان خرید بسته PRO برای اشتراک فعال PLUS وجود ندارد؛ جهت ارتقا لطفاً از طریق پنل کاربری وب‌سایت اقدام فرمایید.';
    } else if (userTier == 'pro' && accessTier == 'pro') {
      namedSlot = 'pro_to_pro';
      defaultMsgKey = 'same_tier_blocked';
    } else if (userTier == 'plus' && accessTier == 'plus') {
      namedSlot = 'plus_to_plus';
      defaultMsgKey = 'same_tier_blocked';
    }
  }

  StorefrontRuleResult _fromRuleMap(Map<String, dynamic> r) {
    final act = (r['action'] ?? 'allow').toString().trim().toLowerCase();
    if (act == 'block' || act == 'upgrade') {
      final rawFb = r['feedback'] ?? r['message'];
      final fk = (r['feedback_key'] ?? defaultMsgKey).toString().trim();
      final fb = resolveStorefrontFeedback(
        rawFb,
        messages,
        fallbackKey: fk.isNotEmpty ? fk : defaultMsgKey,
        fallbackText: defaultMsgText,
        vars: vars,
      );
      return StorefrontRuleResult(action: act, feedback: fb);
    }
    return const StorefrontRuleResult(action: 'allow', feedback: {'mode': 'silent', 'message': ''});
  }

  for (final scope in [optRules, blkRules]) {
    for (final rawCr in _sfList(scope['custom_rules'])) {
      final cr = _sfMap(rawCr);
      if (cr.isNotEmpty &&
          _sfRuleMatches(cr, userState: userState, userTier: userTier, targetTier: targetTier, accessTier: accessTier, packageKey: packageKey)) {
        return _fromRuleMap(cr);
      }
    }
    if (namedSlot.isNotEmpty) {
      final sr = _sfMap(scope[namedSlot]);
      if (sr.isNotEmpty) return _fromRuleMap(sr);
    }
  }

  for (final rawCr in _sfList(globalRules['custom_rules'])) {
    final cr = _sfMap(rawCr);
    if (cr.isNotEmpty &&
        _sfRuleMatches(cr, userState: userState, userTier: userTier, targetTier: targetTier, accessTier: accessTier, packageKey: packageKey)) {
      return _fromRuleMap(cr);
    }
  }

  if (namedSlot == 'pro_to_plus' && option['allow_downgrade'] == true) {
    return const StorefrontRuleResult(action: 'allow', feedback: {'mode': 'silent', 'message': ''});
  }

  if (namedSlot.isNotEmpty) {
    final sr = _sfMap(globalRules[namedSlot]);
    if (sr.isNotEmpty) return _fromRuleMap(sr);
  }

  if (namedSlot == 'pro_to_plus') {
    return StorefrontRuleResult(
      action: 'block',
      feedback: resolveStorefrontFeedback(null, messages, fallbackKey: 'downgrade_blocked', fallbackText: defaultMsgText, vars: vars),
    );
  }
  final upForTiers = _sfList(planBlock['upgrade_for_tiers']).map((e) => e.toString().trim().toLowerCase()).toList();
  final requireUpgradeFromPlus = option['require_upgrade_from_plus'] != false;
  if (namedSlot == 'plus_to_pro' && upForTiers.contains('plus') && requireUpgradeFromPlus) {
    return const StorefrontRuleResult(action: 'upgrade', feedback: {'mode': 'silent', 'message': ''});
  }

  return const StorefrontRuleResult(action: 'allow', feedback: {'mode': 'silent', 'message': ''});
}

bool isStorefrontBlockVisible(
  Map<String, dynamic> block, {
  required String? userToken,
  required Map<String, dynamic>? userData,
}) {
  if (!_sfBool(block['visible'], true)) return false;

  final rawVis = block['visibility'];
  final List<String> rules;
  if (rawVis is List) {
    rules = rawVis.map((e) => e.toString().trim().toLowerCase()).where((e) => e.isNotEmpty).toList();
  } else {
    final s = (rawVis ?? 'all').toString().trim().toLowerCase();
    rules = s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }
  if (rules.isEmpty || rules.contains('all')) return true;

  final isLoggedIn = userToken != null && userToken.isNotEmpty;
  final isExpired = userData?['is_expired'] == true;
  final isTrial = userData?['is_trial'] == true;
  final isActivePaid = isLoggedIn && userData != null && !isExpired && !isTrial;
  final userTier = (userData?['plan_tier'] ?? '').toString().trim().toLowerCase();

  for (final r in rules) {
    if (r == 'guest' && !isLoggedIn) return true;
    if (r == 'logged_in' && isLoggedIn) return true;
    if (r == 'trial' && isLoggedIn && !isExpired && isTrial) return true;
    if (r == 'expired' && isLoggedIn && isExpired) return true;
    if (r == 'active_paid' && isActivePaid) return true;
    if (r.startsWith('tier:')) {
      final target = r.substring(5).trim();
      if (isActivePaid && userTier == target) return true;
    }
    if (r.startsWith('not_tier:')) {
      final target = r.substring(9).trim();
      if (!(isActivePaid && userTier == target)) return true;
    }
  }
  return false;
}

BoxDecoration buildStorefrontDecoration(
  Map<String, dynamic> style, {
  Color defaultBg = const Color(0xFF0E0E14),
  Color defaultBorder = const Color(0x1AFFFFFF),
  double defaultBorderWidth = 1.0,
  double defaultRadius = 14.0,
}) {
  final gradRaw = _sfList(style['gradient_colors'])
      .map((e) => parseHexColor(e, Colors.transparent))
      .where((c) => c != Colors.transparent)
      .toList();
  final bgColor = parseHexColor(style['bg_color'], defaultBg);
  final borderColor = parseHexColor(style['border_color'], defaultBorder);
  final borderWidth = _sfDouble(style['border_width'], defaultBorderWidth);
  final radius = _sfDouble(style['border_radius'], defaultRadius);
  final shadowHex = (style['shadow_color'] ?? '').toString().trim();
  final shadowColor = shadowHex.isNotEmpty ? parseHexColor(shadowHex, Colors.transparent) : Colors.transparent;

  return BoxDecoration(
    color: gradRaw.length >= 2 ? null : bgColor,
    gradient: gradRaw.length >= 2
        ? LinearGradient(
            colors: gradRaw,
            begin: parseAlignment(style['gradient_begin'], Alignment.topRight),
            end: parseAlignment(style['gradient_end'], Alignment.bottomLeft),
          )
        : null,
    borderRadius: BorderRadius.circular(radius),
    border: (borderWidth > 0 && borderColor != Colors.transparent)
        ? Border.all(color: borderColor, width: borderWidth)
        : null,
    boxShadow: (shadowColor != Colors.transparent)
        ? [
            BoxShadow(
              color: shadowColor,
              blurRadius: _sfDouble(style['shadow_blur'], 12.0),
              spreadRadius: _sfDouble(style['shadow_spread'], 0.0),
            ),
          ]
        : null,
  );
}

class StorefrontPlansView extends StatelessWidget {
  final Map<String, dynamic> remoteConfig;
  final String? userToken;
  final Map<String, dynamic>? userData;
  final bool isLoadingConfig;
  final Future<void> Function() onRefresh;
  final Future<void> Function(Map<String, dynamic> option, Map<String, dynamic> planBlock) onPurchaseOption;
  final Future<void> Function(String packageKey) onBuyPackageByKey;
  final Future<void> Function() onUpgrade;
  final VoidCallback onRequireAuth;
  final void Function(int tabIndex) onSwitchTab;
  final Future<void> Function(String url) onLaunchUrl;
  final void Function(String message) onShowToast;

  const StorefrontPlansView({
    super.key,
    required this.remoteConfig,
    required this.userToken,
    required this.userData,
    required this.isLoadingConfig,
    required this.onRefresh,
    required this.onPurchaseOption,
    required this.onBuyPackageByKey,
    required this.onUpgrade,
    required this.onRequireAuth,
    required this.onSwitchTab,
    required this.onLaunchUrl,
    required this.onShowToast,
  });

  @override
  Widget build(BuildContext context) {
    final sf = _sfMap(remoteConfig['storefront']).isNotEmpty
        ? _sfMap(remoteConfig['storefront'])
        : _sfMap(_sfMap(remoteConfig['ui_config'])['storefront']);

    final page = _sfMap(sf['page']);
    final messages = _sfMap(sf['messages']);
    final loadingText = (page['loading_text'] ?? 'در حال دریافت اطلاعات پلن‌ها و ظاهر فروشگاه از سرور...').toString();
    final errTitle = (page['error_title'] ?? 'عدم دریافت اطلاعات فروشگاه از سرور').toString();
    final errSub = (page['error_subtitle'] ?? 'لطفاً اتصال اینترنت خود را بررسی کرده و مجدداً تلاش فرمایید.').toString();
    final errRetry = (page['error_retry_btn'] ?? 'تلاش مجدد').toString();

    if (sf.isEmpty || _sfList(sf['blocks']).isEmpty && isLoadingConfig) {
      if (sf.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoadingConfig) ...[
                  const CircularProgressIndicator(color: Color(0xFFFF3B5C)),
                  const SizedBox(height: 16),
                  Text(
                    loadingText,
                    style: const TextStyle(fontSize: 13, color: Color(0xFFA0A0B0)),
                    textAlign: TextAlign.center,
                  ),
                ] else ...[
                  const Icon(Icons.cloud_off_rounded, size: 46, color: Color(0xFFA0A0B0)),
                  const SizedBox(height: 12),
                  Text(
                    errTitle,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    errSub,
                    style: const TextStyle(fontSize: 12, color: Color(0xFFA0A0B0)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(errRetry, style: const TextStyle(fontWeight: FontWeight.w800)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF3B5C),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }
    }

    final blocks = _sfList(sf['blocks']);
    final padH = _sfDouble(page['padding_horizontal'], 20.0);
    final padV = _sfDouble(page['padding_vertical'], 16.0);
    final pageGrad = _sfList(page['bg_gradient_colors'])
        .map((e) => parseHexColor(e, Colors.transparent))
        .where((c) => c != Colors.transparent)
        .toList();
    final pageBg = parseHexColor(page['bg_color'], const Color(0xFF060608));

    final children = <Widget>[];
    if (_sfBool(page['show_header'], true)) {
      children.add(_buildPageHeader(page));
      children.add(SizedBox(height: _sfDouble(page['header_bottom_spacing'], 18.0)));
    }

    int visibleCount = 0;
    for (final rawBlk in blocks) {
      final blk = _sfMap(rawBlk);
      if (blk.isEmpty) continue;
      if (!isStorefrontBlockVisible(blk, userToken: userToken, userData: userData)) continue;
      final widget = _buildBlock(context, blk, messages: messages, page: page);
      if (widget == null) continue;
      visibleCount++;
      final mTop = _sfDouble(blk['margin_top'], 0.0);
      final mBot = _sfDouble(blk['margin_bottom'], 18.0);
      children.add(
        Padding(
          padding: EdgeInsets.only(top: mTop, bottom: mBot),
          child: widget,
        ),
      );
    }

    if (visibleCount == 0) {
      children.add(
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF0E0E14),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0x1AFFFFFF)),
          ),
          child: Text(
            (page['empty_state_text'] ?? 'در حال حاضر پلنی برای نمایش وجود ندارد.').toString(),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFA0A0B0), fontSize: 13),
          ),
        ),
      );
    }

    Widget listView = ListView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      children: children,
    );

    if (_sfBool(page['pull_to_refresh'], true)) {
      listView = RefreshIndicator(
        onRefresh: onRefresh,
        color: const Color(0xFFFF3B5C),
        backgroundColor: const Color(0xFF14141E),
        child: listView,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: pageGrad.length >= 2 ? null : pageBg,
        gradient: pageGrad.length >= 2
            ? LinearGradient(
                colors: pageGrad,
                begin: parseAlignment(page['bg_gradient_begin'], Alignment.topCenter),
                end: parseAlignment(page['bg_gradient_end'], Alignment.bottomCenter),
              )
            : null,
      ),
      child: listView,
    );
  }

  Widget _buildPageHeader(Map<String, dynamic> page) {
    final title = (page['header_title'] ?? 'پلن‌های تجاری و اشتراک RyzerDNS').toString();
    final subtitle = (page['header_subtitle'] ?? '').toString();
    final badgeText = (page['header_badge_text'] ?? '').toString().trim();
    final align = parseCrossAlign(page['header_align'], CrossAxisAlignment.start);
    final tAlign = parseTextAlign(page['header_align'], TextAlign.start);

    final content = Column(
      crossAxisAlignment: align,
      children: [
        Row(
          mainAxisAlignment: align == CrossAxisAlignment.center
              ? MainAxisAlignment.center
              : (align == CrossAxisAlignment.end ? MainAxisAlignment.end : MainAxisAlignment.spaceBetween),
          children: [
            Flexible(
              child: Text(
                title,
                textAlign: tAlign,
                style: TextStyle(
                  fontSize: _sfDouble(page['header_title_size'], 16.0),
                  fontWeight: parseFontWeight(page['header_title_weight'], FontWeight.w900),
                  color: parseHexColor(page['header_title_color'], Colors.white),
                ),
              ),
            ),
            if (badgeText.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: parseHexColor(page['header_badge_bg'], const Color(0x1AFF3B5C)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: parseHexColor(page['header_badge_color'], const Color(0xFFFF3B5C)),
                  ),
                ),
              ),
            ],
          ],
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: tAlign,
            style: TextStyle(
              fontSize: _sfDouble(page['header_subtitle_size'], 12.0),
              color: parseHexColor(page['header_subtitle_color'], const Color(0xFFA0A0B0)),
              height: 1.4,
            ),
          ),
        ],
      ],
    );

    if (_sfBool(page['header_as_card'], false)) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(_sfDouble(page['header_padding'], 16.0)),
        decoration: BoxDecoration(
          color: parseHexColor(page['header_bg_color'], const Color(0xFF0E0E14)),
          borderRadius: BorderRadius.circular(_sfDouble(page['header_border_radius'], 14.0)),
          border: Border.all(
            color: parseHexColor(page['header_border_color'], const Color(0x1AFFFFFF)),
            width: _sfDouble(page['header_border_width'], 1.0),
          ),
        ),
        child: content,
      );
    }
    return content;
  }

  Future<void> _dispatchFeedbackAction(BuildContext context, Map<String, dynamic> act) async {
    final t = (act['type'] ?? act['action_type'] ?? '').toString().trim().toLowerCase();
    final target = (act['target'] ?? '').toString().trim();
    switch (t) {
      case 'open_url':
        final u = (act['url'] ?? target).toString().trim();
        if (u.isNotEmpty) onLaunchUrl(u);
        break;
      case 'switch_tab':
        final idx = _sfInt(act['tab_index'] ?? target, 0);
        onSwitchTab(idx.clamp(0, 3));
        break;
      case 'open_auth':
        onRequireAuth();
        break;
      case 'open_upgrade':
        onUpgrade();
        break;
      case 'copy':
      case 'copy_text':
        final val = (act['copy_value'] ?? target).toString();
        if (val.isNotEmpty) {
          Clipboard.setData(ClipboardData(text: val));
          onShowToast((act['toast_text'] ?? 'کپی شد: $val').toString());
        }
        break;
      case 'refresh':
        onRefresh();
        break;
      default:
        break;
    }
  }

  Widget? _buildBlock(
    BuildContext context,
    Map<String, dynamic> block, {
    Map<String, dynamic> messages = const {},
    Map<String, dynamic> page = const {},
  }) {
    final type = (block['type'] ?? '').toString().trim().toLowerCase();
    switch (type) {
      case 'upgrade_card':
        return _buildUpgradeCardBlock(context, block, messages: messages);
      case 'active_status':
        return _buildActiveStatusBlock(block);
      case 'plan':
        return _buildPlanBlock(context, block, messages: messages, page: page);
      case 'custom_box':
        return _buildCustomBoxBlock(context, block);
      case 'grid_row':
        return _buildGridRowBlock(context, block, messages: messages, page: page);
      case 'section_header':
        return _buildSectionHeaderBlock(block);
      case 'divider':
        return Divider(
          color: parseHexColor(block['color'], const Color(0x1AFFFFFF)),
          thickness: _sfDouble(block['thickness'], 1.0),
          height: _sfDouble(block['height'], 16.0),
        );
      case 'spacer':
        return SizedBox(height: _sfDouble(block['height'], 12.0));
      default:
        return null;
    }
  }

  Widget? _buildUpgradeCardBlock(
    BuildContext context,
    Map<String, dynamic> block, {
    Map<String, dynamic> messages = const {},
  }) {
    final isLoggedIn = userToken != null && userToken!.isNotEmpty;
    final isExpired = userData?['is_expired'] == true;
    final isTrial = userData?['is_trial'] == true;
    final isActivePaid = isLoggedIn && userData != null && !isExpired && !isTrial;
    if (!isActivePaid) return null;

    final userTier = (userData?['plan_tier'] ?? '').toString().trim().toLowerCase();
    final showForTiers = _sfList(block['show_for_tiers']).map((e) => e.toString().trim().toLowerCase()).toList();
    final maxTierList = _sfList(block['max_tier_list']).map((e) => e.toString().trim().toLowerCase()).toList();

    if (showForTiers.contains(userTier)) {
      final st = _sfMap(block['upgrade_state']);
      final iconName = (st['icon'] ?? 'upgrade').toString();
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: _sfDouble(st['padding_h'], 16.0),
          vertical: _sfDouble(st['padding_v'], 16.0),
        ),
        decoration: buildStorefrontDecoration(
          st,
          defaultBg: const Color(0xFF0E0E14),
          defaultBorder: const Color(0x80FFAB00),
          defaultBorderWidth: 1.2,
          defaultRadius: 14.0,
        ),
        child: Row(
          children: [
            if (iconName.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: parseHexColor(st['icon_bg_color'], const Color(0x33FFAB00)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  resolveStorefrontIcon(iconName),
                  color: parseHexColor(st['icon_color'], const Color(0xFFFFAB00)),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (st['title'] ?? 'ارتقای اشتراک به Ryzer PRO').toString(),
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      color: parseHexColor(st['title_color'], Colors.white),
                    ),
                  ),
                  if ((st['subtitle'] ?? '').toString().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      st['subtitle'].toString(),
                      style: TextStyle(
                        fontSize: 11,
                        color: parseHexColor(st['subtitle_color'], const Color(0xFFFFD54F)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: onUpgrade,
              style: ElevatedButton.styleFrom(
                backgroundColor: parseHexColor(st['btn_bg_color'], const Color(0xFFFFAB00)),
                foregroundColor: parseHexColor(st['btn_text_color'], Colors.black),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_sfDouble(st['btn_border_radius'], 8.0)),
                ),
                elevation: 0,
              ),
              child: Text(
                (st['button_text'] ?? 'ارتقا').toString(),
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      );
    }

    if (maxTierList.contains(userTier) && _sfBool(block['show_when_max_tier'], true)) {
      final st = _sfMap(block['max_tier_state']);
      final iconName = (st['icon'] ?? 'verified').toString();
      final trailingName = (st['trailing_icon'] ?? 'lock_outline').toString();
      final maxCard = Container(
        padding: EdgeInsets.symmetric(
          horizontal: _sfDouble(st['padding_h'], 16.0),
          vertical: _sfDouble(st['padding_v'], 13.0),
        ),
        decoration: buildStorefrontDecoration(
          st,
          defaultBg: const Color(0xFF0E0E14),
          defaultBorder: const Color(0x1AFFFFFF),
          defaultBorderWidth: 1.0,
          defaultRadius: 14.0,
        ),
        child: Row(
          children: [
            if (iconName.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: parseHexColor(st['icon_bg_color'], const Color(0x1A00E676)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  resolveStorefrontIcon(iconName),
                  color: parseHexColor(st['icon_color'], const Color(0xFF00E676)),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (st['title'] ?? 'ارتقای اشتراک').toString(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: parseHexColor(st['title_color'], Colors.white70),
                    ),
                  ),
                  if ((st['subtitle'] ?? '').toString().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      st['subtitle'].toString(),
                      style: TextStyle(
                        fontSize: 11,
                        color: parseHexColor(st['subtitle_color'], const Color(0xFF8E8EA8)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailingName.isNotEmpty)
              Icon(
                resolveStorefrontIcon(trailingName),
                color: parseHexColor(st['trailing_icon_color'], const Color(0xFF555566)),
                size: 18,
              ),
          ],
        ),
      );
      final tapFbRaw = st['tap_feedback'] ?? st['tap_message'];
      if (tapFbRaw != null && tapFbRaw.toString().trim().isNotEmpty) {
        return GestureDetector(
          onTap: () {
            final fb = resolveStorefrontFeedback(tapFbRaw, messages);
            showServerFeedback(
              context,
              fb,
              onToast: onShowToast,
              onAction: (act) => _dispatchFeedbackAction(context, act),
            );
          },
          child: maxCard,
        );
      }
      return maxCard;
    }

    return null;
  }

  Widget _buildActiveStatusBlock(Map<String, dynamic> block) {
    final cs = _sfMap(block['card_style']);
    final isLoggedIn = userToken != null && userToken!.isNotEmpty;
    final isExpired = userData?['is_expired'] == true;
    final isTrial = userData?['is_trial'] == true;
    final userTier = (userData?['plan_tier'] ?? '').toString().trim().toLowerCase();

    String titleRaw;
    String subRaw;
    if (!isLoggedIn) {
      titleRaw = (block['guest_title'] ?? 'وارد حساب کاربری نشده‌اید').toString();
      subRaw = (block['guest_subtitle'] ?? 'جهت خرید اشتراک وارد حساب شوید').toString();
    } else if (isExpired) {
      titleRaw = (block['expired_title'] ?? block['title'] ?? 'وضعیت اشتراک: {tier}').toString();
      subRaw = (block['expired_subtitle'] ?? block['subtitle'] ?? 'زمان باقی‌مانده: {remaining}').toString();
    } else if (isTrial) {
      titleRaw = (block['trial_title'] ?? block['title'] ?? 'وضعیت اشتراک: {tier}').toString();
      subRaw = (block['trial_subtitle'] ?? block['subtitle'] ?? 'زمان باقی‌مانده: {remaining}').toString();
    } else if (userTier == 'plus') {
      titleRaw = (block['plus_title'] ?? block['title'] ?? 'وضعیت اشتراک: {tier}').toString();
      subRaw = (block['plus_subtitle'] ?? block['subtitle'] ?? 'زمان باقی‌مانده: {remaining}').toString();
    } else if (userTier == 'pro') {
      titleRaw = (block['pro_title'] ?? block['title'] ?? 'وضعیت اشتراک: {tier}').toString();
      subRaw = (block['pro_subtitle'] ?? block['subtitle'] ?? 'زمان باقی‌مانده: {remaining}').toString();
    } else {
      titleRaw = (block['title'] ?? 'وضعیت اشتراک: {tier}').toString();
      subRaw = (block['subtitle'] ?? 'زمان باقی‌مانده: {remaining}').toString();
    }

    final title = resolveStorefrontTemplate(titleRaw, userToken: userToken, userData: userData);
    final subtitle = resolveStorefrontTemplate(subRaw, userToken: userToken, userData: userData);
    final iconName = (block['icon'] ?? 'verified').toString();
    final guestBtnText = (block['guest_btn_text'] ?? 'ورود').toString();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _sfDouble(cs['padding_h'], 16.0),
        vertical: _sfDouble(cs['padding_v'], 14.0),
      ),
      decoration: buildStorefrontDecoration(
        cs,
        defaultBg: const Color(0xFF0E0E14),
        defaultBorder: const Color(0x3300E676),
        defaultBorderWidth: 1.2,
        defaultRadius: 14.0,
      ),
      child: Row(
        children: [
          if (iconName.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: parseHexColor(block['icon_bg_color'], const Color(0x1A00E676)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                resolveStorefrontIcon(iconName),
                color: parseHexColor(block['icon_color'], const Color(0xFF00E676)),
                size: _sfDouble(block['icon_size'], 22.0),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: _sfDouble(cs['title_size'], 13.5),
                    fontWeight: FontWeight.w800,
                    color: parseHexColor(cs['title_color'], Colors.white),
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: _sfDouble(cs['subtitle_size'], 11.5),
                      color: parseHexColor(cs['subtitle_color'], const Color(0xFF00E676)),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!isLoggedIn)
            TextButton(
              onPressed: onRequireAuth,
              child: Text(guestBtnText, style: const TextStyle(color: Color(0xFFFF3B5C), fontWeight: FontWeight.w800)),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeaderBlock(Map<String, dynamic> block) {
    final title = (block['title'] ?? '').toString();
    final subtitle = (block['subtitle'] ?? '').toString();
    final align = parseCrossAlign(block['align'], CrossAxisAlignment.start);
    final tAlign = parseTextAlign(block['align'], TextAlign.start);
    return Column(
      crossAxisAlignment: align,
      children: [
        if (title.isNotEmpty)
          Text(
            title,
            textAlign: tAlign,
            style: TextStyle(
              fontSize: _sfDouble(block['title_size'], 14.5),
              fontWeight: FontWeight.w900,
              color: parseHexColor(block['title_color'], Colors.white),
            ),
          ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            subtitle,
            textAlign: tAlign,
            style: TextStyle(
              fontSize: _sfDouble(block['subtitle_size'], 11.5),
              color: parseHexColor(block['subtitle_color'], const Color(0xFFA0A0B0)),
            ),
          ),
        ],
      ],
    );
  }

  Widget? _buildGridRowBlock(
    BuildContext context,
    Map<String, dynamic> block, {
    Map<String, dynamic> messages = const {},
    Map<String, dynamic> page = const {},
  }) {
    final cols = _sfList(block['columns']);
    final spacing = _sfDouble(block['spacing'], 12.0);
    final visibleWidgets = <Widget>[];
    for (final rawCol in cols) {
      final colMap = _sfMap(rawCol);
      if (colMap.isEmpty) continue;
      if (!isStorefrontBlockVisible(colMap, userToken: userToken, userData: userData)) continue;
      final w = _buildBlock(context, colMap, messages: messages, page: page);
      if (w != null) visibleWidgets.add(w);
    }
    if (visibleWidgets.isEmpty) return null;

    final rowChildren = <Widget>[];
    for (int i = 0; i < visibleWidgets.length; i++) {
      rowChildren.add(Expanded(child: visibleWidgets[i]));
      if (i < visibleWidgets.length - 1) {
        rowChildren.add(SizedBox(width: spacing));
      }
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rowChildren,
    );
  }

  Widget _buildPlanBlock(
    BuildContext context,
    Map<String, dynamic> block, {
    Map<String, dynamic> messages = const {},
    Map<String, dynamic> page = const {},
  }) {
    final cs = _sfMap(block['card_style']);
    final badge = _sfMap(block['badge']);
    final features = _sfList(block['features']);
    final options = _sfList(block['options']);
    final radius = _sfDouble(cs['border_radius'], 14.0);
    final ribbonText = (block['ribbon_text'] ?? '').toString().trim();
    final iconName = (block['icon'] ?? '').toString().trim();
    final title = (block['title'] ?? 'پلن اشتراک').toString();
    final subtitle = (block['subtitle'] ?? '').toString().trim();
    final footerNote = (block['footer_note'] ?? '').toString().trim();
    final currencyLabel = (page['currency_label'] ?? 'تومان').toString();

    final isLoggedIn = userToken != null && userToken!.isNotEmpty;
    final isExpired = userData?['is_expired'] == true;
    final isTrial = userData?['is_trial'] == true;
    final isActivePaid = isLoggedIn && userData != null && !isExpired && !isTrial;
    final userTier = (userData?['plan_tier'] ?? '').toString().trim().toLowerCase();

    final lockedFor = _sfList(block['locked_for_tiers']).map((e) => e.toString().trim().toLowerCase()).toList();
    final upgradeFor = _sfList(block['upgrade_for_tiers']).map((e) => e.toString().trim().toLowerCase()).toList();

    final showLocked = isActivePaid && lockedFor.contains(userTier);
    final showUpgrade = !showLocked && isActivePaid && upgradeFor.contains(userTier);

    Widget actionArea;
    if (showLocked) {
      final ln = _sfMap(block['locked_notice']);
      final lockIcon = (ln['icon'] ?? 'block').toString();
      final lockTextRaw = (ln['text'] ?? 'این پلن برای اشتراک فعلی شما غیرقابل انتخاب است.').toString();
      final lockText = resolveStorefrontTemplate(lockTextRaw, userToken: userToken, userData: userData);
      final lockBox = Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: _sfDouble(ln['padding_v'], 12.0), horizontal: 12),
        decoration: BoxDecoration(
          color: parseHexColor(ln['bg_color'], const Color(0x0AFFFFFF)),
          borderRadius: BorderRadius.circular(_sfDouble(ln['border_radius'], 8.0)),
          border: Border.all(color: parseHexColor(ln['border_color'], const Color(0x1AFFFFFF))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (lockIcon.isNotEmpty) ...[
              Icon(
                resolveStorefrontIcon(lockIcon),
                size: 14,
                color: parseHexColor(ln['icon_color'], const Color(0xFF8E8EA8)),
              ),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                lockText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: parseHexColor(ln['text_color'], const Color(0xFF8E8EA8)),
                ),
              ),
            ),
          ],
        ),
      );
      final tapFbRaw = ln['tap_feedback'] ?? ln['feedback'] ?? ln['tap_message'];
      if (tapFbRaw != null && tapFbRaw.toString().trim().isNotEmpty) {
        actionArea = InkWell(
          borderRadius: BorderRadius.circular(_sfDouble(ln['border_radius'], 8.0)),
          onTap: () {
            final fb = resolveStorefrontFeedback(tapFbRaw, messages, fallbackKey: 'plan_locked');
            showServerFeedback(
              context,
              fb,
              onToast: onShowToast,
              onAction: (act) => _dispatchFeedbackAction(context, act),
            );
          },
          child: lockBox,
        );
      } else {
        actionArea = lockBox;
      }
    } else if (showUpgrade) {
      final ub = _sfMap(block['upgrade_button']);
      final upIcon = (ub['icon'] ?? 'upgrade').toString();
      actionArea = SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onUpgrade,
          icon: upIcon.isNotEmpty ? Icon(resolveStorefrontIcon(upIcon), size: 16) : const SizedBox.shrink(),
          label: Text(
            (ub['text'] ?? 'ارتقا به پلن PRO (مابه‌التفاوت)').toString(),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: parseHexColor(ub['bg_color'], const Color(0xFFFFAB00)),
            foregroundColor: parseHexColor(ub['text_color'], Colors.black),
            padding: EdgeInsets.symmetric(vertical: _sfDouble(ub['padding_v'], 10.0)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_sfDouble(ub['border_radius'], 8.0)),
            ),
            elevation: 0,
          ),
        ),
      );
    } else {
      actionArea = _buildPlanOptionsArea(block, options, isActivePaid: isActivePaid, currencyLabel: currencyLabel);
    }

    final defaultFeatIcon = (cs['feature_icon'] ?? 'check_circle').toString();
    final defaultFeatIconColor = parseHexColor(cs['feature_icon_color'], const Color(0xFF00E676));
    final defaultFeatIconSize = _sfDouble(cs['feature_icon_size'], 14.0);
    final defaultFeatTextColor = parseHexColor(cs['feature_text_color'], const Color(0xFFD0D0E0));
    final defaultFeatFontSize = _sfDouble(cs['feature_font_size'], 12.0);
    final featSpacing = _sfDouble(cs['feature_spacing'], 6.0);

    final innerCard = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Row(
                children: [
                  if (iconName.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: parseHexColor(block['icon_bg_color'], const Color(0x1AFF3B5C)),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        resolveStorefrontIcon(iconName),
                        color: parseHexColor(block['icon_color'], const Color(0xFFFF3B5C)),
                        size: _sfDouble(block['icon_size'], 18.0),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: _sfDouble(cs['title_size'], 14.5),
                            fontWeight: parseFontWeight(cs['title_weight'], FontWeight.w900),
                            color: parseHexColor(cs['title_color'], Colors.white),
                          ),
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: _sfDouble(cs['subtitle_size'], 11.5),
                              color: parseHexColor(cs['subtitle_color'], const Color(0xFFA0A0B0)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_sfBool(badge['show'], false) && (badge['text'] ?? '').toString().trim().isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: _sfDouble(badge['padding_h'], 8.0),
                  vertical: _sfDouble(badge['padding_v'], 3.0),
                ),
                decoration: BoxDecoration(
                  color: parseHexColor(badge['bg_color'], const Color(0xFFFF3B5C)),
                  borderRadius: BorderRadius.circular(_sfDouble(badge['border_radius'], 6.0)),
                  border: (_sfDouble(badge['border_width'], 0.0) > 0)
                      ? Border.all(
                          color: parseHexColor(badge['border_color'], Colors.transparent),
                          width: _sfDouble(badge['border_width'], 0.0),
                        )
                      : null,
                ),
                child: Text(
                  badge['text'].toString(),
                  style: TextStyle(
                    fontSize: _sfDouble(badge['font_size'], 10.5),
                    fontWeight: FontWeight.w800,
                    color: parseHexColor(badge['text_color'], Colors.white),
                  ),
                ),
              ),
            ],
          ],
        ),
        if (features.isNotEmpty) const SizedBox(height: 14),
        ...features.map((f) {
          final isObj = f is Map;
          final fm = isObj ? _sfMap(f) : const <String, dynamic>{};
          final fText = isObj ? (fm['text'] ?? '').toString() : f.toString();
          if (fText.trim().isEmpty) return const SizedBox.shrink();
          final fIcon = isObj ? (fm['icon'] ?? defaultFeatIcon).toString() : defaultFeatIcon;
          final fIconColor = isObj
              ? parseHexColor(fm['icon_color'], defaultFeatIconColor)
              : defaultFeatIconColor;
          final fTextColor = isObj
              ? parseHexColor(fm['text_color'], defaultFeatTextColor)
              : defaultFeatTextColor;
          final fSize = isObj ? _sfDouble(fm['font_size'], defaultFeatFontSize) : defaultFeatFontSize;
          final fBold = isObj && _sfBool(fm['bold'], false);

          return Padding(
            padding: EdgeInsets.only(bottom: featSpacing),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (fIcon.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(resolveStorefrontIcon(fIcon), size: defaultFeatIconSize, color: fIconColor),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    fText,
                    style: TextStyle(
                      fontSize: fSize,
                      color: fTextColor,
                      fontWeight: fBold ? FontWeight.w800 : FontWeight.w400,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        if (_sfBool(cs['show_divider'], true))
          Divider(
            color: parseHexColor(cs['divider_color'], const Color(0x1AFFFFFF)),
            height: _sfDouble(cs['divider_height'], 24.0),
          )
        else
          const SizedBox(height: 12),
        actionArea,
        if (footerNote.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            footerNote,
            style: TextStyle(
              fontSize: _sfDouble(block['footer_note_size'], 11.0),
              color: parseHexColor(block['footer_note_color'], const Color(0xFF8E8EA8)),
              height: 1.4,
            ),
          ),
        ],
      ],
    );

    if (ribbonText.isEmpty) {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: _sfDouble(cs['padding_h'], 18.0),
          vertical: _sfDouble(cs['padding_v'], 18.0),
        ),
        decoration: buildStorefrontDecoration(
          cs,
          defaultBg: const Color(0xFF0E0E14),
          defaultBorder: const Color(0x33FFFFFF),
          defaultBorderWidth: 1.0,
          defaultRadius: radius,
        ),
        child: innerCard,
      );
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: buildStorefrontDecoration(
        cs,
        defaultBg: const Color(0xFF0E0E14),
        defaultBorder: const Color(0x33FFFFFF),
        defaultBorderWidth: 1.0,
        defaultRadius: radius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: parseHexColor(block['ribbon_bg_color'], const Color(0xFFFF3B5C)),
            child: Text(
              ribbonText,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: parseHexColor(block['ribbon_text_color'], Colors.white),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: _sfDouble(cs['padding_h'], 18.0),
              vertical: _sfDouble(cs['padding_v'], 18.0),
            ),
            child: innerCard,
          ),
        ],
      ),
    );
  }

  Widget _buildPlanOptionsArea(
    Map<String, dynamic> planBlock,
    List<dynamic> rawOptions, {
    required bool isActivePaid,
    String currencyLabel = 'تومان',
  }) {
    final options = rawOptions.map(_sfMap).where((o) => o.isNotEmpty).toList();
    if (options.isEmpty) return const SizedBox.shrink();

    final layout = (planBlock['options_layout'] ?? 'row').toString().trim().toLowerCase();
    final spacing = _sfDouble(planBlock['options_spacing'], 10.0);

    if (layout == 'column') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < options.length; i++) ...[
            _buildSingleOptionButton(planBlock, options[i], isActivePaid: isActivePaid, currencyLabel: currencyLabel),
            if (i < options.length - 1) SizedBox(height: spacing),
          ],
        ],
      );
    }

    if (layout == 'grid') {
      final cols = _sfInt(planBlock['options_columns'], 2).clamp(1, 4);
      final rows = <Widget>[];
      for (int i = 0; i < options.length; i += cols) {
        final slice = options.sublist(i, (i + cols > options.length) ? options.length : i + cols);
        final rowItems = <Widget>[];
        for (int j = 0; j < slice.length; j++) {
          rowItems.add(Expanded(child: _buildSingleOptionButton(planBlock, slice[j], isActivePaid: isActivePaid, currencyLabel: currencyLabel)));
          if (j < slice.length - 1) rowItems.add(SizedBox(width: spacing));
        }
        // Fill empty space if last row has fewer items
        for (int k = slice.length; k < cols; k++) {
          rowItems.add(SizedBox(width: spacing));
          rowItems.add(const Expanded(child: SizedBox.shrink()));
        }
        rows.add(Row(crossAxisAlignment: CrossAxisAlignment.start, children: rowItems));
        if (i + cols < options.length) rows.add(SizedBox(height: spacing));
      }
      return Column(children: rows);
    }

    // Default 'row'
    final rowWidgets = <Widget>[];
    for (int i = 0; i < options.length; i++) {
      rowWidgets.add(Expanded(child: _buildSingleOptionButton(planBlock, options[i], isActivePaid: isActivePaid, currencyLabel: currencyLabel)));
      if (i < options.length - 1) rowWidgets.add(SizedBox(width: spacing));
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: rowWidgets);
  }

  Widget _buildSingleOptionButton(
    Map<String, dynamic> planBlock,
    Map<String, dynamic> opt, {
    required bool isActivePaid,
    String currencyLabel = 'تومان',
  }) {
    final style = _sfMap(opt['style']);
    final enabled = _sfBool(opt['enabled'], true);
    final silentDisabled = opt['silent_when_disabled'] == true;
    final variant = (style['variant'] ?? 'outlined').toString().trim().toLowerCase();
    final radius = _sfDouble(style['border_radius'], 8.0);
    final padV = _sfDouble(style['padding_v'], 8.0);

    final defaultBg = variant == 'filled' ? const Color(0xFFFF3B5C) : Colors.transparent;
    final defaultBorder = variant == 'filled' ? Colors.transparent : const Color(0x4DFFFFFF);
    final defaultBorderW = variant == 'filled' ? 0.0 : 1.0;

    final gradColors = _sfList(style['gradient_colors'])
        .map((e) => parseHexColor(e, Colors.transparent))
        .where((c) => c != Colors.transparent)
        .toList();
    final bgColor = enabled
        ? parseHexColor(style['bg_color'], defaultBg)
        : const Color(0x14FFFFFF);
    final borderColor = enabled
        ? parseHexColor(style['border_color'], defaultBorder)
        : const Color(0x1AFFFFFF);
    final borderWidth = _sfDouble(style['border_width'], defaultBorderW);
    final textColor = enabled
        ? parseHexColor(style['text_color'], Colors.white)
        : const Color(0xFF707085);
    final subtextColor = enabled
        ? parseHexColor(style['subtext_color'], const Color(0xFFA0A0B0))
        : const Color(0xFF606075);

    final labelBase = (opt['label'] ?? '').toString();
    final renewalLabel = (opt['renewal_label'] ?? '').toString().trim();
    final labelText = (isActivePaid && renewalLabel.isNotEmpty) ? renewalLabel : labelBase;
    final sublabel = (opt['sublabel'] ?? '').toString().trim();
    final priceText = enabled
        ? ((opt['price_text'] ?? '').toString().isNotEmpty
            ? opt['price_text'].toString()
            : formatTomanComma(_sfInt(opt['price'], 0), currencyLabel: currencyLabel))
        : (opt['disabled_text'] ?? 'ناموجود').toString();
    final origPriceText = (opt['original_price_text'] ?? '').toString().trim();
    final discountBadge = (opt['discount_badge'] ?? '').toString().trim();

    return Container(
      decoration: BoxDecoration(
        color: (enabled && gradColors.length >= 2) ? null : bgColor,
        gradient: (enabled && gradColors.length >= 2)
            ? LinearGradient(colors: gradColors, begin: Alignment.topRight, end: Alignment.bottomLeft)
            : null,
        borderRadius: BorderRadius.circular(radius),
        border: (borderWidth > 0 && borderColor != Colors.transparent)
            ? Border.all(color: borderColor, width: borderWidth)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: (enabled || !silentDisabled) ? () => onPurchaseOption(opt, planBlock) : null,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: padV),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (discountBadge.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      color: parseHexColor(opt['discount_badge_bg'], const Color(0xFF00E676)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      discountBadge,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        color: parseHexColor(opt['discount_badge_color'], Colors.black),
                      ),
                    ),
                  ),
                ],
                Text(
                  labelText,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: subtextColor, fontWeight: FontWeight.w600),
                ),
                if (origPriceText.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    origPriceText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      color: subtextColor.withOpacity(0.75),
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  priceText,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: textColor),
                ),
                if (sublabel.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    sublabel,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 9.5, color: subtextColor),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomBoxBlock(BuildContext context, Map<String, dynamic> block) {
    final cs = _sfMap(block['card_style']);
    final badge = _sfMap(block['badge']);
    final bullets = _sfList(block['bullets']);
    final actions = _sfList(block['actions']).map(_sfMap).where((a) => a.isNotEmpty).toList();
    final layout = (block['layout'] ?? 'vertical').toString().trim().toLowerCase();
    final radius = _sfDouble(cs['border_radius'], 14.0);
    final ribbonText = (block['ribbon_text'] ?? '').toString().trim();
    final iconName = (block['icon'] ?? '').toString().trim();

    final title = resolveStorefrontTemplate((block['title'] ?? '').toString(), userToken: userToken, userData: userData);
    final subtitle = resolveStorefrontTemplate((block['subtitle'] ?? '').toString(), userToken: userToken, userData: userData);
    final body = resolveStorefrontTemplate((block['body'] ?? '').toString(), userToken: userToken, userData: userData);
    final tAlign = parseTextAlign(block['text_align'], TextAlign.start);
    final cAlign = parseCrossAlign(block['text_align'], CrossAxisAlignment.start);

    final defaultFeatIcon = (cs['feature_icon'] ?? 'check_circle').toString();
    final defaultFeatIconColor = parseHexColor(cs['feature_icon_color'], const Color(0xFF00E676));
    final defaultFeatTextColor = parseHexColor(cs['feature_text_color'], const Color(0xFFD0D0E0));

    Widget? iconWidget;
    if (iconName.isNotEmpty) {
      iconWidget = Container(
        padding: EdgeInsets.all(_sfDouble(block['icon_box_padding'], 8.0)),
        decoration: BoxDecoration(
          color: parseHexColor(block['icon_bg_color'], const Color(0x1AFF3B5C)),
          borderRadius: BorderRadius.circular(_sfDouble(block['icon_box_radius'], 10.0)),
        ),
        child: Icon(
          resolveStorefrontIcon(iconName),
          color: parseHexColor(block['icon_color'], const Color(0xFFFF3B5C)),
          size: _sfDouble(block['icon_size'], 20.0),
        ),
      );
    }

    Widget? badgeWidget;
    if (_sfBool(badge['show'], false) && (badge['text'] ?? '').toString().trim().isNotEmpty) {
      badgeWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: parseHexColor(badge['bg_color'], const Color(0xFFFF3B5C)),
          borderRadius: BorderRadius.circular(_sfDouble(badge['border_radius'], 6.0)),
        ),
        child: Text(
          badge['text'].toString(),
          style: TextStyle(
            fontSize: _sfDouble(badge['font_size'], 10.5),
            fontWeight: FontWeight.w800,
            color: parseHexColor(badge['text_color'], Colors.white),
          ),
        ),
      );
    }

    Widget buildActionBtn(Map<String, dynamic> act) {
      final st = _sfMap(act['style']);
      final actIcon = (act['icon'] ?? '').toString().trim();
      final r = _sfDouble(st['border_radius'], 8.0);
      final variant = (st['variant'] ?? 'filled').toString().trim().toLowerCase();
      final bg = parseHexColor(st['bg_color'], variant == 'outlined' ? Colors.transparent : const Color(0xFFFF3B5C));
      final fg = parseHexColor(st['text_color'], Colors.white);
      final bCol = parseHexColor(st['border_color'], variant == 'outlined' ? const Color(0x4DFFFFFF) : Colors.transparent);
      final bW = _sfDouble(st['border_width'], variant == 'outlined' ? 1.0 : 0.0);

      return Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(r),
          border: (bW > 0 && bCol != Colors.transparent) ? Border.all(color: bCol, width: bW) : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(r),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _executeBoxAction(act),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: _sfDouble(st['padding_h'], 14.0),
                vertical: _sfDouble(st['padding_v'], 9.0),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (actIcon.isNotEmpty) ...[
                    Icon(resolveStorefrontIcon(actIcon), size: 15, color: fg),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      (act['label'] ?? 'ادامه').toString(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: _sfDouble(st['font_size'], 12.0),
                        fontWeight: FontWeight.w800,
                        color: fg,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    Widget content;
    if (layout == 'horizontal') {
      content = Row(
        children: [
          if (iconWidget != null) ...[iconWidget, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.isNotEmpty)
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: _sfDouble(cs['title_size'], 13.5),
                      fontWeight: parseFontWeight(cs['title_weight'], FontWeight.w800),
                      color: parseHexColor(cs['title_color'], Colors.white),
                    ),
                  ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: _sfDouble(cs['subtitle_size'], 11.5),
                      color: parseHexColor(cs['subtitle_color'], const Color(0xFFA0A0B0)),
                    ),
                  ),
                ],
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: TextStyle(
                      fontSize: _sfDouble(cs['body_size'], 12.0),
                      color: parseHexColor(cs['body_color'], const Color(0xFFD0D0E0)),
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(width: 10),
            buildActionBtn(actions.first),
          ] else if (badgeWidget != null) ...[
            const SizedBox(width: 8),
            badgeWidget,
          ],
        ],
      );
    } else {
      content = Column(
        crossAxisAlignment: cAlign,
        children: [
          if (iconWidget != null || title.isNotEmpty || badgeWidget != null)
            Row(
              mainAxisAlignment: cAlign == CrossAxisAlignment.center
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    mainAxisAlignment: cAlign == CrossAxisAlignment.center
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.start,
                    children: [
                      if (iconWidget != null) ...[iconWidget, const SizedBox(width: 10)],
                      if (title.isNotEmpty)
                        Flexible(
                          child: Text(
                            title,
                            textAlign: tAlign,
                            style: TextStyle(
                              fontSize: _sfDouble(cs['title_size'], 13.5),
                              fontWeight: parseFontWeight(cs['title_weight'], FontWeight.w800),
                              color: parseHexColor(cs['title_color'], Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (badgeWidget != null) ...[const SizedBox(width: 8), badgeWidget],
              ],
            ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: tAlign,
              style: TextStyle(
                fontSize: _sfDouble(cs['subtitle_size'], 11.5),
                color: parseHexColor(cs['subtitle_color'], const Color(0xFFA0A0B0)),
                height: 1.4,
              ),
            ),
          ],
          if (body.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: tAlign,
              style: TextStyle(
                fontSize: _sfDouble(cs['body_size'], 12.0),
                color: parseHexColor(cs['body_color'], const Color(0xFFD0D0E0)),
                height: 1.5,
              ),
            ),
          ],
          if (bullets.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...bullets.map((bItem) {
              final isMap = bItem is Map;
              final bm = isMap ? _sfMap(bItem) : const <String, dynamic>{};
              final bText = isMap ? (bm['text'] ?? '').toString() : bItem.toString();
              if (bText.trim().isEmpty) return const SizedBox.shrink();
              final bIcon = isMap ? (bm['icon'] ?? defaultFeatIcon).toString() : defaultFeatIcon;
              return Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (bIcon.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          resolveStorefrontIcon(bIcon),
                          size: 14,
                          color: isMap
                              ? parseHexColor(bm['icon_color'], defaultFeatIconColor)
                              : defaultFeatIconColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        bText,
                        style: TextStyle(
                          fontSize: isMap ? _sfDouble(bm['font_size'], 12.0) : 12.0,
                          fontWeight: (isMap && _sfBool(bm['bold'], false)) ? FontWeight.w800 : FontWeight.w400,
                          color: isMap
                              ? parseHexColor(bm['text_color'], defaultFeatTextColor)
                              : defaultFeatTextColor,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                for (int i = 0; i < actions.length; i++) ...[
                  Expanded(child: buildActionBtn(actions[i])),
                  if (i < actions.length - 1) const SizedBox(width: 8),
                ],
              ],
            ),
          ],
        ],
      );
    }

    final onTapMap = _sfMap(block['on_tap']);
    final hasTap = (onTapMap['action_type'] ?? '').toString().trim().isNotEmpty &&
        onTapMap['action_type'] != 'none';

    final bodyWithPad = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: _sfDouble(cs['padding_h'], 16.0),
        vertical: _sfDouble(cs['padding_v'], 14.0),
      ),
      child: content,
    );

    final fullChild = ribbonText.isEmpty
        ? bodyWithPad
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                color: parseHexColor(block['ribbon_bg_color'], const Color(0xFFFF3B5C)),
                child: Text(
                  ribbonText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: parseHexColor(block['ribbon_text_color'], Colors.white),
                  ),
                ),
              ),
              bodyWithPad,
            ],
          );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: buildStorefrontDecoration(
        cs,
        defaultBg: const Color(0xFF0E0E14),
        defaultBorder: const Color(0x33FFFFFF),
        defaultBorderWidth: 1.0,
        defaultRadius: radius,
      ),
      child: hasTap
          ? Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _executeBoxAction(onTapMap),
                child: fullChild,
              ),
            )
          : fullChild,
    );
  }

  void _executeBoxAction(Map<String, dynamic> act) {
    final type = (act['action_type'] ?? 'none').toString().trim().toLowerCase();
    final target = (act['target'] ?? '').toString().trim();
    switch (type) {
      case 'buy_package':
        final pk = (act['package_key'] ?? target).toString().trim();
        if (pk.isNotEmpty) onBuyPackageByKey(pk);
        break;
      case 'upgrade':
        onUpgrade();
        break;
      case 'open_url':
        final u = (act['url'] ?? target).toString().trim();
        if (u.isNotEmpty) onLaunchUrl(u);
        break;
      case 'switch_tab':
        final idx = _sfInt(act['tab_index'] ?? target, 0);
        onSwitchTab(idx.clamp(0, 3));
        break;
      case 'open_auth':
        onRequireAuth();
        break;
      case 'copy_text':
        final val = (act['copy_value'] ?? target).toString();
        if (val.isNotEmpty) {
          Clipboard.setData(ClipboardData(text: val));
          onShowToast((act['toast_text'] ?? 'کپی شد: $val').toString());
        }
        break;
      case 'refresh':
        onRefresh();
        break;
      default:
        break;
    }
  }
}

Future<bool?> showServerPreInvoiceDialog({
  required BuildContext context,
  required Map<String, dynamic> preCfg,
  required String planDisplayTitle,
  required String baseFormatted,
  required String feeFormatted,
  required String totalFormatted,
}) {
  final dlgBg = parseHexColor(preCfg['dialog_bg_color'], const Color(0xFF0E0E14));
  final dlgBorder = parseHexColor(preCfg['dialog_border_color'], const Color(0x33FFFFFF));
  final dlgBorderW = _sfDouble(preCfg['dialog_border_width'], 1.0);
  final dlgRadius = _sfDouble(preCfg['dialog_border_radius'], 16.0);
  final iconName = (preCfg['icon'] ?? 'receipt_long').toString();
  final iconColor = parseHexColor(preCfg['icon_color'], const Color(0xFFFF3B5C));
  final iconBg = parseHexColor(preCfg['icon_bg_color'], const Color(0x1AFF3B5C));
  final boxBg = parseHexColor(preCfg['box_bg_color'], const Color(0xFF14141E));
  final boxBorder = parseHexColor(preCfg['box_border_color'], const Color(0x1AFFFFFF));
  final boxRadius = _sfDouble(preCfg['box_border_radius'], 12.0);
  final divColor = parseHexColor(preCfg['divider_color'], const Color(0x1AFFFFFF));
  final labelColor = parseHexColor(preCfg['label_color'], const Color(0xFFA0A0B0));
  final valColor = parseHexColor(preCfg['value_color'], const Color(0xFFE0E0EC));
  final totalLblColor = parseHexColor(preCfg['total_label_color'], Colors.white);
  final totalValColor = parseHexColor(preCfg['total_value_color'], const Color(0xFF00E676));
  final footerNote = (preCfg['footer_note'] ?? 'پرداخت امن از طریق درگاه رسمی انجام می‌شود و اشتراک بلافاصله فعال می‌گردد.').toString();
  final warningText = (preCfg['warning_text'] ?? '').toString().trim();

  return showDialog<bool>(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: dlgBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(dlgRadius),
          side: BorderSide(color: dlgBorder, width: dlgBorderW),
        ),
        title: Row(
          children: [
            if (iconName.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(resolveStorefrontIcon(iconName), color: iconColor, size: 18),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                (preCfg['title'] ?? 'پیش‌فاکتور خرید اشتراک').toString(),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: parseHexColor(preCfg['title_color'], Colors.white),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: boxBg,
                borderRadius: BorderRadius.circular(boxRadius),
                border: Border.all(color: boxBorder),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text((preCfg['label_plan'] ?? 'پلن انتخابی').toString(), style: TextStyle(fontSize: 12, color: labelColor)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          planDisplayTitle,
                          textAlign: TextAlign.left,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  Divider(color: divColor, height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text((preCfg['label_base_amount'] ?? 'مبلغ پلن').toString(), style: TextStyle(fontSize: 12, color: labelColor)),
                      Text(baseFormatted, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: valColor)),
                    ],
                  ),
                  if (_sfBool(preCfg['show_fee_row'], true)) ...[
                    Divider(color: divColor, height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text((preCfg['label_fee'] ?? 'کارمزد درگاه پرداخت').toString(), style: TextStyle(fontSize: 12, color: labelColor)),
                        Text(feeFormatted, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: labelColor)),
                      ],
                    ),
                  ],
                  Divider(color: divColor, height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text((preCfg['label_total'] ?? 'مبلغ نهایی قابل پرداخت').toString(), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: totalLblColor)),
                      Text(totalFormatted, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: totalValColor)),
                    ],
                  ),
                ],
              ),
            ),
            if (warningText.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: parseHexColor(preCfg['warning_bg_color'], const Color(0x1AFFAB00)),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: parseHexColor(preCfg['warning_border_color'], const Color(0x4DFFAB00))),
                ),
                child: Text(
                  warningText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: parseHexColor(preCfg['warning_text_color'], const Color(0xFFFFD54F)),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            if (footerNote.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                footerNote,
                style: TextStyle(
                  fontSize: 11,
                  color: parseHexColor(preCfg['footer_note_color'], const Color(0xFFA0A0B0)),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: parseHexColor(preCfg['cancel_btn_border_color'], const Color(0x33FFFFFF))),
                    foregroundColor: parseHexColor(preCfg['cancel_btn_text_color'], Colors.white70),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text((preCfg['cancel_btn_text'] ?? 'انصراف').toString(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: parseHexColor(preCfg['confirm_btn_bg_color'], const Color(0xFFD91B35)),
                    foregroundColor: parseHexColor(preCfg['confirm_btn_text_color'], Colors.white),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_sfDouble(preCfg['confirm_btn_radius'], 10.0)),
                    ),
                  ),
                  child: Text(
                    (preCfg['confirm_btn_text'] ?? 'انتقال به درگاه پرداخت').toString(),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

Future<bool?> showServerUpgradeInvoiceDialog({
  required BuildContext context,
  required Map<String, dynamic> upiCfg,
  required String fromPlan,
  required String toPlan,
  required int remainingDays,
  required String baseFormatted,
  required String feeFormatted,
  required String totalFormatted,
}) {
  final dlgBg = parseHexColor(upiCfg['dialog_bg_color'], const Color(0xFF0E0E14));
  final dlgBorder = parseHexColor(upiCfg['dialog_border_color'], const Color(0x33FFAB00));
  final dlgBorderW = _sfDouble(upiCfg['dialog_border_width'], 1.0);
  final dlgRadius = _sfDouble(upiCfg['dialog_border_radius'], 16.0);
  final iconName = (upiCfg['icon'] ?? 'upgrade').toString();
  final iconColor = parseHexColor(upiCfg['icon_color'], const Color(0xFFFFAB00));
  final iconBg = parseHexColor(upiCfg['icon_bg_color'], const Color(0x33FFAB00));
  final boxBg = parseHexColor(upiCfg['box_bg_color'], const Color(0xFF14141E));
  final boxBorder = parseHexColor(upiCfg['box_border_color'], const Color(0x1AFFFFFF));
  final boxRadius = _sfDouble(upiCfg['box_border_radius'], 12.0);
  final divColor = parseHexColor(upiCfg['divider_color'], const Color(0x1AFFFFFF));
  final footerNote = (upiCfg['footer_note'] ?? 'این مبلغ بر اساس روز‌های باقی‌مانده شما محاسبه شده است.').toString();

  return showDialog<bool>(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: dlgBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(dlgRadius),
          side: BorderSide(color: dlgBorder, width: dlgBorderW),
        ),
        title: Row(
          children: [
            if (iconName.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
                child: Icon(resolveStorefrontIcon(iconName), color: iconColor, size: 20),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                (upiCfg['title'] ?? 'پیش‌فاکتور ارتقای اشتراک').toString(),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: parseHexColor(upiCfg['title_color'], Colors.white),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: boxBg,
                borderRadius: BorderRadius.circular(boxRadius),
                border: Border.all(color: boxBorder),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text((upiCfg['label_from_plan'] ?? 'سرویس / پلن فعلی').toString(), style: const TextStyle(fontSize: 12, color: Color(0xFFA0A0B0))),
                      Text(fromPlan, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                    ],
                  ),
                  Divider(color: divColor, height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text((upiCfg['label_to_plan'] ?? 'پلن انتخابی مقصد').toString(), style: const TextStyle(fontSize: 12, color: Color(0xFFA0A0B0))),
                      Text(toPlan, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: parseHexColor(upiCfg['to_plan_color'], const Color(0xFFFFAB00)))),
                    ],
                  ),
                  if (_sfBool(upiCfg['show_remaining_days_row'], true) && remainingDays > 0) ...[
                    Divider(color: divColor, height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text((upiCfg['label_remaining_days'] ?? 'مدت زمان باقی‌مانده').toString(), style: const TextStyle(fontSize: 12, color: Color(0xFFA0A0B0))),
                        Text('$remainingDays ${(upiCfg['days_suffix'] ?? 'روز').toString()}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFE0E0EC))),
                      ],
                    ),
                  ],
                  Divider(color: divColor, height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text((upiCfg['label_base_amount'] ?? 'مبلغ مابه‌التفاوت پلن').toString(), style: const TextStyle(fontSize: 12, color: Color(0xFFA0A0B0))),
                      Text(baseFormatted, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFE0E0EC))),
                    ],
                  ),
                  if (_sfBool(upiCfg['show_fee_row'], true)) ...[
                    Divider(color: divColor, height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text((upiCfg['label_fee'] ?? 'کارمزد درگاه پرداخت').toString(), style: const TextStyle(fontSize: 12, color: Color(0xFFA0A0B0))),
                        Text(feeFormatted, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFFA0A0B0))),
                      ],
                    ),
                  ],
                  Divider(color: divColor, height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text((upiCfg['label_total'] ?? 'مبلغ نهایی قابل پرداخت').toString(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                      Text(totalFormatted, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: parseHexColor(upiCfg['total_value_color'], const Color(0xFF00E676)))),
                    ],
                  ),
                ],
              ),
            ),
            if (footerNote.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: parseHexColor(upiCfg['footer_note_bg_color'], const Color(0x0AFFFFFF)),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: parseHexColor(upiCfg['footer_note_border_color'], const Color(0x14FFFFFF))),
                ),
                child: Text(
                  footerNote,
                  style: TextStyle(fontSize: 11, color: parseHexColor(upiCfg['footer_note_color'], const Color(0xFFA0A0B0))),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0x33FFFFFF)),
                    foregroundColor: Colors.white70,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text((upiCfg['cancel_btn_text'] ?? 'انصراف').toString(), style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: parseHexColor(upiCfg['confirm_btn_bg_color'], const Color(0xFFFFAB00)),
                    foregroundColor: parseHexColor(upiCfg['confirm_btn_text_color'], Colors.black),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_sfDouble(upiCfg['confirm_btn_radius'], 10.0)),
                    ),
                  ),
                  child: Text(
                    (upiCfg['confirm_btn_text'] ?? 'انتقال به درگاه پرداخت').toString(),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
