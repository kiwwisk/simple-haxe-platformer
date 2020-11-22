package;

import h2d.Graphics;
import h2d.Object;
import h2d.Tile;
import h2d.TileGroup;
import h2d.col.Bounds;
import h2d.col.Point;
import h2d.Scene.Scene;

@:publicFields
class Level {
	var g:Main;

	var max_x:Int = 0;
	var max_y:Int = 0;

	var layers:Map<String, Scene>;
	var cols:Array<{b:Bounds, is_colliding:Bool}> = [];
	var tilesheet:Tile;

	function new() {
		g = Main.inst;
		tilesheet = hxd.Res.sheet.toTile();
		load_terrain();
	}

	function clear_colliding() {
		for (b in cols) {
			b.is_colliding = false;
		}
	}

	function draw_debug() {
		for (b in cols) {
			g.debug.lineStyle(2, b.is_colliding ? 0xff00ff : 0xff0000);
			g.debug.drawRect(b.b.x, b.b.y, b.b.width, b.b.height);
		}
	}

	function collide(col:Bounds):Bool {
		for (b in cols) {
			if (b.b.intersects(col))
				return true;
		}
		return false;
	}

	// Based on https://gamedev.stackexchange.com/a/22119/117750
	// first we check horizontal movement, then vertical to get correct results.
	function move_and_slide(obj:Object, col:Bounds, vel:Point):{on_ground:Bool, on_left:Bool, on_right:Bool} {
		var on_ground = false;
		var on_left = false;
		var on_right = false;
		var pos_x_change:Float = 0.0;

		// check horizontal:
		if (vel.x != 0) {
			var new_col = Bounds.fromValues(col.x + vel.x, col.y, col.width, col.height);

			for (b in cols) {
				var i = b.b.intersection(new_col);
				if (!i.isEmpty()) {
					// 320 <= 320 je false (.isEmpty() nerobi nearequal!)
					if (Math.abs(i.xMax - i.xMin) < 0.0001)
						continue;
					if (Math.abs(i.yMax - i.yMin) < 0.0001)
						continue;

					b.is_colliding = true;
					if (vel.x < 0) {
						on_left = true;
					} else {
						on_right = true;
					}

					pos_x_change = vel.x - sign(vel.x) * i.width;
					obj.x = obj.x + pos_x_change;
					vel.x = 0;
					break;
				}
			}
		}

		// check vertical:
		if (vel.y != 0) {
			var new_col = Bounds.fromValues(col.x + pos_x_change, col.y + vel.y, col.width, col.height);

			for (b in cols) {
				var i = b.b.intersection(new_col);
				if (!i.isEmpty()) {
					// 320 <= 320 je false (.isEmpty() nerobi nearequal!)
					if (Math.abs(i.xMax - i.xMin) < 0.0001)
						continue;
					if (Math.abs(i.yMax - i.yMin) < 0.0001)
						continue;

					b.is_colliding = true;
					obj.y = obj.y + vel.y - sign(vel.y) * i.height;
					on_ground = vel.y > 0;

					vel.y = 0;
					break;
				}
			}
		}
		return {on_ground: on_ground, on_left: on_left, on_right: on_right};
	}

	inline static function sign(value:Float):Float {
		return value < 0.0 ? -1.0 : 1.0;
	}

	function load_terrain() {
		max_x = 0;
		max_y = 0;

		cols = [];
		for (o in g.s2d.getLayer(g.layers["Top"]))
			o.remove();
		for (o in g.s2d.getLayer(g.layers["Background1"]))
			o.remove();
		for (o in g.s2d.getLayer(g.layers["Background2"]))
			o.remove();

		var tm = hxd.Res.sample_level.toMap();

		var flat = tilesheet.gridFlatten(16);
		for (t in flat) {
			t.scaleToSize(64, 64);
		}

		for (layer in tm.layers) {
			var x = 0;
			var y = 0;

			// add collisions:
			if (layer.name == "Collision") {
				for (t in layer.data) {
					if (t > 0) {
						cols.push({b: Bounds.fromValues(x * 64, y * 64 - 32, flat[t - 1].width, flat[t - 1].height), is_colliding: false});
						if (max_x < x)
							max_x = x;
						if (max_y < y)
							max_y = y;
					}
					x += 1;
					if (x > 49) {
						x = 0;
						y += 1;
					}
				}
				continue;
			}

			var tg = new TileGroup(tilesheet);
			g.s2d.addChildAt(tg, g.layers[layer.name]);

			if (layer.name == "Water") {
				tg.alpha = 0.5;
			}

			// add normal layer:
			for (t in layer.data) {
				if (t > 0)
					tg.add(x * 64, y * 64 - 32, flat[t - 1]);
				x += 1;
				if (x > 49) {
					x = 0;
					y += 1;
				}
			}
		}

		// add some water:
		g.water = new Graphics();
		g.s2d.addChildAt(g.water, g.layers["Background1"]);
		g.water.beginFill(0x0000ff, .5);
		g.water.drawRect(64 * 0 + 32, 408 + 64 * 2 + 10, 64 * 3, 128 + 64);
		g.water.visible = false;
	}
}
