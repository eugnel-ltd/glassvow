extends RefCounted
## The Duskblade invariance guard (#544 P3): the balance tools were made class-
## parameterised without moving one Duskblade run. Every arm of the readout
## panel (C_shatter, C_lantern, C_edge, A, A_lit, R) in every cell (V0 and V5,
## fresh and full) is played on two seeds by the greedy pilot, and on one seed
## by the search player, and each whole run row (outcome, deck, fights, the
## flame descriptor and its per-fight rows) is digested. The digests were taken
## on main before the change, through the simulator's own option and policy
## path, so they are the rows `balance_readout.py run` writes.
##
## A pin moves only with a deliberate change to the Duskblade's play: the
## instrument (pilot or search version), its content, or the rules it runs. Say
## so in the commit that re-pins it, never as a side effect of something else.
##
## PINS are 1.0's instrument of record, pilot `p8-d0-v3` and search `s1` (the
## simulator's defaults, named here explicitly). PINS_1_1 pin the 1.1 instrument
## of #544 P6 beside them, pilot `p9` and search `s2`, on one seed a cell and arm
## for each player: its own rows move only with a deliberate change to it.
const Sim: GDScript = preload("res://tools/balance_sim.gd")
const Pilot: GDScript = preload("res://tools/balance_pilot.gd")
const Search: GDScript = preload("res://tools/balance_search.gd")
const ASPECT: String = "duskblade"
const ARMS: Dictionary = {
	"C_shatter": ["--way=shatter", "--build=adaptive"],
	"C_lantern": ["--way=lantern", "--build=adaptive"],
	"C_edge": ["--way=edge", "--build=adaptive"],
	"A": ["--way=none", "--build=adaptive"],
	"A_lit": ["--way=none", "--build=lit"],
	"R": ["--way=none", "--build=random"],
}
const CELLS: Array[String] = ["v0-fresh", "v0-full", "v5-fresh", "v5-full"]
const GREEDY_SEEDS: Array[int] = [12000, 12001]
const SEARCH_SEED: int = 12000
## The bots each panel is played by: --pilot and --search.
const BOTS_1_0: Array[String] = ["p8-d0-v3", "s1"]
const BOTS_1_1: Array[String] = ["p9", "s2"]
## "<cell>/<arm>/<player>/<seed>" -> the SHA-256 of the run row's JSON.
const PINS: Dictionary = {
	"v0-fresh/C_shatter/greedy/12000": "e6884361bad93bef66f7b26e269a8798bf22218aaf202b9d3e8278829a6571f3",
	"v0-fresh/C_shatter/greedy/12001": "9e9c865c44dcf8d0a25a0e001f54c2a0c0c1f399bcc659744afacb239de55b19",
	"v0-fresh/C_shatter/search/12000": "a5ce0abf5bd6300d035d6a6973cd6480333304ad0e85f7651653b21c79067142",
	"v0-fresh/C_lantern/greedy/12000": "ff55e432765bf8bb8b3a2e2441adb134a6d86a0011fae796b231be4672eb0cd6",
	"v0-fresh/C_lantern/greedy/12001": "0da6b57c628ea42e7c8c6458d6ec5a2da3dcd7087cc2e0f50f9d5ac82305269d",
	"v0-fresh/C_lantern/search/12000": "0b82b7e245133189f7eae1fee9995524f36131ad0543fe09971ec80dad61ffb9",
	"v0-fresh/C_edge/greedy/12000": "6ed1c4d2edcc6a12f9b769a36c7cc2da71a227faa34aa964f28b0d6e790317e9",
	"v0-fresh/C_edge/greedy/12001": "c7a7f667dc4892554f461c600ec5dc317271f1a4871b060fcc3319f49aebe4a4",
	"v0-fresh/C_edge/search/12000": "9272cd3f2b526e340417d9834bbade0130e64e000079638bb1d25b56bb9306c4",
	"v0-fresh/A/greedy/12000": "b3f74bab615865753e8a9646891c1778c9ab58802cb89f69ef7179161023bcab",
	"v0-fresh/A/greedy/12001": "d3ddc247ac56af2955e61bbe7395509d084195b4dc69d98a42b46b97c9b1e796",
	"v0-fresh/A/search/12000": "ac6a92318f6e451e6b09569409ed09f8c533a130663bd2ca2c553c8369e2ad15",
	"v0-fresh/A_lit/greedy/12000": "6e5be33dbc60209142e96b07ff37f4f83844c40c74d66685a0f65275d8c8283c",
	"v0-fresh/A_lit/greedy/12001": "0c4853a159bd8a6ce5b9e3df7d8630314df0e59251b04bc7df45f3b8f7aa86b0",
	"v0-fresh/A_lit/search/12000": "61b7f10432cc23d27e75153dfd1d9c3b3ccdc0dfcae0e6cf2e2ffd8f0d8a511d",
	"v0-fresh/R/greedy/12000": "a581181bd043ef61ab3ba990fafdb13db33c4dcf2ea539277f07a160c17053f5",
	"v0-fresh/R/greedy/12001": "353c94620538d31cb962cdcd25337c21c8e1e58530a7ff977d76a95d952ef9ea",
	"v0-fresh/R/search/12000": "e60bd190b663fb58a0157319ae6c058c744da6141ae66daf598ba24855a1639b",
	"v0-full/C_shatter/greedy/12000": "8d2ddeba66f4e065499451f33f3bb1b06d9638f8c30844259739b4eacd795271",
	"v0-full/C_shatter/greedy/12001": "5d7f85160fca6ba5400ede0b54ecb21ce2f073a531dba4d32f018f2f6a256c5f",
	"v0-full/C_shatter/search/12000": "67a203fa7dc70cb221eb7f9149f6f57ad6699f020b3ee4009ceaca030ed08c9d",
	"v0-full/C_lantern/greedy/12000": "83b5544f052cbb297352f9847cf2e12ed3269dc06b2ec343ce5df50956e6487a",
	"v0-full/C_lantern/greedy/12001": "b0d8c709c41ad40275a1d220fa766539523dde80124366a454d2a550a30dbf06",
	"v0-full/C_lantern/search/12000": "617b6bbfa71b9eb6e45405f2579e97821574daa4921237e16124fca66a656bcf",
	"v0-full/C_edge/greedy/12000": "9bc1dbda1b5ebc5547ddca99fc0d47b0a9c84f1c56af658d4ecf5fdb3e0ac2ae",
	"v0-full/C_edge/greedy/12001": "e382dcb5cace829cd1499619a7386742d739b42374181ac23c22b99f65bb2163",
	"v0-full/C_edge/search/12000": "4d0bcffb0a1e5631fd16c1ebb94357078f52226245d89a1c5709fcd03a000f7c",
	"v0-full/A/greedy/12000": "601774be6e04ea826ce245600099374f6d90b6387e25ac37b07fb1f84d21a643",
	"v0-full/A/greedy/12001": "4c443f36c0ba2299a8d673305ed66198075fc8cae78c0a8267eba897069de346",
	"v0-full/A/search/12000": "15dfde9928de573495a555c441e1a0227cf79813066f5ae60dc1838b552feac2",
	"v0-full/A_lit/greedy/12000": "ff31150957b4bd070ed8edb2a9c243028b83b3753df72982e6f1489bc360c15b",
	"v0-full/A_lit/greedy/12001": "547df72899fd7ecaf8a9444771d8716637b1e51107b62905fd245466f042c2c7",
	"v0-full/A_lit/search/12000": "fcea4f77e2b68e85589251a0415721b70389182a502ea4a0c578dc140c621719",
	"v0-full/R/greedy/12000": "e8f7278efec86b2816a06f9e1450492da02d37f0bd131893462a244320f74fd6",
	"v0-full/R/greedy/12001": "bda48c51171ce3e4837d564cfd692e9f7e1707b6a5694f3975181bc9dcd56a33",
	"v0-full/R/search/12000": "094b661da95ee21522f74fa9af8ba91db7be310e9f10c6eed1db9cfeaae0019f",
	"v5-fresh/C_shatter/greedy/12000": "3e3154e2dec133e54188c9b0e092f9686e765941956780a9988849822a21fb8b",
	"v5-fresh/C_shatter/greedy/12001": "f3d6d2d433e70c31ed06f1dd7dc6051cbaafb2122d77da254fa55fdfd50ec5bd",
	"v5-fresh/C_shatter/search/12000": "c7e14e58e65ecbe46005b2bbb96be0ebc859c81ecb339a1cea2b89e8cf6704f2",
	"v5-fresh/C_lantern/greedy/12000": "24f0202d8fdb4f52d64ee0ccd68f186333233c86204ccb7960e9ea6110087b72",
	"v5-fresh/C_lantern/greedy/12001": "33a9ea7169d844029b446f33ecada0730eed53b0a8a964015a9d81e3b4c6dff7",
	"v5-fresh/C_lantern/search/12000": "05df2c561d8db3aa2614ecf2686e7e92e170f84fee8bdd993058a8b3d8134b50",
	"v5-fresh/C_edge/greedy/12000": "6c1ea169ee5770cde94fb73d681808cabaaa4d962e4c3cd2907af4b4b839927c",
	"v5-fresh/C_edge/greedy/12001": "440cf23fbb21b49369e967010915e092a0b633f2e8bf5cf9e4858ae47978adb2",
	"v5-fresh/C_edge/search/12000": "214929c4e36ca7eca0e1e4f66696bfbcd725cc66d98c1347cf60e7ab293431df",
	"v5-fresh/A/greedy/12000": "48caaef247dca56a3b3541db748a88c40dddd0a11874066bf3d3d27627502947",
	"v5-fresh/A/greedy/12001": "fd68fbea19b3c10bf6f2832e69be70d6fa2162ea543e4c8a3cc8ecf1b19447db",
	"v5-fresh/A/search/12000": "868beddd657b9b15eb6e7e68d6741a4198d015fe8522bb8a2a8fa5b59e82bfa5",
	"v5-fresh/A_lit/greedy/12000": "517e49149798ed491593953ef5f9c5be1f833eda74087513fe2130ecf5ecbea2",
	"v5-fresh/A_lit/greedy/12001": "50234599101dd2bbd2da9a5d51e6c85c82867b929fb9ef589270429fd4bbe8d1",
	"v5-fresh/A_lit/search/12000": "77d0a35a776115b4e065fb11c46700d6e8c48fc11ed684506655c1b52dd024d9",
	"v5-fresh/R/greedy/12000": "7d2cceba4be9502290a0f0340c11c4addae536f0053f8c1820c05bce1e69f908",
	"v5-fresh/R/greedy/12001": "32fca61cb57aadcdfa24af8bf32a4f9e1bb4932b83e57f5b418912b84f614080",
	"v5-fresh/R/search/12000": "7a6ed1b1c6d78e8fe89ce1a1fad3b928112567afcbb1df3ffedf8e908be56fb7",
	"v5-full/C_shatter/greedy/12000": "eb9f165df74108995151667b1e7b3c641f6bb11fe48d83d9b61c5c9a8468ab99",
	"v5-full/C_shatter/greedy/12001": "2df20ac07d81d4d81bebb58406397dbbe38a379e231e57dc30bdaeda44db3ee4",
	"v5-full/C_shatter/search/12000": "6274bd0192c057c6ee605a6fcf426cbcf5e0783a8d35f52d8f1b3ee48c0eaff7",
	"v5-full/C_lantern/greedy/12000": "612c74e993edd189b85ecafde7aaaa7c92ce67a18df7c9466db14f2f53eaf1a7",
	"v5-full/C_lantern/greedy/12001": "e1440a70eb11d306a7e6868cb1b03564fe16bdc205c9edbfe088aa0f50d6c8a6",
	"v5-full/C_lantern/search/12000": "3125186c34bfb8d47807e554a43a6f60584cbeef5ed8d1ce7e224a302ce1fd19",
	"v5-full/C_edge/greedy/12000": "d885093d97e6e3a71ae80b80b723c415cec86b3f3d2ae8fb3c54322303984a72",
	"v5-full/C_edge/greedy/12001": "9eec2362701b7cf0a0ef637c9f088bfe32d1ec7a20c07a3a663ec8c8c3ea21b6",
	"v5-full/C_edge/search/12000": "38259b8a99d8c8440c94c77feddb0f1f71d0396154993fb17275918fc0a68b32",
	"v5-full/A/greedy/12000": "f587b37be4362408909ef9ab816683b2c1bfb796b318f234ee5d070ce101860f",
	"v5-full/A/greedy/12001": "49a76fa32045fbb9f48fdbe4535a77f12f4f06d67374b4e0d962eb37d91a39be",
	"v5-full/A/search/12000": "f1fba7364b0a32236b6842eeb94075aafdce9f5f73f90bc9d88335be4a323ed5",
	"v5-full/A_lit/greedy/12000": "6b218de45f27b630a37e6006fbf108a533e68f2dd7fb6c6d05d70dbe03ba6e79",
	"v5-full/A_lit/greedy/12001": "5bc9db78ac0e82a985d19d4a875c7a597ac99cc5dff4727af8b586ebda8d89a2",
	"v5-full/A_lit/search/12000": "fb6f42680d334a06c0355816e14d0f225228886661d3b79ebef8d76414f97cb8",
	"v5-full/R/greedy/12000": "860a8d6f7308be1533c4a45841e4641d17ccc9c66193c75a3af9b7d9db059913",
	"v5-full/R/greedy/12001": "ddbde79f4b8430f8e93b558c762b1ac8b72c3cb2b6a93aec4ef5424ace96ff4f",
	"v5-full/R/search/12000": "5bde20dec314220f2c453744b6d664ca9698cfb1cb4c9b6678c310be81a5cffd",
}
## The 1.1 instrument's panel (#544 P6): pilot p9, search s2.
const PINS_1_1: Dictionary = {
	"v0-fresh/C_shatter/greedy/12000/p9-s2": "e6884361bad93bef66f7b26e269a8798bf22218aaf202b9d3e8278829a6571f3",
	"v0-fresh/C_shatter/search/12000/p9-s2": "a6c27a431234b5eb3acd66fc32d89d66d8b6b04624c491ebca93bb78981e12d3",
	"v0-fresh/C_lantern/greedy/12000/p9-s2": "ff55e432765bf8bb8b3a2e2441adb134a6d86a0011fae796b231be4672eb0cd6",
	"v0-fresh/C_lantern/search/12000/p9-s2": "deb3cfbe29ccbaa2f97482c2a3ceafcbc296ce3ad02fe7fbe5a674ff8b7a7835",
	"v0-fresh/C_edge/greedy/12000/p9-s2": "6ed1c4d2edcc6a12f9b769a36c7cc2da71a227faa34aa964f28b0d6e790317e9",
	"v0-fresh/C_edge/search/12000/p9-s2": "e4d30d0da8bd9390b8d29f2361c989204d8e9378ed85456c7db5792826d4d750",
	"v0-fresh/A/greedy/12000/p9-s2": "b3f74bab615865753e8a9646891c1778c9ab58802cb89f69ef7179161023bcab",
	"v0-fresh/A/search/12000/p9-s2": "ac6a92318f6e451e6b09569409ed09f8c533a130663bd2ca2c553c8369e2ad15",
	"v0-fresh/A_lit/greedy/12000/p9-s2": "6e5be33dbc60209142e96b07ff37f4f83844c40c74d66685a0f65275d8c8283c",
	"v0-fresh/A_lit/search/12000/p9-s2": "61b7f10432cc23d27e75153dfd1d9c3b3ccdc0dfcae0e6cf2e2ffd8f0d8a511d",
	"v0-fresh/R/greedy/12000/p9-s2": "a581181bd043ef61ab3ba990fafdb13db33c4dcf2ea539277f07a160c17053f5",
	"v0-fresh/R/search/12000/p9-s2": "e2f05476cd46c80dd92f28634d5806c7590ace69da09aeeb662802e0e7e6a352",
	"v0-full/C_shatter/greedy/12000/p9-s2": "8d2ddeba66f4e065499451f33f3bb1b06d9638f8c30844259739b4eacd795271",
	"v0-full/C_shatter/search/12000/p9-s2": "0a271c1411fedbdf1141ffef8a0afe2e5a6244bede8f817a5f556160946ce7f8",
	"v0-full/C_lantern/greedy/12000/p9-s2": "83b5544f052cbb297352f9847cf2e12ed3269dc06b2ec343ce5df50956e6487a",
	"v0-full/C_lantern/search/12000/p9-s2": "3700b2bbc2b6ee5b60f35bf05291e79b313c7e75a3234778e427cb07179676d2",
	"v0-full/C_edge/greedy/12000/p9-s2": "9bc1dbda1b5ebc5547ddca99fc0d47b0a9c84f1c56af658d4ecf5fdb3e0ac2ae",
	"v0-full/C_edge/search/12000/p9-s2": "b09b98f0ca8d1864b5961d1168abef6b3ce905cd8a98a4bab159137ea146fea9",
	"v0-full/A/greedy/12000/p9-s2": "601774be6e04ea826ce245600099374f6d90b6387e25ac37b07fb1f84d21a643",
	"v0-full/A/search/12000/p9-s2": "87d8d44e723f14ade5e2025650e53cc54fe66dc555324f82dc39bff852a79a2e",
	"v0-full/A_lit/greedy/12000/p9-s2": "ff31150957b4bd070ed8edb2a9c243028b83b3753df72982e6f1489bc360c15b",
	"v0-full/A_lit/search/12000/p9-s2": "8c5966fd4608213fd2885941447cbcb35b1a6f302eb0413e3b14040db17f1e2f",
	"v0-full/R/greedy/12000/p9-s2": "e8f7278efec86b2816a06f9e1450492da02d37f0bd131893462a244320f74fd6",
	"v0-full/R/search/12000/p9-s2": "094b661da95ee21522f74fa9af8ba91db7be310e9f10c6eed1db9cfeaae0019f",
	"v5-fresh/C_shatter/greedy/12000/p9-s2": "3e3154e2dec133e54188c9b0e092f9686e765941956780a9988849822a21fb8b",
	"v5-fresh/C_shatter/search/12000/p9-s2": "1ec5e1e4b8ff5fef201792b40e0a75ce446ba86c9bcb4b01afeec4e47ff6d344",
	"v5-fresh/C_lantern/greedy/12000/p9-s2": "3591c67f368bc540e308462adfd862a790655bc2330599d4572793a8b4c34839",
	"v5-fresh/C_lantern/search/12000/p9-s2": "05df2c561d8db3aa2614ecf2686e7e92e170f84fee8bdd993058a8b3d8134b50",
	"v5-fresh/C_edge/greedy/12000/p9-s2": "6c1ea169ee5770cde94fb73d681808cabaaa4d962e4c3cd2907af4b4b839927c",
	"v5-fresh/C_edge/search/12000/p9-s2": "8ac94ab275fe307ac4f0f713574f1ae1997de8a8c19cd026fd626e564f75c783",
	"v5-fresh/A/greedy/12000/p9-s2": "b679d0a03cbd987a9a018572ca1dc1a87b9b0176141e8649d76b23aa4048e93a",
	"v5-fresh/A/search/12000/p9-s2": "868beddd657b9b15eb6e7e68d6741a4198d015fe8522bb8a2a8fa5b59e82bfa5",
	"v5-fresh/A_lit/greedy/12000/p9-s2": "54387e5d1855ff9e16afa13c162da5a3ed1157920b24b02a68cae089c8debeb8",
	"v5-fresh/A_lit/search/12000/p9-s2": "77d0a35a776115b4e065fb11c46700d6e8c48fc11ed684506655c1b52dd024d9",
	"v5-fresh/R/greedy/12000/p9-s2": "7d2cceba4be9502290a0f0340c11c4addae536f0053f8c1820c05bce1e69f908",
	"v5-fresh/R/search/12000/p9-s2": "30f4fecf0cfeb4e932e78f97c69fc6628264a34ea6d7134978cfd2a08650926d",
	"v5-full/C_shatter/greedy/12000/p9-s2": "eb9f165df74108995151667b1e7b3c641f6bb11fe48d83d9b61c5c9a8468ab99",
	"v5-full/C_shatter/search/12000/p9-s2": "6274bd0192c057c6ee605a6fcf426cbcf5e0783a8d35f52d8f1b3ee48c0eaff7",
	"v5-full/C_lantern/greedy/12000/p9-s2": "612c74e993edd189b85ecafde7aaaa7c92ce67a18df7c9466db14f2f53eaf1a7",
	"v5-full/C_lantern/search/12000/p9-s2": "07df2407eb41d35d67c844fa80b8a3cd670ec4b4f983e7cae69c16475456edad",
	"v5-full/C_edge/greedy/12000/p9-s2": "d885093d97e6e3a71ae80b80b723c415cec86b3f3d2ae8fb3c54322303984a72",
	"v5-full/C_edge/search/12000/p9-s2": "c51aa02f515a6abfb1f382d3c3797a6f982afe82042b3994ba5d4321f8a127d0",
	"v5-full/A/greedy/12000/p9-s2": "f587b37be4362408909ef9ab816683b2c1bfb796b318f234ee5d070ce101860f",
	"v5-full/A/search/12000/p9-s2": "f1fba7364b0a32236b6842eeb94075aafdce9f5f73f90bc9d88335be4a323ed5",
	"v5-full/A_lit/greedy/12000/p9-s2": "6b218de45f27b630a37e6006fbf108a533e68f2dd7fb6c6d05d70dbe03ba6e79",
	"v5-full/A_lit/search/12000/p9-s2": "fb6f42680d334a06c0355816e14d0f225228886661d3b79ebef8d76414f97cb8",
	"v5-full/R/greedy/12000/p9-s2": "860a8d6f7308be1533c4a45841e4641d17ccc9c66193c75a3af9b7d9db059913",
	"v5-full/R/search/12000/p9-s2": "4c8aa6b17aa7ef773354dba714c9bd729e30db6e4e817ff8401d0c73f9894d7f",
}


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	_check(fails, "", PINS, digests(content, BOTS_1_0, GREEDY_SEEDS, ""))
	var one_seed: Array[int] = [SEARCH_SEED]
	_check(fails, "1.1 ", PINS_1_1, digests(content, BOTS_1_1, one_seed, "/p9-s2"))
	# The bots are static: leave 1.0's selected for the tests that follow.
	Pilot.select(Pilot.VERSION)
	Search.select(Search.VERSION)


static func _check(fails: Array[String], label: String, pins: Dictionary, now: Dictionary) -> void:
	for key: String in pins:
		if not now.has(key) or now[key] != pins[key]:
			fails.append("balance invariance: %s%s expected %s got %s" % [label, key, pins[key], now.get(key, "no run")])
	if now.size() != pins.size():
		fails.append("balance invariance: the %spanel has %d runs, %d pinned" % [label, now.size(), pins.size()])


## Every panel run's digest under `bots`, keyed as in PINS (with `suffix`).
static func digests(content: ContentDB, bots: Array[String], greedy_seeds: Array[int],
		suffix: String) -> Dictionary:
	var out: Dictionary = {}
	for cell: String in CELLS:
		for arm: String in ARMS:
			for seed: int in greedy_seeds:
				out["%s/%s/greedy/%d%s" % [cell, arm, seed, suffix]] = _digest(content, cell, arm, "greedy", seed, bots)
			out["%s/%s/search/%d%s" % [cell, arm, SEARCH_SEED, suffix]] = _digest(content, cell, arm, "search",
				SEARCH_SEED, bots)
	return out


## One run exactly as `balance_sim.gd` plays it for the same flags.
static func _digest(content: ContentDB, cell: String, arm: String, play: String, seed: int,
		bots: Array[String]) -> String:
	var args: PackedStringArray = PackedStringArray(["--aspect=" + ASPECT, "--vow=" + cell.get_slice("-", 0).substr(1),
		"--pool=" + cell.get_slice("-", 1), "--play=" + play, "--pilot=" + bots[0]])
	if play == "search":
		args.append("--search=" + bots[1])
	var flags: Array = ARMS[arm]
	for flag_v: Variant in flags:
		args.append(str(flag_v))
	var opts: Dictionary = Sim._options(args)
	var row: Dictionary = Sim.simulate(content, ASPECT, seed, int(float(str(opts["vow"]))), PackedStringArray(),
		Sim._policy(opts), str(opts["build"]) == "random", false, Sim._mix(opts), null, false,
		str(opts["pool"]), str(opts["play"]), str(opts["pilot"]), str(opts["search"]))
	return JSON.stringify(row).sha256_text()
