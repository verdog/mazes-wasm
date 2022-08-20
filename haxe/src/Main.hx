var MAZES:Array<Dynamic> = [
	BinaryTreeMaze,
	SidewinderMaze,
	AldousBroderMaze,
	WilsonMaze,
	FastMaze,
	HuntAndKillMaze,
	RecursiveBacktrackerMaze,
	RecursiveRecursiveBacktrackerMaze
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

function temp() {
	var g = new PolarGrid(24);

	RecursiveRecursiveBacktrackerMaze.on(g);

	// g.setDistances(g.randomCell().calculateDistances());
	//g.setDistances(g.at(120,25).distances());

	g.png("outputs/circle.png");
}

class Main {
	
	static function main() {
		// countDeadEnds();
		// return;

		return temp();

		var n = Std.parseInt(Sys.args()[0]);

		#if debug
		n = 64;
		#end

		for (maze in MAZES) {
			var g = new ColoredGrid(n, n);
			maze.on(g);
			var start = g.at(Std.int(g.rows/2), Std.int(g.columns/2));
			g.setDistances(start.calculateDistances());
			g.png('outputs/${maze.name}_$n.png');
		}
	}
}
