class Main {
	static function main() {
		var g = new ColoredGrid(16, 16);
		// SidewinderMaze.on(g);
		BinaryTreeMaze.on(g);

		var start = g.at(0, 0);
		
		g.setDistances(start.distances());

		g.print();
		g.png();
	}
}
