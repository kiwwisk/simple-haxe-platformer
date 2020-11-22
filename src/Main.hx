package;

import ak.ent.Snake;
import h2d.col.Point;
import h2d.filter.Blur;
import hxd.Key;
import h2d.SpriteBatch;
import h2d.Graphics;
import hxd.Timer;
import hxd.Window;
import h2d.Tile;
import ak.ent.Hero;

@:publicFields
class Main extends hxd.App {
	var hero:Hero;
	var snakes:Array<Snake> = [];

	var layers:Map<String, Int> = [
		"Background2" => 0,
		"Background1" => 1,
		"Hero" => 2,
		"Water" => 3,
		"Top" => 4,
		"Debug" => 5
	];

	var tiles:Tile;

	var physical_camera:Point;
	var camera_debug:Graphics;

	var level:Level;
	var debug:Graphics;
	var parts:SpriteBatch;

	var water:Graphics;

	var particle_tile:Tile;
	var particle_timer:Float = 0;

	override function init() {
		tiles = hxd.Res.characters.toTile();
		physical_camera = new Point();
		level = new Level();

		{
			particle_tile = Tile.fromColor(0xffffff, 2, 2);
			parts = new SpriteBatch(particle_tile);
			s2d.addChildAt(parts, layers["Hero"]);
			parts.hasUpdate = true;

			parts.blendMode = Add;
			parts.filter = new h2d.filter.Group([new h2d.filter.Glow(0xffffff), new h2d.filter.Blur(5)]);
		}
		debug = new Graphics();
		s2d.addChildAt(debug, layers["Debug"]);
		debug.visible = false;

		hero = new Hero(900, 100, Standing, Right);
		new Snake(300, 150, Right);
		new Snake(1300, 150, Right);

		physical_camera = hero.get_hero_center();

		#if debug
		hxd.Res.sample_level.watch(function() {
			trace('Reload!');
			level.load_terrain();
		});
		#end

		camera_debug = new Graphics();
		s2d.addChildAt(camera_debug, layers["Debug"]);
	}

	override function update(dt:Float) {
		#if hl
		if (Key.isPressed(Key.ESCAPE) == true) {
			Sys.exit(0);
		}
		#end

		Window.getInstance().title = Std.string(Timer.fps());

		if (hxd.Key.isPressed(hxd.Key.Q)) {
			debug.visible = !debug.visible;
		}
		level.clear_colliding();

		hero.update(dt);
		for (s in snakes) {
			s.update(dt);
		}

		var p = hero.get_hero_center();

		var screen_pos = hero.get_hero_center();
		s2d.camera.cameraToScreen(screen_pos);

		var h_vel_x = hero.vel.x / 9.0; // 0..1 (1 je max velocity)

		var clamped_vel = Math.abs(h_vel_x);
		if (clamped_vel < 0.1) {
			clamped_vel = 0.1;
		}

		var desired_camera_x = p.x + (s2d.width * 0.2) * (hero.direction == Left ? -1 : 1);

		// physical_camera.x "lerps" to desired_camera.x
		physical_camera.x = physical_camera.x + (0.12 * clamped_vel) * (desired_camera_x - physical_camera.x);

		if (Math.abs(physical_camera.x - desired_camera_x) < 120) {
			// real camera X "lerps" to physical_camera.x (smootherstep)
			var t = 1.0 - Math.abs(physical_camera.x - desired_camera_x) / 120.0;
			// t = t * t * (3 - 2 * t); // smoothstep
			t = t * t * t * (t * (t * 6 - 15) + 10); // smootherstep
			s2d.camera.x = s2d.camera.x + (0.8 * t) * (physical_camera.x - (s2d.width / 2) - s2d.camera.x);
		}

		if (s2d.camera.x < 0) {
			s2d.camera.x = 0;
		}
		if (s2d.camera.x + s2d.width > level.max_x * 64 + 64) {
			s2d.camera.x = level.max_x * 64 - s2d.width + 64;
		}

		var desired_camera_y = p.y + 64;
		if ((hero.col_state.on_ground == false) && (hero.inside_water == false)) {
			if (screen_pos.y < s2d.height * 0.05) {
				physical_camera.y = desired_camera_y;
			} else if (screen_pos.y > s2d.height * 0.75) {
				physical_camera.y = desired_camera_y;
			}
		} else if (hero.inside_water == true) {
			physical_camera.y = p.y;
		} else {
			if (Math.abs(desired_camera_y - physical_camera.y) > 64 * 2) {
				physical_camera.y = desired_camera_y;
			}
		}

		s2d.camera.y = s2d.camera.y + 0.075 * (physical_camera.y - (s2d.height / 2) - s2d.camera.y);

		if (s2d.camera.y < -32) {
			s2d.camera.y = -32;
		}
		if (s2d.camera.y + s2d.height > (level.max_y + 1) * 64 - 32) {
			s2d.camera.y = (level.max_y + 1) * 64 - s2d.height - 32;
		}
	}

	static var inst:Main;

	function add_particle(t:Tile, tm:Float, x:Float, y:Float, vx:Float, vy:Float) {
		var p = new Part(t, tm, vx, vy);
		parts.add(p);
		p.x = x;
		p.y = y;
	}

	override function render(e:h3d.Engine) {
		s3d.render(e);

		camera_debug.visible = debug.visible;
		if (debug.visible == true) {
			debug.clear();

			level.draw_debug();

			camera_debug.clear();

			var pt:Point = new Point();

			camera_debug.lineStyle(1, 0xff0000);

			pt.x = physical_camera.x;
			pt.y = physical_camera.y - 100;
			camera_debug.moveTo(pt.x, pt.y);

			pt.x = physical_camera.x;
			pt.y = physical_camera.y + 100;
			camera_debug.lineTo(pt.x, pt.y);

			pt.x = physical_camera.x - 100;
			pt.y = physical_camera.y;
			camera_debug.moveTo(pt.x, pt.y);

			pt.x = physical_camera.x + 100;
			pt.y = physical_camera.y;
			camera_debug.lineTo(pt.x, pt.y);
		} // debug visible
		s2d.render(e);
	}

	static function main() {
		#if hl
		hxd.Res.initLocal();
		#else
		hxd.Res.initEmbed();
		#end

		inst = new Main();
	}
}
