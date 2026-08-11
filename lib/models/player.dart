/// A seat at the table for one game. Players are per-game, not global — the
/// same person in two games is two rows, which keeps history immutable.
class Player {
  const Player({required this.id, required this.name, required this.seatOrder});

  final String id;
  final String name;

  /// Position in the roster, used for stable ordering and tie-breaks.
  final int seatOrder;

  Player copyWith({String? name, int? seatOrder}) => Player(
        id: id,
        name: name ?? this.name,
        seatOrder: seatOrder ?? this.seatOrder,
      );

  @override
  bool operator ==(Object other) =>
      other is Player &&
      other.id == id &&
      other.name == name &&
      other.seatOrder == seatOrder;

  @override
  int get hashCode => Object.hash(id, name, seatOrder);
}
