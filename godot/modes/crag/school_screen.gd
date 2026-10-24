extends JournalPage
## The climbing school at Lion Rock: knowledge checks on knots, belaying,
## anchors and clipping, and reading a route. One question at a time,
## three answers; after you answer, why. Right answers open gear in the
## locker. Always on screen: this is a game, not a lesson.

var tabs: SegmentedTabs
var card_box: VBoxContainer
var progress: Label
var topic := "knots"
var current: Dictionary = {}
var answered := false
var _topics: Array = KnowledgeChecks.TOPICS.keys()


func build() -> void:
	set_title("Climbing school")
	var col := UiKit.vbox(5)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.add_child(col)
	var labels: Array = []
	for t in _topics:
		labels.append(KnowledgeChecks.TOPICS[t])
	tabs = SegmentedTabs.make(labels)
	tabs.changed.connect(func(i: int) -> void:
		topic = _topics[i]
		_next())
	col.add_child(tabs)
	progress = UiKit.label("", UiTokens.TEXT_S, UiTokens.INK_MUTED)
	col.add_child(progress)
	card_box = UiKit.vbox(4)
	col.add_child(JournalPage.scroller(card_box))
	var foot := UiKit.label(KnowledgeChecks.DISCLAIMER, UiTokens.TEXT_S, UiTokens.EMBER, false, 440.0)
	foot.name = "Disclaimer"
	col.add_child(foot)
	_next()


func _next() -> void:
	current = KnowledgeChecks.next_card(topic)
	if current.is_empty():
		# All right in this topic: go round again from the first.
		current = KnowledgeChecks.topic_cards(topic)[0]
	answered = false
	_render(-1)


func _render(picked: int) -> void:
	for c in card_box.get_children():
		c.queue_free()
	var n := KnowledgeChecks.topic_cards(topic).size()
	progress.text = "%s: %d of %d right · %d right in all (3 opens the hard shell, 6 the thermos of tea)" % [
		KnowledgeChecks.TOPICS[topic], KnowledgeChecks.right_in(topic), n, Profile.knowledge_right()]
	card_box.add_child(UiKit.label(String(current["q"]), UiTokens.TEXT_L + 1, UiTokens.INK, true, 440.0))
	var options: Array = current["options"]
	for i in options.size():
		var kind := "paper"
		var text := String(options[i])
		if picked >= 0:
			if i == int(current["answer"]):
				kind = "primary"
				text = "Right: " + text
			elif i == picked:
				kind = "danger"
				text = "Not this: " + text
		var b := UiKit.button(text, _answer.bind(i), kind, UiTokens.TEXT)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.name = "Option%d" % i
		b.disabled = picked >= 0 and i != picked and i != int(current["answer"])
		card_box.add_child(b)
	if picked >= 0:
		var why := UiKit.panel(UiTokens.PAPER_RAISED, 6.0)
		var w := UiKit.vbox(2)
		why.add_child(w)
		w.add_child(UiKit.label("Why", UiTokens.TEXT, UiTokens.INK, true))
		w.add_child(UiKit.label(String(current["why"]), UiTokens.TEXT, UiTokens.INK_SOFT, false, 420.0))
		if bool(current.get("simplified", false)):
			w.add_child(UiKit.label("Simplified for the game: the real answer depends on the situation.", UiTokens.TEXT_S, UiTokens.INK_MUTED))
		card_box.add_child(why)
		var next := UiKit.button("Next question", _next, "primary", UiTokens.TEXT)
		next.name = "Next"
		card_box.add_child(next)
		next.grab_focus.call_deferred()


func _answer(i: int) -> void:
	if answered:
		return
	answered = true
	var right := i == int(current["answer"])
	Profile.answer(String(current["id"]), right)
	Analytics.event("knowledge_answered", {"card": current["id"], "right": right})
	Audio.play("chime" if right else "thud", -10.0, 0.0, false)
	_render(i)
