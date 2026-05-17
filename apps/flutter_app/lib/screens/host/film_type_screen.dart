import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../models/event.dart';
import '../../services/providers.dart';
import '../../widgets/ui_atoms.dart';

class _FilmTypeChoice {
  final EventType id;
  final String label;
  final String hint;
  final List<Color> asoebi;
  const _FilmTypeChoice(this.id, this.label, this.hint, this.asoebi);
}

const _filmTypes = <_FilmTypeChoice>[
  _FilmTypeChoice(EventType.owambe, 'Owambe', 'Saturday party',
      [Color(0xFF7A3B25), Color(0xFFE89C5C), Color(0xFF3D5A3F)]),
  _FilmTypeChoice(EventType.wedding, 'Wedding', 'Traditional or white',
      [Color(0xFF1E2A52), Color(0xFFD4A857), Color(0xFF8B0F2C)]),
  _FilmTypeChoice(EventType.naming, 'Naming', 'Welcoming a child',
      [Color(0xFFE8D8B8), Color(0xFFA88B5C), Color(0xFFC9A4B0)]),
  _FilmTypeChoice(EventType.birthday, 'Birthday', 'Big numbers',
      [Color(0xFF5C2030), Color(0xFFE8A55C), Color(0xFFB8447A)]),
  _FilmTypeChoice(EventType.funeral, 'Celebration of life', 'Funeral, gentle',
      [Color(0xFF3A3530), Color(0xFF8B7B6B), Color(0xFF5C4438)]),
  _FilmTypeChoice(EventType.other, 'Other', 'Custom film',
      [Color(0xFF1A130C), Color(0xFF7A6E60), Color(0xFFD9A85C)]),
];

class _AsoebiCard extends StatelessWidget {
  final _FilmTypeChoice type;
  final bool selected;
  final VoidCallback onTap;

  const _AsoebiCard({required this.type, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: MoraEase.out,
        height: 156,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? MoraColors.accent : MoraColors.borderSubtle,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: type.asoebi[1].withValues(alpha: 0.18),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(19),
          child: Stack(
            children: [
              Positioned.fill(child: AsoebiSwatch(palette: type.asoebi)),
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x1A0F0A06), Color(0xD90F0A06)],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12, left: 12,
                child: Row(
                  children: type.asoebi.map((c) => Container(
                    width: 14, height: 4,
                    margin: const EdgeInsets.only(right: 3),
                    decoration: BoxDecoration(
                      color: c,
                      borderRadius: BorderRadius.circular(1),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 0.5),
                      ],
                    ),
                  )).toList(),
                ),
              ),
              Positioned(
                left: 14, right: 14, bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(type.label, style: MoraText.display(size: 22)),
                    const SizedBox(height: 4),
                    Text(type.hint, style: MoraText.body(size: 12, color: MoraColors.textSecondary)),
                  ],
                ),
              ),
              if (selected)
                Positioned(
                  top: 12, right: 12,
                  child: Container(
                    width: 26, height: 26,
                    decoration: const BoxDecoration(
                      color: MoraColors.accent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, size: 16, color: MoraColors.onAccent),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class FilmTypeScreen extends ConsumerStatefulWidget {
  const FilmTypeScreen({super.key});

  @override
  ConsumerState<FilmTypeScreen> createState() => _FilmTypeScreenState();
}

class _FilmTypeScreenState extends ConsumerState<FilmTypeScreen> {
  late EventType _selected;

  @override
  void initState() {
    super.initState();
    // Persist the user's last pick if they came back to this screen after
    // tapping forward into FilmDetails. Falls back to Owambe (our wedge).
    _selected = ref.read(filmDraftProvider).type ?? EventType.owambe;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            StepHeader(onBack: () => context.pop(), step: 1, of: 3),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      style: MoraText.display(size: 30),
                      children: [
                        const TextSpan(text: 'What kind of '),
                        TextSpan(text: 'film', style: MoraText.display(size: 30, italic: true)),
                        const TextSpan(text: '?'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Pick the gathering. We'll tune the defaults.",
                    style: MoraText.body(size: 14, color: MoraColors.textSecondary),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.0,
                  physics: const NeverScrollableScrollPhysics(),
                  children: _filmTypes
                      .map((t) => _AsoebiCard(
                            type: t,
                            selected: _selected == t.id,
                            onTap: () => setState(() => _selected = t.id),
                          ))
                      .toList(),
                ),
              ),
            ),
            BottomAction(
              children: [
                PrimaryButton(
                  label: 'Continue',
                  onTap: () {
                    ref.read(filmDraftProvider.notifier).setType(_selected);
                    context.push('/film-details');
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
