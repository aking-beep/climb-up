class_name Online
extends RefCounted
## The client of the CLIMB UP records service (docs/records-backend.md).
##
## A build talks to a service only when it names one: the project setting
## climb_up/records/endpoint (set for a beta build, see
## server/deploy/README.md), or CLIMB_UP_RECORDS_ENDPOINT in the
## environment (desktop testing). Without one, available() is false, the
## game keeps every record on the device and the online boards say they are
## not connected. With one, nothing is sent until the player makes an
## account (age first) on the account screen. Records only ever become
## "verified" from a server's reply.
##
## The account is the token the server issued: it is also the recovery
## code a player copies to restore the account on another device.

const CONFIG := "user://climb_up_online.json"
const ENDPOINT_SETTING := "climb_up/records/endpoint"
const PRIVACY_SETTING := "climb_up/records/privacy_url"
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
## Online accounts are for players this old and up; younger players keep
## their records on the device (no account, nothing sent).
const MIN_ACCOUNT_AGE := 13

var endpoint := ""
var token := ""
var player_id := ""
var display_name := ""
var friend_code := ""
var visibility := ""
## Set when the age asked for an account was under MIN_ACCOUNT_AGE: the
## device does not ask again (a neutral age gate is not retried).
var under_age := false
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
		display_name = String(d.get("displayName", ""))
		friend_code = String(d.get("friendCode", ""))
		visibility = String(d.get("visibility", ""))
		under_age = bool(d.get("underAge", false))
	if endpoint == "":
		endpoint = build_endpoint()


## The service this build talks to ("" for none): the environment's, else
## the project setting's. Only https, except on this machine (testing).
static func build_endpoint() -> String:
	var e := OS.get_environment("CLIMB_UP_RECORDS_ENDPOINT")
	if e == "":
		e = String(ProjectSettings.get_setting(ENDPOINT_SETTING, ""))
	e = e.strip_edges().trim_suffix("/")
	return e if endpoint_ok(e) else ""


static func endpoint_ok(url: String) -> bool:
	if url.begins_with("https://") and url.length() > 8:
		return true
	for local in ["http://127.0.0.1", "http://localhost", "http://10.0.2.2"]:
		if url.begins_with(local):
			return true
	return false


## The privacy policy's address, for the sign-up screen ("" if none set).
static func privacy_url() -> String:
	return String(ProjectSettings.get_setting(PRIVACY_SETTING, ""))


## True when this build has a service to talk to (signed in or not).
func available() -> bool:
	return transport.is_valid() or endpoint != ""


func signed_in() -> bool:
	return token != ""


func _save() -> void:
	SaveGame.write({"endpoint": endpoint, "token": token, "playerId": player_id, "displayName": display_name,
		"friendCode": friend_code, "visibility": visibility, "underAge": under_age}, CONFIG)


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
	# Signed out on the server (the account was deleted elsewhere): stop.
	if r["code"] == 401:
		return {"ok": false, "retry": true}
	# No answer, a server error or "too many": keep it and try later.
	if r["code"] == 0 or r["code"] == 429 or r["code"] >= 500:
		return {"ok": false, "retry": true}
	return {"ok": false, "reason": String(r["body"].get("error", r["body"].get("reason", "refused")))}


## Makes an account on the service (age first, for privacy); saves the
## token. "" on success, else why not. `base` "" means this build's.
func register(base: String, age: int, name: String = "") -> String:
	if age < MIN_ACCOUNT_AGE:
		under_age = true
		_save()
		return "Online records are for players %d and over. Your records stay on this device." % MIN_ACCOUNT_AGE
	var was := endpoint
	if base != "":
		endpoint = base.trim_suffix("/")
	var body := {"age": age}
	if name.strip_edges() != "":
		var problem := name_problem(name)
		if problem != "":
			endpoint = was
			return problem
		body["displayName"] = name.strip_edges()
	var r := await request("POST", "/v1/players", body)
	if r["code"] != 201:
		endpoint = was
		return _why(r)
	token = String(r["body"]["token"])
	player_id = String(r["body"]["playerId"])
	friend_code = String(r["body"].get("friendCode", ""))
	visibility = String(r["body"].get("visibility", ""))
	display_name = String(body.get("displayName", ""))
	_save()
	return ""


## Restores an account on this device from its recovery code. "" on
## success, else why not.
func restore(base: String, code: String) -> String:
	var was := [endpoint, token]
	if base != "":
		endpoint = base.trim_suffix("/")
	token = code.strip_edges()
	var r := await request("GET", "/v1/me")
	if r["code"] != 200:
		endpoint = was[0]
		token = was[1]
		return "That recovery code was not recognised." if r["code"] == 401 else _why(r)
	_take_me(r["body"])
	_save()
	return ""


## Fetches the account's details again (name, friend code, visibility).
func refresh() -> bool:
	var r := await request("GET", "/v1/me")
	if r["code"] != 200:
		return false
	_take_me(r["body"])
	_save()
	return true


func _take_me(me: Dictionary) -> void:
	player_id = String(me.get("playerId", ""))
	display_name = String(me.get("displayName", "")) if me.get("displayName") != null else ""
	friend_code = String(me.get("friendCode", ""))
	visibility = String(me.get("visibility", ""))


## Deletes the account and everything the service holds about it, then
## signs out here. "" on success.
func delete_account() -> String:
	var r := await request("DELETE", "/v1/me")
	if r["code"] != 204:
		return _why(r)
	forget()
	return ""


## A leaderboard: {ok, entries} or {ok: false, reason}. `kind` is crag,
## daily or expedition; `id` the route, date or difficulty.
func board(kind: String, id: String, scope: String, query: String = "") -> Dictionary:
	var r := await request("GET", "/v1/leaderboards/%s/%s?scope=%s%s" % [kind, id.uri_encode(), scope, ("&" + query) if query != "" else ""])
	if r["code"] != 200:
		return {"ok": false, "reason": _why(r)}
	return {"ok": true, "entries": r["body"].get("entries", [])}


## First verified ascents and completions, by the server's clock.
func firsts() -> Dictionary:
	var r := await request("GET", "/v1/firsts")
	if r["code"] != 200:
		return {"ok": false, "reason": _why(r)}
	return {"ok": true, "firsts": r["body"].get("firsts", [])}


func add_friend(code: String) -> String:
	var r := await request("POST", "/v1/friends", {"friendCode": code.strip_edges().to_upper()})
	return "" if r["code"] == 200 else ("No player has that friend code." if r["code"] == 404 else _why(r))


func report(name: String, reason: String = "name") -> String:
	var r := await request("POST", "/v1/reports", {"player": name, "reason": reason})
	return "" if r["code"] == 200 else _why(r)


## Why a request failed, in words for the player.
static func _why(r: Dictionary) -> String:
	if int(r["code"]) == 0:
		return "Could not reach the CLIMB UP service. Check your connection and try again."
	if int(r["code"]) >= 500:
		return "The CLIMB UP service had a problem. Try again later."
	return String(r["body"].get("error", r["body"].get("reason", "The service said no (%d)." % int(r["code"]))))


## Signs out on this device (the account stays on the server). The
## device's under-age answer is kept.
func forget() -> void:
	token = ""
	player_id = ""
	display_name = ""
	friend_code = ""
	visibility = ""
	endpoint = build_endpoint()
	if under_age:
		_save()
	else:
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
