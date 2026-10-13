import 'package:simulation_core/simulation_core.dart';

/// Grades of the player's songs by skills, budget and team (docs F35).
void main() {
  String letter(int x) => x >= 90
      ? 'A+'
      : x >= 80
          ? 'A'
          : x >= 70
              ? 'B'
              : x >= 55
                  ? 'C'
                  : x >= 40
                      ? 'D'
                      : 'E';
  for (final skill in [35.0, 60.0, 100.0]) {
    for (final team in [false, true]) {
      for (final budget in BudgetTier.values) {
        final counts = <String, int>{};
        for (var seed = 1; seed <= 20; seed++) {
          final w = WorldGen.create(seed: seed, startYear: 2018);
          final p = WorldGen.addPlayer(w,
              name: 'P',
              genre: 0,
              tier: StartTier.unknown,
              money: StartMoney.millionaire);
          for (final k in SkillKind.values) {
            p.skills[k] = skill;
          }
          p.coreFans = 1e8; // every collaborator available
          p.fame = 1;
          Collaborator? best(CollaboratorRole r) => team
              ? (w.collaborators.where((c) => c.role == r).toList()
                    ..sort((a, b) => b.skill.compareTo(a.skill)))
                  .first
              : null;
          for (var i = 0; i < 10; i++) {
            p.creativeEnergy = 100;
            final s = Actions.writeSong(w, p,
                budget: budget,
                producer: best(CollaboratorRole.producer),
                cowriter: best(CollaboratorRole.songwriter));
            final g = letter(s.quality.round());
            counts[g] = (counts[g] ?? 0) + 1;
            w.week++;
          }
        }
        final order = ['A+', 'A', 'B', 'C', 'D', 'E'];
        print('skills ${skill.round().toString().padLeft(3)} '
            '${team ? 'top team' : 'alone   '} ${budget.name.padRight(6)} '
            '${order.where(counts.containsKey).map((g) => '$g ${counts[g]}').join(', ')}');
      }
    }
  }
}
