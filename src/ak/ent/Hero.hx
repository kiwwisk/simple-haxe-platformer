package ak.ent;

import h2d.col.Point;
import h2d.Graphics;
import hxd.Key;
import h2d.Anim;
import h2d.col.Bounds;

enum HeroDirection {
	Left;
	Right;
}

enum HeroState {
	Standing;
	Walking;
	Swimming;
	JumpBegin(jumpstate:{t:Float});
	JumpUp;
	JumpDown(jumpstate:{start_y:Float});
	JumpEnd(jumpstate:{
		t:Float,
		start_y:Float,
		particles_spawned:Bool
	});
}

@:publicFields
class Hero {
	var a:Anim;
	var state:HeroState;

	var direction:HeroDirection;
	var col:Graphics;
	var vel:h2d.col.Point;

	var acc:h2d.col.Point;

	var col_state:{
		on_ground:Bool
	} = {on_ground: false};
	var inside_water:Bool = false;

	var water_intersection:Bounds;

	var g:Main;

	function new(x:Int, y:Int, s:HeroState, d:HeroDirection) {
		g = Main.inst;
		state = s;
		direction = d;

		vel = new Point();
		acc = new Point();

		a = new Anim(get_anim(), 8);
		g.s2d.addChildAt(a, g.layers["Hero"]);
		a.play(get_anim());
		a.setScale(4.0);
		a.setPosition(x, y);

		col = new Graphics(a);
		col.beginFill(0x00ff00, .5);
		col.drawRect(9, 10, 13, 22);
		col.visible = false;

		water_intersection = Bounds.fromValues(0, 0, 0, 0);
	}

	function get_hero_center():Point {
		var b = a.getBounds();
		var p = new Point(a.x + b.width / 2, a.y + b.height / 2);
		return p;
	}

	function update(dt:Float) {
		var spd:Float = 9.0;
		var spd_acc:Float = 0.13;

		if (Key.isDown(Key.LEFT))
			acc.x -= spd;

		if (Key.isDown(Key.RIGHT))
			acc.x += spd;

		if (inside_water) {
			if (Key.isDown(Key.UP))
				acc.y -= spd;

			if (Key.isDown(Key.DOWN))
				acc.y += spd;
		}

		// apply gravity - always (on_air, on_ground, inside water)
		acc.y += 1.5;

		// apply drag (only inside water)
		if (inside_water) {
			var mag_squared = vel.x * vel.x + vel.y * vel.y;
			var v_n = vel.clone();
			v_n.normalize();
			var C:Float = -0.058;

			acc.x += C * v_n.x * mag_squared;
			acc.y += C * v_n.y * mag_squared;
		}

		if (!inside_water) {
			if (acc.x != 0) {
				vel.x = vel.x + spd_acc * (acc.x - vel.x);
			} else {
				vel.x *= col_state.on_ground ? 0.89 : 0.98;
			}
			vel.y += acc.y;
		} else {
			vel.x = vel.x + spd_acc * (acc.x - vel.x);
			vel.y = vel.y + spd_acc * (acc.y - vel.y);
		}

		var bounds_before = Bounds.fromPoints(col.localToGlobal(col.getSize().getMin()), col.localToGlobal(col.getSize().getMax()));

		function _change_state() {
			if ((direction == Left) && (vel.x > 0)) {
				direction = Right;
				a.play(get_anim(), a.currentFrame);
			} else if ((direction == Right) && (vel.x < 0)) {
				direction = Left;
				a.play(get_anim(), a.currentFrame);
			}
		}

		// correct direction based on velocity:
		_change_state();

		// falling animation:
		switch (state) {
			case Walking | Standing:
				if (col_state.on_ground == false) {
					state = JumpDown({start_y: a.y});
					a.play(get_anim(), 0);
				}
			default:
		}

		switch (state) {
			case Standing:
				if (vel.x != 0.0) {
					direction = vel.x < 0 ? Left : Right;
					state = Walking;
					a.play(get_anim(), 0);
				}
			case Walking:
				if ((Math.abs(vel.x) < 0.6)) {
					state = Standing;
					a.play(get_anim(), 0);
					vel.x = 0;
				}
			case Swimming:
				if ((Math.abs(vel.y) < 0.001)) {
					vel.y = 0;
				}
				// jump out of the water if we are sufficiently above the water-level
				if ((water_intersection.height <= col.getBounds().height / 3) && (vel.y <= 0)) {
					inside_water = false;
					vel.y = -28;
					state = JumpUp;
					a.play(get_anim(), 0);
				}
			case JumpBegin(jumpstate):
				jumpstate.t -= dt;
				if (jumpstate.t <= 0) {
					vel.y -= 28;
					state = JumpUp;
					a.play(get_anim(), 0);
				}
			case JumpUp:
				if (vel.y >= 0) {
					state = JumpDown({start_y: a.y});
					a.play(get_anim(), 0);
				}
			case JumpDown(jumpstate):
				if (inside_water) {
					state = Swimming;
					a.play(get_anim(), 0);
				} else if (col_state.on_ground) {
					state = JumpEnd({t: 0.15, start_y: jumpstate.start_y, particles_spawned: false});
					a.play(get_anim(), 0);
				}
			case JumpEnd(jumpstate):
				// spawn some particles
				if (!jumpstate.particles_spawned) {
					var b = col.getBounds();
					var p_x = b.x + b.width / 2;
					var p_y = b.y + b.height - 6;

					var w = Math.min(a.y - jumpstate.start_y, 768.0) / 768.0;
					var num:Int = Std.int(w * w * 200);

					for (i in 1...num) {
						var p_time = 0.5 + Math.random() * 2 - 1;
						var p_vx = Math.random() * 100 - 50;
						var p_vy = -30 - Math.random() * -30;

						g.add_particle(g.particle_tile, p_time, p_x, p_y, p_vx, p_vy);
					}

					jumpstate.particles_spawned = true;
				}

				jumpstate.t -= dt;
				if (jumpstate.t <= 0) {
					state = Standing;
					a.play(get_anim(), 0);
				}
		}

		// clamp speed - always
		if (vel.x > spd) {
			vel.x = spd;
		}
		if (vel.x < -spd) {
			vel.x = -spd;
		}
		if (vel.y > spd * (inside_water ? 2 : 4)) {
			vel.y = spd * (inside_water ? 2 : 4);
		}
		if (vel.y < -spd * (inside_water ? 2 : 4)) {
			vel.y = -spd * (inside_water ? 2 : 4);
		}

		// change the position of `a` and change the velocity
		col_state = g.level.move_and_slide(a, bounds_before, vel);
		// move the a with rest of the velocity
		a.setPosition(a.x + vel.x, a.y + vel.y);
		if ((col_state.on_ground == true) && (Key.isDown(Key.UP) == true)) {
			switch (state) {
				case Walking | Standing:
					state = JumpBegin({t: 0.1});
					a.play(get_anim(), 0);
				default:
			}
		}

		switch (state) {
			case JumpUp:
			// we are trying to jump out of the water, don't check for water then.
			default:
				// check if we are inside water (this should go to Level.check_water() or something)
				var new_bounds = Bounds.fromValues(bounds_before.x + vel.x, bounds_before.y + vel.y, bounds_before.width, bounds_before.height);
				inside_water = g.water.getBounds().intersects(new_bounds);
				if (inside_water) {
					water_intersection = g.water.getBounds().intersection(new_bounds);
				}
		}

		// reset acceleration
		acc.x = 0;
		acc.y = 0;
	}

	function get_anim() {
		switch (state) {
			case Standing:
				if (direction == Right) {
					return [g.tiles.sub(32 * 0, 0, 32, 32)];
				} else {
					var t = g.tiles.sub(32 * 0, 0, 32, 32);
					t.flipX();
					t.dx = 0;
					return [t];
				}
			case Walking:
				if (direction == Right) {
					var st1 = g.tiles.sub(32 * 0, 0, 32, 32);
					var st2 = g.tiles.sub(32 * 1, 0, 32, 32);
					var st3 = g.tiles.sub(32 * 2, 0, 32, 32);
					var st4 = g.tiles.sub(32 * 3, 0, 32, 32);
					return [st1, st2, st3, st4];
				} else {
					var st1 = g.tiles.sub(32 * 0, 0, 32, 32);
					var st2 = g.tiles.sub(32 * 1, 0, 32, 32);
					var st3 = g.tiles.sub(32 * 2, 0, 32, 32);
					var st4 = g.tiles.sub(32 * 3, 0, 32, 32);
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
			case JumpBegin(_):
				if (direction == Right) {
					return [g.tiles.sub(32 * 4, 0, 32, 32)];
				} else {
					var t = g.tiles.sub(32 * 4, 0, 32, 32);
					t.flipX();
					t.dx = 0;
					return [t];
				}
			case JumpUp:
				if (direction == Right) {
					return [g.tiles.sub(32 * 5, 0, 32, 32)];
				} else {
					var t = g.tiles.sub(32 * 5, 0, 32, 32);
					t.flipX();
					t.dx = 0;
					return [t];
				}
			case JumpDown(_) | Swimming:
				if (direction == Right) {
					return [g.tiles.sub(32 * 6, 0, 32, 32)];
				} else {
					var t = g.tiles.sub(32 * 6, 0, 32, 32);
					t.flipX();
					t.dx = 0;
					return [t];
				}
			case JumpEnd(_):
				if (direction == Right) {
					return [g.tiles.sub(32 * 7, 0, 32, 32)];
				} else {
					var t = g.tiles.sub(32 * 7, 0, 32, 32);
					t.flipX();
					t.dx = 0;
					return [t];
				}
		}
	}
}
