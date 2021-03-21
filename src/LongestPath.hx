import Image.gridToPNG;

class Main {
	static function main() {
		var g = new DistanceGrid(5, 5);
		// SidewinderMaze.on(g);
		BinaryTreeMaze.on(g);

		var start = g.at(0, 0);
		var distances = start.distances();
		
		var max_data = distances.max();
		var new_start = max_data.cell;
		var distance = max_data.distance;

		var new_distances = new_start.distances();
		var max_data = new_distances.max();

		g.distances = new_distances.pathTo(max_data.cell);

		g.print();
		// gridToPNG(g);
	}
}
