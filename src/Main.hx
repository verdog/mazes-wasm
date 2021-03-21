import Image.gridToPNG;

class Main {
	static function main() {
		var g = new DistanceGrid(5, 5);
		SidewinderMaze.on(g);
		// BinaryTreeMaze.on(g);

		var start = g.at(0, 0);
		var distances = start.distances();

		g.distances = distances.pathTo(g.at(g.rows - 1, g.columns - 1));

		g.print();
		// gridToPNG(g);
	}
}
