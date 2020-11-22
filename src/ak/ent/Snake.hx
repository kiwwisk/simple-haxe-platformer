package ak.ent;

import h2d.col.Bounds;
import h2d.Graphics;
import h2d.col.Point;
import h2d.Anim;

enum SnakeDirection {
	Left;
	Right;
}

enum SnakeState {
	Walking;
	Notice(noticestate:{t:Float});
	Charge(chargestate:{t:Float});
	Crashed(crashedstate:{t:Float, particles_spawned:Bool, jump_progression:Float});
}

@:publicFields
class Snake {
	var a:Anim;
	var g:Main;
	var direction:SnakeDirection;
	var state:SnakeState = Walking;

	var acc:Point;
	var vel:Point;
	var col:Graphics;

	var col_state:{on_ground:Bool, on_left:Bool, on_right:Bool} = {on_ground: false, on_left: false, on_right: false};

	var on_ground:Bool = false;

	function new(x:Int, y:Int, d:SnakeDirection) {
		g = Main.inst;
		direction = d;

		acc = new Point();
		vel = new Point();

		acc.x = 0;
		acc.y = 0;

		vel.x = 0;
		vel.y = 0;

		a = new Anim(get_anim(), 8);
		g.s2d.addChildAt(a, g.layers["Hero"]);
		a.setScale(4.0);
		a.setPosition(x, y);

		col = new Graphics(a);
		col.beginFill(0x00ff00, .5);
		col.drawRect(9, 18, 14, 14);
		col.visible = false;

		g.snakes.push(this);
	}

	function get_anim() {
		switch (direction) {
			case Right:
				var st1 = g.tiles.sub(32 * 0, 96, 32, 32);
				var st2 = g.tiles.sub(32 * 1, 96, 32, 32);
				var st3 = g.tiles.sub(32 * 2, 96, 32, 32);
				var st4 = g.tiles.sub(32 * 3, 96, 32, 32);
				return [st1, st2, st3, st4];
			case Left:
				var st1 = g.tiles.sub(32 * 0, 96, 32, 32);
				var st2 = g.tiles.sub(32 * 1, 96, 32, 32);
				var st3 = g.tiles.sub(32 * 2, 96, 32, 32);
				var st4 = g.tiles.sub(32 * 3, 96, 32, 32);
				st1.flipX();
				st1.dx = 0;
				st2.flipX();
				st2.dx = 0;
				st3.flipX();
				st3.dx = 0;
				st4.flipX();
				st4.dx = 0;
				return [st1, st2, st3, st4];
		}
	}

	function update(dt:Float) {
		var spd = 2.0;
		var max_spd = spd;
		var charge_duration = 0.5;

		switch (state) {
			case Walking:
				// switch to correct direction on terrain crash
				switch ([col_state, direction]) {
					case [{on_left: true}, Left]:
						direction = Right;
						a.play(get_anim(), 0);
					case [{on_right: true}, Right]:
						direction = Left;
						a.play(get_anim(), 0);
					case _:
				}
				acc.x = spd * (direction == Left ? -1 : 1);

				if (col_state.on_ground == false) {
					acc.x = 0;
				}

				// scan for hero in front of us:
				if (g.hero.col_state.on_ground == true) {
					var hc = g.hero.get_hero_center();
					var sc = get_center();

					if ((Math.abs(hc.x - sc.x) < 64 * 4) && (Math.abs(hc.y - sc.y) < 64)) {
						if (((direction == Left) && (hc.x < sc.x)) || ((direction == Right) && (hc.x > sc.x))) {
							state = Notice({t: 0.5});
							acc.x = 0; // stop
						}
					}
				}

				// compute the velocity
				vel.x = vel.x + 0.1 * (acc.x - vel.x);
			case Notice(noticestate):
				vel.x *= 0.89;
				noticestate.t -= dt;
				if (noticestate.t <= 0) {
					state = Charge({t: charge_duration});
					vel.y = -9;
				}
			case Charge(chargestate):
				var x = 1.0 - (chargestate.t / charge_duration);

				if ((col_state.on_left == true) || (col_state.on_right == true)) {
					state = Crashed({t: 1.0, particles_spawned: false, jump_progression: x});
				} else {
					// https://easings.net/#easeOutExpo
					if (x >= 1) {
						x = 1;
					} else {
						x = 1 - Math.pow(2, -10 * x);
					}

					max_spd = 12.0;
					vel.x = vel.x + x * (max_spd * (direction == Left ? -1 : 1) - vel.x);

					chargestate.t -= dt;
					if (chargestate.t <= 0) {
						state = Walking;
					}
				}
			case Crashed(crashedstate):
				if (!crashedstate.particles_spawned) {
					var b = col.getBounds();
					var p_x = b.x + b.width / 2;
					var p_y = b.y + b.height - 6;

					for (i in 1...Std.int((1 - crashedstate.jump_progression) * 50)) {
						var p_time = 0.5 + Math.random() * 2 - 1;
						var p_vx = Math.random() * 100 - 50;
						var p_vy = -30 - Math.random() * -30;

						g.add_particle(g.particle_tile, p_time, p_x, p_y, p_vx, p_vy);
					}

					crashedstate.particles_spawned = true;

					vel.y = -32 * (1 - crashedstate.jump_progression);
				}

				crashedstate.t -= dt;
				if (crashedstate.t <= 0) {
					state = Walking;
				}
		}

		// gravity
		switch (state) {
			case Charge(_):
				acc.y += 0.8;
			case _:
				acc.y += 1.5;
		}
		vel.y += acc.y;

		// clamp speed - always
		if (vel.x > max_spd) {
			vel.x = max_spd;
		}
		if (vel.x < -max_spd) {
			vel.x = -max_spd;
		}
		if (vel.y > max_spd * 12) {
			vel.y = max_spd * 12;
		}
		if (vel.y < -max_spd * 12) {
			vel.y = -max_spd * 12;
		}

		var bounds_before = Bounds.fromPoints(col.localToGlobal(col.getSize().getMin()), col.localToGlobal(col.getSize().getMax()));

		// change the position of `a` and change the velocity
		col_state = g.level.move_and_slide(a, bounds_before, vel);
		// move the a with rest of the velocity
		a.setPosition(a.x + vel.x, a.y + vel.y);

		acc.x = 0;
		acc.y = 0;
	}

	function get_center():Point {
		var b = a.getBounds();
		var p = new Point(a.x + b.width / 2, a.y + b.height / 2);
		return p;
	}
}
