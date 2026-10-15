class_name Online
extends RefCounted
## The client of the CLIMB UP records service (docs/records-backend.md).
##
## Not connected in this build: there is no deployed service and no
## credentials, so configured() is false and nothing is ever sent. The
## pieces that do not need a server are here and tested: the rules for a
## public display name, the age gate, and what a submission carries.
## Records only ever become "verified" from a server's reply.

const CONFIG := "user://climb_up_online.json"
## Public names: 3 to 16 letters, digits, spaces, - or _, starting with a
## letter or digit. Checked again by the server (unique, case-insensitive).
const NAME_MIN := 3
const NAME_MAX := 16
## Words a public name may not contain (a short starter list; the server
## keeps the real one).
const BLOCKED := ["admin", "moderator", "official", "climbup"]
## Under this age a player gets no public name, no friends and no global
## boards (COPPA in the US; the stricter GDPR age where it applies is set
## by the server per country).
const MIN_PUBLIC_AGE := 13

var endpoint := ""
var token := ""
var player_id := ""
## The node HTTP requests run under (Records).
var host: Node
## For tests: a Callable(entry: Dictionary) -> Dictionary standing in for
## the network.
var transport: Callable


func _init() -> void:
	var d: Variant = SaveGame.read(CONFIG)
	if typeof(d) == TYPE_DICTIONARY:
		endpoint = String(d.get("endpoint", ""))
		token = String(d.get("token", ""))
		player_id = String(d.get("playerId", ""))


## True only with a service address and a signed-in player (or a test
## transport). Never true in a shipped build without both.
func configured() -> bool:
	return transport.is_valid() or (endpoint != "" and token != "")


## Sends one queued attempt. {ok, serverTime} when the server accepted
## it, {ok: false, reason} when it refused, {ok: false, retry: true} when
## the network failed (try again later).
func submit(entry: Dictionary) -> Dictionary:
	if transport.is_valid():
		return transport.call(entry)
	var r := await request("POST", "/v1/submissions", {"id": entry["id"], "kind": entry["kind"], "clientTime": entry["clientTime"], "payload": entry["payload"]})
	if r["code"] == 200:
		return r["body"]
	# No answer, a server error or "too many": keep it and try later.
	if r["code"] == 0 or r["code"] == 429 or r["code"] >= 500:
		return {"ok": false, "retry": true}
	return {"ok": false, "reason": String(r["body"].get("error", r["body"].get("reason", "refused")))}


## Makes an account on the service (age first, for privacy); saves the
## token. "" on success, else why not.
func register(base: String, age: int, display_name: String = "") -> String:
	endpoint = base
	var body := {"age": age}
	if display_name != "":
		body["displayName"] = display_name
	var r := await request("POST", "/v1/players", body)
	if r["code"] != 201:
		endpoint = ""
		return String(r["body"].get("error", "could not reach the service"))
	token = String(r["body"]["token"])
	player_id = String(r["body"]["playerId"])
	SaveGame.write({"endpoint": endpoint, "token": token, "playerId": player_id}, CONFIG)
	return ""


## Signs out on this device (the account stays on the server).
func forget() -> void:
	endpoint = ""
	token = ""
	player_id = ""
	SaveGame.erase(CONFIG)


## One JSON request: {code (0 if no answer), body}.
func request(method: String, path: String, body: Dictionary = {}) -> Dictionary:
	if host == null or not host.is_inside_tree() or endpoint == "":
		return {"code": 0, "body": {}}
	var http := HTTPRequest.new()
	http.timeout = 10.0
	host.add_child(http)
	var headers := PackedStringArray(["Content-Type: application/json"])
	if token != "":
		headers.append("Authorization: Bearer " + token)
	var verb: int = {"GET": HTTPClient.METHOD_GET, "POST": HTTPClient.METHOD_POST, "PATCH": HTTPClient.METHOD_PATCH, "DELETE": HTTPClient.METHOD_DELETE}[method]
	if http.request(endpoint + path, headers, verb, JSON.stringify(body) if method != "GET" else "") != OK:
		http.queue_free()
		return {"code": 0, "body": {}}
	var res: Array = await http.request_completed
	http.queue_free()
	var parsed: Variant = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8()) if (res[3] as PackedByteArray).size() > 0 else {}
	return {"code": int(res[1]) if int(res[0]) == HTTPRequest.RESULT_SUCCESS else 0, "body": parsed if typeof(parsed) == TYPE_DICTIONARY else {}}


## "" when `name` can be a public display name, else why not.
static func name_problem(name: String) -> String:
	var n := name.strip_edges()
	if n.length() < NAME_MIN or n.length() > NAME_MAX:
		return "Names are %d to %d characters." % [NAME_MIN, NAME_MAX]
	var re := RegEx.new()
	re.compile("^[A-Za-z0-9][A-Za-z0-9 _-]*$")
	if re.search(n) == null:
		return "Use letters, numbers, spaces, - and _, starting with a letter or number."
	var low := n.to_lower().replace(" ", "").replace("_", "").replace("-", "")
	for w in BLOCKED:
		if w in low:
			return "That name is reserved."
	return ""


## The key two names collide on (the server enforces uniqueness on it).
static func name_key(name: String) -> String:
	return name.strip_edges().to_lower().replace(" ", "").replace("_", "").replace("-", "")


## What an account may do at `age`: under MIN_PUBLIC_AGE, records stay
## private (no public name, no friends, no global boards).
static func age_rules(age: int) -> Dictionary:
	if age < MIN_PUBLIC_AGE:
		return {"publicName": false, "friends": false, "globalBoards": false, "note": "Under %d: your records stay private to you." % MIN_PUBLIC_AGE}
	return {"publicName": true, "friends": true, "globalBoards": true, "note": ""}
