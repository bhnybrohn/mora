import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../models/event.dart';
import '../../services/api_failure.dart';
import '../../services/providers.dart';
import '../../widgets/location_picker.dart';
import '../../widgets/ui_atoms.dart';

/// Edit film name / location / starts_at after creation. Date+time picker
/// mirrors FilmDetails; reveal-time is recomputed from the new start.
class EditFilmScreen extends ConsumerStatefulWidget {
  final String eventId;
  const EditFilmScreen({super.key, required this.eventId});

  @override
  ConsumerState<EditFilmScreen> createState() => _EditFilmScreenState();
}

class _EditFilmScreenState extends ConsumerState<EditFilmScreen> {
  final _name = TextEditingController();
  String _location = '';
  DateTime? _startsAt;
  bool _hydrated = false;
  bool _saving = false;
  String? _error;
  Event? _event;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _hydrate(Event e) {
    if (_hydrated) return;
    _name.text = e.name;
    _location = e.location;
    _startsAt = e.startsAt.toLocal();
    _event = e;
    _hydrated = true;
  }

  Future<void> _pickLocation() async {
    final picked = await LocationPickerSheet.open(context, initial: _location);
    if (picked != null) setState(() => _location = picked);
  }

  Future<void> _pickDateTime() async {
    final initial = _startsAt ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;
    if (!mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;

    setState(() {
      _startsAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _save() async {
    if (_saving || _event == null) return;
    final newName = _name.text.trim();
    if (newName.isEmpty) {
      setState(() => _error = 'Give the film a name.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final start = _startsAt ?? _event!.startsAt;
      // Reuse the original delta between start/end & start/reveal so the user
      // doesn't have to re-set those if they only shifted the date.
      final origStart = _event!.startsAt;
      final endDelta = _event!.endsAt.difference(origStart);
      final revealDelta = _event!.revealAt.difference(origStart);

      await ref.read(eventsServiceProvider).update(
            widget.eventId,
            name: newName,
            location: _location.trim(),
            startsAt: start,
            endsAt: start.add(endDelta),
            revealAt: start.add(revealDelta),
          );

      ref.invalidate(myFilmsProvider);
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
    final eventAsync = ref.watch(_eventByIdProvider(widget.eventId));

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            StepHeader(onBack: () => context.pop()),
            eventAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.fromLTRB(20, 40, 20, 0),
                child: Center(child: CircularProgressIndicator(color: MoraColors.accent, strokeWidth: 2)),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.fromLTRB(20, 40, 20, 0),
                child: Text("Couldn't load: $e", style: MoraText.body(size: 13, color: MoraColors.negative)),
              ),
              data: (event) {
                _hydrate(event);
                return Expanded(child: _body(event));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(Event event) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  style: MoraText.display(size: 30),
                  children: [
                    const TextSpan(text: 'Edit '),
                    TextSpan(text: 'film', style: MoraText.display(size: 30, italic: true)),
                    const TextSpan(text: '.'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Reveal timing recalculates from the new start. Existing photos stay.',
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
                _FieldLabel('Film name'),
                const SizedBox(height: 8),
                _Shell(
                  child: TextField(
                    controller: _name,
                    style: MoraText.display(size: 22),
                    cursorColor: MoraColors.accent,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                _PickerField(
                  label: 'Date & time',
                  primary: _shortDate(_startsAt ?? event.startsAt.toLocal()),
                  secondary: _shortTime(_startsAt ?? event.startsAt.toLocal()),
                  icon: Icons.event_outlined,
                  onTap: _pickDateTime,
                ),
                const SizedBox(height: 16),
                _PickerField(
                  label: 'Location',
                  primary: _location.isEmpty ? 'Pick a place' : _location,
                  secondary: _location.isEmpty ? 'City, venue, address' : 'Tap to change',
                  icon: Icons.place_outlined,
                  muted: _location.isEmpty,
                  onTap: _pickLocation,
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
              label: _saving ? 'Saving…' : 'Save changes',
              onTap: _saving ? null : _save,
            ),
          ],
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(), style: MoraText.label());
}

class _Shell extends StatelessWidget {
  final Widget child;
  const _Shell({required this.child});

  @override
  Widget build(BuildContext context) => Container(
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

class _PickerField extends StatelessWidget {
  final String label;
  final String primary;
  final String secondary;
  final IconData icon;
  final VoidCallback onTap;
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

final _eventByIdProvider = FutureProvider.family.autoDispose<Event, String>((ref, id) {
  return ref.watch(eventsServiceProvider).get(id);
});
