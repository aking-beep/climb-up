extends TestCase
## The camp screen as a strategy screen on a phone: every choice of every
## decision fits on screen at once (played through a careful expedition on
## a 480 x 270 view), a choice shows its consequences as chips, the first
## tap previews it on the resources and the second commits it, and the
## party and the log are a tab away.


var screen: SubViewport
var camp: Node


var view := Vector2i(480, 270)


func _open() -> void:
	screen = SubViewport.new()
	screen.size = view
	root.add_child(screen)
	camp = load(Expedition.CAMP).instantiate()
	screen.add_child(camp)
	await _settle()


func _settle() -> void:
	for i in 4:
		await tree.process_frame


func _close() -> void:
	screen.queue_free()
	await tree.process_frame


## Every word showing on the card.
func _screen_text() -> String:
	var out := ""
	var stack: Array = [camp.paper]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Label or n is Button:
			out += n.text + " "
		stack.append_array(n.get_children())
	return out


## True when every choice card and the confirm button are inside the card.
func _all_fit() -> String:
	# The screen itself: the card may not grow past its bottom edge.
	var area := Rect2(Vector2.ZERO, Vector2(view)).intersection(camp._scroll.get_global_rect())
	for b in camp.choice_cards:
		var r: Rect2 = b.get_global_rect()
		if r.end.y > area.end.y + 1.0 or r.position.y < area.position.y - 1.0:
			return "choice '%s' at %s outside %s" % [b.get_meta("title").text, r, area]
	if camp._confirm and camp._confirm.get_global_rect().end.y > area.end.y + 1.0:
		return "confirm outside the card"
	return ""


func test_every_decision_fits_on_a_phone() -> void:
	# A wide phone, and a 4:3 tablet (the narrowest the game's view gets).
	for v in [Vector2i(480, 270), Vector2i(360, 270)]:
		view = v
		await _play_and_check()
	view = Vector2i(480, 270)


func _play_and_check() -> void:
	SaveGame.erase()
	Expedition.navigate = false
	Expedition.new_expedition(7)
	await _open()
	var checked := 0
	var most := 0
	for n in 60:
		if not Expedition.active():
			break
		var p: Variant = Expedition.pending()
		if p != null:
			Expedition.finish_climb(TestSessions.complete(p))
			await _settle()
			continue
		var d: Dictionary = Expedition.trek().get("descent", {})
		if not d.is_empty() and not d.get("played", false):
			Expedition.finish_descent({"attemptId": d["attemptId"], "challengeId": "descent", "result": "complete", "staminaLeft": 60, "slips": 0, "assisted": true, "regrouped": false, "seconds": 300})
			await _settle()
			continue
		var card := Expedition.card()
		eq(camp.choice_cards.size(), card["choices"].size(), "%s: a card for every choice" % card["id"])
		var words := _screen_text().to_lower()
		for jargon in ["acclimat", "scree", "margin", " bid", "high camp", "summit push"]:
			check(not jargon in words, "%s: no '%s' on screen (plain words for everyone)" % [card["id"], jargon.strip_edges()])
		var bad: String = _all_fit()
		eq(bad, "", "%s (%d choices, type tier %d): everything on screen" % [card["id"], card["choices"].size(), camp.tier])
		checked += 1
		most = maxi(most, card["choices"].size())
		var pick := 0
		for i in card["choices"].size():
			if TestSessions.CAREFUL.has(card["choices"][i]["label"]):
				pick = i
		if card["id"] == "trek-route":
			pick = 0
		Expedition.choose(pick)
		await _settle()
	check(checked >= 15, "a whole expedition's decisions were checked (%d)" % checked)
	print("      %d decisions checked on a %d x %d screen, up to %d choices each" % [checked, view.x, view.y, most])
	await _close()
	SaveGame.erase()


func test_a_choice_is_previewed_then_confirmed() -> void:
	SaveGame.erase()
	Expedition.navigate = false
	Expedition.new_expedition(7)
	Expedition.choose(0)  # the long way
	await _open()
	var card := Expedition.card()
	var i := -1
	for k in card["choices"].size():
		if not Trek.foresee(Expedition.session, card["choices"][k], Expedition.def).get("deltas", {}).is_empty():
			i = k
			break
	check(i >= 0, "a choice with consequences")
	var flow: HFlowContainer = camp.choice_cards[i].get_meta("flow")
	check(flow.get_child_count() >= 2, "its consequences show as chips (%d)" % flow.get_child_count())
	var before: int = Expedition.state()["history"].size()
	check(camp._confirm.disabled, "nothing to confirm before a choice is picked")
	camp.choice_cards[i].pressed.emit()
	await _settle()
	eq(Expedition.state()["history"].size(), before, "the first tap only previews")
	check(not camp._confirm.disabled and "Confirm" in camp._confirm.text, "and offers Confirm")
	var deltas: Dictionary = Trek.foresee(Expedition.session, card["choices"][i], Expedition.def)["deltas"]
	var shown := false
	for key in deltas:
		if camp.chips.has(key) and camp.chips[key].preview == int(deltas[key]):
			shown = true
	check(shown, "the resources show what it would do (%s)" % deltas)
	eq(_all_fit(), "", "and everything still fits")
	camp.choice_cards[i].pressed.emit()
	await _settle()
	check(Expedition.state()["history"].size() > before, "the second tap commits")
	await _close()
	SaveGame.erase()


func test_plain_words_for_people_who_never_climbed() -> void:
	eq(Plain.say("Turn the bid around"), "Turn back before the top", "a climbing phrase in everyday words")
	eq(Plain.say("Faster on the scree."), "Faster on the loose gravel.", "a climbing word swapped")
	eq(Plain.say("Acclimatization matters"), "Getting used to the height matters", "keeping the capital letter")
	check(Plain.say("Pole pole, then pole pole.").count("(slowly, slowly)") == 1, "a local word explained once")
	eq(Plain.score("Risk management"), "Staying safe", "the score's names are plain too")
	eq(Plain.say("Scree and rock steps"), "Loose gravel and rock steps", "at the start of a sentence")


func test_the_party_and_the_log_are_a_tab_away() -> void:
	SaveGame.erase()
	Expedition.navigate = false
	Expedition.new_expedition(7)
	Expedition.choose(0)
	Expedition.choose(0)
	await _open()
	eq(camp._portraits.get_child_count(), 4, "four portraits")
	camp._open_tab("team")
	await _settle()
	var text := ""
	for c in camp.paper.get_children():
		if c is Label:
			text += c.text + " "
		for g in c.get_children():
			if g is Label:
				text += g.text + " "
	check("Lena" in text and "Jun" in text, "the team tab lists the party")
	camp._open_tab("log")
	await _settle()
	check(camp.paper.get_child_count() > 0, "the log tab shows what happened")
	camp._open_tab("decide")
	await _settle()
	check(not camp.choice_cards.is_empty(), "and back to the decision")
	await _close()
	SaveGame.erase()
