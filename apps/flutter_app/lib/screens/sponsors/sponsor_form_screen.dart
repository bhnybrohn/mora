import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/theme.dart';
import '../../services/api_failure.dart';
import '../../services/providers.dart';
import '../../services/sponsors_service.dart';
import '../../widgets/ui_atoms.dart';

/// Add or edit a single sponsor. Pass an existing [Sponsor] in via go_router's
/// `extra` to switch into edit mode.
class SponsorFormScreen extends ConsumerStatefulWidget {
  final String eventId;
  final Sponsor? existing;
  const SponsorFormScreen({super.key, required this.eventId, this.existing});

  @override
  ConsumerState<SponsorFormScreen> createState() => _SponsorFormScreenState();
}

class _SponsorFormScreenState extends ConsumerState<SponsorFormScreen> {
  final _name = TextEditingController();
  final _tagline = TextEditingController();
  final _link = TextEditingController();

  // Role chips — same set the design's MadePossibleBy reference uses, plus
  // a couple of common owambe roles.
  static const _roles = [
    'Aso oke',
    'Catering',
    'Photography',
    'Venue',
    'Make-up',
    'MC',
    'DJ',
    'Florist',
    'Cake',
    'Other',
  ];

  // Role → curated 3-color palette. Mirrors the API's `_palette_for_role`
  // so what the user sees in the picker is the same default we'd save.
  static const Map<String, List<Color>> _rolePalettes = {
    'aso oke':     [Color(0xFF3A1418), Color(0xFFD4A857), Color(0xFF7A3025)],
    'catering':    [Color(0xFF2A1F1A), Color(0xFFE89C5C), Color(0xFF4D2A20)],
    'photography': [Color(0xFF1A1714), Color(0xFFA88B5C), Color(0xFF3D3530)],
    'venue':       [Color(0xFF1F2A52), Color(0xFFD4A857), Color(0xFF3D3530)],
    'make-up':     [Color(0xFF3A2A30), Color(0xFFE8A55C), Color(0xFF8B5530)],
    'mc':          [Color(0xFF2A1A0D), Color(0xFFF1C57E), Color(0xFF5C2A14)],
    'dj':          [Color(0xFF13110D), Color(0xFFA47C40), Color(0xFF3A2515)],
    'florist':     [Color(0xFF1A2820), Color(0xFFD89F4A), Color(0xFF5C4438)],
    'cake':        [Color(0xFF2A1A0D), Color(0xFFE8D8B8), Color(0xFFC9A4B0)],
    'other':       [Color(0xFF1A130C), Color(0xFF7A6E60), Color(0xFFD9A85C)],
  };

  // Per-slot color choices for the palette picker, picked from the design's
  // warm vocabulary so swatches stay coherent across films.
  static const _baseSwatches = [
    Color(0xFF3A1418), Color(0xFF1A130C), Color(0xFF1F2A52),
    Color(0xFF2A1F1A), Color(0xFF1A1714), Color(0xFF3A2A30),
    Color(0xFF1A2820), Color(0xFF5C2030),
  ];
  static const _glowSwatches = [
    Color(0xFFD4A857), Color(0xFFE89C5C), Color(0xFFF1C57E),
    Color(0xFFA88B5C), Color(0xFFE6B66B), Color(0xFFC77859),
    Color(0xFFE8A55C), Color(0xFFD9A85C),
  ];
  static const _liftSwatches = [
    Color(0xFF7A3025), Color(0xFF4D2A20), Color(0xFF3D3530),
    Color(0xFF8B5530), Color(0xFF5C4438), Color(0xFFC9A4B0),
    Color(0xFFB8447A), Color(0xFF522010),
  ];

  String _role = 'Aso oke';
  List<Color> _palette = _rolePalettes['aso oke']!;
  bool _featured = false;
  Uint8List? _pendingLogoBytes;
  String? _existingLogoUrl;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _name.text = e.name;
      _role = e.role;
      _tagline.text = e.tagline ?? '';
      _link.text = e.link ?? '';
      _featured = e.isFeatured;
      _existingLogoUrl = e.logoUrl;
      _palette = e.palette.length == 3
          ? e.palette
          : (_rolePalettes[e.role.toLowerCase()] ?? _rolePalettes['other']!);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _tagline.dispose();
    _link.dispose();
    super.dispose();
  }

  void _selectRole(String role) {
    setState(() {
      _role = role;
      // Adopt the role's default palette unless the user already customized.
      // We keep their custom palette when editing if it doesn't match the
      // old role's default.
      final preset = _rolePalettes[role.toLowerCase()];
      if (preset != null) _palette = preset;
    });
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await File(picked.path).readAsBytes();
    setState(() {
      _pendingLogoBytes = bytes;
      _existingLogoUrl = null; // pending overrides remote
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give the sponsor a name.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final svc = ref.read(sponsorsServiceProvider);

      // Upload any pending logo first so we have a key to attach.
      String? logoKey;
      if (_pendingLogoBytes != null) {
        logoKey = await svc.uploadLogo(
          eventId: widget.eventId,
          bytes: _pendingLogoBytes!,
        );
      }

      if (_isEdit) {
        await svc.update(
          eventId: widget.eventId,
          sponsorId: widget.existing!.id,
          name: name,
          role: _role,
          palette: _palette,
          link: _link.text.trim(),
          tagline: _tagline.text.trim(),
          logoKey: logoKey, // null leaves it alone
          isFeatured: _featured,
        );
      } else {
        await svc.create(
          eventId: widget.eventId,
          name: name,
          role: _role,
          palette: _palette,
          link: _link.text.trim().isEmpty ? null : _link.text.trim(),
          tagline: _tagline.text.trim().isEmpty ? null : _tagline.text.trim(),
          logoKey: logoKey,
          isFeatured: _featured,
        );
      }

      ref.invalidate(sponsorsForEventProvider(widget.eventId));
      if (!mounted) return;
      context.pop();
    } on ApiFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _saving = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            StepHeader(onBack: () => context.pop()),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      style: MoraText.display(size: 30),
                      children: [
                        TextSpan(text: _isEdit ? 'Edit ' : 'Add a '),
                        TextSpan(text: 'sponsor', style: MoraText.display(size: 30, italic: true)),
                        const TextSpan(text: '.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'They show up in the album foot, and a featured one becomes a magazine insert mid-album.',
                    style: MoraText.body(size: 13, color: MoraColors.textSecondary, height: 1.5),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── Logo + name preview ───
                    Row(
                      children: [
                        GestureDetector(
                          onTap: _pickLogo,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: SizedBox(
                              width: 72, height: 72,
                              child: _logoPreview(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: _pickLogo,
                                child: Text(
                                  _pendingLogoBytes != null || _existingLogoUrl != null
                                      ? 'Replace logo'
                                      : 'Add a logo',
                                  style: MoraText.body(
                                    size: 13,
                                    color: MoraColors.accent,
                                    weight: FontWeight.w500,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "If you skip it we'll generate a warm asoebi swatch from your palette.",
                                style: MoraText.body(size: 11, color: MoraColors.textTertiary, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ─── Name ───
                    _FieldLabel('Sponsor name'),
                    const SizedBox(height: 8),
                    _Shell(
                      child: TextField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        style: MoraText.display(size: 22),
                        cursorColor: MoraColors.accent,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          hintText: 'Folake Adisa Textiles',
                          hintStyle: MoraText.display(size: 22, color: MoraColors.textTertiary),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ─── Role ───
                    _FieldLabel('Role'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _roles.map((r) {
                        final selected = r.toLowerCase() == _role.toLowerCase();
                        return _Chip(
                          label: r,
                          selected: selected,
                          onTap: () => _selectRole(r),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 24),

                    // ─── Palette ───
                    _FieldLabel('Brand colors'),
                    const SizedBox(height: 6),
                    Text(
                      'Base · accent · lift. We use these to draw a warm swatch when no logo.',
                      style: MoraText.body(size: 11, color: MoraColors.textTertiary, height: 1.4),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 0,
                          child: SizedBox(
                            width: 76, height: 76,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: AsoebiSwatch(palette: _palette),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _PaletteRow(
                                label: 'Base',
                                colors: _baseSwatches,
                                selected: _palette[0],
                                onPick: (c) => setState(() => _palette = [c, _palette[1], _palette[2]]),
                              ),
                              const SizedBox(height: 8),
                              _PaletteRow(
                                label: 'Accent',
                                colors: _glowSwatches,
                                selected: _palette[1],
                                onPick: (c) => setState(() => _palette = [_palette[0], c, _palette[2]]),
                              ),
                              const SizedBox(height: 8),
                              _PaletteRow(
                                label: 'Lift',
                                colors: _liftSwatches,
                                selected: _palette[2],
                                onPick: (c) => setState(() => _palette = [_palette[0], _palette[1], c]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ─── Tagline + Link ───
                    _FieldLabel('Tagline (optional)'),
                    const SizedBox(height: 8),
                    _Shell(
                      child: TextField(
                        controller: _tagline,
                        style: MoraText.body(size: 15, color: MoraColors.textPrimary, height: 1.4),
                        cursorColor: MoraColors.accent,
                        maxLength: 120,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          counterText: '',
                          hintText: 'Aso oke, woven slow.',
                          hintStyle: MoraText.body(size: 15, color: MoraColors.textTertiary, height: 1.4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    _FieldLabel('Link (optional)'),
                    const SizedBox(height: 8),
                    _Shell(
                      child: TextField(
                        controller: _link,
                        keyboardType: TextInputType.url,
                        style: MoraText.mono(size: 14, color: MoraColors.textPrimary),
                        cursorColor: MoraColors.accent,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          hintText: 'https://instagram.com/…',
                          hintStyle: MoraText.mono(size: 14, color: MoraColors.textTertiary),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ─── Featured ───
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => setState(() => _featured = !_featured),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _featured ? MoraColors.accent : MoraColors.borderSubtle),
                            color: _featured ? const Color(0x14D9A85C) : const Color(0x06F5EFE6),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _featured ? Icons.star_rounded : Icons.star_outline_rounded,
                                size: 18,
                                color: _featured ? MoraColors.accent : MoraColors.textSecondary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Feature in the album',
                                        style: MoraText.body(size: 14, weight: FontWeight.w500, height: 1.2)),
                                    const SizedBox(height: 2),
                                    Text(
                                      'One featured sponsor becomes a full magazine insert between sections.',
                                      style: MoraText.body(size: 11, color: MoraColors.textTertiary, height: 1.4),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: MoraColors.negative.withValues(alpha: 0.08),
                          border: Border.all(color: MoraColors.negative.withValues(alpha: 0.4)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(_error!,
                            style: MoraText.body(size: 13, color: MoraColors.negative, height: 1.4)),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            BottomAction(
              children: [
                PrimaryButton(
                  label: _saving ? 'Saving…' : (_isEdit ? 'Save sponsor' : 'Add sponsor'),
                  onTap: _saving ? null : _save,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _logoPreview() {
    if (_pendingLogoBytes != null) {
      return Image.memory(_pendingLogoBytes!, fit: BoxFit.cover);
    }
    if (_existingLogoUrl != null && _existingLogoUrl!.isNotEmpty) {
      return Image.network(_existingLogoUrl!, fit: BoxFit.cover);
    }
    // Fallback: live preview of the asoebi swatch.
    return Stack(
      fit: StackFit.expand,
      children: [
        AsoebiSwatch(palette: _palette),
        Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: const Icon(Icons.add_a_photo_outlined, size: 22, color: Color(0xCCF5EFE6)),
        ),
      ],
    );
  }
}

// ─── Atoms used only here ─────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(), style: MoraText.label());
  }
}

class _Shell extends StatelessWidget {
  final Widget child;
  const _Shell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MoraColors.borderEmphasis),
        color: const Color(0x08F5EFE6),
      ),
      child: child,
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: MoraEase.out,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? MoraColors.accent.withValues(alpha: 0.14) : Colors.transparent,
          border: Border.all(color: selected ? MoraColors.accent : MoraColors.borderSubtle),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          label,
          style: MoraText.body(
            size: 12,
            color: selected ? MoraColors.accent : MoraColors.textSecondary,
            weight: selected ? FontWeight.w600 : FontWeight.w500,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

class _PaletteRow extends StatelessWidget {
  final String label;
  final List<Color> colors;
  final Color selected;
  final ValueChanged<Color> onPick;

  const _PaletteRow({
    required this.label,
    required this.colors,
    required this.selected,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 46,
          child: Text(label.toUpperCase(), style: MoraText.label(size: 9)),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: colors.map((c) {
                final isSelected = c.toARGB32() == selected.toARGB32();
                return GestureDetector(
                  onTap: () => onPick(c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: MoraEase.out,
                    width: 22, height: 22,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c,
                      border: Border.all(
                        color: isSelected ? MoraColors.textPrimary : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: isSelected
                          ? [BoxShadow(color: c.withValues(alpha: 0.45), blurRadius: 8, offset: const Offset(0, 2))]
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
