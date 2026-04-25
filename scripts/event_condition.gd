extends RefCounted
class_name EventCondition

## Narrow condition DSL evaluator for event `enabled_if` expressions.
##
## Grammar:
##   expr   := or_expr
##   or     := and ("||" and)*
##   and    := atom ("&&" atom)*
##   atom   := "(" expr ")" | leaf
##
## Leaf tokens (whitespace-insensitive beyond their own spacing):
##   cash >= N
##   cash <= N                (also > < ==)
##   flag.<name>              — true iff flags[name] truthy
##   has_placed:<building_id> — true iff a structure_placed of that id in the registry
##   total.<bucket> >= N      — accumulated demand (monotonic)
##   fulfilled.<bucket> >= N  — placed capacity in that bucket
##   unserved.<bucket> >= N   — total - fulfilled (spendable bank)
##   demand.<bucket> >= N     — alias for unserved.<bucket> (back-compat)
##   state.<character_id> == "ARRIVED" | "WANT_REVEALED" | ...
##   count.<event_id> >= N
##
## Empty / whitespace-only expressions evaluate to TRUE (no gate).
## Unknown tokens evaluate to FALSE and log a warning (once per unique token).
##
## Context shape expected:
##   {
##     "cash": int,
##     "flags": Dictionary,                 # flag_name -> bool
##     "placed_ids": Dictionary,            # building_id -> bool / count (truthy check)
##     "demand": Dictionary,                # bucket_id -> unserved (alias)
##     "total": Dictionary,                 # bucket_id -> float
##     "fulfilled": Dictionary,             # bucket_id -> float
##     "unserved": Dictionary,              # bucket_id -> float
##     "character_states": Dictionary,      # character_id -> int
##     "event_counts": Dictionary,          # event_id -> int
##   }
##
## Missing keys read as neutral (0 / "" / false) rather than erroring.

const STATE_NAMES := {
	"NOT_ARRIVED":              0,
	"ARRIVED":                  1,
	"WANT_REVEALED":            2,
	"SATISFIED":                3,
	"CONTRIBUTES_TO_LANDMARK":  4,
}

static var _warned_tokens: Dictionary = {}

## Evaluate `expr` against `ctx`. Empty expression => true.
static func evaluate(expr: String, ctx: Dictionary) -> bool:
	var e := expr.strip_edges()
	if e.is_empty():
		return true
	return _eval_or(e, ctx)

# ── Top-down splitters (paren-aware) ──────────────────────────────────────────

static func _split_top_level(s: String, sep: String) -> Array:
	var parts: Array = []
	var depth := 0
	var start := 0
	var i := 0
	var n := s.length()
	var sl := sep.length()
	while i < n:
		var c := s[i]
		if c == "(":
			depth += 1
			i += 1
			continue
		if c == ")":
			depth -= 1
			i += 1
			continue
		if depth == 0 and i + sl <= n and s.substr(i, sl) == sep:
			parts.append(s.substr(start, i - start))
			i += sl
			start = i
			continue
		i += 1
	parts.append(s.substr(start, n - start))
	return parts

static func _eval_or(expr: String, ctx: Dictionary) -> bool:
	var parts: Array = _split_top_level(expr, "||")
	if parts.size() == 1:
		return _eval_and(expr, ctx)
	for p in parts:
		if _eval_and(String(p).strip_edges(), ctx):
			return true
	return false

static func _eval_and(expr: String, ctx: Dictionary) -> bool:
	var parts: Array = _split_top_level(expr, "&&")
	if parts.size() == 1:
		return _eval_atom(expr, ctx)
	for p in parts:
		if not _eval_atom(String(p).strip_edges(), ctx):
			return false
	return true

static func _eval_atom(expr: String, ctx: Dictionary) -> bool:
	var s := expr.strip_edges()
	if s.is_empty():
		return false
	# Parenthesised group — must wrap the *entire* atom, not just a leading open.
	if s.begins_with("(") and s.ends_with(")") and _parens_balanced_around(s):
		return _eval_or(s.substr(1, s.length() - 2), ctx)
	return _eval_leaf(s, ctx)

static func _parens_balanced_around(s: String) -> bool:
	var depth := 0
	for i in range(s.length()):
		var c := s[i]
		if c == "(":
			depth += 1
		elif c == ")":
			depth -= 1
			if depth == 0 and i != s.length() - 1:
				return false
	return depth == 0

# ── Leaf token evaluation ─────────────────────────────────────────────────────

static func _eval_leaf(raw: String, ctx: Dictionary) -> bool:
	var tok := raw.strip_edges()
	if tok.is_empty():
		return false

	# cash <op> N
	if tok.begins_with("cash "):
		var rhs := tok.substr(5).strip_edges()
		return _eval_numeric_cmp(int(ctx.get("cash", 0)), rhs)

	# demand.<bucket> / total.<bucket> / fulfilled.<bucket> / unserved.<bucket>
	for prefix: String in ["demand.", "total.", "fulfilled.", "unserved."]:
		if not tok.begins_with(prefix):
			continue
		var rest := tok.substr(prefix.length())
		var sp := _find_first_op_boundary(rest)
		if sp < 0:
			return _warn_and_false(tok)
		var bucket := rest.substr(0, sp).strip_edges()
		var cmp := rest.substr(sp).strip_edges()
		var ctx_key: String = prefix.trim_suffix(".")
		var val: float = float(ctx.get(ctx_key, {}).get(bucket, 0.0))
		return _eval_numeric_cmp_f(val, cmp)

	# count.<event_id> <op> N
	if tok.begins_with("count."):
		var rest2 := tok.substr(6)
		var sp2 := _find_first_op_boundary(rest2)
		if sp2 < 0:
			return _warn_and_false(tok)
		var eid := rest2.substr(0, sp2).strip_edges()
		var cmp2 := rest2.substr(sp2).strip_edges()
		var n: int = int(ctx.get("event_counts", {}).get(eid, 0))
		return _eval_numeric_cmp(n, cmp2)

	# state.<character_id> == "<STATE>"
	if tok.begins_with("state."):
		var rest3 := tok.substr(6)
		var eq := rest3.find("==")
		if eq < 0:
			return _warn_and_false(tok)
		var cid := rest3.substr(0, eq).strip_edges()
		var rhs3 := rest3.substr(eq + 2).strip_edges()
		if rhs3.begins_with("\""):
			rhs3 = rhs3.substr(1)
		if rhs3.ends_with("\""):
			rhs3 = rhs3.substr(0, rhs3.length() - 1)
		rhs3 = rhs3.strip_edges()
		var want: int = int(STATE_NAMES.get(rhs3, -1))
		if want < 0:
			return _warn_and_false(tok)
		var cur: int = int(ctx.get("character_states", {}).get(cid, 0))
		return cur == want

	# flag.<name>
	if tok.begins_with("flag."):
		var name := tok.substr(5).strip_edges()
		return bool(ctx.get("flags", {}).get(name, false))

	# has_placed:<id>
	if tok.begins_with("has_placed:"):
		var bid := tok.substr(11).strip_edges()
		var placed: Dictionary = ctx.get("placed_ids", {})
		return bool(placed.get(bid, false))

	return _warn_and_false(tok)

# ── Numeric comparison helpers ────────────────────────────────────────────────

## Find the first index where an operator ( >= <= == > < ) begins.
## Returns -1 if none.
static func _find_first_op_boundary(s: String) -> int:
	for i in range(s.length()):
		var c := s[i]
		if c == ">" or c == "<" or c == "=":
			return i
	return -1

static func _parse_cmp(rhs: String) -> Array:
	# Split "<op> N" into [op, value_str].
	var r := rhs.strip_edges()
	var op := ""
	var rest := ""
	if r.begins_with(">="):
		op = ">="
		rest = r.substr(2)
	elif r.begins_with("<="):
		op = "<="
		rest = r.substr(2)
	elif r.begins_with("=="):
		op = "=="
		rest = r.substr(2)
	elif r.begins_with(">"):
		op = ">"
		rest = r.substr(1)
	elif r.begins_with("<"):
		op = "<"
		rest = r.substr(1)
	else:
		return []
	return [op, rest.strip_edges()]

static func _eval_numeric_cmp(lhs: int, rhs: String) -> bool:
	var parts: Array = _parse_cmp(rhs)
	if parts.is_empty():
		return _warn_and_false(rhs)
	var op: String = parts[0]
	var n: int = int(parts[1])
	match op:
		">=": return lhs >= n
		"<=": return lhs <= n
		"==": return lhs == n
		">":  return lhs > n
		"<":  return lhs < n
	return false

static func _eval_numeric_cmp_f(lhs: float, rhs: String) -> bool:
	var parts: Array = _parse_cmp(rhs)
	if parts.is_empty():
		return _warn_and_false(rhs)
	var op: String = parts[0]
	var n: float = float(parts[1])
	match op:
		">=": return lhs >= n
		"<=": return lhs <= n
		"==": return is_equal_approx(lhs, n)
		">":  return lhs > n
		"<":  return lhs < n
	return false

static func _warn_and_false(tok: String) -> bool:
	if not _warned_tokens.has(tok):
		_warned_tokens[tok] = true
		push_warning("[EventCondition] unknown_token: \"%s\"" % tok)
	return false
