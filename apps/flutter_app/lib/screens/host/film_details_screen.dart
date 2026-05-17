import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../models/event.dart';
import '../../services/api_failure.dart';
import '../../services/providers.dart';
import '../../widgets/location_picker.dart';
import '../../widgets/ui_atoms.dart';

class FilmDetailsScreen extends ConsumerStatefulWidget {
  const FilmDetailsScreen({super.key});

  @override
  ConsumerState<FilmDetailsScreen> createState() => _FilmDetailsScreenState();
}

class _FilmDetailsScreenState extends ConsumerState<FilmDetailsScreen> {
  late final TextEditingController _nameController;
  // Location is picked via the LocationPickerSheet (Nominatim-backed), so we
  // just hold the chosen string here instead of a TextEditingController.
  late String _location;
  late String _reveal;
  late int _frames;
  late DateTime _startsAt;
  bool _creating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(filmDraftProvider);
    // Start empty so "Tobi & Adaeze" shows as a greyed-out hint the user can
    // type straight over, instead of having to backspace it first.
    _nameController = TextEditingController(text: draft.name);
    _location = draft.location;
    _reveal = draft.reveal;
    _frames = draft.frames;
    _startsAt = draft.startsAt;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickLocation() async {
    final picked = await LocationPickerSheet.open(context, initial: _location);
    if (picked != null && picked.isNotEmpty) {
      setState(() => _location = picked);
    }
  }

  Future<void> _create() async {
    if (_creating) return;
    final draft = ref.read(filmDraftProvider);
    final type = draft.type;
    if (type == null) {
      // Safety net — FilmType screen should have set this.
      context.go('/film-type');
      return;
    }

    // Persist into the draft so back/forward navigation doesn't lose state.
    final ctrl = ref.read(filmDraftProvider.notifier);
    final name = _nameController.text.trim();
    final location = _location.trim();
    ctrl.setName(name);
    ctrl.setLocation(location);
    ctrl.setReveal(_reveal);
    ctrl.setFrames(_frames);
    ctrl.setStartsAt(_startsAt);

    final ends = _startsAt.add(const Duration(hours: 10));
    final revealAt = switch (_reveal) {
      'during' => _startsAt,
      'delay'  => ends.add(const Duration(hours: 24)),
      _        => ends.add(const Duration(minutes: 30)), // 'after'
    };

    setState(() {
      _creating = true;
      _error = null;
    });

    try {
      final event = await ref.read(eventsServiceProvider).create(
            name: name.isEmpty ? 'Untitled film' : name,
            location: location,
            eventType: type,
            privacy: EventPrivacy.public,
            startsAt: _startsAt,
            endsAt: ends,
            revealAt: revealAt,
            tier: EventTier.standard,
          );
      ref.invalidate(myFilmsProvider);
      ctrl.reset();
      if (!mounted) return;
      context.go('/qr-share', extra: event.id);
    } on ApiFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _creating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _creating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            StepHeader(onBack: () => context.pop(), step: 2, of: 3),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      style: MoraText.display(size: 30),
                      children: [
                        const TextSpan(text: 'Name your '),
                        TextSpan(text: 'film', style: MoraText.display(size: 30, italic: true)),
                        const TextSpan(text: '.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Guests will see this on their invite and at the develop moment.',
                    style: MoraText.body(size: 14, color: MoraColors.textSecondary),
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
                    // ─── Film name (the editorial hero input) ───
                    _FieldLabel('Film name'),
                    const SizedBox(height: 8),
                    _EditorialInputShell(
                      child: TextField(
                        controller: _nameController,
                        style: MoraText.display(size: 24),
                        cursorColor: MoraColors.accent,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          hintText: 'Tobi & Adaeze',
                          hintStyle: MoraText.display(size: 24, color: MoraColors.textTertiary),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ─── Side-by-side: Date & time | Location ───
                    // Date & time and Location stack full-width — the Location
                    // field opens the LocationPickerSheet on tap (Nominatim
                    // search + "use as written" fallback).
                    _PickerField(
                      label: 'Date & time',
                      primary: _shortDate(_startsAt),
                      secondary: _shortTime(_startsAt),
                      icon: Icons.event_outlined,
                      onTap: _pickDateTime,
                    ),
                    const SizedBox(height: 16),
                    _PickerField(
                      label: 'Location',
                      primary: _location.isEmpty ? 'Pick a place' : _location,
                      secondary: _location.isEmpty
                          ? 'City, venue, address'
                          : 'Tap to change',
                      icon: Icons.place_outlined,
                      muted: _location.isEmpty,
                      onTap: _pickLocation,
                    ),

                    const SizedBox(height: 28),

                    // ─── Reveal timing ───
                    _FieldLabel('When the film develops'),
                    const SizedBox(height: 10),
                    PillToggleGroup(
                      value: _reveal,
                      onChange: (v) => setState(() => _reveal = v),
                      options: const [
                        MapEntry('during', 'During'),
                        MapEntry('after', 'After'),
                        MapEntry('delay', 'On delay'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _reveal == 'during'
                          ? 'Photos appear live as guests take them.'
                          : _reveal == 'after'
                              ? 'Photos stay hidden until you tap develop after the event.'
                              : 'Photos develop automatically 24 hours after the event.',
                      style: MoraText.body(size: 13, color: MoraColors.textSecondary, height: 1.5),
                    ),

                    const SizedBox(height: 28),

                    // ─── Frames dial ───
                    Center(
                      child: Column(
                        children: [
                          Text('FRAMES PER GUEST', style: MoraText.label()),
                          const SizedBox(height: 14),
                          FramesDial(
                            value: _frames,
                            onChange: (v) => setState(() => _frames = v),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            "Like a disposable. Choose carefully — guests can't add more.",
                            style: MoraText.body(size: 12, color: MoraColors.textTertiary),
                          ),
                        ],
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
                        child: Text(
                          _error!,
                          style: MoraText.body(size: 13, color: MoraColors.negative, height: 1.4),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            BottomAction(
              hint: const Text('Free until 5 guests join · then ₦2,500'),
              children: [
                PrimaryButton(
                  label: _creating ? 'Creating…' : 'Create film',
                  onTap: _creating ? null : _create,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDateTime() async {
    final initial = _startsAt;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => _moraDialogTheme(ctx, child!),
    );
    if (pickedDate == null) return;
    if (!mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      builder: (ctx, child) => _moraDialogTheme(ctx, child!),
    );
    if (pickedTime == null) return;

    setState(() {
      _startsAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Widget _moraDialogTheme(BuildContext ctx, Widget child) {
    return Theme(
      data: Theme.of(ctx).copyWith(
        colorScheme: const ColorScheme.dark(
          primary: MoraColors.accent,
          onPrimary: MoraColors.onAccent,
          surface: MoraColors.bgElevated,
          onSurface: MoraColors.textPrimary,
        ),
        dialogTheme: const DialogThemeData(backgroundColor: MoraColors.bgElevated),
        timePickerTheme: const TimePickerThemeData(
          backgroundColor: MoraColors.bgElevated,
          hourMinuteColor: MoraColors.bgOverlay,
          dialBackgroundColor: MoraColors.bgOverlay,
        ),
      ),
      child: child,
    );
  }
}

// ─── Editorial input shells ────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(), style: MoraText.label());
  }
}

class _EditorialInputShell extends StatelessWidget {
  final Widget child;
  const _EditorialInputShell({required this.child});

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

class _PickerField extends StatelessWidget {
  final String label;
  final String primary;
  final String secondary;
  final IconData icon;
  final VoidCallback onTap;
  /// When true the primary value is rendered in the tertiary text color so
  /// "Pick a place" reads as a placeholder, not as a filled-in value.
  final bool muted;

  const _PickerField({
    required this.label,
    required this.primary,
    required this.secondary,
    required this.icon,
    required this.onTap,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 8),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: MoraColors.borderEmphasis),
                color: const Color(0x08F5EFE6),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: MoraColors.textSecondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          primary,
                          style: MoraText.display(
                            size: 16,
                            height: 1.1,
                            color: muted ? MoraColors.textTertiary : MoraColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(secondary,
                            style: MoraText.body(size: 11, color: MoraColors.textTertiary, height: 1.2)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 16, color: MoraColors.textTertiary),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Formatters ────────────────────────────────────────────────────────────

String _shortDate(DateTime d) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${days[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
}

String _shortTime(DateTime d) {
  final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final mm = d.minute.toString().padLeft(2, '0');
  final ampm = d.hour < 12 ? 'AM' : 'PM';
  return '$h12:$mm $ampm';
}
