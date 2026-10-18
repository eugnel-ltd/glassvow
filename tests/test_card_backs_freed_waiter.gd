extends RefCounted
## A successful shared bake belongs to callers whose hosts still exist.
## The render barrier makes host removal precede completion without timing.


static func run(fails: Array[String]) -> void:
	CardBacks.use_catalogue(null)
	var render: _BarrierRender = _BarrierRender.new()
	CardBacks.use_renderer(render.render)
	# Unparented hosts intentionally match the supported fake-render test seam.
	var owner_host: Node = Node.new()
	var live_host: Node = Node.new()
	var gone_host: Node = Node.new()
	var owner: _Caller = _Caller.start(owner_host)
	var live: _Caller = _Caller.start(live_host)
	var gone: _Caller = _Caller.start(gone_host)
	if render.calls != 1 or owner.done or live.done or gone.done:
		fails.append("card backs freed waiter: callers did not share one pending bake")
	gone_host.free()
	render.open.emit()
	if not owner.done or owner.got == null or CardBacks.cached("rose") != owner.got:
		fails.append("card backs freed waiter: successful owner did not keep its bake")
	if not live.done or live.got != owner.got:
		fails.append("card backs freed waiter: a live waiter lost the successful bake")
	if not gone.done or gone.got != null:
		fails.append("card backs freed waiter: successful shared bake reached a freed waiter")
	var repeat: _Caller = _Caller.start(owner_host)
	if not repeat.done or repeat.got != owner.got or render.calls != 1:
		fails.append("card backs freed waiter: owner cache hit was lost or a caller retried")
	CardBacks.use_renderer(Callable())
	CardBacks.use_catalogue(null)
	owner_host.free()
	live_host.free()


class _BarrierRender:
	extends RefCounted
	signal open
	var calls: int = 0

	func render(_host: Node, _id: String, scale: float) -> CardBacks.Baked:
		calls += 1
		await open
		var out: CardBacks.Baked = CardBacks.Baked.new()
		out.oversample = scale
		return out


class _Caller:
	extends RefCounted
	var done: bool = false
	var got: CardBacks.Baked = null

	static func start(host: Node) -> _Caller:
		var caller: _Caller = _Caller.new()
		caller._run(host)
		return caller

	func _run(host: Node) -> void:
		got = await CardBacks.bake(host, "rose")
		done = true
