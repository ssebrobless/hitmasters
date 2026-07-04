extends RefCounted

enum State {
	NORMAL,
	LATCHED,
	AIRBORNE,
	PERCHED,
	BURROWED,
	MOUNTED,
	STANCE,
	DEFENDING,
}

static func can_transition(from_state: State, to_state: State) -> bool:
	if from_state == to_state:
		return true
	match from_state:
		State.BURROWED:
			return to_state == State.NORMAL
		State.MOUNTED:
			return to_state == State.NORMAL
		_:
			return true

static func label(state: State) -> String:
	match state:
		State.LATCHED:
			return "latched"
		State.AIRBORNE:
			return "airborne"
		State.PERCHED:
			return "perched"
		State.BURROWED:
			return "burrowed"
		State.MOUNTED:
			return "mounted"
		State.STANCE:
			return "stance"
		State.DEFENDING:
			return "defending"
		_:
			return "normal"
