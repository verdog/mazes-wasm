class Main {
	static function main() {
		var n = Std.parseInt(Sys.args()[0]);
		// var g = new ColoredGrid(n, n);
		var g = new WalllessGrid(n, n);
		// SidewinderMaze.on(g);
		// BinaryTreeMaze.on(g);
		// AldousBroderMaze.on(g);
		// WilsonMaze.on(g);
		FastMaze.on(g);

		var start = g.at(Std.int(g.rows/2), Std.int(g.columns/2));
		
		g.setDistances(start.distances());

		// g.print();
		g.png();
	}
}
