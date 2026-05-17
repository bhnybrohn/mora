import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../services/locations_service.dart';
import '../services/providers.dart';

/// Modal sheet that searches Nominatim as the user types and lets them pick
/// a place. Always offers a "Use as written" row so a venue name that doesn't
/// match a geocoder hit (eg "Auntie Yemi's house") still works.
class LocationPickerSheet extends ConsumerStatefulWidget {
  /// Pre-fill the search input so reopening the picker with an existing
  /// value lets the user just tap a result, not retype.
  final String initial;

  const LocationPickerSheet({super.key, this.initial = ''});

  /// Convenience wrapper — shows the sheet and returns the user's pick,
  /// or null if dismissed.
  static Future<String?> open(BuildContext context, {String initial = ''}) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: MoraColors.bgElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => LocationPickerSheet(initial: initial),
    );
  }

  @override
  ConsumerState<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends ConsumerState<LocationPickerSheet> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<LocationHit> _results = const [];
  bool _searching = false;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initial;
    if (widget.initial.isNotEmpty) {
      // Pre-run a search so the sheet opens with relevant hits already.
      WidgetsBinding.instance.addPostFrameCallback((_) => _run(widget.initial));
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    if (q.trim().length < 2) {
      setState(() {
        _results = const [];
        _searching = false;
      });
      return;
    }
    // 350 ms is roughly one character-pause; keeps us well under Nominatim's
    // 1 req/sec policy without feeling laggy.
    _debounce = Timer(const Duration(milliseconds: 350), () => _run(q));
  }

  Future<void> _run(String q) async {
    setState(() {
      _searching = true;
      _hasSearched = true;
    });
    final hits = await ref.read(locationsServiceProvider).search(q);
    if (!mounted) return;
    setState(() {
      _results = hits;
      _searching = false;
    });
  }

  void _pick(String value) {
    if (value.trim().isEmpty) return;
    Navigator.of(context).pop(value.trim());
  }

  @override
  Widget build(BuildContext context) {
    // Push the sheet up above the keyboard.
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: FractionallySizedBox(
        heightFactor: 0.82,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: MoraColors.borderEmphasis,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: Row(
                  children: [
                    Text('PICK A LOCATION', style: MoraText.label()),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('Cancel',
                          style: MoraText.body(size: 13, color: MoraColors.textSecondary, height: 1.2)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Search input
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: MoraColors.borderEmphasis),
                    color: const Color(0x08F5EFE6),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, size: 18, color: MoraColors.textSecondary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          autofocus: true,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.search,
                          style: MoraText.body(size: 16, color: MoraColors.textPrimary),
                          cursorColor: MoraColors.accent,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            hintText: 'City, venue, address',
                            hintStyle: MoraText.body(size: 16, color: MoraColors.textTertiary),
                          ),
                          onChanged: _onChanged,
                          onSubmitted: (v) {
                            if (_results.isNotEmpty) {
                              _pick(_results.first.shortLabel);
                            } else {
                              _pick(v);
                            }
                          },
                        ),
                      ),
                      if (_controller.text.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _controller.clear();
                            setState(() {
                              _results = const [];
                              _hasSearched = false;
                            });
                          },
                          child: const Icon(Icons.close_rounded,
                              size: 18, color: MoraColors.textTertiary),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Results
              Expanded(child: _resultsList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resultsList() {
    final q = _controller.text.trim();

    if (q.length < 2) {
      return _hint(
        icon: Icons.public_rounded,
        title: 'Start typing a place',
        body: 'A city, venue or address — anywhere in the world.',
      );
    }

    if (_searching && _results.isEmpty) {
      return const Center(
        child: SizedBox(
          width: 28, height: 28,
          child: CircularProgressIndicator(strokeWidth: 2, color: MoraColors.accent),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      itemCount: _results.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (ctx, i) {
        // First row is always "use as written" — keeps the path open for
        // venue names the geocoder doesn't know.
        if (i == 0) {
          return _UseAsWrittenRow(
            text: q,
            onTap: () => _pick(q),
          );
        }
        final hit = _results[i - 1];
        return _ResultRow(
          hit: hit,
          onTap: () => _pick(hit.shortLabel),
        );
      },
    );
  }

  Widget _hint({required IconData icon, required String title, required String body}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 36, 32, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 30, color: MoraColors.textTertiary),
          const SizedBox(height: 12),
          Text(title,
              textAlign: TextAlign.center,
              style: MoraText.display(size: 18, italic: true)),
          const SizedBox(height: 6),
          Text(body,
              textAlign: TextAlign.center,
              style: MoraText.body(size: 12, color: MoraColors.textTertiary, height: 1.5)),
          if (_hasSearched && _results.isEmpty && !_searching) ...[
            const SizedBox(height: 14),
            Text(
              'No matches — you can still use what you typed.',
              textAlign: TextAlign.center,
              style: MoraText.body(size: 12, color: MoraColors.textTertiary),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final LocationHit hit;
  final VoidCallback onTap;
  const _ResultRow({required this.hit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0x06F5EFE6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: MoraColors.borderSubtle),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.place_outlined, size: 16, color: MoraColors.textSecondary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(hit.shortLabel,
                        style: MoraText.body(size: 14, color: MoraColors.textPrimary, weight: FontWeight.w500, height: 1.2)),
                    if (hit.displayName != hit.shortLabel) ...[
                      const SizedBox(height: 2),
                      Text(
                        hit.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: MoraText.body(size: 11, color: MoraColors.textTertiary, height: 1.4),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UseAsWrittenRow extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _UseAsWrittenRow({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0x14D9A85C),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x33D9A85C)),
          ),
          child: Row(
            children: [
              const Icon(Icons.edit_outlined, size: 16, color: MoraColors.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Use as written',
                        style: MoraText.label(color: MoraColors.accent)),
                    const SizedBox(height: 4),
                    Text(text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MoraText.body(size: 14, color: MoraColors.textPrimary, weight: FontWeight.w500, height: 1.2)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
