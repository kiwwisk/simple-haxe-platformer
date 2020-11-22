package;

import h2d.col.Bounds;
import h2d.Tile;
import h2d.SpriteBatch;

@:publicFields
class Part extends BatchElement {
	var vx:Float = 0;
	var vy:Float = 0;

	var time:Float;
	var gm:Main;

	function new(t:Tile, time_:Float, vx_:Float, vy_:Float) {
		super(t);

		vx = vx_;
		vy = vy_;

		time = time_;
		gm = Main.inst;
	}

	override function update(dt:Float):Bool {
		var spd:Float = 18;
		time -= dt;
		if (time <= 0) {
			return false;
		}

		vy += 0.5; // add gravity

		// clamp velocity
		if (vx > spd) {
			vx = spd;
		}
		if (vx < -spd) {
			vx = -spd;
		}
		if (vy > spd * 4) {
			vy = spd * 4;
		}
		if (vy < -spd * 4) {
			vy = -spd * 4;
		}

		x += vx;
		var b = Bounds.fromValues(x, y, 4, 4);
		if (gm.level.collide(b)) {
			x -= vx;
			vx *= -0.3;
		}

		y += vy;
		var b = Bounds.fromValues(x, y, 4, 4);
		if (gm.level.collide(b)) {
			y -= vy;
			vy *= -0.5;
		}

		// add friction
		var f = Math.pow(0.95, dt * 60);
		vx *= f;
		vy *= f;

		return true;
	}
}
