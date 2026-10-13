import 'package:flutter/material.dart';
import '../core/career_state.dart';
import '../core/commands.dart';
import '../core/scope.dart';
import '../core/images.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';
import 'game_shell.dart';
import 'new_career_screen.dart';
import 'settings_screen.dart';

/// Start screen: the list of careers (save slots).
class SlotsScreen extends StatefulWidget {
  const SlotsScreen({super.key});

  @override
  State<SlotsScreen> createState() => _SlotsScreenState();
}

class _SlotsScreenState extends State<SlotsScreen> {
  List<Map<String, Object?>>? _slots;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final slots = await context.controller.exec(Cmd.listSlots());
    if (mounted) setState(() => _slots = slots);
  }

  Future<void> _open(String slotId) async {
    final controller = context.controller;
    try {
      await controller.exec(Cmd.resume(slotId));
      if (!mounted) return;
      await openCareer(context, CareerState(controller));
    } catch (e) {
      if (mounted) showError(context, e);
    }
    _load();
  }

  Future<void> _delete(String slotId, String name) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.deleteCareerTitle),
        content: Text(l.deleteCareerBody(name)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(c, true), child: Text(l.delete)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.controller.exec(Cmd.deleteSlot(slotId));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final slots = _slots;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.appTitle),
        actions: [
          IconButton(
            tooltip: l.settings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(l.newCareer),
        onPressed: () async {
          await Navigator.push(context,
              MaterialPageRoute(builder: (_) => const NewCareerScreen()));
          _load();
        },
      ),
      body: slots == null
          ? const Center(child: CircularProgressIndicator())
          : slots.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.graphic_eq, size: 64),
                      const SizedBox(height: 16),
                      Text(l.noCareersTitle,
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text(l.noCareersBody, textAlign: TextAlign.center),
                    ]),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  itemCount: slots.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final s = slots[i];
                    final id = s['slotId'] as String;
                    final name = s['artistName'] as String? ?? '?';
                    final fame = (s['fame'] as num?)?.toDouble() ?? 0;
                    final fans = (s['coreFans'] as num?)?.toDouble() ?? 0;
                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        leading: ArtistAvatar(name: name, seed: id.hashCode),
                        title: Text(name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text(
                            '${context.fmt.weekOf(s['weekOfYear'] as int? ?? 1, s['year'] as int? ?? 0)}'
                            ' · ${l.fameValue(fmt.percent(fame))}'
                            ' · ${l.fansValue(fmt.compact(fans))}'),
                        onTap: () => _open(id),
                        trailing: IconButton(
                          tooltip: l.delete,
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _delete(id, name),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

/// Pushes the game for an opened career; closes the save when leaving.
Future<void> openCareer(BuildContext context, CareerState state) async {
  await state.refresh();
  if (!context.mounted) return;
  final images = context.imagesRead..open(state.slotId!);
  state.onScheduledAlbumOut = (scheduleId, albumId) => images.adoptWithEditions(
      ImageStore.scheduledKey(scheduleId), ImageStore.albumKey(albumId));
  await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => GameShell(state: state)),
  );
  images.close();
  await state.controller.exec(Cmd.closeCareer());
}
