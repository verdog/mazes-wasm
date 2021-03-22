var MAZES:Array<Dynamic> = [
	BinaryTreeMaze,
	SidewinderMaze,
	AldousBroderMaze,
	WilsonMaze,
	FastMaze,
	HuntAndKillMaze,
	RecursiveBacktrackerMaze
];

function countDeadEnds() {
	var n = Std.parseInt(Sys.args()[0]);
	var g = new ColoredGrid(n, n);

	var tries = 100;
	var size = 20;

	var averages = new Map<String, Float>();

	for (maze in MAZES) {
		// trace('Running $maze...');

		var dead_end_counts = [];
		for (i in 0...tries) {
			var grid = new Grid(size, size);
			maze.on(grid);
			dead_end_counts.push(grid.deadEnds().length);
			trace('${dead_end_counts[dead_end_counts.length - 1]}');
		}

		var total = 0;
		for (count in dead_end_counts) {
			total += count;
		}
		averages[maze.name()] = total/dead_end_counts.length;
	}

	var total_cells = size * size;

	trace('Average dead-ends per $size x $size maze ($total_cells cells):');

	var sorted = [for (algo => average in averages) {algorithm:algo, average:average}];
	sorted.sort(function(a, b) return Std.int(a.average - b.average));

	for (data in sorted) {
		var percentage = averages[data.algorithm] * 100 / (size * size);
		trace('${data.algorithm} : ${averages[data.algorithm]}/$total_cells $percentage%');
	}
}

class Main {
	
	static function main() {
		// countDeadEnds();
		// return;

		var n = Std.parseInt(Sys.args()[0]);
		var chosen_maze_name = Sys.args()[1];
		var chosen_maze = null;
		var g = new ColoredGrid(n, n);

		for (maze in MAZES) {
			if (maze.name() == chosen_maze_name) {
				chosen_maze = maze;
				break;
			}
		}

		chosen_maze.on(g);

		var start = g.at(Std.int(g.rows/2), Std.int(g.columns/2));
		
		g.setDistances(start.distances());

		g.png();
	}
}
