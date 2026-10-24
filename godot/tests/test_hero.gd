extends TestCase
## The drawn climber (Hero, HeroRig): every pose is a real pose (finite,
## joints the right length), the same time gives the same pose, hands land
## on the wall targets, and each body and look draws without errors.


func test_every_pose_is_finite_and_deterministic() -> void:
	for body in ["m", "f"]:
		var b := HeroRig.build(body)
		for pose in HeroRig.POSES:
			var view: String = HeroRig.VIEW[pose]
			for t in [0.0, 0.37, 1.9]:
				var p1 := HeroRig.compute(b, pose, view, t)
				var p2 := HeroRig.compute(b, pose, view, t)
				for k in HeroRig.KEYS:
					var v := float(p1.get(k, 0.0))
					check(is_finite(v), "%s %s %s at %.2f is finite" % [body, pose, k, t])
					eq(v, float(p2.get(k, 0.0)), "%s %s %s: the same time, the same pose" % [body, pose, k])


func test_hands_reach_the_holds() -> void:
	var b := HeroRig.build("m")
	for pose in ["climbA", "climbB", "reach", "hang"]:
		var T := HeroRig.wall_targets(b, pose, 0.0)
		var p := HeroRig.compute(b, pose, "back", 0.0)
		var f := HeroRig.frame(b, p["lean"], "back")
		var arm := HeroRig.chain(f["sR"], p["uaR"], p["faR"], b["ua"], b["fa"])
		var reach: float = b["ua"] + b["fa"]
		var want: Vector2 = T["hR"]
		if f["sR"].distance_to(want) < reach - 0.1:
			check((arm[2] as Vector2).distance_to(want) < 0.5, "%s: the right hand is on its hold (%.2f off)" % [pose, (arm[2] as Vector2).distance_to(want)])


func test_ik_never_stretches_a_limb() -> void:
	var s := Vector2.ZERO
	for t in [Vector2(100, 0), Vector2(0, 0.01), Vector2(10, 10), Vector2(-5, 20)]:
		var r: Array = HeroRig.ik2(s, t, 16.0, 14.0, 1.0)
		var chain := HeroRig.chain(s, r[0], r[1], 16.0, 14.0)
		near(chain[0].distance_to(chain[1]), 16.0, 0.001, "upper arm keeps its length")
		near(chain[1].distance_to(chain[2]), 14.0, 0.001, "forearm keeps its length")


func test_every_look_draws() -> void:
	var screen := SubViewport.new()
	screen.size = Vector2i(480, 270)
	root.add_child(screen)
	var x := 10.0
	for hw in ["helmet", "beanie", "sunhat", "headlamp", "cap", "none"]:
		for pack in ["crag", "daypack", "expedition", "none"]:
			var h := Hero.new()
			h.set_look({"headwear": hw, "pack": pack, "body": "f" if pack == "daypack" else "m", "bagPattern": "dots"})
			h.pose = ["idle", "walk", "climb", "fall"][int(x) % 4]
			h.position = Vector2(x, 100)
			screen.add_child(h)
			x += 18.0
	await physics_frames(3)
	check(screen.get_child_count() == 24, "24 climbers drawn")
	screen.queue_free()
	await physics_frames(1)
