class Main {
	static function main() {
		var g = new ColoredGrid(64, 64);
		SidewinderMaze.on(g);
		// BinaryTreeMaze.on(g);

		var start = g.at(63, 0);
		
		g.setDistances(start.distances());

		// g.print();
		g.png();
	}
}
